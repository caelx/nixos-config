{ inputs, config, pkgs, ... }:

let
  # Derive home directory from user config
  homeDir = config.users.users.nixos.home;
  ageKeyPath = "${homeDir}/.local/state/sops-nix/sops-age.key";

  generate-age-key = pkgs.writeShellScriptBin "generate-age-key" ''
    set -euo pipefail
    TARGET_FILE="${ageKeyPath}"
    TARGET_DIR=$(dirname "$TARGET_FILE")

    if [ -f "$TARGET_FILE" ]; then
        echo "Error: Age key already exists at $TARGET_FILE"
        echo "If you want to regenerate it, delete the file first."
        exit 1
    fi

    echo "Generating a fresh age key at $TARGET_FILE..."
    mkdir -p "$TARGET_DIR"
    ${pkgs.age}/bin/age-keygen -o "$TARGET_FILE"
    chmod 600 "$TARGET_FILE"
    
    echo "Success! Age key generated at $TARGET_FILE"
    echo "Please back up this file. It is required to decrypt secrets."
    ${pkgs.age}/bin/age-keygen -y "$TARGET_FILE"
  '';

  secrets-edit = pkgs.writeShellScriptBin "secrets-edit" ''
    export SOPS_AGE_KEY_FILE="${ageKeyPath}"
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    if [ -z "''${1:-}" ]; then
      echo "Usage: secrets-edit <filename>"
      exit 1
    fi
    # If file exists locally, use it. Otherwise try repo root.
    if [ -f "$1" ]; then
      exec ${pkgs.sops}/bin/sops "$@"
    else
      exec ${pkgs.sops}/bin/sops "$REPO_ROOT/$1"
    fi
  '';

  secrets-decrypt = pkgs.writeShellScriptBin "secrets-decrypt" ''
    export SOPS_AGE_KEY_FILE="${ageKeyPath}"
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    if [ -z "''${1:-}" ]; then
      echo "Usage: secrets-decrypt <filename>"
      exit 1
    fi
    # If file exists locally, use it. Otherwise try repo root.
    if [ -f "$1" ]; then
      exec ${pkgs.sops}/bin/sops -d "$@"
    else
      exec ${pkgs.sops}/bin/sops -d "$REPO_ROOT/$1"
    fi
  '';

  secrets-encrypt = pkgs.writeShellScriptBin "secrets-encrypt" ''
    export SOPS_AGE_KEY_FILE="${ageKeyPath}"
    exec ${pkgs.sops}/bin/sops -e "$@"
  '';

  secrets-get-public-key = pkgs.writeShellScriptBin "secrets-get-public-key" ''
    if [ ! -f "${ageKeyPath}" ]; then
      echo "Error: Age key not found at ${ageKeyPath}"
      echo "Run generate-age-key first."
      exit 1
    fi
    ${pkgs.age}/bin/age-keygen -y "${ageKeyPath}"
  '';

  secrets-list-keys = pkgs.writeShellScriptBin "secrets-list-keys" ''
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    SOPS_CONFIG="$REPO_ROOT/.sops.yaml"

    if [ ! -f "$SOPS_CONFIG" ]; then
      echo "Error: .sops.yaml not found at $SOPS_CONFIG"
      exit 1
    fi

    echo "Public keys and associated systems in .sops.yaml:"
    echo "--------------------------------------------------"
    # Extract age keys and comments, handling cases with and without comments
    grep "age1" "$SOPS_CONFIG" | sed -E 's/^[[:space:]]*- ([^[:space:]#]+)([[:space:]]*#[[:space:]]*)?(.*)$/\1 \3/' | while read -r key system; do
      printf "%-60s | %s\n" "$key" "''${system:-Unknown}"
    done
  '';

  secrets-reencrypt = pkgs.writeShellScriptBin "secrets-reencrypt" ''
    export SOPS_AGE_KEY_FILE="${ageKeyPath}"
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    TARGET_FILE="''${1:-secrets.yaml}"

    # If file exists locally, use it. Otherwise try repo root.
    if [ -f "$TARGET_FILE" ]; then
      FILE_PATH="$TARGET_FILE"
    else
      FILE_PATH="$REPO_ROOT/$TARGET_FILE"
    fi

    if [ ! -f "$FILE_PATH" ]; then
      echo "Error: Secrets file not found at $FILE_PATH"
      exit 1
    fi

    echo "Re-encrypting $FILE_PATH using keys defined in .sops.yaml..."
    ${pkgs.sops}/bin/sops updatekeys "$FILE_PATH"
  '';

  secrets-add-key = pkgs.writeShellScriptBin "secrets-add-key" ''
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    SOPS_CONFIG="$REPO_ROOT/.sops.yaml"

    if [ -z "''${1:-}" ]; then
      echo "Usage: secrets-add-key <public_age_key> [system_name]"
      exit 1
    fi

    NEW_KEY="$1"
    SYSTEM_NAME="''${2:-}"

    if [ ! -f "$SOPS_CONFIG" ]; then
      echo "Error: .sops.yaml not found at $SOPS_CONFIG"
      exit 1
    fi

    # Check if key already exists
    if grep -q "$NEW_KEY" "$SOPS_CONFIG"; then
      echo "Key already exists in .sops.yaml"
      exit 0
    fi

    echo "Adding key $NEW_KEY to $SOPS_CONFIG..."
    # Add the key using yq
    ${pkgs.yq-go}/bin/yq -i ".creation_rules[0].key_groups[0].age += [\"$NEW_KEY\"]" "$SOPS_CONFIG"

    # If system name provided, append the comment to the line with the new key
    if [ -n "$SYSTEM_NAME" ]; then
      sed -i "s|$NEW_KEY|$NEW_KEY # $SYSTEM_NAME|" "$SOPS_CONFIG"
    fi
    echo "Key added. Don't forget to run secrets-reencrypt."
  '';


  secrets-remove-key = pkgs.writeShellScriptBin "secrets-remove-key" ''
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    SOPS_CONFIG="$REPO_ROOT/.sops.yaml"

    if [ -z "''${1:-}" ]; then
      echo "Usage: secrets-remove-key <public_age_key>"
      exit 1
    fi

    KEY_TO_REMOVE="$1"

    if [ ! -f "$SOPS_CONFIG" ]; then
      echo "Error: .sops.yaml not found at $SOPS_CONFIG"
      exit 1
    fi

    echo "Removing key $KEY_TO_REMOVE from $SOPS_CONFIG..."
    # Using yq to remove the key from the first creation rule's age list
    ${pkgs.yq-go}/bin/yq -i ".creation_rules[0].key_groups[0].age -= [\"$KEY_TO_REMOVE\"]" "$SOPS_CONFIG"
    echo "Key removed. Don't forget to run secrets-reencrypt."
  '';

  register-host = pkgs.writeShellScriptBin "register-host" ''
    set -euo pipefail
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    
    echo "Paste the JSON bootstrap data and press Ctrl+D:"
    DATA=$(cat)
    
    # Check if data is valid JSON
    if ! echo "$DATA" | ${pkgs.jq}/bin/jq . >/dev/null 2>&1; then
      echo "Error: Invalid JSON input."
      exit 1
    fi

    HOSTNAME=$(echo "$DATA" | ${pkgs.jq}/bin/jq -r '.hostname')
    PUBLIC_KEY=$(echo "$DATA" | ${pkgs.jq}/bin/jq -r '.public_key')
    HW_CONFIG=$(echo "$DATA" | ${pkgs.jq}/bin/jq -r '.hardware_config')
    
    if [ -z "$HOSTNAME" ] || [ "$HOSTNAME" == "null" ]; then
      echo "Error: Could not parse hostname from input."
      exit 1
    fi
    
    echo "Registering host: $HOSTNAME"
    echo "Public Key: $PUBLIC_KEY"
    
    # 1. Update .sops.yaml
    echo "Updating .sops.yaml..."
    # Fallback to direct yq and sed if helper not available
    ${pkgs.yq-go}/bin/yq -i ".creation_rules[0].key_groups[0].age += [\"$PUBLIC_KEY\"]" "$REPO_ROOT/.sops.yaml"
    sed -i "s|$PUBLIC_KEY|$PUBLIC_KEY # $HOSTNAME|" "$REPO_ROOT/.sops.yaml"
    
    # 2. Create host directory and files
    HOST_DIR="$REPO_ROOT/hosts/$HOSTNAME"
    mkdir -p "$HOST_DIR"
    
    echo "Updating $HOST_DIR/hardware-configuration.nix..."
    echo "$HW_CONFIG" > "$HOST_DIR/hardware-configuration.nix"
    
    if [ ! -f "$HOST_DIR/default.nix" ]; then
      echo "Creating basic $HOST_DIR/default.nix..."
      cat > "$HOST_DIR/default.nix" <<EOF
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "$HOSTNAME";
}
EOF
    fi
    
    # 3. Re-encrypt secrets
    echo "Re-encrypting secrets..."
    export SOPS_AGE_KEY_FILE="${ageKeyPath}"
    ${pkgs.sops}/bin/sops updatekeys "$REPO_ROOT/secrets.yaml"
    
    echo ""
    echo "--------------------------------------------------------------------------------"
    echo "Host $HOSTNAME has been registered successfully!"
    echo "Next Steps:"
    echo "1. Verify .sops.yaml changes."
    echo "2. Add '$HOSTNAME' to 'flake.nix' in the 'nixosConfigurations' section."
    echo "3. Commit and push the changes."
    echo "4. On the new host, run: sudo nixos-rebuild switch --flake .#$HOSTNAME"
    echo "--------------------------------------------------------------------------------"
  '';
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  environment.systemPackages = [ 
    generate-age-key 
    secrets-edit
    secrets-decrypt
    secrets-encrypt
    secrets-get-public-key
    secrets-reencrypt
    secrets-add-key
    secrets-remove-key
    secrets-list-keys
    register-host
  ];

  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";

    # Ensure we use the package from sops-nix itself
    package = inputs.sops-nix.packages.${pkgs.stdenv.hostPlatform.system}.sops-install-secrets;

    age.keyFile = ageKeyPath;

    secrets = {
      nixos-password = { neededForUsers = true; };
    };
  };
}

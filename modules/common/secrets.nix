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
      echo "Usage: secrets-add-key <public_age_key>"
      exit 1
    fi

    NEW_KEY="$1"

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
    # Using yq to add the key to the first creation rule's age list
    ${pkgs.yq-go}/bin/yq -i ".creation_rules[0].key_groups[0].age += [\"$NEW_KEY\"]" "$SOPS_CONFIG"
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

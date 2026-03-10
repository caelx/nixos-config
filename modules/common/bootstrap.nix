{ config, pkgs, lib, ... }:

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
    # Ensure user 'nixos' and group 'users' exist before chown
    if id "nixos" >/dev/null 2>&1; then
      chown nixos:users "$TARGET_FILE"
    fi
    chmod 600 "$TARGET_FILE"
    
    echo "Success! Age key generated at $TARGET_FILE"
    echo "Please back up this file. It is required to decrypt secrets."
    ${pkgs.age}/bin/age-keygen -y "$TARGET_FILE"
  '';

  bootstrap-host = pkgs.writeShellScriptBin "bootstrap-host" ''
    set -euo pipefail
    
    # 0. Find Repo Root
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/nixos-config")
    if [ ! -d "$REPO_ROOT" ]; then
      echo "Error: Could not find repository root at $REPO_ROOT"
      exit 1
    fi

    # 1. Get hostname
    NEW_HOSTNAME="''${1:-}"
    if [ -z "$NEW_HOSTNAME" ]; then
      printf "Enter the new hostname for this system: "
      read -r NEW_HOSTNAME
    fi
    if [ -z "$NEW_HOSTNAME" ]; then
      echo "Error: Hostname cannot be empty."
      exit 1
    fi

    echo "--------------------------------------------------------------------------------"
    echo "BOOTSTRAP: Initializing $NEW_HOSTNAME"
    echo "--------------------------------------------------------------------------------"

    # 2. Create host directory
    HOST_DIR="$REPO_ROOT/hosts/$NEW_HOSTNAME"
    mkdir -p "$HOST_DIR"

    # 3. Generate Hardware Configuration
    if [ ! -f "$HOST_DIR/hardware-configuration.nix" ]; then
      echo "Generating hardware configuration..."
      ${pkgs.nixos-install-tools}/bin/nixos-generate-config --no-filesystems --show-hardware-config > "$HOST_DIR/hardware-configuration.nix"
    fi

    # 4. Create basic default.nix for the host
    if [ ! -f "$HOST_DIR/default.nix" ]; then
      echo "Creating basic default.nix for $NEW_HOSTNAME..."
      cat > "$HOST_DIR/default.nix" <<EOF
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "$NEW_HOSTNAME";
}
EOF
    fi

    # 5. SOPS Age Key Generation
    TARGET_FILE="${ageKeyPath}"
    if [ -f "$TARGET_FILE" ]; then
      echo "SOPS Age key already exists at $TARGET_FILE"
      PUBLIC_KEY=$(${pkgs.age}/bin/age-keygen -y "$TARGET_FILE")
    else
      echo "Generating a new SOPS Age key..."
      mkdir -p "$(dirname "$TARGET_FILE")"
      ${pkgs.age}/bin/age-keygen -o "$TARGET_FILE"
      if id "nixos" >/dev/null 2>&1; then
        chown nixos:users "$TARGET_FILE"
      fi
      chmod 600 "$TARGET_FILE"
      PUBLIC_KEY=$(${pkgs.age}/bin/age-keygen -y "$TARGET_FILE")
      echo "New SOPS Age key generated at $TARGET_FILE"
    fi

    echo ""
    echo "Public Key: $PUBLIC_KEY"
    echo ""
    echo "Next Steps:"
    echo "1. Add the public key to '.sops.yaml' in the repository root."
    echo "2. Run 'secrets-reencrypt' to update the secrets file."
    echo "3. Add '$NEW_HOSTNAME' to 'flake.nix' in the 'nixosConfigurations' section."
    echo "4. Commit the new files."
    echo "5. Run 'sudo nixos-rebuild switch --flake .#$NEW_HOSTNAME' to apply."
    echo "--------------------------------------------------------------------------------"
  '';
in
{
  environment.systemPackages = [
    bootstrap-host
    generate-age-key
  ];
}

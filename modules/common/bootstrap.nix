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
    
    # Check if we are running on a NixOS system
    if [ ! -f /etc/os-release ] || ! grep -q "NixOS" /etc/os-release; then
      echo "Error: This script must be run on a NixOS system."
      exit 1
    fi

    echo "--------------------------------------------------------------------------------"
    echo "NixOS Host Bootstrap Utility"
    echo "--------------------------------------------------------------------------------"

    # 0. Find Repo Root
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/nixos-config")
    if [ ! -d "$REPO_ROOT" ]; then
      echo "Error: Could not find repository root at $REPO_ROOT"
      echo "Please clone the repository first: git clone <repo> ~/nixos-config"
      exit 1
    fi

    # 1. Get hostname (argument or interactive)
    NEW_HOSTNAME="''${1:-}"
    if [ -z "$NEW_HOSTNAME" ]; then
      printf "Enter the new hostname for this system: "
      read -r NEW_HOSTNAME
    fi
    if [ -z "$NEW_HOSTNAME" ]; then
      echo "Error: Hostname cannot be empty."
      exit 1
    fi

    # 2. Create host directory
    HOST_DIR="$REPO_ROOT/hosts/$NEW_HOSTNAME"
    mkdir -p "$HOST_DIR"

    # 3. Generate Hardware Configuration
    echo "Generating hardware configuration for $NEW_HOSTNAME..."
    ${pkgs.nixos-install-tools}/bin/nixos-generate-config --no-fstab --show-hardware-config > "$HOST_DIR/hardware-configuration.nix"
    echo "Hardware configuration saved to: $HOST_DIR/hardware-configuration.nix"

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

  # Add host-specific modules or configuration here
}
EOF
    fi

    echo ""

    # 5. SOPS Age Key Generation
    TARGET_FILE="${ageKeyPath}"
    if [ -f "$TARGET_FILE" ]; then
      echo "SOPS Age key already exists at $TARGET_FILE"
      PUBLIC_KEY=$(${pkgs.age}/bin/age-keygen -y "$TARGET_FILE")
    else
      echo "Generating a new SOPS Age key..."
      mkdir -p "$(dirname "$TARGET_FILE")"
      ${pkgs.age}/bin/age-keygen -o "$TARGET_FILE"
      # Ensure user 'nixos' and group 'users' exist before chown
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
    echo "2. Run 'secrets-reencrypt' to update the secrets file with the new key."
    echo "3. Add '$NEW_HOSTNAME' to 'flake.nix' in the 'nixosConfigurations' section."
    echo "4. Commit and push the changes (if possible)."
    echo "5. Run 'sudo nixos-rebuild switch --flake $REPO_ROOT#$NEW_HOSTNAME' on this host."
    echo "--------------------------------------------------------------------------------"
  '';
in
{
  # Activation scripts
  system.activationScripts = {
    # Named with 'aaa' prefix to ensure it runs early (alphabetical order)
    aaaSopsBootstrap = {
      supportsDryActivation = true;
      deps = [ "users" "groups" ];
      text = ''
        # Check if age key exists
        TARGET_FILE="${ageKeyPath}"
        if [ ! -f "$TARGET_FILE" ]; then
          echo "--------------------------------------------------------------------------------"
          echo "BOOTSTRAP: New Host Initialization"
          echo "--------------------------------------------------------------------------------"
          
          # 1. Determine hostname from configuration
          CURRENT_HOSTNAME="${config.networking.hostName}"
          echo "Target Hostname: $CURRENT_HOSTNAME"

          # 2. SOPS Key Generation
          echo "Generating SOPS Age key..."
          mkdir -p "$(dirname "$TARGET_FILE")"
          # Since this runs as root during activation, we need to ensure the user owns it
          ${pkgs.age}/bin/age-keygen -o "$TARGET_FILE"
          if id "nixos" >/dev/null 2>&1; then
            chown nixos:users "$TARGET_FILE"
          fi
          chmod 600 "$TARGET_FILE"
          PUBLIC_KEY=$(${pkgs.age}/bin/age-keygen -y "$TARGET_FILE")
          
          # 3. Hardware Configuration Generation
          echo "Generating hardware configuration..."
          TEMP_HW_CONFIG=$(mktemp --suffix=.nix)
          ${pkgs.nixos-install-tools}/bin/nixos-generate-config --no-fstab --show-hardware-config > "$TEMP_HW_CONFIG"
          
          echo ""
          echo "New Public Key: $PUBLIC_KEY"
          echo "Hardware configuration generated at: $TEMP_HW_CONFIG"
          echo ""
          echo "Please follow these steps to complete the bootstrap:"
          echo "1. Copy $TEMP_HW_CONFIG to 'hosts/$CURRENT_HOSTNAME/hardware-configuration.nix' in your repo."
          echo "2. Add this public key to '.sops.yaml' in the repository."
          echo "3. Run 'secrets-reencrypt' to update the secrets file."
          echo "4. Commit and push the changes."
          echo "5. Pull the changes on this host and run 'nixos-rebuild switch' again."
          echo "--------------------------------------------------------------------------------"
          
          # Exit with error to halt activation if we are NOT in a dry run
          if [ -z "''${NIXOS_ACTION:-}" ] || [ "''${NIXOS_ACTION}" != "dry-activate" ]; then
            exit 1
          fi
        fi
      '';
    };
  };

  environment.systemPackages = [
    bootstrap-host
    generate-age-key
  ];
}

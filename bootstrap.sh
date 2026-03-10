#!/usr/bin/env bash
set -euo pipefail

# 0. Find Repo Root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)")
if [ ! -d "$REPO_ROOT" ]; then
  echo "Error: Could not find repository root."
  exit 1
fi

# 1. Get hostname
NEW_HOSTNAME="''${1:-}"
if [ -z "$NEW_HOSTNAME" ]; then
  echo "Usage: $0 <hostname>"
  echo "Error: Hostname is required."
  exit 1
fi

echo "--------------------------------------------------------------------------------"
echo "BOOTSTRAP: Initializing $NEW_HOSTNAME"
echo "--------------------------------------------------------------------------------"

# 2. Create host directory
HOST_DIR="$REPO_ROOT/hosts/$NEW_HOSTNAME"
mkdir -p "$HOST_DIR"

# 3. Generate Hardware Configuration
HW_CONFIG_OUT="$HOME/hardware-configuration.nix"
echo "Generating hardware configuration..."
if command -v nixos-generate-config >/dev/null; then
  nixos-generate-config --no-filesystems --show-hardware-config > "$HW_CONFIG_OUT"
else
  # Try to run via nix-shell if not installed
  nix-shell -p nixos-install-tools --run "nixos-generate-config --no-filesystems --show-hardware-config" > "$HW_CONFIG_OUT"
fi
echo "Hardware configuration saved to: $HW_CONFIG_OUT"

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
TARGET_FILE="$HOME/.local/state/sops-nix/sops-age.key"
if [ -f "$TARGET_FILE" ]; then
  echo "SOPS Age key already exists at $TARGET_FILE"
  if command -v age-keygen >/dev/null; then
    PUBLIC_KEY=$(age-keygen -y "$TARGET_FILE")
  else
    PUBLIC_KEY=$(nix-shell -p age --run "age-keygen -y $TARGET_FILE")
  fi
else
  echo "Generating a new SOPS Age key..."
  mkdir -p "$(dirname "$TARGET_FILE")"
  if command -v age-keygen >/dev/null; then
    age-keygen -o "$TARGET_FILE"
    chmod 600 "$TARGET_FILE"
    PUBLIC_KEY=$(age-keygen -y "$TARGET_FILE")
  else
    nix-shell -p age --run "age-keygen -o $TARGET_FILE"
    chmod 600 "$TARGET_FILE"
    PUBLIC_KEY=$(nix-shell -p age --run "age-keygen -y $TARGET_FILE")
  fi
  echo "New SOPS Age key generated at $TARGET_FILE"
fi

echo ""
echo "Public Key for $NEW_HOSTNAME:"
echo "$PUBLIC_KEY # $NEW_HOSTNAME"
echo ""
echo "Next Steps:"
echo "1. Copy the hardware config: cp $HW_CONFIG_OUT hosts/$NEW_HOSTNAME/"
echo "2. Add the public key line above to '.sops.yaml' in the repository root."
echo "3. Run 'secrets-reencrypt' (or nix-shell -p sops --run 'sops updatekeys secrets.yaml') to update secrets."
echo "4. Add '$NEW_HOSTNAME' to 'flake.nix' in the 'nixosConfigurations' section."
echo "5. Commit the new files in 'hosts/$NEW_HOSTNAME'."
echo "6. Run 'sudo nixos-rebuild switch --flake $REPO_ROOT#$NEW_HOSTNAME' to apply."
echo "--------------------------------------------------------------------------------"

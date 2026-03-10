#!/usr/bin/env bash
set -euo pipefail

# 0. Find Repo Root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")
if [ ! -d "$REPO_ROOT" ]; then
  echo "Error: Could not find repository root."
  exit 1
fi

# 1. Check for root (should NOT be run as root directly, but will use sudo when needed)
if [ "$(id -u)" -eq 0 ]; then
  echo "Error: This script should be run as a normal user, not root."
  echo "It will use 'sudo' internally when necessary."
  exit 1
fi

# 2. Get hostname
if [ $# -lt 1 ]; then
  echo "Usage: $0 <hostname>"
  echo "Error: Hostname argument is required."
  exit 1
fi

# Ensure we have a clean hostname string
NEW_HOSTNAME="${1//\'/}"
if [ -z "$NEW_HOSTNAME" ]; then
  echo "Error: Hostname cannot be empty."
  exit 1
fi

# Use nix-shell to ensure we have jq and age available for the rest of the script
if [[ "$*" != *"--nix-shell-internal"* ]]; then
  exec nix-shell -p jq age nixos-install-tools --run "bash $0 $NEW_HOSTNAME --nix-shell-internal"
fi

echo "--------------------------------------------------------------------------------"
echo "BOOTSTRAP: Initializing $NEW_HOSTNAME"
echo "--------------------------------------------------------------------------------"

# 3. Generate Hardware Configuration
echo "Generating hardware configuration (may require sudo)..."
TMP_HW_CONFIG=$(mktemp)
# Trap to ensure cleanup even if something fails
trap 'rm -f "$TMP_HW_CONFIG"' EXIT

# Redirect stderr to /dev/null to hide sudo password prompt if it fails to get sudo access,
# though sudo should usually be allowed to run.
if sudo nixos-generate-config --no-filesystems --show-hardware-config > "$TMP_HW_CONFIG" 2>/dev/null; then
    HW_CONFIG_CONTENT=$(cat "$TMP_HW_CONFIG")
else
    echo "Warning: Could not generate hardware configuration automatically."
    HW_CONFIG_CONTENT="{ ... }: { }"
fi
rm -f "$TMP_HW_CONFIG"
# Clear trap as we've manually cleaned up or reached a point where it's no longer needed
trap - EXIT

# 4. SOPS Age Key Generation
TARGET_FILE="$HOME/.local/state/sops-nix/sops-age.key"
if [ ! -f "$TARGET_FILE" ]; then
  echo "Generating a new SOPS Age key..."
  mkdir -p "$(dirname "$TARGET_FILE")"
  age-keygen -o "$TARGET_FILE"
  chmod 600 "$TARGET_FILE"
  echo "New SOPS Age key generated at $TARGET_FILE"
else
  echo "SOPS Age key already exists at $TARGET_FILE"
fi
PUBLIC_KEY=$(age-keygen -y "$TARGET_FILE")

echo ""
echo "--------------------------------------------------------------------------------"
echo "MACHINE READABLE DATA (Copy the block below including braces)"
echo "--------------------------------------------------------------------------------"
jq -n \
  --arg hostname "$NEW_HOSTNAME" \
  --arg public_key "$PUBLIC_KEY" \
  --arg hw_config "$HW_CONFIG_CONTENT" \
  '{hostname: $hostname, public_key: $public_key, hardware_config: $hw_config}'
echo "--------------------------------------------------------------------------------"
echo ""

echo "Next Steps:"
echo "1. Copy the JSON block above."
echo "2. On your management machine, run: register-host"
echo "3. Paste the JSON when prompted."
echo "--------------------------------------------------------------------------------"

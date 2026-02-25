{ config, lib, pkgs, ... }:

{
  # System-level activation script to fix home directory ownership
  # This runs as root, allowing it to fix files owned by root.
  system.activationScripts.homeChown = {
    text = ''
      # Detect the default user from WSL configuration if available, else fallback
      USER="${config.wsl.defaultUser or "nixos"}"
      HOME_DIR="/home/$USER"
      SENTINEL="$HOME_DIR/.local/state/nix/home_chown.done"

      # Only proceed if the user exists and the group with the same name exists
      if id "$USER" >/dev/null 2>&1 && getent group "$USER" >/dev/null 2>&1; then
        if [ -d "$HOME_DIR" ] && [ ! -f "$SENTINEL" ]; then
          echo "Running one-time system-level home directory chown for $USER:$USER..."
          
          # Ensure the sentinel directory exists with correct ownership first
          mkdir -p "$(dirname "$SENTINEL")"
          chown -R "$USER:$USER" "$(dirname "$SENTINEL")"

          # Perform the recursive chown
          chown -R "$USER:$USER" "$HOME_DIR"

          # Create the sentinel file
          touch "$SENTINEL"
          chown "$USER:$USER" "$SENTINEL"
        fi
      else
        echo "Skipping home directory chown: user or group '$USER' does not exist."
      fi
    '';
    # Ensure this runs after the users and groups are created
    deps = [ "users" "groups" ];
  };
}

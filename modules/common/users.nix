{ config, pkgs, ... }:

{
  # System-level activation script to fix home directory ownership
  # This runs as root, allowing it to fix files owned by root.
  system.activationScripts.homeChown = {
    text = ''
      USER="nixos"
      HOME_DIR="/home/$USER"
      SENTINEL="$HOME_DIR/.local/state/nix/home_chown.done"

      if [ -d "$HOME_DIR" ] && [ ! -f "$SENTINEL" ]; then
        echo "Running one-time system-level home directory chown for $USER..."
        
        # Ensure the sentinel directory exists with correct ownership first
        mkdir -p "$(dirname "$SENTINEL")"
        chown -R $USER:nixos "$(dirname "$SENTINEL")"

        # Perform the recursive chown
        chown -R $USER:nixos "$HOME_DIR"

        # Create the sentinel file
        touch "$SENTINEL"
        chown $USER:nixos "$SENTINEL"
      fi
    '';
    # Ensure this runs after the users are created and after Home Manager activation
    deps = [ "users" "groups" ];
  };
}

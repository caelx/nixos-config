{
  description = "Unified NixOS Configuration Repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    sops-nix = {
      url = "github:Mic92/sops-nix";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixos-wsl, nix-index-database, ... }@inputs: 
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      apps = forAllSystems (system: {
        bootstrap = {
          type = "app";
          program = let
            pkgs = pkgsFor system;
            # Use the same logic as in modules/common/bootstrap.nix but standalone
            bootstrap-script = pkgs.writeShellScriptBin "bootstrap-host" ''
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
                # We assume we are running on the target machine
                if command -v nixos-generate-config >/dev/null; then
                  nixos-generate-config --no-filesystems --show-hardware-config > "$HOST_DIR/hardware-configuration.nix"
                else
                  echo "Warning: nixos-generate-config not found. Creating empty hardware-configuration.nix"
                  echo "{ ... }: { }" > "$HOST_DIR/hardware-configuration.nix"
                fi
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
              # We use the same path as defined in common/secrets.nix
              TARGET_FILE="$HOME/.local/state/sops-nix/sops-age.key"
              if [ -f "$TARGET_FILE" ]; then
                echo "SOPS Age key already exists at $TARGET_FILE"
                PUBLIC_KEY=$(${pkgs.age}/bin/age-keygen -y "$TARGET_FILE")
              else
                echo "Generating a new SOPS Age key..."
                mkdir -p "$(dirname "$TARGET_FILE")"
                ${pkgs.age}/bin/age-keygen -o "$TARGET_FILE"
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
              echo "4. Commit the new files in 'hosts/$NEW_HOSTNAME'."
              echo "5. Run 'sudo nixos-rebuild switch --flake .#$NEW_HOSTNAME' to apply."
              echo "--------------------------------------------------------------------------------"
            '';
          in "${bootstrap-script}/bin/bootstrap-host";
        };
      });

      nixosConfigurations = {
      # Primary host
      launch-octopus = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self; };
        modules = [
          nixos-wsl.nixosModules.default
          ./hosts/launch-octopus/default.nix
          
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nixos = ./home/nixos.nix;
            home-manager.sharedModules = [
              nix-index-database.homeModules.nix-index
            ];
          }
        ];
      };
      # Armored Armadillo (Desktop WSL2)
      armored-armadillo = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self; };
        modules = [
          nixos-wsl.nixosModules.default
          ./hosts/armored-armadillo/default.nix
          
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nixos = ./home/nixos.nix;
            home-manager.sharedModules = [
              nix-index-database.homeModules.nix-index
            ];
          }
        ];
      };
      # Boomer Kuwanger (Emulator PC)
      boomer-kuwanger = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self; };
        modules = [
          inputs.nixos-hardware.nixosModules.common-cpu-amd
          inputs.nixos-hardware.nixosModules.common-gpu-amd
          inputs.nixos-hardware.nixosModules.common-pc-ssd
          ./hosts/boomer-kuwanger/default.nix
          
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nixos = ./home/nixos.nix;
            home-manager.sharedModules = [
              nix-index-database.homeModules.nix-index
            ];
          }
        ];
      };
    };
  };
}

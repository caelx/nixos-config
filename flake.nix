{
  description = "Unified NixOS Configuration Repository";

  inputs = {
    # NixOS official package source, using the nixos-24.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Home Manager for user-level configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Optimized hardware configurations
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    # NixOS configurations
    nixosConfigurations = {
      # Placeholder for the first host
      # workstation = nixpkgs.lib.nixosSystem { ... };
    };

    # Home Manager configurations
    homeConfigurations = {
      # Placeholder for the primary user
      # "james" = home-manager.lib.homeManagerConfiguration { ... };
    };
  };
}

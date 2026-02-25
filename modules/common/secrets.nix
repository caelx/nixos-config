{ inputs, config, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";

    age.keyFile = "/home/nixos/.ssh/id_ed25519"; # Using user's SSH key for age

    secrets = {
      smb-user = { };
      smb-pass = { };
    };
  };
}

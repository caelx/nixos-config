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

  sops-edit = pkgs.writeShellScriptBin "sops-edit" ''
    export SOPS_AGE_KEY_FILE="${ageKeyPath}"
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    if [ -z "''${1:-}" ]; then
      echo "Usage: sops-edit <filename>"
      exit 1
    fi
    # If file exists locally, use it. Otherwise try repo root.
    if [ -f "$1" ]; then
      exec ${pkgs.sops}/bin/sops "$@"
    else
      exec ${pkgs.sops}/bin/sops "$REPO_ROOT/$1"
    fi
  '';

  sops-decrypt = pkgs.writeShellScriptBin "sops-decrypt" ''
    export SOPS_AGE_KEY_FILE="${ageKeyPath}"
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    if [ -z "''${1:-}" ]; then
      echo "Usage: sops-decrypt <filename>"
      exit 1
    fi
    # If file exists locally, use it. Otherwise try repo root.
    if [ -f "$1" ]; then
      exec ${pkgs.sops}/bin/sops -d "$@"
    else
      exec ${pkgs.sops}/bin/sops -d "$REPO_ROOT/$1"
    fi
  '';

  sops-encrypt = pkgs.writeShellScriptBin "sops-encrypt" ''
    export SOPS_AGE_KEY_FILE="${ageKeyPath}"
    exec ${pkgs.sops}/bin/sops -e "$@"
  '';
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  environment.systemPackages = [ 
    generate-age-key 
    sops-edit
    sops-decrypt
    sops-encrypt
  ];

  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";

    # Ensure we use the package from sops-nix itself
    package = inputs.sops-nix.packages.${pkgs.system}.sops-install-secrets;

    age.keyFile = ageKeyPath;

    secrets = {
      smb-user = { };
      smb-pass = { };
      smb-server = { };
      smb-share = { };
    };
  };
}

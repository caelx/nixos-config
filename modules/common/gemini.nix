{ pkgs, ... }:

let
  gemini-cli = pkgs.writeShellScriptBin "gemini" ''
    # Launch Gemini CLI via npx to avoid manual global installs
    # and ensure we always have the tool available.
    # We suppress node warnings as in the original config.
    export NODE_NO_WARNINGS=1
    exec ${pkgs.nodejs}/bin/npx -y @google/gemini-cli "$@"
  '';
in
{
  environment.systemPackages = [
    gemini-cli
  ];
}

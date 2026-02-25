{ pkgs, ... }:

let
  gemini-cli = pkgs.writeShellScriptBin "gemini" ''
    # Launch Gemini CLI via npx to avoid manual global installs
    # and ensure we always have the tool available.
    # We suppress node warnings as in the original config.
    export NODE_NO_WARNINGS=1
    
    # Ensure conductor extension is installed
    if ! "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli extensions list | grep -q "conductor"; then
      "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/conductor --auto-update --consent
    fi

    # Ensure security extension is installed
    if ! "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli extensions list | grep -q "security"; then
      "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/security --auto-update --consent
    fi

    exec ${pkgs.nodejs}/bin/npx -y @google/gemini-cli "$@"
  '';
in
{
  environment.systemPackages = [
    gemini-cli
  ];
}

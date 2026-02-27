{ pkgs, ... }:

let
  gemini-cli = pkgs.writeShellScriptBin "gemini" ''
    # Launch Gemini CLI via npx to avoid manual global installs
    # and ensure we always have the tool available.
    export NODE_NO_WARNINGS=1
    
    # Ensure conductor extension is installed
    if [ ! -d "$HOME/.gemini/extensions/conductor" ]; then
      "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/conductor --auto-update --consent
    fi

    # Ensure security extension is installed
    if [ ! -d "$HOME/.gemini/extensions/gemini-cli-security" ]; then
      "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/security --auto-update --consent
    fi

    "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli "$@"
  '';
in
{
  environment.systemPackages = [
    gemini-cli
  ];
}

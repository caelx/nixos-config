{ pkgs, ... }:

let
  gemini-cli = pkgs.writeShellScriptBin "gemini" ''
    # Launch Gemini CLI via npx to avoid manual global installs
    # and ensure we always have the tool available.
    # We suppress node warnings as in the original config.
    export NODE_NO_WARNINGS=1
    
    # Ensure conductor extension is installed
    if [ ! -d "$HOME/.gemini/extensions/conductor" ]; then
      "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/conductor --auto-update --consent
    fi

    # Ensure security extension is installed
    if [ ! -d "$HOME/.gemini/extensions/gemini-cli-security" ]; then
      "${pkgs.nodejs}/bin/npx" -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/security --auto-update --consent
    fi

    # Use a temporary file to capture output for high demand detection
    TMP_OUT=$(mktemp)
    
    # Run gemini and capture output while still showing it to the user
    # We use a trap to ensure the temp file is cleaned up
    trap 'rm -f "$TMP_OUT"' EXIT
    
    ${pkgs.nodejs}/bin/npx -y @google/gemini-cli "$@" | tee "$TMP_OUT"
    
    # Check for High Demand message
    if grep -q "We are currently experiencing high demand" "$TMP_OUT"; then
      if command -v win-notify >/dev/null 2>&1; then
        # Get tab info if possible
        TAB_INFO="$(hostname):$(pwd | sed "s|^$HOME|~|")"
        win-notify "Gemini is experiencing high demand" "Action Required" "$TAB_INFO"
      fi
    fi
  '';
in
{
  environment.systemPackages = [
    gemini-cli
  ];
}

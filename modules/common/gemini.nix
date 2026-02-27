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

    # Use a temporary file to capture output for high demand detection
    TMP_OUT=$(mktemp)
    
    # Ensure cleanup on exit
    trap 'rm -f "$TMP_OUT"; [ -n "$DETECTOR_PID" ] && kill "$DETECTOR_PID" 2>/dev/null' EXIT
    
    # Start background detector to tail the output in real-time
    (
      # Wait for file to exist
      until [ -f "$TMP_OUT" ]; do sleep 0.1; done
      
      # Tail the file and trigger notification on match
      # We use a loop to catch multiple occurrences if they happen
      tail -f -n +1 "$TMP_OUT" | grep --line-buffered "We are currently experiencing high demand" | while read -r line; do
        if command -v win-notify >/dev/null 2>&1; then
          TAB_INFO="$(hostname):$(pwd | sed "s|^$HOME|~|")"
          win-notify "Gemini is experiencing high demand" "Action Required" "$TAB_INFO"
        fi
      done
    ) >/dev/null 2>&1 &
    DETECTOR_PID=$!

    # Run gemini using 'script' to capture interactive output while maintaining TTY.
    # -q: quiet (don't show start/stop messages)
    # -f: flush output after each write (critical for real-time tailing)
    # -e: return exit code of child process
    # -c: command to run
    script -q -f -e -c "${pkgs.nodejs}/bin/npx -y @google/gemini-cli $(printf '%q ' "$@")" "$TMP_OUT"
    EXIT_CODE=$?
    
    exit $EXIT_CODE
  '';
in
{
  environment.systemPackages = [
    gemini-cli
  ];
}

{ pkgs, lib, ... }:

let
  base-gemini = pkgs.writeShellScriptBin "gemini-base" ''
    # Ensure conductor extension is installed
    if [ ! -d "$HOME/.gemini/extensions/conductor" ]; then
      npx -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/conductor --auto-update --consent
    fi

    # Ensure security extension is installed
    if [ ! -d "$HOME/.gemini/extensions/gemini-cli-security" ]; then
      npx -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/security --auto-update --consent
    fi

    npx -y @google/gemini-cli "$@"
  '';

  gemini-cli = pkgs.symlinkJoin {
    name = "gemini";
    paths = [ base-gemini ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/gemini-base \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs ]} \
        --set NODE_NO_WARNINGS 1
      mv $out/bin/gemini-base $out/bin/gemini
    '';
  };
in
{
  environment.systemPackages = [
    gemini-cli
  ];

  environment.etc."gemini-cli/settings.json".text = builtins.toJSON {
    general = {
      sessionRetention = {
        enabled = true;
        maxAge = "30d";
        warningAcknowledged = true;
      };
      defaultApprovalMode = "default";
      enablePromptCompletion = true;
    };
    security = {
      auth = {
        selectedType = "oauth-personal";
      };
      enablePermanentToolApproval = true;
    };
    context = {
      fileFiltering = {
        respectGitIgnore = false;
      };
    };
    hooks = {
      AfterAgent = [
        {
          matcher = "*";
          hooks = [
            {
              name = "notify-waiting";
              type = "command";
              command = "notify-send \"Gemini\" \"Waiting for input...\" -u critical";
            }
          ];
        }
      ];
    };
    mcpServers = {
      playwright = {
        command = "mcp-server-playwright";
        args = [ ];
        env = {
          PLAYWRIGHT_HEADLESS = "true";
        };
      };
    };
  };
}

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

    # Ensure nix skill is installed
    if [ ! -d "$HOME/.gemini/skills/nix" ]; then
      npx -y @google/gemini-cli skills install ${./../../home/config/skills/nix/nix.skill} --scope user --consent
    fi

    # Ensure wsl2 skill is installed
    if [ ! -d "$HOME/.gemini/skills/wsl2" ]; then
      npx -y @google/gemini-cli skills install ${./../../home/config/skills/wsl2/wsl2.skill} --scope user --consent
    fi

    # Ensure python skill is installed
    if [ ! -d "$HOME/.gemini/skills/python" ]; then
      npx -y @google/gemini-cli skills install ${./../../home/config/skills/python/python.skill} --scope user --consent
    fi

    npx -y @google/gemini-cli "$@"
  '';

  gemini-cli = pkgs.symlinkJoin {
    name = "gemini";
    paths = [ base-gemini ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/gemini-base \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs pkgs.uv pkgs.playwright-driver.browsers pkgs.openssh ]} \
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
    experimental = {
      modelSteering = true;
      plan = true;
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
    skills = {
      enabled = true;
      default = [ ];
    };
    hooksConfig = {
      enabled = true;
    };
    hooks = {
      Notification = [
        {
          matcher = "ToolPermission";
          hooks = [
            {
              name = "user-input-notifier";
              type = "command";
              command = "notify-send \"Gemini\" \"Tool requires approval...\" -u critical";
            }
          ];
        }
      ];
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
      ssh = {
        command = "npx";
        args = [ "-y" "@aiondadotcom/mcp-ssh" ];
        env = {
          SSH_AUTH_SOCK = "/run/user/1000/ssh-agent";
        };
      };
      browser-use = {
        command = "uvx";
        args = [ "--from" "browser-use[cli]" "browser-use" "--mcp" ];
        env = {
          BROWSER_USE_HEADLESS = "true";
        };
      };
    };
  };
}

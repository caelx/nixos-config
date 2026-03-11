{ pkgs, lib, ... }:

let
  mkSkill = name: src: pkgs.runCommand "${name}.skill" {
    nativeBuildInputs = [ pkgs.zip ];
  } ''
    cd ${src}
    zip -r $out .
  '';

  skills = {
    nix = mkSkill "nix" ./../../home/config/skills/nix;
    wsl2 = mkSkill "wsl2" ./../../home/config/skills/wsl2;
    python = mkSkill "python" ./../../home/config/skills/python;
    browser-use = mkSkill "browser-use" ./../../home/config/skills/browser-use;
    build123d = mkSkill "build123d" ./../../home/config/skills/build123d;
  };

  base-gemini = pkgs.writeShellScriptBin "gemini-base" ''
    # Ensure conductor extension is installed
    if [ ! -d "$HOME/.gemini/extensions/conductor" ]; then
      npx -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/conductor --auto-update --consent
    fi

    # Ensure security extension is installed
    if [ ! -d "$HOME/.gemini/extensions/gemini-cli-security" ]; then
      npx -y @google/gemini-cli extensions install https://github.com/gemini-cli-extensions/security --auto-update --consent
    fi

    # Helper function to install or update a skill
    sync_skill() {
      local name=$1
      local src=$2
      local marker="$HOME/.gemini/skills/$name/.nix-store-path"

      if [ ! -f "$marker" ] || [ "$(cat "$marker")" != "$src" ]; then
        echo "Syncing skill: $name..."
        npx -y @google/gemini-cli skills install "$src" --scope user --consent
        echo "$src" > "$marker"
      fi
    }

    sync_skill "nix" "${skills.nix}"
    sync_skill "wsl2" "${skills.wsl2}"
    sync_skill "python" "${skills.python}"
    sync_skill "browser-use" "${skills.browser-use}"
    sync_skill "build123d" "${skills.build123d}"

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

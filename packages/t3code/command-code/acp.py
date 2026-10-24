#!/usr/bin/env python3
"""Launch native Command Code with persisted login and zero data retention."""

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def provider_environment(environment):
    # Native login in persisted HOME owns authentication. Never inject vault or
    # Command Code API credentials. Hosted catalogs remain native and current.
    env = {k: v for k, v in environment.items()
           if not k.startswith(("BW_", "COMMAND_CODE_", "AGENT_BW_"))
           and k != "CMD_DISABLE_REMOTE_MODEL_CATALOG"}
    env.update(CMD_ZDR="1", COMMANDCODE_SKIP_UPDATES="1", DO_NOT_TRACK="1")
    return env


def main():
    if sys.argv[1:] not in (["acp"], ["login"], ["--version"]):
        raise ValueError("this managed cmd entry accepts acp, login or --version")
    # No protocol intermediary: model catalogs, order, native defaults, commands,
    # configuration options and session operations all belong to the agent.
    # Native login owns auth.json; do not read, copy or serialize its token.
    os.execvpe("node", ["node", str(ROOT / "node_modules/command-code/dist/index.mjs"),
                       *sys.argv[1:]], provider_environment(os.environ))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Command Code provider unavailable; check native login and installation.", file=sys.stderr)
        sys.exit(1)

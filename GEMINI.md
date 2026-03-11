# Project Gemini Memories

This file serves as the primary memory and persistent fact store for Gemini CLI within this project.

## Lessons Learned

- (New lessons will be added here automatically when Gemini learns from mistakes or discovers new project conventions.)

## Gemini Added Memories

- **Skill Refactor**: The `nixos` skill has been renamed to `system` and set as a default skill in `modules/common/gemini.nix`.
- **Memory Policy**: Gemini is now instructed to use this `GEMINI.md` file for project-specific persistence instead of global memory.
- **Automated Maintenance**: Automated daily garbage collection and generation cleanup (keeping 7 days) is configured in `modules/common/default.nix`. Use `nh clean all --keep X` for manual pruning.
- **Plan Mode Enabled**: Experimental plan mode has been enabled in `modules/develop/gemini.nix` while maintaining `default` as the default approval mode.
- **SSH MCP & Agent**: `mcp-ssh` is configured to use the SSH agent at `/run/user/1000/ssh-agent`. Users must ensure their keys (especially password-protected ones) are loaded into the agent before using remote tasks.
- **MCP Runners**: `uv` and `nodejs` (for `npx`) are required for the current MCP server configurations (`mcp-browser-use` and `mcp-ssh`).
- **oh-my-gemini**: The `richardcb/oh-my-gemini` extension is installed and managed via the Gemini wrapper in `modules/develop/gemini.nix`.
- **Python Skill Added**: A new `python` skill for modern development using `uv`, Nix flakes, and comprehensive testing/linting has been added to `home/config/skills/python/`.

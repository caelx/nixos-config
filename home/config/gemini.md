# Project Gemini: Global Instructions & System Expert

## Core Directives

### 1. Memory & Persistence
- **Primary Store**: ALWAYS use the project-level `GEMINI.md` as the primary memory and persistent fact store for the current workspace.
- **Save Memory**: Use `save_memory` ONLY for cross-project user preferences or high-level global facts.
- **Continuous Learning**: If you make a mistake, find a bug, or discover a non-obvious convention, update the `## Lessons Learned` or `## Gemini Added Memories` section in the project's `GEMINI.md` immediately.

### 2. NixOS & Development Workflow
- **Environment**: ALWAYS use **Nix Flakes** (`flake.nix`) for project environments.
- **Activation**: PRIORITIZE **`direnv`** with `.envrc` for seamless shell activation. Avoid `nix-shell -p` for persistent projects.
- **System Management**: Use **`nh`** (Nix Helper) for system rebuilds (`nh os switch`), builds (`nh os build`), and searching (`nh search`).
- **One-off Commands**: Use **`,` (comma)** for ephemeral execution of utilities not in the permanent configuration.
- **Shell Syntax**: All shell snippets must be valid **Fish** syntax (e.g., `set -x VAR val`, `; and`, `^/dev/null`).

### 3. Engineering Standards
- **File Inspection**: NEVER use `cat` to read files. Always use the `read_file` tool for surgical or full-file inspection.
- **Testing (TDD)**: Prioritize unit tests. Attempt to run tests autonomously using project-specific runners.
- **Conductor Validation**: In the Conductor workflow, ALWAYS attempt to execute "Manual Verification Steps" autonomously if they involve non-interactive shell commands. Validation is the only path to finality.
- **Non-Interactive Execution**: Always use non-interactive flags (e.g., `-y`, `--yes`, `--no-pager`) and environment variables (e.g., `CI=true`, `PAGER=cat`) to ensure commands terminate.
- **Documentation**: Maintain `README.md`, `CHANGELOG.md`, and `VERSION` files. Update them with every significant change.
- **Versioning**: Increment the **Patch** version for tasks, and **Minor** version for Phase/Track completions in the `VERSION` file.

## Expertise Sections

### Python Development
- **Package Manager**: Use **`uv`** for dependency management (`uv add`, `uv run`, `uv init`).
- **Linting/Formatting**: Use **`ruff`** for linting and formatting (`ruff check --fix`, `ruff format`).
- **Layout**: Use the **`src/` layout** and a unified **`pyproject.toml`**.
- **Testing**: Use **`pytest`**.

## Command Reference Matrix

| Action | Command | Tool/Logic |
| :--- | :--- | :--- |
| **Dev Environment** | `nix develop` / `direnv allow` | Nix Flakes / direnv |
| **Build Config** | `nh os build` | nh |
| **Apply Config** | `nh os switch` | nh |
| **Search Pkgs** | `nh search <query>` | nh |
| **Run Once** | `, <command>` | comma |
| **File Inspection** | `read_file <path>` | Internal Tool |
| **Testing** | `<test-runner> <args>` | Autonomously verify code |

## Interaction Protocol
- **Proactive Validation**: Run tests or verification steps autonomously after implementation.
- **Documentation First**: Ensure `README.md` and `CHANGELOG.md` are updated before finalizing any task.
- **Brevity**: Provide commands first, followed by concise technical rationale.

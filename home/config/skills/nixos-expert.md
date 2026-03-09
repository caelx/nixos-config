# Role: NixOS & General Development Expert
# Context: Unified development workflow focusing on NixOS, automation, TDD, and documentation.

## Core Directives
* **NixOS & Environments**:
    * ALWAYS use **Nix Flakes** for project environments.
    * PRIORITIZE **`direnv`** with environment variables for seamless shell activation.
    * Use **`nh`** for system rebuilds and searches.
    * Use **`,` (comma)** for ephemeral utility execution.
* **Test-Driven Development (TDD)**:
    * PRIORITIZE writing and running unit tests autonomously using project-specific runners.
* **Conductor & Automation**:
    * Automate Conductor "Manual Verification Steps" whenever possible via non-interactive shell commands.
    * NEVER run interactive commands (e.g., `vim`, `less`); always use non-interactive flags or environment variables (e.g., `PAGER=cat`).
* **Documentation Mandate**:
    * ALWAYS generate and maintain a **`README.md`** and a **`CHANGELOG.md`**.
    * Keep these files up to date with every new feature, bug fix, or significant change.

## Command Reference Matrix
| Action | Command | Tool |
| :--- | :--- | :--- |
| **Apply Config** | `nh os switch` | nh |
| **Run Once** | `, <command>` | comma |
| **Environment** | `direnv allow` | direnv |
| **Testing** | `<test-runner>` | pytest/npm/etc |

## Interaction Protocol
* **Documentation First**: Before finalizing a task, ensure `README.md` and `CHANGELOG.md` reflect the current state.
* **Fish Syntax**: All shell snippets must be valid **Fish** syntax.
* **Non-Interactive**: Ensure all tool calls and commands are designed to terminate without user input.

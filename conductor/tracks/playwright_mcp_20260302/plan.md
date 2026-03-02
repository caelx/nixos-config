# Implementation Plan - Playwright MCP Integration for Gemini

## Phase 1: Package Installation & Environment Configuration
- [x] Task: Update `home/nixos.nix` to install Playwright packages. 087513f
    - [x] Add `pkgs.playwright-driver.browsers` and `pkgs.playwright` to `home.packages`.
- [x] Task: Configure Playwright environment variables in `home/nixos.nix`. 087513f
    - [x] Set `PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}"`.
    - [x] Set `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"`.
- [ ] Task: Conductor - User Manual Verification 'Package Installation & Environment Configuration' (Protocol in workflow.md)

## Phase 2: Gemini CLI Integration
- [ ] Task: Update Gemini CLI settings in `home/nixos.nix`.
    - [ ] Add `mcpServers` block to `home.file.".gemini/settings.json"`.
    - [ ] Configure `playwright` MCP server with `command: "npx"` and `args: ["-y", "@modelcontextprotocol/server-playwright"]`.
- [ ] Task: Conductor - User Manual Verification 'Gemini CLI Integration' (Protocol in workflow.md)

## Phase 3: Validation & Testing
- [ ] Task: Verify integration and browser access.
    - [ ] Apply changes with `nh home switch`.
    - [ ] Run a test command via Gemini CLI to verify browser navigation.
- [ ] Task: Conductor - User Manual Verification 'Validation & Testing' (Protocol in workflow.md)

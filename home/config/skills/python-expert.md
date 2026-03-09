# Role: Python Development Expert
# Context: Modern Python development using `uv`, `ruff`, and `src` layout.

## Core Directives
* **Package Management**: ALWAYS use **`uv`** for dependency management, virtual environments, and running scripts (`uv pip`, `uv run`, `uv venv`).
* **Code Structure**: All source code MUST be placed in a **`src/`** directory (src layout).
* **Formatting & Linting**:
    * Use **`ruff`** for fast linting and auto-formatting.
    * Use **`Pylance`** (via Pyright) for type checking and LSP-based formatting in the editor.
* **Testing Strategy**:
    * Implement **Unit Tests** for isolated logic.
    * Implement **Integration Tests** for component interactions.
    * Use `pytest` as the primary test runner.
* **Tooling Priority**:
    * Use `uv run ruff format` for code formatting.
    * Use `uv run pytest` for running tests.

## Command Reference Matrix
| Action | Command | Tool |
| :--- | :--- | :--- |
| **Install Depts** | `uv add <pkg>` | uv |
| **Run Code** | `uv run <script>.py` | uv |
| **Format Code** | `uv run ruff format .` | ruff |
| **Lint Code** | `uv run ruff check .` | ruff |
| **Run Tests** | `uv run pytest` | pytest |

## Interaction Protocol
* **Standard Layout**: When starting a project, immediately recommend `uv init` and moving code to `src/`.
* **Test-Driven**: Encourage writing tests alongside implementation, separating unit and integration tests into `tests/unit` and `tests/integration`.

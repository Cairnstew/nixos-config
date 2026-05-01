# 🤖 Agent Operating Guide (Global)

## 0. Purpose & Authority
This repository is a **Deterministic System Graph**. All modifications must treat the repository structure as a strict execution environment. 

**Namespace Constraint:** All custom options and services defined in this repository MUST reside under the `my.*` attribute set (e.g., `my.services.name`, `my.programs.name`).

**Intent Hierarchy:**
1.  **`default.nix` (Implementation):** The primary source of truth for evaluation.
2.  **`meta.nix` (Semantic Intent):** Machine-readable contract for autowiring and LLM reasoning.
3.  **`tests.nix` (Validation):** Required test definitions for the module.
4.  **`AGENT.md` (Local Policy):** Local overrides for specific module constraints.

---

## 1. Directory & File Convention
Each module is a self-contained unit located under `modules/<category>/<name>/`.

### 1.1 Required Files
* **`default.nix`**: The entrypoint. Defines the `my.*` options and imports all logic.
* **`meta.nix`**: Machine-readable metadata (name, tags, description) for **Nix-Unified** autowiring.
* **`tests.nix`**: Contains `systemd` smoke tests, VM tests, or assertions. **MUST** be imported via `default.nix`.
* **`README.md`**: Human documentation.

### 1.2 Sidecar Implementation Pattern
Functionality should be decomposed into logical units rather than one monolithic file.
* **Internal Logic:** Separate distinct features (e.g., networking, specific systemd units, package wrappers) into their own `.nix` files within the module directory.
* **Explicit Imports:** All sidecar files (including `tests.nix`) **MUST** be explicitly imported in `default.nix`. No directory scanning is permitted.

---

## 2. Core Operating Principles

### 2.1 Explicit Dependency Graphs
Modules must be designed as a clear chain of dependencies. When modifying a module, trace the execution flow:
> **Options/Inputs** → **Internal Implementation Modules** → **Systemd/Configuration Units** → **Test Validation**

### 2.2 The `my.*` Namespace
Agents must never define options in the global NixOS namespace (e.g., `services.*`) unless extending an existing upstream module. All new features must be nested under `options.my`.

### 2.3 Minimal Structural Mutation
* **Preserve Import Topology:** Maintain the existing relationship between `default.nix` and its sidecar files.
* **No Stylistic Refactoring:** Do not reformat code or change variable naming unless it directly relates to a functional requirement.

---

## 3. Modification Protocol

1.  **Context Sync:** Read `meta.nix` for intent and `AGENT.md` for local constraints.
2.  **Modular Decomposition:** If a change introduces a new distinct functionality, create a new `.nix` file (e.g., `feature.nix`) and import it into `default.nix`.
3.  **Namespace Alignment:** Ensure all new options are placed under `my.<category>.<name>`.
4.  **Test Integration:** Every logic change requires a corresponding update in `tests.nix`. Ensure the smoke tests or assertions cover the new state.
5.  **Metadata Update:** If options change, update `meta.nix` to ensure the "Contract" remains accurate for the autowirer.

---

## 4. Failure Modes (Hard Gates)
The following will result in a rejected change:
* **Implicit Imports:** Adding a sidecar file without an explicit `import ./file.nix` in `default.nix`.
* **Namespace Violation:** Defining options outside the `my.*` hierarchy.
* **Missing `tests.nix`:** Creating or significantly refactoring a module without a functional `tests.nix` file.
* **Metadata Drift:** Mismatch between the behavior in the code and the description in `meta.nix`.

---

## 5. Design Philosophy
This repository optimizes for **Machine-Readable Intent**. We prefer explicit code over "clever" Nix abstractions. Every module should be understandable by an Agent through its `meta.nix` and verifiable through its `tests.nix`.
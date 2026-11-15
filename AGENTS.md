# Agent Guide (`red-tape`)

Convention-based Nix flake builder on `adios-flake` with `hjem` / `hjem-rum` Manifest v3 and `hjemSchemas` support (`leporuid/red-tape`).

## 1. Repository Layout

| Path | Responsibility |
| :--- | :--- |
| `flake.nix` | Public API (`mkFlake`, `modules`, `hjemSchemas`, `formatter`, `devShells` with `nix-unit` + `nixfmt-tree`). |
| `lib/default.nix` | `mkFlake` entrypoint and `redTape` module re-export. |
| `lib/internal.nix` | Pure filesystem scanning (`scanDir`, `scanHosts`, `scanEntries`, `scanSubdirs`) and builders (`buildHosts`, `buildAll`, `filterPlatforms`). |
| `modules/default.nix` | Top-level `adios` module declaring flake-scoped outputs (`modules`, `hjemConfigurations`, `hjemModules`, `rumModules`, `schemas`). |
| `modules/*.nix` | Per-concern `adios` modules (`project`, `scope`, `packages`, `devshells`, `formatter`, `checks`, `hosts`, `modules`, `templates`, `lib`, `contrib`). |
| `contrib/*.nix` | Opt-in host and module extensions (`darwin.nix`, `home-manager.nix`, `hjem.nix`, `system-manager.nix`). |
| `tests/` | `nix-unit` test suite aggregated in `tests/default.nix` with offline fixtures in `tests/fixtures/`. |

## 2. Architecture Rules

- **Host & User Discovery**: `modules/hosts.nix` scans `(scanHosts (src + "/users") hostTypes) // (scanHosts (src + "/hosts") hostTypes)`.
- **Hjem Contrib (`contrib/hjem.nix`)**:
  - Registers `hjem-configuration.nix` and `home-configuration.nix` → `hjemConfigurations`.
  - Registers `moduleTypes` (`hjem` → `hjemModules`, `rum` → `rumModules`).
  - Evaluates `lib.evalModules` with `class = "hjem"`, `clobberFiles = lib.mkDefault true`, optional `hjem-rum` / `hjem-impure` inputs, `system.nix` sibling override, and emits Manifest v3 (`manifest`, `packages`, `config`, `options`, `build`).
- **Schemas**: `flake.nix` exports `hjemSchemas` (`hjemConfigurations`, `hjemModules`, `rumModules`) for `flake-schemas` / Determinate Nix checks.

## 3. Verification & Hygiene

- **Tests**: `nix develop -c nix-unit tests/default.nix` (must pass all tests offline).
- **Formatting**: `nix fmt` (`nixfmt-tree`, RFC 166).
- **Git & Context**: Never read `flake.lock`. Stage only modified target files and use Conventional Commits.

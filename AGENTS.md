# AGENTS.md

Standalone Quickshell (QML) settings app for a Caelestia + Hyprland desktop. No build system, test suite, lint, or CI — the app runs directly from source and verification is running it and observing the live effects.

## Run

```sh
scripts/setup-symlinks.sh   # required once after clone (see below)
qs -p .
```

## Symlinked directories (critical)

`components/`, `services/`, `utils/`, `modules/`, `assets/` are git-ignored symlinks into the system-installed Caelestia shell (`/etc/xdg/quickshell/caelestia`, override the source location with `CAELESTIA_DIR`). A fresh clone has none of them and the app won't run; recreate with `scripts/setup-symlinks.sh`.

- Never edit anything under these symlinks — that hits the installed shell, not this repo.
- The app vendors nothing; a Caelestia/Quickshell update that changes component APIs may break this repo's glue code.

## Imports

Quickshell `qs.` imports resolve against the repo root and the symlinked dirs — don't confuse repo-local code with the linked shell:

- `qs.core` → this repo's `core/` (`Schemes`, `HyprVars` singletons)
- `qs.pages`, `qs.ui` → this repo's `pages/`, `ui/`
- `qs.components`, `qs.services`, `qs.utils`, `qs.modules.*` → the **linked Caelestia shell**
- `Caelestia.Config` (e.g. `GlobalConfig`, `Colours`, `Tokens`) → the linked shell's QML modules

Every file uses `pragma ComponentBehavior: Bound`; follow that convention.

## Update-safety contract

Never write files owned by the Caelestia dots. Only the sanctioned override layers:

| Domain | Mechanism |
|---|---|
| Colour scheme | `caelestia scheme set` CLI (`core/Schemes.qml`) |
| Shell settings | `GlobalConfig.<section>.<key>` → `~/.config/caelestia/shell.json`; read + persistence automatic |
| Hyprland settings | `core/HyprVars.qml` writes **only** `~/.config/caelestia/hypr-vars.lua`; merged at config load |
| Monitors/Displays | `core/Displays.qml` writes **only** `~/.config/caelestia/monitors.lua` (`hl.monitor({...})` calls, required from `hypr-user.lua` — the require line is bootstrapped once at startup); live state from `Quickshell.Hyprland` IPC |

**Applying config changes**: `hyprctl keyword` is rejected by Hyprland's native Lua config ("non-legacy parsers") — do not use it. Both `hypr-vars.lua` and `monitors.lua` take effect through Hyprland's config auto-reload (file watch); `core/Displays.qml` additionally calls `hyprctl reload` after each write for immediacy.

Hyprland details:

- Defaults are parsed from `~/.config/hypr/variables.lua`; values are kept as raw Lua RHS strings, and anything the naive parser can't understand is preserved verbatim on write. Don't replace `parseLua` with a real Lua parser — verbatim passthrough is the point.
- Overrides equal to the `variables.lua` default are **deleted** from the file, not written — keep the override file minimal.

## Adding a setting

- **Shell**: add a row in `pages/ShellPage.qml` bound to the matching `GlobalConfig.<section>.<key>`.
- **Hyprland**: add a `schema` entry in `core/HyprVars.qml` (`key` = `variables.lua` name, `live` = hyprctl keyword path if mappable, `type` = `"int" | "real" | "bool" | "string" | "app"`), then a row in `pages/HyprlandPage.qml` (local `NumRow`/`BoolRow`/`AppRow` components; `AppRow` wraps `ui/AppSelectRow.qml`).
- **Monitor/Display**: specs stream live from `Quickshell.Hyprland` (`Hyprland.monitors` + `lastIpcObject` — no polling); controls live in `pages/DisplaysPage.qml`, setters/persistence in `core/Displays.qml`. Only overridden fields reach `monitors.lua`; unknown hand-edited fields there are preserved verbatim.

## Known quirks

- `ui/AppSelectRow.qml` exists because the upstream `SelectRow` menu stops repainting inside this app's `FloatingWindow` (Qt layering bug). Don't swap it back for the upstream control.
- **Gating the dropdown overlay uses `visible`, not `enabled`**: child MouseAreas of a disabled MouseArea still receive clicks in this Quickshell build — `enabled` alone left the collapsed panel at (0,0) live as a click target over the sidebar.
- `core/Schemes.qml` hardcodes the installed schemes dir (`/usr/lib/python3.14/site-packages/caelestia/data/schemes`) — bump it when the Caelestia/Python package version changes.
- A monitor rule that omits `scale` inherits Hyprland's **auto** scale (2 on this panel at native res), not the dots' scale = 1 — `writeOverrides` always pins scale explicitly.

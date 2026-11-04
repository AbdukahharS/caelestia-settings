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
| Keybinds (`kb*` variables) | same `core/HyprVars.qml` / `hypr-vars.lua` layer (`bindsSchema` + `setBind`/`resetBind`); values are bare strings or `{ "A", "B" }` tables |
| Monitors/Displays | `core/Displays.qml` writes **only** `~/.config/caelestia/monitors.lua` (`hl.monitor({...})` calls, required from `hypr-user.lua` — the require line is bootstrapped once at startup); live state from `Quickshell.Hyprland` IPC |

**Applying config changes**: `hyprctl keyword` is rejected by Hyprland's native Lua config ("non-legacy parsers") — do not use it. Both `hypr-vars.lua` and `monitors.lua` take effect through Hyprland's config auto-reload (file watch); `core/Displays.qml` additionally calls `hyprctl reload` after each write for immediacy.

Hyprland details:

- Defaults are parsed from `~/.config/hypr/variables.lua`; values are kept as raw Lua RHS strings, and anything the naive parser can't understand is preserved verbatim on write. Don't replace `parseLua` with a real Lua parser — verbatim passthrough is the point.
- Overrides equal to the `variables.lua` default are **deleted** from the file, not written — keep the override file minimal.

## Adding a setting

- **Shell**: add a row in `pages/ShellPage.qml` bound to the matching `GlobalConfig.<section>.<key>`.
- **Hyprland**: add a `schema` entry in `core/HyprVars.qml` (`key` = `variables.lua` name, `live` = hyprctl keyword path if mappable, `type` = `"int" | "real" | "bool" | "string" | "app"`), then a row in `pages/HyprlandPage.qml` (local `NumRow`/`BoolRow`/`AppRow` components; `AppRow` wraps `ui/AppSelectRow.qml`).
- **Monitor/Display**: specs stream live from `Quickshell.Hyprland` (`Hyprland.monitors` + `lastIpcObject` — no polling); controls live in `pages/DisplaysPage.qml`, setters/persistence in `core/Displays.qml`. Only overridden fields reach `monitors.lua`; unknown hand-edited fields there are preserved verbatim.
- **Keybind**: add a `bindsSchema` entry in `core/HyprVars.qml` (`key` = `kb*` variable in `variables.lua`, `label`, `section`; `prefix: true` for the modifier-only prefixes keybinds.lua combines with 0–9). The Keybinds page (`pages/KeybindsPage.qml`) renders sections from the schema — no per-row wiring. Qt key → keysym mapping lives in `pages/KeyNames.js`. Binds have no `hyprctl keyword` mapping; every commit calls `hyprctl reload`.

Keybinds page gotchas:

- **Capture only sees free combos.** Hyprland consumes combos that already have a bind before they reach any client, so capturing a currently-bound combo fires the old action and the app sees nothing. The page flags conflicting chips (from schema binds plus `KeyNames.builtinBinds` for the hardcoded ones) instead of pretending capture works.
- **Never rewrite values `parseBind` flags `verbatim`** (concatenated expressions etc.) — the page renders them read-only so `setBind` can't silently drop parts of them.
- **Don't access a JS array's `.keys` field** — `Array.prototype.keys` is a function in QML's V4 engine; `parseBind`'s array field is named `binds` for that reason.

## Known quirks

- `qmllint` on PATH is Qt5's and silently exits 255 on any file containing `pragma ComponentBehavior: Bound` without checking anything — use `/usr/lib/qt6/bin/qmllint` (its only complaints are environmental `qs.*` import resolution outside the Quickshell runtime). QML `console.*` output goes to the per-instance `~/.local/state/quickshell` log, not stderr, unless `QT_FORCE_STDERR_LOGGING=1`.
- **Quickshell 0.3.2's `Process` has no usable `exited` signal** and `qs ipc` prints "Target not found." with exit **0** — never branch on exit codes or `onExited`. Use `StdioCollector.onStreamFinished` and decide on output content, like the single-instance guard in `ui/MainWindow.qml`.
- **Single-instance guard** (same file): every instance registers IPC target `settings` with a `ping()` returning its PID; `qs ipc call` targets the *oldest* instance, so a probing duplicate gets either a peer's PID (→ `show()` the peer, quit unmapped — `visible: sole` means `onVisibleChanged` never fires and no state is flushed) or its own PID (→ it's the oldest; re-check `qs list -j`). A peer that stays listed but never answers after ~2s of retries → quit anyway: two writers clobber `hypr-vars.lua`/`monitors.lua`/`shell.json` with stale in-memory state, and a wedged peer is treated as live. Note IPC return values arrive as plain stdout text (`ping` → PID, possibly with trailing newline).

- `ui/AppSelectRow.qml` exists because the upstream `SelectRow` menu stops repainting inside this app's `FloatingWindow` (Qt layering bug). Don't swap it back for the upstream control.
- **Gating the dropdown overlay uses `visible`, not `enabled`**: child MouseAreas of a disabled MouseArea still receive clicks in this Quickshell build — `enabled` alone left the collapsed panel at (0,0) live as a click target over the sidebar.
- `core/Schemes.qml` hardcodes the installed schemes dir (`/usr/lib/python3.14/site-packages/caelestia/data/schemes`) — bump it when the Caelestia/Python package version changes.
- A monitor rule that omits `scale` inherits Hyprland's **auto** scale (2 on this panel at native res), not the dots' scale = 1 — `writeOverrides` always pins scale explicitly.
- Quickshell `FileView` loads asynchronously: `text()` returns `""` at `Component.onCompleted` unless the view sets `blockLoading: true`. Every startup read in `core/` needs that flag — `Displays.qml`'s missing flag made its bootstrap write wipe `monitors.lua` (and rewrite `hypr-user.lua`) on every launch, silently resetting settings like display scale.

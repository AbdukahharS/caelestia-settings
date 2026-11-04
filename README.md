# caelestia-settings

A unified settings app for a Caelestia + Hyprland system, built as a standalone
Quickshell app that reuses Caelestia's own QML components — same fonts, colours
(M3 palette), corner radii, animations, and it follows scheme changes live.

Currently manages:

- **Style** — Caelestia colour schemes plus the wallpaper-derived dynamic scheme (swatch previews, apply, light/dark)
- **Shell** — bar, launcher, sidebar and service settings (writes `~/.config/caelestia/shell.json` via `GlobalConfig`, the same API the shell itself uses)
- **Hyprland** — gaps, rounding, blur, shadow, input, default apps (writes the Caelestia override layer `~/.config/caelestia/hypr-vars.lua`, applies instantly via `hyprctl keyword`)

## Update safety

The app **never writes files owned by the dots**. It only touches the sanctioned
override layers designed for user customisation:

| Setting | Written to | Applied |
|---|---|---|
| Colour scheme | (via `caelestia scheme` CLI) | instantly, shell + app follow |
| Shell settings | `~/.config/caelestia/shell.json` | instantly (shell hot-reloads config) |
| Hyprland settings | `~/.config/caelestia/hypr-vars.lua` | `hyprctl keyword` where mapped + `hyprctl reload` |

`caelestia update` merges these override files, so upgrades can't conflict.
If a Caelestia/Quickshell update changes component APIs, only this app's glue
code may need a touch-up — the app vendors nothing; it symlinks the installed
shell.

## Run

```sh
qs -p ~/Projects/shzd/caelestia-settings
```

### Recommended: bind it to a key

Add to `~/.config/caelestia/hypr-user.lua` (survives updates):

```lua
-- Settings app
hl.bind(
    "CTRL + SUPER + S",
    hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/Projects/shzd/caelestia-settings")
)
```

### App launcher

Registered system-wide as **"Caelestia Settings"** via
`~/.local/share/applications/caelestia-settings.desktop` — find it in fuzzel,
the Caelestia launcher, or any XDG launcher (icon: Caelestia logo). Recreate it
there if you move the project; `Exec` uses absolute paths so it works from any
launcher environment.

## Development setup

```sh
git clone git@github.com:AbdukahharS/caelestia-settings.git
cd caelestia-settings
scripts/setup-symlinks.sh   # recreate the QML symlinks into /etc/xdg/quickshell/caelestia
qs -p .
```

The symlinks are machine-specific and git-ignored by design; the setup script
also doubles as the fix-it step if a Caelestia package update moves paths.

## Layout

```
shell.qml        entry point (loads fonts + main window)
ui/              window + nav rail
pages/           one file per settings domain
core/            logic singletons
  Schemes.qml      scheme discovery/apply (wraps `caelestia scheme`)
  HyprVars.qml     Hyprland variable read/override/live-apply
components, services, utils, modules, assets -> symlinks into
                 /etc/xdg/quickshell/caelestia (recreated automatically on
                 shell updates; only break if package paths move)
```

### Adding a setting

- **Shell setting**: add a row in `pages/ShellPage.qml` bound to the matching
  `GlobalConfig.<section>.<key>` — reading and persistence are automatic.
- **Hyprland setting**: add an entry to `schema` in `core/HyprVars.qml`
  (`key` = name in `variables.lua`, `live` = hyprctl keyword if mappable),
  then drop a `NumRow`/`BoolRow`/`StrRow` into `pages/HyprlandPage.qml`.

Values equal to the `variables.lua` defaults are *removed* from
`hypr-vars.lua` rather than written, keeping the override file minimal.

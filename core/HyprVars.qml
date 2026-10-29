pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Manages Hyprland settings through Caelestia's sanctioned override layer.
///
/// Defaults live in ~/.config/hypr/variables.lua; overrides live in
/// ~/.config/caelestia/hypr-vars.lua (merged at Hyprland startup by
/// hyprland.lua). This singleton only ever writes the override file, so
/// `caelestia update` can never conflict with the app.
///
/// Values are stored as their raw Lua right-hand-side strings (e.g. `"foot"`,
/// `true`, `15`). Simple values are parsed for editing; anything the parser
/// cannot understand (arrays, concatenated expressions) is preserved verbatim
/// on write.
Singleton {
    id: root

    readonly property string defaultsFile: `${Quickshell.env("HOME")}/.config/hypr/variables.lua`
    readonly property string overridesFile: `${Quickshell.env("HOME")}/.config/caelestia/hypr-vars.lua`

    property var defaults: ({})
    property var overrides: ({})

    /// Curated settings exposed in the Hyprland page.
    ///   key    — variables.lua entry name
    ///   label  — display name
    ///   type   — "int" | "real" | "bool" | "string"
    ///   live   — hyprctl keyword for instant apply, omitted if not mappable
    ///   from/to/step — bounds for numeric entries
    readonly property var schema: [
        // Gaps & corners
        {
            "key": "windowGapsIn",
            "label": "Inner gaps",
            "type": "int",
            "live": "general:gaps_in",
            "from": 0,
            "to": 40
        },
        {
            "key": "windowGapsOut",
            "label": "Outer gaps",
            "type": "int",
            "live": "general:gaps_out",
            "from": 0,
            "to": 60
        },
        {
            "key": "workspaceGaps",
            "label": "Workspace gaps",
            "type": "int",
            "live": "general:gaps_workspaces",
            "from": 0,
            "to": 80
        },
        {
            "key": "windowRounding",
            "label": "Corner rounding",
            "type": "int",
            "live": "decoration:rounding",
            "from": 0,
            "to": 30
        },

        // Blur
        {
            "key": "blurEnabled",
            "label": "Blur",
            "type": "bool",
            "live": "decoration:blur:enabled"
        },
        {
            "key": "blurSize",
            "label": "Blur size",
            "type": "int",
            "live": "decoration:blur:size",
            "from": 1,
            "to": 40
        },
        {
            "key": "blurPasses",
            "label": "Blur passes",
            "type": "int",
            "live": "decoration:blur:passes",
            "from": 1,
            "to": 8
        },
        {
            "key": "blurXray",
            "label": "Blur x-ray",
            "type": "bool",
            "live": "decoration:blur:xray"
        },

        // Shadow
        {
            "key": "shadowEnabled",
            "label": "Shadow",
            "type": "bool",
            "live": "decoration:shadow:enabled"
        },
        {
            "key": "shadowRange",
            "label": "Shadow range",
            "type": "int",
            "live": "decoration:shadow:range",
            "from": 0,
            "to": 60
        },

        // Input
        {
            "key": "touchpadScrollFactor",
            "label": "Touchpad scroll speed",
            "type": "real",
            "live": "input:scroll_factor",
            "from": 0.1,
            "to": 2,
            "step": 0.1
        },
        {
            "key": "cursorSize",
            "label": "Cursor size",
            "type": "int",
            "live": "cursor:size",
            "from": 16,
            "to": 48
        },

        // Apps (require a Hyprland reload)
        {
            "key": "terminal",
            "label": "Terminal",
            "type": "app",
            "categories": ["TerminalEmulator"]
        },
        {
            "key": "browser",
            "label": "Browser",
            "type": "app",
            "categories": ["WebBrowser"]
        },
        {
            "key": "editor",
            "label": "Editor",
            "type": "app",
            "categories": ["TextEditor", "IDE"]
        },
        {
            "key": "fileExplorer",
            "label": "File explorer",
            "type": "app",
            "categories": ["FileManager"]
        }
    ]

    signal valuesChanged()

    function entry(key: string): var {
        return schema.find(s => s.key === key) ?? null;
    }

    /// Installed applications matching a schema entry's categories, as
    /// [{ name, command }]. The currently set value is always included as an
    /// option (marked custom when it isn't an installed app), so values like
    /// "codium" (no .desktop file) never disappear from the UI.
    function appChoices(entry: var): var {
        const cats = entry.categories ?? [];
        const out = [];
        const seen = {};

        for (const e of DesktopEntries.applications.values) {
            const argv = e.command;
            if (e.noDisplay || !argv || !argv.length)
                continue;
            const ec = e.categories ?? [];
            if (!cats.some(c => ec.includes(c)))
                continue;
            const cmd = argv.join(" ");
            if (seen[cmd])
                continue;
            seen[cmd] = true;
            out.push({
                "name": e.name,
                "command": cmd
            });
        }

        out.sort((a, b) => a.name.localeCompare(b.name));

        const current = typed(entry);
        if (current && !out.some(o => o.command === current))
            out.unshift({
                "name": `${current} (custom)`,
                "command": current
            });

        return out;
    }

    /// Current value as raw Lua RHS text (override wins over default).
    function value(key: string): string {
        const o = overrides[key];
        if (o !== undefined)
            return o;
        return defaults[key] ?? "";
    }

    function isOverridden(key: string): bool {
        return overrides[key] !== undefined;
    }

    /// Current value coerced to the entry's type for editor widgets.
    function typed(entry: var): var {
        const raw = value(entry.key);
        if (entry.type === "bool")
            return raw === "true";
        if (entry.type === "int")
            return parseInt(raw) || 0;
        if (entry.type === "real")
            return parseFloat(raw) || 0;
        return raw.replace(/^"|"$/g, "");
    }

    /// Sets an entry, persists the override file and (if mappable) applies it
    /// to the running Hyprland session instantly.
    function set(entry: var, v: var): void {
        const raw = rawOf(entry, v);
        const next = Object.assign({}, overrides);

        if (raw === defaults[entry.key])
            delete next[entry.key]; // matches default → no override needed
        else
            next[entry.key] = raw;

        overrides = next;
        writeOverrides();
        valuesChanged();

        if (entry.live) {
            liveProc.command = ["hyprctl", "keyword", entry.live, raw];
            liveProc.running = true;
        }
    }

    /// Resets an entry back to the variables.lua default (and live value if
    /// mappable).
    function reset(entry: var): void {
        const d = defaults[entry.key];
        if (d === undefined || !isOverridden(entry.key))
            return;

        const next = Object.assign({}, overrides);
        delete next[entry.key];
        overrides = next;
        writeOverrides();
        valuesChanged();

        if (entry.live) {
            // Re-derive the default value for the live keyword
            const t = entry.type;
            const v = t === "bool" ? (d === "true" ? "true" : "false") : t === "string" ? d : d;
            liveProc.command = ["hyprctl", "keyword", entry.live, v];
            liveProc.running = true;
        }
    }

    function rawOf(entry: var, v: var): string {
        if (entry.type === "bool")
            return v ? "true" : "false";
        if (entry.type === "string" || entry.type === "app") {
            const s = `${v}`.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
            return `"${s}"`;
        }
        return `${v}`;
    }

    function reloadHypr(): void {
        reloadProc.running = true;
    }

    function writeOverrides(): void {
        const keys = Object.keys(overrides).sort();
        let text = "-- Managed by caelestia-settings.\n";
        text += "-- These values are merged over ~/.config/hypr/variables.lua at Hyprland startup.\n";
        text += "return {\n";
        for (const k of keys)
            text += `    ${k} = ${overrides[k]},\n`;
        text += "}\n";
        storage.setText(text);
    }

    /// Parses simple `key = value` entries from a Lua table file. Values are
    /// kept as raw text; complex expressions survive a write untouched.
    function parseLua(text: string): var {
        const result = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*=[ \t](.+?),?[ \t]*$/);
            if (m)
                result[m[1]] = m[2];
        }
        return result;
    }

    Process {
        id: liveProc
    }

    Process {
        id: reloadProc

        command: ["hyprctl", "reload"]
    }

    FileView {
        id: storage

        path: root.overridesFile
        atomicWrites: true
        watchChanges: true
        onLoaded: root.overrides = root.parseLua(text())
        onFileChanged: root.overrides = root.parseLua(text())
    }

    FileView {
        id: defaultsView

        path: root.defaultsFile
        watchChanges: true
        onLoaded: root.defaults = root.parseLua(text())
        onFileChanged: root.defaults = root.parseLua(text())
    }

    Component.onCompleted: {
        root.defaults = root.parseLua(defaultsView.text());
        root.overrides = root.parseLua(storage.text());
    }
}

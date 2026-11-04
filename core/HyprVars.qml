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

    /// Curated keybinds exposed in the Keybinds page.
    ///
    /// Keybinds are plain `kb*` variables consumed by
    /// ~/.config/hypr/hyprland/keybinds.lua, so they ride the same override
    /// layer as every other Hyprland variable here. Values are one quoted
    /// string or an array of quoted strings ({ "A", "B" }); there is no
    /// `live` keyword for binds — changes apply via `hyprctl reload`.
    ///   key     — variables.lua entry name
    ///   label   — action description
    ///   section — display group on the page (contiguous, in order)
    ///   prefix  — modifier combined with 0-9 by keybinds.lua; single string
    ///   hint    — shown in place of "Default: …" when not overridden
    readonly property var bindsSchema: [
        // Prefixes (combined with number keys 1-0 by keybinds.lua)
        {
            "key": "kbGoToWs",
            "label": "Workspace focus modifier",
            "section": "Prefixes",
            "prefix": true,
            "hint": "Combined with number keys 1–0"
        },
        {
            "key": "kbGoToWsGroup",
            "label": "Workspace group focus modifier",
            "section": "Prefixes",
            "prefix": true,
            "hint": "Combined with number keys 1–0"
        },
        {
            "key": "kbMoveWinToWs",
            "label": "Move to workspace modifier",
            "section": "Prefixes",
            "prefix": true,
            "hint": "Combined with number keys 1–0"
        },
        {
            "key": "kbMoveWinToWsSilent",
            "label": "Silent move modifier",
            "section": "Prefixes",
            "prefix": true,
            "hint": "Combined with number keys 1–0"
        },
        {
            "key": "kbMoveWinToWsGroup",
            "label": "Move to workspace group modifier",
            "section": "Prefixes",
            "prefix": true,
            "hint": "Combined with number keys 1–0"
        },

        // Workspaces
        { "key": "kbMoveWinToWsSpecial", "label": "Move window to special workspace", "section": "Workspaces" },
        { "key": "kbMoveWinFromWsSpecial", "label": "Move window from special workspace", "section": "Workspaces" },
        { "key": "kbMoveWinToWsNext", "label": "Move window to next workspace", "section": "Workspaces" },
        { "key": "kbMoveWinToWsPrev", "label": "Move window to previous workspace", "section": "Workspaces" },
        { "key": "kbNextWs", "label": "Next workspace", "section": "Workspaces" },
        { "key": "kbPrevWs", "label": "Previous workspace", "section": "Workspaces" },
        { "key": "kbNextWsGroup", "label": "Next workspace group", "section": "Workspaces" },
        { "key": "kbPrevWsGroup", "label": "Previous workspace group", "section": "Workspaces" },

        // Window groups
        { "key": "kbWindowCycleNext", "label": "Cycle to next window", "section": "Window groups" },
        { "key": "kbWindowCyclePrev", "label": "Cycle to previous window", "section": "Window groups" },
        { "key": "kbWindowGroupCycleNext", "label": "Cycle to next window group", "section": "Window groups" },
        { "key": "kbWindowGroupCyclePrev", "label": "Cycle to previous window group", "section": "Window groups" },
        { "key": "kbUngroup", "label": "Remove window from group", "section": "Window groups" },
        { "key": "kbToggleGroup", "label": "Toggle window group", "section": "Window groups" },
        { "key": "kbGroupLockActive", "label": "Lock active group", "section": "Window groups" },

        // Window actions
        { "key": "kbWindowDecreaseWidth", "label": "Decrease window width", "section": "Window actions" },
        { "key": "kbWindowIncreaseWidth", "label": "Increase window width", "section": "Window actions" },
        { "key": "kbWindowDecreaseHeight", "label": "Decrease window height", "section": "Window actions" },
        { "key": "kbWindowIncreaseHeight", "label": "Increase window height", "section": "Window actions" },
        { "key": "kbMoveWindow", "label": "Move window (drag)", "section": "Window actions" },
        { "key": "kbResizeWindow", "label": "Resize window (drag)", "section": "Window actions" },
        { "key": "kbCenterWindow", "label": "Center window", "section": "Window actions" },
        { "key": "kbNormalizeWindow", "label": "Normalize window size", "section": "Window actions" },
        { "key": "kbWindowPip", "label": "Picture-in-picture", "section": "Window actions" },
        { "key": "kbPinWindow", "label": "Pin window", "section": "Window actions" },
        { "key": "kbWindowFullscreen", "label": "Fullscreen", "section": "Window actions" },
        { "key": "kbWindowBorderedFullscreen", "label": "Bordered fullscreen (maximize)", "section": "Window actions" },
        { "key": "kbToggleWindowFloating", "label": "Toggle floating", "section": "Window actions" },
        { "key": "kbCloseWindow", "label": "Close window", "section": "Window actions" },

        // Special workspaces
        { "key": "kbSpecialWs", "label": "Toggle special workspace", "section": "Special workspaces" },
        { "key": "kbSystemMonitorWs", "label": "Toggle system monitor workspace", "section": "Special workspaces" },
        { "key": "kbMusicWs", "label": "Toggle music workspace", "section": "Special workspaces" },
        { "key": "kbCommunicationWs", "label": "Toggle communication workspace", "section": "Special workspaces" },
        { "key": "kbTodoWs", "label": "Toggle todo workspace", "section": "Special workspaces" },

        // Apps
        { "key": "kbTerminal", "label": "Terminal", "section": "Apps" },
        { "key": "kbBrowser", "label": "Browser", "section": "Apps" },
        { "key": "kbEditor", "label": "Editor", "section": "Apps" },
        { "key": "kbFileExplorer", "label": "File explorer", "section": "Apps" },
        { "key": "kbAudioSettings", "label": "Audio settings", "section": "Apps" },

        // Utilities
        { "key": "kbScreenshot", "label": "Screenshot (fullscreen)", "section": "Utilities" },
        { "key": "kbScreenshotFreeze", "label": "Screenshot (frozen)", "section": "Utilities" },
        { "key": "kbScreenshotRegion", "label": "Screenshot (region)", "section": "Utilities" },
        { "key": "kbRecord", "label": "Record screen", "section": "Utilities" },
        { "key": "kbRecordSound", "label": "Record screen with sound", "section": "Utilities" },
        { "key": "kbRecordRegion", "label": "Record screen region", "section": "Utilities" },
        { "key": "kbColorPicker", "label": "Color picker", "section": "Utilities" },

        // Media
        { "key": "kbMediaToggle", "label": "Play / pause media", "section": "Media" },
        { "key": "kbMediaNext", "label": "Next track", "section": "Media" },
        { "key": "kbMediaPrev", "label": "Previous track", "section": "Media" },
        { "key": "kbMediaStop", "label": "Stop media", "section": "Media" },
        { "key": "kbVolumeMute", "label": "Mute output", "section": "Media" },

        // Misc
        { "key": "kbLauncher", "label": "Launcher", "section": "Misc" },
        { "key": "kbSession", "label": "Session menu", "section": "Misc" },
        { "key": "kbShowSidebar", "label": "Show sidebar", "section": "Misc" },
        { "key": "kbClearNotifs", "label": "Clear notifications", "section": "Misc" },
        { "key": "kbShowPanels", "label": "Show all panels", "section": "Misc" },
        { "key": "kbLock", "label": "Lock session", "section": "Misc" },
        { "key": "kbRestoreLock", "label": "Restore lock screen", "section": "Misc" },
        { "key": "kbSleep", "label": "Sleep", "section": "Misc" },

        // Clipboard & emoji
        { "key": "kbClipboard", "label": "Clipboard history", "section": "Clipboard & emoji" },
        { "key": "kbClipboardDel", "label": "Delete clipboard history", "section": "Clipboard & emoji" },
        { "key": "kbClipboardPasteLatest", "label": "Paste latest clipboard item", "section": "Clipboard & emoji" },
        { "key": "kbEmoji", "label": "Emoji picker", "section": "Clipboard & emoji" }
    ]

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

    // ------------------------------------------------------------------
    // Keybinds (see bindsSchema above)
    // ------------------------------------------------------------------

    function bindEntry(key: string): var {
        return bindsSchema.find(s => s.key === key) ?? null;
    }

    function unescapeLua(s: string): string {
        return s.replace(/\\["\\]/g, ch => ch[1]);
    }

    /// Parses a raw Lua right-hand side into { keys: string[], verbatim: bool }.
    /// `verbatim` marks values this simple parser must not rewrite (e.g.
    /// concatenated expressions) — the page shows them read-only so a write
    /// can never drop part of them.
    function parseBind(raw: string): var {
        const s = `${raw ?? ""}`.trim();

        // Single quoted string
        let m = s.match(/^"((?:[^"\\]|\\.)*)"$/);
        if (m)
            return { "binds": m[1] === "" ? [] : [unescapeLua(m[1])], "verbatim": false };

        // Lua array table: { "A", "B" }
        m = s.match(/^\{(.*)\}$/);
        if (m) {
            const inner = m[1];
            const binds = [];
            const re = /"((?:[^"\\]|\\.)*)"/g;
            let mm;
            while ((mm = re.exec(inner)) !== null)
                binds.push(unescapeLua(mm[1]));
            // Only rewrite when the table is exactly a list of strings —
            // anything else (expressions, trailing entries) stays verbatim.
            const leftover = inner.replace(/"(?:[^"\\]|\\.)*"/g, "").replace(/[\s,]/g, "");
            if (binds.length > 0 && leftover === "")
                return { "binds": binds, "verbatim": false };
            return { "binds": binds, "verbatim": true };
        }

        return { "binds": [], "verbatim": true };
    }

    /// Raw Lua RHS for a list of bind strings: one key stays a bare string,
    /// several become an array table, none becomes "" (action disabled).
    function formatBind(keys: var): string {
        const q = k => `"${`${k}`.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
        if (!keys || keys.length === 0)
            return `""`;
        if (keys.length === 1)
            return q(keys[0]);
        return `{ ${keys.map(q).join(", ")} }`;
    }

    /// Canonicalises a bind string for display/writing: trims tokens, drops
    /// stray commas, de-dupes and orders modifiers SUPER > CTRL > ALT > SHIFT.
    /// Returns "" when no actual key remains (modifiers only).
    function normaliseBind(s: string): string {
        const order = ["SUPER", "CTRL", "ALT", "SHIFT"];
        const mods = [];
        let key = "";
        for (let token of `${s}`.split("+")) {
            token = token.trim().replace(/,+$/, "");
            if (token === "")
                continue;
            const u = token.toUpperCase();
            if (order.includes(u)) {
                if (!mods.includes(u))
                    mods.push(u);
            } else if (key === "") {
                key = token;
            } else {
                key += " + " + token; // unexpected extra keys: keep them
            }
        }
        if (key === "")
            return "";
        mods.sort((a, b) => order.indexOf(a) - order.indexOf(b));
        if (/^[a-z]$/.test(key))
            key = key.toUpperCase();
        // hyprctl binds shows mouse tokens stored lowercase (mouse_down);
        // keep the written form canonical too.
        if (/^mouse/i.test(key))
            key = key.toLowerCase();
        return mods.concat([key]).join(" + ");
    }

    /// Comparison token for a bind: mods and key sorted, lowercased, spaces
    /// stripped — so "SUPER + T" and "T + super" are the same bind.
    function bindToken(bind: string): string {
        return `${bind}`.split("+").map(t => t.trim().toLowerCase()).filter(t => t !== "").sort().join("+");
    }

    /// True when `raw` describes the same key set as the variables.lua
    /// default, ignoring quote style and spacing. Values parseBind flags
    /// verbatim are never considered equal — a rewrite would drop parts.
    function bindMatchesDefault(raw: string, key: string): bool {
        const d = defaults[key];
        if (d === undefined)
            return false;
        const dp = parseBind(d);
        const np = parseBind(raw);
        if (dp.verbatim || np.verbatim)
            return false;
        return dp.binds.map(bindToken).sort().join("|") === np.binds.map(bindToken).sort().join("|");
    }

    /// Current binds for a keybind entry as a string list.
    function bindValue(key: string): var {
        return parseBind(value(key)).binds;
    }

    /// Full parse of a keybind entry's current value: { binds, verbatim }.
    function bindParsed(key: string): var {
        return parseBind(value(key));
    }

    /// Sets a bind entry and applies it: writes the override file (dropping
    /// the override when it matches the default) and reloads Hyprland, since
    /// binds have no `hyprctl keyword` mapping.
    function setBind(entry: var, keys: var): void {
        const norm = [];
        for (const k of keys) {
            const n = normaliseBind(`${k}`);
            if (n !== "")
                norm.push(n);
        }

        const raw = formatBind(norm);
        const next = Object.assign({}, overrides);

        if (bindMatchesDefault(raw, entry.key))
            delete next[entry.key]; // matches default → no override needed
        else
            next[entry.key] = raw;

        overrides = next;
        writeOverrides();
        valuesChanged();
        reloadHypr();
    }

    /// Resets a bind entry back to the variables.lua default.
    function resetBind(entry: var): void {
        if (!isOverridden(entry.key))
            return;

        const next = Object.assign({}, overrides);
        delete next[entry.key];
        overrides = next;
        writeOverrides();
        valuesChanged();
        reloadHypr();
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
        // Reads must block until loaded: without this, text() returns "" in
        // Component.onCompleted, and overrides briefly started empty — a
        // setField in that window would clobber existing overrides.
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        onLoaded: root.overrides = root.parseLua(text())
        onFileChanged: root.overrides = root.parseLua(text())
    }

    FileView {
        id: defaultsView

        path: root.defaultsFile
        // Blocked like storage: Component.onCompleted parses this before any
        // async preload can finish.
        blockLoading: true
        watchChanges: true
        onLoaded: root.defaults = root.parseLua(text())
        onFileChanged: root.defaults = root.parseLua(text())
    }

    Component.onCompleted: {
        root.defaults = root.parseLua(defaultsView.text());
        root.overrides = root.parseLua(storage.text());
    }
}

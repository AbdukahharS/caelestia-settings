pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/// Manages monitor/display settings through Caelestia's sanctioned override
/// layer.
///
/// Live state comes from Quickshell's Hyprland IPC (Hyprland.monitors +
/// lastIpcObject) — nothing is polled. Overrides live in
/// ~/.config/caelestia/monitors.lua as `hl.monitor({...})` calls; the file is
/// loaded from hypr-user.lua via `require("monitors")`, which this singleton
/// inserts once if missing. Fields equal to the dots' defaults (mode
/// "preferred", scale 1, vrr off, enabled) are omitted rather than written,
/// and unknown fields from hand edits are preserved verbatim, so
/// `caelestia update` can never conflict with the app. Every change is also
/// applied to the running session instantly via `hyprctl keyword monitor`.
Singleton {
    id: root

    readonly property string userConfFile: `${Quickshell.env("HOME")}/.config/caelestia/hypr-user.lua`
    readonly property string overridesFile: `${Quickshell.env("HOME")}/.config/caelestia/monitors.lua`

    /// Scale inherited from hyprland.lua's generic monitor rule when a
    /// monitor has no override (mode "preferred", vrr off, enabled).
    readonly property real defaultScale: 1

    /// name -> { mode?, scale?, vrr?, disabled?, [other]: raw Lua RHS text }
    property var overrides: ({})

    // --- Live state ---

    /// The HyprlandMonitor for a name, or null.
    function monitor(name: string): var {
        return Hyprland.monitors.values.find(m => m.name === name) ?? null;
    }

    /// Full `hyprctl -j monitors`-shaped data (availableModes, refreshRate,
    /// physical size, serial, ...) for a monitor.
    function ipcFor(name: string): var {
        return monitor(name)?.lastIpcObject ?? {};
    }

    /// Mode string for a monitor's current IPC state.
    function liveMode(ipc: var): string {
        if (!ipc.width)
            return "preferred";
        const rate = Number(ipc.refreshRate ?? 0);
        return rate > 0 ? `${ipc.width}x${ipc.height}@${rate.toFixed(2)}Hz` : `${ipc.width}x${ipc.height}`;
    }

    // --- Effective values (override wins over live state) ---

    /// e.g. "2560x1600@165.00Hz", "preferred".
    function effectiveMode(name: string): string {
        const raw = overrides[name]?.mode;
        if (raw !== undefined)
            return unquote(raw);
        return liveMode(ipcFor(name));
    }

    function effectiveResolution(name: string): string {
        return resOf(effectiveMode(name));
    }

    function effectiveScale(name: string): real {
        const raw = overrides[name]?.scale;
        const v = raw !== undefined ? parseFloat(raw) : NaN;
        return !isNaN(v) ? v : (ipcFor(name).scale ?? defaultScale);
    }

    function effectiveVrr(name: string): bool {
        const raw = overrides[name]?.vrr;
        if (raw !== undefined) {
            const v = parseInt(raw);
            return isNaN(v) ? raw === "true" : v > 0;
        }
        return !!ipcFor(name).vrr;
    }

    function isEnabled(name: string): bool {
        const raw = overrides[name]?.disabled;
        const disabled = raw !== undefined ? raw === "true" : !!ipcFor(name).disabled;
        return !disabled;
    }

    function isOverridden(name: string, field: string): bool {
        return overrides[name]?.[field] !== undefined;
    }

    // --- Choices for the pickers ---

    /// [{ name, value }] resolutions from availableModes (plus the current
    /// one), largest first, with the "preferred" default first.
    function resolutionChoices(name: string): var {
        const ipc = ipcFor(name);
        const cur = effectiveMode(name);
        const curRes = resOf(cur === "preferred" ? liveMode(ipc) : cur);

        const reses = [];
        const seen = {};
        for (const mode of (ipc.availableModes ?? []).concat(curRes ? [curRes] : [])) {
            const res = resOf(mode);
            if (res && !seen[res]) {
                seen[res] = true;
                reses.push(res);
            }
        }
        reses.sort((a, b) => pixelCount(b) - pixelCount(a));

        const out = [{
            "name": "Preferred (default)",
            "value": "preferred"
        }];
        for (const res of reses)
            out.push({
                "name": res,
                "value": res
            });
        return out;
    }

    /// [{ name, value }] refresh rates available at the monitor's effective
    /// resolution; the current rate is always included.
    function rateChoices(name: string): var {
        const ipc = ipcFor(name);
        const mode = effectiveMode(name);
        const res = mode === "preferred" ? resOf(liveMode(ipc)) : resOf(mode);
        const cur = mode === "preferred" ? rateOf(liveMode(ipc)) : rateOf(mode);

        const rates = [];
        const seen = {};
        if (cur) {
            rates.push(cur);
            seen[cur] = true;
        }
        for (const m of ipc.availableModes ?? []) {
            if (resOf(m) !== res)
                continue;
            const r = rateOf(m);
            if (r && !seen[r]) {
                seen[r] = true;
                rates.push(r);
            }
        }
        rates.sort((a, b) => parseFloat(b) - parseFloat(a));
        return rates.map(r => ({
            "name": `${parseFloat(r)} Hz`,
            "value": r
        }));
    }

    /// [{ name, value }] scales Hyprland accepts for the monitor's current
    /// mode: `pixelSize / scale` must be an integer logical size (the check
    /// from Hyprland's Monitor.cpp), enumerated on Hyprland's own 1/120 grid.
    /// Falls back to common steps when the mode is unknown. Labels are
    /// rounded to 2 decimals (e.g. 16/15 shows as 1.07); values are written
    /// at full precision so Hyprland's exact-equality check passes.
    function scaleChoices(name: string): var {
        const ipc = ipcFor(name);
        const cur = effectiveScale(name);

        if (!ipc.width) {
            const steps = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3];
            if (!steps.some(s => Math.abs(s - cur) < 0.001))
                steps.push(cur);
            return steps.sort((a, b) => a - b).map(s => ({
                "name": scaleLabel(s),
                "value": s
            }));
        }

        const out = [];
        const seen = {};
        for (let n = 60; n <= 480; n++) {
            if (ipc.width * 120 % n !== 0 || ipc.height * 120 % n !== 0)
                continue;
            const s = n / 120;
            const key = Math.round(s * 100);
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({
                "name": scaleLabel(s),
                "value": s
            });
        }

        if (!out.some(o => Math.abs(o.value - cur) < 0.001))
            out.push({
                "name": scaleLabel(cur),
                "value": cur
            });
        out.sort((a, b) => a.value - b.value);
        return out;
    }

    function scaleLabel(s: real): string {
        return `${Math.round(s * 100) / 100}`;
    }

    function pixelCount(res: string): int {
        const m = `${res}`.match(/^(\d+)x(\d+)$/);
        return m ? Number(m[1]) * Number(m[2]) : 0;
    }

    function resOf(mode: string): string {
        const s = `${mode}`;
        const i = s.indexOf("@");
        return i > 0 ? s.slice(0, i) : s;
    }

    function rateOf(mode: string): string {
        const s = `${mode}`;
        const i = s.indexOf("@");
        return i > 0 ? s.slice(i + 1) : "";
    }

    function unquote(raw: string): string {
        return `${raw}`.replace(/^"(.*)"$/, "$1");
    }

    function quoteLua(value: string): string {
        const s = `${value}`.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
        return `"${s}"`;
    }

    // --- Setters (persist + live-apply) ---

    function setResolution(name: string, res: string): void {
        if (res === "preferred") {
            // Resetting must actually return to preferred: the generic
            // applyMonitor preserves the current explicit mode. Mutate +
            // persist here and apply once with the forced mode — a second
            // synchronous applyMonitor would be dropped while the first
            // Process is still running.
            mutateField(name, "mode", quoteLua("preferred"), true);
            applyMonitor(name, "preferred");
            return;
        }
        const rate = rateOf(effectiveMode(name));
        setField(name, "mode", quoteLua(rate ? `${res}@${rate}` : res), false);
    }

    function setRate(name: string, rate: string): void {
        setField(name, "mode", quoteLua(`${resOf(effectiveMode(name))}@${rate}`), false);
    }

    function setScale(name: string, scale: real): void {
        setField(name, "scale", `${scale}`, scale === defaultScale);
    }

    function setVrr(name: string, on: bool): void {
        setField(name, "vrr", on ? "1" : "0", !on);
    }

    function setEnabled(name: string, enabled: bool): void {
        // Refuse to disable the last enabled monitor — that blanks the
        // session with no way back except a TTY.
        if (!enabled && Hyprland.monitors.values.filter(m => !m.lastIpcObject.disabled).length <= 1)
            return;
        setField(name, "disabled", enabled ? "false" : "true", enabled);
    }

    /// Stores a field as raw Lua RHS text, drops it when it matches the
    /// inherited default, prunes empty monitor entries, then persists and
    /// live-applies.
    function setField(name: string, field: string, raw: string, isDefault: bool): void {
        mutateField(name, field, raw, isDefault);
        applyMonitor(name);
    }

    /// setField without the live apply — for callers that apply themselves
    /// (e.g. with a forced mode).
    function mutateField(name: string, field: string, raw: string, isDefault: bool): void {
        const next = Object.assign({}, overrides);
        const entry = Object.assign({}, next[name] ?? {});

        if (isDefault)
            delete entry[field];
        else
            entry[field] = raw;

        if (Object.keys(entry).length === 0)
            delete next[name];
        else
            next[name] = entry;

        overrides = next;
        writeOverrides();
    }

    /// Applies a monitor's effective rule to the running session via
    /// `hyprctl keyword monitor`. Non-overridden fields keep their current
    /// live values so unrelated changes never move the monitor; `forcedMode`
    /// (used by the "Preferred (default)" reset) overrides that for mode.
    function applyMonitor(name: string, forcedMode: string): void {
        const ipc = ipcFor(name);
        const entry = overrides[name] ?? {};
        const disabled = entry.disabled !== undefined ? entry.disabled === "true" : !!ipc.disabled;

        if (disabled) {
            liveProc.command = ["hyprctl", "keyword", "monitor", `${name},disable`];
        } else {
            const mode = forcedMode ?? (entry.mode !== undefined ? unquote(entry.mode) : liveMode(ipc));
            const scale = entry.scale !== undefined ? parseFloat(entry.scale) : (ipc.scale ?? defaultScale);
            const parts = [name, mode, `${ipc.x ?? 0}x${ipc.y ?? 0}`, `${scale}`];
            if (effectiveVrr(name))
                parts.push("vrr", "1");
            liveProc.command = ["hyprctl", "keyword", "monitor", parts.join(",")];
        }
        liveProc.running = true;
    }

    // --- Persistence ---

    function writeOverrides(): void {
        const names = Object.keys(overrides).sort();
        const order = ["mode", "scale", "vrr", "disabled"];

        let text = "-- Managed by caelestia-settings.\n";
        text += "-- Loaded from hypr-user.lua via require(\"monitors\") and merged over the\n";
        text += "-- defaults in ~/.config/hypr/hyprland.lua. Fields matching those defaults\n";
        text += "-- are omitted; delete a field to reset it.\n";

        for (const name of names) {
            const entry = overrides[name];
            const keys = Object.keys(entry).sort((a, b) => {
                const ia = order.indexOf(a);
                const ib = order.indexOf(b);
                return (ia === -1 ? order.length : ia) - (ib === -1 ? order.length : ib);
            });

            text += `\nhl.monitor({\n    output = ${quoteLua(name)},\n`;
            for (const key of keys)
                text += `    ${key} = ${entry[key]},\n`;
            text += "})\n";
        }

        storage.setText(text);
    }

    /// Parses `hl.monitor({...})` blocks into raw Lua RHS strings. Values are
    /// kept as raw text; unknown fields (transform, mirror, ...) survive a
    /// write untouched.
    function parseMonitors(text: string): var {
        const result = {};
        const re = /hl\.monitor\s*\{/g;

        let match;
        while ((match = re.exec(text))) {
            let depth = 1;
            let i = re.lastIndex;
            while (i < text.length && depth > 0) {
                const c = text[i];
                if (c === "{")
                    depth++;
                else if (c === "}")
                    depth--;
                i++;
            }

            const entry = {};
            for (const line of text.slice(re.lastIndex, i - 1).split("\n")) {
                const m = line.match(/^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*=[ \t](.+?),?[ \t]*$/);
                if (m)
                    entry[m[1]] = m[2];
            }

            const output = entry.output ? unquote(entry.output) : null;
            if (output) {
                delete entry.output;
                result[output] = entry;
            }
        }

        return result;
    }

    /// Ensures hypr-user.lua requires this file, creating the line once if
    /// missing. Only runs at startup; never rewrites the user's file after.
    function ensureRequired(): void {
        const text = userConf.text();
        if (/require\s*\(?\s*["']monitors["']\s*\)?/.test(text))
            return;

        const block = "# Monitor layout managed by caelestia-settings\nrequire(\"monitors\")\n";
        userConf.setText(text.trim() === "" ? block : text.replace(/\n*$/, "\n") + "\n" + block);
    }

    Process {
        id: liveProc
    }

    FileView {
        id: storage

        path: root.overridesFile
        atomicWrites: true
        watchChanges: true
        onLoaded: root.overrides = root.parseMonitors(text())
        onFileChanged: root.overrides = root.parseMonitors(text())
    }

    FileView {
        id: userConf

        path: root.userConfFile
        watchChanges: false
    }

    Component.onCompleted: {
        root.overrides = root.parseMonitors(storage.text());
        // The file must exist on disk before hypr-user.lua requires it, or
        // Lua's require() errors at config load. An empty rules file is
        // valid. Block on the write so the require line can never land first.
        if (storage.text() === "") {
            root.writeOverrides();
            storage.waitForJob();
        }
        root.ensureRequired();
    }
}

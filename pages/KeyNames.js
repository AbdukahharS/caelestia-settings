// Qt key events -> Hyprland keybind strings.
//
// Hyprland's Lua config binds keys by XKB keysym name ("SUPER + T",
// "Page_Up", "XF86AudioNext"). This library translates the QKeyEvent a
// capture widget receives into that form. Modifier names follow the dots'
// conventions; plain keysym names are capitalised to match variables.lua
// ("Comma", "Backslash", "Page_Up"), which Hyprland resolves
// case-insensitively.
//
// Known limits (inherent to Wayland, not this mapping):
//   - Mouse events ("mouse_down", "mouse:272") never arrive as key events,
//     so those binds are edited as text by the page instead.
//   - Combos already bound by Hyprland are consumed by the compositor and
//     never reach this window; the page surfaces that in its capture hint
//     and conflict warnings.

.pragma library

/// Sentinel returned by combo() when the user pressed Escape.
var CANCEL = "\u0000cancel";

/// Binds hardcoded in hyprland/keybinds.lua (not variable-driven). Used by
/// the settings page only to flag conflicts; they cannot be edited.
var builtinBinds = [
    { "bind": "SUPER + Left", "label": "Focus left" },
    { "bind": "SUPER + Right", "label": "Focus right" },
    { "bind": "SUPER + Up", "label": "Focus up" },
    { "bind": "SUPER + Down", "label": "Focus down" },
    { "bind": "SUPER + SHIFT + Left", "label": "Move window left" },
    { "bind": "SUPER + SHIFT + Right", "label": "Move window right" },
    { "bind": "SUPER + SHIFT + Up", "label": "Move window up" },
    { "bind": "SUPER + SHIFT + Down", "label": "Move window down" },
    { "bind": "CTRL + SUPER + SHIFT + R", "label": "Restart shell" },
    { "bind": "CTRL + SUPER + ALT + R", "label": "Restart shell (re-exec)" },
    { "bind": "SUPER + ALT + F12", "label": "Test notification" },
    { "bind": "SUPER + mouse:272", "label": "Window drag" },
    { "bind": "SUPER + mouse:273", "label": "Window resize" },
    { "bind": "XF86MonBrightnessUp", "label": "Brightness up" },
    { "bind": "XF86MonBrightnessDown", "label": "Brightness down" },
    { "bind": "XF86AudioPlay", "label": "Media play (media keys)" },
    { "bind": "XF86AudioPause", "label": "Media pause (media keys)" },
    { "bind": "XF86AudioNext", "label": "Media next (media keys)" },
    { "bind": "XF86AudioPrev", "label": "Media prev (media keys)" },
    { "bind": "XF86AudioStop", "label": "Media stop (media keys)" },
    { "bind": "XF86AudioMute", "label": "Mute (media keys)" },
    { "bind": "XF86AudioMicMute", "label": "Mute mic (media keys)" },
    { "bind": "XF86AudioRaiseVolume", "label": "Volume up (media keys)" },
    { "bind": "XF86AudioLowerVolume", "label": "Volume down (media keys)" }
]

// Qt.Key -> XKB keysym name, dots' capitalisation style.
var namedKeys = {}
namedKeys[Qt.Key_Tab] = "Tab"
namedKeys[Qt.Key_Backtab] = "ISO_Left_Tab"
namedKeys[Qt.Key_Backspace] = "Backspace"
namedKeys[Qt.Key_Return] = "Return"
namedKeys[Qt.Key_Enter] = "KP_Enter"
namedKeys[Qt.Key_Insert] = "Insert"
namedKeys[Qt.Key_Delete] = "Delete"
namedKeys[Qt.Key_Print] = "Print"
namedKeys[Qt.Key_SysReq] = "Sys_Req"
namedKeys[Qt.Key_Pause] = "Pause"
namedKeys[Qt.Key_Clear] = "Clear"
namedKeys[Qt.Key_Home] = "Home"
namedKeys[Qt.Key_End] = "End"
namedKeys[Qt.Key_Left] = "Left"
namedKeys[Qt.Key_Up] = "Up"
namedKeys[Qt.Key_Right] = "Right"
namedKeys[Qt.Key_Down] = "Down"
namedKeys[Qt.Key_PageUp] = "Page_Up"
namedKeys[Qt.Key_PageDown] = "Page_Down"
namedKeys[Qt.Key_CapsLock] = "Caps_Lock"
namedKeys[Qt.Key_NumLock] = "Num_Lock"
namedKeys[Qt.Key_ScrollLock] = "Scroll_Lock"
namedKeys[Qt.Key_Menu] = "Menu"
namedKeys[Qt.Key_Space] = "Space"

// Punctuation / symbols. Keysym names capitalised like variables.lua.
namedKeys[Qt.Key_Comma] = "Comma"
namedKeys[Qt.Key_Period] = "Period"
namedKeys[Qt.Key_Slash] = "Slash"
namedKeys[Qt.Key_Semicolon] = "Semicolon"
namedKeys[Qt.Key_Apostrophe] = "Apostrophe"
namedKeys[Qt.Key_Minus] = "Minus"
namedKeys[Qt.Key_Equal] = "Equal"
namedKeys[Qt.Key_Backslash] = "Backslash"
namedKeys[Qt.Key_BracketLeft] = "BracketLeft"
namedKeys[Qt.Key_BracketRight] = "BracketRight"
namedKeys[Qt.Key_QuoteLeft] = "Grave"
namedKeys[Qt.Key_AsciiTilde] = "Asciitilde"
namedKeys[Qt.Key_Less] = "Less"
namedKeys[Qt.Key_Greater] = "Greater"
namedKeys[Qt.Key_Bar] = "Bar"
namedKeys[Qt.Key_Exclam] = "Exclam"
namedKeys[Qt.Key_QuoteDbl] = "Quotedbl"
namedKeys[Qt.Key_NumberSign] = "Numbersign"
namedKeys[Qt.Key_Dollar] = "Dollar"
namedKeys[Qt.Key_Percent] = "Percent"
namedKeys[Qt.Key_Ampersand] = "Ampersand"
namedKeys[Qt.Key_ParenLeft] = "Parenleft"
namedKeys[Qt.Key_ParenRight] = "Parenright"
namedKeys[Qt.Key_Asterisk] = "Asterisk"
namedKeys[Qt.Key_Plus] = "Plus"
namedKeys[Qt.Key_Colon] = "Colon"
namedKeys[Qt.Key_Question] = "Question"
namedKeys[Qt.Key_At] = "At"
namedKeys[Qt.Key_Underscore] = "Underscore"
namedKeys[Qt.Key_AsciiCircum] = "Asciicircum"
namedKeys[Qt.Key_BraceLeft] = "Braceleft"
namedKeys[Qt.Key_BraceRight] = "Braceright"

// Media / volume / brightness -> their XF86 keysym names.
namedKeys[Qt.Key_MediaPlay] = "XF86AudioPlay"
namedKeys[Qt.Key_MediaTogglePlayPause] = "XF86AudioPlay"
namedKeys[Qt.Key_MediaPause] = "XF86AudioPause"
namedKeys[Qt.Key_MediaStop] = "XF86AudioStop"
namedKeys[Qt.Key_MediaPrevious] = "XF86AudioPrev"
namedKeys[Qt.Key_MediaNext] = "XF86AudioNext"
namedKeys[Qt.Key_MediaRecord] = "XF86AudioRecord"
namedKeys[Qt.Key_AudioRewind] = "XF86AudioRewind"
namedKeys[Qt.Key_AudioForward] = "XF86AudioForward"
namedKeys[Qt.Key_VolumeUp] = "XF86AudioRaiseVolume"
namedKeys[Qt.Key_VolumeDown] = "XF86AudioLowerVolume"
namedKeys[Qt.Key_VolumeMute] = "XF86AudioMute"
namedKeys[Qt.Key_MicMute] = "XF86AudioMicMute"
namedKeys[Qt.Key_MonBrightnessUp] = "XF86MonBrightnessUp"
namedKeys[Qt.Key_MonBrightnessDown] = "XF86MonBrightnessDown"

// Modifier keys that arrive as regular key events. Pressing only SUPER is
// bindable and matches the dots' launcher convention ("SUPER + SUPER_L");
// the other lone modifiers are ignored and wait for a real key. Qt has no
// Shift_L/Control_L/Alt_L key constants — the generic ones carry the events.
var modifierKeys = {}
modifierKeys[Qt.Key_Super_L] = "SUPER_L"
modifierKeys[Qt.Key_Super_R] = "SUPER_R"
modifierKeys[Qt.Key_Shift] = ""
modifierKeys[Qt.Key_Control] = ""
modifierKeys[Qt.Key_Alt] = ""
modifierKeys[Qt.Key_AltGr] = ""
modifierKeys[Qt.Key_Meta] = ""
modifierKeys[Qt.Key_Hyper_L] = ""
modifierKeys[Qt.Key_Hyper_R] = ""

// Qt.KeyboardModifier -> Hyprland mod name.
var modNames = {}
modNames[Qt.MetaModifier] = "SUPER"
modNames[Qt.ControlModifier] = "CTRL"
modNames[Qt.AltModifier] = "ALT"
modNames[Qt.ShiftModifier] = "SHIFT"

/// Canonical modifier display order.
var modOrder = ["SUPER", "CTRL", "ALT", "SHIFT"]

function keysymFor(key, keypad) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z)
        return String.fromCharCode(key);
    if (key >= Qt.Key_0 && key <= Qt.Key_9)
        return keypad ? "KP_" + (key - Qt.Key_0) : `${key - Qt.Key_0}`;
    if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
        return `F${key - Qt.Key_F1 + 1}`;
    return namedKeys[key] ?? "";
}

function modsFor(modifiers) {
    const mods = [];
    for (const m of modOrder) {
        for (const flag in modNames)
            if (modNames[flag] === m && (modifiers & Number(flag)))
                mods.push(m);
    }
    return mods;
}

/// Translates a QKeyEvent into a bind string.
///
/// Returns:
///   - CANCEL when Escape is pressed (capture should abort)
///   - "MOD + MOD + KEY" for a complete combo
///   - "" while only ignorable modifiers are held, or for unknown keys
function combo(event) {
    if (event.key === Qt.Key_Escape)
        return CANCEL;

    // Modifier key events: only SUPER alone is bindable.
    if (event.key in modifierKeys) {
        const superKey = modifierKeys[event.key];
        if (superKey === "")
            return "";
        const mods = modsFor(event.modifiers);
        if (!mods.includes("SUPER"))
            mods.push("SUPER");
        return mods.join(" + ") + " + " + superKey;
    }

    if (event.key === Qt.Key_unknown)
        return "";

    const keysym = keysymFor(event.key, !!(event.modifiers & Qt.KeypadModifier));
    if (keysym === "")
        return "";

    const mods = modsFor(event.modifiers);
    return (mods.length ? mods.join(" + ") + " + " : "") + keysym;
}

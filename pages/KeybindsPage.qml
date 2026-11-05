pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.core
import qs.services
import qs.modules.nexus.common
import qs.ui
import "KeyNames.js" as KeyNames

/// Hyprland keybind editor via Caelestia's override layer (hypr-vars.lua).
///
/// Keybinds are plain `kb*` variables (see HyprVars.bindsSchema), so every
/// action here shows one or more bind chips. Clicking a chip captures the
/// next key combo live and commits it; commits write hypr-vars.lua and run
/// `hyprctl reload` (binds have no keyword mapping).
///
/// Capture limits, both inherent to Wayland:
///   - Hyprland consumes combos that already have a bind before they reach
///     this window, so capturing such a combo fires the old action instead.
///     Conflicting chips are outlined so a free combo can be picked.
///   - Mouse events never arrive as key events; binds containing `mouse`
///     tokens are edited as text instead.
SettingsPage {
    id: root

    // Section names in display order — schema entries are contiguous per
    // section, so adjacent-equal check suffices.
    readonly property var sections: {
        const out = [];
        for (const e of HyprVars.bindsSchema) {
            if (out.length === 0 || out[out.length - 1] !== e.section)
                out.push(e.section);
        }
        return out;
    }

    /// canonical bind token → labels claiming it, from the schema plus the
    /// binds hardcoded in keybinds.lua. Rebuilt whenever overrides change.
    readonly property var conflictIndex: {
        const idx = {};
        const claim = (bind, label) => {
            const t = HyprVars.bindToken(bind);
            if (t === "")
                return;
            (idx[t] = idx[t] ?? []).push(label);
        };
        for (const e of HyprVars.bindsSchema) {
            const parsed = HyprVars.bindParsed(e.key);
            if (parsed.verbatim)
                continue; // fragments of expressions — not real binds
            for (const k of parsed.binds)
                claim(k, e.label);
        }
        for (const b of KeyNames.builtinBinds)
            claim(b.bind, `${b.label} (built-in)`);
        return idx;
    }

    function conflictsFor(bind: string, ownLabel: string): var {
        const claims = conflictIndex[HyprVars.bindToken(bind)] ?? [];
        return claims.filter(l => l !== ownLabel);
    }

    function entriesFor(section: string): var {
        return HyprVars.bindsSchema.filter(e => e.section === section);
    }

    /// One captured key combo as a pill. Click recaptures (or opens a text
    /// field for mouse binds); the close icon removes the bind.
    component BindChip: StyledRect {
        id: chip

        required property int index
        required property string modelData

        property var row

        readonly property bool capturing: row.captureIndex === index
        readonly property bool isMouse: /mouse/i.test(modelData)
        readonly property bool editing: row.editIndex === index
        readonly property bool conflicted: !capturing && root.conflictsFor(modelData, row.ownLabel).length > 0

        radius: implicitHeight / 2 * Math.min(1, Tokens.rounding.scale)
        color: capturing ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh
        border.width: conflicted ? 1 : 0
        border.color: Colours.palette.m3error
        implicitWidth: editing ? chipEdit.width : chipRow.implicitWidth
        implicitHeight: editing ? chipEdit.implicitHeight : chipRow.implicitHeight + Tokens.padding.small * 2

        function remove(): void {
            if (row.verbatim)
                return; // never rewrite values we cannot fully represent
            const keys = row.bindData.binds.slice();
            keys.splice(index, 1);
            HyprVars.setBind(row.modelData, keys);
        }

        onCapturingChanged: {
            if (capturing)
                forceActiveFocus();
        }

        // Losing focus for any reason (clicking elsewhere, page switch)
        // cancels the capture instead of leaving a live grabber around.
        onActiveFocusChanged: {
            if (!activeFocus && capturing)
                row.stopCapture();
        }

        Keys.onPressed: event => {
            event.accepted = true;
            const c = KeyNames.combo(event);
            if (c === KeyNames.CANCEL) {
                row.stopCapture();
                return;
            }
            if (c !== "")
                row.commitCapture(c);
        }

        // Bottom of the z-stack: everything declared after it (the label row
        // and the text editor) renders above it and receives clicks first.
        StateLayer {
            anchors.fill: parent
            topLeftRadius: parent.radius
            topRightRadius: parent.radius
            bottomLeftRadius: parent.radius
            bottomRightRadius: parent.radius
            color: chip.capturing ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            // No capture for verbatim values: committing would rewrite the
            // variable without the parts this parser cannot represent.
            enabled: !row.verbatim
            onClicked: {
                if (chip.capturing)
                    return;
                if (chip.isMouse)
                    row.startEdit(chip.index);
                else
                    row.startCapture(chip.index);
            }
        }

        RowLayout {
            id: chipRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small
            visible: !chip.editing

            StyledText {
                text: chip.capturing ? "Press keys · Esc cancels" : chip.modelData
                color: chip.capturing ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }

            MaterialIcon {
                visible: chip.conflicted
                text: "warning"
                color: Colours.palette.m3error
                fontStyle: Tokens.font.icon.small
            }

            // Mouse binds cannot be captured; the pencil hints that clicking
            // opens a text editor instead.
            MaterialIcon {
                visible: chip.isMouse && !chip.capturing
                text: "edit"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            // Remove affordance; hidden while capturing so the whole pill
            // behaves as one key-grabber, and for verbatim values where any
            // rewrite would drop the un-parseable parts.
            MouseArea {
                visible: !chip.capturing && !row.verbatim
                implicitWidth: removeIcon.implicitWidth
                implicitHeight: removeIcon.implicitHeight
                cursorShape: Qt.PointingHandCursor

                MaterialIcon {
                    id: removeIcon

                    anchors.centerIn: parent
                    text: "close"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                onClicked: chip.remove()
            }
        }

        // Text editor for mouse-containing binds.
        StyledTextField {
            id: chipEdit

            visible: chip.editing
            text: chip.modelData
            verticalPadding: Tokens.padding.extraSmall
            horizontalPadding: Tokens.padding.medium
            implicitWidth: Math.min(280, Math.max(160, contentWidth + horizontalPadding * 2))

            onVisibleChanged: {
                if (visible)
                    forceActiveFocus();
            }

            onAccepted: row.commitEdit(chip.index, text)
            onActiveFocusChanged: {
                if (!activeFocus && visible && chip.editing)
                    row.commitEdit(chip.index, text);
            }
        }
    }

    /// Empty slot appending a new bind (hidden for modifier prefixes and
    /// read-only values, which bind exactly one combo or none).
    component AddChip: StyledRect {
        id: addChip

        property var row

        readonly property int slotIndex: row ? row.bindData.binds.length : 0
        readonly property bool capturing: row.captureIndex === slotIndex

        visible: !row.verbatim && !(row.isPrefix && slotIndex >= 1)

        radius: implicitHeight / 2 * Math.min(1, Tokens.rounding.scale)
        color: capturing ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh
        implicitWidth: addRow.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: addRow.implicitHeight + Tokens.padding.small * 2

        onCapturingChanged: {
            if (capturing)
                forceActiveFocus();
        }

        onActiveFocusChanged: {
            if (!activeFocus && capturing)
                row.stopCapture();
        }

        Keys.onPressed: event => {
            event.accepted = true;
            const c = KeyNames.combo(event);
            if (c === KeyNames.CANCEL) {
                row.stopCapture();
                return;
            }
            if (c !== "")
                row.commitCapture(c);
        }

        RowLayout {
            id: addRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "add"
                color: addChip.capturing ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: addChip.capturing ? "Press keys · Esc cancels" : "Add bind"
                color: addChip.capturing ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }

        StateLayer {
            anchors.fill: parent
            topLeftRadius: parent.radius
            topRightRadius: parent.radius
            bottomLeftRadius: parent.radius
            bottomRightRadius: parent.radius
            color: addChip.capturing ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
            onClicked: addChip.row.startCapture(addChip.slotIndex)
        }
    }

    /// One action row: label block plus its bind chips.
    component KeybindRow: ConnectedRect {
        id: bindRow

        required property int index
        required property var modelData

        readonly property string ownLabel: modelData.label
        readonly property var bindData: HyprVars.bindParsed(modelData.key)
        readonly property bool verbatim: bindData.verbatim
        readonly property bool isPrefix: !!modelData.prefix

        // -1: idle; 0..n-1: recapture chip i; n: capture into a new slot
        property int captureIndex: -1
        property int editIndex: -1

        // The value can change underneath an armed capture (reset button,
        // external hypr-vars.lua edit via watchChanges): drop stale capture
        // and edit slots, otherwise a rebuilt chip inherits a dead grabber.
        onBindDataChanged: {
            captureIndex = -1;
            editIndex = -1;
        }

        function startCapture(i: int): void {
            editIndex = -1;
            captureIndex = i;
        }

        function startEdit(i: int): void {
            captureIndex = -1;
            editIndex = i;
        }

        function stopCapture(): void {
            captureIndex = -1;
        }

        function commitCapture(combo: string): void {
            const keys = bindData.binds.slice();
            if (captureIndex >= keys.length)
                keys.push(combo);
            else
                keys[captureIndex] = combo;
            HyprVars.setBind(modelData, keys);
            stopCapture();
        }

        function commitEdit(i: int, text: string): void {
            editIndex = -1;
            const n = HyprVars.normaliseBind(text);
            if (n === "" || n === bindData.binds[i])
                return; // invalid or unchanged → keep old value
            const keys = bindData.binds.slice();
            keys[i] = n;
            HyprVars.setBind(modelData, keys);
        }

        Layout.fillWidth: true
        implicitHeight: contentRow.implicitHeight + Tokens.padding.medium * 2

        RowLayout {
            id: contentRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: bindRow.ownLabel
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        if (bindRow.verbatim)
                            return "Complex value — shown read-only";
                        if (HyprVars.isOverridden(bindRow.modelData.key))
                            return `Default: ${HyprVars.defaults[bindRow.modelData.key]}`;
                        return bindRow.modelData.hint ?? "";
                    }
                    color: bindRow.verbatim ? Colours.palette.m3error : Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            Flow {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.small

                Repeater {
                    // Verbatim values get no chips: their parsed entries are
                    // fragments of expressions this parser cannot rewrite.
                    model: bindRow.verbatim ? [] : bindRow.bindData.binds

                    BindChip {
                        row: bindRow
                    }
                }

                AddChip {
                    row: bindRow
                }

                // Raw read-only view for values parseBind flags verbatim.
                StyledRect {
                    visible: bindRow.verbatim
                    radius: implicitHeight / 2 * Math.min(1, Tokens.rounding.scale)
                    color: Colours.tPalette.m3surfaceContainerHigh
                    border.width: 1
                    border.color: Colours.palette.m3error
                    implicitWidth: rawText.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: rawText.implicitHeight + Tokens.padding.small * 2

                    StyledText {
                        id: rawText

                        anchors.centerIn: parent
                        text: HyprVars.value(bindRow.modelData.key)
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                    }
                }
            }

            IconButton {
                visible: HyprVars.isOverridden(bindRow.modelData.key)
                icon: "restart_alt"
                onClicked: HyprVars.resetBind(bindRow.modelData)
            }
        }
    }

    title: "Keybinds"

    headerActions: [
        TextButton {
            text: "Reload Hyprland"

            onClicked: HyprVars.reloadHypr()
        }
    ]

    InfoBanner {
        Layout.bottomMargin: Tokens.spacing.largeIncreased
        text: "Click a bind chip to press a new key combination. Combos Hyprland already consumes never reach this window — the old action fires instead, so outlined chips mark conflicts with another action. Binds containing mouse events open a text editor."
    }

    Repeater {
        model: root.sections

        ColumnLayout {
            id: sectionCol

            required property string modelData
            required property int index

            readonly property var entries: root.entriesFor(sectionCol.modelData)

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            SectionHeader {
                first: sectionCol.index === 0
                text: sectionCol.modelData
            }

            Repeater {
                model: sectionCol.entries

                KeybindRow {
                    first: index === 0
                    last: index === sectionCol.entries.length - 1
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.extraLargeIncreased
        text: "Changes write to hypr-vars.lua (values matching variables.lua are removed) and reload Hyprland immediately."
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
        wrapMode: Text.WordWrap
    }
}

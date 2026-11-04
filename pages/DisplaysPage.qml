pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.core
import qs.services
import qs.modules.nexus.common
import qs.ui

/// Monitor/display settings via Caelestia's override layer (monitors.lua).
/// Specs stream live from Hyprland's IPC; changes apply instantly via
/// `hyprctl keyword monitor` and persist for the next reload/startup.
Item {
    id: root

    readonly property real cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)

    /// Dropdown for Displays choice lists, built on AppSelectRow (upstream
    /// SelectRow's menu does not repaint inside this app's FloatingWindow).
    component ChoiceRow: AppSelectRow {
        id: choice

        property string labelText
        property string sub
        property var options: []
        property var selectedValue

        signal picked(string value)

        label: labelText
        subtext: sub
        menuItems: {
            // Depend on options itself, not just items.count: a rebuild with
            // the same count (e.g. picking a scale) must not leave a stale
            // array of destroyed MenuItems (blank chip + blank popover).
            const opts = choice.options;
            const out = [];
            for (let i = 0; i < items.count && i < opts.length; i++) {
                const item = items.objectAt(i);
                if (item)
                    out.push(item);
            }
            return out;
        }
        // Numbers (scale) come back from Hyprland's IPC rounded to 8
        // significant digits (e.g. 1.0666667) while option values are the
        // exact doubles (128/120) — strict equality can never match. 0.001
        // is far below the 1/120 grid spacing scale values live on, matching
        // the tolerance already used in Displays.scaleChoices.
        active: {
            for (let i = 0; i < menuItems.length; i++) {
                const v = menuItems[i].value;
                if (typeof v === "number" && typeof selectedValue === "number") {
                    if (Math.abs(v - selectedValue) < 0.001)
                        return menuItems[i];
                } else if (v === selectedValue) {
                    return menuItems[i];
                }
            }
            return null;
        }
        onSelected: item => choice.picked(item.value)

        Instantiator {
            id: items

            model: choice.options

            MenuItem {
                required property var modelData

                text: modelData.name
                value: modelData.value
            }
        }
    }

    component ScaleRow: ChoiceRow {
        property string monitorName

        labelText: "Scale"
        sub: Displays.isOverridden(monitorName, "scale") ? "Default: 1" : ""
        options: Displays.scaleChoices(monitorName)
        selectedValue: Displays.effectiveScale(monitorName)
        onPicked: value => Displays.setScale(monitorName, value)
    }

    StyledFlickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + Tokens.padding.extraLarge * 2

        ColumnLayout {
            id: column

            x: (root.width - root.cappedWidth) / 2
            y: Tokens.padding.extraLarge
            width: root.cappedWidth
            spacing: Tokens.spacing.extraLargeIncreased

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: "Displays"
                    font: Tokens.font.title.large
                    Layout.fillWidth: true
                }

                TextButton {
                    text: "Reload Hyprland"
                    onClicked: HyprVars.reloadHypr()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: Hyprland.monitors.values.length === 0
                text: "No displays detected."
                color: Colours.palette.m3outline
                font: Tokens.font.label.medium
            }

            Repeater {
                model: Hyprland.monitors

                delegate: ColumnLayout {
                    id: card

                    required property var modelData
                    required property int index

                    readonly property string name: modelData.name
                    readonly property var ipc: modelData.lastIpcObject

                    Layout.fillWidth: true
                    Layout.topMargin: index === 0 ? 0 : Tokens.spacing.extraLargeIncreased
                    spacing: Tokens.spacing.extraLargeIncreased

                    SectionHeader {
                        first: true
                        text: card.name
                    }

                    // Specs (read-only, live from Hyprland's IPC)
                    InfoRow {
                        first: true
                        icon: "monitor"
                        label: "Model"
                        value: card.modelData.description || "Unknown"
                    }

                    InfoRow {
                        label: "Current mode"
                        value: Displays.effectiveMode(card.name)
                    }

                    InfoRow {
                        label: "Physical size"
                        value: card.ipc.physicalWidth ? `${card.ipc.physicalWidth}×${card.ipc.physicalHeight} mm` : "Unknown"
                    }

                    InfoRow {
                        label: "Position"
                        value: `${card.ipc.x ?? 0},${card.ipc.y ?? 0}`
                    }

                    InfoRow {
                        label: "Workspace"
                        value: card.modelData.activeWorkspace ? card.modelData.activeWorkspace.name : "—"
                    }

                    InfoRow {
                        label: "Serial"
                        value: card.ipc.serial || "Unknown"
                    }

                    InfoRow {
                        last: true
                        label: "Pixel format"
                        value: card.ipc.currentFormat || "Unknown"
                    }

                    // Controls
                    ToggleRow {
                        first: true
                        text: "Enabled"
                        subtext: card.ipc.disabled && !Displays.isOverridden(card.name, "disabled") ? "Disabled outside caelestia-settings" : (Displays.isOverridden(card.name, "disabled") ? "Default: enabled" : "")
                        checked: Displays.isEnabled(card.name)
                        onToggled: Displays.setEnabled(card.name, checked)
                    }

                    ChoiceRow {
                        labelText: "Resolution"
                        sub: Displays.isOverridden(card.name, "mode") ? "Default: preferred" : ""
                        options: Displays.resolutionChoices(card.name)
                        selectedValue: Displays.effectiveResolution(card.name)
                        onPicked: value => Displays.setResolution(card.name, value)
                    }

                    ChoiceRow {
                        labelText: "Refresh rate"
                        options: Displays.rateChoices(card.name)
                        selectedValue: Displays.rateOf(Displays.effectiveMode(card.name))
                        onPicked: value => Displays.setRate(card.name, value)
                    }

                    ScaleRow {
                        monitorName: card.name
                    }

                    ToggleRow {
                        last: true
                        text: "Variable refresh rate"
                        subtext: Displays.isOverridden(card.name, "vrr") ? "Default: off" : ""
                        checked: Displays.effectiveVrr(card.name)
                        onToggled: Displays.setVrr(card.name, checked)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: "Changes apply instantly. Values matching the dots' monitor defaults are not written to monitors.lua; deleting a value resets it. Position is left to Hyprland's auto layout."
                color: Colours.palette.m3outline
                font: Tokens.font.label.medium
                wrapMode: Text.WordWrap
            }
        }
    }
}

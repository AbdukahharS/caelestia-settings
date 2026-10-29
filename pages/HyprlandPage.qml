pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.core
import qs.services
import qs.modules.nexus.common
import qs.ui

/// Hyprland settings via Caelestia's override layer (hypr-vars.lua).
/// Changes apply instantly via `hyprctl keyword` where a keyword mapping
/// exists; everything persists for the next reload/startup.
Item {
    id: root

    readonly property real cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)

    component NumRow: StepperRow {
        property var e

        label: e ? e.label : ""
        subtext: e && HyprVars.isOverridden(e.key) ? `Default: ${HyprVars.defaults[e.key]}` : ""
        value: HyprVars.typed(e)
        from: e && e.from !== undefined ? e.from : 0
        to: e && e.to !== undefined ? e.to : 100
        stepSize: e && e.step !== undefined ? e.step : 1
        onMoved: v => HyprVars.set(e, v)
    }

    component PercentRow: StepperRow {
        property var e

        label: e ? e.label : ""
        subtext: e && HyprVars.isOverridden(e.key) ? `Default: ${HyprVars.defaults[e.key]}` : ""
        value: Math.round(HyprVars.typed(e) * 100)
        from: e && e.from !== undefined ? e.from * 100 : 0
        to: e && e.to !== undefined ? e.to * 100 : 100
        stepSize: 5
        onMoved: v => HyprVars.set(e, v / 100)
    }

    component BoolRow: ToggleRow {
        property var e

        text: e ? e.label : ""
        subtext: e && HyprVars.isOverridden(e.key) ? `Default: ${HyprVars.defaults[e.key]}` : ""
        checked: HyprVars.typed(e)
        onToggled: HyprVars.set(e, checked)
    }

    /// App picker: select populated from installed desktop entries filtered
    /// by the schema entry's categories. Values are launch commands, matching
    /// how variables.lua is consumed by the dots.
    component AppRow: AppSelectRow {
        id: appRow

        property var e

        readonly property var choices: {
            const out = [];
            for (let i = 0; i < appsInst.count; i++)
                out.push(appsInst.objectAt(i));
            return out;
        }

        label: e ? e.label : ""
        subtext: e && HyprVars.isOverridden(e.key) ? `Default: ${HyprVars.defaults[e.key]}` : ""
        menuItems: appRow.choices
        active: appRow.choices.find(i => i.value === (e ? HyprVars.typed(e) : "")) ?? null
        onSelected: item => HyprVars.set(e, item.value)

        Instantiator {
            id: appsInst

            model: appRow.e ? HyprVars.appChoices(appRow.e) : []

            MenuItem {
                required property var modelData

                text: modelData.name
                value: modelData.command
            }
        }
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
                    text: "Hyprland"
                    font: Tokens.font.title.large
                    Layout.fillWidth: true
                }

                TextButton {
                    text: "Reload Hyprland"
                    onClicked: HyprVars.reloadHypr()
                }
            }

            // Gaps & corners
            SectionHeader {
                first: true
                text: "Gaps & corners"
            }

            NumRow {
                first: true
                e: HyprVars.entry("windowGapsIn")
            }

            NumRow {
                e: HyprVars.entry("windowGapsOut")
            }

            NumRow {
                e: HyprVars.entry("workspaceGaps")
            }

            NumRow {
                last: true
                e: HyprVars.entry("windowRounding")
            }

            // Blur
            SectionHeader {
                text: "Blur"
            }

            BoolRow {
                first: true
                e: HyprVars.entry("blurEnabled")
            }

            NumRow {
                e: HyprVars.entry("blurSize")
            }

            NumRow {
                e: HyprVars.entry("blurPasses")
            }

            BoolRow {
                last: true
                e: HyprVars.entry("blurXray")
            }

            // Shadow
            SectionHeader {
                text: "Shadow"
            }

            BoolRow {
                first: true
                e: HyprVars.entry("shadowEnabled")
            }

            NumRow {
                last: true
                e: HyprVars.entry("shadowRange")
            }

            // Input
            SectionHeader {
                text: "Input"
            }

            PercentRow {
                first: true
                e: HyprVars.entry("touchpadScrollFactor")
            }

            NumRow {
                last: true
                e: HyprVars.entry("cursorSize")
            }

            // Apps
            SectionHeader {
                text: "Apps"
            }

            AppRow {
                e: HyprVars.entry("terminal")
            }

            AppRow {
                e: HyprVars.entry("browser")
            }

            AppRow {
                e: HyprVars.entry("editor")
            }

            AppRow {
                e: HyprVars.entry("fileExplorer")
            }

            StyledText {
                Layout.fillWidth: true
                text: "App changes take effect on reload. Values matching the defaults in variables.lua are not written to hypr-vars.lua."
                color: Colours.palette.m3outline
                font: Tokens.font.label.medium
                wrapMode: Text.WordWrap
            }
        }
    }
}

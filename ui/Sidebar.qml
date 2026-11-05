pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

/// Full-width navigation pane: branded header above connected-corner nav
/// rows (icon badge + label + description), following the idiom of the
/// shell's own settings app. Rows carry hover/press state layers, a visible
/// focus ring and arrow-key navigation.
Rectangle {
    id: root

    property int current: 0

    readonly property var navModel: [
        {
            "icon": "palette",
            "label": "Style",
            "description": "Colour scheme"
        },
        {
            "icon": "tune",
            "label": "Shell",
            "description": "Bar & services"
        },
        {
            "icon": "window",
            "label": "Hyprland",
            "description": "Gaps, blur, input"
        },
        {
            "icon": "keyboard",
            "label": "Binds",
            "description": "Keybind editor"
        },
        {
            "icon": "monitor",
            "label": "Displays",
            "description": "Monitors & layout"
        }
    ]

    implicitWidth: 350
    color: Colours.tPalette.m3surfaceContainerLow

    // Hairline separation from the content surface.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Colours.palette.m3outlineVariant
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: headerIcon.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: headerIcon.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.palette.m3primary

                MaterialIcon {
                    id: headerIcon

                    anchors.centerIn: parent
                    text: "settings"
                    color: Colours.palette.m3onPrimary
                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                    grade: 25
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: "Settings"
                    font: Tokens.font.title.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Caelestia"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }
        }

        VerticalFadeFlickable {
            id: navFlick

            Layout.fillWidth: true
            Layout.fillHeight: true
            topMargin: Tokens.padding.small
            bottomMargin: Tokens.padding.small
            contentHeight: navColumn.implicitHeight

            TapHandler {
                onTapped: navFlick.focus = true
            }

            ColumnLayout {
                id: navColumn

                // Inset from the sidebar edges so the row pills don't touch
                // the window edge or the divider (clear gap like the
                // shell's nav pane).
                x: Tokens.padding.large
                width: (parent ? parent.width : 0) - Tokens.padding.large * 2
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    id: navRepeater

                    model: root.navModel

                    NavButton {}
                }
            }
        }
    }

    component NavButton: StyledRect {
        id: btn

        required property var modelData
        required property int index

        readonly property bool active: root.current === index
        readonly property bool first: index === 0
        readonly property bool last: index === root.navModel.length - 1

        Layout.fillWidth: true
        // Odd fix keeps the layer pixels aligned (matches the shell's nav).
        implicitHeight: {
            const h = row.implicitHeight + Tokens.padding.large * 2;
            return h % 2 === 0 ? h : h + 1;
        }

        activeFocusOnTab: true

        color: btn.active ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : btn.active ? Tokens.rounding.extraLargeIncreased : btn.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : btn.active ? Tokens.rounding.extraLargeIncreased : btn.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : btn.active ? Tokens.rounding.extraLargeIncreased : btn.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : btn.active ? Tokens.rounding.extraLargeIncreased : btn.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

        RadiusBehavior on topLeftRadius {}
        RadiusBehavior on topRightRadius {}
        RadiusBehavior on bottomLeftRadius {}
        RadiusBehavior on bottomRightRadius {}

        Keys.onUpPressed: if (btn.index > 0)
            navRepeater.itemAt(btn.index - 1).forceActiveFocus()

        Keys.onDownPressed: if (btn.index < root.navModel.length - 1)
            navRepeater.itemAt(btn.index + 1).forceActiveFocus()

        Keys.onReturnPressed: root.current = btn.index
        Keys.onSpacePressed: root.current = btn.index

        StateLayer {
            id: stateLayer

            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius

            onClicked: root.current = btn.index
        }

        // Keyboard focus ring, above the state layer.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: btn.activeFocus ? 2 : 0
            border.color: Colours.palette.m3primary
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
        }

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.fillHeight: true
                Layout.topMargin: -1
                Layout.bottomMargin: -1
                implicitWidth: height

                radius: Tokens.rounding.full
                color: btn.active ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                Behavior on color {
                    CAnim {}
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1

                    text: btn.modelData.icon
                    color: btn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                    grade: 25
                    fill: btn.active ? 1 : 0

                    Behavior on color {
                        CAnim {}
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: btn.modelData.label
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: btn.modelData.description
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}

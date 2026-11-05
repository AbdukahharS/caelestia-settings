pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

/// Shared visual chrome for the Style tab's scheme cards: card surface with
/// hover/press state layer, swatch chips, current-scheme highlight, keyboard
/// focus ring and labels. Subtypes provide `chips`, `label`, `subtext` and
/// `current`, and react to `activated()`.
Item {
    id: root

    property bool current
    property string label
    property string subtext
    property var chips: []

    signal activated()

    width: 164
    height: 158

    activeFocusOnTab: true

    Keys.onReturnPressed: root.activated()
    Keys.onSpacePressed: root.activated()

    StyledRect {
        id: card

        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerLow
    }

    StateLayer {
        anchors.fill: parent
        radius: Tokens.rounding.large

        onClicked: root.activated()
    }

    // Keyboard focus ring, above the state layer.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Tokens.rounding.large
        border.width: root.activeFocus ? 2 : 0
        border.color: Colours.palette.m3primary
    }

    Rectangle {
        id: swatch

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.padding.medium
        width: parent.width - Tokens.padding.largeIncreased * 2
        height: 90
        radius: Tokens.rounding.medium
        clip: true
        color: Colours.palette.m3surfaceContainerHigh
        border.width: root.current ? 2 : 0
        border.color: Colours.palette.m3primary

        Behavior on border.width {
            Anim {}
        }

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Repeater {
                model: root.chips

                Rectangle {
                    required property var modelData

                    width: (parent.width - parent.spacing * 4) / 5
                    height: parent.height
                    radius: (width / 2) * 0.6
                    color: modelData

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }

        MaterialIcon {
            visible: root.current
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            text: "check_circle"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }
    }

    StyledText {
        id: name

        anchors.top: swatch.bottom
        anchors.topMargin: Tokens.spacing.small
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Tokens.padding.small * 2
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        font: Tokens.font.body.medium
        elide: Text.ElideRight
    }

    StyledText {
        anchors.top: name.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Tokens.padding.small * 2
        horizontalAlignment: Text.AlignHCenter
        text: root.subtext
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
        elide: Text.ElideRight
    }
}

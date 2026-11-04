pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

/// Shared visual chrome for the Style tab's scheme cards: swatch chips,
/// current-scheme highlight and labels. Subtypes provide `chips`, `label`,
/// `subtext` and `current`, and react to `activated()`.
Item {
    id: root

    property bool current
    property string label
    property string subtext
    property var chips: []

    signal activated()

    width: 150
    height: 132

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Rectangle {
        id: swatch

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 132
        height: 84
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
        text: root.label
        font: Tokens.font.body.medium
    }

    StyledText {
        anchors.top: name.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.subtext
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
    }
}

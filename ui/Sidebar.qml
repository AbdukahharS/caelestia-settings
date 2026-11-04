pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property int current: 0

    implicitWidth: 96

    component NavButton: Item {
        id: btn

        required property var modelData
        required property int index

        readonly property bool active: root.current === index

        width: root.width
        height: 68

        // M3 navigation rail pill
        Rectangle {
            id: pill

            width: 52
            height: 32
            radius: height / 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6
            color: btn.active ? Colours.palette.m3secondaryContainer : "transparent"

            Behavior on color {
                CAnim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: btn.modelData.icon
                color: btn.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.current = btn.index
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: btn.modelData.label
            color: btn.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.extraLarge
        spacing: Tokens.padding.medium

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "settings"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.extraLarge
        }

        Repeater {
            model: [
                {
                    "icon": "palette",
                    "label": "Style"
                },
                {
                    "icon": "tune",
                    "label": "Shell"
                },
                {
                    "icon": "window",
                    "label": "Hyprland"
                },
                {
                    "icon": "keyboard",
                    "label": "Binds"
                },
                {
                    "icon": "monitor",
                    "label": "Displays"
                }
            ]

            NavButton {}
        }
    }
}

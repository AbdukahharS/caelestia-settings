pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.core
import qs.services
import qs.modules.nexus.common

Item {
    id: root

    /// Parses a scheme .txt file (`name hex` per line) into swatch chip colours.
    function parseChips(text: string): var {
        const map = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^([A-Za-z]+)[ \t]+([0-9a-fA-F]+)$/);
            if (m)
                map[m[1]] = `#${m[2]}`;
        }
        return ["primary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "surfaceContainerHigh"].map(k => map[k] ?? Colours.palette.m3outlineVariant);
    }

    component SchemeCard: Item {
        id: card

        required property var modelData

        readonly property bool current: Schemes.isCurrent(modelData.name, modelData.flavour)
        readonly property string mode: {
            const preferred = Colours.light ? "light" : "dark";
            return modelData.modes.includes(preferred) ? preferred : (modelData.modes[0] ?? "dark");
        }
        readonly property string schemeFile: `${modelData.dir}/${mode}.txt`
        property var chips: []

        width: 150
        height: 132

        FileView {
            path: card.schemeFile
            watchChanges: false
            onLoaded: card.chips = root.parseChips(text())
        }

        MouseArea {
            id: clickArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Schemes.apply(card.modelData.name, card.modelData.flavour)
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
            border.width: card.current ? 2 : 0
            border.color: Colours.palette.m3primary

            Behavior on border.width {
                Anim {}
            }

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Repeater {
                    model: card.chips

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
                visible: card.current
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
            text: card.modelData.name
            font: Tokens.font.body.medium
        }

        StyledText {
            anchors.top: name.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.modelData.flavour
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLarge
        spacing: Tokens.spacing.largeIncreased

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: "Style"
                font: Tokens.font.title.large
                Layout.fillWidth: true
            }

            ToggleRow {
                text: "Light mode"
                checked: Colours.light
                onToggled: Schemes.setMode(checked ? "light" : "dark")
            }

            IconButton {
                icon: "refresh"
                onClicked: Schemes.refresh()
            }
        }

        StyledText {
            text: "Colour scheme"
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.title.medium
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width

            Flow {
                width: parent.width
                spacing: Tokens.spacing.large

                Repeater {
                    model: Schemes.schemes

                    SchemeCard {}
                }
            }
        }
    }
}

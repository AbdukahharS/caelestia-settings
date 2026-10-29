pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.pages

FloatingWindow {
    id: win

    title: "Settings"
    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false
    visible: true

    implicitWidth: 980
    implicitHeight: 660
    minimumSize.width: 780
    minimumSize.height: 540

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    onVisibleChanged: if (!visible)
        Qt.quit()

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar

            Layout.fillHeight: true
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackLayout {
                anchors.fill: parent
                currentIndex: sidebar.current

                AppearancePage {}
                ShellPage {}
                HyprlandPage {}
            }
        }
    }
}

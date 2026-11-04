pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.core
import qs.services
import qs.pages

FloatingWindow {
    id: win

    title: "Settings"
    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false
    visible: true

    implicitWidth: WindowState.restoredWidth || WindowState.defaultWidth
    implicitHeight: WindowState.restoredHeight || WindowState.defaultHeight
    minimumSize.width: WindowState.minWidth
    minimumSize.height: WindowState.minHeight

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    onVisibleChanged: if (!visible) {
        WindowState.flush();
        Qt.quit();
    }

    onWidthChanged: WindowState.noteSize(width, height)
    onHeightChanged: WindowState.noteSize(width, height)

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
                KeybindsPage {}
                DisplaysPage {}
            }
        }
    }
}

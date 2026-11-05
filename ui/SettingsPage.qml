pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

/// Shared scaffold for the settings pages: a title row with an optional
/// right-aligned actions area, above a capped-width centred content column
/// inside a fade-out flickable.
///
/// Page content goes into the default property (the content column) and is
/// laid out like rows in a ColumnLayout. The header MouseArea overlaps the
/// flickable's top margin so clicks under the header don't reach the
/// flickable (same trick as the shell's PageBase).
ColumnLayout {
    id: root

    property string title
    /// Right-of-title actions (Buttons, IconButtons). Rendered in a plain
    /// Row — children keep natural sizes, but Layout-managed controls
    /// (e.g. ToggleRow) will collapse here; put those in the content
    /// column instead.
    property alias headerActions: actionsRow.children
    default property alias contentChildren: contentColumn.data

    readonly property real cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)

    spacing: Tokens.spacing.extraLargeIncreased

    MouseArea {
        z: 1
        implicitWidth: header.implicitWidth
        implicitHeight: header.implicitHeight - Layout.bottomMargin
        Layout.bottomMargin: -flick.topMargin
        onClicked: focus = true

        RowLayout {
            id: header

            spacing: Tokens.spacing.largeIncreased

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font: Tokens.font.title.large
                elide: Text.ElideRight
            }

            Row {
                id: actionsRow

                spacing: Tokens.spacing.medium
            }
        }
    }

    VerticalFadeFlickable {
        id: flick

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -topMargin
        topMargin: Tokens.padding.large
        bottomMargin: Tokens.padding.extraLarge

        contentHeight: contentColumn.implicitHeight

        TapHandler {
            onTapped: flick.focus = true
        }

        // Flickable auto-parents visual children to its contentItem.
        ColumnLayout {
            id: contentColumn

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.cappedWidth
            // Tight spacing like the shell's settings pages: connected rows
            // sit flush and interlock their corners; SectionHeader owns the
            // section gap via its own top margin.
            spacing: Tokens.spacing.extraSmall / 2
        }
    }
}

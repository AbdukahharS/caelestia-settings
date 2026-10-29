pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.nexus.common

/// Drop-in replacement for nexus SelectRow whose split-button menu renders
/// reliably inside this app's FloatingWindow. The upstream Menu overlay stops
/// repainting after its open animation on reparented items (Qt layering bug),
/// so this builds the popover from primitives verified to render: a
/// full-window MouseArea overlay + Elevation panel.
///
/// API matches SelectRow: label, subtext, menuItems (list<MenuItem>), active,
/// selected(item), first/last.
ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property list<MenuItem> menuItems
    property MenuItem active
    property bool menuOnTop

    signal selected(item: MenuItem)

    Layout.fillWidth: true

    // Open state lives here so the overlay can live in the window contentItem
    // while the row stays inside flickables/stacks.
    property bool expanded

    onExpandedChanged: {
        if (expanded) {
            // Imperatively ensure the overlay sits in the window contentItem:
            // the creation-time binding can hold null for items instantiated
            // inside not-yet-visible stacks.
            const win = QsWindow.window;
            if (win && overlay.parent !== win.contentItem)
                overlay.parent = win.contentItem;
        }
        Qt.callLater(positionPanel);
    }

    function positionPanel(): void {
        if (!expanded || !overlay.parent)
            return;
        const p = buttonRect.mapToItem(overlay.parent, 0, 0);
        let x = p.x + buttonRect.width - panel.width;
        x = Math.max(Tokens.padding.small, Math.min(x, overlay.parent.width - panel.width - Tokens.padding.small));
        let y = root.menuOnTop ? p.y - panel.height - Tokens.spacing.small : p.y + buttonRect.height + Tokens.spacing.small;
        if (!root.menuOnTop && y + panel.height > overlay.parent.height - Tokens.padding.small)
            y = p.y - panel.height - Tokens.spacing.small;
        panel.x = x;
        panel.y = y;
    }

    // Deterministic height: content + vertical padding, with the row
    // vertically centred via anchors (no fill-feedback loops).
    implicitHeight: rowLayout.implicitHeight + Tokens.padding.medium * 2

    RowLayout {
        id: rowLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        // Split-button look: value pill + chevron, both toggle the popover
        Row {
            id: buttonRect

            spacing: Math.floor(Tokens.spacing.extraSmall / 2)

            StyledRect {
                radius: implicitHeight / 2 * Math.min(1, Tokens.rounding.scale)
                topRightRadius: Tokens.rounding.medium / 2
                bottomRightRadius: Tokens.rounding.medium / 2
                color: Colours.palette.m3secondaryContainer
                implicitWidth: valueLabel.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: valueLabel.implicitHeight + Tokens.padding.small * 2

                StateLayer {
                    topRightRadius: parent.topRightRadius
                    bottomRightRadius: parent.bottomRightRadius
                    color: Colours.palette.m3onSecondaryContainer
                    onClicked: root.expanded = !root.expanded
                }

                StyledText {
                    id: valueLabel

                    anchors.centerIn: parent
                    text: root.active ? root.active.activeText : ""
                    color: Colours.palette.m3onSecondaryContainer
                    font: Tokens.font.body.small
                }
            }

            StyledRect {
                id: chevronRect

                property real rad: root.expanded ? implicitHeight / 2 * Math.min(1, Tokens.rounding.scale) : Tokens.rounding.medium / 2

                radius: implicitHeight / 2 * Math.min(1, Tokens.rounding.scale)
                topLeftRadius: rad
                bottomLeftRadius: rad
                color: Colours.palette.m3secondaryContainer
                implicitWidth: implicitHeight
                implicitHeight: chevron.implicitHeight + Tokens.padding.small * 2

                StateLayer {
                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    color: Colours.palette.m3onSecondaryContainer
                    onClicked: root.expanded = !root.expanded
                }

                MaterialIcon {
                    id: chevron

                    anchors.centerIn: parent
                    text: "expand_more"
                    color: Colours.palette.m3onSecondaryContainer
                    rotation: root.expanded ? 180 : 0

                    Behavior on rotation {
                        Anim {}
                    }
                }

                Behavior on rad {
                    Anim {}
                }
            }
        }
    }

    // Full-window overlay: closes on outside click. Reparented to the window
    // contentItem so it draws above all page content; deliberately never
    // GPU-layered (layer toggling on reparented items breaks repainting).
    MouseArea {
        id: overlay

        objectName: "appSelectOverlay"
        property var row: root

        anchors.fill: parent
        z: 100
        enabled: root.expanded
        hoverEnabled: root.expanded
        cursorShape: root.expanded ? Qt.ArrowCursor : undefined
        onClicked: root.expanded = false

        opacity: root.expanded ? 1 : 0
        layer.enabled: false

        parent: {
            const win = QsWindow.window;
            return win ? win.contentItem : null;
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        onParentChanged: Qt.callLater(root.positionPanel)
        onWidthChanged: root.positionPanel()
        onHeightChanged: root.positionPanel()

        Elevation {
            id: panel

            level: 2
            radius: Tokens.rounding.large
            implicitWidth: Math.max(200, column.implicitWidth + column.anchors.margins * 2)
            implicitHeight: column.implicitHeight + column.anchors.margins * 2

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onWheel: e => e.accepted = true
            }

            StyledRect {
                anchors.fill: parent
                radius: parent.radius
                color: Colours.palette.m3surfaceContainerLow

                ColumnLayout {
                    id: column

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.extraSmall
                    spacing: 0

                    Repeater {
                        model: root.menuItems

                        Item {
                            id: option

                            required property int index
                            required property MenuItem modelData

                            readonly property bool isActive: modelData === root.active

                            Layout.fillWidth: true
                            implicitWidth: optionRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: optionRow.implicitHeight + Tokens.padding.medium * 2

                            StateLayer {
                                topLeftRadius: option.index === 0 ? Tokens.rounding.medium : Tokens.rounding.extraSmall
                                topRightRadius: option.index === 0 ? Tokens.rounding.medium : Tokens.rounding.extraSmall
                                bottomLeftRadius: option.index === root.menuItems.length - 1 ? Tokens.rounding.medium : Tokens.rounding.extraSmall
                                bottomRightRadius: option.index === root.menuItems.length - 1 ? Tokens.rounding.medium : Tokens.rounding.extraSmall

                                color: option.isActive ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                                onClicked: {
                                    root.selected(option.modelData);
                                    root.active = option.modelData;
                                    option.modelData.clicked();
                                    root.expanded = false;
                                }
                            }

                            RowLayout {
                                id: optionRow

                                anchors.fill: parent
                                anchors.margins: Tokens.padding.medium
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: option.modelData?.icon ?? (option.isActive ? "check" : "")
                                    color: option.isActive ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: option.modelData?.text ?? ""
                                    color: option.isActive ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.nexus.common
import qs.services

/// Compact page-level note: icon + wrapped text on a rounded low surface.
/// Use for hints that would otherwise be a bare paragraph on the page.
ConnectedRect {
    id: root

    property alias icon: icon.text
    property alias text: label.text

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

    topLeftRadius: Tokens.rounding.medium
    topRightRadius: Tokens.rounding.medium
    bottomLeftRadius: Tokens.rounding.medium
    bottomRightRadius: Tokens.rounding.medium

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            text: "info"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.medium
        }

        StyledText {
            id: label

            Layout.fillWidth: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
            wrapMode: Text.WordWrap
        }
    }
}

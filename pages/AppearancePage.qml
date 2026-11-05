pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.core
import qs.services
import qs.modules.nexus.common
import qs.ui

SettingsPage {
    id: root

    readonly property list<string> chipKeys: ["primary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "surfaceContainerHigh"]

    /// Parses a scheme .txt file (`name hex` per line) into swatch chip colours.
    function parseChips(text: string): var {
        const map = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^([A-Za-z]+)[ \t]+([0-9a-fA-F]+)$/);
            if (m)
                map[m[1]] = `#${m[2]}`;
        }
        return root.chipKeys.map(k => map[k] ?? Colours.palette.m3outlineVariant);
    }

    /// Parses `caelestia wallpaper -p` JSON scheme output into swatch chip colours.
    function parseJsonChips(text: string): var {
        let colours = {};
        try {
            colours = JSON.parse(text).colours ?? {};
        } catch (e) {}
        return root.chipKeys.map(k => colours[k] ? `#${colours[k]}` : Colours.palette.m3outlineVariant);
    }

    component SchemeCard: SchemeCardBase {
        id: schemeCard

        required property var modelData

        readonly property string mode: {
            const preferred = Colours.light ? "light" : "dark";
            return modelData.modes.includes(preferred) ? preferred : (modelData.modes[0] ?? "dark");
        }
        readonly property string schemeFile: `${modelData.dir}/${mode}.txt`

        current: Schemes.isCurrent(modelData.name, modelData.flavour)
        label: modelData.name
        subtext: modelData.flavour

        FileView {
            path: schemeCard.schemeFile
            watchChanges: false
            onLoaded: schemeCard.chips = root.parseChips(text())
        }

        onActivated: Schemes.apply(modelData.name, modelData.flavour)
    }

    /// The wallpaper-derived dynamic scheme, with a live preview of the
    /// colours the current wallpaper would produce.
    component DynamicCard: SchemeCardBase {
        id: dynamicCard

        current: Colours.scheme === "dynamic"
        label: "Dynamic"
        subtext: "wallpaper"

        Process {
            id: previewProc

            stdout: StdioCollector {
                onStreamFinished: dynamicCard.chips = root.parseJsonChips(text)
            }
        }

        function refreshPreview(): void {
            if (!Wallpapers.current)
                return;
            previewProc.command = ["caelestia", "wallpaper", "-p", Wallpapers.current];
            previewProc.running = true;
        }

        Component.onCompleted: dynamicCard.refreshPreview()

        Connections {
            target: Wallpapers

            function onCurrentChanged(): void {
                dynamicCard.refreshPreview();
            }
        }

        Connections {
            target: Colours

            function onLightChanged(): void {
                dynamicCard.refreshPreview();
            }
        }

        onActivated: Schemes.applyDynamic()
    }

    title: "Style"

    headerActions: [
        IconButton {
            icon: "refresh"

            onClicked: Schemes.refresh()
        }
    ]

    SectionHeader {
        first: true
        text: "Appearance"
    }

    ToggleRow {
        first: true
        last: true
        text: "Light mode"
        subtext: "Switch the palette between light and dark"
        checked: Colours.light
        onToggled: Schemes.setMode(checked ? "light" : "dark")
    }

    SectionHeader {
        text: "Colour scheme"
    }

    Flow {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        spacing: Tokens.spacing.large

        DynamicCard {}

        Repeater {
            model: Schemes.schemes

            SchemeCard {}
        }
    }
}

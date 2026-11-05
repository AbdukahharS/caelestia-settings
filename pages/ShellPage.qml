pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.ui

SettingsPage {
    id: root

    readonly property list<MenuItem> clockItems: [
        MenuItem {
            text: "Auto"
            value: ClockFormat.Auto
        },
        MenuItem {
            text: "12-hour"
            value: ClockFormat.TwelveHour
        },
        MenuItem {
            text: "24-hour"
            value: ClockFormat.TwentyFourHour
        }
    ]

    title: "Shell"

    // Bar
    SectionHeader {
        first: true
        text: "Bar"
    }

    ToggleRow {
        first: true
        text: "Persistent"
        subtext: "Always reserve space for the bar"
        checked: GlobalConfig.bar.persistent
        onToggled: GlobalConfig.bar.persistent = checked
    }

    ToggleRow {
        text: "Show on hover"
        subtext: "Reveal the bar when hovering the top edge"
        checked: GlobalConfig.bar.showOnHover
        onToggled: GlobalConfig.bar.showOnHover = checked
    }

    ToggleRow {
        text: "Workspaces scroll actions"
        checked: GlobalConfig.bar.scrollActions.workspaces
        onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
    }

    StepperRow {
        label: "Visible workspaces"
        value: GlobalConfig.bar.workspaces.shown
        from: 1
        to: 10
        stepSize: 1
        onMoved: v => GlobalConfig.bar.workspaces.shown = v
    }

    ToggleRow {
        text: "Occupied workspace background"
        checked: GlobalConfig.bar.workspaces.occupiedBg
        onToggled: GlobalConfig.bar.workspaces.occupiedBg = checked
    }

    ToggleRow {
        text: "Active workspace trail"
        checked: GlobalConfig.bar.workspaces.activeTrail
        onToggled: GlobalConfig.bar.workspaces.activeTrail = checked
    }

    ToggleRow {
        text: "Invert active window icon"
        checked: GlobalConfig.bar.activeWindow.inverted
        onToggled: GlobalConfig.bar.activeWindow.inverted = checked
    }

    ToggleRow {
        text: "Tray background"
        checked: GlobalConfig.bar.tray.background
        onToggled: GlobalConfig.bar.tray.background = checked
    }

    ToggleRow {
        text: "Compact tray"
        checked: GlobalConfig.bar.tray.compact
        onToggled: GlobalConfig.bar.tray.compact = checked
    }

    ToggleRow {
        last: true
        text: "Recolour tray icons"
        checked: GlobalConfig.bar.tray.recolour
        onToggled: GlobalConfig.bar.tray.recolour = checked
    }

    // Launcher
    SectionHeader {
        text: "Launcher"
    }

    ToggleRow {
        first: true
        last: true
        text: "Allow dangerous actions"
        subtext: "Power options and potentially destructive commands in the launcher"
        checked: GlobalConfig.launcher.enableDangerousActions
        onToggled: GlobalConfig.launcher.enableDangerousActions = checked
    }

    // Sidebar
    SectionHeader {
        text: "Sidebar"
    }

    ToggleRow {
        first: true
        last: true
        text: "Enabled"
        checked: GlobalConfig.sidebar.enabled
        onToggled: GlobalConfig.sidebar.enabled = checked
    }

    // Services
    SectionHeader {
        text: "Services"
    }

    AppSelectRow {
        first: true
        label: "Clock format"
        menuItems: root.clockItems
        active: root.clockItems.find(i => i.value === GlobalConfig.services.clockFormat)
        onSelected: item => GlobalConfig.services.clockFormat = item.value
    }

    StepperRow {
        label: "Audio increment"
        subtext: "Volume change per keypress (0–1)"
        value: GlobalConfig.services.audioIncrement
        from: 0.01
        to: 0.5
        stepSize: 0.01
        onMoved: v => GlobalConfig.services.audioIncrement = v
    }

    StepperRow {
        last: true
        label: "Brightness increment"
        subtext: "Brightness change per keypress (0–1)"
        value: GlobalConfig.services.brightnessIncrement
        from: 0.01
        to: 0.5
        stepSize: 0.01
        onMoved: v => GlobalConfig.services.brightnessIncrement = v
    }
}

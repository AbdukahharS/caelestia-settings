pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Persists the main window's size across launches.
///
/// State lives in ~/.config/caelestia/settings-window.json — an app-owned
/// sibling of hypr-vars.lua / monitors.lua. The Caelestia dots don't own this
/// file and `caelestia update` never touches unknown files, so the
/// update-safety contract holds.
///
/// The saved size is restored at startup (restoredWidth/restoredHeight); until
/// a save exists the window falls back to its default size. Restored values
/// are clamped to the minimum, so a size captured on a smaller display can't
/// wedge the window on the next launch.
Singleton {
    id: root

    readonly property string stateFile: `${Quickshell.env("HOME")}/.config/caelestia/settings-window.json`

    readonly property int defaultWidth: 980
    readonly property int defaultHeight: 660
    readonly property int minWidth: 780
    readonly property int minHeight: 540

    /// Size to restore; 0 = never saved (use defaults). Set once at load —
    /// the window's initial size binds to these, so they must never change
    /// while running (that would re-evaluate implicitWidth mid-resize).
    property int restoredWidth: 0
    property int restoredHeight: 0

    /// Last seen size, for saving; 0 = nothing recorded yet.
    property int width: 0
    property int height: 0

    Timer {
        id: saveTimer

        interval: 400
        onTriggered: root.flush()
    }

    FileView {
        id: storage

        path: root.stateFile
        // Reads must block until loaded: without this, text() returns "" in
        // Component.onCompleted and the saved size would be missed at startup.
        blockLoading: true
        atomicWrites: true
    }

    Component.onCompleted: {
        try {
            const saved = JSON.parse(storage.text());
            root.restoredWidth = Math.max(root.minWidth, saved.width || 0);
            root.restoredHeight = Math.max(root.minHeight, saved.height || 0);
        } catch (e) {} // missing/corrupt file: fall back to defaults
    }

    /// Records a live size change; writes are debounced while dragging.
    function noteSize(w: int, h: int): void {
        // Window init emits degenerate sizes (0) before the compositor's
        // first configure; recording those once fed implicitWidth's old
        // binding and shrank the window. Valid sizes only.
        if (w < root.minWidth || h < root.minHeight)
            return;
        root.width = w;
        root.height = h;
        saveTimer.restart();
    }

    /// Writes state now; blocks until the write lands (used on window close).
    function flush(): void {
        if (root.width <= 0 || root.height <= 0)
            return;
        saveTimer.stop();
        storage.setText(JSON.stringify({
            "width": root.width,
            "height": root.height
        }));
        storage.waitForJob();
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    /// Maps only once the single-instance guard confirms no peer instance.
    /// A duplicate launch instead focuses the running window via IPC and
    /// quits unmapped — two live instances could clobber each other's
    /// hypr-vars.lua / monitors.lua / shell.json writes (stale in-memory
    /// state winning over fresh state).
    property bool sole: false

    visible: sole

    implicitWidth: WindowState.restoredWidth || WindowState.defaultWidth
    implicitHeight: WindowState.restoredHeight || WindowState.defaultHeight
    minimumSize.width: WindowState.minWidth
    minimumSize.height: WindowState.minHeight

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    Component.onCompleted: guard.start()

    onVisibleChanged: if (!visible) {
        WindowState.flush();
        Qt.quit();
    }

    onWidthChanged: WindowState.noteSize(width, height)
    onHeightChanged: WindowState.noteSize(width, height)

    /// Registered by every instance (including dupes, before the guard
    /// verdict): `ping` reports the answering instance's PID so the guard
    /// can tell self from peer (the CLI targets the oldest instance), and
    /// `show` raises the winning instance when a duplicate launch arrives.
    IpcHandler {
        target: "settings"

        function show(): void {
            win.visible = true;
            win.requestActivate();
        }

        function ping(): string {
            return `${Quickshell.processId}`;
        }
    }

    // Single-instance guard.
    //
    // Decisions are content-based: this Quickshell build prints "Target not
    // found." with exit 0 for missing IPC targets and its Process has no
    // usable exited signal, so exit codes are useless — the dots' own
    // StdioCollector.onStreamFinished pattern is used throughout.
    //
    // 1. `call settings ping`: the CLI targets the oldest live instance of
    //    this config. Our own PID comes back → we are the oldest (any newer
    //    peers are duplicates that will kill themselves via their own probe)
    //    → cross-check the instance list. A different PID → a real peer is
    //    live → `call settings show` makes it raise itself, and we quit as a
    //    duplicate.
    // 2. No answer (nothing registered yet, or a pre-guard instance) → list
    //    this config's instances. No peer → we are the sole instance and map
    //    the window. A peer that never answers after ~2s of retries → quit
    //    anyway: never race a writer we cannot talk to, even a wedged one.
    Process {
        id: guard

        property string phase
        property int retries

        function start(): void {
            retries = 0;
            probe();
        }

        function probe(): void {
            phase = "probe";
            command = ["qs", "ipc", "-p", Quickshell.shellDir, "call", "settings", "ping"];
            running = true;
        }

        function focus(): void {
            phase = "focus";
            command = ["qs", "ipc", "-p", Quickshell.shellDir, "call", "settings", "show"];
            running = true;
        }

        function listPeers(): void {
            phase = "list";
            command = ["qs", "list", "-j", "-p", Quickshell.shellDir];
            running = true;
        }

        function die(): void {
            // Unmapped duplicate: visible never changed, so there is nothing
            // to flush — plain quit.
            Qt.quit();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const value = (text ?? "").trim();

                if (guard.phase === "probe") {
                    const pid = Number(value);
                    if (!Number.isNaN(pid) && pid !== 0 && pid !== Quickshell.processId)
                        guard.focus(); // a real peer answered: raise it, quit
                    else
                        guard.listPeers(); // self / no answer: check the list
                    return;
                }

                if (guard.phase === "focus") {
                    guard.die(); // the live instance focused itself
                    return;
                }

                let peers = [];
                try {
                    peers = JSON.parse(value).filter(inst => inst.pid !== Quickshell.processId);
                } catch (e) {
                    peers = [];
                }

                if (peers.length === 0) {
                    win.sole = true; // confirmed alone (or a retried peer died)
                } else if (guard.retries >= 10) {
                    guard.die(); // peer alive but unanswered after ~2s: never race it
                } else {
                    guard.retries += 1;
                    retryTimer.start();
                }
            }
        }
    }

    Timer {
        id: retryTimer

        interval: 200
        onTriggered: guard.probe()
    }

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

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property string systemSchemesDir: "/usr/lib/python3.14/site-packages/caelestia/data/schemes"
    readonly property string userSchemesDir: `${Paths.data}/schemes`

    /// [{ name, flavour, dir }]
    property var schemes: []

    function isCurrent(name: string, flavour: string): bool {
        return Colours.scheme === name && Colours.flavour === flavour;
    }

    function apply(name: string, flavour: string): void {
        applyProc.command = ["caelestia", "scheme", "set", "-n", name, "-f", flavour, "-m", Colours.light ? "light" : "dark"];
        applyProc.running = true;
    }

    function setMode(mode: string): void {
        Colours.setMode(mode);
    }

    function refresh(): void {
        listProc.command = ["find", "-L", systemSchemesDir, userSchemesDir, "-mindepth", "3", "-maxdepth", "3", "-type", "f", "-name", "*.txt"];
        listProc.running = true;
    }

    Process {
        id: applyProc
    }

    Process {
        id: listProc

        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of this.text.trim().split("\n").filter(l => l)) {
                    const parts = line.split("/").filter(p => p);
                    const file = parts[parts.length - 1];
                    if (!file.endsWith(".txt"))
                        continue;
                    const mode = file.slice(0, -4);
                    const flavour = parts[parts.length - 2];
                    const name = parts[parts.length - 3];
                    const dir = "/" + parts.slice(0, -1).join("/");
                    if (!map[dir])
                        map[dir] = {
                            "name": name,
                            "flavour": flavour,
                            "dir": dir,
                            "modes": []
                        };
                    if (!map[dir].modes.includes(mode))
                        map[dir].modes.push(mode);
                }
                const entries = Object.values(map);
                entries.sort((a, b) => a.name.localeCompare(b.name) || a.flavour.localeCompare(b.flavour));
                root.schemes = entries;
            }
        }
    }

    Component.onCompleted: refresh()
}

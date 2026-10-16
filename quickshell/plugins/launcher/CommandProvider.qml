import QtQuick
import Quickshell
import qs.components
import qs.services

// "> command": runs it with sh (in the background), or in a terminal that
// stays open (Shift+Enter / Tab).
LauncherProvider {
    name: "Command"
    keyword: ">"
    global: false

    function query(text: string, seq: int): var {
        if (text === "")
            return [{ title: "Type a command", subtitle: "Enter runs it in the background; Shift+Enter in a terminal", icon: "terminal", score: 1, key: "", highlight: false, keepOpen: true, run: () => {} }];
        return [{
                title: text,
                subtitle: "Run",
                icon: "terminal",
                score: 100,
                key: "",
                highlight: false,
                run: () => Quickshell.execDetached(["sh", "-c", text]),
                actions: [
                    {
                        label: "Run in a terminal",
                        icon: "terminal",
                        run: () => Quickshell.execDetached(["foot", "--hold", "sh", "-c", text])
                    }
                ]
            }];
    }
}

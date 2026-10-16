import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.services

// "= expression": the calculator (Calc, qalc behind it); Enter copies the
// result.
LauncherProvider {
    id: root

    name: "Calculator"
    keyword: "="
    global: false

    property int pending: -1

    function query(text: string, seq: int): var {
        if (text === "")
            return [{ title: "Type an expression", subtitle: "Units and currency too: 5 km in miles, 20 usd in pkr", icon: "calculate", score: 1, key: "", highlight: false, keepOpen: true, run: () => {} }];
        pending = seq;
        // "5 km in miles": qalc reads that "in" as inches; "to" converts.
        Calc.evaluate(text.replace(/\s+in\s+([A-Za-z€$£¥]+)\s*$/, " to $1"));
        return null;
    }

    readonly property Connections calc: Connections {
        target: Calc

        function onResultChanged(): void {
            if (root.pending < 0 || !Calc.result)
                return;
            const value = Calc.result;
            root.publish(root.pending, [{
                    title: value,
                    subtitle: "Enter copies it",
                    icon: "calculate",
                    score: 100,
                    key: "",
                    highlight: false,
                    run: () => Clipboard.copyText(value)
                }]);
        }
    }
}

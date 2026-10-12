import QtQuick

// One setting in a SettingsPage. `kind` picks the panel's primitive for it:
//   choice   one of `options` ([{ value, icon, label }]): a ButtonGroup
//   toggle   true / false: a ListRow with a StyledSwitch (`icon` leads it)
//   multi    any number of `options`, an array of their values: Chips that
//            toggle
//   text     free text (`placeholder`); `secret` hides it: a TextField
//   number   `min`..`max` by `step`, shown with `unit` or `format`: a
//            StyledSlider
// `section` starts a new group on the page; `shown` hides it while it
// doesn't apply (a binding on other values).
QtObject {
    property string key
    property string icon: "tune"
    property string kind: "choice"
    property string label
    property string description
    property string section
    property var def
    property var options: []
    property string placeholder
    property bool secret: false
    property real min: 0
    property real max: 100
    property real step: 1
    property string unit
    // How a number reads: "" (value + unit) | "duration" (seconds as
    // 45 s / 2:30 min / 1 h 30 min); `zeroLabel` stands for 0 ("Never").
    property string format
    property string zeroLabel
    property bool shown: true
}

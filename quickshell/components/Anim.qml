import QtQuick
import qs.config

NumberAnimation {
    duration: Tokens.anim.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Tokens.anim.standard
}

import QtQuick
import qs.config

ColorAnimation {
    duration: Tokens.anim.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Tokens.anim.standard
}

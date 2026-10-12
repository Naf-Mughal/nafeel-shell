import QtQuick
import qs.config

// A panel's scrolling column (a Flickable): the wheel moves it by the scroll
// step with a short glide (WheelScroll), it clips to itself and stops at its
// ends. Sliders inside keep the vertical wheel for the page; they only take
// a sideways scroll.
Flickable {
    id: root

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width

    WheelScroll {
        view: root
    }
}

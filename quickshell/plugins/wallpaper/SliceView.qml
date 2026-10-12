pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The slice carousel (after Ryoku's SliceDelegate and its slice list, MIT):
// the library as slanted strips leaning against each other, the selected one
// opened wide in the middle. Moving the selection slides the band and the
// strips open and close around it. Each slice is one shader (shaders/
// slice.frag: the slanted rounded cut, dimming, rim, shadow) rather than
// Ryoku's shape-mask layers.
//
// Ryoku's proportions: expanded 924 : slice 135, overlap -30, lean 35.
//
// No ListView: it only estimates where unbuilt slices go and re-estimates as
// they come and go, which made the band jump now and then mid-slide. Here
// every slice is placed by arithmetic from one animated position (`pos`, the
// open slice as a fractional index), as Ryoku's hand of cards does, and a
// ring of slots is reused: a slot keeps its wallpaper while it's on screen,
// only the one leaving one end takes the one entering the other (unseen).
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    readonly property int count: model.length
    // For the store's paging (the picker asks for more near the end).
    readonly property bool atXEnd: count > 0 && currentIndex >= count - 3

    signal picked(int index, bool close)

    readonly property real expandedWidth: Math.min(width * 0.62, height * 16 / 9)
    readonly property real sliceWidth: Math.round(expandedWidth * 0.146)
    readonly property real skew: Math.round(sliceWidth * 0.26)
    readonly property real spacing: -Math.round(sliceWidth * 0.22)
    readonly property real pitch: sliceWidth + spacing
    readonly property real grow: expandedWidth - sliceWidth
    readonly property real pad: 16

    // The open slice, as a fractional index; everything reads it.
    property real pos: 0

    function move(dx: int, dy: int): void {
        if (count > 0)
            currentIndex = Math.max(0, Math.min(count - 1, currentIndex + dx + dy));
    }

    function centreOn(i: int): void {
        if (i < 0 || i >= count)
            return;
        travel.stop();
        currentIndex = i;
        travel.stop();
        pos = i;
    }

    onCurrentIndexChanged: {
        if (drag.active)
            return;
        travel.to = currentIndex;
        travel.restart();
    }
    onCountChanged: {
        if (currentIndex >= count)
            currentIndex = Math.max(0, count - 1);
    }


    NumberAnimation {
        id: travel

        target: root
        property: "pos"
        duration: Tokens.dur(420)
        easing.type: Easing.OutCubic
    }

    // ── Where things go (all from pos) ──
    readonly property int _a: Math.max(0, Math.min(count - 1, Math.floor(pos)))
    readonly property real _f: Math.max(0, Math.min(1, pos - _a))

    function weight(i: int): real {
        return Math.max(0, 1 - Math.abs(i - pos));
    }

    function widthOf(i: int): real {
        return sliceWidth + grow * weight(i);
    }

    // Left edge of slice k on the band: k steps, plus what the (at most two)
    // open-ish slices before it add.
    function leftOf(k: int): real {
        return k * pitch + (k > _a ? grow * (1 - _f) : 0) + (k > _a + 1 ? grow * _f : 0);
    }

    // The band's point that sits in the middle: between the centres of the
    // two slices either side of pos.
    readonly property real centre: {
        const wa = sliceWidth + grow * (1 - _f);
        const wb = sliceWidth + grow * _f;
        return leftOf(_a) + (1 - _f) * (wa / 2) + _f * (wa + spacing + wb / 2);
    }

    // The ring: enough slots to cover the width either side, plus a margin.
    readonly property int half: Math.max(4, Math.ceil(width / 2 / Math.max(1, pitch)) + 3)
    readonly property int slots: 2 * half + 1
    readonly property int base: Math.round(pos) - half

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.move(event.angleDelta.y > 0 || event.angleDelta.x > 0 ? -1 : 1, 0)
    }

    // Dragging slides the band directly; letting go settles on the nearest.
    DragHandler {
        id: drag

        property real startPos: 0

        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            if (active) {
                travel.stop();
                startPos = root.pos;
            } else {
                const i = Math.max(0, Math.min(root.count - 1, Math.round(root.pos)));
                if (i !== root.currentIndex)
                    root.currentIndex = i;
                travel.to = i;
                travel.restart();
            }
        }
        onTranslationChanged: {
            if (active)
                root.pos = Math.max(0, Math.min(root.count - 1, startPos - translation.x / root.pitch));
        }
    }

    Repeater {
        model: root.slots

        delegate: Item {
            id: slice

            required property int index
            // This slot's wallpaper: the one in the window that maps to it.
            readonly property int idx: root.base + (((index - root.base) % root.slots) + root.slots) % root.slots
            readonly property bool valid: idx >= 0 && idx < root.count
            readonly property var modelData: valid ? root.model[idx] : ({})

            readonly property bool isCurrent: idx === root.currentIndex
            readonly property bool current: (modelData.path ?? "") !== "" && modelData.path === Wallpapers.wallpaperOf(Wallpapers.target)
            readonly property bool chosen: (modelData.path ?? "") !== "" && modelData.path === Wallpapers.chosen
            readonly property bool hovered: hover.hovered
            // Fade the far ends of the band (Ryoku's viewport falloff).
            readonly property real dist: Math.abs(x + width / 2 - root.width / 2) / (root.width / 2)

            visible: valid && opacity > 0.01
            x: root.leftOf(idx) - root.centre + root.width / 2
            width: root.widthOf(idx)
            height: root.height
            z: isCurrent ? 100 : hovered ? 90 : 50 - Math.min(Math.abs(idx - root.currentIndex), 50)
            opacity: dist <= 0.7 ? 1 : Math.max(0, 1 - (dist - 0.7) / 0.45)

            // The picture at the slice's size (cropped), as the shader's texture:
            // the thumbnail, and in the open slice the file itself decoded at the
            // slice's real size on top (a 480 px thumbnail or the store's 300 px
            // preview stretched across ~900 px looked grainy).
            Item {
                id: pic

                width: slice.width
                height: slice.height
                visible: false

                Image {
                    id: img

                    anchors.fill: parent
                    source: Wallpapers.picture(slice.modelData)
                    sourceSize: Qt.size(Math.round(root.expandedWidth), Math.round(root.height))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Loader {
                    anchors.fill: parent
                    // Open (or opening) only: one full image at a time.
                    active: slice.isCurrent
                    // A live wallpaper moves here: its animated preview (the
                    // indexer's, a few seconds as animated WebP), not the video.
                    sourceComponent: (slice.modelData.video ?? false) ? livePreview : stillFull
                }

                Component {
                    id: livePreview

                    AnimatedImage {
                        source: slice.modelData.preview ? "file://" + slice.modelData.preview : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        playing: true
                        smooth: true
                    }
                }

                Component {
                    id: stillFull

                    Image {
                        readonly property real dpr: root.Window.window?.devicePixelRatio ?? 1

                        source: slice.modelData.remote ? (slice.modelData.full ?? "") : slice.modelData.path ? "file://" + slice.modelData.path : ""
                        sourceSize: Qt.size(Math.round(root.expandedWidth * dpr), Math.round(root.height * dpr))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                        mipmap: true
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Tokens.anim.normal
                            }
                        }
                    }
                }
            }

            ShaderEffectSource {
                id: tex

                sourceItem: pic
                hideSource: true
                visible: false
                smooth: true
            }

            ShaderEffect {
                x: -root.pad
                y: -root.pad
                width: slice.width + 2 * root.pad
                height: slice.height + 2 * root.pad
                visible: img.status === Image.Ready && slice.opacity > 0.01

                property var source: tex
                property size size: Qt.size(width, height)
                property real pad: root.pad
                property real skew: root.skew
                property real radius: Tokens.rounding.normal
                property real dim: slice.isCurrent ? 0 : slice.hovered ? 0.15 : 0.42
                property color rim: slice.current ? Colours.palette.m3primary : slice.chosen ? Colours.palette.m3tertiary : slice.isCurrent ? Qt.alpha(Colours.palette.m3onSurface, 0.85) : "transparent"
                property real rimWidth: slice.isCurrent || slice.chosen ? 2.5 : 2
                property real shadow: slice.isCurrent ? 0.5 : 0.28

                Behavior on dim {
                    NumberAnimation {
                        duration: Tokens.anim.normal
                    }
                }

                fragmentShader: Qt.resolvedUrl("../../shaders/slice.frag.qsb")
            }

            // While the thumbnail loads: the slice's shape in paper.
            Rectangle {
                visible: img.status !== Image.Ready
                anchors.fill: parent
                radius: Tokens.rounding.normal
                color: Colours.palette.m3surfaceContainerHigh
                opacity: 0.6
            }

            // Seals in the open slice: 選 chosen (top left, past the lean), 印
            // current (bottom right, before it).
            Seal {
                visible: slice.chosen && slice.width > root.sliceWidth * 2
                x: root.skew + Tokens.spacing.normal
                y: Tokens.spacing.normal
                glyph: "選"
                size: 22
            }

            Seal {
                visible: slice.current && slice.width > root.sliceWidth * 2
                x: slice.width - root.skew - width - Tokens.spacing.normal
                y: slice.height - height - Tokens.spacing.normal
                glyph: "印"
                size: 22
            }

            // The open slice's pigments and its favourite star.
            Row {
                visible: slice.isCurrent && slice.width > root.sliceWidth * 2 && (slice.modelData.colours?.length ?? 0) > 0
                x: Tokens.spacing.normal + 4
                y: slice.height - height - Tokens.spacing.normal - 2
                spacing: 4

                Repeater {
                    model: slice.modelData.colours ?? []

                    Rectangle {
                        required property string modelData

                        width: 11
                        height: 11
                        radius: 6
                        color: modelData
                        border.width: 1
                        border.color: Qt.alpha("black", 0.5)
                    }
                }
            }

            MaterialIcon {
                readonly property bool fav: Wallpapers.favourites[slice.modelData.path] ?? false

                visible: slice.width > root.sliceWidth * 2 && (fav || slice.hovered)
                x: slice.width - width - Tokens.spacing.normal - 2
                y: Tokens.spacing.normal
                text: "star"
                fill: fav ? 1 : 0
                size: 20
                color: fav ? Colours.palette.m3primary : "white"
                style: Text.Outline
                styleColor: Qt.alpha("black", 0.5)

                TapHandler {
                    onTapped: Wallpapers.toggleFavourite(slice.modelData.path)
                }
            }

            // A store result: resolution and download state, in the open slice.
            StoreBadge {
                visible: (slice.modelData.remote ?? false) && slice.width > root.sliceWidth * 2
                x: root.skew
                width: slice.width - 2 * root.skew
                height: slice.height
                wall: slice.modelData
            }

            // Hits only inside the slant.
            containmentMask: QtObject {
                function contains(point: point): bool {
                    const t = 1 - point.y / slice.height;
                    const left = root.skew * t;
                    const right = slice.width - root.skew + root.skew * t;
                    return point.y >= 0 && point.y <= slice.height && point.x >= left && point.x <= right;
                }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    root.currentIndex = slice.idx;
                    root.picked(slice.idx, false);
                }
                onDoubleTapped: {
                    root.currentIndex = slice.idx;
                    root.picked(slice.idx, true);
                }
            }
        }
    }
}

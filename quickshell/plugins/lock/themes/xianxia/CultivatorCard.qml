import QtQuick
import QtQuick.Effects
import "../.."

// The cultivator, as the dashboard's user card: the wallpaper as the cover,
// qi building up over it from the left as far as this level's cultivation
// (it runs up during an unlock's reward), the face or the name's initial in
// a seal, the name, the realm; on the right the realm's layer large, the qi
// to the next and the streak.
Item {
    id: card

    required property var xian
    readonly property real sc: xian.sc
    readonly property real progress: Math.max(0, Math.min(1, (xian.shownXp - xian.levelFloor) / Math.max(1, xian.levelCeil - xian.levelFloor)))
    readonly property string name: xian.ctx.userName ? xian.ctx.userName.charAt(0).toUpperCase() + xian.ctx.userName.slice(1) : ""

    width: 480 * sc
    height: 100 * sc

    // Cover and qi, clipped to the card's corners.
    Item {
        id: cover

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            color: Xian.paperFill
        }

        Image {
            anchors.fill: parent
            source: card.xian.host.wallpaperStill
            sourceSize: Qt.size(Math.max(64, Math.ceil(width)), Math.max(64, Math.ceil(height)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0.45
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Xian.alpha(Xian.ink, 0.88) }
                GradientStop { position: 1; color: Xian.alpha(Xian.ink, 0.25) }
            }
        }

        // Qi, gathered from the left up to the cultivation.
        Rectangle {
            width: parent.width * card.progress
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Xian.alpha(Xian.gold, 0.02) }
                GradientStop { position: 0.85; color: Xian.alpha(Xian.gold, 0.16) }
                GradientStop { position: 1; color: Xian.alpha(Xian.goldHi, 0.3) }
            }

            // Its edge, breathing.
            Rectangle {
                anchors.right: parent.right
                width: 2 * card.sc
                height: parent.height
                visible: card.progress > 0.005
                color: Xian.goldHi
                opacity: 0.45 + 0.3 * Math.sin(card.xian.ctx.ambientTime * 2.2)
            }
        }
    }

    Rectangle {
        id: corners

        anchors.fill: parent
        radius: Xian.radiusNormal
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: cover
        maskEnabled: true
        maskSource: corners
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: Xian.radiusNormal
        color: "transparent"
        border.width: 1
        border.color: Xian.alpha(Xian.paper, 0.08)
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 18 * card.sc
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16 * card.sc

        // The face, or the name's initial as a seal.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 62 * card.sc
            height: width

            Rectangle {
                id: faceMask

                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Xian.alpha(Xian.gold, 0.16)
                border.width: 1
                border.color: Xian.alpha(Xian.gold, 0.5)
            }

            Text {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: card.name.charAt(0)
                font.family: Xian.serif
                font.pixelSize: 28 * card.sc
                color: Xian.goldHi
            }

            Image {
                id: face

                anchors.fill: parent
                source: card.xian.host.avatar
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: false
            }

            MultiEffect {
                anchors.fill: face
                source: face
                visible: face.status === Image.Ready
                maskEnabled: true
                maskSource: faceMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * card.sc

            Row {
                spacing: 8 * card.sc

                Text {
                    id: nameText

                    text: card.name
                    font.family: Xian.serif
                    font.pixelSize: 21 * card.sc
                    color: Xian.paper
                }

                Text {
                    anchors.baseline: nameText.baseline
                    text: "道友"
                    font.family: Xian.cjk
                    font.pixelSize: 13 * card.sc
                    color: Xian.gold
                }
            }

            Text {
                text: card.xian.realm.zh + (card.xian.realm.stageZh ? " · " + card.xian.realm.stageZh : "")
                font.family: Xian.cjk
                font.pixelSize: 14 * card.sc
                color: Xian.gold
            }

            Text {
                text: (card.xian.realm.en + (card.xian.realm.stageEn ? ", " + card.xian.realm.stageEn : "")).toUpperCase()
                font.family: Xian.serif
                font.pixelSize: 10 * card.sc
                font.letterSpacing: 1.5 * card.sc
                color: Xian.paperDim
            }
        }
    }

    // The level large, the qi to the next and the streak.
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 20 * card.sc
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1 * card.sc

        Text {
            anchors.right: parent.right
            text: Xian.numeral(card.xian.shownLevel)
            font.family: Xian.cjk
            font.pixelSize: 32 * card.sc
            color: Xian.paper
        }

        Text {
            anchors.right: parent.right
            text: ("Qi " + Math.floor(card.xian.shownXp - card.xian.levelFloor) + " / " + (card.xian.levelCeil - card.xian.levelFloor)).toUpperCase()
            font.family: Xian.serif
            font.pixelSize: 10 * card.sc
            font.letterSpacing: 1.5 * card.sc
            color: Xian.paperDim
        }

        Text {
            anchors.right: parent.right
            text: (card.xian.host.stats.streak + "-day streak · 悟道 " + card.xian.host.stats.achieved + "/" + card.xian.host.stats.achievable).toUpperCase()
            font.family: Xian.serif
            font.pixelSize: 10 * card.sc
            font.letterSpacing: 1.5 * card.sc
            color: Xian.paperDim
        }
    }
}

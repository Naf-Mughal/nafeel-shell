pragma Singleton

// Shared choreography. cascade(container): its visible children arrive one
// after another, each fading in and rising a few pixels on the expressive
// spatial curve, staggered: the panel opens, then its content settles in
// item by item (rather than all at once).

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property int stagger: Tokens.dur(35)
    readonly property int rise: 10

    function cascade(container: Item, delay: int): void {
        if (!container || Tokens.reduceMotion)
            return;
        // Step inside single wrappers (a Loader, a Flickable's content) to the
        // items themselves.
        for (let depth = 0; depth < 3; depth++) {
            const shown = Array.from(container.children).filter(c => c.visible && c.width > 0 && c.height > 0);
            if (shown.length !== 1 || shown[0].children.length < 2)
                break;
            container = shown[0];
        }
        let i = 0;
        for (const child of container.children) {
            if (!child.visible || child.width === 0 || child.height === 0)
                continue;
            const anim = cascadeAnim.createObject(child, {
                target: child,
                delay: (delay ?? 40) + Math.min(i, 10) * root.stagger
            });
            anim.start();
            i++;
        }
    }

    Component {
        id: cascadeAnim

        SequentialAnimation {
            id: seq

            property Item target
            property int delay
            readonly property Translate shift: Translate {
                y: root.rise
            }

            Component.onCompleted: {
                target.opacity = 0;
                target.transform = [shift];
            }

            PauseAnimation {
                duration: seq.delay
            }
            ParallelAnimation {
                NumberAnimation {
                    target: seq.target
                    property: "opacity"
                    to: 1
                    duration: Tokens.anim.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedDecel
                }
                NumberAnimation {
                    target: seq.shift
                    property: "y"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.expressiveSpatial
                }
            }
            ScriptAction {
                script: {
                    seq.target.transform = [];
                    seq.destroy();
                }
            }
        }
    }
}

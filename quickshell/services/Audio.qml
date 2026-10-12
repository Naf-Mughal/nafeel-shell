pragma Singleton

// The default output and input, live from PipeWire.

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    // Output devices, and apps playing sound.
    readonly property var sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream)

    // Apps recording from a microphone right now.
    // Streams recording a microphone. Not ones capturing what's playing (a
    // sink's monitor), such as the shell's own visualiser.
    readonly property var recorders: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream && n.name !== "caelestia-shell" && n.properties["stream.capture.sink"] !== "true")
    readonly property bool micInUse: recorders.length > 0

    function streamName(n: var): string {
        return n.properties["application.name"] || n.description || n.name;
    }

    function setSink(n: var): void {
        Pipewire.preferredDefaultAudioSink = n;
    }

    // Up to 150%, like Noctalia's own volume steps allow.
    function setVolume(v: real): void {
        if (sink?.ready && sink.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }

    function toggleMute(): void {
        if (sink?.ready && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setSourceVolume(v: real): void {
        if (source?.ready && source.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }

    function toggleSourceMute(): void {
        if (source?.ready && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source, ...root.streams]
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// What's playing, for the lock's guqin corner: the playing MPRIS player, else
// the first one there is.
Singleton {
    id: root

    readonly property var activePlayer: Mpris.players.values.find(p => p.playbackState === MprisPlaybackState.Playing)
        ?? Mpris.players.values[0] ?? null
    readonly property bool isPlaying: activePlayer ? activePlayer.playbackState === MprisPlaybackState.Playing : false
    readonly property string title: activePlayer ? activePlayer.trackTitle : ""
    readonly property string artist: activePlayer ? activePlayer.trackArtist : ""

    function playPause() {
        if (activePlayer && activePlayer.canTogglePlaying)
            activePlayer.togglePlaying();
    }

    function next() {
        if (activePlayer && activePlayer.canGoNext)
            activePlayer.next();
    }

    function previous() {
        if (activePlayer && activePlayer.canGoPrevious)
            activePlayer.previous();
    }
}

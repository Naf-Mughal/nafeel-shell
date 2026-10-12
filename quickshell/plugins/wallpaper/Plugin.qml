import QtQuick
import Quickshell

// The wallpaper studio plugin's root: the stores (Wallhaven's pictures,
// motionbgs's live wallpapers) and rotation; the picker (Mod+W) is its
// manifest drawer. The wallpaper itself, the library and the theme are the
// kernel's (Wallpapers, Theme): with this off the desktop keeps its
// wallpaper, nothing picks, fetches or rotates.
Scope {
    readonly property Wallhaven wallhaven: Wallhaven {}
    readonly property MotionBgs motionbgs: MotionBgs {}
    readonly property WallpaperRotation rotation: WallpaperRotation {}
}

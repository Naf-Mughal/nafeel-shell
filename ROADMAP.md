# Shell roadmap

The plan for nafeel/shell: from a Quickshell shell hosted by Noctalia to a full desktop stack of
its own. Kept here so any session (or person) can see where things stand. Update it in the same
change as the work: tick items, move finished stages to Done with a date.

## Where it's going

One cohesive system, owned end to end:

| Layer | Runs on |
|---|---|
| Compositor | umbriel |
| Login | SDDM running the shell's own lock as its theme (cave-abode look) |
| Desktop | `nafeel-shell` (all UI and services) + the `Nafeel` native module + small scripts |
| Lock | the same cave-abode code, inside the shell |
| Apps | themed from one pigment palette by the shell's own template engine |

The look, in layers:

1. **Base: ink and paper xianxia** with Ryoku's discipline: sumi ink (dark) or rice paper (light),
   paper fibre and grain, ink wash, hairlines not boxes, Latin + CJK gloss pairs, tracked mono
   labels, seals, nothing loud.
2. **Colour: M3 roles, pastel pigments.** Roles from the wallpaper, then a pigment pass that
   desaturates them into ink-wash and paper tones nudged toward mineral pigments (cinnabar,
   jade/malachite, azurite, ochre-gold). Cinnabar stays fixed.
3. **Frosted paper** (Ryoku's recipe): translucent surfaces (80-90%, a setting) over a small
   compositor blur with grain and a touch of vibrancy, frost only inside the shapes.
4. **Motion: one physics engine** better than Caelestia's goo and Ryoku's blob: real GPU blobs,
   ink-bleed edges, split and merge, surface tension, surfaces that soak in like ink.
5. **Primitives and layout directives built for this desktop**, so every new panel comes out
   cohesive without hand-tuning.

Sources: Caelestia and Ryoku (GPL-3.0) and Noctalia (MIT) may be ported directly (the user wants
direct code reuse where it's good: Noctalia's clipboard and idle 1:1), with their
notices kept (see NOTICE). Take mechanics wholesale; restyle visuals into the one language above.

## Now

- [x] **Verify Alt+Tab by hand** (user confirmed 2026-10-11): hold Alt + Tab through the list; a quick tap flips to the last
  window without the panel showing; Shift+Tab back; Esc cancels; over a fullscreen app. Note
  whether Tab inside the `switcher` submap is instant or goes through the keybind (~70 ms).
- [x] Verify screenshots keep panels (user confirmed 2026-10-11): `Mod+Shift+S` with a panel open; the capture button with
  the capture panel pinned.
- [x] Commit the work so far (native module, switcher, previews, capture fix) as a known-good
  point to roll back to.
- [x] Add NOTICE: Caelestia, Ryoku (and what it inherits: DankMaterialShell MIT, OkShell),
  Cave Abode, Noctalia (MIT).

## Stage D: design system (before rebuilding anything else)

Everything built after this uses it, so nothing needs restyling later.

- [x] **D1 Frosted paper** (2026-10-11). Plugin setting `paper` (90 / 85 / 80% or solid, default
  85) -> Tokens.transparency -> the frame and lock frame surfaces; containers stay solid sheets.
  umbriel `[[layer_rule]]` for `^nafeel-shell` (blur, ignore_alpha 0.05, not optimized) written
  into the shell's fragment unless solid; global `[appearance.blur]` set to Ryoku's recipe
  (radius 4, 1 pass, noise 0.01, saturation 1.17; config backed up). Paper fibre (`fibre`
  uniform: strands at three angles + speckle, slightly denser and lighter) in frame.frag.
- [x] **D2 Pigment palette** (2026-10-11; reworked the same day). `wallpaper-palette/bin/pigment.py`,
  the plugin's default variant `pigment`. Reading after Okmain (dgroshev.com/blog/okmain): the
  full image averaged down in Oklab (no sRGB mud, no noise colours), pixels weighted by place
  (centre 1, borders 0.3), neutrals split off (ink and paper), colour pixels clustered by
  weighted k-means++ in the a/b plane and merged when they're one colour. Roles: surfaces are
  black and white (the wallpaper's own ink and paper, barely tinted; the paper look is the
  shell's frost, not coloured surfaces); accents are the real colours: the most covering leads
  (primary), the most vivid of the rest pops (tertiary), the next real colour is secondary;
  nothing invented (only the fruit-salad style blends); a faint colour that covers little stays
  faint; a black-and-white wallpaper gives a black-and-white palette (errors stay red). Warm
  colours keep their names as they lighten (ochre -> yellow, not peach; red -> coral, not
  pink). Styles: `pigment`, `-vibrant`, `-expressive`, `-fruitsalad`, `-soft`.
  Tried and dropped (the user found them bad): coloured-paper surfaces and a watercolour wash
  in the frame shader; maybe revisit later.
- [x] **D3a Blob engine** (2026-10-11). Ryoku's blob engine (GPL-3.0, from Caelestia) ported
  into the `Nafeel` module: BlobGroup, BlobRect, BlobInvertedRect, BlobShape, BlobMaterial and
  its shaders (`native/src/blob*`, `native/shaders/blob.*`). Extended: the paper (ink wash,
  grain, fibre, gilded line just outside the shape) in the blob shader; BlobRect `axisAligned`
  (corners bounce outward, no tilt) and `maxStretch`. FrameWindow draws the frame as a
  BlobInvertedRect and every drawer as a BlobRect (per-corner radii: only desktop-facing corners
  round; no sinks), all inside one layer faded as a whole: the frosted paper, without seams
  where shapes overlap. The goo is the BlobRect spring in C++ (Drawer reads `rawDeformMatrix`);
  the JS goo is gone. The lock frame still uses shaders/frame.frag.
- [x] **D3b Wet ink** (2026-10-11): each blob has a wetness (BlobRect `wet` from outside, plus
  its own speed, eased: quick to wet, slower to dry; packed in the rect data). Wet ink bleeds:
  a ragged edge (two octaves of noise on the boundary, up to ~3.5 px) that dries crisp; and
  surface tension: wet shapes join each other and the frame with a fatter neck (fillet up to
  2.5x) that tightens to the exact fillet as they settle. Drawers are wet as they open, near
  closed, and while moving fast. (Padding widened so the neck isn't clipped.)
- [x] **Out of the bar** (2026-10-11): corner panels have no seed bubble; they start flush with
  their bar, run along it first (progY leads opening) and then come out of it (progX), and
  closing pull back into the bar first and then shrink along it. Wet follows how far out of the
  bar it is; the ragged bleed toned to 1.6 px. Mist and spirit motes removed from all drawers
  (they made the motion janky).
- [x] **The bar morphs** (2026-10-11): a panel is the bar's own edge swelling out. `emerge`
  (0..1, how far out of the bar) drives it: while low, the desktop-facing corners are as round as
  the blob allows (a smooth swell of the bar) and square up as it comes out; the join neck is up
  to 4x the fillet while wet (wet = 1 - emerge), so the bar's edge flows into the swell and it
  melts back the same way; the content inks in only from 50% out (and leaves first), so nothing
  seems to slide out from under the bar.
- [x] **Part of the bar** (2026-10-11, after several rounds with the user): a corner panel grows
  out of its corner point in both directions (a spring per axis, width a touch brisker; a try at
  "length at once, only the edge moves" read as coming from the left and was reverted); the content sits in an `out` window clipped at the bar's and border's
  edges and rides the moving edges (a corner's free corner), so it never appears from behind the bar's icons, which act as the panel's tabs
  (content starts right beside them). The spring goo stays, but pinned: BlobRect `anchor` (the
  side it grows out of; offset = (M - I)(C - P)) so only the free edge squashes and stretches and
  the root never comes loose from the bar; the content window gets the same transform. Tried and
  dropped on the way: the bar's drawn width growing; a round swell with a fat neck; content
  inking in late.
- [x] **Tempo** (2026-10-11): Tokens.tempo scales all motion (tried 2 and 1.5; the user settled
  on 1, brisk 0.7). Durations scale by it (Tokens.dur, now used by every hard-coded duration but the lock theme's); every spring
  goes through Tokens.springK/dampK (stiffness / t^2, damping / t: same bounce, slower), and the
  goo's stiffness and damping scale the same way.
- [x] **Goo pill** (2026-10-11): the bar groups' active pill is a BlobRect in its own BlobGroup
  (the pill colour), so it stretches along its travel between controls and settles with a
  squash (deformScale 2.2x the frame's goo).
- [x] **D3c More motion** (2026-10-11): the goo pill splits: moving to another control it leaves
  a tail BlobRect behind that shrinks away (Tokens.anim.normal) while the pill springs off, the
  two joined by a neck (group smoothing 8) that thins and snaps. Ink-soak reveal: a drawer's
  content window gets a layer effect (shaders/soak.frag) only while revealing: the content soaks
  out from the side or corner it grows from behind a blotchy fbm front, on its own pace
  (`soak`: 900 ms in, InOutQuad, so it isn't over before it shows; normal out). Fixed after the
  user's first look: a tail was dropped when the pill re-entered a group mid-fade (a full-width
  line); now tails only between controls, the pill appears in place when entering, and the split
  is stronger (smoothing 10, slower tail, goo 3.5x). Second look: the pill jumped because the
  brief no-control gap while the pointer crosses between icons reset it; BarGroup now moves the
  pill imperatively (onActiveControlChanged: spring + tail between controls, instant from
  nowhere, held 220 ms through gaps). The soak was hidden by Choreo.cascade (content still
  faded while the front passed): cascades removed from frame panels, the soak is their reveal.
  Third look: the soak runs once from empty each time content arrives (Drawer.resoak(): on open,
  and CornerPopout on switching kinds while open), recedes on close; the notifications group's
  pill was pale on pale (secondary on secondaryContainer), now the group's inverse like the
  sound group's; the workspace indicator's gold plate is a goo blob with a splitting tail too
  (the user loves it). Fourth look: a hairline across the bar was a pill/tail sliver on its way to
  nothing (wide, sub-pixel tall); tails and pills now leave their BlobGroup below 1 px, and
  BlobShape repaints when its group changes (leaving a group, Ryoku's engine kept drawing the
  last frame: a stale pill). Reduced
  motion: a plain fade.
- [x] **D4 Primitives** (2026-10-12). Roles in Colours (`roleFill/roleInk/roleSubInk`: "paper"
  at a level 0..4, or primary/secondary/tertiary/error at "soft" | "strong" | "ghost"), so fill
  and ink always pair the same way. `Surface`: the one container (role, emphasis, level, shape
  preset, hairline outline; interactive: state layer, press bounce, Expressive morph,
  clicked/rightClicked/middleClicked; `ink`/`subInk` for children). `Sheet` (titled section:
  eyebrow, Latin + gloss heading, trailing actions, content), `Chip`, `Strip` (scrolling row
  or column, wheel, optional centred carousel). IconButton, Tile, ListRow and ButtonGroup
  rebuilt on Surface (same APIs). Wallpaper chips and strip and the Alt+Tab carousel moved onto
  Chip/Strip. Remaining hand-made surfaces (about 79 Rectangle/StyledRect in modules) move over
  with D5.
- [x] **D5 Layout directives** (2026-10-12). `Panel` is the root of every bar panel: its heading
  (PanelHeader: a Surface badge, Latin title + gloss, subtitle, actions) when it has a title,
  then its sections on the panel rhythm (`density`: comfortable | compact). The rest of a
  panel's layout comes from the frame (where it grows from, the morph between panels sharing a
  corner, the joins into the bars, the ink-soak reveal). All bar panels (Sound, Audio,
  Brightness, Connections: Network/Bluetooth, Battery, Session, Notifications, Media, Capture)
  are Panels; their cards are Surfaces by role (paper levels; primary/error heroes; secondary
  badges and picks); PopoutHeader is PanelHeader under its old name. Also converted: plain
  cards in the command center Home tab, Notes, the polkit prompt and the dock items. Left as
  they are on purpose: progress tracks, workspace miniatures, Capture's big custom buttons,
  the lock theme's own drawing. Not yet on Panel: the command center tabs, action center and
  OSD (their own layouts).

## Stage N: replace Noctalia

Noctalia keeps running as the fallback until N7.

- [x] **N1 Easy wins** (2026-10-12). Night light: a native `NightLight` (wlr-gamma-control;
  Noctalia's Kelvin->RGB curve and ramps, MIT, ported; a fade in ~50 K steps; retries when
  another client holds the gamma; off fades to 6500 K and releases, so the compositor restores
  the original), Noctalia's own night light switched off in the shell's fragment. Caffeine: a
  Wayland IdleInhibitor held by each frame. Brightness through brightnessctl. Weather fetched by
  the shell (Open-Meteo geocoding + forecast every 15 min, cached in
  ~/.cache/nafeel-shell/weather.json, same data shape), plugin setting `location` (seeded from
  Noctalia's). Session actions run by the shell (Session.run: lock = the shell's lock, suspend
  = lock then sleep, log out / restart / shut down through graceful-power; IPC `session run`).
  Keys (umbriel config, backed up): brightness via brightnessctl, volume/mute via wpctl, Mod+L
  the shell's lock, Mod+Shift+L `shell-msg suspend`, Mod+Ctrl+Escape umbriel's dpms-off.
  Also: the OSD uses the panels' M3 slider (draggable, the percentage on its icon button), and
  IconButton has a `caption`: volume, mic and brightness show their percentage under the icon
  in the sound panel and the action center.
  Left for later stages: dark/light toggle (N5, theme engine), Notes' Noctalia fallback and the
  file-manager plugin (N7 cut-over), Mod+S settings (N7).
- [x] **N2 Clipboard** (2026-10-12): Noctalia's clipboard stack ported 1:1 into the `Nafeel`
  module under `native/src/noctalia/` (MIT; files as they are: ClipboardService, its poll
  source, the encrypted file store, secret store and storage key provider, secure buffer,
  virtual keyboard, atomic file and file utils; shims only for config_types (StorageKeySource)
  and the logger, on Qt logging). `Clipboard` (singleton, `native/src/clipboard.*`) runs it on a
  worker thread with Noctalia's poll loop and its own Wayland connection (seat, ext/wlr data
  control, virtual keyboard), Noctalia's defaults (keep from closed apps, 100 entries, auto
  paste: Ctrl+Shift+V text, Ctrl+V images, 220 ms after the panel lets go). Same history files
  and keyring key, so the history carried over. Noctalia's clipboard is off while the shell
  runs (`clipboard_enabled = false` in the fragment: one writer). Panel: top-left corner
  `bar:clipboard` (search, list with pinned first, text/image preview, paste / pin / delete,
  clear unpinned; double-press to confirm; Up/Down, Enter, Delete, Ctrl+P); the bar icon,
  `:` in the command center, its calculator copy and `shell-msg clipboard` (Mod+V) use it.
  C++ standard raised to 23 (Noctalia's). Fixed after: the frame's Esc handler took the focus
  from a panel's search field when a click pinned a hover preview (arrows and typing died in
  the clipboard and wallpaper picker); it now claims the focus only when nothing has it.
- [x] **N3 Capture** (2026-10-12; user verified region shot, region recording, pause/mic): the nafeel/capture plugin's service ported into the shell's
  Capture service (same API for the dialog, bar and lock). Region picker is the shell's own
  (modules/capture/Picker.qml, as Noctalia's with confirm off: every screen frozen, dimmed
  outside the selection, drag and let go; a click takes that screen; Esc / right click cancel);
  screenshots are cut out of the frozen still (ShaderEffectSource + grabToImage at the screen's
  scale), saved to ~/Pictures/Screenshots and copied as an image (Clipboard.copyImageFile).
  Recordings: gpu-screen-recorder via bin/record.sh (60 fps, very high, auto codec, cursor;
  system audio / mic as the dialog says; stop SIGINT, pause SIGUSR2, live mic mute with pactl),
  region from the picker. Locked: both take the monitor with gpu-screen-recorder.
  Notifications with preview and Open / Edit / Folder / Delete: bin/capture-notify. Prefs and
  state in ~/.local/state/nafeel-shell/capture (prefs carried over); IPC target `capture`;
  shell-msg snip/record, the lock's tokens (CaveAbode) use it. Still Noctalia: "Edit" and the
  dialog's Annotate (Noctalia's annotator) until the shell has its own (see N7); the plugin
  stays enabled as the fallback and for annotate's save.
- [x] **Keyboard in panels** (2026-10-12, user verified): corner panels are made afresh on open
  and CornerPopout hands the pinned one the keyboard (Panel `focusTarget`), as the wallpaper
  picker does; the frame no longer asks for activeFocusItem (a Quickshell window has none).
- [x] **N4 Wallpaper** (2026-10-12, user verified): the shell draws it (modules/background: a Background layer
  per screen, namespace `nafeel-wallpaper` so the frost rule leaves it alone, decoded at screen
  size); a new one soaks in from the middle (the panels' soak front, 1.6 s). Wallpapers owns
  the path (~/.local/state/nafeel-shell/wallpaper.json, Noctalia's adopted on first run),
  set/random locally, IPC target `wallpaper` (set/random/get); Session.wallpaper follows it.
  Noctalia's wallpaper is off (`[wallpaper] enabled = false`) but still gets the path
  (`wallpaper-set`) so the palette plugin retints, until N5 moves the palette step in.
- [x] **N5 Theme engine** (2026-10-12): `bin/nafeel-theme` (Python, stdlib), built on all three:
  Noctalia's template language (matugen-compatible formats and filters), manifests (template.toml,
  requires_path, hooks, the kdeglobals merge, the multi-client rule) and built-in templates
  (theme/templates/builtin, MIT), so its community templates run unchanged (copied once from
  Noctalia's cache to ~/.local/share/nafeel-shell/templates/community); Ryoku's core/apps split and
  kdeglobals merge; Caelestia's live terminal recolour (OSC to every pty), `{{ $role }}`, user
  templates (~/.config/nafeel-shell/templates) and post hook. On top, the shell's tokens:
  paper_0..4, ink/ink_sub/ink_faint/rule, the pigments lead/pop/second (pigment.py now gives each
  a hex), alpha.base/layers, radius.*, font.*, short forms (`paper.2.hex`) and token arguments
  (`| set_alpha alpha.base`). One document, ~/.local/state/nafeel-shell/theme.json: Colours reads it,
  every template renders from it. `nafeel-theme update` = palette (theme/palette/extract.py +
  pigment.py, only when wallpaper/variant changed) + build + apply, ~0.7 s; config in
  ~/.config/nafeel-shell/theme.toml (taken from Noctalia's template ids). The Theme service runs it
  on wallpaper, paper or radius change; IPC `theme update|force`. Noctalia's templates are off
  (fragment) and the wallpaper-palette plugin is disabled (settings.toml, backup
  .bak-shell-n5). Fixed on the way: Noctalia's 16-role expansion tinted neutral wallpapers (umbriel's
  unfocused border was reddish). Known: Spicetify's hook fails (no Spotify at /opt/spotify).
- [x] **Bus, staged actions, shell-level ink** (2026-10-12): `Bus` (pub/sub with retained topics) and
  `Subscribe {}`; `ActionService` (a panel stages, closing it commits; held by a service, as a
  Singleton can't derive from another); Wallpapers uses it: the picker chooses (選 seal) and its
  palette is staged meanwhile (`nafeel-theme update --stage` -> theme-next.json), closing sets it.
  `Ink` runs one transition for the whole shell: every window's `InkStill` takes a still, the
  colours (Colours.load) and the wallpaper (Background swaps its pre-decoded slot) change underneath,
  the stills soak away from the centre (shaders/inkwipe.frag: wet front, tide line only where the
  shell drew); the apps' templates (`nafeel-theme commit`) start at 55% so they land with it.
  Colours no longer watches theme.json; Theme conducts. Gotchas: Qt 6.12's JS compiler segfaults on
  optional calls (`f?.()`, `a[b]?.()`); `Transition` clashes with Qt Quick's type (hence `Ink`).
  LockKeys keeps its 350 ms poll: LEDs send no events and modifiers only reach the focused client.
- [x] **N5b Theme next** (2026-10-12). Translucent apps: `{{ alpha.apps }}` (the Theme page's app
  opacity, 78% like foot had) in foot ([colors-dark] alpha; foot.ini's own alpha removed), kitty
  (background_opacity) and alacritty (window opacity); `{{ alpha.gtk }}` on GTK's window, view,
  headerbar and sidebar colours (1 unless "Translucent GTK apps"). Which apps: the Theme page picks
  built-in templates (builtin.toml's catalog) and community ones (Noctalia's catalog,
  api.noctalia.dev/templates, cached a day; a chosen one is downloaded on the next update, every
  file md5-checked, all or nothing) as `kind: "multi"` chips; nafeel-theme reads theme.core /
  theme.community over theme.toml (`list --json`, `catalog`). Light/dark: mode Auto (light from
  the weather's sunrise to sunset, else 07-19; nafeel-theme resolves it, the shell rebuilds when
  the day turns). A change made on the Theme page soaks in under the ink when the colours change.
- [x] **Dock rework** (2026-10-12, user: the panel-wide hover was janky). Pins are a setting
  (Dock page; default Chrome, foot, Dolphin, VS Code; right-click still pins), matched to windows
  by desktop entry. The command center's icon sits in the dock's middle (apps split either side):
  resting on it opens the command center, a click opens/closes it; the dock itself no longer opens
  anything on hover. Resting on a running app shows its windows in a PopupWindow above the icon
  (ListRows; click to go there); the hover-shown dock stays while the popup is hovered
  (ShellState.keep / unpreviewLater). No magnification (the user found the Mac-style scaling bad):
  a hovered app gets a soft Surface behind its icon. Delays and "other running apps" are settings.
- [x] **Themed app icons** (2026-10-12, user: dock icons unequal, should follow the theme).
  `AppIcon` primitive: every app the same size, a Surface tile on the shell's rounding in its
  kind's colour role with a Material Symbol (Apps.kind: from the desktop entry's freedesktop
  categories, a data table: browser globe, terminal, folder, code, mail, chat, music, video,
  graphics, game, office, calculator, settings, system); an app of no known kind gets its own
  icon tinted (MultiEffect colorization) on the tile. Dock page "Icon style": themed / tinted /
  original. The dock's command center tile matches.
- [x] **Dock previews and bare icons** (2026-10-12, user: tiles looked bad; previews should be
  real window pictures and part of the panel). AppIcon draws no tile: the kind's symbol at full
  size in its role colour (or the app's icon tinted / as is); the middle command center symbol
  matches. Resting on a running app sets ShellState.dockPreview and the dock's own drawer grows by
  DockPreview: live WindowThumbs (16:10, the Dock page's preview height) with titles, click to go
  there; leaving the dock puts them away (closeDelay); resting on the middle symbol opens the
  command center instead. The PopupWindow list is gone. IPC `shell dockPreview <app>`.
- [x] **Dock window count** (2026-10-12): the running indicator is a round Surface badge on the
  icon's top-right corner with the number of open windows in Chinese numerals (Xian.digits,
  十, then 多), CJK serif, strong primary while focused; nothing under the icons, so the row stays
  even. Icons are the apps' own by default (Dock page: icon style, icon size), each the same box
  centred in the dock.
- [x] **Polkit panel** (2026-10-12): out of the bottom centre now (the dock and the command
  center make way while it's up), rebuilt as a Panel: what's asking (its icon and message on a
  paper Surface), who to authenticate as when there's a choice (Chips), the password (shakes and
  says so when wrong; Esc cancels the request), Caps Lock pointed out, Details (the action id),
  Cancel / Authenticate as role Surfaces. Checked with a real `pkexec true` (timed out, cancelled).
- [x] **Paper fibre in dark mode** (2026-10-12, user liked the light-mode texture): the fibre was
  a brightness multiplier, invisible on dark ink; frame.frag and blob.frag add a lift that grows
  as the paper darkens, so the strands read the same in both modes. Appearance gains "Paper
  texture" (0-200 %, off at 0), no longer tied to frosted paper.
- [x] **N6 Idle** (2026-10-12): services/Idle, a port of Noctalia's idle manager
  (src/idle/idle_manager.cpp: behaviours in order, resume actions, locked timeouts, the pre-action
  fade that later behaviours join and input cancels, overlay torn down before actions) onto
  Quickshell's IdleMonitor (ext-idle-notify, respecting Wayland idle inhibitors: caffeine, video
  in browsers/mpv). Profiles stay idle-kit's (profiles/ac.toml, battery.toml), read by
  bin/idle-profiles and switched by the charger; the Cave Abode lock command maps to the shell's
  lock; screen_off = umbriel dpms-off/on. modules/idle/GraceOverlay is the fade. The lock keeps
  its motion and live wallpaper until the dim stage (Idle.dimmed), then goes still, then suspend
  (was a blind 25 s doze). idle-kit keeps battery saver and warnings; its idle-profile stops
  feeding Noctalia while ~/.local/state/nafeel-shell/idle-managed exists, idle-suspend asks the
  shell first. Bus idle.*; IPC `idle status|reload`. Still Noctalia's: the ScreenSaver D-Bus name
  (apps that only inhibit over D-Bus aren't seen until N7 moves it into the native module).
- [x] **N6b Annotator** (2026-10-12): the shell's own (Noctalia's tools and keys as the reference;
  its code wasn't copied). Native `AnnotationCanvas` (QQuickPaintedItem, native/src/annotationcanvas.*):
  move, brush (smoothed), highlighter, line, arrow, rectangle, circle (fill), text (the serif),
  numbering (renumbers), blur (downscale + box blur), eraser, crop; Shift snaps (45°, squares); one
  undo step per gesture (50); committed annotations cached, the live one drawn on top; `save(path)`
  renders at the image's resolution and crops. modules/capture/Annotator.qml: the image over the
  dimmed desktop on the focused screen, a toolbar of Surfaces (undo/redo, 12 tools, fill, 8 colours,
  S/M/L + [ ], copy, save, done, close); each tool keeps its colour and size (capture/annotate.json).
  Done/Save write a new screenshot, copy it and post the usual notification; Copy only copies. Flows:
  the capture panel's "Edit"/`capture request screenshot edit` picks a region then annotates it;
  the notification's Edit and `annotate open <file>` open a file; IPC `annotate open|region|close`.
  Checked with a scripted qmltestrunner pass over every tool (save + crop).
- [x] **N7 Settings and cut-over** (2026-10-12; tag `pre-n7` before it). Settings came with F3. The
  shell no longer needs Noctalia: native `ScreenSaver` (org.freedesktop.ScreenSaver at
  /org/freedesktop/ScreenSaver and /ScreenSaver, Inhibit/UnInhibit, an app's inhibitors go when it
  leaves the bus; the name is queued so it's taken the moment another holder lets go; Idle holds
  off while inhibited); type-to-launch in umbriel's overview (modules/overview/OverviewCapture,
  Noctalia's behaviour: letters open the launcher, Enter/Esc toggle, arrows move; Panels page);
  shell-msg without Noctalia fallbacks (lock falls back to cave-abode's standalone lock, suspend to
  systemctl); the lock no longer pings cave-abode; services/Noctalia.qml gone; the capture plugin
  disabled (capture.toml retired). umbriel autostarts bin/nafeel-shell (Mod+Shift+X removed; config
  backup .bak-n7-*); the supervisor asks `qs list` whether a shell runs and waits while a
  crash-restarted copy runs. Cut over live: Noctalia stopped, the shell started by umbriel; the
  shell owns Notifications and ScreenSaver, polkit registered, struts in place. umbriel's
  plugins/shell.toml and shell-frost.toml are now static (the plugin service only rewrites them if
  Noctalia runs). Rollback: `umbriel msg spawn:/home/nafeel/.local/opt/noctalia-edges/bin/noctalia`
  (and the autostart line in umbriel's config). Left: noctalia-greeter until Stage G.

## Stage W: wallpaper studio (asked 2026-10-12; Ryoku's ryogami wall-ui, MIT, as the base)

Ryoku's picker (ryogami wall-ui, ~23k lines QML + a Go indexing daemon) taken apart and rebuilt in
the shell's ink-and-paper style on the shell's own services (Wallpapers is an ActionService; Bus;
the theme's staging and Ink).

- [x] **W1 Library** (2026-10-12): `nafeel-theme index` -> theme/palette/library.py: 480 px WebP
  thumbnails in ~/.cache/nafeel-shell/thumbs, each wallpaper's lead pigment (Oklab hue bucket 0-11,
  99 = black and white), chroma, lightness and up to four pigment colours; incremental by
  size+mtime (746 walls: ~3 min first, seconds after; 15 MB). Wallpapers: a quick `find` first, the
  index merged in, filters (folder, colour, dark/light, favourites, search), sorts (name, colour
  wheel, recent, most used), favourites and use counts (wallpaper-library.json), progress on the
  Bus. Picker: WallCard (印 current, 選 chosen, pigment dots, star), SliceView (the user's pick:
  Ryoku's slice carousel, each slice one shader, shaders/slice.frag; no ListView (its estimates of unbuilt
  slices made the band jump now and then): every slice placed by arithmetic from one sprung
  position, a ring of slots reused (a slot keeps its wallpaper while on screen); drag slides it; a fanned hand was tried and
  dropped), StripView, MosaicView; colour swatches in Oklab
  hues; Ctrl+F favourite, Ctrl+1/2/3 views; the drawer's size follows the view (slice: nearly full
  width). IPC `wallpaper view <slice|strip|mosaic>`.
- [x] **W2 Wallhaven store** (2026-10-12): services/Wallhaven (after Ryoku's WallhavenService and
  download process): search via curl (query, General/Anime/People, Sketchy/NSFW with the new
  `wallhaven_key` plugin setting, sort top/hot/latest/random/views/favourites, top range, ratio,
  at-least size = the screen, colour = our Oklab swatch mapped to Wallhaven's nearest allowed
  colour), paged (the next page when the view nears the end), downloads three at a time with
  progress, https + w.wallhaven.cc only, `file` checks it's an image, then into
  ~/Pictures/Wallpapers/wallhaven/wallhaven-<id>.<ext>; the library rescans and the download is
  chosen (or set, if the picker closed). The picker's storefront button switches the same views
  to the store (StoreBadge: resolution, progress, tick). IPC `wallpaper source library|store`.
  Sharper previews: the open slice decodes the file (or the store's full image) at its real size
  over the thumbnail; thumbnails are 720 px q88 (were 480 px q82: grainy), old ones pruned.
- [x] **W3 Per-monitor and rotation** (2026-10-12): Wallpapers.outputs (a screen's own over the
  main one; wallpaper.json { path, outputs }); the main screen (the first) drives the colours, any
  other changes only its picture (Theme.goOutput: decode there, then the ink); Bus
  "wallpaper.output.<name>" (retained), preloads carry their output. The picker shows a screen row
  ("Every screen" / each output, "· colours" on the main) when more than one is connected.
  services/WallpaperRotation (after Ryoku's playlist and day/night rotation, MIT): every
  15 min..1 day, from everything / favourites / what's shown / a folder, shuffled (no repeats until
  the pool goes round) or in order; day & night folders swapped at the weather's sunrise/sunset
  (06/18 without it); paused while locked, catches up after; rotation.json; the picker's
  autorenew button swaps the filter row for these settings; IPC `rotation next|toggle|on|off`.
  (`Rotation` silently resolved to Qt Quick's transform type: hence the long name.)
- [x] **W4 Live wallpapers** (2026-10-12, local files): videos (mp4/webm/mkv/mov/m4v) in the library
  (a frame a second in for the thumbnail and colour; the palette already took a frame), ▶ badge,
  the open slice plays a muted preview. Background's slots are WallSlot: an Image or a
  MediaPlayer + VideoOutput (no audio output), ready after the first frames, so the ink works to
  and from video; playing only while visible, not locked, no fullscreen window on that screen,
  and on AC unless `liveOnBattery`. Session.wallpaper is a still (stillOf) for the home tab etc.
  VA-API decodes (AMD Lucienne). Measured over a still: 4K +345 MB / +12% CPU; 1080p +137 MB / +8%
  (mpvpaper: 255 MB, same CPU). "Live wallpaper resolution" setting: Original (default) | 1080p |
  720p, the last two a copy made once by the indexer (Lanczos, CRF 16). An adaptive mode (full on
  an empty workspace, 720p behind windows, handing over mid-play) was built and dropped at the
  user's request; it also showed two decoders at once stall (the 4K one never left Loading). The
  picker shows the indexer's animated WebP preview (3 s, 12 fps, 720 px, ~0.5 MB) instead of
  decoding the video. Plus "Live wallpapers on battery" (hold still / keep playing). Gotcha: a
  Live store (2026-10-12):
  services/MotionBgs reads motionbgs.com's public result pages (search, or the latest paged),
  downloads from its own /dl/4k|hd/<id>/ links into ~/Pictures/Wallpapers/live, `file` checks
  it's a video; the picker's store has a provider chip (Wallhaven | ▶ Live · motionbgs) and a
  4K/HD chip; IPC `wallpaper source live`. moewalls was not added: its downloads sit behind an
  encoded, ad-gated token.
- [ ] **W5 Steam Workshop** (on hold 2026-10-12: no Steam here, and the Workshop needs an account
  that owns Wallpaper Engine; pick up if those change). Wallpaper Engine videos (and scenes, if a renderer is viable) from the
  Steam library; from Ryoku's SteamWorkshop service.

## Stage F: native features (asked 2026-10-12)

The custom Noctalia plugins and the user's wishes become shell features: a service (Bus) +
declared settings + a settings page. Order agreed: notes, dashboard, then N6b, then the settings
foundation and folding idle-kit / graceful-power / cave-abode / app-theming / file-manager in.

- [x] **F1 Notes** (2026-10-12): services/NotesStore (Markdown files in ~/Documents/Notes, as
  Noctalia's notes keep them; a Scratchpad always on top, pins, last open in notes.json; create,
  rename, trash via gio, jot) and the notes drawer (Mod+X, 780x600): list with search beside the
  editor, title renames the file, autosave (and on switch/close), Markdown preview, pin, delete
  (twice); Ctrl+N/F/↑/↓/P/E/S/Delete. IPC `notes jot|create <text>`.
- [x] **F2 Dashboard** (2026-10-12; Caelestia's, on the shell's primitives at the user's ask): a
  Panel (PanelHeader with the tabs as a ButtonGroup, ShellState.dashTab) out of the top centre on
  hover or Mod+Shift+D. Dash tab is Caelestia's grid (WeatherCard, UserCard, MediaCard tall,
  ClockCard, the calendar, ResourcesCard); Media (the record large, players as chips in a Sheet,
  Media.choose); Performance (CPU hero: Gauge + Sparkline + temperature + GPU; memory; storage;
  network rx/tx sparklines; the battery as a tank; readings are ListRows, colours from roles);
  Weather (the command center's). SystemStats gained GPU busy, swap, disk, network rates and
  history. New primitives: Gauge, Sparkline. Mod+D: the desktop (an empty workspace, and back;
  Umbriel.toggleDesktop, IPC `desktop toggle`).
- [x] **F2b Visualiser and lyrics** (2026-10-12): Caelestia's native audio chain in Nafeel
  (src/caelestia: PipeWire collector, provider, CavaProvider, Service/ServiceRef; cava's core vendored
  in src/cava, MIT, on FFTW; cava_init gained a scaling mode upstream: linear). services/Visualiser,
  components/RadialVisualiser (strokes out of the record; capture only while shown). services/Lyrics
  in QML: lrclib /get then /search, LRC parsed, the current line follows the player, cached in
  ~/.cache/nafeel-shell/lyrics; Caelestia's NetEase fallback left out (an unofficial endpoint). The
  Media tab: the record + visualiser, players, lyrics centred on the line being sung. A native
  rebuild needs a full shell restart (QML reloads keep the old .so).
- [x] **F2c Caelestia, faithfully** (2026-10-12, after the user's screenshots: the first pass
  matched content, not design): m3shapes (soramanew, Apache-2.0) vendored and built as the M3Shapes
  module (the M3 Expressive shapes and morphs Caelestia uses). New primitives: CircularProgress
  (arc, gap, track), LinearProgress (M3 bar with stop), ShapeImage (image cut to an M3 shape),
  ShapeBadge (icon on a shape in a role). Dash: Caelestia's clock (hour ••• minute, AM/PM),
  weather, user (gem badge, face in a pill, thought bubble with the compositor, clamshell uptime),
  calendar (weekend tertiary, today on a sunny shape; the command center's too), resources as
  three rings, media (cover in a 12-cookie under a progress arc, title/album/artist, controls,
  bongocat while playing). Performance: CPU/GPU hero cards (ring round the icon, name, temperature
  bar, usage in a shape morphing cookie → sunny → burst), storage and memory gauges, network with
  rx/tx sparklines and totals, the battery as a filling tank. Media: drifting M3 shapes, cover in a
  9-cookie with the visualiser starting on its edge (distanceAtAngle), details, shuffle/prev/wide
  play/next/repeat, lyrics, players. Inline components that used outer ids failed ("X is not a
  type"): they live in Perf*.qml files. IPC `shell dash <tab>`.
- [x] **F2d** (2026-10-12): the user preferred the first Dashboard tab to Caelestia's: restored
  (user card over the wallpaper, stacked clock, plain calendar, resource bars, the spinning record)
  with one addition, bongocat under the media controls. Media and Performance keep the later work.
- [x] **F2e** (2026-10-12): media controls all 52 px on the shell's rounding (MediaControl), the
  player chosen from a full-width selector that lists the players above it (PlayerSelect); storage
  as compact as memory, one gauge per physical drive (SystemStats.disks from lsblk: mounted file
  systems summed per disk; system drive first).
- [x] **F2f** (2026-10-12): the player selector pinned to the controls' 52 px row. The user
  signed off: **the dashboard is complete.**
- [x] **F2g** (2026-10-12, at the user's ask): the OSD and the dashboard are one panel. While the
  dashboard is open the OSD drawer stays shut and the OSD shows in the dashboard's heading, between
  the title and the tabs (PanelHeader/Panel `middle`; OsdView sliderWidth/buttonSize/labelWidth).
  The privacy OSD no longer fires for the shell's own visualiser (Audio.recorders skips sink-monitor
  captures and `caelestia-shell`).
  Then (user: the pill was rounded wrong) a shared `modules/osd/OsdInline`: a paper Surface on the
  shell's rounding (rounding.morph, like the tabs), as tall as the heading's controls; the wallpaper
  picker hosts it too (between its title and tools) and the OSD drawer stays shut over it.

- [x] **F3a Settings foundation and panel** (2026-10-12). The shell owns its settings:
  `~/.config/nafeel-shell/settings.json` (config/Settings: values, set/reset, watched for outside
  edits; the first run took the plugin's state/settings.json). A feature declares its settings
  beside it as a `SettingsPage` of `SettingItem`s (key, kind choice|toggle|text|number, icon,
  label, description, section, default, options with icons) and reads `page.v.<key>`: the default
  lives in one place. Pages so far: Appearance (Tokens: radius, paper, immersion, motion),
  Wallpaper (Wallpapers: live resolution, on battery, Wallhaven key), Weather (location).
  modules/settings/SettingsPanel: a top-centre drawer (Mod+S, `shell-msg settings`, falls back to
  Noctalia's), pages as ListRows, each setting from the panels' primitives (choice: ButtonGroup;
  on/off: ListRow + StyledSwitch; text: TextField; number: StyledSlider; under a Sheet heading
  whose trailing action resets it; SectionLabel eyebrows, hairlines between). The plugin's
  [[setting]]s are gone from Noctalia's window; service.luau reads the radius from the shell's file;
  the frosted-paper layer rule is the shell's own umbriel fragment (plugins/shell-frost.toml,
  services/Umbriel, included from umbriel's config); nafeel-theme reads the new file. Chip follows
  the shell's rounding instead of a full pill. IPC `settings get|set|reset|list`,
  `shell settings <page>`.
- [x] **F3a+ More settings, nothing hard-coded** (2026-10-12, at the user's ask: "no hard coded
  things unless absolutely necessary"). New pages: Panels (hover close delay, Alt+Tab reveal),
  Theme (mode, palette variant, contrast, terminal flavour, theme apps, live terminals;
  nafeel-theme reads them over theme.toml; the dark-mode tiles set the mode), Display (night light
  warmth), Capture (folders, copy, fps, quality, cursor), Notifications (toast time, the app's own
  timeout, toasts at once, history kept), On-screen display (how long, and each kind on/off),
  Time & units (services/Time: 24-hour clock everywhere a time shows, °C/°F, wind unit), Media
  (visualiser bars), Notes (folder); Wallpaper gained the library folder and Rotation (its settings
  moved from rotation.json; the picker's controls set the same keys; options built from the
  folders), Weather the refresh interval. Pages can be shared (WallpaperRotation adds a section to
  Wallpaper; Settings.itemsOf/valuesOf). Choices with more than five options are wrapping Chips.
  Settings set before the file is read are applied only where the file has no value. The panel
  starts every feature with settings (services are lazy) and its page list is a Strip.
- [x] **F3b Power & Idle** (2026-10-12). Idle builds its four stages (dim, lock, screen off,
  sleep) from the Power & idle page: plugged-in and battery timeouts (0 = never; the same values
  idle-kit's profiles had), the warning fade, the dim level, sleep waiting for quiet audio and how
  long. Dim is the shell's (Brightness.quietly: never raised, restored on return, no OSD);
  sleep-when-quiet polls uncorked streams / MPRIS every 10 s, then Session suspend. Power: battery
  saver below a level (Power Saver; back to Balanced on plug-in; only acts when its own choice
  changes, and a restart doesn't undo a hand-picked profile), low / critical warnings
  (notify-send), `Power.low` follows the low level (bar, panels, lock). SettingItem gained
  `format: "duration"` and `zeroLabel`. idle-kit is disabled; its Noctalia hooks file is retired
  (~/.config/noctalia/idle-kit.toml.bak-retired-*); `[lockscreen] lock_before_suspend = false`
  moved into the shell's Noctalia fragment; bin/idle-profiles is gone. The idle-kit plugin dir
  can be deleted.
- [x] **Scrolling** (2026-10-12, user: panels scrolled too slowly, and the vertical wheel moved
  sliders). `WheelScroll` (one notch = the Panels page's scroll step, 160 px by default, with a
  short glide; quick notches add up; a touchpad 1:1) drives the new `Scroller` primitive (every
  panel's scrolling column: settings, notifications, action center, Wi-Fi list, notes, clipboard
  text, command center popout tabs, lyrics) and `Strip`. StyledSlider takes only a sideways
  scroll. Checked with a qmltestrunner pass (scroll over a slider, adding notches, both ends,
  sideways slider).
- [x] **F3c Session, Lock, Theme, Default apps** (2026-10-12). Session: graceful restart / shut
  down / sign out in services/Session (every window asked to close, then after the grace time a
  critical notification names the holdouts with "… anyway" / "Cancel", closing them carries on;
  settings: close apps first, grace, how long to ask). Lock (CaveAbode, same Session & lock page):
  lock before sleep (a logind delay inhibitor + PrepareForSleep from gdbus; locks, then a moment
  for the lock to cover, then sleep), lock colours (the theme's, from the shell's own palette now,
  or the original ink and gold). Theme page: Qt and KDE apps (services/AppTheming writes umbriel's
  app-theming.toml env and qtengine's config.json: follow the theme, icon theme and widget style
  from what's installed, fonts and size, single click). Default apps page (services/DefaultApps:
  file manager among the installed ones, for Mod+E, xdg-mime folders and the FileManager1 D-Bus
  service). graceful-power, app-theming and file-manager are disabled (their Noctalia file
  retired); cave-abode keeps only the greeter's mirror (its sleep watcher is off:
  lock_before_suspend = false). Long-running helpers (inhibitor, gdbus, udevadm) now die with the
  shell (setpriv --pdeathsig), so restarts leave nothing behind. Still to do with N7: the
  ScreenSaver D-Bus name (Noctalia holds it while it runs).

## Stage G: greeter (SDDM, decided 2026-10-12)

The user chose SDDM over greetd + noctalia-greeter (Noctalia is going) and over a Quickshell
greeter. SDDM runs QML themes in its own greeter (sddm-greeter-qt6), not Quickshell: no
PanelWindow, Pam/Greetd services or the shell's singletons. The cave-abode surface is plain
QtQuick apart from Xian/Tokens/CaveAbode/Colours and LockContext, so it is shared, not copied.

- [x] **G1 Shared cave-abode** (2026-10-12). The lock's look (themes/xianxia: XianxiaSurface,
  Formation, IncenseSticks, Xian; and Glyph, HoldArea, CaptureImage, LockInput, LockTheme) imports
  nothing of the shell: it takes `ctx` (LockContext in the shell) and `host` (ShellLockHost: type,
  rounding, palette, wallpaper + its live player, avatar, battery, cultivation, media, capture) as
  plain properties and reaches its siblings by relative path; Xian and LockTheme are plain
  QtObject singletons fed by the host.
- [x] **G2 The login screen: the shell's own lock in SDDM** (2026-10-12; the user dropped greetd
  altogether). sddm/: Main.qml, GreeterContext (LockContext's interface and phases, sddm.login,
  SDDM's power actions, test-mode demo verdicts that start over), GreeterHost (the host's shape,
  filled from the shell's export; no battery, media or capture at login). services/GreeterExport
  writes GreeterData.qml (palette, follow, type, rounding, 24 h, cultivation, user), the wallpaper
  (a live one as the video it plays, with a full-size first frame from ffmpeg) and ~/.face to
  ~/.local/state/nafeel-shell/greeter and /var/lib/nafeel-greeter (when it exists). bin/nafeel-greeter
  assembles the theme from sddm/ + the shared lock files + VideoLayer + the lock shaders, with the
  qmldirs plain Qt needs; `test` runs sddm-greeter-qt6 --test-mode (checked: live wallpaper,
  palette, name, realm, streak, clock). Gotcha: an id named like the surface's property (`ctx: ctx`)
  binds the property to itself; ids are greeterCtx / greeterHost.
- [x] **G3 Switch** (2026-10-12, the user ran both; SDDM enabled, greetd disabled, takes over at the next boot; the installed theme loads clean in test mode): `sudo bin/nafeel-greeter install` (theme to
  /usr/share/sddm/themes/nafeel, /var/lib/nafeel-greeter for the shell's export, seeded with the
  current one, /etc/sddm.conf.d/10-nafeel.conf Current=nafeel), then `sudo bin/nafeel-greeter
  switch` (greetd off, SDDM on). The greeter runs on SDDM's default X11 (xorg-server installed);
  a Wayland greeter under umbriel can come later.
- [x] **G4 Retire the old login** (2026-10-12; the user confirmed SDDM after a reboot): greetd,
  greetd-agreety and noctalia-greeter removed (snapper snapshots 177/178; /var/lib/noctalia-greeter
  and /etc/greetd moved to /var/backups/greetd-retired-20261012). The cave-abode Noctalia plugin
  and its config moved to ~/.local/share/noctalia/retired-20261012; its standalone lock lives on
  as fallback-lock/ (bin/lock: Quickshell's Lock.qml, Noctalia's lock as the last resort if
  installed), which shell-msg runs for lock and suspend when the shell is down.

## Stage R: the shell as a kernel, every feature a plugin (asked 2026-10-12)

The shell is the kernel (the frame and drawer host, Settings, the primitives, the Bus, ShellState,
Colours/Theme/Ink, umbriel, IPC, the plugin registry, the native module); every feature is a
plugin that ships with it ("batteries") and can be switched off, loading nothing then.

- [x] **R1 Move** (2026-10-12): the shell lives in `~/.local/share/nafeel-shell` (its data folders,
  palette-venv and templates, beside the code, not synced); the Noctalia glue (plugin.toml,
  service.luau, translations) is gone; umbriel's autostart, shell-msg, cave-abode's lock fallback
  point here; dotfiles keep it as `.local/share/nafeel-shell/`.
- [x] **R2 Kernel plugin registry** (2026-10-12): services/Plugins reads
  `quickshell/plugins/<id>/plugin.json` ({ id, name, gloss, icon, description, default, root,
  drawers: [{ name, entry, edge, along, corner, width, height (a number or "content"), keyboard,
  hoverZone }] }). shell.qml loads each enabled plugin's root (Plugins.instance(id) finds it);
  FrameWindow makes each enabled plugin's drawers (joined to the frame's shape; the input mask has
  16 slots now); the Settings panel's Plugins page switches them (key plugin.<id>); a page goes
  with its plugin. IPC `plugins list|enable|disable`. Quickshell limits found: a folder becomes a
  `qs.*` module only if the shell imports it at startup, so plugin folders can't hold singletons
  or name their sibling files as types: a plugin's files are served through Quickshell's scheme
  (Qt.resolvedUrl from the kernel, so they import qs.config/services/components), its root makes
  its objects from their URLs (Qt.createComponent), and they go when it's switched off.
- [x] **R3 Pilot: notes** (2026-10-12): plugins/notes (plugin.json, Plugin.qml making the
  NotesStore, Notes.qml the drawer, reading `Plugins.instance("notes").store`). Checked: drawer
  from the manifest, the `notes` IPC and settings page come and go with the switch.
- [x] **R3b Plugin folders are modules** (2026-10-12): bin/nafeel-shell writes
  quickshell/PluginModules.qml (one `import qs.plugins.<id>` per plugin folder) before every start
  and shell.qml loads it, so Quickshell registers each folder: a plugin's files use each other by
  name like any QML (a plugin that's off is registered, nothing in it made). Adding a plugin folder
  needs a restart. Plugin services are still objects its root makes (not singletons), so they go
  when it's switched off.
- [x] **R4a dashboard** (2026-10-12): plugins/dashboard (no root: it only shows kernel services);
  the manifest drawer (top, width 1100 capped to the screen, height "content" springing).
  FrameWindow.drawerOpen(name) for the kernel's checks (the OSD hides under it).
- [x] **R4b overview, apps, polkit** (2026-10-12): plugins/overview (root OverviewCapture; the
  plugin switch replaced its setting), plugins/apps (AppTheming + DefaultApps as objects its root
  makes), plugins/polkit (the agent is its root; the prompt is a manifest drawer). Manifest drawers
  gained `openWhen` (opens by itself while the root's property is true, on the focused screen) and
  `modal` (takes the keyboard; the dock makes way): FrameWindow.modalHere replaced polkitHere.
  Kernel/platform services stay services (Audio, Brightness, Bluetooth, Network, Power, Media,
  SystemStats, Session, Time, Weather, Apps, Wallpapers, Theme/Colours/Ink, Bus, ShellState,
  Settings, Umbriel); plugins take their own services along.
- [x] **R4c osd** (2026-10-12): plugins/osd (the Osd state is its root; OsdView the manifest
  drawer; OsdInline for the dashboard and the wallpaper picker, hidden when the plugin is off).
  Manifest drawers gained `yieldTo` (shut while those drawers are open), `width: "content"` and
  `padding`.
- [x] **R4d capture** (2026-10-12): plugins/capture (Capture, Picker, Annotator; the root makes
  Capture and hands it to the other two). The bar's capture button and its panel, and the lock's
  capture tokens, use `Plugins.instance("capture").capture` and hide while it's off (bindings read
  it with ?. guards; calls stay plain, since optional calls crash Qt 6.12). CapturePopout still
  sits with the bar's popouts until the bar is a plugin.
- [x] **R4e wallpaper studio** (2026-10-12): plugins/wallpaper (picker and its views; Wallhaven,
  MotionBgs and WallpaperRotation as objects its root makes; the picker a manifest drawer sized by
  its view: content drawers now get `availableWidth`). The kernel keeps Wallpapers (current,
  library, outputs, setting it, the theme) and asks the plugin for its stores (none while it's off).
- [x] **R4f idle, lock** (2026-10-12): plugins/idle (Idle and GraceOverlay; the lock reads
  `Plugins.instance("idle").idle` and dozes on its own timer without it), plugins/lock (the lock
  screen, its theme in themes/xianxia, CaveAbode, LockStats and GreeterExport as the plugin's own
  singletons, made by its root so they run from the start). PluginModules now imports every folder
  with QML inside a plugin (themes/xianxia), so plugins can have singletons and sub-folders; a
  plugin's singletons are made only when used (a plugin off from the start loads nothing; one
  switched off mid-session keeps its singletons until the next start). nafeel-greeter and
  LockPreview point at plugins/lock.
- [x] **R4g notifications, switcher, visualiser** (2026-10-12): plugins/notifications (the
  server, toasts as a corner drawer opening on `hasPopups`, the action center on the bottom-right
  corner), plugins/switcher (its keys a frame overlay: manifests gained `overlays`; the carousel an
  `openIf` drawer over fullscreen windows), the visualiser and lyrics into plugins/dashboard.
- [x] **R4h the bar as slots** (2026-10-12): manifests gained `slots` (items for `bar.top`,
  `bar.actions`, `bar.middle`, `bar.bottom`: components/PluginSlot, a Repeater whose controls the
  capsule's pill finds through their loaders), `popouts` (a bar corner's panel, "bar:<name>") and
  `tabs` (command center tabs). plugins/workspaces (from extensions/), plugins/clipboard (its root
  keeps the history from login); capture and notifications bring their buttons, panels and tab.
  services/Extensions and extensions/ are gone; a capsule hides while its slot is empty.
  Plugin roots, drawers and overlays now sit on stable models (every plugin, active while it's on),
  so switching one plugin no longer rebuilds the others (a lock or a recording survives it).
- [x] **R4 done.** The kernel keeps the frame and its chrome (bar, dock, command center, the
  sound/connect/battery/session corner), Settings, the primitives and the platform services
  (Audio, Brightness, Bluetooth, Network, Power, Media, SystemStats, Session, Time, Weather, Apps,
  Wallpapers, Display, Theme/Colours/Ink, Bus, ShellState, Umbriel).

## Ideas, not scheduled

- Custom panels as plugins (a Ryoku Rashin-style dashboard).
- Dock window thumbnails (WindowThumb).
- A layout studio for the bar (Ryoku's Bar Studio idea) on top of D5.
- Trim memory (about 230 MB PSS with everything opened once).

## Notes

- Open (2026-10-12 11:36): during a dashboard preview a second full shell instance appeared as a
  child of the running shell (loaded the config, found polkit/notifications taken) and segfaulted in
  QWindow::setFlag during polish; the running shell was unaffected. Not the supervisor. Watch for
  a repeat (coredumpctl; by-id logs).
  Repeated 2026-10-12 17:40 (pid 1163913): the same SIGSEGV in QWindow::setFlag from
  QQuickWindowPrivate::polishItems, during a hot reload of FrameWindow; Quickshell restarted
  itself (the restarted process runs as plain `/usr/bin/quickshell`, so pgrep -f on the -p
  command line misses it: use `qs list`). Hot reloads also leave the polkit agent unregistered
  ("an authentication agent already exists"); a full restart fixes it.

- Screen-share picker belongs to xdg-desktop-portal-umbriel, not Noctalia: unaffected by N7.
- The native module needs a rebuild after a Qt minor upgrade (`native/build.sh`).

## Done

- Phases 0-7 (2026-10-10/11): plugin + supervisor, full Material scheme from wallpaper-palette,
  frame of four bars and four corners (Noctalia-style concave joins, ink wash, gilded edge),
  bar with spring active pill, corner and edge popouts (Wi-Fi, Bluetooth, audio, display, battery,
  media, notifications, capture, session), dock + command center (search, `>` `=` `:` modes, 12
  tabs), notification server + toasts + action center, OSD (volume, mic, brightness, toggles),
  cave-abode lock inside the shell and its frame, switch-over from Noctalia's bars.
- Polish passes 1-4: settings (radius preset, immersion, motion), tokens, goo (BlobRect port),
  two-spring corners, choreography (cascade, toast glide), M3 state layers and press bounce, dock
  magnify, mist and spirit motes, glosses and 时辰 touches, empty states, lock cohesion.
- 2026-10-11: `Mod+Shift+S` goes straight to region picking (closing any open panel first);
  `Mod+Shift+R` opens the capture popout on Record, starts on a second press, stops while
  recording (the old keys' flow, without Noctalia's centred dialog). Tried windows flush against
  the bar; reverted, the user prefers the gap.
- 2026-10-11: **wallpaper picker** (`Mod+W`, top-centre drawer: folder chips, a strip of the
  library centred on the current wall, set through Noctalia), **notes** (`Mod+X`, right-edge pad,
  autosaved to `~/.local/state/nafeel-shell/notes.md`), **polkit prompts** (the shell's agent in a
  top-centre drawer; Noctalia's `polkit_agent` GUI override moved out of settings.toml so the
  plugin can switch it, restored on disable), **the rest of the OSD** (caffeine, night light,
  Caps/Num Lock, keyboard layout, microphone in use, screen being shared; `Mod+Ctrl+C` routes
  through the shell). Frame shader now has ten drawer slots.
- 2026-10-11: left bar regrouped: above the session button only [tray] and [sound · connections ·
  battery], every left-bar panel now a corner panel (bottom-left: session, sound = volume + mic +
  brightness + display toggles + now playing, connections = Wi-Fi | Bluetooth, battery; top-left:
  notifications, capture); the middle bar popout is gone. OSD is a pill from the top centre. Any
  pinned panel takes the keyboard (Esc closes it); clicks inside pinned panels no longer close them
  (the outside-click catcher ignores open drawers). Wallpaper picker: search field, arrow keys move
  the selection, Enter sets, Esc closes.
- 2026-10-11: **native module** (`native/`, QML import `Nafeel`, built by `native/build.sh`, by the
  supervisor if missing, and by install.sh): `WindowThumb` captures one window over
  ext-image-copy-capture on its own Wayland connection, only while visible, damage-driven with an
  fps cap, scaled to its drawn size on the CPU and uploaded as a texture; `Keyboard.modifiers()`
  reads the held modifiers. **Shell Alt+Tab** replaces Noctalia's: a top-centre carousel of live
  previews (MRU order from the umbriel service, windows on every screen's active workspace),
  Alt+Tab / Alt+Shift+Tab through `shell-msg switch`, letting go of Alt commits (key release, or
  the modifier state once it has the keyboard, so a quick tap works; the carousel waits 140 ms before showing, so a quick tap never shows it), umbriel `switcher` submap
  while open (Ctrl+Alt+Escape leaves it). Binds and Mod+Tab live in the shell's umbriel fragment;
  the nafeel/window-switcher plugin is disabled (its fragment backed up and removed). **Workspace
  previews**: windows on other workspaces are live thumbnails now.
- 2026-10-11: screenshots keep open panels again (the capture plugin's old rule, which `shell-msg
  snip` had broken by closing them): `Mod+Shift+S` leaves any panel up to be captured, and the
  capture popout's button keeps the popout in the shot when it's pinned (clicked open); a hover
  preview, or a recording, still closes it first.
- 2026-10-11: workspace previews draw inactive workspaces as a miniature desktop: the wallpaper in
  a scaled copy of the shell's frame (bar-thick border, rounded hole, gilded edge), live window
  tiles on it; an empty one shows 空 on a chip of the shell's surface.
- 2026-10-11: fixed bar groups vanishing for good after a fullscreen window or the lock (a group
  hid itself when no child was visible, and children count as invisible while the bar is hidden).

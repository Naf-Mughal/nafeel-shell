#!/usr/bin/env bash
# Installs or upgrades nafeel-shell. Run it from the clone, which must be
# ~/.local/share/nafeel-shell:
#
#   git clone https://github.com/Naf-Mughal/nafeel-shell ~/.local/share/nafeel-shell
#   ~/.local/share/nafeel-shell/install.sh [--packages]
#
# Upgrade: `git pull && ./install.sh`. Safe to rerun.
# Everything it changes is backed up as *.bak-nafeel-shell-<time> first.
set -euo pipefail

root=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
want="$HOME/.local/share/nafeel-shell"
stamp=$(date +%Y%m%d-%H%M%S)
umbriel_dir="$HOME/.config/umbriel"
umbriel_conf="$umbriel_dir/config.toml"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
ask() { local a=""; { read -rp "$1 [y/N] " a </dev/tty; } 2>/dev/null || true; [[ "$a" == [yY]* ]]; }
# Process ids of the Quickshell instances whose config path contains $1.
qs_pids() { qs list --all 2>/dev/null | awk -v pat="$1" '/Process ID:/ { pid = $3 } /Config path:/ && index($0, pat) { print pid }'; }

if [[ "$root" != "$(readlink -f "$want")" ]]; then
    echo "nafeel-shell must live in $want (it's at $root)." >&2
    echo "Move it there, or: git clone <repo> $want" >&2
    exit 1
fi

# --- Packages -----------------------------------------------------------------
# Dolphin + the KDE portal: the default file manager and the file picker apps
# open through the portal (plugins/apps/DefaultApps.qml writes the choice).
# plasma-integration (KDE's Qt platform theme), kconfig (kwriteconfig6) and
# the Darkly style: how Qt/KDE apps take the theme (plugins/apps/AppTheming.qml).
pkgs=(quickshell cmake base-devel qt6-base qt6-declarative qt6-shadertools
      wayland wayland-protocols libsodium libsecret libxkbcommon fftw libpipewire
      pipewire wireplumber brightnessctl libnotify python gpu-screen-recorder
      dolphin xdg-desktop-portal-kde plasma-integration kconfig darkly-bin)
# Any umbriel will do (the dotfiles build a patched one, umbriel-nafeel-git,
# which provides umbriel): only ask for umbriel-git when none is installed.
pacman -T umbriel >/dev/null 2>&1 || pkgs+=(umbriel-git)
if [[ "${1:-}" == "--packages" ]]; then
    say "installing packages"
    if command -v paru >/dev/null; then
        paru -S --needed "${pkgs[@]}"
    else
        sudo pacman -S --needed "${pkgs[@]}" || warn "some packages are AUR-only; install paru, or get them yourself"
    fi
fi
missing=()
for c in quickshell qs umbriel cmake brightnessctl wpctl notify-send python3; do
    command -v "$c" >/dev/null || missing+=("$c")
done
if ((${#missing[@]})); then
    warn "not found: ${missing[*]} (rerun with --packages, or install them yourself)"
fi

# --- Native module --------------------------------------------------------------
say "building the native module"
if ! "$root/native/build.sh"; then
    warn "the native module didn't build; the shell retries at start (log: \$XDG_RUNTIME_DIR/nafeel-shell-build.log)"
fi

# --- Keybind entry ---------------------------------------------------------------
mkdir -p "$HOME/.local/bin"
ln -sfn "$root/bin/shell-msg" "$HOME/.local/bin/shell-msg"
chmod +x "$root"/bin/* "$root"/fallback-lock/bin/* 2>/dev/null || true
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) warn "~/.local/bin isn't on PATH; umbriel's shell-msg keybinds need it" ;; esac

# --- umbriel: autostart the shell, include its fragments -------------------------------
if [[ -f "$umbriel_conf" ]]; then
    mkdir -p "$umbriel_dir/plugins"
    frag="$umbriel_dir/plugins/shell.toml"
    if [[ -f "$frag" ]] && ! cmp -s "$root/umbriel/shell.toml" "$frag"; then
        cp -a "$frag" "$frag.bak-nafeel-shell-$stamp"
    fi
    cp "$root/umbriel/shell.toml" "$frag"

    cp -a "$umbriel_conf" "$umbriel_conf.bak-nafeel-shell-$stamp"
    python3 - "$umbriel_conf" "$want/bin/nafeel-shell" <<'PY'
import re, sys
path, shell = sys.argv[1], sys.argv[2]
text = open(path).read()

def section(name):
    """(start, end) of a [name] table's body, or None."""
    m = re.search(r'(?m)^\s*\[' + re.escape(name) + r'\]\s*$', text)
    if not m:
        return None
    n = re.search(r'(?m)^\s*\[', text[m.end():])
    return m.end(), m.end() + n.start() if n else len(text)

# autostart: drop Noctalia and any older shell path, then add this one.
s = section("general")
if s is None:
    text = text.rstrip("\n") + f'\n\n[general]\nautostart = ["{shell}"]\n'
else:
    body = text[s[0]:s[1]]
    m = re.search(r'(?m)^(\s*)autostart\s*=\s*\[(.*?)\][ \t]*(?:#[^\n]*)?', body, re.S)
    if m:
        items = re.findall(r'"([^"]*)"', m.group(2))
        keep = [i for i in items if "noctalia" not in i and "nafeel-shell" not in i]
        new = ", ".join(f'"{i}"' for i in keep + [shell])
        body = body[:m.start()] + f"{m.group(1)}autostart = [{new}]" + body[m.end():]
    else:
        body = f'\nautostart = ["{shell}"]' + body
    text = text[:s[0]] + body + text[s[1]:]

# include the shell's fragments (optional: shell-frost.toml appears once the shell runs).
want = ["plugins/shell.toml", "plugins/shell-frost.toml"]
s = section("include.optional")
if s is None:
    files = ", ".join(f'"{f}"' for f in want)
    text = text.rstrip("\n") + f"\n\n[include.optional]\nfiles = [{files}]\n"
else:
    body = text[s[0]:s[1]]
    m = re.search(r'(?m)^(\s*)files\s*=\s*\[(.*?)\]', body, re.S)
    items = re.findall(r'"([^"]*)"', m.group(2)) if m else []
    items += [f for f in want if f not in items]
    line = "files = [" + ", ".join(f'"{f}"' for f in items) + "]"
    body = body[:m.start()] + m.group(1) + line + body[m.end():] if m else "\n" + line + body
    text = text[:s[0]] + body + text[s[1]:]

open(path, "w").write(text)
PY
    if cmp -s "$umbriel_conf" "$umbriel_conf.bak-nafeel-shell-$stamp"; then
        rm -f "$umbriel_conf.bak-nafeel-shell-$stamp"
    else
        say "umbriel config updated (backup: config.toml.bak-nafeel-shell-$stamp)"
    fi
    if command -v umbriel >/dev/null && ! umbriel config validate >/dev/null 2>&1; then
        warn "umbriel rejects the new config; restoring the backup"
        umbriel config validate || true
        cp -a "$umbriel_conf.bak-nafeel-shell-$stamp" "$umbriel_conf"
    fi
else
    warn "no $umbriel_conf; start umbriel once, then rerun this"
fi

# --- Login screen ------------------------------------------------------------------
greeter_ok=0
grep -qs 'Current=nafeel' /etc/sddm.conf.d/10-nafeel.conf && greeter_ok=1
if ((greeter_ok)); then
    if ask "Update the login screen theme (sudo)?"; then
        sudo "$root/bin/nafeel-greeter" install
    fi
elif ask "Use the shell's lock as the login screen (SDDM; replaces greetd if it's on; sudo)?"; then
    sudo "$root/bin/nafeel-greeter" install
    sudo "$root/bin/nafeel-greeter" switch
fi

# --- Power tuning (laptops) -----------------------------------------------------------
# Charger-following system tuning: wifi power save, USB autosuspend, writeback
# on battery (udev rule + service; system/power-tune).
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    if [[ -x /usr/local/bin/nafeel-power-tune ]]; then
        if ! cmp -s "$root/system/power-tune/nafeel-power-tune" /usr/local/bin/nafeel-power-tune &&
            ask "Update the battery power tuning (sudo)?"; then
            sudo "$root/system/power-tune/install"
        fi
    elif ask "Install the battery power tuning: wifi power save, USB autosuspend, writeback (sudo)?"; then
        sudo "$root/system/power-tune/install"
    fi
fi

# --- Running session -----------------------------------------------------------------
if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v umbriel >/dev/null; then
    running=$(qs_pids "$root/quickshell/shell.qml")
    if [[ -n "$running" ]]; then
        if ask "Restart the running shell now to load this version?"; then
            for p in $running; do qs kill --pid "$p" >/dev/null 2>&1 || true; done   # its supervisor starts it again
        fi
    elif ask "Start the shell in this session now?"; then
        umbriel msg "spawn:$root/bin/nafeel-shell" >/dev/null
    fi
fi

cat <<EOF

Done. If the shell isn't on screen yet, log out and back in.
  Upgrade later:  cd $root && git pull && ./install.sh
  Settings:       Mod+S (kept in ~/.config/nafeel-shell/settings.json; the old
                  plugin's settings carry over on the first start)
  Logs:           \$XDG_RUNTIME_DIR/nafeel-shell.log
EOF

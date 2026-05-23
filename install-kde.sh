#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DNF="${DNF:-dnf}"
CHANGED=()
SKIPPED=()
LAST_BACKUP_PATH=""
STATE_DIR="$HOME/.local/state/fedora-plasma-glow-kit"
STATE_FILE="$STATE_DIR/install.state"

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
ui_intro 2>/dev/null || true
ui_title "Fedora Plasma Glow Kit KDE" 2>/dev/null || echo "Fedora Plasma Glow Kit KDE"

ask() {
  local prompt="$1" default="${2:-n}" reply
  case "${FEDORA_PLASMA_GLOW_ASSUME:-}" in
  yes | YES | y | Y | true | TRUE | 1) return 0 ;;
  no | NO | n | N | false | FALSE | 0) return 1 ;;
  esac
  read -r -p "$prompt [$default] " reply || true
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]]
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

record_state() {
  local key="$1" value="$2"
  mkdir -p "$STATE_DIR"
  grep -Fqx "$key=$value" "$STATE_FILE" 2>/dev/null || printf '%s=%s\n' "$key" "$value" >>"$STATE_FILE"
}

backup_path() {
  local target="$1" stamp
  LAST_BACKUP_PATH=""
  stamp="$(date +%Y%m%d-%H%M%S)"
  if [ -e "$target" ] || [ -L "$target" ]; then
    cp -a "$target" "$target.bak.$stamp"
    LAST_BACKUP_PATH="$target.bak.$stamp"
    CHANGED+=("backed up $target")
  fi
}

show_file_diff() {
  local before="$1" after="$2"
  [ -n "$before" ] || return 0
  [ -f "$before" ] || return 0
  [ -f "$after" ] || return 0
  ui_section "Diff: $after" 2>/dev/null || printf '\nDiff: %s\n' "$after"
  diff -u --label "before:$after" --label "after:$after" "$before" "$after" || true
}

install_kde_packages() {
  local pkgs=(kdeplasma-addons papirus-icon-theme variety qt6-qttools) pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  sudo "$DNF" install -y "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && record_state dnf "$pkg"
  done
  CHANGED+=("installed KDE customization packages")
}

install_taskbar_widget_packages() {
  local pkgs=(plasma-desktop plasma-workspace kdeplasma-addons kde-connect kdeconnectd bluedevil) pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  sudo "$DNF" install -y "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && record_state dnf "$pkg"
  done
  CHANGED+=("installed KDE taskbar/widget packages")
}

install_bundled_plasmoids() {
  local src_root="$ROOT_DIR/configs/kde/plasmoids" target_root="$HOME/.local/share/plasma/plasmoids" src target
  [ -d "$src_root" ] || {
    SKIPPED+=("no bundled KDE plasmoids found")
    return
  }
  mkdir -p "$target_root"
  for src in "$src_root"/*; do
    [ -d "$src" ] || continue
    target="$target_root/$(basename "$src")"
    if [ -e "$target" ]; then
      SKIPPED+=("KDE plasmoid already exists: $(basename "$target")")
      continue
    fi
    cp -a "$src" "$target"
    CHANGED+=("installed bundled KDE plasmoid $(basename "$target")")
  done
}

install_bluetooth_headphone_codecs() {
  local pkgs=(bluez bluedevil pipewire pipewire-pulseaudio pipewire-alsa wireplumber libldac libfreeaptx fdk-aac-free ffmpeg gstreamer1-plugin-openh264 gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly) pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  sudo "$DNF" install -y --skip-unavailable "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && record_state dnf "$pkg"
  done
  sudo systemctl enable --now bluetooth || true
  CHANGED+=("installed Bluetooth/headphone audio packages and enabled bluetooth")
}

install_rounded_corners_effect() {
  local pkg="kwin-effect-roundedcorners" repo="matinlotfali/KDE-Rounded-Corners" was_installed=0 repo_was_enabled=0
  ui_warn "Rounded Corners is provided by a third-party COPR, not the Fedora base repositories." 2>/dev/null || true
  printf 'COPR to enable: %s\nPackage to install: %s\n' "$repo" "$pkg"
  if ! ask "Enable this COPR and install the KWin Rounded Corners effect?" "n"; then
    SKIPPED+=("third-party KWin Rounded Corners effect")
    return
  fi
  if ! "$DNF" copr list >/dev/null 2>&1; then
    SKIPPED+=("DNF COPR plugin is unavailable; install the COPR plugin first to use Rounded Corners")
    return
  fi
  rpm -q "$pkg" >/dev/null 2>&1 && was_installed=1
  if "$DNF" copr list 2>/dev/null | grep -Fqx "copr.fedorainfracloud.org/$repo"; then
    repo_was_enabled=1
  fi
  if [ "$repo_was_enabled" -eq 0 ]; then
    sudo "$DNF" -y copr enable "$repo"
    record_state copr "$repo"
    CHANGED+=("enabled COPR $repo")
  fi
  sudo "$DNF" install -y "$pkg"
  if [ "$was_installed" -eq 0 ] && rpm -q "$pkg" >/dev/null 2>&1; then
    record_state dnf "$pkg"
  fi
  CHANGED+=("installed KWin Rounded Corners effect")
  SKIPPED+=("Rounded Corners effect may still need enabling in System Settings > Window Management > Desktop Effects")
}

disable_network_wait_online() {
  ui_warn "This can speed up boot, but may affect services that require network-online.target at boot." 2>/dev/null || true
  if systemctl list-unit-files NetworkManager-wait-online.service >/dev/null 2>&1; then
    sudo systemctl disable NetworkManager-wait-online.service
    CHANGED+=("disabled NetworkManager-wait-online.service")
  else
    SKIPPED+=("NetworkManager-wait-online.service not found")
  fi
}

fix_panel_alignment() {
  local layout panel_id icon_id spacer_a spacer_b left_ids right_ids order
  if ! command_exists qdbus; then
    SKIPPED+=("qdbus not available for Plasma panel alignment")
    return
  fi
  backup_path "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
  layout="$(qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
    for (const id of panelIds) {
      const panel = panelById(id);
      if (!panel || panel.location !== "top") continue;
      panel.alignment = "left";
      const left = [];
      const right = [];
      const spacers = [];
      let icon = "";
      for (const wid of panel.widgetIds) {
        const w = panel.widgetById(wid);
        if (!w) continue;
        if (w.type === "org.kde.plasma.marginsseparator") {
          w.remove();
          continue;
        }
        if (w.type === "org.kde.plasma.panelspacer") {
          spacers.push(wid);
          continue;
        }
        if (w.type === "org.kde.plasma.icontasks") {
          icon = wid;
          continue;
        }
        if (w.type === "org.kde.plasma.systemtray" || w.type === "org.kde.plasma.digitalclock" || w.type === "org.kde.plasma.showdesktop") {
          right.push(wid);
          continue;
        }
        left.push(wid);
      }
      while (spacers.length < 2) {
        const s = panel.addWidget("org.kde.plasma.panelspacer");
        spacers.push(s.id);
      }
      print(id + "|" + icon + "|" + spacers[0] + "|" + spacers[1] + "|" + left.join(";") + "|" + right.join(";"));
      break;
    }
  ' | tail -n 1 || true)"
  IFS='|' read -r panel_id icon_id spacer_a spacer_b left_ids right_ids <<<"$layout"
  if [ -n "$panel_id" ] && [ -n "$icon_id" ] && [ -n "$spacer_a" ] && [ -n "$spacer_b" ]; then
    order="${left_ids};${spacer_a};${icon_id};${spacer_b};${right_ids}"
    order="${order#;}"
    order="${order%;}"
    kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group "$panel_id" --group General --key AppletOrder "$order"
    CHANGED+=("centered Icon Tasks between two Plasma spacers on panel $panel_id")
  else
    SKIPPED+=("could not identify top panel/Icon Tasks for centering")
  fi
  CHANGED+=("set top Plasma panel alignment to left")
  systemctl --user restart plasma-plasmashell.service >/dev/null 2>&1 || true
  CHANGED+=("restarted plasmashell to apply panel layout")
  show_file_diff "$LAST_BACKUP_PATH" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
}

tune_panel_colorizer() {
  local plasma_cfg="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" result
  [ -f "$plasma_cfg" ] || {
    SKIPPED+=("Plasma desktop applet config not found")
    return
  }
  backup_path "$plasma_cfg"
  result="$(
    python3 - <<'PY'
from pathlib import Path
import configparser, json, re, sys

path = Path.home() / ".config/plasma-org.kde.plasma.desktop-appletsrc"
parser = configparser.ConfigParser(interpolation=None, strict=False)
parser.optionxform = str
parser.read(path)

colorizer_sections = []
for sec in parser.sections():
    match = re.fullmatch(r"Containments\]\[(\d+)\]\[Applets\]\[(\d+)", sec)
    if not match:
        continue
    if parser.get(sec, "plugin", fallback="") != "luisbocanegra.panel.colorizer":
        continue
    general = f"Containments][{match.group(1)}][Applets][{match.group(2)}][Configuration][General"
    if parser.has_section(general) and parser.has_option(general, "globalSettings"):
        colorizer_sections.append((match.group(1), general))

if not colorizer_sections:
    print("NO_COLORIZER")
    sys.exit(0)

total_spacers = []
for containment_id, general in colorizer_sections:
    global_settings = json.loads(parser.get(general, "globalSettings"))
    overrides = json.loads(parser.get(general, "configurationOverrides", fallback='{"overrides":{},"associations":[]}'))

    normal = global_settings.setdefault("widgets", {}).setdefault("normal", {})
    normal["spacing"] = max(int(normal.get("spacing", 4) or 4), 10)
    margin = normal.setdefault("margin", {"enabled": True, "side": {}})
    margin["enabled"] = True
    side = margin.setdefault("side", {})
    side.update({
        "left": max(int(side.get("left", 0) or 0), 10),
        "right": max(int(side.get("right", 0) or 0), 10),
        "top": max(int(side.get("top", 0) or 0), 5),
        "bottom": max(int(side.get("bottom", 0) or 0), 8),
    })
    normal.setdefault("backgroundColor", {})["enabled"] = True
    normal["backgroundColor"]["alpha"] = min(float(normal["backgroundColor"].get("alpha", 1) or 1), 0.82)
    normal.setdefault("border", {})["enabled"] = True
    normal["border"]["width"] = max(int(normal["border"].get("width", 1) or 1), 2)
    normal["border"].setdefault("color", {})["enabled"] = True
    normal["border"]["color"]["alpha"] = 0.45

    spacer_ids = []
    icon_task_ids = []
    for sec in parser.sections():
        match = re.fullmatch(rf"Containments\]\[{re.escape(containment_id)}\]\[Applets\]\[(\d+)", sec)
        if match and parser.get(sec, "plugin", fallback="") == "org.kde.plasma.panelspacer":
            spacer_ids.append(int(match.group(1)))
        if match and parser.get(sec, "plugin", fallback="") == "org.kde.plasma.icontasks":
            icon_task_ids.append(int(match.group(1)))
    spacer_ids = sorted(set(spacer_ids))
    icon_task_ids = sorted(set(icon_task_ids))
    total_spacers.extend(spacer_ids)

    spacer_base = json.loads(json.dumps(normal))
    spacer_base["enabled"] = False
    spacer_base["blurBehind"] = False
    spacer_base["spacing"] = 0
    spacer_base.setdefault("backgroundColor", {})["enabled"] = False
    spacer_base.setdefault("backgroundColor", {})["alpha"] = 0
    for key in ("border", "borderSecondary"):
        spacer_base.setdefault(key, {})["enabled"] = False
        spacer_base.setdefault(key, {})["width"] = 0
    for target in ("background", "foreground"):
        spacer_base.setdefault("shadow", {}).setdefault(target, {})["enabled"] = False
    spacer_base.setdefault("margin", {"enabled": True, "side": {}})["enabled"] = True
    spacer_base["margin"].setdefault("side", {}).update({"left": 0, "right": 0, "top": 0, "bottom": 0})

    transparent_override = {state: json.loads(json.dumps(spacer_base)) for state in ("normal", "busy", "hovered", "needsAttention", "expanded")}
    transparent_override["disabledFallback"] = False
    overrides.setdefault("overrides", {})["Starter Kit Transparent Spacers"] = transparent_override
    associations = overrides.setdefault("associations", [])
    for spacer_id in spacer_ids:
        existing = next((item for item in associations if str(item.get("id")) == str(spacer_id) and item.get("name") == "org.kde.plasma.panelspacer"), None)
        if existing is None:
            associations.append({"id": spacer_id, "name": "org.kde.plasma.panelspacer", "presets": ["Starter Kit Transparent Spacers"]})
        elif "Starter Kit Transparent Spacers" not in existing.setdefault("presets", []):
            existing["presets"].append("Starter Kit Transparent Spacers")

    icon_tasks_base = json.loads(json.dumps(normal))
    icon_tasks_base["enabled"] = True
    icon_tasks_base["spacing"] = 10
    icon_tasks_base.setdefault("margin", {"enabled": True, "side": {}})["enabled"] = True
    icon_tasks_base["margin"].setdefault("side", {}).update({"left": 10, "right": 10, "top": 1, "bottom": 3})
    icon_tasks_base.setdefault("backgroundColor", {})["enabled"] = True
    icon_tasks_base["backgroundColor"]["alpha"] = 0.82
    icon_tasks_base.setdefault("border", {})["enabled"] = True
    icon_tasks_base["border"]["width"] = max(int(icon_tasks_base["border"].get("width", 1) or 1), 2)
    icon_tasks_base["border"].setdefault("color", {})["enabled"] = True
    icon_tasks_base["border"]["color"]["alpha"] = 0.45
    icon_tasks_override = {state: json.loads(json.dumps(icon_tasks_base)) for state in ("normal", "busy", "hovered", "needsAttention", "expanded")}
    icon_tasks_override["disabledFallback"] = True
    overrides.setdefault("overrides", {})["Starter Kit Icon Tasks Full Size"] = icon_tasks_override
    for icon_task_id in icon_task_ids:
        existing = next((item for item in associations if str(item.get("id")) == str(icon_task_id) and item.get("name") == "org.kde.plasma.icontasks"), None)
        if existing is None:
            associations.append({"id": icon_task_id, "name": "org.kde.plasma.icontasks", "presets": ["Starter Kit Icon Tasks Full Size"]})
        elif "Starter Kit Icon Tasks Full Size" not in existing.setdefault("presets", []):
            existing["presets"].append("Starter Kit Icon Tasks Full Size")

    parser.set(general, "globalSettings", json.dumps(global_settings, separators=(",", ":")))
    parser.set(general, "configurationOverrides", json.dumps(overrides, separators=(",", ":")))

with path.open("w") as handle:
    parser.write(handle, space_around_delimiters=False)

print(f"UPDATED spacers={','.join(str(item) for item in sorted(set(total_spacers))) or 'none'}")
PY
  )"
  if [[ "$result" == NO_COLORIZER* ]]; then
    SKIPPED+=("Panel Colorizer is not configured on this Plasma panel")
    return
  fi
  CHANGED+=("tuned Panel Colorizer transparent spacers, larger widget margins, and translucent borders ($result)")
  systemctl --user restart plasma-plasmashell.service >/dev/null 2>&1 || true
  CHANGED+=("restarted plasmashell to apply Panel Colorizer tuning")
  show_file_diff "$LAST_BACKUP_PATH" "$plasma_cfg"
}

install_theme_dir_group() {
  local src_root="$1" target_root="$2" label="$3" src target
  [ -d "$src_root" ] || return 0
  mkdir -p "$target_root"
  ui_section "$label" 2>/dev/null || true
  for src in "$src_root"/*; do
    [ -e "$src" ] || continue
    target="$target_root/$(basename "$src")"
    if [ -e "$target" ]; then
      SKIPPED+=("theme already exists: $target")
      ui_info "Already present: $(basename "$target")" 2>/dev/null || true
      continue
    fi
    cp -a "$src" "$target"
    CHANGED+=("installed theme asset $target")
    ui_ok "Installed $(basename "$target")" 2>/dev/null || true
  done
}

install_theme_file_group() {
  local src_root="$1" target_root="$2" label="$3" src target
  [ -d "$src_root" ] || return 0
  mkdir -p "$target_root"
  ui_section "$label" 2>/dev/null || true
  for src in "$src_root"/*; do
    [ -f "$src" ] || continue
    target="$target_root/$(basename "$src")"
    if [ -e "$target" ]; then
      SKIPPED+=("theme file already exists: $target")
      ui_info "Already present: $(basename "$target")" 2>/dev/null || true
      continue
    fi
    cp -a "$src" "$target"
    CHANGED+=("installed theme file $target")
    ui_ok "Installed $(basename "$target")" 2>/dev/null || true
  done
}

install_downloaded_themes() {
  local theme_root="$ROOT_DIR/configs/kde/themes"
  install_theme_dir_group "$theme_root/plasma/desktoptheme" "$HOME/.local/share/plasma/desktoptheme" "Plasma desktop themes"
  install_theme_dir_group "$theme_root/plasma/look-and-feel" "$HOME/.local/share/plasma/look-and-feel" "Plasma look and feel"
  install_theme_file_group "$theme_root/color-schemes" "$HOME/.local/share/color-schemes" "KDE color schemes"
  install_theme_dir_group "$theme_root/aurorae" "$HOME/.local/share/aurorae/themes" "Aurorae window decorations"
  install_theme_dir_group "$theme_root/icons" "$HOME/.local/share/icons" "Icon themes"
  install_theme_dir_group "$theme_root/wallpapers" "$HOME/.local/share/wallpapers" "Wallpapers"
}

apply_theme_preferences() {
  if ! command_exists kwriteconfig6; then
    SKIPPED+=("kwriteconfig6 not available for theme preferences")
    return
  fi
  backup_path "$HOME/.config/kwinrc"
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae.v2
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__Sweet-Dark-transparent
  CHANGED+=("applied Sweet-Dark-transparent Aurorae window decoration")
  show_file_diff "$LAST_BACKUP_PATH" "$HOME/.config/kwinrc"
}

apply_animation_speed() {
  if ! command_exists kwriteconfig6; then
    SKIPPED+=("kwriteconfig6 not available")
    return
  fi
  backup_path "$HOME/.config/kdeglobals"
  kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0.35
  CHANGED+=("set KDE animation speed to 0.35")
  show_file_diff "$LAST_BACKUP_PATH" "$HOME/.config/kdeglobals"
}

show_recommended_hotkeys() {
  cat <<'EOF'

Recommended Fedora KDE hotkeys:

  Meta+W              Toggle Overview
  Meta+G              Toggle Grid View
  Meta+T              Toggle Tiles Editor
  Meta+D              Peek at Desktop
  Meta+Shift+D        Minimize all windows
  Meta+Ctrl+Esc       Kill/select unresponsive window
  Meta+L              Lock session

Krohnkite reference, if installed:

  Meta+H/J/K/L        Focus left/down/up/right
  Meta+Shift+H/J/K/L  Move window left/down/up/right
  Meta+Ctrl+H/J/K/L   Resize window left/down/up/right
  Meta+Shift+F        Toggle float all
  Meta+Shift+Space    Retile

EOF
}

apply_recommended_hotkeys() {
  if ! command_exists kwriteconfig6; then
    SKIPPED+=("kwriteconfig6 not available for hotkeys")
    return
  fi
  backup_path "$HOME/.config/kglobalshortcutsrc"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key Overview "Meta+W,Meta+W,Toggle Overview"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Grid View" "Meta+G,Meta+G,Toggle Grid View"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Edit Tiles" "Meta+T,Meta+T,Toggle Tiles Editor"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Show Desktop" "Meta+D,Meta+D,Peek at Desktop"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key MinimizeAll "Meta+Shift+D,none,Minimize all windows"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Kill Window" "Meta+Ctrl+Esc,Meta+Ctrl+Esc,Kill Window"
  kwriteconfig6 --file kglobalshortcutsrc --group ksmserver --key "Lock Session" $'Meta+L\tScreensaver,Meta+L\tScreensaver,Lock Session'
  CHANGED+=("applied recommended KDE hotkeys")
  show_file_diff "$LAST_BACKUP_PATH" "$HOME/.config/kglobalshortcutsrc"
}

install_packaged_kwin_scripts() {
  local dir="$ROOT_DIR/configs/kde/kwin-scripts" script_dir name
  if ! command_exists kpackagetool6; then
    SKIPPED+=("kpackagetool6 not available")
    return
  fi
  [ -d "$dir" ] || return 0
  for script_dir in "$dir"/*; do
    [ -d "$script_dir" ] || continue
    [ -f "$script_dir/metadata.json" ] || continue
    name="$(basename "$script_dir")"
    if kpackagetool6 --type KWin/Script --list 2>/dev/null | grep -Fxq "$name"; then
      SKIPPED+=("KWin script already installed: $name")
      continue
    fi
    kpackagetool6 --type KWin/Script --install "$script_dir"
    CHANGED+=("installed KWin script $name")
  done
}

enable_kwin_scripts() {
  local list="$ROOT_DIR/configs/kde/kwin-enabled.conf" plugin
  if ! command_exists kwriteconfig6; then
    SKIPPED+=("kwriteconfig6 not available for KWin script enablement")
    return
  fi
  [ -f "$list" ] || return 0
  backup_path "$HOME/.config/kwinrc"
  while IFS= read -r plugin; do
    case "$plugin" in
    "" | \#*) continue ;;
    esac
    kwriteconfig6 --file kwinrc --group Plugins --key "${plugin}Enabled" true
    CHANGED+=("enabled KWin plugin $plugin")
  done <"$list"
  show_file_diff "$LAST_BACKUP_PATH" "$HOME/.config/kwinrc"
}

reconfigure_kwin() {
  if command_exists qdbus; then
    qdbus org.kde.KWin /KWin reconfigure || true
    CHANGED+=("requested KWin reconfigure")
  elif command_exists qdbus6; then
    qdbus6 org.kde.KWin /KWin reconfigure || true
    CHANGED+=("requested KWin reconfigure")
  else
    SKIPPED+=("qdbus/qdbus6 not available; log out/in to apply KWin changes")
  fi
}

if ask "Install KDE customization packages?" "y"; then
  ui_section "Packages" 2>/dev/null || true
  install_kde_packages
fi

if ask "Install KDE taskbar/widget quality-of-life packages?" "y"; then
  ui_section "Taskbar and Widgets" 2>/dev/null || true
  printf 'Includes Plasma workspace/desktop, KDE add-ons, KDE Connect tray integration, and Bluedevil Bluetooth tray support.\n'
  install_taskbar_widget_packages
fi

if ask "Install bundled KDE widgets such as Panel Colorizer if missing?" "y"; then
  ui_section "Bundled KDE Widgets" 2>/dev/null || true
  printf 'Copies bundled non-private plasmoids only when they are not already installed.\n'
  install_bundled_plasmoids
fi

if ask "Install Bluetooth headphone codec/support packages?" "y"; then
  ui_section "Bluetooth Audio" 2>/dev/null || true
  printf 'Includes PipeWire/WirePlumber, BlueZ/Bluedevil, LDAC, aptX, AAC, FFmpeg, OpenH264, and GStreamer codec support where available.\n'
  install_bluetooth_headphone_codecs
fi

if ask "Review optional third-party KWin Rounded Corners effect?" "n"; then
  ui_section "KWin Rounded Corners" 2>/dev/null || true
  printf 'Optional window-corner effect from the matinlotfali/KDE-Rounded-Corners COPR. This is off by default because it uses a third-party repository.\n'
  install_rounded_corners_effect
fi

if ask "Disable NetworkManager-wait-online.service to reduce boot wait time?" "n"; then
  ui_section "Boot Speed" 2>/dev/null || true
  disable_network_wait_online
fi

if ask "Fix Plasma panel alignment so the whole taskbar is not centered?" "y"; then
  ui_section "Panel Alignment" 2>/dev/null || true
  printf 'Sets top Plasma panels to left alignment. This does not copy a full panel layout.\n'
  fix_panel_alignment
fi

if ask "Tune Panel Colorizer for transparent spacers, larger margins, and translucent borders?" "y"; then
  ui_section "Panel Colorizer" 2>/dev/null || true
  printf 'Makes empty Plasma spacer widgets transparent, expands colorized widget island margins, and softens island opacity/borders.\n'
  tune_panel_colorizer
fi

if ask "Install downloaded KDE themes from this kit without overwriting existing themes?" "y"; then
  install_downloaded_themes
fi

if ask "Apply Sweet-Dark-transparent KWin decoration preference?" "n"; then
  apply_theme_preferences
fi

if ask "Apply KDE animation speed factor 0.35?" "y"; then
  ui_section "Animation" 2>/dev/null || true
  apply_animation_speed
fi

if ask "Review recommended Fedora/KDE hotkeys?" "y"; then
  show_recommended_hotkeys
  if ask "Apply these recommended hotkeys?" "n"; then
    ui_section "Hotkeys" 2>/dev/null || true
    apply_recommended_hotkeys
  else
    SKIPPED+=("recommended KDE hotkeys")
  fi
fi

if ask "Install packaged KWin scripts from this kit, if any?" "y"; then
  ui_section "KWin Scripts" 2>/dev/null || true
  install_packaged_kwin_scripts
fi

if ask "Enable detected KWin scripts/plugins?" "y"; then
  enable_kwin_scripts
fi

reconfigure_kwin

echo
ui_title "KDE Customization Summary" 2>/dev/null || echo "KDE customization summary"
printf 'Changed:\n'
printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'
printf '  - %s\n' "${SKIPPED[@]:-(none)}"

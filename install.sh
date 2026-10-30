#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${USER:-$(id -un)}"
USER_HOME="${HOME:-/home/$USER_NAME}"
USER_FULLNAME="$(getent passwd "$USER_NAME" | cut -d: -f5 | cut -d, -f1)"
[ -z "$USER_FULLNAME" ] && USER_FULLNAME="$USER_NAME"

apply_template() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    sed -e "s|@HOME@|$USER_HOME|g" \
        -e "s|@USER@|$USER_NAME|g" \
        -e "s|@USER_FULLNAME@|$USER_FULLNAME|g" \
        "$src" > "$dst"
}

echo "==> Installing user scripts & 3-finger gestures..."
mkdir -p "$USER_HOME/.local/bin" "$USER_HOME/.local/share/three-finger-gestures"
for f in "$REPO_DIR"/bin/*; do
    if [ -f "$f" ]; then
        dst="$USER_HOME/.local/bin/$(basename "$f")"
        apply_template "$f" "$dst"
        chmod +x "$dst"
    fi
done
if [ -d "$REPO_DIR/bin/three-finger-gestures" ]; then
    cp -r "$REPO_DIR"/bin/three-finger-gestures/* "$USER_HOME/.local/share/three-finger-gestures/"
fi

echo "==> Installing custom & patched macOS Plasmoids..."
mkdir -p "$USER_HOME/.local/share/plasma/plasmoids"
cp -r "$REPO_DIR"/plasmoids/* "$USER_HOME/.local/share/plasma/plasmoids/"
find "$USER_HOME/.local/share/plasma/plasmoids" -name "*.qml" -exec sed -i "s|@HOME@|$USER_HOME|g" {} +

echo "==> Installing patched MacTahoe-Dark Plasma Theme, WhiteSur Aurorae & Color Scheme..."
mkdir -p "$USER_HOME/.local/share/plasma/desktoptheme" "$USER_HOME/.local/share/aurorae/themes" "$USER_HOME/.local/share/color-schemes"
cp -r "$REPO_DIR/themes/MacTahoe-Dark" "$USER_HOME/.local/share/plasma/desktoptheme/"
cp -r "$REPO_DIR/themes/WhiteSur-dark-opaque" "$USER_HOME/.local/share/aurorae/themes/"
cp "$REPO_DIR/themes/MacTahoeDark.colors" "$USER_HOME/.local/share/color-schemes/"

echo "==> Installing macOS Lock Screen & Logout Shell Overrides..."
SHELL_DIR="$USER_HOME/.local/share/plasma/shells/org.kde.plasma.desktop"
mkdir -p "$SHELL_DIR/contents/lockscreen" "$SHELL_DIR/contents/logout"
cp /usr/share/plasma/shells/org.kde.plasma.desktop/metadata.json "$SHELL_DIR/"
for item in activitymanager applet configuration defaults explorer InteractiveConsole.qml main.js updates views; do
    ln -sfn "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/$item" "$SHELL_DIR/contents/$item"
done
cp -rn /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/* "$SHELL_DIR/contents/lockscreen/" || true
cp -rn /usr/share/plasma/shells/org.kde.plasma.desktop/contents/logout/* "$SHELL_DIR/contents/logout/" || true
for f in LockScreenUi.qml MainBlock.qml LockOsd.qml; do
    apply_template "$REPO_DIR/shell-overrides/lockscreen/$f" "$SHELL_DIR/contents/lockscreen/$f"
done
for f in Logout.qml LogoutControls.qml LogoutButton.qml; do
    apply_template "$REPO_DIR/shell-overrides/logout/$f" "$SHELL_DIR/contents/logout/$f"
done

echo "==> Installing KWin scripts, rules, Konsole/Yakuake profiles, EasyEffects presets, Sound theme & WhatsApp extension..."
mkdir -p "$USER_HOME/.local/share/kwin/scripts"
cp -r "$REPO_DIR/kwin/chrome-pip-top" "$USER_HOME/.local/share/kwin/scripts/"
cp "$REPO_DIR/kwin/kwinrulesrc" "$USER_HOME/.config/kwinrulesrc"

mkdir -p "$USER_HOME/.local/share/konsole"
cp "$REPO_DIR/konsole/macOS.profile" "$REPO_DIR/konsole/macOS.colorscheme" "$USER_HOME/.local/share/konsole/"
cp "$REPO_DIR/konsole/yakuakerc" "$USER_HOME/.config/yakuakerc"

mkdir -p "$USER_HOME/.local/share/easyeffects/output"
cp "$REPO_DIR"/easyeffects/*.json "$USER_HOME/.local/share/easyeffects/output/"

mkdir -p "$USER_HOME/.local/share/sounds/macOS/stereo"
cp -rn /usr/share/sounds/ocean/stereo/* "$USER_HOME/.local/share/sounds/macOS/stereo/" 2>/dev/null || true
cp -r "$REPO_DIR"/sounds/* "$USER_HOME/.local/share/sounds/macOS/"

mkdir -p "$USER_HOME/.local/share/whatsapp-privacy-ext"
cp -r "$REPO_DIR"/chrome-ext/* "$USER_HOME/.local/share/whatsapp-privacy-ext/"

echo "==> Applying KWin Window Decorations (traffic lights on left), Blur, Rounded Corners, Magic Lamp & Shake Cursor..."
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "library" "org.kde.kwin.aurorae"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "theme" "__aurorae__svg__WhiteSur-dark-opaque"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "ButtonsOnLeft" "XIA"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "ButtonsOnRight" ""
kwriteconfig6 --file kwinrc --group "Plugins" --key "better_blur_dxEnabled" "true"
kwriteconfig6 --file kwinrc --group "Plugins" --key "kwin4_effect_shapecornersEnabled" "true"
kwriteconfig6 --file kwinrc --group "Plugins" --key "magiclampEnabled" "true"
kwriteconfig6 --file kwinrc --group "Plugins" --key "shakecursorEnabled" "true"
kwriteconfig6 --file kwinrc --group "Plugins" --key "chrome-pip-topEnabled" "true"
kwriteconfig6 --file kwinrc --group "Effect-better-blur-dx" --key "BlurDocks" "true"
kwriteconfig6 --file kwinrc --group "Effect-better-blur-dx" --key "BlurMenus" "true"
kwriteconfig6 --file kwinrc --group "Effect-better-blur-dx" --key "BlurDecorations" "true"
kwriteconfig6 --file kwinrc --group "Effect-better-blur-dx" --key "BlurMatching" "true"
kwriteconfig6 --file kwinrc --group "Effect-better-blur-dx" --key "BlurStrength" "12"
kwriteconfig6 --file kwinrc --group "Effect-better-blur-dx" --key "NoiseStrength" "1"
kwriteconfig6 --file kwinrc --group "Round-Corners" --key "Size" "12"
kwriteconfig6 --file kwinrc --group "Round-Corners" --key "InactiveCornerRadius" "12"
kwriteconfig6 --file kdeglobals --group "Sounds" --key "Theme" "macOS"
kwriteconfig6 --file kdeglobals --group "Sounds" --key "Enable" "true"
kwriteconfig6 --file plasmarc --group "Theme" --key "name" "MacTahoe-Dark"

echo "==> Installing systemd user services & LimitNOFILE drop-ins..."
mkdir -p "$USER_HOME/.config/systemd/user"
for svc in "$REPO_DIR"/systemd/*.service "$REPO_DIR"/systemd/*.timer; do
    [ -f "$svc" ] && apply_template "$svc" "$USER_HOME/.config/systemd/user/$(basename "$svc")"
done
mkdir -p "$USER_HOME/.config/systemd/user/plasma-plasmashell.service.d" "$USER_HOME/.config/systemd/user/plasma-kwin_wayland.service.d"
cp "$REPO_DIR/systemd/plasma-plasmashell.service.d/limit-nofile.conf" "$USER_HOME/.config/systemd/user/plasma-plasmashell.service.d/"
cp "$REPO_DIR/systemd/plasma-kwin_wayland.service.d/limit-nofile.conf" "$USER_HOME/.config/systemd/user/plasma-kwin_wayland.service.d/"
systemctl --user daemon-reload
systemctl --user enable --now macos-multiscreen-dock.service macos-screenshare-privacy.service google-ical-sync.timer

echo "==> Applying root-level patches (OSD pill, SDDM theme, Aerial binary patch, Network/DNS privacy)..."
for osd_dir in /usr/lib/qt6/qml/org/kde/plasma/workspace/osd /usr/lib64/qt6/qml/org/kde/plasma/workspace/osd /usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/plasma/workspace/osd; do
    if [ -d "$osd_dir" ]; then
        sudo cp "$REPO_DIR"/shell-overrides/osd/* "$osd_dir/"
    fi
done
sudo mkdir -p /usr/share/sddm/themes/macos-tahoe
sudo cp -r /usr/share/sddm/themes/breeze/* /usr/share/sddm/themes/macos-tahoe/ 2>/dev/null || true
for f in Main.qml Login.qml theme.conf; do
    tmp="/tmp/sddm-$f"
    apply_template "$REPO_DIR/sddm/$f" "$tmp"
    sudo mv "$tmp" "/usr/share/sddm/themes/macos-tahoe/$f"
done
sudo cp "$REPO_DIR/etc/00-macos-privacy.conf" /etc/NetworkManager/conf.d/
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
if [ -d /usr/share/plasma/wallpapers/io.github.birkneralex.aerial/contents/ui ]; then
    tmp="/tmp/aerial-main.qml"
    apply_template "$REPO_DIR/patches/aerial-main.qml" "$tmp"
    sudo mv "$tmp" /usr/share/plasma/wallpapers/io.github.birkneralex.aerial/contents/ui/main.qml
    sudo "$REPO_DIR/patches/patch-aerial-core.py"
fi

qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
"$USER_HOME/.local/bin/macos-multiscreen-sync.sh" || true
echo "==> Done! Your KDE Plasma 6 Wayland desktop is now configured as macOS Tahoe."

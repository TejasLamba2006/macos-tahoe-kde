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

echo "==> Installing user scripts to ~/.local/bin..."
mkdir -p "$USER_HOME/.local/bin"
for f in "$REPO_DIR"/bin/*; do
    dst="$USER_HOME/.local/bin/$(basename "$f")"
    apply_template "$f" "$dst"
    chmod +x "$dst"
done

echo "==> Installing custom macOS Plasmoids (dockseparator, downloads, trash, privacydots)..."
mkdir -p "$USER_HOME/.local/share/plasma/plasmoids"
cp -r "$REPO_DIR"/plasmoids/org.macos.* "$USER_HOME/.local/share/plasma/plasmoids/"
for qml in "$USER_HOME"/.local/share/plasma/plasmoids/org.macos.*/contents/ui/main.qml; do
    sed -i -e "s|@HOME@|$USER_HOME|g" "$qml"
done

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

echo "==> Installing KWin scripts, rules, Konsole profile, Sound theme, and WhatsApp extension..."
mkdir -p "$USER_HOME/.local/share/kwin/scripts"
cp -r "$REPO_DIR/kwin/chrome-pip-top" "$USER_HOME/.local/share/kwin/scripts/"
mkdir -p "$USER_HOME/.local/share/konsole"
cp "$REPO_DIR"/konsole/* "$USER_HOME/.local/share/konsole/"
mkdir -p "$USER_HOME/.local/share/sounds/macOS/stereo"
cp -rn /usr/share/sounds/ocean/stereo/* "$USER_HOME/.local/share/sounds/macOS/stereo/" 2>/dev/null || true
cp -r "$REPO_DIR"/sounds/* "$USER_HOME/.local/share/sounds/macOS/"
mkdir -p "$USER_HOME/.local/share/whatsapp-privacy-ext"
cp -r "$REPO_DIR"/chrome-ext/* "$USER_HOME/.local/share/whatsapp-privacy-ext/"

echo "==> Installing systemd user services..."
mkdir -p "$USER_HOME/.config/systemd/user"
for svc in "$REPO_DIR"/systemd/*; do
    apply_template "$svc" "$USER_HOME/.config/systemd/user/$(basename "$svc")"
done
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
sudo cp "$REPO_DIR/etc/10-macos-privacy.conf" /etc/systemd/resolved.conf.d/
if [ -d /usr/share/plasma/wallpapers/io.github.birkneralex.aerial/contents/ui ]; then
    tmp="/tmp/aerial-main.qml"
    apply_template "$REPO_DIR/patches/aerial-main.qml" "$tmp"
    sudo mv "$tmp" /usr/share/plasma/wallpapers/io.github.birkneralex.aerial/contents/ui/main.qml
    sudo "$REPO_DIR/patches/patch-aerial-core.py"
fi

echo "==> Done! Run ~/.local/bin/macos-multiscreen-sync.sh to sync all monitors."

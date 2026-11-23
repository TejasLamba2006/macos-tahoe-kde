import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class EightMacosFeaturesTests(unittest.TestCase):
    def test_1_cmd_tab_app_switcher_package_and_installer(self):
        pkg = REPO / "kwin/tabbox/macos-app-switcher"
        self.assertTrue((pkg / "metadata.json").is_file())
        qml = (pkg / "contents/ui/main.qml").read_text()
        for token in ("KWin.TabBoxSwitcher", "tabBox.model", "currentIndex", "radius: 22"):
            self.assertIn(token, qml)
        installer = (REPO / "install.sh").read_text()
        self.assertIn("macos-app-switcher", installer)

    def test_2_quicklook_helper_and_servicemenu(self):
        script = (REPO / "bin/macos-quicklook").read_text()
        for token in ("QLocalServer", "QPdfView", "QMediaPlayer", "Qt.Key.Key_Space", "Qt.Key.Key_Escape"):
            self.assertIn(token, script)
        menu = (REPO / "servicemenus/macos-quicklook.desktop").read_text()
        self.assertIn("Exec=@HOME@/.local/bin/macos-quicklook %F", menu)

    def test_4_downloads_dock_stack_popup(self):
        qml = (REPO / "plasmoids/org.macos.downloads/contents/ui/main.qml").read_text()
        for token in ("compactRepresentation:", "fullRepresentation:", "FolderListModel", "DragDrop.DragArea", "Open in Finder"):
            self.assertIn(token, qml)

    def test_5_live_text_ocr_and_shortcut(self):
        script = (REPO / "bin/macos-live-text").read_text()
        for token in ("spectacle", "zbarimg", "tesseract", "wl-copy", "island-push"):
            self.assertIn(token, script)
        desktop = (REPO / "applications/macos-live-text.desktop").read_text()
        self.assertIn("X-KDE-Shortcuts=", desktop)

    def test_7_finder_quick_actions_servicemenu(self):
        menu = (REPO / "servicemenus/macos-quick-actions.desktop").read_text()
        self.assertIn("X-KDE-Submenu=Quick Actions", menu)
        script = (REPO / "bin/macos-quick-action").read_text()
        for token in ("convert-png", "convert-jpg", "convert-webp", "rotate-left", "rotate-right", "create-pdf", "extract-mp3", "copy-path"):
            self.assertIn(token, script)

    def test_8_tahoe_colored_folders_and_emoji_badge(self):
        menu = (REPO / "servicemenus/macos-folder-color.desktop").read_text()
        self.assertIn("X-KDE-Submenu=Folder Color & Emoji", menu)
        script = (REPO / "bin/macos-folder-badge").read_text()
        for token in ("folder-red", "folder-blue", "emoji", ".directory"):
            self.assertIn(token, script)

    def test_9_force_quit_dialog_shortcut_and_apple_menu(self):
        script = (REPO / "bin/macos-force-quit").read_text()
        for token in ("Force Quit Applications", "SIGTERM", "SIGKILL"):
            self.assertIn(token, script)
        desktop = (REPO / "applications/macos-force-quit.desktop").read_text()
        self.assertIn("X-KDE-Shortcuts=Meta+Alt+Esc", desktop)
        kickoff = (REPO / "patches/bartender/src/kickoff/FullRepresentation.qml").read_text()
        self.assertIn("macos-force-quit", kickoff)

    def test_10_stealth_window_exclude_from_capture_kwin_script(self):
        meta = (REPO / "kwin/macos-stealth-window/metadata.json").read_text()
        self.assertIn("macos-stealth-window", meta)
        js = (REPO / "kwin/macos-stealth-window/contents/code/main.js").read_text()
        for token in ("excludeFromCapture", "Meta+Shift+H", "callDBus", "org.phobby.DynamicIsland"):
            self.assertIn(token, js)


if __name__ == "__main__":
    unittest.main()

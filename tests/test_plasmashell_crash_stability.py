import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class PlasmashellCrashStabilityTests(unittest.TestCase):
    def test_bartender_strips_kdeconnect_from_systemtray_extra_items(self):
        script = (REPO / "bin/macos-bartender-ctl").read_text()
        self.assertIn('readConfig("extraItems"', script)
        self.assertIn('writeConfig("extraItems"', script)
        self.assertIn('"org.kde.kdeconnect"', script)

    def test_kdeconnect_plasmoid_override_eliminates_quadratic_dbus_livelock(self):
        delegate_path = REPO / "plasmoids/org.kde.kdeconnect/contents/ui/DeviceDelegate.qml"
        self.assertTrue(delegate_path.is_file(), "User-space org.kde.kdeconnect plasmoid override missing")
        text = delegate_path.read_text()
        self.assertIn('deviceId: root.Window.visibility !== Window.Hidden ? root.model.deviceId : ""', text)
        self.assertIn("model: root.notificationsExpanded ? notificationsModel : null", text)
        self.assertNotIn("notificationsModel.isAnyDimissable", text)

    def test_rtw89_and_wifi_powersave_disabled(self):
        nm_conf = (REPO / "etc/00-macos-privacy.conf").read_text()
        self.assertIn("wifi.powersave=2", nm_conf)

        modprobe_conf = (REPO / "etc/rtw89-stability.conf").read_text()
        self.assertIn("options rtw89_core disable_ps_mode=y", modprobe_conf)
        self.assertIn("options rtw89_pci disable_aspm_l1=y disable_aspm_l1ss=y", modprobe_conf)

        install_sh = (REPO / "install.sh").read_text()
        self.assertIn("/etc/modprobe.d/rtw89-stability.conf", install_sh)


if __name__ == "__main__":
    unittest.main()

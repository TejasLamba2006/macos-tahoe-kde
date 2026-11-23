import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]


class UiResourceTests(unittest.TestCase):
    def test_resource_installer_does_not_change_service_or_user_settings(self):
        source = (ROOT / 'tools/install-ui-resources.py').read_text()
        self.assertIn('os.replace(staged, target)', source)
        self.assertIn('shutil.copy2(target, backup', source)
        self.assertIn('/usr/lib/qt6/rcc', source)
        self.assertNotIn('write_text', source.split('def install(', 1)[1])

    def test_resource_installer_purges_plasmashell_qmlcache_and_dropin_enables_disk_cache(self):
        installer = (ROOT / 'tools/install-ui-resources.py').read_text()
        self.assertIn('.cache/plasmashell/qmlcache', installer)
        dropin = (ROOT / 'systemd/plasma-plasmashell.service.d/limit-nofile.conf').read_text()
        self.assertNotIn('QML_DISABLE_DISK_CACHE', dropin)

    def test_installer_builds_resources_before_preload_configuration(self):
        source = (ROOT / 'install.sh').read_text()
        self.assertLess(source.index('tools/install-ui-resources.py'),
                        source.index('cp "$REPO_DIR/systemd/plasma-plasmashell.service.d/limit-nofile.conf"'))


if __name__ == '__main__':
    unittest.main()

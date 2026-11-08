import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BrightnessResourceTests(unittest.TestCase):
    def test_real_brightness_aot_requires_intended_override(self):
        flags = subprocess.check_output(['pkg-config', '--cflags', '--libs', 'Qt6Core', 'Qt6Qml'], text=True).split()
        version = subprocess.check_output(['pkg-config', '--modversion', 'Qt6Qml'], text=True).strip()
        headers = subprocess.check_output(['pkg-config', '--variable=includedir', 'Qt6Qml'], text=True).strip()
        with tempfile.TemporaryDirectory(prefix='brightness-aot-') as directory:
            tmp = Path(directory)
            lib = tmp / 'preload.so'
            subprocess.run(['g++', '-shared', '-fPIC', '-O2', str(ROOT / 'patches/bartender/bartender_preload.cpp'),
                            *flags, '-ldl', '-o', str(lib)], check=True)
            cpp = tmp / 'probe.cpp'
            cpp.write_text('''#include <QCoreApplication>
#include <QUrl>
#include <private/qqmlmetatype_p.h>
#include <dlfcn.h>
#include <cstdio>
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    if (!dlopen("/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.brightness.so", RTLD_NOW|RTLD_GLOBAL)) return 2;
    if (!dlopen("/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.taskmanager.so", RTLD_NOW|RTLD_GLOBAL)) return 3;
    QQmlMetaType::CachedUnitLookupError error;
    bool brightness = QQmlMetaType::findCachedCompilationUnit(QUrl("qrc:/qt/qml/plasma/applet/org/kde/plasma/brightness/PopupDialog.qml"), QQmlMetaType::AcceptUntyped, &error);
    bool tasks = QQmlMetaType::findCachedCompilationUnit(QUrl("qrc:/qt/qml/plasma/applet/org/kde/plasma/taskmanager/Task.qml"), QQmlMetaType::AcceptUntyped, &error);
    std::printf("brightnessCached=%d tasksCached=%d\\n", brightness, tasks);
    return brightness == (argv[1][0]=='1') && tasks ? 0 : 4;
}''')
            exe = tmp / 'plasmashell'
            includes = ['-I' + headers + '/' + module + '/' + version + suffix
                        for module in ('QtCore', 'QtQml') for suffix in ('', '/' + module)]
            subprocess.run(['g++', str(cpp), *flags, *includes, '-ldl', '-o', str(exe)], check=True)
            resource = tmp / 'home/.local/share/macos-tahoe/brightness.rcc'
            resource.parent.mkdir(parents=True)
            env = os.environ.copy()
            env.update(HOME=str(tmp/'home'), LD_PRELOAD=str(lib), XDG_CONFIG_HOME=str(tmp/'config'),
                       XDG_DATA_HOME=str(tmp/'data'), XDG_CACHE_HOME=str(tmp/'cache'),
                       DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(tmp/'no-bus'))
            for state in ('absent', 'invalid', 'old-other-rcc', 'brightness-override', 'non-plasma'):
                if state == 'invalid':
                    resource.write_bytes(b'not RCC')
                elif state == 'old-other-rcc':
                    subprocess.run(['rcc', '-binary', str(ROOT/'patches/bartender/src/bartender.qrc'), '-o', str(resource)], check=True)
                elif state == 'brightness-override':
                    subprocess.run(['rcc', '-binary', str(ROOT/'patches/brightness/src/brightness.qrc'), '-o', str(resource)], check=True)
                binary = exe
                if state == 'non-plasma':
                    binary = tmp/'not-plasma'; binary.symlink_to(exe)
                with self.subTest(state=state):
                    result = subprocess.run([str(binary), '0' if state == 'brightness-override' else '1'],
                                            env=env, capture_output=True, text=True, timeout=10)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    print(state + ': ' + result.stdout, end='')


if __name__ == '__main__':
    unittest.main()

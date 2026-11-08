import os
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'plasmoids/KdeControlStation/contents/ui/components/ScreenshotBtn.qml'


def block(source, marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


class ScreenshotMenuTests(unittest.TestCase):
    def test_static_native_capture_modes_wait_for_user(self):
        source = SOURCE.read_text()
        for command in ('spectacle -r -w', 'spectacle -u -w', 'spectacle -f -w',
                        'spectacle -R region', 'spectacle -R window', 'spectacle -R screen', 'spectacle -l'):
            self.assertIn(command, source)
        self.assertNotIn('spectacle -a', source)
        self.assertNotIn('Timer {', source, 'Use native chooser, not guessed popup animation delay')

    def test_full_component_menu_context_and_dispatch(self):
        result = subprocess.run([sys.executable, '-B', '-I', str(Path(__file__).resolve()), '--qt-worker'],
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Full capture component context and preference checks passed', result.stdout)
        print(result.stdout + result.stderr, end='')


def run_worker():
    os.environ.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
    os.environ.pop('LD_PRELOAD', None)
    from PyQt6 import sip
    from PyQt6.QtCore import Qt, QUrl, qInstallMessageHandler
    from PyQt6.QtGui import QGuiApplication
    from PyQt6.QtQml import QQmlComponent, QQmlEngine, QJSValue
    from PyQt6.QtQuick import QQuickWindow
    from PyQt6.QtTest import QTest

    app = QGuiApplication([])
    engine = QQmlEngine()
    window = QQuickWindow()
    window.setGeometry(0, 0, 640, 480)
    window.show()
    errors = []
    old = qInstallMessageHandler(lambda kind, context, message: errors.append(message))
    fixture_component = QQmlComponent(engine)
    fixture_component.setData(b'''import QtQuick
QtObject {
    property bool showScreenshot: true
    property bool hideWidgetBeforeScreenshot: true
    property bool expanded: true
    property string screenshotCommand: "spectacle"
    property string lastCommand: ""
    property int fullRepWidth: 500
    property int scale: 1
    property int smallSpacing: 4
    property int mediumSpacing: 8
    property int largeSpacing: 12
    property int mediumFontSize: 14
    property int smallFontSize: 11
    property bool editingLayout: false
    property bool enableTransparency: false
    property int transparencyLevel: 80
    property bool showBorders: true
    property color themeBgColor: "#242424"
    property color disabledBgColor: "#333333"
    property QtObject configuration: QtObject { property int layout: 2 }
}''', QUrl())
    fixture = fixture_component.create()
    assert fixture is not None, [e.toString() for e in fixture_component.errors()]
    engine.rootContext().setContextProperty('root', fixture)
    engine.rootContext().setContextProperty('plasmoid', fixture)
    engine.globalObject().setProperty('i18n', engine.evaluate('(function(s) { return s; })'))
    source = SOURCE.read_text()
    # Full production component/imports/CardButton/Menu; only process transport replaced.
    transport = block(source, '    Plasma5Support.DataSource {')
    source = source.replace(transport, '''    QtObject {
        id: executable
        function exec(cmd) { root.lastCommand = cmd; }
    }''')
    component = QQmlComponent(engine)
    component.setData(source.encode(), QUrl.fromLocalFile(str(SOURCE)))
    obj = component.create()
    assert obj is not None, [e.toString() for e in component.errors()]
    obj.setParentItem(window.contentItem())
    obj.setWidth(160)
    obj.setHeight(120)
    engine.globalObject().setProperty('button', engine.newQObject(obj))
    try:
        def evaluate(script):
            value = engine.evaluate(script)
            assert not value.isError(), value.toString()
            return value
        menu = obj.findChild(type(fixture), 'captureMenu')
        # QObject generic lookup avoids assuming exact QQuickPopup Python wrapper.
        from PyQt6.QtCore import QObject
        menu = obj.findChild(QObject, 'captureMenu')
        assert menu is not None, 'Native Menu absent from full component'
        engine.globalObject().setProperty('menu', engine.newQObject(menu))
        assert menu.property('count') == 9
        assert menu.property('parent') == obj, 'Menu parent must be button, not CardButton icon content'
        expected = {0:'spectacle -r -w', 1:'spectacle -u -w', 2:'spectacle -f -w',
                    4:'spectacle -R region', 5:'spectacle -R window', 6:'spectacle -R screen', 8:'spectacle -l'}
        for hide in (False, True):
            fixture.setProperty('hideWidgetBeforeScreenshot', hide)
            for index, command in expected.items():
                fixture.setProperty('expanded', True)
                evaluate(f'menu.itemAt({index}).triggered()')
                assert fixture.property('lastCommand') == command, (index, fixture.property('lastCommand'))
                assert fixture.property('expanded') == (not hide), 'Existing hide preference ignored'
        fixture.setProperty('screenshotCommand', 'custom-capture --pick')
        evaluate('menu.itemAt(8).triggered()')
        assert fixture.property('lastCommand') == 'custom-capture --pick'
        evaluate('button.forceActiveFocus()')
        QTest.keyClick(window, Qt.Key.Key_Return)
        QTest.qWait(5)
        assert menu.property('opened'), 'Keyboard Return did not open capture menu'
        QTest.keyClick(window, Qt.Key.Key_Escape)
        QTest.qWait(5)
        assert not menu.property('opened'), 'Escape did not close native menu'
        assert not any('TypeError' in e or 'ReferenceError' in e or 'Cannot assign' in e for e in errors), errors
        print('Full capture component context and preference checks passed; dispatch only, no screenshot/recording executed')
    finally:
        engine.globalObject().setProperty('button', QJSValue())
        engine.globalObject().setProperty('menu', QJSValue())
        obj.setParentItem(None)
        sip.delete(obj)
        sip.delete(component)
        sip.delete(fixture)
        sip.delete(fixture_component)
        qInstallMessageHandler(old)
        sip.delete(window)
        sip.delete(engine)
        sip.delete(app)


if __name__ == '__main__':
    if sys.argv[1:] == ['--qt-worker']:
        run_worker()
    else:
        unittest.main()

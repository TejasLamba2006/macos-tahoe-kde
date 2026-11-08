import os
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    ROOT / 'patches/brightness/src/PopupDialog.qml',
    ROOT / 'plasmoids/KdeControlStation/contents/ui/pages/BrightnessControlPage.qml',
)


def block(source, marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


class BrightnessLifecycleTests(unittest.TestCase):
    def test_production_focus_chain_lifecycle(self):
        result = subprocess.run([sys.executable, '-B', '-I', str(Path(__file__).resolve()),
                                 '--qt-worker'], capture_output=True, text=True, timeout=25)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Both production focus chains passed', result.stdout)
        print(result.stdout + result.stderr, end='')


def run_qt_worker():
    os.environ.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
    os.environ.pop('LD_PRELOAD', None)
    from PyQt6 import sip
    from PyQt6.QtCore import Qt, QUrl, qInstallMessageHandler
    from PyQt6.QtGui import QGuiApplication
    from PyQt6.QtQml import QJSValue, QQmlComponent, QQmlEngine
    from PyQt6.QtQuick import QQuickWindow
    from PyQt6.QtTest import QTest

    app = QGuiApplication([])
    engine = QQmlEngine()
    window = QQuickWindow()
    window.setGeometry(0, 0, 400, 400)
    window.show()
    warnings = []
    old_handler = qInstallMessageHandler(lambda kind, context, text: warnings.append(text))
    try:
        for source_path in SOURCES:
            source = source_path.read_text()
            repeater = block(source, '            Repeater {')
            before = repeater[:repeater.index('                Brightness')]
            after = repeater[repeater.index('                // itemAt()'):]
            # Keep real first/last/neighbor bindings, lifecycle handlers and KeyNavigation.
            properties = '\n'.join(re.findall(r'                    property Item (?:previousSlider|nextSlider):[^\n]+', repeater))
            properties += '\n' + '\n'.join(re.findall(r'                    onIndexChanged:[^\n]+', repeater))
            navigation = '\n'.join(line for line in repeater.splitlines() if 'KeyNavigation.' in line)
            navigation = navigation.replace('dialog.firstItemAfterScreenBrightnessRepeater', 'afterItem')
            navigation = navigation.replace('firstItemAfterScreenBrightnessRepeater', 'afterItem')
            navigation = navigation.replace('dialog.KeyNavigation.', 'beforeItem.KeyNavigation.')
            navigation = navigation.replace('brightnessControlPage.KeyNavigation.', 'beforeItem.KeyNavigation.')
            # Model is deterministic local data, not live displays/backlight.
            before = re.sub(r'model: [^\n]+', 'model: displays', before)
            qml = f'''import QtQuick
Item {{
    id: root; width: 400; height: 400
    Item {{ id: beforeItem }}
    Item {{ id: afterItem; objectName: "after"; width: 100; height: 30; activeFocusOnTab: true }}
    property alias list: displays
    property alias repeater: screenBrightnessRepeater
    ListModel {{ id: displays }}
    function chain() {{
        let result = [];
        for (let i = 0; i < screenBrightnessRepeater.count; ++i) {{
            let item = screenBrightnessRepeater.itemAt(i);
            result.push({{name:item.name, previous:item.previousSlider?.name ?? null,
                         next:item.nextSlider?.name ?? null}});
        }}
        return {{first:screenBrightnessRepeater.firstSlider?.name ?? null,
                 last:screenBrightnessRepeater.lastSlider?.name ?? null, items:result}};
    }}
    function append(name) {{ displays.append({{name:name}}); }}
    function insert(i, name) {{ displays.insert(i, {{name:name}}); }}
    function remove(i) {{ displays.remove(i); }}
    function move(a, b) {{ displays.move(a, b, 1); }}
    function reset() {{ screenBrightnessRepeater.model = null; screenBrightnessRepeater.model = displays; }}
    {before}
    Item {{
        required property int index
        required property string name
        objectName: name
        width: 100; height: 30; y: index * 30
        activeFocusOnTab: true
        {properties}
        {navigation}
    }}
    {after}
}}'''
            component = QQmlComponent(engine)
            component.setData(qml.encode(), QUrl.fromLocalFile(str(source_path)))
            assert not component.isError(), [e.toString() for e in component.errors()]
            root = component.create()
            assert root is not None, [e.toString() for e in component.errors()]
            root.setParentItem(window.contentItem())
            engine.globalObject().setProperty('root', engine.newQObject(root))
            try:
                def evaluate(script):
                    value = engine.evaluate(script)
                    assert not value.isError(), value.toString()
                    return value

                def check(names):
                    QTest.qWait(5)
                    chain = evaluate('root.chain()').toVariant()
                    expected = [{'name': name, 'previous': names[i-1] if i else None,
                                 'next': names[i+1] if i+1 < len(names) else None}
                                for i, name in enumerate(names)]
                    assert chain['items'] == expected, (source_path.name, chain, expected)
                    assert chain['first'] == (names[0] if names else None), chain
                    assert chain['last'] == (names[-1] if names else None), chain
                    assert not any('TypeError' in w or 'ReferenceError' in w for w in warnings), warnings

                check([])
                evaluate('root.append("A")'); check(['A'])
                evaluate('root.append("B");root.append("C")'); check(['A', 'B', 'C'])
                evaluate('root.reset()'); check(['A', 'B', 'C'])
                evaluate('root.remove(1)'); check(['A', 'C'])
                evaluate('root.insert(1,"D")'); check(['A', 'D', 'C'])
                evaluate('root.move(0,2)'); check(['D', 'C', 'A'])
                evaluate('root.remove(0)'); check(['C', 'A'])
                evaluate('root.remove(1)'); check(['C'])
                evaluate('root.remove(0)'); check([])
                evaluate('root.append("A");root.append("B");root.append("C")'); check(['A', 'B', 'C'])
                evaluate('root.repeater.firstSlider.forceActiveFocus()')
                for key, expected in ((Qt.Key.Key_Down, 'B'), (Qt.Key.Key_Down, 'C'),
                                      (Qt.Key.Key_Up, 'B'), (Qt.Key.Key_Tab, 'C'),
                                      (Qt.Key.Key_Backtab, 'B')):
                    QTest.keyClick(window, key)
                    assert window.activeFocusItem().objectName() == expected, (key, window.activeFocusItem().objectName())
                print(source_path.name + ': empty/single/reset/remove/insert/move links and real key traversal passed')
            finally:
                engine.globalObject().setProperty('root', QJSValue())
                root.setParentItem(None)
                sip.delete(root)
                sip.delete(component)
        print('Both production focus chains passed; safe Qt teardown')
    finally:
        qInstallMessageHandler(old_handler)
        sip.delete(window)
        sip.delete(engine)
        sip.delete(app)


if __name__ == '__main__':
    if sys.argv[1:] == ['--qt-worker']:
        run_qt_worker()
    else:
        unittest.main()

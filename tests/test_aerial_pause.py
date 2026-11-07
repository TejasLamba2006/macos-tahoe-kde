import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "patches/aerial-main.qml"


def block(source, marker):
    """Extract actual production handlers, never a second copy of the policy."""
    start = source.find(marker)
    if start < 0:
        return ""
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


def check_qml():
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    from PyQt6 import sip
    from PyQt6.QtCore import QUrl
    from PyQt6.QtGui import QGuiApplication
    from PyQt6.QtQml import QQmlComponent, QQmlEngine
    from PyQt6.QtTest import QTest

    source = SOURCE.read_text()
    covered = re.search(r"readonly property bool isCovered: ([^\n]+)", source)
    predicate = covered.group(1) if covered else "false"
    # Only compositor inputs are substituted; all policy/handlers come from source.
    predicate = predicate.replace("KWindowSystem.showingDesktop", "root.showingDesktop")
    image = block(source, "    Image {")
    fallback = image.split("visible:", 1)[1].rsplit("}", 1)[0].strip()
    players = "\n".join(block(source[m.start():], "MediaPlayer {")
                        for m in re.finditer(r"    MediaPlayer \{", source))
    qml = f"""import QtQuick
import QtMultimedia
Item {{
    id: root
    width: 160; height: 120
    property int activePlayer: 0
    property bool loading: true
    property bool showingDesktop: false
    property alias coveredCount: activeWindowMonitor.count
    QtObject {{ id: activeWindowMonitor; property int count: 0 }}
    readonly property bool isCovered: {predicate}
    readonly property int stateA: playerA.playbackState
    readonly property int stateB: playerB.playbackState
    readonly property int positionA: playerA.position
    readonly property int positionB: playerB.position
    readonly property bool fallbackVisible: {fallback}
    property int unexpectedAdvance: 0
    function advance() {{ unexpectedAdvance++; }}
    VideoOutput {{ id: videoOutputA }}
    VideoOutput {{ id: videoOutputB }}
    {block(source, 'onIsCoveredChanged:')}
    {block(source, 'function playSource(source)')}
    {players}
}}"""
    app = QGuiApplication([])
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(qml.encode(), QUrl())
    assert not component.isError(), [e.toString() for e in component.errors()]
    root = component.create()
    assert root is not None, [e.toString() for e in component.errors()]

    def wait_for(predicate, message):
        for _ in range(200):
            if predicate():
                return
            QTest.qWait(10)
        raise AssertionError(message)

    def states(a, b):
        return root.property("stateA") == a and root.property("stateB") == b

    try:
        with tempfile.TemporaryDirectory(prefix="aerial-pause-test-") as directory:
            video = Path(directory) / "clip.mp4"
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i",
                            "color=c=blue:s=160x120:r=15:d=10", "-c:v", "mpeg4",
                            "-y", str(video)], check=True, timeout=15)
            url = QUrl.fromLocalFile(str(video)).toString()
            assert root.property("fallbackVisible")
            root.playSource(url)
            wait_for(lambda: states(0, 1), "Uncovered source did not play")
            wait_for(lambda: root.property("positionB") > 0, "Playback did not advance")
            root.setProperty("coveredCount", 1)
            wait_for(lambda: states(0, 2), "Covered desktop did not pause production player")
            assert not root.property("fallbackVisible"), "Paused frame hidden by fallback"
            paused_position = root.property("positionB")
            QTest.qWait(80)
            assert root.property("positionB") == paused_position
            root.setProperty("showingDesktop", True)
            wait_for(lambda: states(0, 1), "Show Desktop did not resume")
            assert root.property("positionB") >= paused_position, "Resume restarted video"
            root.setProperty("showingDesktop", False)
            wait_for(lambda: states(0, 2), "Leaving Show Desktop did not pause")
            root.playSource(url)
            wait_for(lambda: states(2, 0), "Fresh source while covered did not settle paused")
            QTest.qWait(100)
            assert states(2, 0), "Covered source began playing after load"
            assert not root.property("fallbackVisible"), "Paused fresh source hidden"
            root.setProperty("coveredCount", 0)
            wait_for(lambda: states(1, 0), "Uncover did not resume new active player")
            assert root.property("unexpectedAdvance") == 0, "Unexpected media error/advance"
    finally:
        sip.delete(root)
        sip.delete(component)
        sip.delete(engine)
        sip.delete(app)


class AerialPauseTests(unittest.TestCase):
    def test_production_qml_playback_policy(self):
        result = subprocess.run([sys.executable, "-B", "-I", str(Path(__file__).resolve()),
                                 "--qml-check"], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    if "--qml-check" in sys.argv:
        check_qml()
    else:
        unittest.main()

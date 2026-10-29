// Slider + live value label used by the shared appearance config page.
//
// `value` is an int so it can back an Int kcfg entry directly through a
// `cfg_*` alias. `format` turns the stored int into the displayed text
// (e.g. 170 -> "1.70"), so labels can show real units while the config
// keeps its scaled-int storage.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: field

    property int value: 0
    property int from: 0
    property int to: 100
    property int stepSize: 1
    property var format: (v) => String(v)

    spacing: Kirigami.Units.largeSpacing
    // Fill the form's field column so every slider has the same length.
    Layout.fillWidth: true

    QQC2.Slider {
        id: slider
        Layout.fillWidth: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        from: field.from
        to: field.to
        stepSize: field.stepSize
        snapMode: QQC2.Slider.SnapAlways
        // No tick marks: with fine steps they render as visual noise.
        Kirigami.StyleHints.tickMarkStepSize: -1
        value: field.value
        onMoved: field.value = Math.round(value)
    }

    QQC2.Label {
        id: valueLabel
        text: field.format(field.value)
        horizontalAlignment: Text.AlignRight
        font.features: { "tnum": 1 }
        // Same width for every field (and at least the widest value), so
        // sliders line up and dragging never shifts them.
        Layout.minimumWidth: Math.max(Kirigami.Units.gridUnit * 3.5,
                                      widest.advanceWidth, widestFrom.advanceWidth)

        TextMetrics { id: widest; font: valueLabel.font; text: field.format(field.to) }
        TextMetrics { id: widestFrom; font: valueLabel.font; text: field.format(field.from) }
    }
}

import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.15
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.brightnesscontrolplugin
import "../lib" as Lib
import "components/brightness" as BrightnessComponents

PageTemplate {
    id: brightnessControlPage

    sectionTitle: i18n("Brightness Control")

    property int contentItemHeight: scrollView.implicitHeight

    ScreenBrightnessControl {
        id: screenBrightnessControl
        isSilent: true
    }
    KeyboardBrightnessControl {
        id: keyboardBrightnessControl
        isSilent: true
    }

    readonly property Item firstItemAfterScreenBrightnessRepeater: keyboardBrightnessSlider.visible ? keyboardBrightnessSlider : keyboardBrightnessSlider.KeyNavigation.down
    KeyNavigation.down: screenBrightnessRepeater.firstSlider ?? firstItemAfterScreenBrightnessRepeater

    PlasmaComponents3.ScrollView {
        id: scrollView

        anchors.fill: parent

        focus: false

        function positionViewAtItem(item) {
            if (!PlasmaComponents3.ScrollBar.vertical.visible) {
                return;
            }
            const rect = brightnessList.mapFromItem(item, 0, 0, item.width, item.height);
            if (rect.y < scrollView.contentItem.contentY) {
                scrollView.contentItem.contentY = rect.y;
            } else if (rect.y + rect.height > scrollView.contentItem.contentY + scrollView.height) {
                scrollView.contentItem.contentY = rect.y + rect.height - scrollView.height;
            }
        }

        Column {
            id: brightnessList

            spacing: Kirigami.Units.smallSpacing * 2

            Repeater {
                id: screenBrightnessRepeater
                model: screenBrightnessControl.displays

                property int delegateRevision: 0
                function sliderAt(index) {
                    const revision = delegateRevision;
                    return itemAt(index);
                }
                function updateFocusChain() { ++delegateRevision; }

                property Item firstSlider: sliderAt(0)
                property Item lastSlider: sliderAt(count - 1)

                BrightnessComponents.BrightnessItem {
                    id: screenBrightnessSlider

                    required property int index
                    required property string displayName
                    required property string label
                    required property int brightness
                    required property int maxBrightness

                    property Item previousSlider: screenBrightnessRepeater.sliderAt(index - 1)
                    property Item nextSlider: screenBrightnessRepeater.sliderAt(index + 1)
                    onIndexChanged: Qt.callLater(screenBrightnessRepeater.updateFocusChain)

                    width: scrollView.availableWidth

                    icon.name: "video-display-brightness"
                    text: label
                    type: BrightnessComponents.BrightnessItem.Type.Screen
                    value: brightness
                    minimumValue: 0
                    maximumValue: maxBrightness

                    KeyNavigation.up: previousSlider ?? brightnessControlPage.KeyNavigation.up
                    KeyNavigation.down: nextSlider ?? firstItemAfterScreenBrightnessRepeater
                    KeyNavigation.backtab: previousSlider ?? brightnessControlPage.KeyNavigation.backtab
                    KeyNavigation.tab: KeyNavigation.down

                    stepSize: maxBrightness/100

                    onMoved: screenBrightnessControl.setBrightness(displayName, value)
                    onActiveFocusChanged: if (activeFocus) scrollView.positionViewAtItem(this)
                }

                // itemAt() is not reactive; defer until Repeater finishes removal/reordering.
                onItemAdded: Qt.callLater(updateFocusChain)
                onItemRemoved: Qt.callLater(updateFocusChain)
            }

            BrightnessComponents.BrightnessItem {
                id: keyboardBrightnessSlider

                width: scrollView.availableWidth

                icon.name: "input-keyboard-brightness"
                text: i18n("Keyboard Backlight")
                type: BrightnessComponents.BrightnessItem.Type.Keyboard
                value: keyboardBrightnessControl.brightness
                maximumValue: keyboardBrightnessControl.brightnessMax
                visible: keyboardBrightnessControl.isBrightnessAvailable

                KeyNavigation.up: screenBrightnessRepeater.lastSlider ?? brightnessControlPage.KeyNavigation.up
                KeyNavigation.down: keyboardColorItem.visible ? keyboardColorItem : keyboardColorItem.KeyNavigation.down
                KeyNavigation.backtab: KeyNavigation.up
                KeyNavigation.tab: KeyNavigation.down

                onMoved: keyboardBrightnessControl.brightness = value
                onActiveFocusChanged: if (activeFocus) scrollView.positionViewAtItem(this)

                // Manually dragging the slider around breaks the binding
                Connections {
                    target: keyboardBrightnessControl
                    function onBrightnessChanged() {
                        keyboardBrightnessSlider.value = keyboardBrightnessControl.brightness;
                    }
                }
            }

            BrightnessComponents.KeyboardColorItem {
                id: keyboardColorItem

                width: scrollView.availableWidth

                KeyNavigation.up: keyboardBrightnessSlider.visible ? keyboardBrightnessSlider : keyboardBrightnessSlider.KeyNavigation.up
              //  KeyNavigation.down: nightLightItem
                KeyNavigation.backtab: KeyNavigation.up
                KeyNavigation.tab: KeyNavigation.down

                text: i18n("Keyboard Color")
            }
        }
    }
}

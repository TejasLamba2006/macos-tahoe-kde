import QtQml 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.0
import "../components" as Components
import "components/ControlCenter" as LayoutComponents 
ColumnLayout {
    id: wrapper
    anchors.fill: parent
    spacing: 4
    GridLayout {
        Layout.preferredHeight: root.sectionHeight * 1.3
        Layout.maximumHeight: root.sectionHeight *1.3
    
        rows: 3
        columns: 4
        columnSpacing: 4
        rowSpacing: 4

        Components.NetworkBtn {
            Layout.columnSpan: 2
            isLongButton: true
            glassEffect: true
            roundedWidget: false
            cornerRadius: 16
        }

        Components.MediaPlayer{
            Layout.columnSpan: 2
            Layout.rowSpan: 2
            glassEffect: true
            roundedWidget: false
            cornerRadius: 16
        }

        Components.BluetoothBtn{
            width: height
            glassEffect: true
            noMargins: true
            fullSizeIcon: true
            title: ""
            showTitle: false
            roundedWidget: false
            cornerRadius: 16
            sourceColor: "transparent"
        }
        Components.ColorSchemeSwitcher{
            width: height
            glassEffect: true
            noMargins: true
            fullSizeIcon: true
            title: ""
            roundedWidget: false
            cornerRadius: 16
            sourceColor: "transparent"
        }

        Components.DndButton{
            Layout.columnSpan: 2
            glassEffect: true
            isLongButton: true
            roundedWidget: false
            cornerRadius: 16
        }

        Components.NightLight{
            width: height
            glassEffect: true
            noMargins: true
            isLongButton: true
            title: ""
            roundedWidget: false
            cornerRadius: 16
        }

        Components.KDEConnect{
            width: height
            glassEffect: true
            noMargins: true
            isLongButton: true
            title: ""
            roundedWidget: false
            cornerRadius: 16
        }
    }

    Components.BrightnessSlider{
        Layout.preferredHeight: (root.sectionHeight*1.3) / 3
        Layout.maximumHeight: Layout.preferredHeight
        canTogglePage: true
        glassEffect: true
        cornerRadius: 16
        mediumSizeSlider: true
    }
    Components.Volume{
        Layout.preferredHeight:  (root.sectionHeight*1.3) / 3
        Layout.maximumHeight: Layout.preferredHeight
        glassEffect: true
        cornerRadius: 16
        mediumSizeSlider: true
    }

     GridLayout {
        id: header
        property int extraWidgetsVisible: screenshot.visible + systemActions.visible + cmd1.visible + cmd2.visible
        Layout.preferredHeight: battery.visible && extraWidgetsVisible > 2 ? ((root.sectionHeight*1.3) / 3)*2 :  ((root.sectionHeight*1.3) / 3)
        Layout.maximumHeight: Layout.preferredHeight 

        rows: 2
        columns: 4
        columnSpacing: 4
        rowSpacing: 4
    
        Components.Battery {
            id: battery
            Layout.columnSpan: 2
            glassEffect: true
            roundedWidget: false
            cornerRadius: 16
            isLongButton: true
        }
        Components.ScreenshotBtn {
            id:screenshot
            width: height
            Layout.maximumWidth: width
            glassEffect: true
            noMargins: true
            isLongButton: true
            title: ""
            roundedWidget: false
            cornerRadius: 16
         }
        Components.SystemActions{
            id: systemActions
            Layout.maximumWidth: width
            width: height
            glassEffect: true
            noMargins: true
            roundedWidget: false
            cornerRadius: 16
        }
        Components.CommandRun{
            id: cmd1
            visible: root.showCmd1
            title: root.cmdTitle1
            icon: root.cmdIcon1
            command: root.cmdRun1
            glassEffect: true
            roundedWidget: false
            cornerRadius: 16
            isLongButton: title !="" ? true : false
            Layout.columnSpan: isLongButton ? 2 : 1
        }
        Components.CommandRun{
            id: cmd2
            visible: root.showCmd2
            title: root.cmdTitle2
            icon: root.cmdIcon2
            command: root.cmdRun2
            glassEffect: true
            roundedWidget: false
            cornerRadius: 16
            isLongButton: title != "" ? true : false
            Layout.columnSpan: isLongButton ? 2 : 1
        }
    }
}

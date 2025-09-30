import QtQuick
import Quickshell

PanelWindow {
    implicitHeight: 30

    anchors {
        top: true
        left: true
        right: true
    }

    Text {
        anchors.centerIn: parent
        text: "hello, world!"
    }

}

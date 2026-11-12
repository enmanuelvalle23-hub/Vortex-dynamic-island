import QtQuick
import QtQuick.Controls

Item {
    id: root
    property string text: ""
    property bool active: false
    signal clicked
    width: 108
    height: 40

    Rectangle {
        id: tabBg
        anchors.fill: parent
        color: root.active ? "#313244" : "transparent"
        radius: 0
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 12
        font.weight: root.active ? Font.Medium : Font.Normal
        color: root.active ? "#cdd6f4" : "#6c7086"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
import QtQuick 2.1
import qb.components 1.0

Tile {
    id: root

    property bool dimmed: screenStateController.dimmedColors
    property int catalogRevision: app.catalogRevision
    property int selectionRevision: app.selectionRevision

    onClicked: stage.openFullscreen(app.screenUrl)
    onVisibleChanged: if (visible) app.refresh()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 9
        color: root.dimmed ? "black" : "white"
        border.width: 5
        border.color: app.commissioned ? "#27936a" : (app.bridgeRunning ? "#e39b2f" : "#607d86")

        Text {
            anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
            text: "MATTER"
            color: root.dimmed ? "#dddddd" : "#4d6870"
            font { family: qfont.semiBold.name; pixelSize: isNxt ? 18 : 15 }
        }

        Image {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -5
            width: isNxt ? 70 : 56
            height: width
            source: "drawables/MatterBridgeIcon.svg"
            opacity: app.bridgeRunning ? 1 : 0.55
        }

        Rectangle {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            width: 47; height: 47; radius: 24
            color: root.dimmed ? "#294b50" : "#e1f3f8"
            border.color: root.dimmed ? "#82b5c5" : "#8cc8da"
            Text {
                anchors.centerIn: parent
                text: app.selectedCount()
                color: root.dimmed ? "white" : "#177493"
                font { family: qfont.semiBold.name; pixelSize: 25 }
            }
        }

        Text {
            anchors { bottom: parent.bottom; bottomMargin: 17; horizontalCenter: parent.horizontalCenter }
            width: parent.width - 24
            text: app.selectionCountLabel()
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: root.dimmed ? "#cccccc" : "#37645c"
            font.pixelSize: isNxt ? 15 : 13
        }
    }
}

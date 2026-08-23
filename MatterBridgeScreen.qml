import QtQuick 2.1
import qb.components 1.0

Screen {
    id: root
    screenTitle: "Matter Bridge"

    onShown: app.refresh()

    Column {
        anchors { fill: parent; leftMargin: 28; rightMargin: 28; topMargin: 8; bottomMargin: 8 }
        spacing: 7

        Item {
            width: parent.width; height: 55
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 12; height: 12; radius: 6
                color: app.commissioned ? "#2d9b68" : (app.bridgeRunning ? "#e39b2f" : "#b85b52")
            }
            Column {
                anchors { left: parent.left; leftMargin: 27; right: countColumn.left; rightMargin: 18; verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    text: app.connectionLabel()
                    color: "#304b53"
                    font { family: qfont.semiBold.name; pixelSize: 24 }
                }
                Text {
                    width: parent.width
                    text: app.bridgeMessage
                    elide: Text.ElideRight
                    color: "#718086"
                    font.pixelSize: qfont.metaText
                }
            }
            Column {
                id: countColumn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 220
                Text {
                    width: parent.width
                    text: app.selectedCount() + " van " + app.deviceCount() +
                        (app.commissioned ? " gedeeld" : " geselecteerd")
                    horizontalAlignment: Text.AlignRight
                    color: "#176781"
                    font { family: qfont.semiBold.name; pixelSize: qfont.bodyText }
                }
                Text {
                    width: parent.width
                    text: "Keuze wordt direct bewaard"
                    horizontalAlignment: Text.AlignRight
                    color: "#718086"
                    font.pixelSize: qfont.metaText
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: "#d7dddf" }

        Flickable {
            id: overview
            width: parent.width
            height: parent.height - 70
            contentWidth: width
            contentHeight: overviewColumn.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: overviewColumn
                width: overview.width
                spacing: 8

                Rectangle {
                    visible: app.pairingCode.length > 0
                    width: parent.width; height: visible ? 158 : 0
                    radius: 8
                    color: "#e9f4f7"
                    border.color: "#b9d5dc"

                    Column {
                        anchors { left: parent.left; leftMargin: 22; right: pairingQr.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        spacing: 9
                        Text {
                            width: parent.width
                            text: "Koppelen met Google Home"
                            color: "#304b53"
                            font { family: qfont.semiBold.name; pixelSize: qfont.bodyText }
                        }
                        Text {
                            width: parent.width
                            text: "Scan de QR-code of voer deze code in:"
                            wrapMode: Text.WordWrap
                            color: "#718086"
                            font.pixelSize: qfont.metaText
                        }
                        Text {
                            width: parent.width
                            text: app.formattedPairingCode()
                            color: "#176781"
                            font { family: qfont.semiBold.name; pixelSize: 27 }
                        }
                    }
                    Rectangle {
                        id: pairingQr
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 136; height: 136
                        color: "white"
                        Image {
                            anchors { fill: parent; margins: 5 }
                            source: app.pairingQrImage
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "Apparaten doorsturen via Matter"
                    color: "#304b53"
                    font { family: qfont.semiBold.name; pixelSize: qfont.bodyText }
                }

                Repeater {
                    model: app.knownDevices
                    delegate: Rectangle {
                        width: overviewColumn.width; height: 62
                        radius: 8
                        color: app.selected(modelData.id) ? "#edf8f3" : (index % 2 === 0 ? "#f5f8f8" : "#edf3f3")
                        border.width: app.selected(modelData.id) ? 2 : 1
                        border.color: app.selected(modelData.id) ? "#4aa47d" : "#d2dddf"

                        Rectangle {
                            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                            width: 13; height: 13; radius: 7
                            color: modelData.online ? "#31a26a" : "#a9b4b7"
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 44; top: parent.top; topMargin: 8 }
                            width: 470
                            text: modelData.name
                            elide: Text.ElideRight
                            color: "#304b53"
                            font { family: qfont.semiBold.name; pixelSize: qfont.bodyText }
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 44; bottom: parent.bottom; bottomMargin: 7 }
                            width: 540
                            text: modelData.detail + (modelData.online ? " · online" : " · offline")
                            elide: Text.ElideRight
                            color: "#718086"
                            font.pixelSize: qfont.metaText
                        }
                        Text {
                            anchors { right: shareCheck.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "Via Matter"
                            color: "#5c706f"
                            font.pixelSize: qfont.metaText
                        }
                        Rectangle {
                            id: shareCheck
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            width: 38; height: 38; radius: 6
                            color: app.selected(modelData.id) ? "#d9f0e6" : "#ffffff"
                            border.width: app.selected(modelData.id) ? 3 : 2
                            border.color: app.selected(modelData.id) ? "#27936a" : "#9eb1b6"
                            Text {
                                anchors.centerIn: parent
                                text: app.selected(modelData.id) ? "✓" : ""
                                color: "#176846"
                                font { family: qfont.semiBold.name; pixelSize: 27 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: app.setSelected(modelData.id, !app.selected(modelData.id))
                            }
                        }
                    }
                }

                Text {
                    visible: app.deviceCount() === 0
                    width: parent.width
                    text: app.catalogError
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: "#a05b37"
                    font.pixelSize: qfont.bodyText
                }

                Text {
                    width: parent.width
                    text: "Niet aanwezige apparaten verdwijnen automatisch. Een tijdelijk offline apparaat blijft zichtbaar en geselecteerd."
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: "#718086"
                    font.pixelSize: qfont.metaText
                }
                Item { width: 1; height: 8 }
            }
        }
    }
}

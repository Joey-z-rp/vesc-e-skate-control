import QtQuick 2.5
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import Vedder.vesc.commands 1.0

Item {
    id: container
    anchors.fill: parent
    anchors.margins: 10

    property Commands mCommands: VescIf.commands()
    property bool parkingBrakeActive: false
    property bool torqueVectorActive: false
    property real leftPct: 0.0
    property real rightPct: 0.0

    // 100% when TV not applying, actual value when applying
    property int displayLeftPct:  torqueVectorActive ? (leftPct  !== 0 ? leftPct  : 100) : 100
    property int displayRightPct: torqueVectorActive ? (rightPct !== 0 ? rightPct : 100) : 100
    property color wheelColor: torqueVectorActive ? "#4CAF50" : "#666666"

    function sendParkingBrakeCmd(active) {
        var buffer = new ArrayBuffer(2)
        var dv = new DataView(buffer)
        dv.setUint8(0, 1) // CMD_SET_PARKING_BRAKE
        dv.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(buffer)
    }

    function sendTorqueVectorCmd(active) {
        var buffer = new ArrayBuffer(2)
        var dv = new DataView(buffer)
        dv.setUint8(0, 3) // CMD_SET_TORQUE_VECTOR
        dv.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(buffer)
    }

    Connections {
        target: mCommands
        function onCustomAppDataReceived(data) {
            var dv = new DataView(data)
            var cmd = dv.getUint8(0)
            if (cmd === 1) { // CMD_SET_PARKING_BRAKE
                container.parkingBrakeActive = dv.getUint8(1) !== 0
                parkingBrakeSwitch.checked = container.parkingBrakeActive
            } else if (cmd === 5) { // CMD_TV_STATE
                container.torqueVectorActive = dv.getUint8(1) !== 0
                torqueVectorSwitch.checked = container.torqueVectorActive
                container.leftPct = dv.getInt16(2)
                container.rightPct = dv.getInt16(4)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Parking Brake"
                font.pixelSize: 16
            }

            Item { Layout.fillWidth: true }

            Switch {
                id: parkingBrakeSwitch
                onToggled: {
                    container.parkingBrakeActive = checked
                    sendParkingBrakeCmd(checked)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Torque Vectoring"
                font.pixelSize: 16
            }

            Item { Layout.fillWidth: true }

            Switch {
                id: torqueVectorSwitch
                onToggled: {
                    container.torqueVectorActive = checked
                    sendTorqueVectorCmd(checked)
                }
            }
        }

        // Wheel visualisation — rear view of the board
        Item {
            Layout.fillWidth: true
            height: 110

            Row {
                anchors.centerIn: parent
                spacing: 0

                // Left wheel
                Rectangle {
                    width: 34
                    height: 90
                    radius: 7
                    color: container.wheelColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "L"
                            font.pixelSize: 10
                            color: "#ffffff"
                            opacity: 0.6
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: container.displayLeftPct + "%"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#ffffff"
                        }
                    }
                }

                // Board deck
                Item {
                    width: 88
                    height: 90

                    Rectangle {
                        width: parent.width
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#444444"
                        radius: 4
                    }
                }

                // Right wheel
                Rectangle {
                    width: 34
                    height: 90
                    radius: 7
                    color: container.wheelColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "R"
                            font.pixelSize: 10
                            color: "#ffffff"
                            opacity: 0.6
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: container.displayRightPct + "%"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#ffffff"
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}

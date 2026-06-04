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

        RowLayout {
            Layout.fillWidth: true
            visible: container.torqueVectorActive

            Label {
                text: "Left"
                font.pixelSize: 14
                color: "#888"
            }
            Label {
                text: container.leftPct + "%"
                font.pixelSize: 14
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "Right"
                font.pixelSize: 14
                color: "#888"
            }
            Label {
                text: container.rightPct + "%"
                font.pixelSize: 14
            }
        }
    }
}

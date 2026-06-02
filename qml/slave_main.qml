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

    function sendParkingBrakeCmd(active) {
        var buffer = new ArrayBuffer(2)
        var dv = new DataView(buffer)
        dv.setUint8(0, 1) // CMD_SET_PARKING_BRAKE
        dv.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(buffer)
    }

    Connections {
        target: mCommands
        function onCustomAppDataReceived(data) {
            var dv = new DataView(data)
            if (dv.getUint8(0) === 1) {
                container.parkingBrakeActive = dv.getUint8(1) !== 0
                parkingBrakeSwitch.checked = container.parkingBrakeActive
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent

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
    }
}

import QtQuick 2.5
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import Vedder.vesc.commands 1.0

Item {
    id: container
    anchors.fill: parent
    anchors.margins: 10

    property Commands mCommands: VescIf.commands()

    ColumnLayout {
        anchors.fill: parent

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            text: "Beep"

            onClicked: {
                var buffer = new ArrayBuffer(1)
                var dv = new DataView(buffer)
                dv.setUint8(0, 1) // command: beep
                mCommands.sendCustomAppData(buffer)
            }
        }
    }
}

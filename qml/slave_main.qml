import QtQuick 2.5
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import Vedder.vesc.commands 1.0

Item {
    id: container
    anchors.fill: parent
    anchors.topMargin: 50
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    anchors.bottomMargin: 10

    property Commands mCommands: VescIf.commands()
    property bool parkingBrakeActive: false
    property bool torqueVectorActive: false
    property real leftPct: 0.0
    property real rightPct: 0.0
    property real tvK: 0.1
    property real tvG: 0.001
    property bool absActive: false
    property bool absEngaged: false
    property bool wobbleActive: false
    property bool wobbleDetected: false
    property real wobbleAmp: 30.0
    property real wobbleScoreAdd: 5.0
    property real wobbleScoreDecay: 0.1

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

    function sendWobbleParams() {
        var buffer = new ArrayBuffer(7)
        var dv = new DataView(buffer)
        dv.setUint8(0, 9) // CMD_SET_WOBBLE_PARAMS
        dv.setInt16(1, Math.round(container.wobbleAmp * 10))
        dv.setInt16(3, Math.round(container.wobbleScoreAdd * 10))
        dv.setInt16(5, Math.round(container.wobbleScoreDecay * 100))
        mCommands.sendCustomAppData(buffer)
    }

    function sendWobbleCmd(active) {
        var buffer = new ArrayBuffer(2)
        var dv = new DataView(buffer)
        dv.setUint8(0, 8) // CMD_SET_WOBBLE
        dv.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(buffer)
    }

    function sendAbsCmd(active) {
        var buffer = new ArrayBuffer(2)
        var dv = new DataView(buffer)
        dv.setUint8(0, 7) // CMD_SET_ABS
        dv.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(buffer)
    }

    function sendTvParams() {
        var buffer = new ArrayBuffer(5)
        var dv = new DataView(buffer)
        dv.setUint8(0, 6) // CMD_SET_TV_PARAMS
        dv.setInt16(1, Math.round(container.tvK * 100))
        dv.setInt16(3, Math.round(container.tvG * 10000))
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
            if (dv.getUint8(0) !== 5) return // CMD_TV_STATE
            container.parkingBrakeActive = dv.getUint8(1) !== 0
            parkingBrakeSwitch.checked = container.parkingBrakeActive
            container.torqueVectorActive = dv.getUint8(2) !== 0
            torqueVectorSwitch.checked = container.torqueVectorActive
            container.leftPct = dv.getInt16(3)
            container.rightPct = dv.getInt16(5)
            container.absActive = dv.getUint8(7) !== 0
            container.absEngaged = dv.getUint8(8) !== 0
            container.wobbleActive = dv.getUint8(9) !== 0
            container.wobbleDetected = dv.getUint8(10) !== 0
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

            Label {
                text: "ABS"
                font.pixelSize: 16
            }

            Label {
                text: container.absEngaged ? "ACTIVE" : "READY"
                font.pixelSize: 12
                font.bold: container.absEngaged
                color: container.absEngaged ? "#e53935" : "#888"
            }

            Item { Layout.fillWidth: true }

            Switch {
                id: absSwitch
                onToggled: {
                    container.absActive = checked
                    sendAbsCmd(checked)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Wobble Control"
                font.pixelSize: 16
            }

            Label {
                text: container.wobbleDetected ? "ACTIVE" : "READY"
                font.pixelSize: 12
                font.bold: container.wobbleDetected
                color: container.wobbleDetected ? "#FF6F00" : "#888"
            }

            Item { Layout.fillWidth: true }

            Switch {
                id: wobbleSwitch
                onToggled: {
                    container.wobbleActive = checked
                    sendWobbleCmd(checked)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Amp"; font.pixelSize: 14; color: "#888" }
            Slider {
                from: 0; to: 200; stepSize: 1
                value: container.wobbleAmp
                Layout.fillWidth: true
                onMoved: { container.wobbleAmp = value; sendWobbleParams() }
            }
            Label { text: container.wobbleAmp.toFixed(0) + "°/s"; font.pixelSize: 14 }
        }

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Add"; font.pixelSize: 14; color: "#888" }
            Slider {
                from: 0; to: 20; stepSize: 0.1
                value: container.wobbleScoreAdd
                Layout.fillWidth: true
                onMoved: { container.wobbleScoreAdd = value; sendWobbleParams() }
            }
            Label { text: container.wobbleScoreAdd.toFixed(1); font.pixelSize: 14 }
        }

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Decay"; font.pixelSize: 14; color: "#888" }
            Slider {
                from: 0; to: 2; stepSize: 0.01
                value: container.wobbleScoreDecay
                Layout.fillWidth: true
                onMoved: { container.wobbleScoreDecay = value; sendWobbleParams() }
            }
            Label { text: container.wobbleScoreDecay.toFixed(2); font.pixelSize: 14 }
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

        // TV tuning parameters
        RowLayout {
            Layout.fillWidth: true

            Label { text: "K"; font.pixelSize: 14; color: "#888" }
            Slider {
                id: kSlider
                from: 0.0; to: 1.0; stepSize: 0.01
                value: container.tvK
                Layout.fillWidth: true
                onMoved: {
                    container.tvK = value
                    sendTvParams()
                }
            }
            Label {
                text: container.tvK.toFixed(2)
                font.pixelSize: 14
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label { text: "G"; font.pixelSize: 14; color: "#888" }
            Slider {
                id: gSlider
                from: 0.0; to: 0.01; stepSize: 0.0001
                value: container.tvG
                Layout.fillWidth: true
                onMoved: {
                    container.tvG = value
                    sendTvParams()
                }
            }
            Label {
                text: container.tvG.toFixed(4)
                font.pixelSize: 14
                horizontalAlignment: Text.AlignRight
            }
        }

        Item { Layout.fillHeight: true }
    }
}

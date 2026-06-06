import QtQuick 2.7
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import Vedder.vesc.commands 1.0
import "qrc:/mobile"

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
    property real tvK: 0.08
    property real tvG: 0.0008
    property bool absActive: false
    property bool absEngaged: false
    property bool wobbleActive: false
    property bool wobbleDetected: false
    property real wobbleAmp: 30.0
    property real wobbleScoreAdd: 5.0
    property real wobbleScoreDecay: 0.05
    property real speedMs: 0.0

    property int displayLeftPct:  torqueVectorActive ? (leftPct  !== 0 ? leftPct  : 100) : 100
    property int displayRightPct: torqueVectorActive ? (rightPct !== 0 ? rightPct : 100) : 100

    function _hex(n) {
        var h = Math.max(0, Math.min(255, Math.round(n))).toString(16)
        return h.length === 1 ? "0" + h : h
    }
    function _lerp(r1,g1,b1, r2,g2,b2, t) {
        t = Math.max(0, Math.min(1, t))
        return "#" + _hex(r1+(r2-r1)*t) + _hex(g1+(g2-g1)*t) + _hex(b1+(b2-b1)*t)
    }
    function pctToColor(pct, active) {
        if (!active) return "#555555"
        if (pct >= 100) {
            // green (100%) → blue (at +20%) → purple (at +50%)
            var t = Math.min((pct - 100) / 50, 1)
            return t < 0.4
                ? _lerp(76,175,80,  33,150,243, t / 0.4)           // green → blue
                : _lerp(33,150,243, 103,58,183, (t - 0.4) / 0.6)   // blue → purple
        } else {
            // green (100%) → orange (at -20%) → red (at -50%)
            var t = Math.min((100 - pct) / 50, 1)
            return t < 0.4
                ? _lerp(76,175,80,  255,152,0, t / 0.4)            // green → orange
                : _lerp(255,152,0,  244,67,54, (t - 0.4) / 0.6)    // orange → red
        }
    }

    property color leftWheelColor:  pctToColor(displayLeftPct,  torqueVectorActive)
    property color rightWheelColor: pctToColor(displayRightPct, torqueVectorActive)

    // ── Outbound commands ──────────────────────────────────────────
    function sendParkingBrakeCmd(active) {
        var b = new ArrayBuffer(2); var d = new DataView(b)
        d.setUint8(0, 1); d.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(b)
    }
    function sendTorqueVectorCmd(active) {
        var b = new ArrayBuffer(2); var d = new DataView(b)
        d.setUint8(0, 3); d.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(b)
    }
    function sendTvParams() {
        var b = new ArrayBuffer(5); var d = new DataView(b)
        d.setUint8(0, 6)
        d.setInt16(1, Math.round(container.tvK * 100))
        d.setInt16(3, Math.round(container.tvG * 10000))
        mCommands.sendCustomAppData(b)
    }
    function sendAbsCmd(active) {
        var b = new ArrayBuffer(2); var d = new DataView(b)
        d.setUint8(0, 7); d.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(b)
    }
    function sendWobbleCmd(active) {
        var b = new ArrayBuffer(2); var d = new DataView(b)
        d.setUint8(0, 8); d.setUint8(1, active ? 1 : 0)
        mCommands.sendCustomAppData(b)
    }
    function sendWobbleParams() {
        var b = new ArrayBuffer(7); var d = new DataView(b)
        d.setUint8(0, 9)
        d.setInt16(1, Math.round(container.wobbleAmp * 10))
        d.setInt16(3, Math.round(container.wobbleScoreAdd * 10))
        d.setInt16(5, Math.round(container.wobbleScoreDecay * 100))
        mCommands.sendCustomAppData(b)
    }

    // ── Inbound state ──────────────────────────────────────────────
    Connections {
        target: mCommands
        function onCustomAppDataReceived(data) {
            var dv = new DataView(data)
            if (dv.getUint8(0) !== 5) return
            container.parkingBrakeActive = dv.getUint8(1) !== 0
            parkingBrakeSwitch.on = container.parkingBrakeActive
            if (parkingBrakeSwitch.item) parkingBrakeSwitch.item.on = parkingBrakeSwitch.on
            container.torqueVectorActive = dv.getUint8(2) !== 0
            torqueVectorSwitch.on = container.torqueVectorActive
            if (torqueVectorSwitch.item) torqueVectorSwitch.item.on = torqueVectorSwitch.on
            container.leftPct = dv.getInt16(3)
            container.rightPct = dv.getInt16(5)
            container.absActive  = dv.getUint8(7) !== 0
            absSwitch.on = container.absActive
            if (absSwitch.item) absSwitch.item.on = absSwitch.on
            container.absEngaged = dv.getUint8(8) !== 0
            container.wobbleActive   = dv.getUint8(9)  !== 0
            wobbleSwitch.on = container.wobbleActive
            if (wobbleSwitch.item) wobbleSwitch.item.on = wobbleSwitch.on
            container.wobbleDetected = dv.getUint8(10) !== 0
            container.speedMs = dv.getInt16(11) / 10.0
        }
    }

    // Inline pill toggle — reused via aliased properties
    // on:      bool — current state
    // onColor: color — track color when on
    // toggled: signal
    Component {
        id: toggleComponent
        Item {
            id: tog
            width: 56; height: 30
            property bool on: false
            property color onColor: "#4CAF50"
            signal toggled(bool state)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: tog.on ? tog.onColor : "#555"
                Behavior on color { ColorAnimation { duration: 180 } }

                Rectangle {
                    width: 26; height: 26; radius: 13
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: tog.on ? parent.width - width - 2 : 2
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: { tog.on = !tog.on; tog.toggled(tog.on) }
                }
            }
        }
    }

    // ── Layout ─────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Speedometer — always visible
        CustomGaugeV2 {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            minimumValue: 0; maximumValue: 60
            labelStep: 10; tickmarkScale: 1; tickmarkSuffix: ""
            unitText: "km/h"; typeText: "Speed"
            value: Math.abs(container.speedMs) * 3.6
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton { text: "Main" }
            TabButton { text: "Stability" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // ── Tab 1: Main ────────────────────────────────────────
            ScrollView {
                contentWidth: -1; clip: true
                ColumnLayout {
                    width: container.width - 20
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Parking Brake"; font.pixelSize: 16 }

                        // Indicator — fades in when engaged, space always reserved
                        Item {
                            width: 90; height: 36
                            opacity: container.parkingBrakeActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Rectangle {
                                anchors.centerIn: pbBadge
                                width: pbBadge.width + 14; height: pbBadge.height + 14
                                radius: height / 2; color: "#e53935"; opacity: 0.18
                            }
                            Rectangle {
                                anchors.centerIn: pbBadge
                                width: pbBadge.width + 6; height: pbBadge.height + 6
                                radius: height / 2; color: "#e53935"; opacity: 0.30
                            }
                            Rectangle {
                                id: pbBadge
                                anchors.centerIn: parent
                                width: 78; height: 28; radius: 6
                                color: "#b71c1c"
                                border.color: "#ef5350"; border.width: 1

                                Row {
                                    anchors.centerIn: parent; spacing: 5
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "#ff5252"
                                    }
                                    Label {
                                        text: "ENGAGED"
                                        font.pixelSize: 11; font.bold: true
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                        Loader {
                            id: parkingBrakeSwitch
                            sourceComponent: toggleComponent
                            property bool on: false
                            onLoaded: {
                                item.on = parkingBrakeSwitch.on
                                item.toggled.connect(function(state) {
                                    parkingBrakeSwitch.on = state
                                    container.parkingBrakeActive = state
                                    sendParkingBrakeCmd(state)
                                })
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "ABS"; font.pixelSize: 16 }

                        // Indicator badge — fades in when ABS is enabled
                        Item {
                            width: 86; height: 36
                            opacity: container.absActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            // Glow halos (active only)
                            Rectangle {
                                anchors.centerIn: absBadge
                                width: absBadge.width + 14; height: absBadge.height + 14
                                radius: height / 2; color: "#FF6F00"; opacity: 0.18
                                visible: container.absEngaged
                            }
                            Rectangle {
                                anchors.centerIn: absBadge
                                width: absBadge.width + 6; height: absBadge.height + 6
                                radius: height / 2; color: "#FF6F00"; opacity: 0.30
                                visible: container.absEngaged
                            }

                            Rectangle {
                                id: absBadge
                                anchors.centerIn: parent
                                width: 72; height: 28; radius: 6
                                color: container.absEngaged ? "#bf360c" : "#1b3a1b"
                                border.color: container.absEngaged ? "#FF7043" : "#4CAF50"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 250 } }

                                Row {
                                    anchors.centerIn: parent; spacing: 5
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: container.absEngaged ? "#FF8F00" : "#66BB6A"
                                        Behavior on color { ColorAnimation { duration: 250 } }
                                    }
                                    Label {
                                        text: container.absEngaged ? "ACTIVE" : "READY"
                                        font.pixelSize: 11; font.bold: container.absEngaged
                                        color: container.absEngaged ? "white" : "#a5d6a7"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: 250 } }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                        Loader {
                            id: absSwitch
                            sourceComponent: toggleComponent
                            property bool on: false
                            onLoaded: {
                                item.on = absSwitch.on
                                item.toggled.connect(function(state) {
                                    absSwitch.on = state
                                    container.absActive = state
                                    sendAbsCmd(state)
                                })
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Torque Vectoring"; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        Loader {
                            id: torqueVectorSwitch
                            sourceComponent: toggleComponent
                            property bool on: false
                            onLoaded: {
                                item.on = torqueVectorSwitch.on
                                item.toggled.connect(function(state) {
                                    torqueVectorSwitch.on = state
                                    container.torqueVectorActive = state
                                    sendTorqueVectorCmd(state)
                                })
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
                                width: 50; height: 90; radius: 8
                                color: container.leftWheelColor
                                Behavior on color { ColorAnimation { duration: 300 } }

                                Column {
                                    anchors.centerIn: parent; spacing: 4
                                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "L"; font.pixelSize: 10; color: "#fff"; opacity: 0.6 }
                                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: container.displayLeftPct + "%"; font.pixelSize: 12; font.bold: true; color: "#fff" }
                                }
                            }

                            // Truck hanger
                            Canvas {
                                width: 80; height: 90
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cy = height / 2
                                    var outerHalf = 14   // height at wheel connection
                                    var innerHalf = 5    // height of centre axle bar
                                    var taperX    = 22   // x where taper finishes

                                    ctx.beginPath()
                                    ctx.moveTo(0,           cy - outerHalf)
                                    ctx.lineTo(taperX,      cy - innerHalf)
                                    ctx.lineTo(width - taperX, cy - innerHalf)
                                    ctx.lineTo(width,       cy - outerHalf)
                                    ctx.lineTo(width,       cy + outerHalf)
                                    ctx.lineTo(width - taperX, cy + innerHalf)
                                    ctx.lineTo(taperX,      cy + innerHalf)
                                    ctx.lineTo(0,           cy + outerHalf)
                                    ctx.closePath()
                                    ctx.fillStyle   = "#484848"
                                    ctx.fill()
                                    ctx.strokeStyle = "#5a5a5a"
                                    ctx.lineWidth   = 1
                                    ctx.stroke()
                                }
                            }

                            // Right wheel
                            Rectangle {
                                width: 50; height: 90; radius: 8
                                color: container.rightWheelColor
                                Behavior on color { ColorAnimation { duration: 300 } }

                                Column {
                                    anchors.centerIn: parent; spacing: 4
                                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "R"; font.pixelSize: 10; color: "#fff"; opacity: 0.6 }
                                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: container.displayRightPct + "%"; font.pixelSize: 12; font.bold: true; color: "#fff" }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "K"; font.pixelSize: 14; color: "#888" }
                        Slider {
                            from: 0.0; to: 0.2; stepSize: 0.01; value: container.tvK; Layout.fillWidth: true
                            onMoved: { container.tvK = value; sendTvParams() }
                        }
                        Label { text: container.tvK.toFixed(2); font.pixelSize: 14 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "G"; font.pixelSize: 14; color: "#888" }
                        Slider {
                            from: 0.0; to: 0.002; stepSize: 0.0001; value: container.tvG; Layout.fillWidth: true
                            onMoved: { container.tvG = value; sendTvParams() }
                        }
                        Label { text: container.tvG.toFixed(4); font.pixelSize: 14 }
                    }
                }
            }

            // ── Tab 2: Wobble ──────────────────────────────────────
            ScrollView {
                contentWidth: -1; clip: true
                ColumnLayout {
                    width: container.width - 20
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Wobble Detection"; font.pixelSize: 16 }

                        // Indicator badge — fades in when wobble is enabled
                        Item {
                            width: 86; height: 36
                            opacity: container.wobbleActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Rectangle {
                                anchors.centerIn: wobbleBadge
                                width: wobbleBadge.width + 14; height: wobbleBadge.height + 14
                                radius: height / 2; color: "#FF6F00"; opacity: 0.18
                                visible: container.wobbleDetected
                            }
                            Rectangle {
                                anchors.centerIn: wobbleBadge
                                width: wobbleBadge.width + 6; height: wobbleBadge.height + 6
                                radius: height / 2; color: "#FF6F00"; opacity: 0.30
                                visible: container.wobbleDetected
                            }
                            Rectangle {
                                id: wobbleBadge
                                anchors.centerIn: parent
                                width: 72; height: 28; radius: 6
                                color: container.wobbleDetected ? "#bf360c" : "#1b3a1b"
                                border.color: container.wobbleDetected ? "#FF7043" : "#4CAF50"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 250 } }

                                Row {
                                    anchors.centerIn: parent; spacing: 5
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: container.wobbleDetected ? "#FF8F00" : "#66BB6A"
                                        Behavior on color { ColorAnimation { duration: 250 } }
                                    }
                                    Label {
                                        text: container.wobbleDetected ? "DETECTED" : "READY"
                                        font.pixelSize: 11; font.bold: container.wobbleDetected
                                        color: container.wobbleDetected ? "white" : "#a5d6a7"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: 250 } }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                        Loader {
                            id: wobbleSwitch
                            sourceComponent: toggleComponent
                            property bool on: false
                            onLoaded: {
                                item.on = wobbleSwitch.on
                                item.toggled.connect(function(state) {
                                    wobbleSwitch.on = state
                                    container.wobbleActive = state
                                    sendWobbleCmd(state)
                                })
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Amp"; font.pixelSize: 14; color: "#888" }
                        Slider {
                            from: 0; to: 200; stepSize: 1; value: container.wobbleAmp; Layout.fillWidth: true
                            onMoved: { container.wobbleAmp = value; sendWobbleParams() }
                        }
                        Label { text: container.wobbleAmp.toFixed(0) + "°/s"; font.pixelSize: 14 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Add"; font.pixelSize: 14; color: "#888" }
                        Slider {
                            from: 0; to: 20; stepSize: 0.1; value: container.wobbleScoreAdd; Layout.fillWidth: true
                            onMoved: { container.wobbleScoreAdd = value; sendWobbleParams() }
                        }
                        Label { text: container.wobbleScoreAdd.toFixed(1); font.pixelSize: 14 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Decay"; font.pixelSize: 14; color: "#888" }
                        Slider {
                            from: 0; to: 0.3; stepSize: 0.01; value: container.wobbleScoreDecay; Layout.fillWidth: true
                            onMoved: { container.wobbleScoreDecay = value; sendWobbleParams() }
                        }
                        Label { text: container.wobbleScoreDecay.toFixed(2); font.pixelSize: 14 }
                    }
                }
            }
        }
    }
}

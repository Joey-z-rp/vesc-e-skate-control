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
    property real speedMs: 0.0
    property real remoteThrottle: 0.0
    property bool virtEnabled: false
    property bool virtMasterEnabled: true
    property bool virtSlaveEnabled: true
    property real virtThrottle: 0.0   // raw slider: -1.0 (full brake) to +1.0 (full throttle)
    readonly property real virtMax: 0.4
    readonly property real virtBrakeMax: 1.0
    readonly property real virtDeadband: 0.15

    // Same deadband on both sides; rescales each direction so output starts at 0 at the threshold
    property real virtEffective: {
        if (virtThrottle > virtDeadband)
            return (virtThrottle - virtDeadband) / (1.0 - virtDeadband) * virtMax
        if (virtThrottle < -virtDeadband)
            return (virtThrottle + virtDeadband) / (1.0 - virtDeadband) * virtBrakeMax
        return 0.0
    }

    // Remote is considered neutral when below gesture deadband
    property bool remoteNeutral: Math.abs(remoteThrottle) < 0.03
    // Virtual throttle is actually driving when enabled and remote is idle
    property bool virtActive: virtEnabled && remoteNeutral

    // CMD IDs for master custom app data protocol
    readonly property int cmdMasterState:     10
    readonly property int cmdVirtualThrottle: 11

    // Send virtual throttle state to master LispBM
    // Layout: u8 cmd | u8 enabled | i16 throttle×10000 | u8 masterEn | u8 slaveEn
    function sendVirtualThrottle() {
        const b = new ArrayBuffer(6)
        const d = new DataView(b)
        d.setUint8(0, cmdVirtualThrottle)
        d.setUint8(1, container.virtEnabled ? 1 : 0)
        d.setInt16(2, Math.round(container.virtEffective * 10000))
        d.setUint8(4, container.virtMasterEnabled ? 1 : 0)
        d.setUint8(5, container.virtSlaveEnabled ? 1 : 0)
        mCommands.sendCustomAppData(b)
    }

    // Poll at 10 Hz, only while virtual throttle is enabled
    Timer {
        interval: 100
        running: container.virtEnabled
        repeat: true
        onTriggered: container.sendVirtualThrottle()
    }

    // Receive state broadcast from master LispBM (cmdMasterState = 10)
    // Packet layout: u8 cmd | i16 speed×100 | i16 remoteThrottle×10000
    Connections {
        target: mCommands
        function onCustomAppDataReceived(data) {
            const dv = new DataView(data)
            if (dv.getUint8(0) !== container.cmdMasterState) return
            container.speedMs      = dv.getInt16(1) / 100.0
            container.remoteThrottle = dv.getInt16(3) / 10000.0
        }
    }

    // Reusable pill toggle — same as slave_main.qml
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ── Speedometer ───────────────────────────────────────────────
        CustomGauge {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: container.width / 2
            Layout.preferredHeight: container.width / 2
            minimumValue: 0; maximumValue: 60
            labelStep: 10; tickmarkScale: 1
            precision: 1
            unitText: "km/h"; typeText: "Speed"
            value: Math.abs(container.speedMs) * 3.6
        }

        // ── Virtual throttle header row ───────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Label { text: "Virtual Throttle"; font.pixelSize: 16 }

            // ARMED / ACTIVE badge — only visible when enabled
            Item {
                width: 90; height: 36
                opacity: container.virtEnabled ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                // Outer glow (active only)
                Rectangle {
                    anchors.centerIn: vtBadge
                    width: vtBadge.width + 14; height: vtBadge.height + 14
                    radius: height / 2
                    color: container.virtActive ? "#00C853" : "#FF9800"
                    opacity: 0.18
                    visible: container.virtActive
                }
                Rectangle {
                    anchors.centerIn: vtBadge
                    width: vtBadge.width + 6; height: vtBadge.height + 6
                    radius: height / 2
                    color: container.virtActive ? "#00C853" : "#FF9800"
                    opacity: 0.30
                    visible: container.virtActive
                }

                Rectangle {
                    id: vtBadge
                    anchors.centerIn: parent
                    width: 78; height: 28; radius: 6
                    color: container.virtActive ? "#1b5e20" : "#4a2c00"
                    border.color: container.virtActive ? "#69F0AE" : "#FF9800"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: container.virtActive ? "#69F0AE" : "#FF9800"
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                        Label {
                            text: container.virtActive ? "ACTIVE" : "ARMED"
                            font.pixelSize: 11; font.bold: container.virtActive
                            color: container.virtActive ? "white" : "#FFCC80"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Loader {
                id: virtSwitch
                sourceComponent: toggleComponent
                property bool on: false
                onLoaded: {
                    item.on = virtSwitch.on
                    item.onColor = "#FF9800"
                    item.toggled.connect(function(state) {
                        virtSwitch.on = state
                        container.virtEnabled = state
                        if (!state) container.virtThrottle = 0.0
                        container.sendVirtualThrottle()
                    })
                }
            }
        }

        // ── Motor select row ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            opacity: container.virtEnabled ? 1.0 : 0.4
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Item { Layout.fillWidth: true }

            Label { text: "Master"; font.pixelSize: 13; color: "#aaa" }
            Loader {
                id: masterSwitch
                sourceComponent: toggleComponent
                property bool on: true
                onLoaded: {
                    item.on = masterSwitch.on
                    item.onColor = "#FF9800"
                    item.toggled.connect(function(state) {
                        masterSwitch.on = state
                        container.virtMasterEnabled = state
                        container.sendVirtualThrottle()
                    })
                }
            }

            Item { width: 16 }

            Label { text: "Slave"; font.pixelSize: 13; color: "#aaa" }
            Loader {
                id: slaveSwitch
                sourceComponent: toggleComponent
                property bool on: true
                onLoaded: {
                    item.on = slaveSwitch.on
                    item.onColor = "#FF9800"
                    item.toggled.connect(function(state) {
                        slaveSwitch.on = state
                        container.virtSlaveEnabled = state
                        container.sendVirtualThrottle()
                    })
                }
            }

            Item { Layout.fillWidth: true }
        }

        // ── Live status row ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Label { text: "Remote:"; font.pixelSize: 13; color: "#888" }
            Label {
                text: (container.remoteThrottle >= 0 ? "+" : "") +
                      (container.remoteThrottle * 100).toFixed(1) + "%"
                font.pixelSize: 13
                color: container.remoteNeutral ? "#69F0AE" : "#FF7043"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item { width: 16 }

            Label { text: "Virtual:"; font.pixelSize: 13; color: "#888" }
            Label {
                text: (container.virtEffective > 0 ? "+" : "") + (container.virtEffective * 100).toFixed(1) + "%"
                font.pixelSize: 13
                color: {
                    if (!container.virtActive || container.virtEffective === 0) return "#555"
                    return container.virtEffective > 0 ? "#69F0AE" : "#FF5252"
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // ── Main content area ─────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Throttle slider (visible when enabled) ────────────────
            Item {
                anchors.fill: parent
                visible: container.virtEnabled

                // Cap labels flank the track vertically
                Label {
                    id: topLabel
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Throttle max " + Math.round(container.virtMax * 100) + "%"
                    font.pixelSize: 11; color: "#555"
                }

                Rectangle {
                    id: sliderTrack
                    width: 110
                    anchors.top: topLabel.bottom
                    anchors.topMargin: 4
                    anchors.bottom: bottomLabel.top
                    anchors.bottomMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 18
                    color: "#202020"
                    border.color: "#363636"; border.width: 1

                    // Fill extends from center toward top (throttle) or bottom (brake)
                    Rectangle {
                        x: 6; width: sliderTrack.width - 12; radius: 8
                        y: container.virtThrottle >= 0
                            ? sliderTrack.height / 2 - (sliderTrack.height - 12) / 2 * container.virtThrottle
                            : sliderTrack.height / 2
                        height: Math.abs(container.virtThrottle) * (sliderTrack.height - 12) / 2
                        color: container.virtThrottle >= 0
                            ? (container.virtActive ? "#00C853" : "#FF9800")
                            : "#F44336"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Center neutral line
                    Rectangle {
                        height: 2; x: 4; width: sliderTrack.width - 8
                        y: sliderTrack.height / 2 - 1
                        color: "#484848"
                    }

                    // Upper deadband marker
                    Rectangle {
                        height: 1; x: 4; width: sliderTrack.width - 8
                        y: sliderTrack.height / 2 - (sliderTrack.height - 12) / 2 * container.virtDeadband
                        color: "#555"
                        Label {
                            anchors.left: parent.right; anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+" + Math.round(container.virtDeadband * 100) + "%"
                            font.pixelSize: 10; color: "#555"
                        }
                    }

                    // Lower deadband marker
                    Rectangle {
                        height: 1; x: 4; width: sliderTrack.width - 8
                        y: sliderTrack.height / 2 + (sliderTrack.height - 12) / 2 * container.virtDeadband
                        color: "#555"
                        Label {
                            anchors.left: parent.right; anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: "-" + Math.round(container.virtDeadband * 100) + "%"
                            font.pixelSize: 10; color: "#555"
                        }
                    }

                    // Draggable thumb — rests at center when released
                    Rectangle {
                        id: sliderThumb
                        width: sliderTrack.width - 10
                        height: 56; radius: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#404040"
                        border.color: {
                            if (!container.virtActive || container.virtEffective === 0) return "#FF9800"
                            return container.virtEffective > 0 ? "#00C853" : "#F44336"
                        }
                        border.width: 2
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        y: {
                            const avail = sliderTrack.height - 12 - height
                            return 6 + avail * (1.0 - container.virtThrottle) / 2.0
                        }

                        Label {
                            anchors.centerIn: parent
                            text: container.virtEffective === 0
                                  ? "DEAD"
                                  : (container.virtEffective > 0 ? "+" : "-") +
                                    Math.abs(container.virtEffective * 100).toFixed(0) + "%"
                            font.pixelSize: 18; font.bold: true
                            color: container.virtEffective === 0 ? "#888"
                                   : container.virtEffective > 0 ? "white" : "#FF8A80"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }

                    // Center = neutral, up = throttle, down = brake, release = snap to center
                    MouseArea {
                        anchors.fill: parent
                        onPositionChanged: {
                            const fraction = 1.0 - (mouseY / height)  // 0=bottom, 1=top
                            const raw = fraction * 2.0 - 1.0           // -1=bottom, +1=top
                            container.virtThrottle = Math.max(-1.0, Math.min(1.0, raw))
                        }
                        onReleased:  { container.virtThrottle = 0.0 }
                        onCanceled:  { container.virtThrottle = 0.0 }
                    }
                }

                Label {
                    id: bottomLabel
                    anchors.bottom: hintLabel.top
                    anchors.bottomMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Brake max " + Math.round(container.virtBrakeMax * 100) + "%"
                    font.pixelSize: 11; color: "#555"
                }

                Label {
                    id: hintLabel
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Up = throttle · Down = brake · Release = neutral"
                    font.pixelSize: 11; color: "#555"
                }
            }

            // ── Idle state (virtual throttle off) ─────────────────────
            Column {
                anchors.centerIn: parent
                visible: !container.virtEnabled
                spacing: 10

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Emergency Remote"
                    font.pixelSize: 20; font.bold: true; color: "#404040"
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Enable virtual throttle above\nif real remote has failed"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 14; color: "#505050"
                }
            }
        }
    }
}

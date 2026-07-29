import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1080
    height: 720
    minimumWidth: 840
    minimumHeight: 620
    visible: false
    title: "Fedora Glow Kit"
    color: "#0B1020"

    property color ink: "#0B1020"
    property color surface: "#141B2D"
    property color surfaceHigh: "#1D2940"
    property color fedoraBlue: "#51A2DA"
    property color plasmaViolet: "#9B7BFF"
    property color readyGreen: "#5ED6A0"
    property color warningAmber: "#FFCC66"
    property color textMain: "#F4F7FC"
    property color textMuted: "#9EABC2"

    onClosing: function(close) {
        if (backend.trayActive) {
            close.accepted = false
            root.hide()
        }
    }

    function refresh() {
        var saved = backend.settings()
        profile.currentIndex = profile.find(saved.profile)
        desktop.currentIndex = desktop.find(saved.desktop)
        trayAutostart.checked = saved.tray_autostart
        statusText.text = backend.status()
        planText.text = backend.plan(profile.currentText, desktop.currentText)
    }

    component GlowButton: Button {
        id: control
        leftPadding: 20
        rightPadding: 20
        font.pixelSize: 14
        font.weight: Font.DemiBold
        palette.buttonText: root.textMain
        background: Rectangle {
            radius: 10
            color: control.down ? "#355E88" : control.hovered ? "#286A99" : "#245A82"
            border.color: control.activeFocus ? root.readyGreen : root.fedoraBlue
            border.width: control.activeFocus ? 2 : 1
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.ink

        Rectangle {
            width: 360
            height: 360
            radius: 180
            x: parent.width - 190
            y: -180
            color: "#189B7BFF"
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                color: "#10172A"
                border.color: "#24304A"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 18

                    RowLayout {
                        spacing: 12
                        Rectangle {
                            width: 42
                            height: 42
                            radius: 12
                            color: root.fedoraBlue
                            Text {
                                anchors.centerIn: parent
                                text: "∞"
                                color: "white"
                                font.pixelSize: 25
                                font.bold: true
                            }
                        }
                        Column {
                            Text {
                                text: "FEDORA"
                                color: root.textMuted
                                font.pixelSize: 10
                                font.letterSpacing: 2
                            }
                            Text {
                                text: "Glow Kit"
                                color: root.textMain
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#2B3853"
                    }

                    Text {
                        text: "CONTROL DECK"
                        color: root.plasmaViolet
                        font.pixelSize: 11
                        font.letterSpacing: 1.8
                    }

                    Repeater {
                        model: [
                            ["01", "Preview", root.fedoraBlue],
                            ["02", "Confirm", root.plasmaViolet],
                            ["03", "Apply", root.readyGreen],
                            ["04", "Recover", root.warningAmber]
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            spacing: 12
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: "#10172A"
                                border.color: modelData[2]
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData[0]
                                    color: modelData[2]
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: modelData[1]
                                color: root.textMain
                                font.pixelSize: 15
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        text: "Local-only by design\nNo telemetry · No device IDs"
                        color: root.textMuted
                        font.pixelSize: 12
                        lineHeight: 1.45
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    x: 42
                    y: 36
                    width: Math.max(476, root.width - 334)
                    spacing: 22

                    Text {
                        text: "Make Fedora yours—\nwith a way back."
                        color: root.textMain
                        font.pixelSize: 38
                        font.weight: Font.Bold
                        lineHeight: 0.95
                    }

                    Text {
                        text: "Choose a curated setup, review every section, then continue in a visible terminal."
                        color: root.textMuted
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: statusColumn.implicitHeight + 28
                        radius: 14
                        color: root.surface
                        border.color: "#2A3855"
                        ColumnLayout {
                            id: statusColumn
                            anchors.fill: parent
                            anchors.margins: 14
                            RowLayout {
                                Rectangle {
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: root.readyGreen
                                }
                                Text {
                                    text: "SYSTEM STATUS"
                                    color: root.readyGreen
                                    font.pixelSize: 11
                                    font.letterSpacing: 1.4
                                }
                            }
                            Text {
                                id: statusText
                                Layout.fillWidth: true
                                color: root.textMain
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width < 960 ? 1 : 2
                        columnSpacing: 16
                        rowSpacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: "Setup profile"; color: root.textMuted; font.pixelSize: 12 }
                            ComboBox {
                                id: profile
                                Layout.fillWidth: true
                                Accessible.name: "Setup profile"
                                model: ["daily", "minimal", "dev", "media", "gaming", "privacy", "ai", "full-send", "kde-polish", "gnome-polish"]
                                onCurrentTextChanged: planText.text = backend.plan(currentText, desktop.currentText)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: "Desktop target"; color: root.textMuted; font.pixelSize: 12 }
                            ComboBox {
                                id: desktop
                                Layout.fillWidth: true
                                Accessible.name: "Desktop target"
                                model: ["auto", "kde", "gnome"]
                                onCurrentTextChanged: planText.text = backend.plan(profile.currentText, currentText)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 170
                        radius: 14
                        color: root.surfaceHigh
                        border.color: "#34435F"
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            Text {
                                text: "CHANGE PREVIEW"
                                color: root.fedoraBlue
                                font.pixelSize: 11
                                font.letterSpacing: 1.4
                            }
                            TextArea {
                                id: planText
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                readOnly: true
                                color: root.textMain
                                font.family: "monospace"
                                font.pixelSize: 13
                                wrapMode: TextEdit.Wrap
                                background: null
                                Accessible.name: "Change preview"
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        GlowButton {
                            text: "Open confirmed setup"
                            onClicked: backend.launchApply(profile.currentText, desktop.currentText)
                        }
                        Button {
                            text: "Check updates"
                            onClicked: backend.launchUpdate()
                        }
                        Button {
                            text: "Recovery"
                            onClicked: backend.launchRevert()
                        }
                    }

                    CheckBox {
                        id: trayAutostart
                        text: "Start the optional tray helper when I sign in"
                        palette.windowText: root.textMain
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Settings stay on this computer."
                            color: root.textMuted
                            font.pixelSize: 12
                        }
                        Button {
                            text: "Save settings"
                            onClicked: {
                                backend.save(profile.currentText, desktop.currentText, trayAutostart.checked)
                                statusText.text = backend.status()
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: refresh()
}

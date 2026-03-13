import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    visible: false
    anchors.fill: parent
    z: 2000

    property bool closing: false

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: {
            visible = false
            closing = false
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        opacity: (!closing && visible) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Image {
            anchors.fill: parent
            source: "../assets/gradient.png"
            fillMode: Image.Stretch
            mipmap: true
            opacity: 0.6
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
    }

    Rectangle {
        id: dialog
        width: Math.min(500, parent.width - 40)
        height: contentCol.height + 60
        anchors.centerIn: parent
        color: "#252525"
        radius: 20
        border.color: "#3c3d3f"
        border.width: 1
        scale: (!closing && visible) ? 1.0 : 0.9
        opacity: (!closing && visible) ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Column {
            id: contentCol
            width: parent.width - 60
            anchors.centerIn: parent
            spacing: 25

            Item { height: 10; width: 1 }

            Image {
                source: "../assets/Knock-Knock.png"
                width: 160
                height: 160
                fillMode: Image.PreserveAspectFit
                mipmap: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: qsTranslate("Application", "Need Help?")
                color: "#d8fa00"
                font.family: "Alatsi"
                font.pixelSize: 24
                font.bold: false
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                text: qsTranslate("Application", "Join our Discord server for support, mod sharing, and updates!")
                color: "#ffffff"
                font.family: "Alatsi"
                font.pixelSize: 16
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }

            RowLayout {
                spacing: 20
                Layout.alignment: Qt.AlignHCenter
                width: parent.width

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 120
                    height: 45
                    color: Theme.disabledAccent
                    radius: Theme.radiusMedium
                    scale: closeMouse.pressed ? 0.97 : (closeMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Application", "Close")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closing = true
                            hideTimer.start()
                        }
                    }
                }

                Rectangle {
                    width: 160
                    height: 45
                    color: Theme.primaryAccent
                    radius: Theme.radiusMedium
                    scale: joinMouse.pressed ? 0.97 : (joinMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Application", "Join Discord")
                        color: Theme.textOnAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: joinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("https://discord.gg/PLACEHOLDER")
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Item { height: 5; width: 1 }
        }
    }
}

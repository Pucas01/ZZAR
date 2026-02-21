import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    visible: false
    anchors.fill: parent
    z: 2000

    property string title: "Title"
    property string message: "Message"
    property string confirmText: "OK"
    property string cancelText: "Cancel"
    property bool isConfirmation: false
    property string actionId: ""
    property bool closing: false
    property string customStickerPath: ""

    signal confirmed(string action)
    signal cancelled()

    property int randomSticker: Math.floor(Math.random() * 3)

    onVisibleChanged: {
        if (visible && customStickerPath === "") {
            randomSticker = Math.floor(Math.random() * 3)
        } else if (!visible) {
            customStickerPath = ""
        }
    }

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
            onClicked: {

            }
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
                source: root.customStickerPath !== "" ? root.customStickerPath :
                        root.randomSticker === 0 ? "../assets/SunnaMad.png" :
                        root.randomSticker === 1 ? "../assets/AntonWHAT.png" :
                        "../assets/SeedSuprise.png"
                width: 160
                height: 160
                fillMode: Image.PreserveAspectFit
                mipmap: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.title
                color: "#d8fa00"
                font.family: "Alatsi"
                font.pixelSize: 24
                font.bold: false
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                text: root.message
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
                    id: cancelBtn
                    width: 120
                    height: 45
                    color: Theme.disabledAccent
                    radius: Theme.radiusMedium
                    visible: root.isConfirmation
                    scale: cancelMouse.pressed ? 0.97 : (cancelMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: root.cancelText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closing = true
                            hideTimer.start()
                            root.cancelled()
                        }
                    }
                }

                Rectangle {
                    width: 120
                    height: 45
                    color: Theme.primaryAccent
                    radius: Theme.radiusMedium
                    scale: confirmMouse.pressed ? 0.97 : (confirmMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: root.confirmText
                        color: Theme.textOnAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closing = true
                            hideTimer.start()
                            root.confirmed(root.actionId)
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
            
            Item { height: 5; width: 1 }
        }
    }
}

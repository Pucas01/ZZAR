import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    visible: false
    anchors.fill: parent
    z: 2000

    property string version: ""
    property string changelog: ""
    property bool closing: false
    property bool isDownloading: false
    property int downloadPercent: 0

    signal updateAccepted()
    signal updateDismissed()

    property int randomSticker: Math.floor(Math.random() * 3)

    onVisibleChanged: {
        if (visible) {
            randomSticker = Math.floor(Math.random() * 3)
            isDownloading = false
            downloadPercent = 0
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
            source: "../assets/" + assetsDir + "/gradient.png"
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
        width: Math.min(550, parent.width - 40)
        height: Math.min(contentCol.height + 60, parent.height - 80)
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
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 30
            spacing: 20

            Image {
                source: "../assets/" + assetsDir + "/VivianScribble.png"
                width: 120
                height: 120
                fillMode: Image.PreserveAspectFit
                mipmap: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: qsTranslate("Application", "Update Available!")
                color: Theme.primaryAccent
                font.family: "Alatsi"
                font.pixelSize: 24
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: qsTranslate("Application", "Version %1 is ready to download.").arg(root.version)
                color: "#ffffff"
                font.family: "Alatsi"
                font.pixelSize: 16
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.changelog.length > 0

                Text {
                    text: qsTranslate("Application", "What's New")
                    color: Theme.primaryAccent
                    font.family: "Alatsi"
                    font.pixelSize: 16
                }

                Rectangle {
                    width: parent.width
                    height: Math.min(changelogText.contentHeight + 20, 200)
                    color: "#1a1a1a"
                    radius: 10
                    border.color: "#3c3d3f"
                    border.width: 1

                    Flickable {
                        id: changelogFlickable
                        anchors.fill: parent
                        anchors.margins: 10
                        contentHeight: changelogText.contentHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: changelogFlickable.contentHeight > changelogFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: "#555555"
                            }
                        }

                        Text {
                            id: changelogText
                            width: changelogFlickable.width - 10
                            text: root.changelog
                            color: "#cccccc"
                            font.family: "Alatsi"
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            lineHeight: 1.4
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.isDownloading

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#1a1a1a"

                    Rectangle {
                        width: parent.width * (root.downloadPercent / 100)
                        height: parent.height
                        radius: 3
                        color: Theme.primaryAccent
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }

                Text {
                    text: qsTranslate("Application", "Downloading... %1%").arg(root.downloadPercent)
                    color: "#888888"
                    font.family: "Alatsi"
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            RowLayout {
                spacing: 20
                width: parent.width

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 120
                    height: 45
                    color: Theme.disabledAccent
                    radius: Theme.radiusMedium
                    visible: !root.isDownloading
                    scale: laterMouse.pressed ? 0.97 : (laterMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Application", "Later")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: laterMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closing = true
                            hideTimer.start()
                            root.updateDismissed()
                        }
                    }
                }

                Rectangle {
                    width: 140
                    height: 45
                    color: root.isDownloading ? "#3c3d3f" : (updateMouse.pressed ? Theme.accentDark : updateMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent)
                    radius: Theme.radiusMedium
                    opacity: root.isDownloading ? 0.7 : 1.0
                    scale: (!root.isDownloading && updateMouse.pressed) ? 0.97 : ((!root.isDownloading && updateMouse.containsMouse) ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Item {
                            width: 18
                            height: 18
                            visible: root.isDownloading

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.isDownloading
                            }

                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.beginPath();
                                    ctx.arc(9, 9, 7, 0, Math.PI * 1.5);
                                    ctx.strokeStyle = "#000000";
                                    ctx.lineWidth = 2;
                                    ctx.stroke();
                                }
                            }
                        }

                        Text {
                            text: root.isDownloading ? qsTranslate("Application", "Updating...") : qsTranslate("Application", "Update Now")
                            color: Theme.textOnAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                        }
                    }

                    MouseArea {
                        id: updateMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isDownloading
                        cursorShape: root.isDownloading ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!root.isDownloading) {
                                root.isDownloading = true
                                root.updateAccepted()
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Item { height: 5; width: 1 }
        }
    }

    function show(ver, notes) {
        version = ver
        changelog = notes
        visible = true
    }

    function hide() {
        closing = true
        hideTimer.start()
    }
}

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    visible: false
    anchors.fill: parent
    z: 2000
    objectName: "audioMatchDialog"

    property bool closing: false
    property bool isMatching: false
    property int matchProgress: 0
    property int matchCurrent: 0
    property int matchTotal: 0
    property string selectedFilePath: ""
    property string selectedFileName: ""
    property string matchStatus: ""

    signal fileSelectionRequested()
    signal matchStartRequested(string filePath)
    signal matchCancelled()

    onVisibleChanged: {
        if (visible) {
            isMatching = false
            matchProgress = 0
            matchCurrent = 0
            matchTotal = 0
            matchStatus = ""
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

            Text {
                text: qsTranslate("Application", "Find Matching Sound")
                color: "#d8fa00"
                font.family: "Alatsi"
                font.pixelSize: 24
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                width: parent.width
                spacing: 12

                Text {
                    text: qsTranslate("Application", "Select Recording")
                    color: "#ffffff"
                    font.family: "Alatsi"
                    font.pixelSize: 14
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    color: "#1a1a1a"
                    radius: 10
                    border.color: "#3c3d3f"
                    border.width: 1

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: browseBtn.left
                        anchors.rightMargin: 10
                        text: root.selectedFileName || qsTranslate("Application", "No file selected")
                        color: root.selectedFileName ? "#ffffff" : "#888888"
                        font.family: "Alatsi"
                        font.pixelSize: 13
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        id: browseBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 90
                        height: 34
                        color: browseMouse.pressed ? "#a8c800" : (browseMouse.containsMouse ? "#e8ff33" : "#d8fa00")
                        radius: 8
                        scale: browseMouse.pressed ? 0.97 : (browseMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Application", "Browse...")
                            color: "#000000"
                            font.family: "Alatsi"
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: browseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fileSelectionRequested()
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 12
                visible: root.isMatching

                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: "#1a1a1a"

                    Rectangle {
                        width: parent.width * (root.matchProgress / 100)
                        height: parent.height
                        radius: 4
                        color: "#d8fa00"
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }

                Text {
                    text: root.matchProgress + "%"
                    color: "#d8fa00"
                    font.family: "Alatsi"
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.matchStatus || (qsTranslate("Application", "Matching... %1/%2 sounds").arg(root.matchCurrent).arg(root.matchTotal))
                    color: "#888888"
                    font.family: "Alatsi"
                    font.pixelSize: 13
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
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
                    scale: cancelMouse.pressed ? 0.97 : (cancelMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Application", "Cancel")
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
                            if (root.isMatching) {
                                root.matchCancelled()
                            }
                            root.closing = true
                            hideTimer.start()
                        }
                    }
                }

                Rectangle {
                    width: 140
                    height: 45
                    color: (!root.selectedFilePath || root.isMatching) ? "#3c3d3f" : (startMouse.pressed ? "#a8c800" : startMouse.containsMouse ? "#e8ff33" : "#d8fa00")
                    radius: Theme.radiusMedium
                    opacity: (!root.selectedFilePath || root.isMatching) ? 0.5 : 1.0
                    scale: (root.selectedFilePath && !root.isMatching && startMouse.pressed) ? 0.97 : ((root.selectedFilePath && !root.isMatching && startMouse.containsMouse) ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Item {
                            width: 18
                            height: 18
                            visible: root.isMatching

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.isMatching
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
                            text: root.isMatching ? qsTranslate("Application", "Matching...") : qsTranslate("Application", "Start Matching")
                            color: (!root.selectedFilePath || root.isMatching) ? "#666666" : "#000000"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                        }
                    }

                    MouseArea {
                        id: startMouse
                        anchors.fill: parent
                        enabled: root.selectedFilePath && !root.isMatching
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.isMatching = true
                            root.matchStartRequested(root.selectedFilePath)
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Item { height: 5; width: 1 }
        }
    }

    function show() {
        visible = true
    }

    function hide() {
        closing = true
        hideTimer.start()
    }

    function setSelectedFile(filePath) {
        selectedFilePath = filePath
        var parts = filePath.split("/")
        selectedFileName = parts[parts.length - 1]
    }

    function setProgress(current, total) {
        matchCurrent = current
        matchTotal = total
        if (total > 0) {
            matchProgress = Math.round(100 * current / total)
        }
    }

    function setStatus(message) {
        matchStatus = message
    }

    function setMatching(matching) {
        isMatching = matching
    }
}

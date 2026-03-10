import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15

Item {
    id: modInfoDialog
    objectName: "modInfoDialog"

    property string modUuid: ""
    property string modName: ""
    property string modAuthor: ""
    property string modVersion: ""
    property string modDescription: ""
    property string modThumbnailPath: ""
    property string modCreatedDate: ""
    property int modFileCount: 0
    property var modReplacements: ({})
    property string modGameBananaUrl: ""

    visible: false
    property bool closing: false

    signal exportRequested(string uuid)

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
        anchors.centerIn: parent
        width: 600
        height: 550
        color: "#252525"
        radius: 20
        scale: (!closing && visible) ? 1.0 : 0.9
        opacity: (!closing && visible) ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 5
            radius: 20
            color: "#40000000"
            z: -1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 25
            anchors.bottomMargin: 95
            spacing: 15

            Row {
                width: parent.width
                height: 100
                spacing: 20

                Rectangle {
                    id: thumbnailContainer
                    width: 100
                    height: 100
                    color: "#444444"
                    radius: 36.44

                    Image {
                        id: thumbnailImage
                        anchors.fill: parent
                        source: {
                            if (!modThumbnailPath) return "";
                            if (modThumbnailPath.startsWith("file:///")) return modThumbnailPath;
                            return "file:///" + modThumbnailPath.replace(/\\/g, "/");
                        }
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        visible: false
                        layer.enabled: true
                    }

                    Rectangle {
                        id: thumbnailMask
                        anchors.fill: parent
                        radius: 36.44
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: thumbnailImage
                        source: thumbnailImage
                        maskSource: thumbnailMask
                        visible: modThumbnailPath && modThumbnailPath.length > 0
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modName ? modName.charAt(0).toUpperCase() : "M"
                        color: "#888888"
                        font.family: "Alatsi"
                        font.pixelSize: 42
                        visible: !modThumbnailPath || modThumbnailPath.length === 0
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: modThumbnailPath && modThumbnailPath.length > 0
                        cursorShape: (modThumbnailPath && modThumbnailPath.length > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (modThumbnailPath && modThumbnailPath.length > 0) {
                                fullImagePopup.open()
                            }
                        }
                        
                        Rectangle {
                            anchors.fill: parent
                            radius: 36.44
                            color: "#ffffff"
                            opacity: parent.containsMouse && modThumbnailPath && modThumbnailPath.length > 0 ? 0.1 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                }

                Column {
                    width: parent.width - 120
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        text: modName
                        color: "#CDEE00"
                        font.family: "Audiowide"
                        font.pixelSize: 24
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: qsTranslate("Application", "By %1").arg(modAuthor)
                        color: "#aaaaaa"
                        font.family: "Alatsi"
                        font.pixelSize: 16
                    }

                    Text {
                        text: qsTranslate("Application", "Version %1").arg(modVersion)
                        color: "#888888"
                        font.family: "Alatsi"
                        font.pixelSize: 14
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#3c3d3f"
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: qsTranslate("Application", "Description")
                    color: "#ffffff"
                    font.family: "Alatsi"
                    font.pixelSize: 16
                    font.bold: false
                }

                Rectangle {
                    width: parent.width
                    height: 80
                    radius: 10
                    color: "#1a1a1a"

                    ScrollView {
                        id: descScrollView
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        Text {
                            text: modDescription || qsTranslate("Application", "No description provided.")
                            color: modDescription ? "#cccccc" : "#666666"
                            font.family: "Alatsi"
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            width: descScrollView.availableWidth
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: qsTranslate("Application", "Details")
                    color: "#ffffff"
                    font.family: "Alatsi"
                    font.pixelSize: 16
                    font.bold: false
                }

                Rectangle {
                    width: parent.width
                    height: modGameBananaUrl ? 152 : 120
                    radius: 10
                    color: "#1a1a1a"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 8

                        Row {
                            spacing: 10
                            Text {
                                text: qsTranslate("Application", "UUID:")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                width: 100
                            }
                            Text {
                                text: modUuid
                                color: "#cccccc"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                                width: 350
                            }
                        }

                        Row {
                            spacing: 10
                            Text {
                                text: qsTranslate("Application", "Created:")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                width: 100
                            }
                            Text {
                                text: modCreatedDate || qsTranslate("Application", "Unknown")
                                color: "#cccccc"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                            }
                        }

                        Row {
                            spacing: 10
                            Text {
                                text: qsTranslate("Application", "Audio Files:")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                width: 100
                            }
                            Text {
                                text: modFileCount + " " + qsTranslate("Application", "replacement(s)")
                                color: "#cccccc"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                            }
                        }

                        Row {
                            spacing: 10
                            Text {
                                text: qsTranslate("Application", "Target PCKs:")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                width: 100
                            }
                            Text {
                                text: Object.keys(modReplacements).length + " " + qsTranslate("Application", "PCK file(s)")
                                color: "#cccccc"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                            }
                        }

                        Row {
                            visible: modGameBananaUrl !== ""
                            spacing: 10
                            Text {
                                text: "GameBanana:"
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                width: 100
                            }
                            Text {
                                text: qsTranslate("Application", "Open mod page")
                                color: gbLinkMouse.containsMouse ? "#e8ff33" : Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                font.underline: true
                                Behavior on color { ColorAnimation { duration: 120 } }

                                MouseArea {
                                    id: gbLinkMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally(modGameBananaUrl)
                                }
                            }
                        }
                    }
                }
            }

        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 25
            anchors.bottomMargin: 25
            spacing: 10

            Rectangle {
                width: 150
                height: 45
                radius: Theme.radiusMedium
                color: Theme.disabledAccent
                scale: exportBtnMouse.pressed ? 0.97 : (exportBtnMouse.containsMouse ? 1.03 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Application", "Export to .zzar")
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                }

                MouseArea {
                    id: exportBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: exportRequested(modUuid)
                }
            }

            Rectangle {
                width: 120
                height: 45
                radius: Theme.radiusMedium
                color: Theme.primaryAccent
                scale: closeBtnMouse.pressed ? 0.97 : (closeBtnMouse.containsMouse ? 1.03 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Application", "Close")
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                }

                MouseArea {
                    id: closeBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hide()
                }
            }
        }
    }

    Popup {
        id: fullImagePopup
        width: 512
        height: 512
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
                NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 200; easing.type: Easing.OutBack }
            }
        }
        
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 200 }
                NumberAnimation { property: "scale"; from: 1.0; to: 0.9; duration: 200 }
            }
        }

        background: Rectangle {
            color: "#1a1a1a"
            radius: Theme.radiusLarge || 15
            border.color: "#3c3d3f"
            border.width: 1
        }
        
        Image {
            anchors.fill: parent
            anchors.margins: 10
            source: thumbnailImage.source
            fillMode: Image.PreserveAspectFit
            mipmap: true
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: fullImagePopup.close()
            }
        }
    }

    function show() {
        visible = true
    }

    function hide() {
        closing = true
        hideTimer.start()
    }

    function setModInfo(info) {
        modUuid = info.uuid || ""
        modName = info.name || "Unknown"
        modAuthor = info.author || "Unknown"
        modVersion = info.version || "1.0.0"
        modDescription = info.description || ""
        modThumbnailPath = info.thumbnailPath || ""
        modCreatedDate = info.createdDate || ""
        modFileCount = info.fileCount || 0
        modReplacements = info.replacements || {}
        modGameBananaUrl = info.gamebananaUrl || ""
    }
}

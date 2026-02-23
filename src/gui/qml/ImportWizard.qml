import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: importWizard
    objectName: "importWizard"

    signal browseFilesClicked(string mode)
    signal browseFolderClicked(string mode)
    signal browseThumbnailClicked()
    signal createModClicked(var wizardData)
    signal wizardCancelled()

    property int currentPage: 1
    property string importMode: "pck_file"
    property var selectedFiles: []
    property string selectedFolder: ""
    property string thumbnailPath: ""

    property string modName: ""
    property string modAuthor: ""
    property string modVersion: "1.0.0"
    property string modDescription: ""

    property string detectedFilesSummary: ""
    property int detectedFilesCount: 0

    property bool isImporting: false
    property int importPercent: 0
    property string importStatus: ""

    visible: false
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
        scale: (!closing && visible) ? 1.0 : 0.9
        opacity: (!closing && visible) ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        id: wizardDialog
        anchors.centerIn: parent
        width: 700
        height: 650
        color: "#252525"
        radius: 20

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
            spacing: 15

            Text {
                text: qsTr("Import Existing Mod")
                color: "#CDEE00"
                font.family: "Stretch Pro"
                font.pixelSize: 28
                font.letterSpacing: 2
                font.bold: false
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferNoHinting
            }

            Text {
                text: qsTr("Convert PCK or WEM files to .zzar mod package")
                color: "#888888"
                font.family: "Alatsi"
                font.pixelSize: 14
            }

            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: 4
                    Rectangle {
                        width: 120
                        height: 6
                        radius: 3
                        color: index < currentPage ? "#CDEE00" : "#3c3d3f"

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#3c3d3f"
            }

            Item {
                width: parent.width
                height: parent.height - 180

                Column {
                    anchors.fill: parent
                    spacing: 15
                    visible: currentPage === 1 && !isImporting

                    Text {
                        text: qsTr("Step 1: Select Import Mode")
                        color: "#ffffff"
                        font.family: "Alatsi"
                        font.pixelSize: 18
                        font.bold: false
                    }

                    Text {
                        text: qsTr("What type of mod files do you have?")
                        color: "#aaaaaa"
                        font.family: "Alatsi"
                        font.pixelSize: 14
                    }

                    Column {
                        spacing: 12
                        width: parent.width

                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: 10
                            color: importMode === "pck_file" ? "#3c3d3f" : "#2a2a2a"
                            border.color: importMode === "pck_file" ? "#CDEE00" : "transparent"
                            border.width: 2

                            Row {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 15

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: importMode === "pck_file" ? "#CDEE00" : "#555555"
                                    border.color: "#CDEE00"
                                    border.width: 2

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: "#252525"
                                        visible: importMode === "pck_file"
                                    }
                                }

                                Text {
                                    text: qsTr("Single PCK file (modded game archive)")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: importMode = "pck_file"
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: 10
                            color: importMode === "pck_folder" ? "#3c3d3f" : "#2a2a2a"
                            border.color: importMode === "pck_folder" ? "#CDEE00" : "transparent"
                            border.width: 2

                            Row {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 15

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: importMode === "pck_folder" ? "#CDEE00" : "#555555"
                                    border.color: "#CDEE00"
                                    border.width: 2

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: "#252525"
                                        visible: importMode === "pck_folder"
                                    }
                                }

                                Text {
                                    text: qsTr("Folder containing PCK files")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: importMode = "pck_folder"
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: 10
                            color: importMode === "wem_file" ? "#3c3d3f" : "#2a2a2a"
                            border.color: importMode === "wem_file" ? "#CDEE00" : "transparent"
                            border.width: 2

                            Row {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 15

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: importMode === "wem_file" ? "#CDEE00" : "#555555"
                                    border.color: "#CDEE00"
                                    border.width: 2

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: "#252525"
                                        visible: importMode === "wem_file"
                                    }
                                }

                                Text {
                                    text: qsTr("Single WEM file (audio replacement)")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: importMode = "wem_file"
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: 10
                            color: importMode === "wem_folder" ? "#3c3d3f" : "#2a2a2a"
                            border.color: importMode === "wem_folder" ? "#CDEE00" : "transparent"
                            border.width: 2

                            Row {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 15

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: importMode === "wem_folder" ? "#CDEE00" : "#555555"
                                    border.color: "#CDEE00"
                                    border.width: 2

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: "#252525"
                                        visible: importMode === "wem_folder"
                                    }
                                }

                                Text {
                                    text: qsTr("Folder containing WEM files")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: importMode = "wem_folder"
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: pckWarningCol.implicitHeight + 20
                            radius: 10
                            color: "#2a1a1a"
                            border.color: "#ff6b6b"
                            border.width: 1
                            visible: importMode === "pck_file" || importMode === "pck_folder"

                            Column {
                                id: pckWarningCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Text {
                                    text: qsTr("Warning")
                                    color: "#ff6b6b"
                                    font.family: "Alatsi"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Text {
                                    text: qsTr("PCK files must match the current game version. Using PCK files from a different game version will cause issues, if you dont know what your doing use the WEM file option.")
                                    color: "#cc8888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 12
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.2
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: 15
                    visible: currentPage === 2 && !isImporting

                    Text {
                        text: qsTr("Step 2: Select Files")
                        color: "#ffffff"
                        font.family: "Alatsi"
                        font.pixelSize: 18
                        font.bold: false
                    }

                    Row {
                        width: parent.width
                        spacing: 10

                        Text {
                            text: importMode.indexOf("folder") >= 0 ? qsTr("Folder:") : qsTr("File(s):")
                            color: "#aaaaaa"
                            font.family: "Alatsi"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                        }

                        Rectangle {
                            width: parent.width - 170
                            height: 40
                            radius: 8
                            color: "#1a1a1a"
                            border.color: "#3c3d3f"
                            border.width: 1

                            Text {
                                anchors.fill: parent
                                anchors.margins: 10
                                text: importMode.indexOf("folder") >= 0 ?
                                      (selectedFolder || qsTr("No folder selected")) :
                                      (selectedFiles.length > 0 ? qsTr("%1 file(s) selected").arg(selectedFiles.length) : qsTr("No files selected"))
                                color: selectedFiles.length > 0 || selectedFolder ? "#ffffff" : "#666666"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                elide: Text.ElideMiddle
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Rectangle {
                            width: 90
                            height: 40
                            radius: Theme.radiusMedium
                            color: Theme.primaryAccent
                            scale: browseBtn.pressed ? 0.97 : (browseBtn.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Browse")
                                color: Theme.textOnAccent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            MouseArea {
                                id: browseBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (importMode.indexOf("folder") >= 0) {
                                        browseFolderClicked(importMode)
                                    } else {
                                        browseFilesClicked(importMode)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: qsTr("Selected files:")
                        color: "#aaaaaa"
                        font.family: "Alatsi"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        width: parent.width
                        height: 200
                        radius: 10
                        color: "#1a1a1a"
                        border.color: "#3c3d3f"
                        border.width: 1

                        ListView {
                            id: fileListView
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            model: selectedFiles

                            delegate: Text {
                                text: modelData
                                color: "#cccccc"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                                width: fileListView.width
                            }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("No files selected")
                                color: "#555555"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                visible: selectedFiles.length === 0
                            }
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: 15
                    visible: currentPage === 3 && !isImporting

                    Text {
                        text: qsTr("Step 3: Review Detected Files")
                        color: "#ffffff"
                        font.family: "Alatsi"
                        font.pixelSize: 18
                        font.bold: false
                    }

                    Text {
                        text: qsTr("The following files will be included in the mod:")
                        color: "#aaaaaa"
                        font.family: "Alatsi"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        width: parent.width
                        height: 280
                        radius: 10
                        color: "#1a1a1a"
                        border.color: "#3c3d3f"
                        border.width: 1

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 15
                            clip: true

                            TextArea {
                                id: detectedFilesText
                                text: detectedFilesSummary
                                color: "#cccccc"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                readOnly: true
                                wrapMode: Text.Wrap
                                background: Rectangle { color: "transparent" }
                            }
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: 12
                    visible: currentPage === 4 && !isImporting

                    Text {
                        text: qsTr("Step 4: Mod Information")
                        color: "#ffffff"
                        font.family: "Alatsi"
                        font.pixelSize: 18
                        font.bold: false
                    }

                    Text {
                        text: qsTr("Enter information about this mod:")
                        color: "#aaaaaa"
                        font.family: "Alatsi"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        width: parent.width
                        height: 300
                        radius: 10
                        color: "#2a2a2a"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 15
                            spacing: 12

                            Row {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: qsTr("Name:*")
                                    color: "#aaaaaa"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: parent.width - 90
                                    height: 35
                                    radius: 6
                                    color: "#1a1a1a"
                                    border.color: "#3c3d3f"

                                    TextInput {
                                        id: nameInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: "#ffffff"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                        clip: true
                                        onTextChanged: modName = text

                                        Text {
                                            anchors.fill: parent
                                            text: qsTr("My Awesome Mod")
                                            color: "#555555"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                            visible: !nameInput.text && !nameInput.activeFocus
                                        }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: qsTr("Author:*")
                                    color: "#aaaaaa"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: parent.width - 90
                                    height: 35
                                    radius: 6
                                    color: "#1a1a1a"
                                    border.color: "#3c3d3f"

                                    TextInput {
                                        id: authorInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: "#ffffff"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                        clip: true
                                        onTextChanged: modAuthor = text

                                        Text {
                                            anchors.fill: parent
                                            text: qsTr("Your Name")
                                            color: "#555555"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                            visible: !authorInput.text && !authorInput.activeFocus
                                        }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: qsTr("Version:")
                                    color: "#aaaaaa"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: 100
                                    height: 35
                                    radius: 6
                                    color: "#1a1a1a"
                                    border.color: "#3c3d3f"

                                    TextInput {
                                        id: versionInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: "#ffffff"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                        text: "1.0.0"
                                        clip: true
                                        onTextChanged: modVersion = text
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 5

                                Text {
                                    text: qsTr("Description:")
                                    color: "#aaaaaa"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 60
                                    radius: 6
                                    color: "#1a1a1a"
                                    border.color: "#3c3d3f"

                                    TextInput {
                                        id: descInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: "#ffffff"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                        clip: true
                                        wrapMode: Text.Wrap
                                        onTextChanged: modDescription = text

                                        Text {
                                            anchors.fill: parent
                                            text: qsTr("Describe what this mod does...")
                                            color: "#555555"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                            visible: !descInput.text && !descInput.activeFocus
                                        }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: qsTr("Thumbnail:")
                                    color: "#aaaaaa"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: parent.width - 180
                                    height: 35
                                    radius: 6
                                    color: "#1a1a1a"
                                    border.color: "#3c3d3f"

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: thumbnailPath ? thumbnailPath.split("/").pop() : qsTr("Optional - Browse for image")
                                        color: thumbnailPath ? "#ffffff" : "#555555"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                        elide: Text.ElideMiddle
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                Rectangle {
                                    width: 80
                                    height: 35
                                    radius: Theme.radiusMedium
                                    color: Theme.primaryAccent
                                    scale: thumbBtn.pressed ? 0.97 : (thumbBtn.containsMouse ? 1.03 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Browse")
                                        color: Theme.textOnAccent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }

                                    MouseArea {
                                        id: thumbBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: browseThumbnailClicked()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: qsTr("* Required fields")
                        color: "#666666"
                        font.family: "Alatsi"
                        font.pixelSize: 12
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: 20
                    visible: isImporting

                    Item { width: 1; height: 40 }

                    Text {
                        text: qsTr("Importing Mod...")
                        color: "#ffffff"
                        font.family: "Alatsi"
                        font.pixelSize: 22
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Column {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: parent.width
                            height: 8
                            radius: 4
                            color: "#1a1a1a"

                            Rectangle {
                                width: parent.width * (importPercent / 100)
                                height: parent.height
                                radius: 4
                                color: "#CDEE00"
                                Behavior on width { NumberAnimation { duration: 200 } }
                            }
                        }

                        Text {
                            text: importPercent + "%"
                            color: "#CDEE00"
                            font.family: "Alatsi"
                            font.pixelSize: 16
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    Text {
                        text: importStatus
                        color: "#aaaaaa"
                        font.family: "Alatsi"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                    }

                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#3c3d3f"
                visible: !isImporting
            }

            Row {
                anchors.right: parent.right
                spacing: 10
                visible: !isImporting

                Rectangle {
                    width: 100
                    height: 40
                    radius: Theme.radiusMedium
                    color: Theme.surfaceColor
                    visible: currentPage > 1
                    scale: backBtnMouse.pressed ? 0.97 : (backBtnMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("< Back")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: backBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: goBack()
                    }
                }

                Rectangle {
                    width: 100
                    height: 40
                    radius: Theme.radiusMedium
                    color: Theme.primaryAccent
                    visible: currentPage < 4
                    scale: nextBtnMouse.pressed ? 0.97 : (nextBtnMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Next >")
                        color: Theme.textOnAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: nextBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: goNext()
                    }
                }

                Rectangle {
                    width: 130
                    height: 40
                    radius: Theme.radiusMedium
                    color: Theme.primaryAccent
                    visible: currentPage === 4
                    scale: createBtnMouse.pressed ? 0.97 : (createBtnMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Create Mod")
                        color: Theme.textOnAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: createBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: finishWizard()
                    }
                }

                Rectangle {
                    width: 100
                    height: 40
                    radius: Theme.radiusMedium
                    color: Theme.disabledAccent
                    scale: cancelBtnMouse.pressed ? 0.97 : (cancelBtnMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: cancelBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cancelWizard()
                    }
                }
            }
        }
    }

    function show() {
        visible = true
        resetWizard()
    }

    function hide() {
        closing = true
        hideTimer.start()
    }

    function resetWizard() {
        currentPage = 1
        importMode = "pck_file"
        selectedFiles = []
        selectedFolder = ""
        thumbnailPath = ""
        modName = ""
        modAuthor = ""
        modVersion = "1.0.0"
        modDescription = ""
        detectedFilesSummary = ""
        detectedFilesCount = 0
        isImporting = false
        importPercent = 0
        importStatus = ""

        if (nameInput) nameInput.text = ""
        if (authorInput) authorInput.text = ""
        if (versionInput) versionInput.text = "1.0.0"
        if (descInput) descInput.text = ""
    }

    function goBack() {
        if (currentPage > 1) {
            currentPage--
        }
    }

    function goNext() {
        if (currentPage === 2 && selectedFiles.length === 0) {

            return
        }

        if (currentPage === 2) {
            var summary = qsTr("Files to be included in the mod:") + "\n\n"
            for (var i = 0; i < selectedFiles.length; i++) {
                summary += "  - " + selectedFiles[i] + "\n"
            }
            summary += "\n" + qsTr("Total: %1 file(s)").arg(selectedFiles.length)
            detectedFilesSummary = summary
            detectedFilesCount = selectedFiles.length
        }

        if (currentPage < 4) {
            currentPage++
        }
    }

    function finishWizard() {

        if (!modName || modName.trim() === "") {
            return
        }
        if (!modAuthor || modAuthor.trim() === "") {
            return
        }

        var wizardData = {
            "importMode": importMode,
            "selectedFiles": selectedFiles,
            "selectedFolder": selectedFolder,
            "modName": modName.trim(),
            "modAuthor": modAuthor.trim(),
            "modVersion": modVersion.trim() || "1.0.0",
            "modDescription": modDescription.trim(),
            "thumbnailPath": thumbnailPath
        }

        createModClicked(wizardData)
    }

    function cancelWizard() {
        wizardCancelled()
        hide()
    }

    function setSelectedFiles(files) {
        selectedFiles = files
    }

    function setSelectedFolder(folder, files) {
        selectedFolder = folder
        selectedFiles = files
    }

    function setThumbnailPath(path) {
        thumbnailPath = path
    }

    function setDetectedFilesSummary(summary, count) {
        detectedFilesSummary = summary
        detectedFilesCount = count
    }

    function startImporting() {
        isImporting = true
        importPercent = 0
        importStatus = qsTr("Starting...")
    }

    function updateImportProgress(percent, status) {
        importPercent = percent
        importStatus = status
    }

    function finishImporting() {
        isImporting = false
        hide()
    }
}

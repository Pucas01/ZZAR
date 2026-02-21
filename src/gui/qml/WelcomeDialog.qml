import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    objectName: "welcomeDialog"
    visible: false
    anchors.fill: parent
    z: 1500

    property bool closing: false
    property string selectedMode: ""
    property int currentPage: 1
    property string gameDirectory: ""
    property bool wwiseInstalled: false
    property bool isInstallingWwise: false
    property bool audioToolsInstalled: false
    property bool isInstallingAudioTools: false
    property bool isAutoDetecting: false

    signal modeSelected(string mode)
    signal browseGameDirClicked()
    signal autoDetectClicked()
    signal checkWwiseClicked()
    signal runWwiseSetupClicked()
    signal checkAudioToolsClicked()
    signal runAudioToolsSetupClicked()
    signal startTutorialClicked()

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: {
            visible = false
            closing = false
            currentPage = 1
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
        width: 700
        height: 600
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
            anchors.fill: parent
            anchors.margins: 40
            spacing: 20

            Text {
                text: "Welcome to ZZAR!"
                color: "#CDEE00"
                font.family: "Stretch Pro"
                font.pixelSize: 36
                font.letterSpacing: 2
                font.bold: false
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: currentPage === 1 ? "Choose how you want to use ZZAR" :
                        currentPage === 2 ? "Let's set up your game directory" :
                        currentPage === 3 ? "Set up Wwise for mod creation" :
                        currentPage === 4 ? "Install audio conversion tools" :
                        "Everything looks good!"

                color: "#aaaaaa"
                font.family: "Alatsi"
                font.pixelSize: 16
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: (selectedMode === "maker" && Qt.platform.os === "windows") ? 5 : (selectedMode === "maker" ? 4 : 3)
                    Rectangle {
                        width: (selectedMode === "maker" && Qt.platform.os === "windows") ? 104 : (selectedMode === "maker" ? 130 : 180)
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

            StackLayout {
                width: parent.width
                height: parent.height - 220
                currentIndex: currentPage - 1

                Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 30

                        Rectangle {
                            width: 250
                            height: 280
                            color: installMouseArea.containsMouse ? "#2a2a2a" : "#1a1a1a"
                            radius: 15
                            border.color: installMouseArea.containsMouse ? Theme.primaryAccent : "#3c3d3f"
                            border.width: 2
                            scale: installMouseArea.pressed ? 0.97 : (installMouseArea.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                            Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 15

                                Image {
                                    source: "../assets/MiyabiMelon.png"
                                    width: 120
                                    height: 120
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "Mod Manager"
                                    color: "#ffffff"
                                    font.family: "Audiowide"
                                    font.pixelSize: 22
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "Download and install\n.zzar mod packages"
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 220
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MouseArea {
                                id: installMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selectedMode = "install"
                                    currentPage = 2
                                }
                            }
                        }

                        Rectangle {
                            width: 250
                            height: 280
                            color: makerMouseArea.containsMouse ? "#2a2a2a" : "#1a1a1a"
                            radius: 15
                            border.color: makerMouseArea.containsMouse ? Theme.primaryAccent : "#3c3d3f"
                            border.width: 2
                            scale: makerMouseArea.pressed ? 0.97 : (makerMouseArea.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                            Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 15

                                Image {
                                    source: "../assets/SunnaSmug.png"
                                    width: 120
                                    height: 120
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "Mod Creator"
                                    color: "#ffffff"
                                    font.family: "Audiowide"
                                    font.pixelSize: 22
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "Create and export your\nown .zzar mod packages"
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 220
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MouseArea {
                                id: makerMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selectedMode = "maker"
                                    currentPage = 2
                                }
                            }
                        }
                    }
                }

                Item {
                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 20

                        Rectangle {
                            width: parent.width
                            height: gameDirColumn.height + 40
                            color: "#1a1a1a"
                            radius: 15
                            border.color: "#3c3d3f"
                            border.width: 1

                            Column {
                                id: gameDirColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 20
                                spacing: 15

                                Text {
                                    text: "Game Directory"
                                    color: "#CDEE00"
                                    font.family: "Audiowide"
                                    font.pixelSize: 20
                                }

                                Text {
                                    text: "Select the ZenlessZoneZero_Data folder from your game installation."
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width - browseBtnWelcome.width - autoDetectBtnWelcome.width - 20
                                        height: 45
                                        color: "#252525"
                                        radius: 10
                                        border.color: "#555555"
                                        border.width: 1

                                        TextInput {
                                            id: gameDirInputWelcome
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            color: "#ffffff"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                            clip: true
                                            text: gameDirectory

                                            onTextChanged: {
                                                gameDirectory = text
                                            }

                                            Text {
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter
                                                text: "Path to ZenlessZoneZero_Data folder..."
                                                color: "#555555"
                                                font.family: "Alatsi"
                                                font.pixelSize: 14
                                                visible: gameDirInputWelcome.text.length === 0
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: browseBtnWelcome
                                        width: 100
                                        height: 45
                                        color: browseMouse.pressed ? "#a8c800" : (browseMouse.containsMouse ? "#e8ff33" : Theme.primaryAccent)
                                        radius: Theme.radiusMedium
                                        scale: browseMouse.pressed ? 0.97 : (browseMouse.containsMouse ? 1.03 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                                        Behavior on color { ColorAnimation { duration: Theme.animationDuration } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Browse"
                                            color: Theme.textOnAccent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeMedium
                                        }

                                        MouseArea {
                                            id: browseMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                console.log("[WelcomeDialog] Browse button clicked")
                                                browseGameDirClicked()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: autoDetectBtnWelcome
                                        width: 145
                                        height: 45
                                        color: root.isAutoDetecting ? "#888888" : (autoDetectMouse.pressed ? "#a8c800" : (autoDetectMouse.containsMouse ? "#e8ff33" : Theme.primaryAccent))
                                        radius: Theme.radiusMedium
                                        scale: autoDetectMouse.pressed ? 0.97 : (autoDetectMouse.containsMouse ? 1.03 : 1.0)
                                        opacity: root.isAutoDetecting ? 0.7 : 1.0
                                        Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                                        Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                                        Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Item {
                                                width: 16
                                                height: 16
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: root.isAutoDetecting

                                                RotationAnimation on rotation {
                                                    from: 0
                                                    to: 360
                                                    duration: 1000
                                                    loops: Animation.Infinite
                                                    running: root.isAutoDetecting
                                                }

                                                Canvas {
                                                    anchors.fill: parent
                                                    onPaint: {
                                                        var ctx = getContext("2d");
                                                        ctx.reset();
                                                        ctx.beginPath();
                                                        ctx.arc(8, 8, 6, 0, Math.PI * 1.5);
                                                        ctx.strokeStyle = Theme.textOnAccent;
                                                        ctx.lineWidth = 2;
                                                        ctx.stroke();
                                                    }
                                                }
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.isAutoDetecting ? "Searching..." : "Auto-Detect"
                                                color: Theme.textOnAccent
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeMedium
                                            }
                                        }

                                        MouseArea {
                                            id: autoDetectMouse
                                            anchors.fill: parent
                                            hoverEnabled: !root.isAutoDetecting
                                            cursorShape: root.isAutoDetecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: {
                                                if (!root.isAutoDetecting) {
                                                    console.log("[WelcomeDialog] Auto-detect button clicked")
                                                    autoDetectClicked()
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: gameDirectory.length > 0 ? "✓ Game directory set" : "⚠ No game directory configured"
                                    color: gameDirectory.length > 0 ? "#92fa00" : "#e91a1a"
                                    font.family: "Alatsi"
                                    font.pixelSize: 13
                                }
                            }
                        }

                        Text {
                            text: "You can configure this later from the Settings page"
                            color: "#666666"
                            font.family: "Alatsi"
                            font.pixelSize: 12
                            font.italic: true
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Item {
                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 20

                        Rectangle {
                            width: parent.width
                            height: wwiseColumn.height + 40
                            color: "#1a1a1a"
                            radius: 15
                            border.color: "#3c3d3f"
                            border.width: 1

                            Column {
                                id: wwiseColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 20
                                spacing: 15

                                Text {
                                    text: "Wwise Setup"
                                    color: "#CDEE00"
                                    font.family: "Audiowide"
                                    font.pixelSize: 20
                                }

                                Text {
                                    text: "Wwise is required to convert audio files for Zenless Zone Zero."
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Row {
                                    spacing: 10
                                    width: parent.width

                                    Text {
                                        text: "Status:"
                                        color: "#ffffff"
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        text: wwiseInstalled ? "INSTALLED ✓" : "NOT INSTALLED"
                                        color: wwiseInstalled ? "#92fa00" : "#e91a1a"
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                        font.bold: false
                                    }

                                    Item { width: 1; height: 1; Layout.fillWidth: true }

                                    Rectangle {
                                        width: 100
                                        height: 36
                                        color: checkBtnMouse.pressed ? "#444444" : (checkBtnMouse.containsMouse ? "#666666" : "#555555")
                                        radius: 20
                                        visible: !isInstallingWwise
                                        Behavior on color { ColorAnimation { duration: Theme.animationDuration } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Check"
                                            color: "#ffffff"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: checkBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: checkWwiseClicked()
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 50
                                    color: wwiseInstalled ? "#3c3d3f" : (setupBtnMouse.pressed ? "#a8c800" : setupBtnMouse.containsMouse ? "#e8ff33" : "#CDEE00")
                                    radius: 10
                                    opacity: (wwiseInstalled || isInstallingWwise) ? 0.5 : 1.0
                                    visible: !wwiseInstalled || isInstallingWwise
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 10

                                        Item {
                                            width: 20
                                            height: 20
                                            visible: isInstallingWwise

                                            RotationAnimation on rotation {
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                                running: isInstallingWwise
                                            }

                                            Canvas {
                                                anchors.fill: parent
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.reset();
                                                    ctx.beginPath();
                                                    ctx.arc(10, 10, 7, 0, Math.PI * 1.5);
                                                    ctx.strokeStyle = "#000000";
                                                    ctx.lineWidth = 2.5;
                                                    ctx.stroke();
                                                }
                                            }
                                        }

                                        Text {
                                            text: isInstallingWwise ? "Installing..." : "Run Automated Setup"
                                            color: "#000000"
                                            font.family: "Alatsi"
                                            font.pixelSize: 16
                                            font.bold: false
                                        }
                                    }

                                    MouseArea {
                                        id: setupBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: !wwiseInstalled && !isInstallingWwise
                                        cursorShape: (wwiseInstalled || isInstallingWwise) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (!wwiseInstalled && !isInstallingWwise) {
                                                isInstallingWwise = true
                                                runWwiseSetupClicked()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: wwiseInstalled ?
                                  "Wwise is installed and ready! You can start creating mods." :
                                  "You can install Wwise later from the Settings page"
                            color: "#666666"
                            font.family: "Alatsi"
                            font.pixelSize: 12
                            font.italic: true
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Item {
                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 20

                        Rectangle {
                            width: parent.width
                            height: audioToolsColumn.height + 40
                            color: "#1a1a1a"
                            radius: 15
                            border.color: "#3c3d3f"
                            border.width: 1

                            Column {
                                id: audioToolsColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 20
                                spacing: 15

                                Text {
                                    text: "Windows Audio Tools"
                                    color: "#CDEE00"
                                    font.family: "Audiowide"
                                    font.pixelSize: 20
                                }

                                Text {
                                    text: "FFmpeg and vgmstream are required to convert audio files."
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Row {
                                    spacing: 10
                                    width: parent.width

                                    Text {
                                        text: "Status:"
                                        color: "#ffffff"
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        text: audioToolsInstalled ? "INSTALLED ✓" : "NOT INSTALLED"
                                        color: audioToolsInstalled ? "#92fa00" : "#e91a1a"
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                        font.bold: false
                                    }

                                    Item { width: 1; height: 1; Layout.fillWidth: true }

                                    Rectangle {
                                        width: 100
                                        height: 36
                                        color: checkAudioToolsBtnMouse.pressed ? "#444444" : (checkAudioToolsBtnMouse.containsMouse ? "#666666" : "#555555")
                                        radius: 20
                                        visible: !isInstallingAudioTools
                                        Behavior on color { ColorAnimation { duration: Theme.animationDuration } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Check"
                                            color: "#ffffff"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: checkAudioToolsBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: checkAudioToolsClicked()
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 50
                                    color: audioToolsInstalled ? "#3c3d3f" : (audioToolsSetupBtnMouse.pressed ? "#a8c800" : audioToolsSetupBtnMouse.containsMouse ? "#e8ff33" : "#CDEE00")
                                    radius: 10
                                    opacity: (audioToolsInstalled || isInstallingAudioTools) ? 0.5 : 1.0
                                    visible: !audioToolsInstalled || isInstallingAudioTools
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 10

                                        Item {
                                            width: 20
                                            height: 20
                                            visible: isInstallingAudioTools

                                            RotationAnimation on rotation {
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                                running: isInstallingAudioTools
                                            }

                                            Canvas {
                                                anchors.fill: parent
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.reset();
                                                    ctx.beginPath();
                                                    ctx.arc(10, 10, 7, 0, Math.PI * 1.5);
                                                    ctx.strokeStyle = "#000000";
                                                    ctx.lineWidth = 2.5;
                                                    ctx.stroke();
                                                }
                                            }
                                        }

                                        Text {
                                            text: isInstallingAudioTools ? "Installing..." : "Install Audio Tools"
                                            color: "#000000"
                                            font.family: "Alatsi"
                                            font.pixelSize: 16
                                            font.bold: false
                                        }
                                    }

                                    MouseArea {
                                        id: audioToolsSetupBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: !audioToolsInstalled && !isInstallingAudioTools
                                        cursorShape: (audioToolsInstalled || isInstallingAudioTools) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (!audioToolsInstalled && !isInstallingAudioTools) {
                                                isInstallingAudioTools = true
                                                runAudioToolsSetupClicked()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: audioToolsInstalled ?
                                  "Audio tools are installed! You can now convert audio files." :
                                  "You can install these tools later from the Settings page"
                            color: "#666666"
                            font.family: "Alatsi"
                            font.pixelSize: 12
                            font.italic: true
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Item {
                    Column {
                        anchors.centerIn: parent
                        spacing: 5
                        width: parent.width

                        Image {
                            source: "../assets/BurniceYay.png"
                            width: 240
                            height: 240
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            anchors.horizontalCenter: parent.horizontalCenter

                        }

                        Text {
                            text: "You're all set!"
                            color: "#CDEE00"
                            font.family: "Audiowide"
                            font.pixelSize: 32
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: selectedMode === "maker" ?
                                "ZZAR is configured for mod creation. Go make something!!" :
                                "ZZAR is ready to manage some mods. Install something!"
                            color: "#aaaaaa"
                            font.family: "Alatsi"
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width * 0.8
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Item { height: 10; width: 1 }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15
                visible: currentPage > 1

                Rectangle {
                    width: 120
                    height: 50
                    radius: Theme.radiusMedium
                    color: backMouse.containsMouse ? "#333333" : Theme.surfaceColor
                    scale: backMouse.pressed ? 0.97 : (backMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: "< Back"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {

                            if (selectedMode === "install" && currentPage === 5) {
                                currentPage = 2
                            } else if (selectedMode === "maker" && currentPage === 5 && Qt.platform.os !== "windows") {
                                currentPage = 3
                            } else {
                                currentPage = currentPage - 1
                            }
                        }
                    }
                }

                Rectangle {
                    width: 150
                    height: 50
                    radius: Theme.radiusMedium
                    color: continueMouse.pressed ? "#a8c800" : (continueMouse.containsMouse ? "#e8ff33" : Theme.primaryAccent)
                    scale: continueMouse.pressed ? 0.97 : (continueMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent

                        text: currentPage === 5 ? "Start Tutorial" : "Continue >"
                        color: Theme.textOnAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    MouseArea {
                        id: continueMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (selectedMode === "install") {
                                if (currentPage === 2) {
                                    currentPage = 5
                                } else if (currentPage === 5) {
                                    startTutorialClicked()
                                    modeSelected(selectedMode)
                                    hide()
                                }
                            } else if (selectedMode === "maker") {
                                if (currentPage === 2) {
                                    currentPage = 3
                                    checkWwiseClicked()
                                } else if (currentPage === 3) {

                                    if (Qt.platform.os === "windows") {
                                        currentPage = 4
                                        checkAudioToolsClicked()
                                    } else {
                                        currentPage = 5
                                    }
                                } else if (currentPage === 4) {
                                    currentPage = 5
                                } else if (currentPage === 5) {
                                    startTutorialClicked()
                                    modeSelected(selectedMode)
                                    hide()
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "Skip tutorial"
                color: skipTutorialMouse.containsMouse ? "#d8fa00" : "#888888"
                font.family: "Alatsi"
                font.pixelSize: 13
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: currentPage === 5
                Behavior on color { ColorAnimation { duration: 100 } }

                MouseArea {
                    id: skipTutorialMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        modeSelected(selectedMode)
                        hide()
                    }
                }
            }

            Text {
                text: "You can always change this later in settings"
                color: "#666666"
                font.family: "Alatsi"
                font.pixelSize: 12
                font.italic: true
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: currentPage === 1
            }
        }
    }

    function show() {
        visible = true
        currentPage = 1
        selectedMode = ""
        gameDirectory = ""
    }

    function hide() {
        closing = true
        hideTimer.start()
    }

    function setGameDirectory(path) {
        gameDirectory = path
        if (gameDirInputWelcome) {
            gameDirInputWelcome.text = path
        }
    }
}

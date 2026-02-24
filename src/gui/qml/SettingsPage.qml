import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

Item {
    id: settingsPage
    objectName: "settingsPage"

    signal browseGameDirClicked()
    signal autoDetectClicked()
    signal browseModsDirClicked()
    signal resetModsDirClicked()
    signal saveSettingsClicked(string gamePath)
    signal modCreationModeToggled(bool enabled)
    signal checkWwiseClicked()
    signal runWwiseSetupClicked()
    signal checkAudioToolsClicked()
    signal runAudioToolsSetupClicked()
    signal checkForUpdatesClicked()
    signal downloadUpdateClicked()
    signal restartClicked()
    signal githubTokenSaved(string token)
    signal testUpdateDialogClicked()
    signal redoTutorialClicked()
    signal languageChanged(string langCode)

    property string gameDirectory: ""
    property string currentLanguage: "en"
    property string modsDirectory: ""
    property string defaultModsDirectory: ""
    property bool modCreationEnabled: false
    property bool wwiseInstalled: false
    property bool isInstallingWwise: false
    property bool audioToolsInstalled: false
    property bool isInstallingAudioTools: false
    property bool isAutoDetecting: false

    property bool isCheckingUpdates: false
    property bool isDownloadingUpdate: false
    property bool updateAvailable: false
    property string latestVersion: ""
    property int downloadPercent: 0
    property bool updateDownloaded: false
    property bool devMode: false
    property string githubToken: ""

    property int currentCategory: 0

    Rectangle {
        id: outerFrame
        anchors.fill: parent
        anchors.margins: 15
        color: "#3c3d3f"
        radius: 36.44

        Rectangle {
            id: innerFrame
            anchors.fill: parent
            anchors.margins: 15
            color: "#252525"
            radius: 36.44

            Row {
                id: categoryBar
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: [qsTr("General"), qsTr("Mod Creation"), qsTr("App")]

                    Item {
                        width: tabLabel.implicitWidth + 48
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: 22
                            color: {
                                if (currentCategory === index) return "#d8fa00"
                                if (tabMouse.containsMouse) return "#555555"
                                return "transparent"
                            }
                            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: currentCategory === index ? "#000000" : "#ffffff"
                            font.family: "Alatsi"
                            font.pixelSize: 18
                            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                currentCategory = index
                                scrollArea.contentY = 0
                            }
                        }
                    }
                }
            }

            Flickable {
                id: scrollArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: categoryBar.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 30
                anchors.rightMargin: 30
                anchors.topMargin: 15
                anchors.bottomMargin: 30
                contentHeight: settingsContent.height
                clip: true
                boundsBehavior: Flickable.DragOverBounds
                flickDeceleration: 5000
                maximumFlickVelocity: 2500

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    minimumSize: 0.1
                    anchors.right: parent.right
                    anchors.rightMargin: 0

                    contentItem: Rectangle {
                        implicitWidth: 8
                        radius: 4
                        color: parent.pressed ? "#d8fa00" : (parent.hovered ? "#aac800" : "#555555")
                        opacity: parent.active ? 1.0 : 0.5

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    background: Rectangle {
                        implicitWidth: 8
                        radius: 4
                        color: "#2a2a2a"
                        opacity: 0.3
                    }
                }

                Column {
                    id: settingsContent
                    width: parent.width
                    spacing: 30

                    Rectangle {
                        width: parent.width
                        height: languageContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 0

                        Column {
                            id: languageContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("Language")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTr("Select the display language for ZZAR.")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            ComboBox {
                                id: languageCombo
                                width: 250
                                height: Theme.buttonHeight
                                model: translationManager.availableLanguages
                                textRole: "name"

                                currentIndex: {
                                    var langs = translationManager.availableLanguages
                                    for (var i = 0; i < langs.length; i++) {
                                        if (langs[i].code === settingsPage.currentLanguage) return i
                                    }
                                    return 0
                                }

                                property bool selectedIncomplete: translationManager.isIncomplete(settingsPage.currentLanguage)

                                onActivated: {
                                    var selectedLang = translationManager.availableLanguages[index]
                                    settingsPage.currentLanguage = selectedLang.code
                                    languageChanged(selectedLang.code)
                                    selectedIncomplete = translationManager.isIncomplete(selectedLang.code)
                                }

                                background: Rectangle {
                                    color: languageCombo.pressed ? Qt.darker(Theme.cardBackground, 1.2)
                                         : languageCombo.hovered ? Qt.lighter(Theme.cardBackground, 1.1)
                                         : Theme.cardBackground
                                    radius: Theme.radiusMedium
                                    border.color: "transparent"
                                    border.width: 0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                }

                                contentItem: Text {
                                    text: languageCombo.displayText
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 14
                                    rightPadding: 40
                                }

                                indicator: Rectangle {
                                    x: languageCombo.width - width - 10
                                    y: (languageCombo.height - height) / 2
                                    width: 20
                                    height: 20
                                    color: "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u25BC"
                                        color: Theme.textPrimary
                                        font.pixelSize: 10
                                    }
                                }

                                delegate: ItemDelegate {
                                    width: languageCombo.width - 8
                                    height: Theme.buttonHeight
                                    highlighted: languageCombo.highlightedIndex === index

                                    background: Rectangle {
                                        color: {
                                            if (parent.highlighted) return Theme.primaryAccent
                                            if (parent.hovered) return Qt.lighter(Theme.surfaceDark, 1.3)
                                            return Theme.surfaceDark
                                        }
                                        radius: Theme.radiusSmall
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    contentItem: Text {
                                        text: modelData.name
                                        color: parent.highlighted ? Theme.textOnAccent : Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 14
                                    }
                                }

                                popup: Popup {
                                    y: languageCombo.height + 4
                                    width: languageCombo.width
                                    padding: 4

                                    background: Rectangle {
                                        color: Theme.surfaceDark
                                        radius: Theme.radiusMedium
                                        border.color: Qt.rgba(1, 1, 1, 0.1)
                                        border.width: 1

                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            transparentBorder: true
                                            horizontalOffset: 0
                                            verticalOffset: 4
                                            radius: 8
                                            samples: 16
                                            color: "#80000000"
                                        }
                                    }

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: languageCombo.popup.visible ? languageCombo.delegateModel : null
                                        currentIndex: languageCombo.highlightedIndex
                                        spacing: 2

                                        ScrollIndicator.vertical: ScrollIndicator {
                                            active: true
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: langWarningCol.implicitHeight + 20
                                radius: 10
                                color: "#2a2a1a"
                                border.color: "#ffaa00"
                                border.width: 1
                                visible: languageCombo.selectedIncomplete

                                Column {
                                    id: langWarningCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Text {
                                        text: qsTr("Warning")
                                        color: "#ffaa00"
                                        font.family: "Alatsi"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        text: qsTr("This translation is incomplete. Some text may appear in English.")
                                        color: "#ccaa66"
                                        font.family: "Alatsi"
                                        font.pixelSize: 12
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.2
                                    }

                                    Item {
                                        width: helpLink.implicitWidth
                                        height: helpLink.implicitHeight

                                        Text {
                                            id: helpLink
                                            text: qsTr("Want to help?")
                                            color: helpArea.containsMouse ? "#ffffff" : "#d8fa00"
                                            font.family: "Alatsi"
                                            font.pixelSize: 12
                                            font.underline: helpArea.containsMouse
                                        }

                                        MouseArea {
                                            id: helpArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mainWindow.showAlertDialog(
                                                qsTr("Help Translate ZZAR!"),
                                                qsTr("I need your help to translate ZZAR to more languages!\n\nIf you're interested in translating, reach out to:\n\nDiscord: Pucas01\nTwitter: Pucas02\n\nOr open an issue on the GitHub repo.\n\nI only speak English and Dutch."),
                                                "../assets/YeShunguangReed.png"
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: gameDirContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 0

                        Column {
                            id: gameDirContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("Game Directory")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTr("Select the ZenlessZoneZero_Data folder from your game installation.")
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
                                    width: parent.width - browseBtn.width - autoDetectBtn.width - 20
                                    height: 45
                                    color: "#1a1a1a"
                                    radius: 10
                                    border.color: "#555555"
                                    border.width: 1

                                    TextInput {
                                        id: gameDirInput
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
                                            text: qsTr("Path to ZenlessZoneZero_Data folder...")
                                            color: "#555555"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                            visible: gameDirInput.text.length === 0
                                        }
                                    }
                                }

                                Item {
                                    id: browseBtn
                                    width: 100
                                    height: 45

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.primaryAccent
                                        radius: Theme.radiusMedium
                                        scale: browseMouse.pressed ? 0.97 : (browseMouse.containsMouse ? 1.03 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Browse")
                                        color: Theme.textOnAccent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeMedium
                                    }

                                    MouseArea {
                                        id: browseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: browseGameDirClicked()
                                    }
                                }

                                Item {
                                    id: autoDetectBtn
                                    width: 145
                                    height: 45

                                    Rectangle {
                                        anchors.fill: parent
                                        color: settingsPage.isAutoDetecting ? "#888888" : Theme.primaryAccent
                                        radius: Theme.radiusMedium
                                        scale: autoDetectMouse.pressed ? 0.97 : (autoDetectMouse.containsMouse ? 1.03 : 1.0)
                                        opacity: settingsPage.isAutoDetecting ? 0.7 : 1.0
                                        Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                                        Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                                        Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Item {
                                            width: 16
                                            height: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: settingsPage.isAutoDetecting

                                            RotationAnimation on rotation {
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                                running: settingsPage.isAutoDetecting
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
                                            text: settingsPage.isAutoDetecting ? qsTr("Searching...") : qsTr("Auto-Detect")
                                            color: Theme.textOnAccent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeMedium
                                        }
                                    }

                                    MouseArea {
                                        id: autoDetectMouse
                                        anchors.fill: parent
                                        hoverEnabled: !settingsPage.isAutoDetecting
                                        cursorShape: settingsPage.isAutoDetecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (!settingsPage.isAutoDetecting) {
                                                autoDetectClicked()
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                id: statusText
                                text: gameDirectory.length > 0 ? qsTr("Game directory set") : qsTr("No game directory configured")
                                color: gameDirectory.length > 0 ? "#92fa00" : "#e91a1a"
                                font.family: "Alatsi"
                                font.pixelSize: 12
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: modsDirContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 0

                        Column {
                            id: modsDirContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("Mods Directory")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTr("Choose where mod files are stored. Leave empty to use the default location.")
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
                                    width: parent.width - browseModsBtn.width - resetModsBtn.width - 20
                                    height: 45
                                    color: "#1a1a1a"
                                    radius: 10
                                    border.color: "#555555"
                                    border.width: 1

                                    TextInput {
                                        id: modsDirInput
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        color: "#ffffff"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        clip: true
                                        text: modsDirectory

                                        onTextChanged: {
                                            modsDirectory = text
                                        }

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: defaultModsDirectory.length > 0 ? defaultModsDirectory : qsTr("Default mods directory...")
                                            color: "#555555"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                            visible: modsDirInput.text.length === 0
                                        }
                                    }
                                }

                                Item {
                                    id: browseModsBtn
                                    width: 100
                                    height: 45

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.primaryAccent
                                        radius: Theme.radiusMedium
                                        scale: browseModsMouse.pressed ? 0.97 : (browseModsMouse.containsMouse ? 1.03 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Browse")
                                        color: Theme.textOnAccent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeMedium
                                    }

                                    MouseArea {
                                        id: browseModsMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: browseModsDirClicked()
                                    }
                                }

                                Item {
                                    id: resetModsBtn
                                    width: 100
                                    height: 45

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#555555"
                                        radius: Theme.radiusMedium
                                        scale: resetModsMouse.pressed ? 0.97 : (resetModsMouse.containsMouse ? 1.03 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Reset")
                                        color: "#ffffff"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeMedium
                                    }

                                    MouseArea {
                                        id: resetModsMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: resetModsDirClicked()
                                    }
                                }
                            }

                            Text {
                                text: modsDirectory.length > 0 ? qsTr("Custom mods directory set") : qsTr("Using default: ") + defaultModsDirectory
                                color: modsDirectory.length > 0 ? "#92fa00" : "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 12
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: modCreationContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 1

                        Column {
                            id: modCreationContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            RowLayout {
                                width: parent.width
                                spacing: 20

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Text {
                                        text: qsTr("Mod Creation Mode")
                                        color: "#d8fa00"
                                        font.family: "Alatsi"
                                        font.pixelSize: 24
                                        font.weight: Font.Normal
                                    }

                                    Text {
                                        text: qsTr("Enable tools for creating new mods (requires Wwise).")
                                        color: "#888888"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }

                                Item {
                                    width: 60
                                    height: 30

                                    Rectangle {
                                        id: modCreationSwitchBg
                                        anchors.fill: parent
                                        radius: 15
                                        color: settingsPage.modCreationEnabled ? "#d8fa00" : "#555555"
                                        Behavior on color { ColorAnimation { duration: 200 } }

                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 13
                                            color: "#ffffff"
                                            x: settingsPage.modCreationEnabled ? parent.width - width - 2 : 2
                                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            settingsPage.modCreationEnabled = !settingsPage.modCreationEnabled
                                            modCreationModeToggled(settingsPage.modCreationEnabled)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: tutorialContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 2

                        Column {
                            id: tutorialContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("Tutorial")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTr("Walk through the main features of ZZAR with a guided tutorial.")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            Item {
                                width: parent.width
                                height: 45

                                Rectangle {
                                    anchors.fill: parent
                                    color: redoTutorialMouse.pressed ? "#a8c800" : redoTutorialMouse.containsMouse ? "#e8ff33" : "#d8fa00"
                                    radius: 10
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Redo Tutorial")
                                    color: "#000000"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                    font.bold: false
                                }

                                MouseArea {
                                    id: redoTutorialMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: redoTutorialClicked()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: wwiseContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 1 && settingsPage.modCreationEnabled

                        Column {
                            id: wwiseContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("Wwise Setup")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTr("Wwise is required to convert audio files for Zenless Zone Zero.")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            RowLayout {
                                spacing: 10

                                Text {
                                    text: qsTr("Status:")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: settingsPage.wwiseInstalled ? qsTr("INSTALLED") : qsTr("NOT INSTALLED")
                                    color: settingsPage.wwiseInstalled ? "#92fa00" : "#e91a1a"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                    font.bold: false
                                }

                                Item { Layout.fillWidth: true }

                                Item {
                                    width: 100
                                    height: 36
                                    visible: !settingsPage.isInstallingWwise

                                    Rectangle {
                                        anchors.fill: parent
                                        color: checkBtnMouse.pressed ? "#444444" : "#555555"
                                        radius: 20
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Check")
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

                            Item {
                                width: parent.width
                                height: 45
                                visible: !settingsPage.wwiseInstalled || settingsPage.isInstallingWwise

                                Rectangle {
                                    anchors.fill: parent
                                    color: settingsPage.wwiseInstalled ? "#3c3d3f" : (setupBtnMouse.pressed ? "#a8c800" : setupBtnMouse.containsMouse ? "#e8ff33" : "#d8fa00")
                                    radius: 10
                                    opacity: (settingsPage.wwiseInstalled || settingsPage.isInstallingWwise) ? 0.5 : 1.0
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Item {
                                        width: 20
                                        height: 20
                                        visible: settingsPage.isInstallingWwise
                                        
                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                            running: settingsPage.isInstallingWwise
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
                                        text: settingsPage.isInstallingWwise ? qsTr("Installing...") : qsTr("Run Automated Setup")
                                        color: "#000000"
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                        font.bold: false
                                    }
                                }

                                MouseArea {
                                    id: setupBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: !settingsPage.wwiseInstalled && !settingsPage.isInstallingWwise
                                    cursorShape: (settingsPage.wwiseInstalled || settingsPage.isInstallingWwise) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (!settingsPage.wwiseInstalled && !settingsPage.isInstallingWwise) {
                                            settingsPage.isInstallingWwise = true
                                            runWwiseSetupClicked()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: audioToolsContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 1 && Qt.platform.os === "windows"

                        Column {
                            id: audioToolsContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("Windows Audio Tools")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTr("FFmpeg and vgmstream are required to convert audio files.")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            RowLayout {
                                spacing: 10

                                Text {
                                    text: qsTr("Status:")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: settingsPage.audioToolsInstalled ? qsTr("INSTALLED") : qsTr("NOT INSTALLED")
                                    color: settingsPage.audioToolsInstalled ? "#92fa00" : "#e91a1a"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                    font.bold: false
                                }

                                Item { Layout.fillWidth: true }

                                Item {
                                    width: 100
                                    height: 36
                                    visible: !settingsPage.isInstallingAudioTools

                                    Rectangle {
                                        anchors.fill: parent
                                        color: checkAudioToolsBtnMouse.pressed ? "#444444" : "#555555"
                                        radius: 20
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Check")
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

                            Item {
                                width: parent.width
                                height: 45
                                visible: !settingsPage.audioToolsInstalled || settingsPage.isInstallingAudioTools

                                Rectangle {
                                    anchors.fill: parent
                                    color: settingsPage.audioToolsInstalled ? "#3c3d3f" : (audioToolsSetupBtnMouse.pressed ? "#a8c800" : audioToolsSetupBtnMouse.containsMouse ? "#e8ff33" : "#d8fa00")
                                    radius: 10
                                    opacity: (settingsPage.audioToolsInstalled || settingsPage.isInstallingAudioTools) ? 0.5 : 1.0
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Item {
                                        width: 20
                                        height: 20
                                        visible: settingsPage.isInstallingAudioTools

                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                            running: settingsPage.isInstallingAudioTools
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
                                        text: settingsPage.isInstallingAudioTools ? qsTr("Installing...") : qsTr("Install Audio Tools")
                                        color: "#000000"
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                        font.bold: false
                                    }
                                }

                                MouseArea {
                                    id: audioToolsSetupBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: !settingsPage.audioToolsInstalled && !settingsPage.isInstallingAudioTools
                                    cursorShape: (settingsPage.audioToolsInstalled || settingsPage.isInstallingAudioTools) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (!settingsPage.audioToolsInstalled && !settingsPage.isInstallingAudioTools) {
                                            settingsPage.isInstallingAudioTools = true
                                            runAudioToolsSetupClicked()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: updatesContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 2

                        Column {
                            id: updatesContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("Updates")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTr("Check for new versions of ZZAR.")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            RowLayout {
                                spacing: 10

                                Text {
                                    text: qsTr("Current Version:")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: Qt.application.version
                                    color: "#d8fa00"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Item { Layout.fillWidth: true }

                                Item {
                                    width: 160
                                    height: 36
                                    visible: !settingsPage.isCheckingUpdates && !settingsPage.updateAvailable && !settingsPage.updateDownloaded

                                    Rectangle {
                                        anchors.fill: parent
                                        color: checkUpdatesMouse.pressed ? "#444444" : "#555555"
                                        radius: 20
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Check for Updates")
                                        color: "#ffffff"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        id: checkUpdatesMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: checkForUpdatesClicked()
                                    }
                                }

                                Item {
                                    width: 160
                                    height: 36
                                    visible: settingsPage.isCheckingUpdates

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#555555"
                                        radius: 20
                                        opacity: 0.7
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Item {
                                            width: 16
                                            height: 16
                                            anchors.verticalCenter: parent.verticalCenter

                                            RotationAnimation on rotation {
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                                running: settingsPage.isCheckingUpdates
                                            }

                                            Canvas {
                                                anchors.fill: parent
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.reset();
                                                    ctx.beginPath();
                                                    ctx.arc(8, 8, 6, 0, Math.PI * 1.5);
                                                    ctx.strokeStyle = "#ffffff";
                                                    ctx.lineWidth = 2;
                                                    ctx.stroke();
                                                }
                                            }
                                        }

                                        Text {
                                            text: qsTr("Checking...")
                                            color: "#ffffff"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                        }
                                    }
                                }

                                Item {
                                    width: 110
                                    height: 36
                                    visible: settingsPage.devMode

                                    Rectangle {
                                        anchors.fill: parent
                                        color: testDialogMouse.pressed ? "#a8c800" : testDialogMouse.containsMouse ? "#e8ff33" : "#d8fa00"
                                        radius: 20
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Test Dialog")
                                        color: "#000000"
                                        font.family: "Alatsi"
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        id: testDialogMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: testUpdateDialogClicked()
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: settingsPage.updateAvailable && !settingsPage.updateDownloaded ? updateAvailableCol.height : 0
                                visible: settingsPage.updateAvailable && !settingsPage.updateDownloaded
                                clip: true

                                Column {
                                    id: updateAvailableCol
                                    width: parent.width
                                    spacing: 10

                                    Text {
                                        text: qsTr("Version %1 is available!").arg(settingsPage.latestVersion)
                                        color: "#92fa00"
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                    }

                                    Item {
                                        width: parent.width
                                        height: 45

                                        Rectangle {
                                            anchors.fill: parent
                                            color: settingsPage.isDownloadingUpdate ? "#3c3d3f" : (downloadBtnMouse.pressed ? "#a8c800" : downloadBtnMouse.containsMouse ? "#e8ff33" : "#d8fa00")
                                            radius: 10
                                            opacity: settingsPage.isDownloadingUpdate ? 0.7 : 1.0
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 10

                                            Item {
                                                width: 20
                                                height: 20
                                                visible: settingsPage.isDownloadingUpdate

                                                RotationAnimation on rotation {
                                                    from: 0
                                                    to: 360
                                                    duration: 1000
                                                    loops: Animation.Infinite
                                                    running: settingsPage.isDownloadingUpdate
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
                                                text: settingsPage.isDownloadingUpdate ? qsTr("Downloading... %1%").arg(settingsPage.downloadPercent) : qsTr("Download & Install")
                                                color: "#000000"
                                                font.family: "Alatsi"
                                                font.pixelSize: 16
                                                font.bold: false
                                            }
                                        }

                                        MouseArea {
                                            id: downloadBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: !settingsPage.isDownloadingUpdate
                                            cursorShape: settingsPage.isDownloadingUpdate ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: {
                                                if (!settingsPage.isDownloadingUpdate) {
                                                    settingsPage.isDownloadingUpdate = true
                                                    downloadUpdateClicked()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: settingsPage.updateDownloaded ? restartCol.height : 0
                                visible: settingsPage.updateDownloaded
                                clip: true

                                Column {
                                    id: restartCol
                                    width: parent.width
                                    spacing: 10

                                    Text {
                                        text: qsTr("Update downloaded! Restart to apply.")
                                        color: "#92fa00"
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                    }

                                    Item {
                                        width: parent.width
                                        height: 45

                                        Rectangle {
                                            anchors.fill: parent
                                            color: restartBtnMouse.pressed ? "#a8c800" : restartBtnMouse.containsMouse ? "#e8ff33" : "#d8fa00"
                                            radius: 10
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("Restart Now")
                                            color: "#000000"
                                            font.family: "Alatsi"
                                            font.pixelSize: 16
                                            font.bold: false
                                        }

                                        MouseArea {
                                            id: restartBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: restartClicked()
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 10
                                visible: settingsPage.devMode

                                Text {
                                    text: qsTr("GitHub Token (Dev Mode)")
                                    color: "#d8fa00"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: qsTr("Required for private repos. Leave empty for public repos.")
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width - saveTokenBtn.width - 10
                                        height: 40
                                        color: "#1a1a1a"
                                        radius: 10
                                        border.color: "#555555"
                                        border.width: 1

                                        TextInput {
                                            id: tokenInput
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            color: "#ffffff"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                            clip: true
                                            echoMode: TextInput.Password
                                            text: settingsPage.githubToken

                                            Text {
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter
                                                text: "ghp_xxxxxxxxxxxx..."
                                                color: "#555555"
                                                font.family: "Alatsi"
                                                font.pixelSize: 14
                                                visible: tokenInput.text.length === 0
                                            }
                                        }
                                    }

                                    Item {
                                        id: saveTokenBtn
                                        width: 80
                                        height: 40

                                        Rectangle {
                                            anchors.fill: parent
                                            color: saveTokenMouse.pressed ? "#a8c800" : saveTokenMouse.containsMouse ? "#e8ff33" : "#d8fa00"
                                            radius: 10
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("Save")
                                            color: "#000000"
                                            font.family: "Alatsi"
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: saveTokenMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: githubTokenSaved(tokenInput.text)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: aboutContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 2

                        Column {
                            id: aboutContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("About ZZAR")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTr("Zenless Zone Zero Audio Replacer")
                                color: "#ffffff"
                                font.family: "Alatsi"
                                font.pixelSize: 16
                            }

                            Text {
                                text: qsTr("A tool for managing, making and applying audio mods to Zenless Zone Zero.")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            Row {
                                spacing: 10

                                Text {
                                    text: qsTr("Version:")
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                }

                                Text {
                                    text: Qt.application.version
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                }
                            }

                            Row {
                                spacing: 10

                                Text {
                                    text: qsTr("Author:")
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                }

                                Text {
                                    text: "pucas01"
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: creditContent.height + 105
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 2

                        Column {
                            id: creditContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 15

                            Text {
                                text: qsTr("Credits")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                    text: qsTr("Some of the awsesome people who made this posible")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "failsafe65"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("For making the original audio modding scripts")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "mob159"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("For making PCK extraction and packing scripts which have been used as refrence.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "Thoronium"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("For improving on failsafe65's PCK extraction and packing scripts which have been used as reference.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        
                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "noirs_rf"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("For making a free concept ZZZ design which this programs design is based on.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "Retrotecho"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("For making the first ZZAR logo design.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        
                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "alver_418"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("Maker of Zenless Tools, for making the Chat generator which assets of it where used.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                            Text {
                                text: qsTr("Testers")
                                color: "#d8fa00"
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "mob159"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("For helping me out the most during development.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "Marbles"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("For helping me to do some testing and providing feedback.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "Skysill"
                                    color: '#d8fa00'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTr("For helping me test the linux build.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 20
                    }
                }
            }

            Rectangle {
                id: topFade
                anchors.left: scrollArea.left
                anchors.right: scrollArea.right
                anchors.top: scrollArea.top
                height: 30
                opacity: Math.min(scrollArea.contentY / 5, 1.0)
                z: 1

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#252525" }
                    GradientStop { position: 1.0; color: "transparent" }
                }

                Behavior on opacity { NumberAnimation { duration: 80 } }
            }

            Rectangle {
                id: bottomFade
                anchors.left: scrollArea.left
                anchors.right: scrollArea.right
                anchors.bottom: scrollArea.bottom
                height: 30
                opacity: Math.min((scrollArea.contentHeight - scrollArea.height - scrollArea.contentY) / 5, 1.0)
                z: 1

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: "#252525" }
                }

                Behavior on opacity { NumberAnimation { duration: 80 } }
            }

            Item {
                id: saveButton
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                height: 60
                width: 220
                z: 2

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    radius: 30
                    color: saveMouse.containsMouse ? "#40CDEE00" : "#30000000"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    id: saveButtonBg
                    anchors.fill: parent
                    radius: 30
                    color: saveMouse.pressed ? "#b8de00" : saveMouse.containsMouse ? "#e0f533" : "#CDEE00"
                    scale: saveMouse.pressed ? 0.97 : 1.0
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 28
                        color: "transparent"
                        border.color: "#40ffffff"
                        border.width: 1
                        opacity: saveMouse.containsMouse ? 0.5 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: qsTr("Save Settings")
                        color: "#000000"
                        font.family: "Alatsi"
                        font.pixelSize: 20
                        font.bold: false
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: saveSettingsClicked(gameDirectory)
                }
            }
        }
    }

    function setGameDirectory(path) {
        gameDirectory = path
        gameDirInput.text = path
    }

    function setModsDirectory(path) {
        modsDirectory = path
        modsDirInput.text = path
    }
}

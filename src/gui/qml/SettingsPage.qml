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
    property bool enableGbThumbnails: false
    property bool hideGbThumbnailWarning: false

    property bool isCheckingUpdates: false
    property bool isDownloadingUpdate: false
    property bool updateAvailable: false
    property string latestVersion: ""
    property int downloadPercent: 0
    property bool updateDownloaded: false
    property bool devMode: false
    property string githubToken: ""

    property int currentCategory: 0

    CustomDialog {
        id: thumbnailConfirmDialog
        parent: Overlay.overlay
        title: qsTranslate("Application", "Enable Thumbnails?")
        message: qsTranslate("Application", "Enabling thumbnails will make API calls to GameBanana per thumbnail. GameBanana limits you to 250 requests every hour.\n\nExceeding this rate limit will temporarily block you from viewing mods for 1 hour. Are you sure you want to enable this feature?")
        confirmText: qsTranslate("Application", "Enable")
        cancelText: qsTranslate("Application", "Cancel")
        isConfirmation: true
        showCheckbox: true
        checkboxText: qsTranslate("Application", "Don't show this again")
        isChecked: false
        
        onConfirmed: {
            settingsPage.enableGbThumbnails = true
            if (isChecked) {
                settingsPage.hideGbThumbnailWarning = true
            }
        }
    }

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

            Item {
                id: categoryBar
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                height: 44
                width: tabRow.width

                Rectangle {
                    id: slidingPill
                    y: 0
                    height: 44
                    radius: 22
                    color: Theme.primaryAccent

                    property var tabWidths: []

                    function updatePosition() {
                        if (tabWidths.length === 0) return
                        var xPos = 0
                        for (var i = 0; i < currentCategory; i++) {
                            xPos += tabWidths[i] + 8
                        }
                        x = xPos
                        width = tabWidths[currentCategory] || 0
                    }

                    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                Row {
                    id: tabRow
                    spacing: 8

                    Repeater {
                        id: tabRepeater
                        model: [qsTranslate("Application", "General"), qsTranslate("Application", "Mod Creation"), qsTranslate("Application", "App")]

                        Item {
                            width: tabLabel.implicitWidth + 48
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: 22
                                color: "#555555"
                                opacity: tabMouse.containsMouse && currentCategory !== index ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
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

                            Component.onCompleted: {

                                var arr = slidingPill.tabWidths.slice()
                                arr[index] = width
                                slidingPill.tabWidths = arr
                                slidingPill.updatePosition()
                            }
                        }
                    }
                }

                onWidthChanged: slidingPill.updatePosition()

                Connections {
                    target: settingsPage
                    function onCurrentCategoryChanged() { slidingPill.updatePosition() }
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
                clip: true
                contentHeight: settingsContent.height
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
                        HoverHandler { id: settingsScrollHover }
                        color: parent.pressed ? Theme.primaryAccent : (settingsScrollHover.hovered ? Theme.accentLight : "#555555")
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
                                text: qsTranslate("Application", "Language")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTranslate("Application", "Select the display language for %1.").replace("%1", appName)
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
                                model: translationManager ? translationManager.availableLanguages : []
                                textRole: "name"

                                currentIndex: {
                                    if (!translationManager) return 0
                                    var langs = translationManager.availableLanguages
                                    for (var i = 0; i < langs.length; i++) {
                                        if (langs[i].code === settingsPage.currentLanguage) return i
                                    }
                                    return 0
                                }

                                property bool selectedIncomplete: translationManager ? translationManager.isIncomplete(settingsPage.currentLanguage) : false

                                onActivated: {
                                    var selectedLang = translationManager.availableLanguages[index]
                                    settingsPage.currentLanguage = selectedLang.code
                                    languageChanged(selectedLang.code)
                                    selectedIncomplete = translationManager.isIncomplete(selectedLang.code)
                                }

                                background: Rectangle {
                                    HoverHandler { id: langComboBgHover }
                                    color: languageCombo.pressed ? Qt.darker(Theme.cardBackground, 1.2)
                                         : langComboBgHover.hovered ? Qt.lighter(Theme.cardBackground, 1.1)
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
                                    id: langComboDelegate
                                    width: languageCombo.width - 8
                                    height: Theme.buttonHeight
                                    highlighted: languageCombo.highlightedIndex === index

                                    HoverHandler { id: langComboDelegateHover }

                                    background: Rectangle {
                                        color: {
                                            if (langComboDelegate.highlighted) return Theme.primaryAccent
                                            if (langComboDelegateHover.hovered) return Qt.lighter(Theme.surfaceDark, 1.3)
                                            return Theme.surfaceDark
                                        }
                                        radius: Theme.radiusSmall
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    contentItem: Text {
                                        text: modelData.name
                                        color: langComboDelegate.highlighted ? Theme.textOnAccent : Theme.textPrimary
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
                                        text: qsTranslate("Application", "Warning")
                                        color: "#ffaa00"
                                        font.family: "Alatsi"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        text: qsTranslate("Application", "This translation is incomplete. Some text may appear in English.")
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
                                            text: qsTranslate("Application", "Want to help?")
                                            color: helpArea.containsMouse ? "#ffffff" : Theme.primaryAccent
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
                                                qsTranslate("Application", "Help Translate %1!").replace("%1", appName),
                                                qsTranslate("Application", "I need your help to translate %1 to more languages!\n\nIf you're interested in translating, reach out to:\n\nDiscord: Pucas01\nTwitter: Pucas02\n\nOr open an issue on the GitHub repo.\n\nI only speak English and Dutch.").replace("%1", appName),
                                                "../assets/" + assetsDir + "/YeShunguangReed.png"
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
                                text: qsTranslate("Application", "Game Directory")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTranslate("Application", "Select the %1 folder from your game installation.").replace("%1", gameDataFolder)
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
                                            text: qsTranslate("Application", "Path to %1 folder...").replace("%1", gameDataFolder)
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
                                        text: qsTranslate("Application", "Browse")
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
                                            text: settingsPage.isAutoDetecting ? qsTranslate("Application", "Searching...") : qsTranslate("Application", "Auto-Detect")
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
                                text: gameDirectory.length > 0 ? qsTranslate("Application", "Game directory set") : qsTranslate("Application", "No game directory configured")
                                color: gameDirectory.length > 0 ? Theme.accentDark : "#e91a1a"
                                font.family: "Alatsi"
                                font.pixelSize: 12
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: gbThumbnailsContent.height + 40
                        color: "#333333"
                        radius: 20
                        visible: currentCategory === 2

                        Column {
                            id: gbThumbnailsContent
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
                                        text: qsTranslate("Application", "GameBanana Thumbnails")
                                        color: Theme.primaryAccent
                                        font.family: "Alatsi"
                                        font.pixelSize: 24
                                        font.weight: Font.Normal
                                    }

                                    Text {
                                        text: qsTranslate("Application", "Load mod thumbnails from GameBanana. Enabling this uses API calls and may lead to temporary rate limits if overused.")
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
                                        id: gbThumbnailsSwitchBg
                                        anchors.fill: parent
                                        radius: 15
                                        color: settingsPage.enableGbThumbnails ? Theme.primaryAccent : "#555555"
                                        Behavior on color { ColorAnimation { duration: 200 } }

                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 13
                                            color: "#ffffff"
                                            x: settingsPage.enableGbThumbnails ? parent.width - width - 2 : 2
                                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!settingsPage.enableGbThumbnails) {
                                                if (settingsPage.hideGbThumbnailWarning) {
                                                    settingsPage.enableGbThumbnails = true;
                                                } else {
                                                    thumbnailConfirmDialog.isChecked = false;
                                                    thumbnailConfirmDialog.visible = true;
                                                }
                                            } else {
                                                settingsPage.enableGbThumbnails = false;
                                            }
                                        }
                                    }
                                }
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
                                text: qsTranslate("Application", "Mods Directory")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTranslate("Application", "Choose where mod files are stored. Leave empty to use the default location.")
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
                                            text: defaultModsDirectory.length > 0 ? defaultModsDirectory : qsTranslate("Application", "Default mods directory...")
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
                                        text: qsTranslate("Application", "Browse")
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
                                        text: qsTranslate("Application", "Reset")
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
                                text: modsDirectory.length > 0 ? qsTranslate("Application", "Custom mods directory set") : qsTranslate("Application", "Using default: ") + defaultModsDirectory
                                color: modsDirectory.length > 0 ? Theme.accentDark : "#888888"
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
                                        text: qsTranslate("Application", "Mod Creation Mode")
                                        color: Theme.primaryAccent
                                        font.family: "Alatsi"
                                        font.pixelSize: 24
                                        font.weight: Font.Normal
                                    }

                                    Text {
                                        text: qsTranslate("Application", "Enable tools for creating new mods (requires Wwise).")
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
                                        color: settingsPage.modCreationEnabled ? Theme.primaryAccent : "#555555"
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
                                text: qsTranslate("Application", "Tutorial")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTranslate("Application", "Walk through the main features of %1 with a guided tutorial.").replace("%1", appName)
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
                                    color: redoTutorialMouse.pressed ? Theme.accentDark : redoTutorialMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent
                                    radius: 10
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTranslate("Application", "Redo Tutorial")
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
                                text: qsTranslate("Application", "Wwise Setup")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTranslate("Application", "Wwise is required to convert audio files for %1.").replace("%1", gameName)
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            RowLayout {
                                spacing: 10

                                Text {
                                    text: qsTranslate("Application", "Status:")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: settingsPage.wwiseInstalled ? qsTranslate("Application", "INSTALLED") : qsTranslate("Application", "NOT INSTALLED")
                                    color: settingsPage.wwiseInstalled ? Theme.accentDark : "#e91a1a"
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
                                        text: qsTranslate("Application", "Check")
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
                                    color: settingsPage.wwiseInstalled ? "#3c3d3f" : (setupBtnMouse.pressed ? Theme.accentDark : setupBtnMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent)
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
                                        text: settingsPage.isInstallingWwise ? qsTranslate("Application", "Installing...") : qsTranslate("Application", "Run Automated Setup")
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
                                text: qsTranslate("Application", "Windows Audio Tools")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTranslate("Application", "FFmpeg and vgmstream are required to convert audio files.")
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            RowLayout {
                                spacing: 10

                                Text {
                                    text: qsTranslate("Application", "Status:")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: settingsPage.audioToolsInstalled ? qsTranslate("Application", "INSTALLED") : qsTranslate("Application", "NOT INSTALLED")
                                    color: settingsPage.audioToolsInstalled ? Theme.accentDark : "#e91a1a"
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
                                        text: qsTranslate("Application", "Check")
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
                                    color: settingsPage.audioToolsInstalled ? "#3c3d3f" : (audioToolsSetupBtnMouse.pressed ? Theme.accentDark : audioToolsSetupBtnMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent)
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
                                        text: settingsPage.isInstallingAudioTools ? qsTranslate("Application", "Installing...") : qsTranslate("Application", "Install Audio Tools")
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
                                text: qsTranslate("Application", "Updates")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: qsTranslate("Application", "Check for new versions of %1.").replace("%1", appName)
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            RowLayout {
                                spacing: 10

                                Text {
                                    text: qsTranslate("Application", "Current Version:")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: Qt.application.version
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Item { Layout.fillWidth: true }

                                Item {
                                    implicitWidth: checkUpdatesText.implicitWidth + 32
                                    implicitHeight: 36
                                    visible: !settingsPage.isCheckingUpdates && !settingsPage.updateAvailable && !settingsPage.updateDownloaded

                                    Rectangle {
                                        anchors.fill: parent
                                        color: checkUpdatesMouse.pressed ? "#444444" : "#555555"
                                        radius: 20
                                    }

                                    Text {
                                        id: checkUpdatesText
                                        anchors.centerIn: parent
                                        text: qsTranslate("Application", "Check for Updates")
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
                                            text: qsTranslate("Application", "Checking...")
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
                                        color: testDialogMouse.pressed ? Theme.accentDark : testDialogMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent
                                        radius: 20
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTranslate("Application", "Test Dialog")
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
                                        text: qsTranslate("Application", "Version %1 is available!").arg(settingsPage.latestVersion)
                                        color: Theme.accentDark
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                    }

                                    Item {
                                        width: parent.width
                                        height: 45

                                        Rectangle {
                                            anchors.fill: parent
                                            color: settingsPage.isDownloadingUpdate ? "#3c3d3f" : (downloadBtnMouse.pressed ? Theme.accentDark : downloadBtnMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent)
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
                                                text: settingsPage.isDownloadingUpdate ? qsTranslate("Application", "Downloading... %1%").arg(settingsPage.downloadPercent) : qsTranslate("Application", "Download & Install")
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
                                        text: qsTranslate("Application", "Update downloaded! Restart to apply.")
                                        color: Theme.accentDark
                                        font.family: "Alatsi"
                                        font.pixelSize: 16
                                    }

                                    Item {
                                        width: parent.width
                                        height: 45

                                        Rectangle {
                                            anchors.fill: parent
                                            color: restartBtnMouse.pressed ? Theme.accentDark : restartBtnMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent
                                            radius: 10
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTranslate("Application", "Restart Now")
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
                                    text: qsTranslate("Application", "GitHub Token (Dev Mode)")
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: qsTranslate("Application", "Required for private repos. Leave empty for public repos.")
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
                                            color: saveTokenMouse.pressed ? Theme.accentDark : saveTokenMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent
                                            radius: 10
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTranslate("Application", "Save")
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
                                text: qsTranslate("Application", "About %1").replace("%1", appName)
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                text: appFullName
                                color: "#ffffff"
                                font.family: "Alatsi"
                                font.pixelSize: 16
                            }

                            Text {
                                text: qsTranslate("Application", "A tool for managing, making and applying audio mods to %1.").replace("%1", gameName)
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            Row {
                                spacing: 10

                                Text {
                                    text: qsTranslate("Application", "Version:")
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
                                    text: qsTranslate("Application", "Author:")
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
                                text: qsTranslate("Application", "Credits")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                            Text {
                                    text: qsTranslate("Application", "Some of the awsesome people who made this posible")
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "failsafe65"
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "For making the original audio modding scripts")
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
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "For making PCK extraction and packing scripts which have been used as refrence.")
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
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "For improving on failsafe65's PCK extraction and packing scripts which have been used as reference.")
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
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "For making a free concept ZZZ design which this programs design is based on.")
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
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "For making the first %1 logo design.").replace("%1", appName)
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
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "Maker of Zenless Tools, for making the Chat generator which assets of it where used.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                            Text {
                                text: qsTranslate("Application", "Testers")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "mob159"
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "For helping me out the most during development.")
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
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "For helping me to do some testing and providing feedback.")
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
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "For helping me test the linux build.")
                                    color: '#888888'
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                            Text {
                                text: qsTranslate("Application", "Translators")
                                color: Theme.primaryAccent
                                font.family: "Alatsi"
                                font.pixelSize: 24
                                font.weight: Font.Normal
                            }

                        Column {
                            spacing: 4
                            width: parent.width
                                Text {
                                    text: "Luafile_Gabriel"
                                    color: Theme.primaryAccent
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: qsTranslate("Application", "Spanish translation.")
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
                anchors.margins: 16
                height: 60
                width: 220
                z: 2

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    radius: 30
                    color: saveMouse.containsMouse ? Qt.rgba(Theme.primaryAccent.r, Theme.primaryAccent.g, Theme.primaryAccent.b, 0.25) : "#30000000"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    id: saveButtonBg
                    anchors.fill: parent
                    radius: 30
                    color: saveMouse.pressed ? Theme.accentDark : saveMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent
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
                        text: qsTranslate("Application", "Save Settings")
                        color: "#000000"
                        font.family: "Alatsi"
                        font.pixelSize: 22
                        font.bold: false
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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

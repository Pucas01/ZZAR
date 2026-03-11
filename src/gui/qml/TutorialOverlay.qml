import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: tutorialRoot
    visible: false
    anchors.fill: parent

    property bool modCreationEnabled: false
    property var appRoot: null

    property bool showingIntro: false
    property int currentSection: 0
    property int currentMessageIndex: 0

    signal requestPageChange(int tabIndex)
    signal tutorialFinished()

    property var tutorialData: [
        {
            tabIndex: 1,
            sectionTitle: qsTranslate("Application", "Mod Manager"),
            messages: (appName !== "ZZAR" ? [
                { text: qsTranslate("Application", "Oh hey... looks like i'm in the wrong game."), highlight: "" },
                { text: qsTranslate("Application", "Doesn't matter i know how audio mods work. i trained for this."), highlight: "" },
            ] : []).concat([
                { text: qsTranslate("Application", "You're here. i'll show you how this works."), highlight: "" },
                { text: qsTranslate("Application", "These buttons. use them."), highlight: "tutorialButtonRow" },
                { text: qsTranslate("Application", "This installs %1 mod packages. self explanatory.").replace("%1", modFileExt), highlight: "tutorialInstallBtn" },
                { text: qsTranslate("Application", "This one imports non-%1 mods and converts them.").replace("%1", appName), highlight: "tutorialImportBtn" },
                { text: qsTranslate("Application", "Remove button. select a mod first, then press it."), highlight: "tutorialRemoveBtn" },
                { text: qsTranslate("Application", "When you're done picking mods, apply. nothing happens until you do."), highlight: "tutorialApplyBtn" },
                { text: "", highlight: "tutorialApplyBtn", sticker: "MiyabiMelon.png" },
                { text: qsTranslate("Application", "Oh and if you ever wanted to ask me something, im all ears (DM Pucas01 on Discord, Pucas02 on Twitter or make an issue on the github)."), highlight: "tutorialApplyBtn" },
            ])
        },
        {
            tabIndex: 0,
            sectionTitle: qsTranslate("Application", "GameBanana"),
            messages: [
                { text: qsTranslate("Application", "GameBanana. browse and download mods made by the community."), highlight: "" },
                { text: qsTranslate("Application", "Search by name, or sort by downloads, likes, or newest."), highlight: "tutorialGbToolbar" },
                { text: qsTranslate("Application", "The search bar. type anything."), highlight: "tutorialGbSearch" },
                { text: qsTranslate("Application", "Sort options. default puts %1-native mods first.").replace("%1", appName), highlight: "tutorialGbSort" },
                { text: qsTranslate("Application", "The mod grid. click a card to see details, screenshots, and files."), highlight: "tutorialGbGrid" },
                { text: qsTranslate("Application", "Mods with the %1 badge install directly. others you download and install manually.").replace("%1", appName), highlight: "tutorialGbGrid" },
            ]
        },
        {
            tabIndex: 2,
            sectionTitle: qsTranslate("Application", "Audio Browser"),
            messages: [
                { text: qsTranslate("Application", "Audio Browser. Yanagi's favorite tab, apparently."), highlight: "" },
                { text: qsTranslate("Application", "These tabs switch between music / sfx, and voice audio. pick one."), highlight: "tutorialLangTabs" },
                { text: qsTranslate("Application", "Search bar. type an ID, name, or tag. it finds things."), highlight: "tutorialSearchInput" },
                { text: qsTranslate("Application", "The audio tree. every sound file in the game is in here."), highlight: "tutorialTreeList" },
                { text: qsTranslate("Application", "Open a PCK File then a BNK file and then play a WEM file (WEM files are the audio)."), highlight: "tutorialTreeList" },
                { text: qsTranslate("Application", "Right-click a file to replace it or mute it."), highlight: "tutorialTreeList" },
                { text: qsTranslate("Application", "You can also rename and tag a sound by right-clicking."), highlight: "tutorialTreeList" },
                { text: qsTranslate("Application", "Audio player. play, pause, stop. you've seen one before."), highlight: "tutorialAudioPlayer" },
                { text: qsTranslate("Application", "Got a %1 mod already? import it here if you want to keep editing it.").replace("%1", modFileExt), highlight: "tutorialImportZzarBtn" },
                { text: qsTranslate("Application", "Shows your changes. also where you apply them for in-game testing."), highlight: "tutorialShowChangesBtn" },
                { text: qsTranslate("Application", "Export. packages everything into a %1 mod.").replace("%1", modFileExt), highlight: "tutorialExportBtn" },
                { text: qsTranslate("Application", "Reset. wipes all changes. also required if you have mods enabled in the mod manager."), highlight: "tutorialResetBtn" }
            ]
        },
        {
            tabIndex: 3,
            sectionTitle: qsTranslate("Application", "Audio Conversion"),
            messages: [
                { text: qsTranslate("Application", "Audio Converter. last one."), highlight: "" },
                { text: qsTranslate("Application", "Conversion mode. WEM to WAV, WAV to WEM. pick whichever."), highlight: "tutorialModeCombo" },
                { text: qsTranslate("Application", "Input goes here. file or folder, doesn't matter."), highlight: "tutorialInputField" },
                { text: qsTranslate("Application", "Or just use these."), highlight: "tutorialBrowseRow" },
                { text: qsTranslate("Application", "Output directory. leave it empty and it saves next to the original."), highlight: "tutorialOutputField" },
                { text: qsTranslate("Application", "Sample rate. 48000 is fine. don't change it unless you actually know why."), highlight: "tutorialSampleRate" },
                { text: qsTranslate("Application", "Press convert. done."), highlight: "tutorialConvertBtn" },
                { text: qsTranslate("Application", "..that's everything."), highlight: "" }
            ]
        }
    ]

    function getVisibleSections() {
        if (modCreationEnabled) return tutorialData

        return [tutorialData[0], tutorialData[1]]
    }

    function getCurrentMessage() {
        var sections = getVisibleSections()
        if (currentSection >= sections.length) return null
        var sec = sections[currentSection]
        if (currentMessageIndex >= sec.messages.length) return null
        return sec.messages[currentMessageIndex]
    }

    function getCurrentSection() {
        var sections = getVisibleSections()
        if (currentSection >= sections.length) return null
        return sections[currentSection]
    }

    function getTotalSections() {
        return getVisibleSections().length
    }

    function start() {
        currentSection = 0
        currentMessageIndex = 0
        chatListModel.clear()
        visible = true
        showingIntro = true
        var sndUrl = Qt.resolvedUrl("../assets/" + assetsDir + "/Knock-Knock-audio.wav").toString()
        console.log("[Tutorial] playSound:", sndUrl, "backend:", modManagerBackend)
        if (modManagerBackend) modManagerBackend.playSound(sndUrl)
        knockLoopTimer.restart()
    }

    function answerCall() {
        showingIntro = false
        knockLoopTimer.stop()

        var sec = getCurrentSection()
        if (sec) requestPageChange(sec.tabIndex)

        updateTimer.start()
    }

    function advance() {
        var sections = getVisibleSections()
        var sec = sections[currentSection]

        if (currentMessageIndex < sec.messages.length - 1) {
            currentMessageIndex++
            addCurrentMessageToChat()
            updateSpotlight()
        } else if (currentSection < sections.length - 1) {
            currentSection++
            currentMessageIndex = 0
            chatListModel.clear()

            var nextSec = sections[currentSection]
            requestPageChange(nextSec.tabIndex)

            updateTimer.start()
        } else {
            finish()
        }
    }

    function finish() {
        visible = false
        currentSection = 0
        currentMessageIndex = 0
        chatListModel.clear()
        tutorialFinished()
    }

    function addCurrentMessageToChat() {
        var msg = getCurrentMessage()
        if (msg) {
            chatListModel.append({
                messageText: msg.text || "",
                stickerSource: msg.sticker || ""
            })
            chatListView.positionViewAtEnd()
        }
    }

    Timer {
        id: updateTimer
        interval: 300
        onTriggered: {
            addCurrentMessageToChat()
            updateSpotlight()
        }
    }

    property real spotX: 0
    property real spotY: 0
    property real spotW: 0
    property real spotH: 0
    property bool hasSpotlight: false

    Behavior on spotX { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on spotY { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on spotW { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on spotH { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    function findItemByObjectName(root, name) {
        if (!root) return null
        if (root.objectName === name) return root
        for (var i = 0; i < root.children.length; i++) {
            var found = findItemByObjectName(root.children[i], name)
            if (found) return found
        }
        return null
    }

    function updateSpotlight() {
        var msg = getCurrentMessage()
        if (!msg || !msg.highlight || msg.highlight === "") {
            hasSpotlight = false
            return
        }

        var item = findItemByObjectName(appRoot, msg.highlight)
        if (!item) {
            hasSpotlight = false
            return
        }

        var mapped = item.mapToItem(tutorialRoot, 0, 0)
        var pad = 8
        spotX = mapped.x - pad
        spotY = mapped.y - pad
        spotW = item.width + pad * 2
        spotH = item.height + pad * 2
        hasSpotlight = true
    }

    Rectangle {
        id: topDark
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: hasSpotlight ? spotY : parent.height
        color: "#CC000000"
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: {} }
    }

    Rectangle {
        id: leftDark
        anchors.left: parent.left
        anchors.top: topDark.bottom
        width: hasSpotlight ? spotX : 0
        height: hasSpotlight ? spotH : 0
        color: "#CC000000"
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: {} }
    }

    Rectangle {
        id: rightDark
        anchors.right: parent.right
        anchors.top: topDark.bottom
        width: hasSpotlight ? (parent.width - spotX - spotW) : 0
        height: hasSpotlight ? spotH : 0
        color: "#CC000000"
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: {} }
    }

    Rectangle {
        id: bottomDark
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: hasSpotlight ? (parent.height - spotY - spotH) : 0
        color: "#CC000000"
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: {} }
    }

    Rectangle {
        x: spotX
        y: spotY
        width: spotW
        height: spotH
        color: "transparent"
        border.color: Theme.primaryAccent
        border.width: 2
        radius: 8
        visible: hasSpotlight
        opacity: pulseAnim.running ? pulseAnim._opacity : 1.0

        property real _pulseOpacity: 1.0

        SequentialAnimation {
            id: pulseAnim
            running: hasSpotlight
            loops: Animation.Infinite
            property real _opacity: 1.0

            NumberAnimation { target: pulseAnim; property: "_opacity"; from: 1.0; to: 0.3; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { target: pulseAnim; property: "_opacity"; from: 0.3; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        }

        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    Timer {
        id: knockLoopTimer
        interval: 2345
        repeat: true
        running: showingIntro
        onTriggered: if (modManagerBackend) modManagerBackend.playSound(Qt.resolvedUrl("../assets/" + assetsDir + "/Knock-Knock-audio.wav").toString())
    }

    // Intro screen — shown before tutorial starts
    Rectangle {
        id: introOverlay
        anchors.fill: parent
        color: "#CC000000"
        visible: showingIntro
        z: 100

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.centerIn: parent
            spacing: 28

            Item {
                width: 140
                height: 140
                anchors.horizontalCenter: parent.horizontalCenter
                clip: false

                Image {
                    id: phoneImage
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bobOffset
                    width: 120
                    height: 120
                    source: "../assets/" + assetsDir + "/Knock-Knock.png"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    transformOrigin: Item.Bottom

                    property real bobOffset: 0
                }

                // ZZAR: knock/vibrate animation
                SequentialAnimation {
                    running: showingIntro && appName === "ZZAR"
                    loops: Animation.Infinite
                    // Knock 1 (~0ms)
                    NumberAnimation { target: phoneImage; property: "rotation"; to: -6; duration: 30; easing.type: Easing.OutQuad }
                    NumberAnimation { target: phoneImage; property: "rotation"; to:  6; duration: 35; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: phoneImage; property: "rotation"; to:  0; duration: 25; easing.type: Easing.InQuad }
                    // Gap to knock 2 (~257ms)
                    PauseAnimation { duration: 167 }
                    // Knock 2 (~257ms)
                    NumberAnimation { target: phoneImage; property: "rotation"; to: -6; duration: 30; easing.type: Easing.OutQuad }
                    NumberAnimation { target: phoneImage; property: "rotation"; to:  6; duration: 35; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: phoneImage; property: "rotation"; to:  0; duration: 25; easing.type: Easing.InQuad }
                    // Gap to knock 3 (~925ms)
                    PauseAnimation { duration: 578 }
                    // Knock 3 (~925ms)
                    NumberAnimation { target: phoneImage; property: "rotation"; to: -6; duration: 30; easing.type: Easing.OutQuad }
                    NumberAnimation { target: phoneImage; property: "rotation"; to:  6; duration: 35; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: phoneImage; property: "rotation"; to:  0; duration: 25; easing.type: Easing.InQuad }
                    // Gap to knock 4 (~1167ms)
                    PauseAnimation { duration: 152 }
                    // Knock 4 (~1167ms)
                    NumberAnimation { target: phoneImage; property: "rotation"; to: -6; duration: 30; easing.type: Easing.OutQuad }
                    NumberAnimation { target: phoneImage; property: "rotation"; to:  6; duration: 35; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: phoneImage; property: "rotation"; to:  0; duration: 25; easing.type: Easing.InQuad }
                    // Tail silence to match 2345ms total loop
                    PauseAnimation { duration: 1087 }
                }

                // SRAR: one bob up then settle, badge pops in after
                SequentialAnimation {
                    id: srarIntroAnim
                    running: showingIntro && appName !== "ZZAR"
                    loops: 1
                    // bob up — quick burst
                    NumberAnimation { target: phoneImage; property: "bobOffset"; to: -14; duration: 220; easing.type: Easing.OutQuad }
                    // fall back with gravity + small squash overshoot
                    NumberAnimation { target: phoneImage; property: "bobOffset"; to: 3;   duration: 360; easing.type: Easing.InQuad }
                    NumberAnimation { target: phoneImage; property: "bobOffset"; to: 0;   duration: 160; easing.type: Easing.OutQuad }
                    // brief pause, then badge pops in
                    PauseAnimation { duration: 100 }
                    NumberAnimation { target: notifBadge; property: "badgeScale"; from: 0; to: 1.3; duration: 150; easing.type: Easing.OutBack }
                    NumberAnimation { target: notifBadge; property: "badgeScale"; to: 1.0; duration: 120; easing.type: Easing.InQuad }
                }

                // Notification badge (SRAR only) — positioned relative to Item, outside clip
                Rectangle {
                    id: notifBadge
                    visible: appName !== "ZZAR"
                    width: 30
                    height: 30
                    radius: 13
                    color: "#e8365d"
                    x: parent.width - 26
                    y: 4

                    property real badgeScale: appName !== "ZZAR" ? 0 : 1
                    transform: Scale {
                        origin.x: notifBadge.width / 2
                        origin.y: notifBadge.height / 2
                        xScale: notifBadge.badgeScale
                        yScale: notifBadge.badgeScale
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "1"
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Hoshimi Miyabi"
                color: Theme.primaryAccent
                font.family: "inpin hongmengti"
                font.pixelSize: 18
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                property int dotCount: 0

                Timer {
                    interval: 600
                    running: true
                    repeat: true
                    onTriggered: parent.dotCount = (parent.dotCount + 1) % 3
                }

                Text {
                    text: appName !== "ZZAR" ? qsTranslate("Application", "new message") : qsTranslate("Application", "incoming call")
                    color: "#888888"
                    font.family: "inpin hongmengti"
                    font.pixelSize: 14
                }

                // Fixed-width dot area sized to "..."
                Item {
                    width: callDotRef.implicitWidth
                    height: callDotRef.implicitHeight

                    Text {
                        id: callDotRef
                        visible: false
                        text: "..."
                        font.family: "inpin hongmengti"
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.left: parent.left
                        text: ".".repeat(parent.parent.dotCount + 1)
                        color: "#888888"
                        font.family: "inpin hongmengti"
                        font.pixelSize: 14
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160
                height: 50
                radius: 25
                color: answerMouse.pressed ? Theme.accentDark : (answerMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent)
                scale: answerMouse.pressed ? 0.95 : 1.0
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on scale { NumberAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: appName !== "ZZAR" ? qsTranslate("Application", "Open") : qsTranslate("Application", "Answer")
                    color: "#000000"
                    font.family: "inpin hongmengti"
                    font.pixelSize: 18
                    font.bold: false
                }

                MouseArea {
                    id: answerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: answerCall()
                }
            }
        }
    }

    ListModel {
        id: chatListModel
    }

    property bool chatOnRight: hasSpotlight ? (spotX < tutorialRoot.width / 2) : true
    Behavior on chatOnRight { enabled: false }

    Rectangle {
        id: chatPanel
        width: Math.min(520, tutorialRoot.width * 0.45)
        height: Math.min(600, tutorialRoot.height * 0.75)

        x: chatOnRight ? (tutorialRoot.width - width - 40) : 40
        y: Math.max(40, (tutorialRoot.height - height) / 2)

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#000000" }
            GradientStop { position: 1.0; color: "#201f20" }
        }
        radius: 20
        border.color: "#3c3d3f"
        border.width: 1

        visible: !showingIntro
        opacity: 0
        scale: 0.88

        Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        onVisibleChanged: {
            if (visible) {
                panelEnterAnim.start()
            }
        }

        ParallelAnimation {
            id: panelEnterAnim
            NumberAnimation { target: chatPanel; property: "opacity"; from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }
            NumberAnimation { target: chatPanel; property: "scale";   from: 0.88; to: 1.0; duration: 350; easing.type: Easing.OutBack }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Row {
                width: parent.width
                spacing: 10

                Image {
                    width: 38
                    height: 38
                    source: "../assets/" + assetsDir + "/IconMessageRoleCircle07.png"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 48
                    spacing: 2

                    Text {
                        text: "Hoshimi Miyabi"
                        color: Theme.primaryAccent
                        font.family: "inpin hongmengti"
                        font.pixelSize: 16
                        font.bold: false
                    }

                    Text {
                        text: qsTranslate("Application", "%1 Expert - Chief of Hollow Special Operations Section 6").replace("%1", appName)
                        color: "#888888"
                        font.family: "inpin hongmengti"
                        font.pixelSize: 12
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: getTotalSections()
                    Rectangle {
                        width: index === currentSection ? 24 : 8
                        height: 8
                        radius: 4
                        color: index <= currentSection ? Theme.primaryAccent : "#555555"
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#3c3d3f"
            }

            ListView {
                id: chatListView
                width: parent.width
                height: parent.height - 185
                clip: true
                spacing: 12
                model: chatListModel
                boundsBehavior: Flickable.StopAtBounds

                delegate: Row {
                    width: chatListView.width
                    spacing: 8
                    leftPadding: 4

                    Image {
                        width: 40
                        height: 40
                        source: "../assets/" + assetsDir + "/IconMessageRoleCircle07.png"
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        anchors.top: parent.top
                    }

                    Item {
                        property real maxBubbleWidth: chatListView.width - 52
                        width: maxBubbleWidth
                        height: bubbleRect.height

                        Image {
                            x: -10
                            y: 0
                            width: 14
                            height: 16
                            source: "../assets/" + assetsDir + "/chat_message_arrow_left_.png"
                            fillMode: Image.PreserveAspectFit
                        }

                        Rectangle {
                            id: bubbleRect
                            width: model.stickerSource !== "" ? (stickerImage.width + 20) : Math.min(bubbleText.implicitWidth + 24, parent.maxBubbleWidth)
                            height: model.stickerSource !== "" ? (stickerImage.height + 20) : (bubbleText.height + 20)
                            color: "#ffffff"
                            radius: 15

                            Text {
                                id: bubbleText
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 10
                                width: parent.parent.maxBubbleWidth - 24
                                text: model.messageText
                                color: "#4d4d4d"
                                font.family: "inpin hongmengti"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                visible: model.stickerSource === ""
                            }

                            Image {
                                id: stickerImage
                                anchors.centerIn: parent
                                width: 120
                                height: 120
                                source: model.stickerSource !== "" ? ("../assets/ZZAR/" + model.stickerSource) : ""
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                visible: model.stickerSource !== ""
                            }
                        }
                    }
                }

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                    NumberAnimation { property: "y"; from: 20; duration: 200; easing.type: Easing.OutQuad }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Rectangle {
                    id: nextButton
                    width: parent.width
                    height: 44
                    radius: 22
                    color: nextBtnMouse.pressed ? Theme.accentDark : (nextBtnMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent)
                    scale: nextBtnMouse.pressed ? 0.97 : 1.0
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var sections = getVisibleSections()
                            var sec = sections[currentSection]
                            if (!sec) return qsTranslate("Application", "Got it!")

                            if (currentMessageIndex < sec.messages.length - 1) {
                                return qsTranslate("Application", "Next")
                            } else if (currentSection < sections.length - 1) {
                                return qsTranslate("Application", "Next Page") + " \u2192"
                            } else {
                                return qsTranslate("Application", "Got it!")
                            }
                        }
                        color: "#000000"
                        font.family: "inpin hongmengti"
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: nextBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: advance()
                    }
                }

                Text {
                    text: qsTranslate("Application", "Skip tutorial")
                    color: "#888888"
                    font.family: "inpin hongmengti"
                    font.pixelSize: 12
                    topPadding: 12
                    anchors.horizontalCenter: parent.horizontalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Theme.primaryAccent
                        onExited: parent.color = "#888888"
                        onClicked: finish()
                    }
                }
            }
        }
    }
}

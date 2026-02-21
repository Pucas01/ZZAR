import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: tutorialRoot
    visible: false
    anchors.fill: parent

    property bool modCreationEnabled: false
    property var appRoot: null

    property int currentSection: 0
    property int currentMessageIndex: 0

    signal requestPageChange(int tabIndex)
    signal tutorialFinished()

    property var tutorialData: [
        {
            tabIndex: 0,
            sectionTitle: "Mod Manager",
            messages: [
                { text: "You're here. i'll show you how this works.", highlight: "" },
                { text: "These buttons. use them.", highlight: "tutorialButtonRow" },
                { text: "This installs .zzar mod packages. self explanatory.", highlight: "tutorialInstallBtn" },
                { text: "This one imports non-ZZAR mods and converts them.", highlight: "tutorialImportBtn" },
                { text: "Remove button. select a mod first, then press it.", highlight: "tutorialRemoveBtn" },
                { text: "When you're done picking mods, apply. nothing happens until you do.", highlight: "tutorialApplyBtn" },
                { text: "", highlight: "tutorialApplyBtn", sticker: "MiyabiMelon.png" },
                { text: "Oh and if you ever wanted to ask me something, im all ears (DM Pucas01 on Discord, Pucas02 on Twitter or make an issue on the github).", highlight: "tutorialApplyBtn" },
            ]
        },
        {
            tabIndex: 1,
            sectionTitle: "Audio Browser",
            messages: [
                { text: "Audio Browser. Yanagi's favorite tab, apparently.", highlight: "" },
                { text: "These tabs switch between music / sfx, and voice audio. pick one.", highlight: "tutorialLangTabs" },
                { text: "Search bar. type an ID, name, or tag. it finds things.", highlight: "tutorialSearchInput" },
                { text: "The audio tree. every sound file in the game is in here.", highlight: "tutorialTreeList" },
                { text: "Open a PCK File then a BNK file and then play a WEM file (WEM files are the audio).", highlight: "tutorialTreeList" },
                { text: "Right-click a file to replace it or mute it.", highlight: "tutorialTreeList" },
                { text: "You can also rename and tag a sound by right-clicking.", highlight: "tutorialTreeList" },
                { text: "Audio player. play, pause, stop. you've seen one before.", highlight: "tutorialAudioPlayer" },
                { text: "Got a .zzar mod already? import it here if you want to keep editing it.", highlight: "tutorialImportZzarBtn" },
                { text: "Shows your changes. also where you apply them for in-game testing.", highlight: "tutorialShowChangesBtn" },
                { text: "Export. packages everything into a .zzar mod.", highlight: "tutorialExportBtn" },
                { text: "Reset. wipes all changes. also required if you have mods enabled in the mod manager.", highlight: "tutorialResetBtn" }
            ]
        },
        {
            tabIndex: 2,
            sectionTitle: "Audio Conversion",
            messages: [
                { text: "Audio Converter. last one.", highlight: "" },
                { text: "Conversion mode. WEM to WAV, WAV to WEM. pick whichever.", highlight: "tutorialModeCombo" },
                { text: "Input goes here. file or folder, doesn't matter.", highlight: "tutorialInputField" },
                { text: "Or just use these.", highlight: "tutorialBrowseRow" },
                { text: "Output directory. leave it empty and it saves next to the original.", highlight: "tutorialOutputField" },
                { text: "Sample rate. 48000 is fine. don't change it unless you actually know why.", highlight: "tutorialSampleRate" },
                { text: "Press convert. done.", highlight: "tutorialConvertBtn" },
                { text: "..that's everything.", highlight: "" }
            ]
        }
    ]

    function getVisibleSections() {
        if (modCreationEnabled) return tutorialData
        return [tutorialData[0]]
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

        var sec = getCurrentSection()
        if (sec) {
            requestPageChange(sec.tabIndex)
        }

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
        border.color: "#d8fa00"
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

        Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        // Block clicks from passing through
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
                    source: "../assets/IconMessageRoleCircle07.png"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Hoshimi Miyabi"
                        color: "#d8fa00"
                        font.family: "inpin hongmengti"
                        font.pixelSize: 16
                        font.bold: false
                    }

                    Text {
                        text: "ZZAR Expert - Chief of Hollow Special Operations Section 6"
                        color: "#888888"
                        font.family: "inpin hongmengti"
                        font.pixelSize: 12
                    }
                }

                Item { width: 1; height: 1; Layout.fillWidth: true }
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
                        color: index <= currentSection ? "#d8fa00" : "#555555"
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
                        source: "../assets/IconMessageRoleCircle07.png"
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
                            source: "../assets/chat_message_arrow_left_.png"
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
                                source: model.stickerSource !== "" ? ("../assets/" + model.stickerSource) : ""
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
                    color: nextBtnMouse.pressed ? "#b8de00" : (nextBtnMouse.containsMouse ? "#e8ff33" : "#d8fa00")
                    scale: nextBtnMouse.pressed ? 0.97 : 1.0
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var sections = getVisibleSections()
                            var sec = sections[currentSection]
                            if (!sec) return "Got it!"

                            if (currentMessageIndex < sec.messages.length - 1) {
                                return "Next"
                            } else if (currentSection < sections.length - 1) {
                                return "Next Page \u2192"
                            } else {
                                return "Got it!"
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
                    text: "Skip tutorial"
                    color: "#888888"
                    font.family: "inpin hongmengti"
                    font.pixelSize: 12
                    topPadding: 12
                    anchors.horizontalCenter: parent.horizontalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = "#d8fa00"
                        onExited: parent.color = "#888888"
                        onClicked: finish()
                    }
                }
            }
        }
    }
}

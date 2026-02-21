import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import "../components"
import "."

Item {
    id: audioConversionPage
    objectName: "audioConversionPage"
    clip: true

    signal browseInputFileClicked()
    signal browseInputDirectoryClicked()
    signal browseOutputDirectoryClicked()
    signal convertAudioClicked(int mode, string inputPath, string outputPath, int sampleRate, bool normalize)
    signal normalizeAudioToggled(bool checked)

    property string inputPath: ""
    property string outputPath: ""
    property int currentMode: 0
    property bool converting: false
    property bool normalizeChecked: true
    property string logText: ""

    Rectangle {
        id: outerFrame
        anchors.fill: parent
        anchors.margins: 15
        color: Theme.backgroundColor
        radius: Theme.radiusLarge

        Rectangle {
            id: innerFrame
            anchors.fill: parent
            anchors.margins: 15
            color: Theme.surfaceColor
            radius: Theme.radiusLarge

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingMedium

                Text {
                    text: "Conversion Mode"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                }

                ComboBox {
                    id: modeCombo
                    objectName: "tutorialModeCombo"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.buttonHeightLarge
                    model: [
                        "WEM → WAV",
                        "MP3/FLAC/OGG → WAV",
                        "WAV → WEM"
                    ]
                    currentIndex: currentMode
                    onCurrentIndexChanged: {
                        currentMode = currentIndex
                    }

                    background: Rectangle {
                        color: modeCombo.pressed ? Qt.darker(Theme.cardBackground, 1.2)
                             : modeCombo.hovered ? Qt.lighter(Theme.cardBackground, 1.1)
                             : Theme.cardBackground
                        radius: Theme.radiusMedium
                        border.color: modeCombo.activeFocus ? Theme.primaryAccent : "transparent"
                        border.width: modeCombo.activeFocus ? 2 : 0
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }

                    contentItem: Text {
                        text: modeCombo.displayText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 14
                        rightPadding: 40
                    }

                    indicator: Rectangle {
                        x: modeCombo.width - width - 10
                        y: (modeCombo.height - height) / 2
                        width: 20
                        height: 20
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "▼"
                            color: Theme.textSecondary
                            font.pixelSize: 10
                        }
                    }

                    delegate: ItemDelegate {
                        width: modeCombo.width
                        height: Theme.buttonHeightLarge
                        highlighted: modeCombo.highlightedIndex === index

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
                            text: modelData
                            color: parent.highlighted ? Theme.textOnAccent : Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 14
                        }
                    }

                    popup: Popup {
                        y: modeCombo.height + 4
                        width: modeCombo.width
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
                            model: modeCombo.popup.visible ? modeCombo.delegateModel : null
                            currentIndex: modeCombo.highlightedIndex
                            spacing: 2

                            ScrollIndicator.vertical: ScrollIndicator {
                                active: true
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingSmall
                    visible: currentMode === 1

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 4
                        color: normalizeChecked ? Theme.primaryAccent : Theme.cardBackground
                        border.color: normalizeChecked ? Theme.primaryAccent : Theme.textSecondary
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\u2713"
                            color: Theme.textOnAccent
                            font.pixelSize: 14
                            font.bold: true
                            visible: normalizeChecked
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                normalizeChecked = !normalizeChecked
                                normalizeAudioToggled(normalizeChecked)
                            }
                        }
                    }

                    Text {
                        text: "Normalize Audio"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                normalizeChecked = !normalizeChecked
                                normalizeAudioToggled(normalizeChecked)
                            }
                        }
                    }
                }

                Text {
                    text: "Input"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                    Layout.topMargin: Theme.spacingSmall
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Theme.buttonHeight
                    color: Theme.cardBackground
                    radius: Theme.radiusMedium

                    TextInput {
                        id: inputField
                        objectName: "tutorialInputField"
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        clip: true
                        text: inputPath

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            text: "Select file or directory"
                            visible: !inputField.text && !inputField.activeFocus
                        }
                    }
                }

                RowLayout {
                    objectName: "tutorialBrowseRow"
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    ZZARButton {
                        text: "Browse File"
                        onClicked: browseInputFileClicked()
                    }

                    ZZARButton {
                        text: "Browse Directory"
                        onClicked: browseInputDirectoryClicked()
                    }
                }

                Text {
                    text: "Output Settings"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                    Layout.topMargin: Theme.spacingSmall
                }

                Text {
                    text: "Output Directory:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    Rectangle {
                        Layout.fillWidth: true
                        height: Theme.buttonHeight
                        color: Theme.cardBackground
                        radius: Theme.radiusMedium

                        TextInput {
                            id: outputField
                            objectName: "tutorialOutputField"
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            clip: true
                            text: outputPath

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                text: "Auto (same as input)"
                                visible: !outputField.text && !outputField.activeFocus
                            }
                        }
                    }

                    ZZARButton {
                        text: "Browse"
                        onClicked: browseOutputDirectoryClicked()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    Text {
                        text: "Sample Rate (Hz):"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    ComboBox {
                        id: sampleRateCombo
                        objectName: "tutorialSampleRate"
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: Theme.buttonHeight
                        model: ["44100", "48000", "96000"]
                        currentIndex: 1

                        background: Rectangle {
                            color: sampleRateCombo.pressed ? Qt.darker(Theme.cardBackground, 1.2)
                                 : sampleRateCombo.hovered ? Qt.lighter(Theme.cardBackground, 1.1)
                                 : Theme.cardBackground
                            radius: Theme.radiusMedium
                            border.color: "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }

                        contentItem: Text {
                            text: sampleRateCombo.displayText
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 14
                            rightPadding: 40
                        }

                        indicator: Rectangle {
                            x: sampleRateCombo.width - width - 10
                            y: (sampleRateCombo.height - height) / 2
                            width: 20
                            height: 20
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "▼"
                                color: Theme.textPrimary
                                font.pixelSize: 10
                            }
                        }

                        delegate: ItemDelegate {
                            width: sampleRateCombo.width - 8
                            height: Theme.buttonHeight
                            highlighted: sampleRateCombo.highlightedIndex === index

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
                                text: modelData
                                color: parent.highlighted ? Theme.textOnAccent : Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 14
                            }
                        }

                        popup: Popup {
                            y: sampleRateCombo.height + 4
                            width: sampleRateCombo.width
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
                                model: sampleRateCombo.popup.visible ? sampleRateCombo.delegateModel : null
                                currentIndex: sampleRateCombo.highlightedIndex
                                spacing: 2

                                ScrollIndicator.vertical: ScrollIndicator {
                                    active: true
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                ZZARButton {
                    objectName: "tutorialConvertBtn"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.buttonHeightLarge
                    text: converting ? "Converting..." : "Convert Audio"
                    enabled: !converting && inputPath !== ""
                    buttonColor: enabled ? Theme.primaryAccent : Theme.disabledAccent
                    fontSize: Theme.fontSizeNormal
                    onClicked: {
                        convertAudioClicked(
                            currentMode,
                            inputField.text,
                            outputField.text,
                            parseInt(sampleRateCombo.currentText),
                            normalizeChecked
                        )
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    color: Theme.cardBackground
                    radius: 4
                    visible: converting

                    Rectangle {
                        id: progressBar
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.5
                        color: Theme.primaryAccent
                        radius: 4

                        SequentialAnimation on width {
                            running: converting
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 0
                                to: progressBar.parent.width
                                duration: 1500
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }

                Text {
                    text: "Log:"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 120
                    color: Theme.surfaceDark
                    radius: Theme.radiusMedium

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingSmall
                        clip: true

                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        TextEdit {
                            id: logTextEdit
                            width: parent.width
                            text: logText
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true

                            Text {
                                anchors.centerIn: parent
                                text: "Conversion log will appear here..."
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                visible: logTextEdit.text === ""
                            }
                        }
                    }
                }
            }
        }
    }

    function setInputPath(path) {
        inputPath = path
        inputField.text = path
    }

    function setOutputPath(path) {
        outputPath = path
        outputField.text = path
    }

    function setConvertingState(isConverting) {
        converting = isConverting
    }

    function appendLog(message) {
        if (logText === "") {
            logText = message
        } else {
            logText += "\n" + message
        }
    }

    function clearLog() {
        logText = ""
    }
}

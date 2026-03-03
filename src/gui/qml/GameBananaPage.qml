import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import "."

Item {
    id: gameBananaPage
    objectName: "gameBananaPage"

    property bool isLoading: false
    property var modsList: []

    signal loadModsRequested(int page, string sort)
    signal modCardClicked(int modId)
    signal refreshRequested()
    signal downloadModRequested(string downloadUrl, string filename, string modName)

    function onModsLoaded(mods) {
        modsList = mods
        isLoading = false
    }

    function onModDetailsLoaded(details) {

        if (details && details.thumbnail) {
            var newList = modsList.slice()
            for (var i = 0; i < newList.length; i++) {
                if (newList[i].id === details.id && !newList[i].thumbnail) {
                    newList[i] = Object.assign({}, newList[i], { thumbnail: details.thumbnail })
                    modsList = newList
                    break
                }
            }
        }
        modDialog.showModDetails(details)
        isLoading = false
    }

    function setLoadingState(loading) {
        isLoading = loading
    }

    function onDownloadProgress(progress) {
        modDialog.setDownloadProgress(progress)
    }

    function onThumbnailUpdated(modId, thumbnailUrl) {
        var newList = modsList.slice()
        for (var i = 0; i < newList.length; i++) {
            if (newList[i].id === modId) {
                newList[i] = Object.assign({}, newList[i], { thumbnail: thumbnailUrl })
                modsList = newList
                return
            }
        }
    }

    Rectangle {
        id: outerFrame
        anchors.fill: parent
        anchors.margins: 15
        color: Theme.backgroundColor
        radius: 36.44

        Rectangle {
            id: innerFrame
            anchors.fill: parent
            anchors.margins: 15
            color: Theme.surfaceColor
            radius: 36.44

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: 12

                Flow {
                    id: toolbar
                    Layout.fillWidth: true
                    spacing: 10

                    Item {
                        height: Theme.buttonHeight
                        width: 260

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.cardBackground
                            radius: Theme.radiusMedium

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: Theme.spacingSmall

                                Text {
                                    text: "\uf002"
                                    color: Theme.textTertiary
                                    font.pixelSize: 14
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    color: Theme.textOnAccent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeNormal
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    clip: true

                                    Text {
                                        anchors.fill: parent
                                        text: "Search mods..."
                                        color: Theme.textTertiary
                                        font: searchInput.font
                                        verticalAlignment: Text.AlignVCenter
                                        visible: !searchInput.text && !searchInput.activeFocus
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        height: Theme.buttonHeight
                        width: sortComboContent.implicitWidth + 40

                        Rectangle {
                            anchors.fill: parent
                            color: sortComboMouse.pressed ? Qt.darker(Theme.cardBackground, 1.2)
                                 : sortComboMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.1)
                                 : Theme.cardBackground
                            radius: Theme.radiusMedium
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                id: sortComboContent
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Sort: " + sortComboBox.currentText
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u25BC"
                                color: Theme.textPrimary
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: sortComboMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sortComboBox.popup.open()
                        }

                        ComboBox {
                            id: sortComboBox
                            anchors.fill: parent
                            opacity: 0
                            model: ["Default", "Most Downloaded", "Most Liked", "Newest"]

                            onCurrentIndexChanged: {
                                var sortMap = { 0: "default", 1: "downloads", 2: "likes", 3: "date" }
                                loadModsRequested(1, sortMap[currentIndex])
                            }

                            popup: Popup {
                                y: sortComboBox.height + 4
                                width: sortComboBox.width
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
                                    model: sortComboBox.popup.visible ? sortComboBox.delegateModel : null
                                    currentIndex: sortComboBox.highlightedIndex
                                    spacing: 2
                                }
                            }

                            delegate: ItemDelegate {
                                width: sortComboBox.width - 8
                                height: Theme.buttonHeight

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
                        }
                    }

                    Item {
                        height: Theme.buttonHeight
                        width: refreshBtnRow.implicitWidth + 32

                        Rectangle {
                            anchors.fill: parent
                            color: refreshMouse.pressed ? "#a8c800" : refreshMouse.containsMouse ? "#e8ff33" : Theme.primaryAccent
                            radius: Theme.radiusMedium
                            scale: refreshMouse.pressed ? 0.95 : 1.0
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }
                        }

                        Row {
                            id: refreshBtnRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                id: refreshIcon
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u21BB"
                                color: Theme.textOnAccent
                                font.pixelSize: 16

                                RotationAnimation on rotation {
                                    from: 0; to: 360
                                    duration: 900
                                    running: isLoading
                                    loops: Animation.Infinite
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Refresh"
                                color: Theme.textOnAccent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeNormal
                            }
                        }

                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: refreshRequested()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingMedium
                        visible: isLoading && modsList.length === 0

                        Item {
                            width: 56
                            height: 56
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 28
                                color: "transparent"
                                border.color: Theme.primaryAccent
                                border.width: 4

                                RotationAnimation on rotation {
                                    from: 0; to: 360
                                    duration: 1200
                                    running: isLoading
                                    loops: Animation.Infinite
                                }

                                Rectangle {
                                    width: 10; height: 10
                                    radius: 5
                                    color: Theme.primaryAccent
                                    x: parent.width / 2 - 5
                                    y: 0
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Loading mods..."
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: !isLoading && modsList.length === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No mods found"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamilyTitle
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Try refreshing or check your connection"
                            color: "#888888"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Flickable {
                        id: gridFlickable
                        anchors.fill: parent
                        visible: !isLoading || modsList.length > 0
                        clip: true
                        contentHeight: gridFlow.height
                        boundsBehavior: Flickable.DragOverBounds
                        flickDeceleration: 5000
                        maximumFlickVelocity: 2500

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 8

                            contentItem: Rectangle {
                                radius: 4
                                color: parent.pressed ? Theme.primaryAccent : "#555555"
                            }
                        }

                        Flow {
                            id: gridFlow
                            width: parent.width - 12
                            spacing: 16

                            Repeater {
                                model: modsList

                                Item {
                                    width: 240
                                    height: 300

                                    Rectangle {
                                        id: cardBg
                                        anchors.fill: parent
                                        color: cardMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.1) : Theme.cardBackground
                                        radius: Theme.radiusMedium
                                        scale: cardMouse.pressed ? 0.97 : 1.0

                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: cardBg.width
                                                height: cardBg.height
                                                radius: Theme.radiusMedium
                                            }
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 0

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 160
                                                color: "#444444"

                                                Image {
                                                    anchors.fill: parent
                                                    source: modelData.thumbnail || ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                                                        color: "#888888"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 48
                                                        visible: parent.status !== Image.Ready
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                Layout.margins: 12
                                                spacing: 4

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name || "Unknown Mod"
                                                    color: Theme.textOnAccent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeNormal
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WordWrap
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "by " + (modelData.author || "Unknown")
                                                    color: Theme.textTertiary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    elide: Text.ElideRight
                                                }

                                                Item { Layout.fillHeight: true }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 10

                                                    Text {
                                                        text: "\u2665 " + (modelData.likes || "0")
                                                        color: Theme.textTertiary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                    }

                                                    Text {
                                                        text: "\u2193 " + (modelData.downloads || "0")
                                                        color: Theme.textTertiary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                    }

                                                    Item { Layout.fillWidth: true }

                                                    Rectangle {
                                                        height: 20
                                                        width: catLabel.implicitWidth + 14
                                                        color: Theme.primaryAccent
                                                        radius: 10

                                                        Text {
                                                            id: catLabel
                                                            anchors.centerIn: parent
                                                            text: modelData.category || "Mod"
                                                            color: Theme.textOnAccent
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 10
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.radiusMedium
                                            color: "transparent"
                                            border.color: Theme.primaryAccent
                                            border.width: 2
                                            opacity: cardMouse.containsMouse ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                        }

                                        MouseArea {
                                            id: cardMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modCardClicked(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    GameBananaModDialog {
        id: modDialog
        onDownloadRequested: {
            downloadModRequested(downloadUrl, filename, modName)
        }
    }
}

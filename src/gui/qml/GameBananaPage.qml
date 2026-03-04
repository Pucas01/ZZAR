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
    property var installedModIds: []
    property int sortIndex: 0

    property var sortedModsList: {
        var list = modsList.slice()
        if (sortIndex === 0) list.sort(function(a, b) {
            var zzarDiff = (b.zzar_supported ? 1 : 0) - (a.zzar_supported ? 1 : 0)
            if (zzarDiff !== 0) return zzarDiff
            return (b.date_added || 0) - (a.date_added || 0)
        })
        else if (sortIndex === 1) list.sort(function(a, b) { return (b.downloads || 0) - (a.downloads || 0) })
        else if (sortIndex === 2) list.sort(function(a, b) { return (b.likes || 0) - (a.likes || 0) })
        else if (sortIndex === 3) list.sort(function(a, b) { return (b.date_added || 0) - (a.date_added || 0) })
        return list
    }

    signal loadModsRequested(int page, string sort)
    signal modCardClicked(int modId)
    signal refreshRequested()
    signal downloadModRequested(string downloadUrl, string filename, string modName, int modId)
    signal installChosenZZARRequested(string zipPath, string zzarName)

    function onModsLoaded(mods) {
        modsList = mods
        isLoading = false
        installedModIds = gameBananaBackend.getInstalledModIds()
        modDialog.installedModNames = gameBananaBackend.getInstalledModNames()
        modDialog.installedUrlMap = gameBananaBackend.getInstalledUrlMap()
        modDialog.installedVersion += 1
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
        modDialog.installedModNames = gameBananaBackend.getInstalledModNames()
        modDialog.installedUrlMap = gameBananaBackend.getInstalledUrlMap()
        modDialog.installedVersion += 1
        installedModIds = gameBananaBackend.getInstalledModIds()
        modDialog.showModDetails(details)
        isLoading = false
    }

    function onInstalledModsChanged(names) {
        modDialog.installedModNames = names
        modDialog.installedUrlMap = gameBananaBackend.getInstalledUrlMap()
        modDialog.installedVersion += 1
        installedModIds = gameBananaBackend.getInstalledModIds()
    }

    function setLoadingState(loading) {
        isLoading = loading
    }

    function onDownloadProgress(progress) {
        modDialog.setDownloadProgress(progress)
    }

    function setInstallState(installing) {
        modDialog.setInstallState(installing)
    }

    function showZZARChooser(names, zipPath) {
        modDialog.showZZARChooser(names, zipPath)
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

    function onDownloadCountUpdated(modId, downloads) {
        var newList = modsList.slice()
        for (var i = 0; i < newList.length; i++) {
            if (newList[i].id === modId) {
                newList[i] = Object.assign({}, newList[i], { downloads: downloads })
                modsList = newList
                return
            }
        }
    }

    function onZZARSupportUpdated(modId, supported) {
        var newList = modsList.slice()
        for (var i = 0; i < newList.length; i++) {
            if (newList[i].id === modId) {
                newList[i] = Object.assign({}, newList[i], { zzar_supported: supported })
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

                    ComboBox {
                        id: sortComboBox
                        height: Theme.buttonHeight
                        model: ["Default", "Most Downloaded", "Most Liked", "Newest"]

                        onActivated: sortIndex = index

                        background: Rectangle {
                            color: sortComboBox.pressed ? Qt.darker(Theme.cardBackground, 1.2)
                                 : sortComboBox.hovered ? Qt.lighter(Theme.cardBackground, 1.1)
                                 : Theme.cardBackground
                            radius: Theme.radiusMedium
                            border.color: "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        contentItem: Text {
                            text: "Sort: " + sortComboBox.displayText
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 14
                            rightPadding: 40
                        }

                        indicator: Rectangle {
                            x: sortComboBox.width - width - 10
                            y: (sortComboBox.height - height) / 2
                            width: 20; height: 20
                            color: "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "\u25BC"
                                color: Theme.textPrimary
                                font.pixelSize: 10
                            }
                        }

                        delegate: ItemDelegate {
                            width: sortComboBox.width - 8
                            height: Theme.buttonHeight
                            highlighted: sortComboBox.highlightedIndex === index

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

                                ScrollIndicator.vertical: ScrollIndicator { active: true }
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
                                model: sortedModsList

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

                                                Rectangle {
                                                    anchors.top: parent.top
                                                    anchors.left: parent.left
                                                    anchors.margins: 8
                                                    height: 22
                                                    width: zzarBadgeLabel.implicitWidth + 14
                                                    radius: Theme.radiusMedium
                                                    color: Theme.primaryAccent
                                                    visible: modelData.zzar_supported === true

                                                    Text {
                                                        id: zzarBadgeLabel
                                                        anchors.centerIn: parent
                                                        text: "ZZAR Native"
                                                        color: Theme.textOnAccent
                                                        font.family: Theme.fontFamilyTitle
                                                        font.pixelSize: 10
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.margins: 8
                                                    height: 22
                                                    width: installedCardBadgeLabel.implicitWidth + 14
                                                    radius: Theme.radiusMedium
                                                    color: Theme.primaryAccent
                                                    visible: gameBananaPage.installedModIds.indexOf(modelData.id) !== -1

                                                    Text {
                                                        id: installedCardBadgeLabel
                                                        anchors.centerIn: parent
                                                        text: "Installed"
                                                        color: Theme.textOnAccent
                                                        font.family: Theme.fontFamilyTitle
                                                        font.pixelSize: 10
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
            downloadModRequested(downloadUrl, filename, modName, modId)
        }
        onInstallChosenZZAR: {
            installChosenZZARRequested(zipPath, zzarName)
        }
    }
}

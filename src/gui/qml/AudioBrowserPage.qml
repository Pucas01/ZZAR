import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import "../components"
import "."

Item {
    id: audioBrowser
    objectName: "audioBrowserPage"
    clip: true

    function getMainWindow() {
        var item = audioBrowser
        while (item.parent) {
            item = item.parent
        }
        return item
    }

    signal languageTabChanged(int index)
    signal searchRequested(string query)
    signal clearSearchClicked()
    signal findMatchingSoundClicked()
    signal mergeWemToggled(bool checked)
    signal hideUselessPckToggled(bool checked)
    signal normalizeAudioToggled(bool checked)
    signal treeItemExpanded(string itemId, string itemType)

    signal treeItemDoubleClicked(string itemId, string itemType, string pckPath)
    signal treeItemRightClicked(string itemId, string itemType, string pckPath, real x, real y)
    signal tagSoundRequested(string itemId, string itemType, string pckPath)
    signal importZzarForEditingClicked()
    signal showChangesClicked()
    signal applyChangesClicked()
    signal exportModClicked()
    signal createModPackageRequested(string name, string author, string version, string description, string thumbnailPath)
    signal resetAllClicked()
    signal removeChangeRequested(string pckFile, string fileId)
    signal navigateToChangeClicked(string pckFile, string fileId, string itemType, string bnkId)
    signal playReplacementClicked(string wemPath)
    signal playClicked()
    signal pauseClicked()
    signal stopClicked()
    signal volumeAdjusted(int value)
    signal seekRequested(real position)
    signal wipDialogRequested()
    signal openAudioFolderClicked(string folderType)

    property real contextMenuX: 0
    property real contextMenuY: 0
    property string gameDirectory: ""
    property string statusText: "Select a game audio directory to start"
    property string nowPlayingText: "Not playing"
    property real playbackProgress: 0.0
    property string timeText: "00:00 / 00:00"
    property int volume: 50
    property bool isPlaying: false
    property bool isPaused: false
    property bool playbackEnabled: false
    property bool mergeWemChecked: true
    property bool hideUselessPckChecked: true
    property bool normalizeAudioChecked: true
    property string highlightItemId: ""
    property int changesCount: 0

    property string highlightPckPath: ""
    property bool sortBySizeAsc: false
    property bool sortByDurationAsc: false

    ListModel { id: languageTabsModel }
    ListModel { id: treeModel }

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
                spacing: Theme.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall
                    visible: languageTabsModel.count > 0

                    Row {
                        id: langTabs
                        objectName: "tutorialLangTabs"
                        spacing: Theme.spacingSmall

                        property int currentIndex: 0

                        Repeater {
                            model: languageTabsModel

                            Item {
                                height: Theme.buttonHeight
                                width: tabLabel.implicitWidth + 28

                                Rectangle {
                                    anchors.fill: parent
                                    color: {
                                        var active = langTabs.currentIndex === index
                                        if (active) return Theme.primaryAccent
                                        return tabMouse.pressed ? Qt.darker(Theme.cardBackground, 1.1)
                                             : tabMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.1)
                                             : Theme.cardBackground
                                    }
                                    radius: Theme.radiusMedium
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: model.label
                                    color: langTabs.currentIndex === index ? Theme.textOnAccent : Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                MouseArea {
                                    id: tabMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        langTabs.currentIndex = index
                                        languageTabChanged(index)
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ComboBox {
                        id: openFolderCombo
                        visible: gameDirectory !== ""
                        implicitWidth: findMatchingSoundBtn.width
                        Layout.preferredHeight: Theme.buttonHeight
                        model: ["StreamingAssets", "Persistent"]
                        displayText: "Open Game Folder"
                        z: 100

                        onActivated: {
                            var folderType = index === 0 ? "streaming" : "persistent"
                            openAudioFolderClicked(folderType)
                        }

                        background: Rectangle {
                            color: openFolderCombo.pressed ? Qt.darker(Theme.primaryAccent, 1.1)
                                 : openFolderCombo.hovered ? Qt.lighter(Theme.primaryAccent, 1.1)
                                 : Theme.primaryAccent
                            radius: Theme.radiusMedium
                            Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                            scale: openFolderCombo.pressed ? 0.97 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: Theme.animationDuration; easing.type: Theme.easingStandard }
                            }
                        }

                        contentItem: Text {
                            text: openFolderCombo.displayText
                            color: Theme.textOnAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 24
                            rightPadding: 20
                        }

                        indicator: Rectangle {
                            x: openFolderCombo.width - width - 10
                            y: (openFolderCombo.height - height) / 2
                            width: 20
                            height: 20
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\u25BC"
                                color: Theme.textOnAccent
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse.accepted = false
                        }

                        delegate: ItemDelegate {
                            width: openFolderCombo.width - 8
                            height: Theme.buttonHeight
                            highlighted: openFolderCombo.highlightedIndex === index

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
                            y: openFolderCombo.height + 4
                            width: openFolderCombo.width
                            padding: 4
                            z: 200

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
                                model: openFolderCombo.popup.visible ? openFolderCombo.delegateModel : null
                                currentIndex: openFolderCombo.highlightedIndex
                                spacing: 2

                                ScrollIndicator.vertical: ScrollIndicator {
                                    active: true
                                }
                            }
                        }
                    }
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
                            id: searchInput
                            objectName: "tutorialSearchInput"
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            clip: true

                            Keys.onReturnPressed: searchRequested(text)

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                text: "Search by ID, name, or tag"
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }
                    }

                    ZZARButton {
                        text: "Search"
                        onClicked: searchRequested(searchInput.text)
                    }
                    ZZARButton {
                        text: "Clear"
                        onClicked: {
                            searchInput.text = ""
                            clearSearchClicked()
                        }
                    }
                    ZZARButton {
                        id: findMatchingSoundBtn
                        text: "Find Matching Sound"
                        buttonColor: Theme.secondaryAccent
                        onClicked: wipDialogRequested()
                    }
                }

                Row {
                    spacing: Theme.spacingLarge

                    Row {
                        spacing: Theme.spacingSmall

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: mergeWemChecked ? Theme.primaryAccent : Theme.cardBackground
                            border.color: mergeWemChecked ? Theme.primaryAccent : Theme.textSecondary
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: Theme.textOnAccent
                                font.pixelSize: 14
                                font.bold: true
                                visible: mergeWemChecked
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mergeWemChecked = !mergeWemChecked
                                    mergeWemToggled(mergeWemChecked)
                                }
                            }
                        }

                        Text {
                            text: "Merge Streaming PCK"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mergeWemChecked = !mergeWemChecked
                                    mergeWemToggled(mergeWemChecked)
                                }
                            }
                        }
                    }

                    Row {
                        spacing: Theme.spacingSmall

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: hideUselessPckChecked ? Theme.primaryAccent : Theme.cardBackground
                            border.color: hideUselessPckChecked ? Theme.primaryAccent : Theme.textSecondary
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: Theme.textOnAccent
                                font.pixelSize: 14
                                font.bold: true
                                visible: hideUselessPckChecked
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    hideUselessPckChecked = !hideUselessPckChecked
                                    hideUselessPckToggled(hideUselessPckChecked)
                                }
                            }
                        }

                        Text {
                            text: "Hide all non soundbank language PCK's"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    hideUselessPckChecked = !hideUselessPckChecked
                                    hideUselessPckToggled(hideUselessPckChecked)
                                }
                            }
                        }
                    }

                    Row {
                        spacing: Theme.spacingSmall

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: normalizeAudioChecked ? Theme.primaryAccent : Theme.cardBackground
                            border.color: normalizeAudioChecked ? Theme.primaryAccent : Theme.textSecondary
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: Theme.textOnAccent
                                font.pixelSize: 14
                                font.bold: true
                                visible: normalizeAudioChecked
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    normalizeAudioChecked = !normalizeAudioChecked
                                    normalizeAudioToggled(normalizeAudioChecked)
                                }
                            }
                        }

                        Text {
                            text: "Normalize Audio on Replace"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    normalizeAudioChecked = !normalizeAudioChecked
                                    normalizeAudioToggled(normalizeAudioChecked)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.surfaceDark
                    radius: Theme.radiusMedium

                    Row {
                        id: treeHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingSmall
                        height: 28
                        spacing: 0

                        Text {
                            width: parent.width * 0.42
                            text: "File"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: parent.width * 0.13
                            text: "ID"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                        Rectangle {
                            width: parent.width * 0.15
                            height: parent.height
                            color: sizeHeaderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                            Text {
                                anchors.fill: parent
                                text: "Size " + (sortBySizeAsc ? "\u25B2" : "\u25BC")
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: sizeHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    sortBySizeAsc = !sortBySizeAsc
                                    sortTreeBySize()
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width * 0.13
                            height: parent.height
                            color: durationHeaderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                            Text {
                                anchors.fill: parent
                                text: "Duration " + (sortByDurationAsc ? "\u25B2" : "\u25BC")
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: durationHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    sortByDurationAsc = !sortByDurationAsc
                                    sortTreeByDuration()
                                }
                            }
                        }
                        Text {
                            width: parent.width * 0.17
                            text: "Type"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle {
                        id: headerSep
                        anchors.top: treeHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spacingSmall
                        anchors.rightMargin: Theme.spacingSmall
                        height: 1
                        color: Theme.textSecondary
                        opacity: 0.3
                    }

                    ListView {
                        id: treeList
                        objectName: "tutorialTreeList"
                        anchors.top: headerSep.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingSmall
                        anchors.topMargin: 4
                        clip: true
                        model: treeModel
                        boundsBehavior: Flickable.DragOverBounds
                        flickDeceleration: 5000
                        maximumFlickVelocity: 2500

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No audio files loaded.\nSelect a game directory to browse."
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            horizontalAlignment: Text.AlignHCenter
                            visible: treeModel.count === 0
                        }

                        delegate: Rectangle {
                            id: treeItem
                            width: treeList.width
                            height: 30
                            property bool isHighlighted: highlightItemId !== "" && model.itemId === highlightItemId && model.pckPath === highlightPckPath
                            color: isHighlighted ? Qt.rgba(Theme.primaryAccent.r, Theme.primaryAccent.g, Theme.primaryAccent.b, 0.25)
                                 : itemMouse.containsMouse ? Qt.lighter(Theme.surfaceDark, 1.4) : "transparent"
                            radius: 4
                            Behavior on color { ColorAnimation { duration: 80 } }

                            property bool expanded: model.expanded || false
                            property int depth: model.depth || 0

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingSmall + (depth * 20)
                                spacing: 0

                                Text {
                                    width: 20
                                    height: parent.height
                                    text: model.hasChildren ? (treeItem.expanded ? "\u25BC" : "\u25B6") : ""
                                    color: Theme.textSecondary
                                    font.pixelSize: 10
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    width: (treeList.width - 20 - depth * 20) * 0.42
                                    height: parent.height
                                    text: {

                                        if (model.itemType && model.itemType.indexOf("WEM") !== -1 && model.tags && model.tags !== "") {
                                            return model.tags
                                        }
                                        return model.fileName || ""
                                    }
                                    color: model.isModified ? Theme.primaryAccent : Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: (treeList.width - 20 - depth * 20) * 0.13
                                    height: parent.height
                                    text: model.itemId || ""
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: (treeList.width - 20 - depth * 20) * 0.15
                                    height: parent.height
                                    text: model.fileSize || ""
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    width: (treeList.width - 20 - depth * 20) * 0.13
                                    height: parent.height
                                    text: model.duration || ""
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    width: (treeList.width - 20 - depth * 20) * 0.17
                                    height: parent.height
                                    text: model.itemType || ""
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor

                                onDoubleClicked: {
                                    treeItemDoubleClicked(model.itemId, model.itemType, model.pckPath || "")
                                }
                                onClicked: {
                                    if (mouse.button === Qt.RightButton) {
                                        var isWem = model.itemType.indexOf("WEM") !== -1
                                        if (isWem) {
                                            contextMenu.contextItemId = model.itemId
                                            contextMenu.contextItemType = model.itemType
                                            contextMenu.contextPckPath = model.pckPath || ""

                                            var pos = itemMouse.mapToItem(audioBrowser, mouse.x, mouse.y)
                                            contextMenuX = pos.x
                                            contextMenuY = pos.y
                                            contextMenu.visible = true
                                        }
                                    } else if (mouse.button === Qt.LeftButton && (model.hasChildren || false)) {

                                        treeItem.expanded = !treeItem.expanded
                                        treeModel.setProperty(index, "expanded", treeItem.expanded)
                                        if (treeItem.expanded) {
                                            if (model.itemType === "PCK") {
                                                audioBrowserBackend.expandPckItem(model.pckPath)
                                            } else {
                                                treeItemExpanded(model.itemId, model.itemType)
                                            }
                                        } else {

                                            var parentDepth = model.depth || 0
                                            var removeStart = index + 1
                                            var removeCount = 0
                                            while (removeStart + removeCount < treeModel.count &&
                                                   (treeModel.get(removeStart + removeCount).depth || 0) > parentDepth) {
                                                removeCount++
                                            }
                                            if (removeCount > 0) {
                                                treeModel.remove(removeStart, removeCount)
                                            }

                                            var collapseId = model.itemType === "PCK" ? model.pckPath : model.itemId
                                            audioBrowserBackend.onItemCollapsed(collapseId, model.itemType)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    QtObject {
                        id: contextMenu
                        property string contextItemId: ""
                        property string contextItemType: ""
                        property string contextPckPath: ""
                        property bool visible: false
                        function close() { visible = false }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    ZZARButton {
                        objectName: "tutorialImportZzarBtn"
                        text: "Import .zzar for Editing"
                        buttonColor: Theme.primaryAccent
                        onClicked: importZzarForEditingClicked()
                    }
                    ZZARButton {
                        objectName: "tutorialShowChangesBtn"
                        text: changesCount > 0 ? "Show Changes (" + changesCount + ")" : "Show Changes"
                        onClicked: showChangesClicked()
                    }
                    ZZARButton {
                        objectName: "tutorialExportBtn"
                        text: "Export as Mod Package"
                        onClicked: exportModClicked()
                    }
                    ZZARButton {
                        objectName: "tutorialResetBtn"
                        text: "Reset All Changes"
                        buttonColor: Theme.disabledAccent
                        textColor: Theme.textPrimary
                        onClicked: resetAllClicked()
                    }
                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    objectName: "tutorialAudioPlayer"
                    Layout.fillWidth: true
                    height: 100
                    color: Theme.surfaceDark
                    radius: Theme.radiusMedium

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingSmall
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Text {
                                text: nowPlayingText
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.italic: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            ZZARButton {
                                text: "\u25B6 Play"
                                enabled: playbackEnabled
                                buttonColor: enabled ? Theme.primaryAccent : Theme.disabledAccent
                                onClicked: playClicked()
                            }
                            ZZARButton {
                                text: "\u23F8 Pause"
                                enabled: isPlaying
                                buttonColor: enabled ? Theme.primaryAccent : Theme.disabledAccent
                                onClicked: pauseClicked()
                            }
                            ZZARButton {
                                text: "\u23F9 Stop"
                                enabled: isPlaying || isPaused
                                buttonColor: enabled ? Theme.primaryAccent : Theme.disabledAccent
                                onClicked: stopClicked()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Slider {
                                id: progressSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 1.0
                                value: playbackProgress
                                onMoved: seekRequested(value)

                                background: Rectangle {
                                    x: progressSlider.leftPadding
                                    y: progressSlider.bottomPadding + progressSlider.availableHeight / 2 - height / 2
                                    width: progressSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: Theme.cardBackground

                                    Rectangle {
                                        width: progressSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 2
                                        color: Theme.primaryAccent
                                    }
                                }
                                handle: Rectangle {
                                    x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                                    y: progressSlider.bottomPadding + progressSlider.availableHeight / 2 - height / 2
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: progressSlider.pressed ? Qt.darker(Theme.primaryAccent, 1.1) : Theme.primaryAccent
                                }
                            }

                            Text {
                                text: timeText
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.preferredWidth: 100
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Text {
                                text: "Volume:"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Slider {
                                id: volumeSlider
                                Layout.preferredWidth: 150
                                from: 0
                                to: 100
                                value: volume
                                onMoved: {
                                    volume = value
                                    volumeAdjusted(value)
                                }

                                background: Rectangle {
                                    x: volumeSlider.leftPadding
                                    y: volumeSlider.bottomPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: volumeSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: Theme.cardBackground

                                    Rectangle {
                                        width: volumeSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 2
                                        color: Theme.primaryAccent
                                    }
                                }
                                handle: Rectangle {
                                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                    y: volumeSlider.bottomPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: volumeSlider.pressed ? Qt.darker(Theme.primaryAccent, 1.1) : Theme.primaryAccent
                                }
                            }

                            Text {
                                text: Math.round(volumeSlider.value) + "%"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.preferredWidth: 40
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                Text {
                    text: statusText
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }

    function setGameDirectory(path) {
        gameDirectory = path
    }

    function setLanguageTabs(tabs) {
        var previousIndex = langTabs.currentIndex
        var previousLabel = ""
        if (previousIndex >= 0 && previousIndex < languageTabsModel.count) {
            previousLabel = languageTabsModel.get(previousIndex).label
        }

        languageTabsModel.clear()
        for (var i = 0; i < tabs.length; i++) {
            languageTabsModel.append({ "label": tabs[i] })
        }

        var restoredIndex = 0
        if (previousLabel !== "") {
            for (var j = 0; j < tabs.length; j++) {
                if (tabs[j] === previousLabel) {
                    restoredIndex = j
                    break
                }
            }
        }
        langTabs.currentIndex = restoredIndex
    }

    function clearTree() {
        treeModel.clear()
    }

    function addTreeItem(item) {
        treeModel.append({
            "fileName": item.fileName || "",
            "itemId": item.itemId || "",
            "fileSize": item.fileSize || "",
            "duration": item.duration || "",
            "itemType": item.itemType || "",
            "tags": item.tags || "",
            "hasChildren": item.hasChildren || false,
            "expanded": false,
            "depth": item.depth || 0,
            "pckPath": item.pckPath || "",
            "isModified": item.isModified || false
        })
    }

    function addTreeItems(items) {
        if (items.length === 0) return

        var firstItem = items[0]
        var insertIdx = -1

        if (firstItem.parentBnk) {

            for (var k = 0; k < treeModel.count; k++) {
                if (treeModel.get(k).itemId === firstItem.parentBnk &&
                    treeModel.get(k).pckPath === firstItem.pckPath) {
                    insertIdx = k + 1

                    while (insertIdx < treeModel.count &&
                           treeModel.get(insertIdx).depth > treeModel.get(k).depth) {
                        insertIdx++
                    }
                    break
                }
            }
        } else if (firstItem.parentPck) {

            for (var j = 0; j < treeModel.count; j++) {
                if (treeModel.get(j).pckPath === firstItem.parentPck &&
                    treeModel.get(j).itemType === "PCK") {
                    insertIdx = j + 1

                    while (insertIdx < treeModel.count &&
                           treeModel.get(insertIdx).depth > 0) {
                        insertIdx++
                    }
                    break
                }
            }
        }

        for (var i = 0; i < items.length; i++) {
            var row = {
                "fileName": items[i].fileName || "",
                "itemId": items[i].itemId || "",
                "fileSize": items[i].fileSize || "",
                "duration": items[i].duration || "",
                "itemType": items[i].itemType || "",
                "tags": items[i].tags || "",
                "hasChildren": items[i].hasChildren || false,
                "expanded": false,
                "depth": items[i].depth || 0,
                "pckPath": items[i].pckPath || "",
                "isModified": items[i].isModified || false
            }
            if (insertIdx >= 0) {
                treeModel.insert(insertIdx + i, row)
            } else {
                treeModel.append(row)
            }
        }
    }

    function setStatus(msg) {
        statusText = msg
    }

    function setNowPlaying(text) {
        nowPlayingText = text
    }

    function setPlaybackState(playing, paused, enabled) {
        isPlaying = playing
        isPaused = paused
        playbackEnabled = enabled
    }

    function setProgress(position, timeStr) {
        playbackProgress = position
        timeText = timeStr
    }

    function scrollToItem(fileId, pckPath) {

        for (var p = 0; p < treeModel.count; p++) {
            var item = treeModel.get(p)
            if (item.pckPath === pckPath &&
                (item.itemType === "PCK" || item.itemType === "BNK") &&
                item.hasChildren && !(item.expanded || false)) {
                treeModel.setProperty(p, "expanded", true)
            }
        }

        for (var i = 0; i < treeModel.count; i++) {
            if (treeModel.get(i).itemId === fileId && treeModel.get(i).pckPath === pckPath) {
                treeList.positionViewAtIndex(i, ListView.Center)
                highlightItemId = fileId
                highlightPckPath = pckPath
                highlightClearTimer.restart()
                return
            }
        }
    }

    Timer {
        id: highlightClearTimer
        interval: 3000
        onTriggered: {
            highlightItemId = ""
            highlightPckPath = ""
        }
    }

    function showTagDialog(soundInfo) {

        tagNameInput.text = soundInfo.name || ""
        tagTagsInput.text = soundInfo.tags || ""
        tagNotesInput.text = soundInfo.notes || ""
        tagHashLabel.text = "Hash: " + (soundInfo.hash || "Unknown")

        tagDialog.currentItemId = soundInfo.itemId || ""
        tagDialog.currentItemType = soundInfo.itemType || ""
        tagDialog.currentPckPath = soundInfo.pckPath || ""

        tagOverlay.visible = true
        tagOverlay.closing = false
        tagNameInput.forceActiveFocus()
    }

    function showMetadataDialog(metadata) {

        if (metadata && Object.keys(metadata).length > 0) {
            metadataNameInput.text = metadata.name || ""
            metadataAuthorInput.text = metadata.author || ""
            metadataVersionInput.text = metadata.version || "1.0.0"
            metadataDescriptionInput.text = metadata.description || ""
            metadataThumbnailPathInput.text = metadata.thumbnail || ""
        } else {

            metadataNameInput.text = ""
            metadataAuthorInput.text = ""
            metadataVersionInput.text = "1.0.0"
            metadataDescriptionInput.text = ""
            metadataThumbnailPathInput.text = ""
        }

        metadataOverlay.visible = true
        metadataOverlay.closing = false
        metadataNameInput.forceActiveFocus()
    }

    function setThumbnailPath(path) {
        metadataThumbnailPathInput.text = path
    }

    function showChanges(changes) {
        changesModel.clear()
        for (var i = 0; i < changes.length; i++) {
            changesModel.append({
                "fileId": changes[i].fileId || "",
                "pckFile": changes[i].pckFile || "",
                "fileType": changes[i].fileType || "",
                "itemType": changes[i].itemType || "",
                "bnkId": changes[i].bnkId || "",
                "dateModified": changes[i].dateModified || "",
                "taggedName": changes[i].taggedName || "",
                "sourceFile": changes[i].sourceFile || "",
                "wemPath": changes[i].wemPath || ""
            })
        }
        changesTitle.text = "Current Changes (" + changes.length + " replacement" + (changes.length !== 1 ? "s" : "") + ")"
        changesOverlay.visible = true
        changesOverlay.closing = false
    }

    function closeChangesDialog() {
        changesOverlay.closing = true
        changesHideTimer.start()
    }

    function showSearchResults(query, results) {
        searchResultsModel.clear()
        for (var i = 0; i < results.length; i++) {
            searchResultsModel.append({
                "name": results[i].name || "",
                "fileId": results[i].fileId || "",
                "tags": results[i].tags || "",
                "itemType": results[i].type || "",
                "pckPath": results[i].pckPath || "",
                "bnkId": results[i].bnkId || ""
            })
        }
        searchResultsTitle.text = "Search Results for '" + query + "' (" + results.length + " found)"
        searchResultsOverlay.visible = true
        searchResultsOverlay.closing = false
    }

    function updateTreeItemTag(itemId, itemType, pckPath, tagText) {

        for (var i = 0; i < treeModel.count; i++) {
            var item = treeModel.get(i)
            if (item.itemId === itemId && item.itemType === itemType && item.pckPath === pckPath) {
                treeModel.setProperty(i, "tags", tagText)
                break
            }
        }
    }

    function sortTreeBySize() {

        function parseSizeToBytes(sizeStr) {
            if (!sizeStr || sizeStr === "") return 0
            var parts = sizeStr.trim().split(' ')
            if (parts.length !== 2) return 0
            var num = parseFloat(parts[0])
            var unit = parts[1].toUpperCase()

            switch(unit) {
                case "B": return num
                case "KB": return num * 1024
                case "MB": return num * 1024 * 1024
                case "GB": return num * 1024 * 1024 * 1024
                default: return 0
            }
        }

        var items = []
        for (var i = 0; i < treeModel.count; i++) {
            var item = treeModel.get(i)
            items.push({
                fileName: item.fileName,
                itemId: item.itemId,
                fileSize: item.fileSize,
                duration: item.duration,
                fileSizeBytes: parseSizeToBytes(item.fileSize),
                itemType: item.itemType,
                tags: item.tags,
                hasChildren: item.hasChildren,
                expanded: item.expanded,
                depth: item.depth,
                pckPath: item.pckPath,
                isModified: item.isModified,
                parentPck: item.parentPck || "",
                parentBnk: item.parentBnk || ""
            })
        }

        function sortAtDepth(depth) {
            var depthItems = []
            var depthIndices = []

            for (var i = 0; i < items.length; i++) {
                if (items[i].depth === depth) {
                    depthItems.push(items[i])
                    depthIndices.push(i)
                }
            }

            depthItems.sort(function(a, b) {
                if (sortBySizeAsc) {
                    return a.fileSizeBytes - b.fileSizeBytes
                } else {
                    return b.fileSizeBytes - a.fileSizeBytes
                }
            })

            for (var j = 0; j < depthItems.length; j++) {
                items[depthIndices[j]] = depthItems[j]
            }
        }

        var maxDepth = 0
        for (var k = 0; k < items.length; k++) {
            if (items[k].depth > maxDepth) maxDepth = items[k].depth
        }
        for (var d = 0; d <= maxDepth; d++) {
            sortAtDepth(d)
        }

        treeModel.clear()
        for (var m = 0; m < items.length; m++) {
            treeModel.append(items[m])
        }
    }

    function sortTreeByDuration() {

        function parseDurationToSeconds(durStr) {
            if (!durStr || durStr === "") return -1
            var clean = durStr.replace("~", "")
            var parts = clean.split(":")
            if (parts.length !== 2) return -1
            var mins = parseInt(parts[0])
            var secs = parseInt(parts[1])
            if (isNaN(mins) || isNaN(secs)) return -1
            return mins * 60 + secs
        }

        var items = []
        for (var i = 0; i < treeModel.count; i++) {
            var item = treeModel.get(i)
            items.push({
                fileName: item.fileName,
                itemId: item.itemId,
                fileSize: item.fileSize,
                duration: item.duration,
                durationSeconds: parseDurationToSeconds(item.duration),
                itemType: item.itemType,
                tags: item.tags,
                hasChildren: item.hasChildren,
                expanded: item.expanded,
                depth: item.depth,
                pckPath: item.pckPath,
                isModified: item.isModified,
                parentPck: item.parentPck || "",
                parentBnk: item.parentBnk || ""
            })
        }

        function sortAtDepth(depth) {
            var depthItems = []
            var depthIndices = []

            for (var i = 0; i < items.length; i++) {
                if (items[i].depth === depth) {
                    depthItems.push(items[i])
                    depthIndices.push(i)
                }
            }

            depthItems.sort(function(a, b) {
                if (sortByDurationAsc) {
                    return a.durationSeconds - b.durationSeconds
                } else {
                    return b.durationSeconds - a.durationSeconds
                }
            })

            for (var j = 0; j < depthItems.length; j++) {
                items[depthIndices[j]] = depthItems[j]
            }
        }

        var maxDepth = 0
        for (var k = 0; k < items.length; k++) {
            if (items[k].depth > maxDepth) maxDepth = items[k].depth
        }
        for (var d = 0; d <= maxDepth; d++) {
            sortAtDepth(d)
        }

        treeModel.clear()
        for (var m = 0; m < items.length; m++) {
            treeModel.append(items[m])
        }
    }

    Item {
        id: contextMenuPopup
        anchors.fill: parent
        visible: contextMenu.visible
        z: 5000

        MouseArea {
            anchors.fill: parent
            onClicked: contextMenu.close()
        }

        Rectangle {
            id: menuPanel
            x: contextMenuX
            y: contextMenuY
            width: 260
            implicitHeight: menuColumn.implicitHeight + 8
            color: Theme.surfaceDark
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
            radius: Theme.radiusMedium

            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 4
                radius: 8
                samples: 16
                color: "#80000000"
            }

            MouseArea { anchors.fill: parent }

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeightLarge
                    color: replaceArea.containsMouse ? (replaceArea.pressed ? Theme.primaryAccent : Qt.lighter(Theme.surfaceDark, 1.3)) : Theme.surfaceDark
                    radius: Theme.radiusSmall
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.fill: parent
                        leftPadding: 14
                        text: "Replace with Custom Audio..."
                        color: replaceArea.containsMouse && replaceArea.pressed ? Theme.textOnAccent : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: replaceArea
                        objectName: "tutorialReplaceArea"
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contextMenu.close()
                            audioBrowserBackend.replaceWithCustomAudio(
                                contextMenu.contextItemId, contextMenu.contextItemType, contextMenu.contextPckPath, normalizeAudioChecked)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeightLarge
                    color: tagArea.containsMouse ? (tagArea.pressed ? Theme.primaryAccent : Qt.lighter(Theme.surfaceDark, 1.3)) : Theme.surfaceDark
                    radius: Theme.radiusSmall
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.fill: parent
                        leftPadding: 14
                        text: "Tag This Sound..."
                        color: tagArea.containsMouse && tagArea.pressed ? Theme.textOnAccent : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: tagArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contextMenu.close()
                            tagSoundRequested(
                                contextMenu.contextItemId, contextMenu.contextItemType, contextMenu.contextPckPath)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeightLarge
                    color: muteArea.containsMouse ? (muteArea.pressed ? Theme.primaryAccent : Qt.lighter(Theme.surfaceDark, 1.3)) : Theme.surfaceDark
                    radius: Theme.radiusSmall
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.fill: parent
                        leftPadding: 14
                        text: "Mute Audio"
                        color: muteArea.containsMouse && muteArea.pressed ? Theme.textOnAccent : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: muteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contextMenu.close()
                            audioBrowserBackend.muteAudio(
                                contextMenu.contextItemId, contextMenu.contextItemType, contextMenu.contextPckPath)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 1
                }

                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeightLarge
                    color: playArea.containsMouse ? (playArea.pressed ? Theme.primaryAccent : Qt.lighter(Theme.surfaceDark, 1.3)) : Theme.surfaceDark
                    radius: Theme.radiusSmall
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.fill: parent
                        leftPadding: 14
                        text: "Play"
                        color: playArea.containsMouse && playArea.pressed ? Theme.textOnAccent : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contextMenu.close()
                            treeItemDoubleClicked(
                                contextMenu.contextItemId, contextMenu.contextItemType, contextMenu.contextPckPath)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeightLarge
                    color: exportArea.containsMouse ? (exportArea.pressed ? Theme.primaryAccent : Qt.lighter(Theme.surfaceDark, 1.3)) : Theme.surfaceDark
                    radius: Theme.radiusSmall
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.fill: parent
                        leftPadding: 14
                        text: "Export as WAV..."
                        color: exportArea.containsMouse && exportArea.pressed ? Theme.textOnAccent : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: exportArea
                        objectName: "tutorialExportArea"
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contextMenu.close()
                            audioBrowserBackend.exportAsWav(
                                contextMenu.contextItemId, contextMenu.contextItemType, contextMenu.contextPckPath)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 1
                }

                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeightLarge
                    color: copyIdArea.containsMouse ? (copyIdArea.pressed ? Theme.primaryAccent : Qt.lighter(Theme.surfaceDark, 1.3)) : Theme.surfaceDark
                    radius: Theme.radiusSmall
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.fill: parent
                        leftPadding: 14
                        text: "Copy ID"
                        color: copyIdArea.containsMouse && copyIdArea.pressed ? Theme.textOnAccent : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: copyIdArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contextMenu.close()
                            clipboardHelper.setText(contextMenu.contextItemId)
                        }
                    }
                }
            }
        }
    }

    Item {
        id: searchResultsOverlay
        visible: false
        anchors.fill: parent
        z: 2000
        property bool closing: false

        Timer {
            id: searchHideTimer
            interval: 200
            onTriggered: {
                searchResultsOverlay.visible = false
                searchResultsOverlay.closing = false
            }
        }

        ListModel { id: searchResultsModel }

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            opacity: (!searchResultsOverlay.closing && searchResultsOverlay.visible) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    searchResultsOverlay.closing = true
                    searchHideTimer.start()
                }
            }
        }

        Rectangle {
            id: searchDialog
            width: Math.min(650, parent.width - 60)
            height: Math.min(500, parent.height - 80)
            anchors.centerIn: parent
            color: Theme.surfaceColor
            radius: Theme.radiusLarge
            border.color: Theme.cardBackground
            border.width: 1
            scale: (!searchResultsOverlay.closing && searchResultsOverlay.visible) ? 1.0 : 0.9
            opacity: (!searchResultsOverlay.closing && searchResultsOverlay.visible) ? 1.0 : 0.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    id: searchResultsTitle
                    text: "Search Results"
                    color: Theme.primaryAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                    Layout.fillWidth: true
                }

                ListView {
                    id: searchResultsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: searchResultsModel
                    spacing: 2
                    boundsBehavior: Flickable.DragOverBounds
                    flickDeceleration: 5000
                    maximumFlickVelocity: 2500

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        width: searchResultsList.width
                        height: 36
                        color: resultMouse.containsMouse ? Qt.lighter(Theme.surfaceDark, 1.4) : Theme.surfaceDark
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: model.name
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: model.fileId
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.preferredWidth: 100
                            }
                            Text {
                                text: model.tags
                                color: Theme.secondaryAccent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                Layout.preferredWidth: 140
                            }
                        }

                        MouseArea {
                            id: resultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {

                                audioBrowserBackend.navigateToSearchResult(
                                    model.fileId, model.itemType, model.pckPath, model.bnkId)
                                searchResultsOverlay.closing = true
                                searchHideTimer.start()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No results found."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                        visible: searchResultsModel.count === 0
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    ZZARButton {
                        text: "Close"
                        onClicked: {
                            searchResultsOverlay.closing = true
                            searchHideTimer.start()
                        }
                    }
                }
            }
        }
    }

    Item {
        id: changesOverlay
        visible: false
        anchors.fill: parent
        z: 2000
        property bool closing: false

        Timer {
            id: changesHideTimer
            interval: 200
            onTriggered: {
                changesOverlay.visible = false
                changesOverlay.closing = false
            }
        }

        ListModel { id: changesModel }

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            opacity: (!changesOverlay.closing && changesOverlay.visible) ? 1.0 : 0.0
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
                onClicked: {
                    changesOverlay.closing = true
                    changesHideTimer.start()
                }
            }
        }

        Rectangle {
            id: changesDialog
            width: Math.min(900, parent.width - 60)
            height: Math.min(550, parent.height - 80)
            anchors.centerIn: parent
            color: Theme.surfaceColor
            radius: Theme.radiusLarge
            border.color: Theme.cardBackground
            border.width: 1
            scale: (!changesOverlay.closing && changesOverlay.visible) ? 1.0 : 0.9
            opacity: (!changesOverlay.closing && changesOverlay.visible) ? 1.0 : 0.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    id: changesTitle
                    text: "Current Changes"
                    color: Theme.primaryAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    color: Theme.surfaceDark
                    radius: 6

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: "File ID"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.preferredWidth: 80
                        }
                        Text {
                            text: "Tagged Name"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.preferredWidth: 150
                        }
                        Text {
                            text: "Replaced By"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "Type"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.preferredWidth: 170
                        }
                        Text {
                            text: "Modified"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.preferredWidth: 70
                        }
                        Text {
                            text: "Actions"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            Layout.preferredWidth: 120
                        }
                    }
                }

                ListView {
                    id: changesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: changesModel
                    spacing: 2
                    boundsBehavior: Flickable.DragOverBounds
                    flickDeceleration: 5000
                    maximumFlickVelocity: 2500

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        width: changesList.width
                        height: 36
                        color: changeMouse.containsMouse ? Qt.lighter(Theme.surfaceDark, 1.4) : Theme.surfaceDark
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: model.fileId
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.preferredWidth: 80
                            }
                            Text {
                                text: model.taggedName || "-"
                                color: model.taggedName ? Theme.primaryAccent : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                Layout.preferredWidth: 150
                            }
                            Text {
                                text: model.sourceFile || "-"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                            Text {
                                text: model.fileType
                                color: Theme.secondaryAccent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.preferredWidth: 170
                            }
                            Text {
                                text: {

                                    var date = new Date(model.dateModified)
                                    if (isNaN(date.getTime())) return "Unknown"
                                    var now = new Date()
                                    var diffMs = now - date
                                    var diffMins = Math.floor(diffMs / 60000)
                                    var diffHours = Math.floor(diffMins / 60)
                                    var diffDays = Math.floor(diffHours / 24)

                                    if (diffMins < 1) return "Just now"
                                    if (diffMins < 60) return diffMins + "m ago"
                                    if (diffHours < 24) return diffHours + "h ago"
                                    if (diffDays < 7) return diffDays + "d ago"
                                    return date.toLocaleDateString()
                                }
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.preferredWidth: 70
                            }

                            ZZARButton {
                                text: "▶"
                                Layout.preferredWidth: 45
                                Layout.preferredHeight: 28
                                buttonColor: Theme.primaryAccent
                                fontSize: 12
                                visible: model.wemPath !== ""
                                onClicked: {
                                    playReplacementClicked(model.wemPath)
                                }
                            }

                            ZZARButton {
                                text: "Remove"
                                Layout.preferredWidth: 70
                                Layout.preferredHeight: 28
                                buttonColor: Theme.disabledAccent
                                fontSize: 11
                                onClicked: {
                                    removeChangeRequested(model.pckFile, model.fileId)
                                }
                            }
                        }

                        MouseArea {
                            id: changeMouse
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.rightMargin: 125
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {

                                navigateToChangeClicked(model.pckFile, model.fileId, model.itemType, model.bnkId)

                                closeChangesDialog()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No changes yet.\nReplace some audio files to see them here."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                        horizontalAlignment: Text.AlignHCenter
                        visible: changesModel.count === 0
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    Item { Layout.fillWidth: true }

                    ZZARButton {
                        text: "Apply Changes"
                        buttonColor: Theme.primaryAccent
                        visible: changesModel.count > 0
                        onClicked: {
                            applyChangesClicked()
                            changesOverlay.closing = true
                            changesHideTimer.start()
                        }
                    }

                    ZZARButton {
                        text: "Close"
                        onClicked: {
                            changesOverlay.closing = true
                            changesHideTimer.start()
                        }
                    }
                }
            }
        }
    }

    Item {
        id: tagOverlay
        visible: false
        anchors.fill: parent
        z: 2001
        property bool closing: false

        Timer {
            id: tagHideTimer
            interval: 200
            onTriggered: {
                tagOverlay.visible = false
                tagOverlay.closing = false
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            opacity: (!tagOverlay.closing && tagOverlay.visible) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    tagOverlay.closing = true
                    tagHideTimer.start()
                }
            }
        }

        Rectangle {
            id: tagDialog
            width: Math.min(450, parent.width - 60)
            height: Math.min(400, parent.height - 80)
            anchors.centerIn: parent
            color: Theme.surfaceColor
            radius: Theme.radiusLarge
            border.color: Theme.cardBackground
            border.width: 1
            scale: (!tagOverlay.closing && tagOverlay.visible) ? 1.0 : 0.9
            opacity: (!tagOverlay.closing && tagOverlay.visible) ? 1.0 : 0.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            property string currentItemId: ""
            property string currentItemType: ""
            property string currentPckPath: ""

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "Tag Sound"
                    color: Theme.primaryAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: "Name:"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: Theme.buttonHeight
                    color: Theme.cardBackground
                    radius: Theme.radiusMedium

                    TextInput {
                        id: tagNameInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            text: "e.g., Astra Ultimate Voice"
                            visible: !tagNameInput.text && !tagNameInput.activeFocus
                        }
                    }
                }

                Text {
                    text: "Tags (comma-separated):"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: Theme.buttonHeight
                    color: Theme.cardBackground
                    radius: Theme.radiusMedium

                    TextInput {
                        id: tagTagsInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            text: "e.g., astra, ultimate, voice"
                            visible: !tagTagsInput.text && !tagTagsInput.activeFocus
                        }
                    }
                }

                Text {
                    text: "Notes:"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Theme.cardBackground
                    radius: Theme.radiusMedium

                    TextEdit {
                        id: tagNotesInput
                        anchors.fill: parent
                        anchors.margins: 14
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: TextEdit.Wrap
                        clip: true

                        Text {
                            anchors.fill: parent
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            text: "Additional notes..."
                            visible: !tagNotesInput.text && !tagNotesInput.activeFocus
                        }
                    }
                }

                Text {
                    id: tagHashLabel
                    text: "Hash: "
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    Item { Layout.fillWidth: true }

                    ZZARButton {
                        text: "Cancel"
                        buttonColor: Theme.disabledAccent
                        onClicked: {
                            tagOverlay.closing = true
                            tagHideTimer.start()
                        }
                    }

                    ZZARButton {
                        text: "Save"
                        buttonColor: Theme.primaryAccent
                        onClicked: {
                            var name = tagNameInput.text.trim()
                            if (!name) {

                                return
                            }

                            var tagsText = tagTagsInput.text.trim()
                            var tags = []
                            if (tagsText) {
                                var tagParts = tagsText.split(',')
                                for (var i = 0; i < tagParts.length; i++) {
                                    var tag = tagParts[i].trim()
                                    if (tag) tags.push(tag)
                                }
                            }

                            var notes = tagNotesInput.text.trim()

                            audioBrowserBackend.saveTag(
                                tagDialog.currentItemId,
                                tagDialog.currentItemType,
                                tagDialog.currentPckPath,
                                name,
                                tags.join(', '),
                                notes
                            )

                            tagOverlay.closing = true
                            tagHideTimer.start()
                        }
                    }
                }
            }
        }
    }

    Item {
        id: metadataOverlay
        visible: false
        anchors.fill: parent
        z: 2001
        property bool closing: false

        Timer {
            id: metadataHideTimer
            interval: 200
            onTriggered: {
                metadataOverlay.visible = false
                metadataOverlay.closing = false
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            opacity: (!metadataOverlay.closing && metadataOverlay.visible) ? 1.0 : 0.0
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
                onClicked: {
                    metadataOverlay.closing = true
                    metadataHideTimer.start()
                }
            }
        }

        Rectangle {
            id: metadataDialog
            width: Math.min(500, parent.width - 60)
            height: Math.min(550, parent.height - 80)
            anchors.centerIn: parent
            color: Theme.surfaceColor
            radius: Theme.radiusLarge
            border.color: Theme.cardBackground
            border.width: 1
            scale: (!metadataOverlay.closing && metadataOverlay.visible) ? 1.0 : 0.9
            opacity: (!metadataOverlay.closing && metadataOverlay.visible) ? 1.0 : 0.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            MouseArea {
                anchors.fill: parent
                onClicked: {

                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "Mod Package Metadata"
                    color: Theme.primaryAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: "Name*:"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: Theme.buttonHeight
                    color: Theme.cardBackground
                    radius: Theme.radiusMedium

                    TextInput {
                        id: metadataNameInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            text: "My Awesome Mod"
                            visible: !metadataNameInput.text && !metadataNameInput.activeFocus
                        }
                    }
                }

                Text {
                    text: "Author*:"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: Theme.buttonHeight
                    color: Theme.cardBackground
                    radius: Theme.radiusMedium

                    TextInput {
                        id: metadataAuthorInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            text: "Your Name"
                            visible: !metadataAuthorInput.text && !metadataAuthorInput.activeFocus
                        }
                    }
                }

                Text {
                    text: "Version:"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: Theme.buttonHeight
                    color: Theme.cardBackground
                    radius: Theme.radiusMedium

                    TextInput {
                        id: metadataVersionInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        text: "1.0.0"
                        clip: true
                    }
                }

                Text {
                    text: "Description:"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    color: Theme.cardBackground
                    radius: Theme.radiusMedium

                    TextEdit {
                        id: metadataDescriptionInput
                        anchors.fill: parent
                        anchors.margins: 14
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: TextEdit.Wrap
                        clip: true

                        Text {
                            anchors.fill: parent
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            text: "Describe what your mod does..."
                            visible: !metadataDescriptionInput.text && !metadataDescriptionInput.activeFocus
                        }
                    }
                }

                Text {
                    text: "Thumbnail:"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: Theme.buttonHeight
                        color: Theme.cardBackground
                        radius: Theme.radiusMedium

                        TextInput {
                            id: metadataThumbnailPathInput
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            readOnly: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                text: "Optional: Select thumbnail image"
                                visible: !metadataThumbnailPathInput.text
                            }
                        }
                    }

                    ZZARButton {
                        text: "Browse"
                        onClicked: audioBrowserBackend.browseThumbnail()
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    Item { Layout.fillWidth: true }

                    ZZARButton {
                        text: "Cancel"
                        buttonColor: Theme.disabledAccent
                        onClicked: {
                            metadataOverlay.closing = true
                            metadataHideTimer.start()
                        }
                    }

                    ZZARButton {
                        text: "Create Package"
                        buttonColor: Theme.primaryAccent
                        onClicked: {
                            var name = metadataNameInput.text.trim()
                            var author = metadataAuthorInput.text.trim()

                            if (!name || !author) {

                                return
                            }

                            var version = metadataVersionInput.text.trim() || "1.0.0"
                            var description = metadataDescriptionInput.text.trim()
                            var thumbnailPath = metadataThumbnailPathInput.text.trim()

                            createModPackageRequested(name, author, version, description, thumbnailPath)

                            metadataOverlay.closing = true
                            metadataHideTimer.start()
                        }
                    }
                }
            }
        }
    }
}

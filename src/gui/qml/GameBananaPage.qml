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
    property var installedDownloadUrls: []
    property var installedZZARsByUrl: ({})
    property var zzarTotalsByUrl: ({})
    property int sortIndex: 0
    property string searchText: ""
    property bool thumbnailsEnabled: false
    property int currentPage: 1
    property int totalPages: 1
    property string currentSort: "default"

    onThumbnailsEnabledChanged: {
        if (thumbnailsEnabled) {
            refreshThumbnails()
        }
    }

    function refreshThumbnails() {

        for (var i = 0; i < gridRepeater.count; i++) {
            var item = gridRepeater.itemAt(i)
            if (item) {
                item._thumbRequested = false
                item.checkVisible()
            }
        }
    }

    property var sortedModsList: {
        var query = searchText.trim().toLowerCase()
        var list = query
            ? modsList.filter(function(m) { return (m.name || "").toLowerCase().indexOf(query) !== -1 })
            : modsList.slice()
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

    signal loadModsRequested(int page, string sort, string search)
    signal modCardClicked(int modId)
    signal refreshRequested()

    property bool _hasLoaded: false

    onVisibleChanged: {
        if (visible && !_hasLoaded) {
            _hasLoaded = true
            currentPage = 1
            loadModsRequested(1, "default", "")
        }
    }
    signal downloadModRequested(string downloadUrl, string filename, string modName, int modId)
    signal installChosenZZARRequested(string zipPath, string zzarName)

    function _refreshInstallState() {
        installedModIds = gameBananaBackend.getInstalledModIds()
        installedDownloadUrls = gameBananaBackend.getInstalledDownloadUrls()
        installedZZARsByUrl = gameBananaBackend.getInstalledZZARsByUrl()
        zzarTotalsByUrl = gameBananaBackend.getZZARTotalsByUrl()
        modDialog.installedModNames = gameBananaBackend.getInstalledModNames()
        modDialog.installedUrlMap = gameBananaBackend.getInstalledUrlMap()
        modDialog.installedDownloadUrls = installedDownloadUrls
        modDialog.installedZZARsByUrl = installedZZARsByUrl
        modDialog.zzarTotalsByUrl = zzarTotalsByUrl
        modDialog.installedVersion += 1
    }

    function onModsLoaded(mods) {
        modsList = mods
        isLoading = false
        _refreshInstallState()
    }

    function onTotalModsCount(count) {
        totalPages = Math.max(1, Math.ceil(count / 50))
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
        _refreshInstallState()
        modDialog.showModDetails(details)
        isLoading = false
    }

    function onInstalledModsChanged(names) {
        _refreshInstallState()
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Flow {
                    id: toolbar
                    objectName: "tutorialGbToolbar"
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
                                    objectName: "tutorialGbSearch"
                                    Layout.fillWidth: true
                                    color: Theme.textOnAccent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeNormal
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    clip: true
                                    onTextChanged: gameBananaPage.searchText = text

                                    Text {
                                        anchors.fill: parent
                                        text: qsTranslate("Application", "Search mods...")
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
                        objectName: "tutorialGbSort"
                        height: Theme.buttonHeight
                        model: [qsTranslate("Application", "Default"), qsTranslate("Application", "Most Downloaded"), qsTranslate("Application", "Most Liked"), qsTranslate("Application", "Newest")]

                        onActivated: {
                            sortIndex = index
                            var sortKeys = ["default", "Downloads", "Likes", "DateAdded"]
                            currentSort = sortKeys[index] || "default"
                            currentPage = 1
                            loadModsRequested(1, currentSort, "")
                        }

                        background: Rectangle {
                            HoverHandler { id: gbSortBgHover }
                            color: sortComboBox.pressed ? Qt.darker(Theme.cardBackground, 1.2)
                                 : gbSortBgHover.hovered ? Qt.lighter(Theme.cardBackground, 1.1)
                                 : Theme.cardBackground
                            radius: Theme.radiusMedium
                            border.color: "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        contentItem: Text {
                            text: qsTranslate("Application", "Sort: ") + sortComboBox.displayText
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
                            id: gbSortDelegate
                            width: sortComboBox.width - 8
                            height: Theme.buttonHeight
                            highlighted: sortComboBox.highlightedIndex === index

                            HoverHandler { id: gbSortDelegateHover }

                            background: Rectangle {
                                color: {
                                    if (gbSortDelegate.highlighted) return Theme.primaryAccent
                                    if (gbSortDelegateHover.hovered) return Qt.lighter(Theme.surfaceDark, 1.3)
                                    return Theme.surfaceDark
                                }
                                radius: Theme.radiusSmall
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            contentItem: Text {
                                text: modelData
                                color: gbSortDelegate.highlighted ? Theme.textOnAccent : Theme.textPrimary
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
                            color: refreshMouse.pressed ? Theme.accentDark : refreshMouse.containsMouse ? Theme.accentLight : Theme.primaryAccent
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
                                text: qsTranslate("Application", "Refresh")
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
                    } // end Flow toolbar

                    // Pagination controls
                    Row {
                        id: paginationRow
                        spacing: 4
                        visible: true
                        Layout.alignment: Qt.AlignVCenter

                        // Prev button
                        Item {
                            width: 32
                            height: Theme.buttonHeight
                            visible: currentPage > 1

                            HoverHandler { id: prevBgHover }

                            Rectangle {
                                anchors.fill: parent
                                color: prevBgHover.hovered ? Qt.lighter(Theme.cardBackground, 1.1) : Theme.cardBackground
                                radius: Theme.radiusMedium
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\u2039"
                                color: Theme.textPrimary
                                font.pixelSize: 18
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    currentPage = currentPage - 1
                                    gridFlickable.contentY = 0
                                    loadModsRequested(currentPage, gameBananaPage.currentSort, "")
                                }
                            }
                        }

                        // Page number buttons
                        Repeater {
                            model: {
                                var pages = []
                                var start = Math.max(1, currentPage - 2)
                                var end = Math.min(totalPages, start + 4)
                                start = Math.max(1, end - 4)
                                for (var i = start; i <= end; i++) pages.push(i)
                                return pages
                            }

                            Item {
                                width: 32
                                height: Theme.buttonHeight

                                HoverHandler { id: pageNumBgHover }

                                Rectangle {
                                    anchors.fill: parent
                                    color: modelData === currentPage
                                         ? Theme.primaryAccent
                                         : pageNumBgHover.hovered ? Qt.lighter(Theme.cardBackground, 1.1)
                                         : Theme.cardBackground
                                    radius: Theme.radiusMedium
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: modelData === currentPage ? Theme.textOnAccent : Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: modelData === currentPage
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: modelData !== currentPage
                                    onClicked: {
                                        currentPage = modelData
                                        gridFlickable.contentY = 0
                                        loadModsRequested(currentPage, gameBananaPage.currentSort, "")
                                    }
                                }
                            }
                        }

                        // Next button
                        Item {
                            width: 32
                            height: Theme.buttonHeight
                            visible: currentPage < totalPages

                            HoverHandler { id: nextBgHover }

                            Rectangle {
                                anchors.fill: parent
                                color: nextBgHover.hovered ? Qt.lighter(Theme.cardBackground, 1.1) : Theme.cardBackground
                                radius: Theme.radiusMedium
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\u203a"
                                color: Theme.textPrimary
                                font.pixelSize: 18
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    currentPage = currentPage + 1
                                    gridFlickable.contentY = 0
                                    loadModsRequested(currentPage, gameBananaPage.currentSort, "")
                                }
                            }
                        }
                    }
                } // end RowLayout

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingMedium
                        visible: isLoading && modsList.length === 0

                        Canvas {
                            id: loadingSpinner
                            width: 56
                            height: 56
                            anchors.horizontalCenter: parent.horizontalCenter

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var cx = width / 2, cy = height / 2, r = (width - 8) / 2
                                // background track
                                ctx.strokeStyle = "#2a2a2a"
                                ctx.lineWidth = 5
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                                ctx.stroke()
                                // accent arc (~270°)
                                ctx.strokeStyle = Theme.primaryAccent
                                ctx.lineWidth = 5
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI)
                                ctx.stroke()
                            }

                            RotationAnimator on rotation {
                                from: 0; to: 360
                                duration: 1000
                                running: isLoading
                                loops: Animation.Infinite
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTranslate("Application", "Loading mods...")
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
                            text: qsTranslate("Application", "No mods found")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamilyTitle
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTranslate("Application", "Try refreshing or check your connection")
                            color: "#888888"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Flickable {
                        id: gridFlickable
                        objectName: "tutorialGbGrid"
                        anchors.fill: parent
                        visible: !isLoading || modsList.length > 0
                        clip: true
                        contentHeight: gridFlow.height
                        boundsBehavior: Flickable.DragOverBounds
                        flickDeceleration: 5000
                        maximumFlickVelocity: 2500

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            minimumSize: 0.1

                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: 4
                                HoverHandler { id: gbGridScrollHover }
                                color: parent.pressed ? Theme.primaryAccent : (gbGridScrollHover.hovered ? Qt.lighter(Theme.primaryAccent, 1.3) : "#555555")
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

                        Flow {
                            id: gridFlow
                            width: parent.width - 12
                            spacing: 16

                            property int cols: Math.max(2, Math.floor((width + 16) / (240 + 16)))
                            property int cardWidth: Math.floor((width - (cols - 1) * 16) / cols)

                            Repeater {
                                id: gridRepeater
                                model: sortedModsList

                                Item {
                                    width: gridFlow.cardWidth
                                    height: 300

                                    property bool _thumbRequested: false

                                    function checkVisible() {
                                        if (_thumbRequested || modelData.thumbnail) return
                                        if (!gameBananaPage.thumbnailsEnabled) return
                                        var cardY = mapToItem(gridFlow, 0, 0).y
                                        var viewTop = gridFlickable.contentY - 320
                                        var viewBottom = gridFlickable.contentY + gridFlickable.height + 320
                                        if (cardY + height > viewTop && cardY < viewBottom) {
                                            _thumbRequested = true
                                            gameBananaBackend.fetchThumbnail(modelData.id)
                                        }
                                    }

                                    Component.onCompleted: checkVisible()
                                    Connections {
                                        target: gridFlickable
                                        function onContentYChanged() { checkVisible() }
                                    }

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
                                                        text: appName + " Native"
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
        objectName: "modDialog"
        onDownloadRequested: {
            downloadModRequested(downloadUrl, filename, modName, modId)
        }
        onInstallChosenZZAR: {
            installChosenZZARRequested(zipPath, zzarName)
        }
    }
}

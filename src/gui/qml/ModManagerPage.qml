import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.15
import QtGraphicalEffects 1.15
import Qt.labs.settings 1.0
import "."

Item {
    id: mod_Manager
    objectName: "modManagerPage"

    clip: true
    signal installModClicked()
    signal importModClicked()
    signal removeModsClicked(var modUuids)
    signal refreshClicked()
    signal openFolderClicked()
    signal applyModsClicked()
    signal modToggled(string modUuid, bool enabled)
    signal modSelected(string modUuid)
    signal moreInfoClicked(string modUuid)

    property var modManager: null
    property var selectedModUuids: []
    property int currentSortMode: 0
    property bool gridViewMode: false
    property var sortOptions: [qsTranslate("Application", "Default"), qsTranslate("Application", "Name (A-Z)"), qsTranslate("Application", "Name (Z-A)"), qsTranslate("Application", "Author (A-Z)"), qsTranslate("Application", "Author (Z-A)"), qsTranslate("Application", "Newest First"), qsTranslate("Application", "Oldest First"), qsTranslate("Application", "Enabled First")]

    Settings {
        id: modManagerSettings
        category: "ModManager"
        property alias sortMode: mod_Manager.currentSortMode
        property alias gridViewMode: mod_Manager.gridViewMode
    }

    ListModel {
        id: modsModel
    }

    Rectangle {
        id: outerFrame
        anchors.fill: parent
        anchors.margins: 15
        color: "#3c3d3f"
        radius: 36.44

        Rectangle {
            id: top_section
            anchors.fill: parent
            anchors.margins: 15
            color: "#252525"
            radius: 36.44

            Row {
                id: viewToggleRow
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 16
                anchors.topMargin: 16
                spacing: 4
                height: 31

                Item {
                    width: 31
                    height: 31

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMedium
                        color: !gridViewMode ? Theme.primaryAccent
                             : listToggleMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.15)
                             : Theme.cardBackground
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\u2630"
                        color: !gridViewMode ? Theme.textOnAccent : Theme.textPrimary
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: listToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: gridViewMode = false
                    }
                }

                Item {
                    width: 31
                    height: 31

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMedium
                        color: gridViewMode ? Theme.primaryAccent
                             : gridToggleMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.15)
                             : Theme.cardBackground
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\u229E"
                        color: gridViewMode ? Theme.textOnAccent : Theme.textPrimary
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: gridToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: gridViewMode = true
                    }
                }
            }

            Flow {
                id: buttons
                objectName: "tutorialButtonRow"
                anchors.left: parent.left
                anchors.right: viewToggleRow.left
                anchors.top: parent.top
                anchors.margins: 16
                anchors.rightMargin: 8
                spacing: 10

                Item {
                    id: btn_install
                    objectName: "tutorialInstallBtn"
                    height: 31
                    width: install.implicitWidth + 32

                    Rectangle {
                        id: rectangle_37
                        anchors.fill: parent
                        color: btn_install_mouse.pressed ? "#a8c800" : btn_install_mouse.containsMouse ? "#e8ff33" : "#d8fa00"
                        radius: 36.44
                        scale: btn_install_mouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                    Text {
                        id: install
                        anchors.centerIn: parent
                        color: "#000000"
                        font.family: "Alatsi"
                        font.pixelSize: 20
                        font.weight: Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTranslate("Application", "Install .zzar Mod")
                        textFormat: Text.PlainText
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: btn_install_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: installModClicked()
                    }
                }
                Item {
                    id: btn_import
                    objectName: "tutorialImportBtn"
                    height: 31
                    width: _import.implicitWidth + 32

                    Rectangle {
                        id: rectangle_38
                        anchors.fill: parent
                        color: btn_import_mouse.pressed ? "#a8c800" : btn_import_mouse.containsMouse ? "#e8ff33" : "#d8fa00"
                        radius: 20
                        scale: btn_import_mouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                    Text {
                        id: _import
                        anchors.centerIn: parent
                        color: "#000000"
                        font.family: "Alatsi"
                        font.pixelSize: 20
                        font.weight: Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTranslate("Application", "Import Non-ZZAR Mod")
                        textFormat: Text.PlainText
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: btn_import_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: importModClicked()
                    }
                }
                Item {
                    id: btn_remove
                    objectName: "tutorialRemoveBtn"
                    height: 31
                    width: remove.implicitWidth + 32

                    Rectangle {
                        id: rectangle_39
                        anchors.fill: parent
                        color: btn_remove_mouse.pressed ? "#a8c800" : btn_remove_mouse.containsMouse ? "#e8ff33" : "#d8fa00"
                        radius: 20
                        scale: btn_remove_mouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                    Text {
                        id: remove
                        anchors.centerIn: parent
                        color: "#000000"
                        font.family: "Alatsi"
                        font.pixelSize: 20
                        font.weight: Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        text: selectedModUuids.length > 1 ? qsTranslate("Application", "Remove Mods (") + selectedModUuids.length + ")" : qsTranslate("Application", "Remove Mod")
                        textFormat: Text.PlainText
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: btn_remove_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: removeModsClicked(selectedModUuids)
                    }
                }
                Item {
                    id: btn_refresh
                    height: 31
                    width: refresh.implicitWidth + 32

                    Rectangle {
                        id: rectangle_40
                        anchors.fill: parent
                        color: btn_refresh_mouse.pressed ? "#a8c800" : btn_refresh_mouse.containsMouse ? "#e8ff33" : "#d8fa00"
                        radius: 20
                        scale: btn_refresh_mouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                    Text {
                        id: refresh
                        anchors.centerIn: parent
                        color: "#000000"
                        font.family: "Alatsi"
                        font.pixelSize: 20
                        font.weight: Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTranslate("Application", "Refresh")
                        textFormat: Text.PlainText
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: btn_refresh_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: refreshClicked()
                    }
                }
                Item {
                    id: btn_openfolder
                    height: 31
                    width: refresh_1.implicitWidth + 32

                    Rectangle {
                        id: rectangle_41
                        anchors.fill: parent
                        color: btn_openfolder_mouse.pressed ? "#a8c800" : btn_openfolder_mouse.containsMouse ? "#e8ff33" : "#d8fa00"
                        radius: 20
                        scale: btn_openfolder_mouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                    Text {
                        id: refresh_1
                        anchors.centerIn: parent
                        color: "#000000"
                        font.family: "Alatsi"
                        font.pixelSize: 20
                        font.weight: Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTranslate("Application", "Open Mod Folder")
                        textFormat: Text.PlainText
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: btn_openfolder_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openFolderClicked()
                    }
                }
            }

            Item {
                id: sortRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: buttons.bottom
                anchors.margins: 16
                anchors.topMargin: 10
                height: Theme.buttonHeight

                ComboBox {
                    id: sortCombo
                    anchors.left: parent.left
                    width: btn_install.width
                    height: Theme.buttonHeight
                    model: sortOptions
                    currentIndex: currentSortMode

                    onCurrentIndexChanged: {
                        if (currentSortMode !== currentIndex) {
                            currentSortMode = currentIndex
                            applySorting()
                        }
                    }

                    background: Rectangle {
                        HoverHandler { id: mmSortBgHover }
                        color: sortCombo.pressed ? Qt.darker(Theme.cardBackground, 1.2)
                             : mmSortBgHover.hovered ? Qt.lighter(Theme.cardBackground, 1.1)
                             : Theme.cardBackground
                        radius: Theme.radiusMedium
                        border.color: "transparent"
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }

                    contentItem: Text {
                        text: qsTranslate("Application", "Sort: ") + sortCombo.displayText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 14
                        rightPadding: 40
                    }

                    indicator: Rectangle {
                        x: sortCombo.width - width - 10
                        y: (sortCombo.height - height) / 2
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
                        id: mmSortDelegate
                        width: sortCombo.width - 8
                        height: Theme.buttonHeight
                        highlighted: sortCombo.highlightedIndex === index

                        HoverHandler { id: mmSortDelegateHover }

                        background: Rectangle {
                            color: {
                                if (mmSortDelegate.highlighted) return Theme.primaryAccent
                                if (mmSortDelegateHover.hovered) return Qt.lighter(Theme.surfaceDark, 1.3)
                                return Theme.surfaceDark
                            }
                            radius: Theme.radiusSmall
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        contentItem: Text {
                            text: modelData
                            color: mmSortDelegate.highlighted ? Theme.textOnAccent : Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 14
                        }
                    }

                    popup: Popup {
                        y: sortCombo.height + 4
                        width: sortCombo.width
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
                            model: sortCombo.popup.visible ? sortCombo.delegateModel : null
                            currentIndex: sortCombo.highlightedIndex
                            spacing: 2

                            ScrollIndicator.vertical: ScrollIndicator {
                                active: true
                            }
                        }
                    }
                }

            }

            ListView {
                id: modsList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: sortRow.bottom
                anchors.bottom: applyModsButton.top
                anchors.margins: 16
                anchors.topMargin: 8
                spacing: 16
                clip: true
                boundsBehavior: Flickable.DragOverBounds
                flickDeceleration: 5000
                maximumFlickVelocity: 2500
                visible: !gridViewMode
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

                model: modsModel

                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Application", "No mods installed.\nClick 'Install .zzar Mod' to get started.")
                    color: "#888888"
                    font.family: "Alatsi"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    visible: modsModel.count === 0
                }

                delegate: Rectangle {
                    id: modItem
                    width: modsList.width
                    height: 108
                    color: modMouseArea.containsMouse ? "#6e6e6e" : "#666666"
                    radius: 36.44
                    border.color: selectedModUuids.indexOf(model.uuid) !== -1 ? "#d8fa00" : "transparent"
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: modMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var idx = selectedModUuids.indexOf(model.uuid)
                            var newList = selectedModUuids.slice()
                            if (idx !== -1) {
                                newList.splice(idx, 1)
                            } else {
                                newList.push(model.uuid)
                            }
                            selectedModUuids = newList
                            modSelected(model.uuid)
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 0

                        Rectangle {
                            id: thumbnailContainer
                            width: 92
                            height: 92
                            color: "#444444"
                            radius: 36.44

                            Image {
                                id: thumbnailImage
                                anchors.fill: parent
                                source: model.thumbnailPath || ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                mipmap: true
                                visible: false
                                layer.enabled: true
                            }

                            Rectangle {
                                id: thumbnailMask
                                anchors.fill: parent
                                radius: 36.44
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: thumbnailImage
                                source: thumbnailImage
                                maskSource: thumbnailMask
                                visible: model.thumbnailPath && model.thumbnailPath.length > 0
                            }

                            Text {
                                anchors.centerIn: parent
                                text: model.name ? model.name.charAt(0).toUpperCase() : "M"
                                color: "#888888"
                                font.family: "Alatsi"
                                font.pixelSize: 36
                                visible: !model.thumbnailPath || model.thumbnailPath.length === 0
                            }

                            Rectangle {
                                visible: model.fromGameBanana
                                width: 22; height: 22; radius: 11
                                color: "#d9282828"
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 3
                                Image {
                                    anchors.centerIn: parent
                                    width: 14; height: 14
                                    source: "../assets/Gamebanana.png"
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                }
                            }
                        }

                        Column {
                            width: parent.width - 92 - modButtonsCol.width - 16
                            height: 92
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 10
                            spacing: 0

                            Text {
                                height: 31
                                width: parent.width - parent.leftPadding
                                color: "#000000"
                                font.family: "Alatsi"
                                font.pixelSize: 20
                                font.weight: Font.Normal
                                horizontalAlignment: Text.AlignLeft
                                text: model.name + " v" + model.version
                                textFormat: Text.PlainText
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            Text {
                                height: 31
                                width: parent.width - parent.leftPadding
                                color: "#1f1e1e"
                                font.family: "Alatsi"
                                font.pixelSize: 16
                                font.weight: Font.Normal
                                horizontalAlignment: Text.AlignLeft
                                text: qsTranslate("Application", "By: ") + model.author
                                textFormat: Text.PlainText
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            Text {
                                height: 31
                                width: parent.width - parent.leftPadding
                                color: "#1f1e1e"
                                font.family: "Alatsi"
                                font.pixelSize: 16
                                font.weight: Font.Normal
                                horizontalAlignment: Text.AlignLeft
                                text: model.description
                                textFormat: Text.PlainText
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        Column {
                            id: modButtonsCol
                            width: Math.max(enableText.implicitWidth, infoText.implicitWidth) + 32
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 8
                            spacing: 9

                            Item {
                                height: 47
                                width: parent.width

                                Rectangle {
                                    objectName: "tutorialEnableBtn"
                                    anchors.fill: parent
                                    color: {
                                        if (model.enabled) {
                                            return toggleMouse.pressed ? "#72ca00" : toggleMouse.containsMouse ? "#a2ff22" : "#92fa00"
                                        } else {
                                            return toggleMouse.pressed ? "#666666" : toggleMouse.containsMouse ? "#999999" : "#808080"
                                        }
                                    }
                                    radius: 20
                                    scale: toggleMouse.pressed ? 0.95 : 1.0
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }
                                Text {
                                    id: enableText
                                    anchors.centerIn: parent
                                    color: "#000000"
                                    font.family: "Alatsi"
                                    font.pixelSize: 20
                                    font.weight: Font.Normal
                                    horizontalAlignment: Text.AlignHCenter
                                    text: model.enabled ? qsTranslate("Application", "Enabled") : qsTranslate("Application", "Disabled")
                                    textFormat: Text.PlainText
                                    verticalAlignment: Text.AlignVCenter
                                }
                                MouseArea {
                                    id: toggleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var newState = !model.enabled
                                        modsModel.setProperty(index, "enabled", newState)
                                        modToggled(model.uuid, newState)
                                    }
                                }
                            }

                            Item {
                                height: 31
                                width: parent.width

                                Rectangle {
                                    anchors.fill: parent
                                    color: infoMouse.pressed ? "#a8c800" : infoMouse.containsMouse ? "#e8ff33" : "#d8fa00"
                                    radius: 20
                                    scale: infoMouse.pressed ? 0.95 : 1.0
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }
                                Text {
                                    id: infoText
                                    anchors.centerIn: parent
                                    color: "#000000"
                                    font.family: "Alatsi"
                                    font.pixelSize: 20
                                    font.weight: Font.Normal
                                    horizontalAlignment: Text.AlignHCenter
                                    text: qsTranslate("Application", "More info")
                                    textFormat: Text.PlainText
                                    verticalAlignment: Text.AlignVCenter
                                }
                                MouseArea {
                                    id: infoMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("More info for mod:", model.uuid)
                                        moreInfoClicked(model.uuid)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GridView {
                id: modsGrid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: sortRow.bottom
                anchors.bottom: applyModsButton.top
                anchors.margins: 16
                anchors.topMargin: 8
                clip: true
                boundsBehavior: Flickable.DragOverBounds
                flickDeceleration: 5000
                maximumFlickVelocity: 2500
                visible: gridViewMode
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

                property int cols: Math.max(2, Math.floor(width / 210))
                cellWidth: Math.floor(width / cols)
                cellHeight: 300

                model: modsModel

                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Application", "No mods installed.\nClick 'Install .zzar Mod' to get started.")
                    color: "#888888"
                    font.family: "Alatsi"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    visible: modsModel.count === 0
                }

                delegate: Item {
                    width: modsGrid.cellWidth
                    height: modsGrid.cellHeight

                    Rectangle {
                        id: gridCard
                        anchors.fill: parent
                        anchors.margins: 6
                        color: gridCardMouse.containsMouse ? "#6e6e6e" : "#666666"
                        radius: 20
                        border.color: selectedModUuids.indexOf(model.uuid) !== -1 ? "#d8fa00" : "transparent"
                        border.width: 2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: gridCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var idx = selectedModUuids.indexOf(model.uuid)
                                var newList = selectedModUuids.slice()
                                if (idx !== -1) newList.splice(idx, 1)
                                else newList.push(model.uuid)
                                selectedModUuids = newList
                                modSelected(model.uuid)
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Rectangle {
                                id: gridThumbContainer
                                width: 140
                                height: 140
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: "#444444"
                                radius: 55

                                Image {
                                    id: gridThumbImg
                                    anchors.fill: parent
                                    source: model.thumbnailPath || ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                    visible: false
                                    layer.enabled: true
                                }
                                Rectangle {
                                    id: gridThumbMask
                                    anchors.fill: parent
                                    radius: 55
                                    visible: false
                                }
                                OpacityMask {
                                    anchors.fill: gridThumbImg
                                    source: gridThumbImg
                                    maskSource: gridThumbMask
                                    visible: model.thumbnailPath && model.thumbnailPath.length > 0
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: model.name ? model.name.charAt(0).toUpperCase() : "M"
                                    color: "#888888"
                                    font.family: "Alatsi"
                                    font.pixelSize: 40
                                    visible: !model.thumbnailPath || model.thumbnailPath.length === 0
                                }

                                Rectangle {
                                    visible: model.fromGameBanana
                                    width: 26; height: 26; radius: 13
                                    color: "#d9282828"
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    Image {
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        source: "../assets/Gamebanana.png"
                                        fillMode: Image.PreserveAspectFit
                                        mipmap: true
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                color: "#000000"
                                font.family: "Alatsi"
                                font.pixelSize: 15
                                font.weight: Font.Normal
                                horizontalAlignment: Text.AlignLeft
                                text: model.name + " v" + model.version
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                color: "#1f1e1e"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignLeft
                                text: qsTranslate("Application", "By: ") + model.author
                                elide: Text.ElideRight
                            }

                            Item {
                                width: parent.width
                                height: 32

                                Rectangle {
                                    anchors.fill: parent
                                    color: {
                                        if (model.enabled) return gridToggleBtn.pressed ? "#72ca00" : gridToggleBtn.containsMouse ? "#a2ff22" : "#92fa00"
                                        else return gridToggleBtn.pressed ? "#666666" : gridToggleBtn.containsMouse ? "#999999" : "#808080"
                                    }
                                    radius: 16
                                    scale: gridToggleBtn.pressed ? 0.95 : 1.0
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    color: "#000000"
                                    font.family: "Alatsi"
                                    font.pixelSize: 16
                                    text: model.enabled ? qsTranslate("Application", "Enabled") : qsTranslate("Application", "Disabled")
                                }
                                MouseArea {
                                    id: gridToggleBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var newState = !model.enabled
                                        modsModel.setProperty(index, "enabled", newState)
                                        modToggled(model.uuid, newState)
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 26

                                Rectangle {
                                    anchors.fill: parent
                                    color: gridInfoBtn.pressed ? "#a8c800" : gridInfoBtn.containsMouse ? "#e8ff33" : "#d8fa00"
                                    radius: 13
                                    scale: gridInfoBtn.pressed ? 0.95 : 1.0
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    color: "#000000"
                                    font.family: "Alatsi"
                                    font.pixelSize: 14
                                    text: qsTranslate("Application", "More info")
                                }
                                MouseArea {
                                    id: gridInfoBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: moreInfoClicked(model.uuid)
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: applyModsButton
                objectName: "tutorialApplyBtn"
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                height: 60
                width: 220

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    radius: 30
                    color: btn_apply_mouse.containsMouse ? "#40CDEE00" : "#30000000"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    id: applyButtonBg
                    anchors.fill: parent
                    radius: 30
                    color: btn_apply_mouse.pressed ? "#b8de00" : btn_apply_mouse.containsMouse ? "#e0f533" : "#CDEE00"
                    scale: btn_apply_mouse.pressed ? 0.97 : 1.0
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 28
                        color: "transparent"
                        border.color: "#40ffffff"
                        border.width: 1
                        opacity: btn_apply_mouse.containsMouse ? 0.5 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: "\u25B6"
                        color: "#000000"
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: qsTranslate("Application", "Apply Mods")
                        color: "#000000"
                        font.family: "Alatsi"
                        font.pixelSize: 22
                        font.bold: false
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    id: btn_apply_mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: applyModsClicked()
                }
            }
        }
    }

    function loadMods(modList) {
        console.log("Load mods called with", modList.length, "mods")
        modsModel.clear()
        for (var i = 0; i < modList.length; i++) {
            var mod = modList[i]
            modsModel.append({
                "uuid": mod.uuid || "",
                "name": mod.name || "Unknown",
                "version": mod.version || "1.0.0",
                "author": mod.author || "Unknown",
                "description": mod.description || "",
                "enabled": mod.enabled || false,
                "priority": mod.priority || 0,
                "thumbnailPath": mod.thumbnailPath || "",
                "installDate": mod.installDate || "",
                "fromGameBanana": mod.fromGameBanana || false
            })
        }
        if (currentSortMode !== 0) {
            applySorting()
        }
        var validUuids = []
        for (var j = 0; j < selectedModUuids.length; j++) {
            for (var k = 0; k < modsModel.count; k++) {
                if (modsModel.get(k).uuid === selectedModUuids[j]) {
                    validUuids.push(selectedModUuids[j])
                    break
                }
            }
        }
        selectedModUuids = validUuids
    }

    function applySorting() {
        if (modsModel.count <= 1) return

        var items = []
        for (var i = 0; i < modsModel.count; i++) {
            items.push({
                "uuid": modsModel.get(i).uuid,
                "name": modsModel.get(i).name,
                "version": modsModel.get(i).version,
                "author": modsModel.get(i).author,
                "description": modsModel.get(i).description,
                "enabled": modsModel.get(i).enabled,
                "priority": modsModel.get(i).priority,
                "thumbnailPath": modsModel.get(i).thumbnailPath,
                "installDate": modsModel.get(i).installDate,
                "fromGameBanana": modsModel.get(i).fromGameBanana
            })
        }

        switch (currentSortMode) {
            case 1:
                items.sort(function(a, b) { return a.name.toLowerCase().localeCompare(b.name.toLowerCase()) })
                break
            case 2:
                items.sort(function(a, b) { return b.name.toLowerCase().localeCompare(a.name.toLowerCase()) })
                break
            case 3:
                items.sort(function(a, b) { return a.author.toLowerCase().localeCompare(b.author.toLowerCase()) })
                break
            case 4:
                items.sort(function(a, b) { return b.author.toLowerCase().localeCompare(a.author.toLowerCase()) })
                break
            case 5:
                items.sort(function(a, b) { return b.installDate.localeCompare(a.installDate) })
                break
            case 6:
                items.sort(function(a, b) { return a.installDate.localeCompare(b.installDate) })
                break
            case 7:
                items.sort(function(a, b) {
                    if (a.enabled === b.enabled) return 0
                    return a.enabled ? -1 : 1
                })
                break
            default:
                items.sort(function(a, b) { return a.priority - b.priority })
                break
        }

        modsModel.clear()
        for (var j = 0; j < items.length; j++) {
            modsModel.append(items[j])
        }
    }

    function clearMods() {
        console.log("Clear mods called")
        modsModel.clear()
        selectedModUuids = []
    }

    function getSelectedModUuids() {
        return selectedModUuids
    }
}

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import "."

Rectangle {
    id: modDialog
    anchors.fill: parent
    color: "transparent"
    visible: false
    z: 1000

    property var modData: null
    property int downloadProgress: 0
    property bool isDownloading: false
    property bool isInstalling: false
    property int previewIndex: 0
    property bool closing: false
    property bool audioPreviewPlaying: false

    property var pendingZZARNames: []
    property string pendingZipPath: ""
    property string activeDownloadUrl: ""
    property var installedModNames: []
    property var installedUrlMap: ({})   // {download_url: mod_name}
    property int installedVersion: 0     // bumped on every install update to force binding re-eval

    signal downloadRequested(string downloadUrl, string filename, string modName, int modId)
    signal installChosenZZAR(string zipPath, string zzarName)

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: {
            visible = false
            closing = false
            if (audioPreviewPlaying) {
                audioBrowserBackend.stop()
                audioPreviewPlaying = false
            }
        }
    }

    function showModDetails(details) {
        modData = details
        previewIndex = 0
        closing = false
        audioPreviewPlaying = false
        visible = true
    }

    function setDownloadProgress(progress) {
        downloadProgress = progress
        if (progress >= 100) {
            isDownloading = false
        }
    }

    function setInstallState(installing) {
        isInstalling = installing
        if (!installing) activeDownloadUrl = ""
    }

    function showZZARChooser(names, zipPath) {
        pendingZZARNames = names
        pendingZipPath = zipPath
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        opacity: (!closing && visible) ? 1.0 : 0.0
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
            onWheel: {}
            onClicked: {
                modDialog.closing = true
                hideTimer.start()
            }
        }
    }

    Item {
        id: dialogPanel
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 860)
        height: Math.min(parent.height - 80, 720)

        scale: (!closing && visible) ? 1.0 : 0.9
        opacity: (!closing && visible) ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Rectangle {
            id: dialogOuter
            anchors.fill: parent
            color: Theme.backgroundColor
            radius: 36.44

            Rectangle {
                id: dialogInner
                anchors.fill: parent
                anchors.margins: 12
                color: Theme.surfaceColor
                radius: 30

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: modData ? modData.name : "Mod Details"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamilyTitle
                            font.pixelSize: 22
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            height: 24
                            width: zzarDialogBadgeText.implicitWidth + 16
                            radius: Theme.radiusMedium
                            color: Theme.primaryAccent
                            visible: modData && modData.zzar_supported === true

                            Text {
                                id: zzarDialogBadgeText
                                anchors.centerIn: parent
                                text: "ZZAR Native"
                                color: Theme.textOnAccent
                                font.family: Theme.fontFamilyTitle
                                font.pixelSize: 11
                            }
                        }

                        Item {
                            height: Theme.buttonHeight
                            width: Theme.buttonHeight

                            Rectangle {
                                anchors.fill: parent
                                color: closeMouse.pressed ? "#cc0000" : closeMouse.containsMouse ? "#ff3333" : Theme.backgroundColor
                                radius: Theme.radiusMedium
                                scale: closeMouse.pressed ? 0.92 : 1.0
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on scale { NumberAnimation { duration: 100 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\u2715"
                                color: Theme.textPrimary
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    modDialog.closing = true
                                    hideTimer.start()
                                }
                            }
                        }
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: contentCol.height
                        boundsBehavior: Flickable.DragOverBounds
                        flickDeceleration: 5000

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 8
                            contentItem: Rectangle {
                                radius: 4
                                color: parent.pressed ? Theme.primaryAccent : "#555555"
                            }
                        }

                        ColumnLayout {
                            id: contentCol
                            width: parent.width - 12
                            spacing: Theme.spacingMedium

                            Rectangle {
                                id: previewContainer
                                Layout.fillWidth: true
                                Layout.preferredHeight: 260
                                color: Theme.cardBackground
                                radius: Theme.radiusMedium
                                clip: true

                                property var mediaList: {
                                    if (!modData) return []
                                    var list = []
                                    var imgs = modData.description_images || []
                                    var vids = modData.description_videos || []

                                    if (modData.thumbnail && (imgs.length === 0 || imgs[0] !== modData.thumbnail))
                                        list.push({ url: modData.thumbnail, type: "image" })

                                    for (var i = 0; i < imgs.length; i++)
                                        list.push({ url: imgs[i], type: "image" })
                                    for (var j = 0; j < vids.length; j++)
                                        list.push({ url: vids[j], type: "video" })

                                    return list
                                }

                                property var currentMedia: mediaList.length > 0 ? mediaList[modDialog.previewIndex] : null

                                Image {
                                    anchors.fill: parent
                                    source: previewContainer.currentMedia && previewContainer.currentMedia.type === "image" ? previewContainer.currentMedia.url : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: !previewContainer.currentMedia || previewContainer.currentMedia.type === "image"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "No Preview Available"
                                        color: Theme.textTertiary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeNormal
                                        visible: parent.status !== Image.Ready && previewContainer.mediaList.length === 0
                                    }
                                }

                                Loader {
                                    id: videoLoader
                                    anchors.fill: parent
                                    source: "VideoPreview.qml"

                                    Binding {
                                        target: videoLoader.item
                                        property: "videoSource"
                                        value: previewContainer.currentMedia && previewContainer.currentMedia.type === "video"
                                               ? previewContainer.currentMedia.url : ""
                                        when: videoLoader.status === Loader.Ready
                                    }

                                    Binding {
                                        target: videoLoader.item
                                        property: "isVideoMedia"
                                        value: !!(previewContainer.currentMedia && previewContainer.currentMedia.type === "video")
                                        when: videoLoader.status === Loader.Ready
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32; height: 32; radius: 16
                                    color: prevMouse.containsMouse ? "#cc000000" : "#99000000"
                                    visible: previewContainer.mediaList.length > 1
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "<"
                                        color: Theme.textPrimary
                                        font.pixelSize: 18
                                        width: parent.width
                                        height: parent.height
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    MouseArea {
                                        id: prevMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var len = previewContainer.mediaList.length
                                            modDialog.previewIndex = (modDialog.previewIndex - 1 + len) % len
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32; height: 32; radius: 16
                                    color: nextMouse.containsMouse ? "#cc000000" : "#99000000"
                                    visible: previewContainer.mediaList.length > 1
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: ">"
                                        color: Theme.textPrimary
                                        font.pixelSize: 18
                                        width: parent.width
                                        height: parent.height
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    MouseArea {
                                        id: nextMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            modDialog.previewIndex = (modDialog.previewIndex + 1) % previewContainer.mediaList.length
                                        }
                                    }
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 8
                                    spacing: 6
                                    visible: previewContainer.mediaList.length > 1

                                    Repeater {
                                        model: previewContainer.mediaList.length

                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            color: index === modDialog.previewIndex ? Theme.primaryAccent : "#80ffffff"
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20

                                RowLayout {
                                    spacing: 10

                                    Rectangle {
                                        width: 44
                                        height: 44
                                        radius: 22
                                        color: Theme.backgroundColor

                                        Image {
                                            anchors.fill: parent
                                            source: modData ? modData.author_avatar : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            layer.enabled: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: 44; height: 44; radius: 22
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modData && modData.author ? modData.author.charAt(0).toUpperCase() : "?"
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 18
                                                visible: parent.status !== Image.Ready
                                            }
                                        }
                                    }

                                    Column {
                                        spacing: 2
                                        Text {
                                            text: modData ? modData.author : "Unknown"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeNormal
                                        }
                                        Text {
                                            text: "Mod Author"
                                            color: "#888888"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                Connections {
                                    target: audioBrowserBackend
                                    function onPlaybackStateUpdate(playing, paused, enabled) {
                                        if (!playing && !paused)
                                            modDialog.audioPreviewPlaying = false
                                    }
                                }

                                Rectangle {
                                    visible: modData && modData.preview_audio_url && modData.preview_audio_url !== ""
                                    width: 32; height: 32; radius: 16
                                    color: previewAudioMouse.containsMouse ? Qt.lighter(Theme.primaryAccent, 1.15) : Theme.primaryAccent
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modDialog.audioPreviewPlaying ? "\u25A0" : "\u25B6"
                                        color: "black"
                                        font.pixelSize: modDialog.audioPreviewPlaying ? 13 : 11
                                    }

                                    MouseArea {
                                        id: previewAudioMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modDialog.audioPreviewPlaying) {
                                                audioBrowserBackend.stop()
                                                modDialog.audioPreviewPlaying = false
                                            } else {
                                                audioBrowserBackend.playUrl(modData.preview_audio_url)
                                                modDialog.audioPreviewPlaying = true
                                            }
                                        }
                                    }
                                }

                                Slider {
                                    id: previewVolumeSlider
                                    visible: modData && modData.preview_audio_url && modData.preview_audio_url !== ""
                                    Layout.preferredWidth: 100
                                    from: 0; to: 100; value: 50
                                    onMoved: audioBrowserBackend.setVolume(Math.round(value))

                                    background: Rectangle {
                                        x: previewVolumeSlider.leftPadding
                                        y: previewVolumeSlider.bottomPadding + previewVolumeSlider.availableHeight / 2 - height / 2
                                        width: previewVolumeSlider.availableWidth
                                        height: 4; radius: 2
                                        color: Theme.cardBackground
                                        Rectangle {
                                            width: previewVolumeSlider.visualPosition * parent.width
                                            height: parent.height; radius: 2
                                            color: Theme.primaryAccent
                                        }
                                    }
                                    handle: Rectangle {
                                        x: previewVolumeSlider.leftPadding + previewVolumeSlider.visualPosition * (previewVolumeSlider.availableWidth - width)
                                        y: previewVolumeSlider.bottomPadding + previewVolumeSlider.availableHeight / 2 - height / 2
                                        width: 12; height: 12; radius: 6
                                        color: previewVolumeSlider.pressed ? Qt.darker(Theme.primaryAccent, 1.1) : Theme.primaryAccent
                                    }
                                }

                                Text {
                                    visible: modData && modData.preview_audio_url && modData.preview_audio_url !== ""
                                    text: Math.round(previewVolumeSlider.value) + "%"
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                Item { Layout.fillWidth: true }

                                Row {
                                    spacing: 10

                                    Repeater {
                                        model: [
                                            { label: "Downloads", value: modData ? modData.downloads.toLocaleString() : "0" },
                                            { label: "Likes",     value: modData ? modData.likes.toLocaleString()     : "0" },
                                            { label: "Views",     value: modData ? modData.views.toLocaleString()     : "0" }
                                        ]

                                        Rectangle {
                                            height: 50
                                            width: Math.max(statValText.implicitWidth + 28, 70)
                                            color: Theme.backgroundColor
                                            radius: Theme.radiusMedium

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 2

                                                Text {
                                                    id: statValText
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.value
                                                    color: Theme.primaryAccent
                                                    font.family: Theme.fontFamilyTitle
                                                    font.pixelSize: 16
                                                }

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.label
                                                    color: "#888888"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Description"
                                    color: Theme.primaryAccent
                                    font.family: Theme.fontFamilyTitle
                                    font.pixelSize: 15
                                }

                                Rectangle {
                                    width: parent.width
                                    height: descText.height + 24
                                    color: Theme.backgroundColor
                                    radius: Theme.radiusMedium

                                    Text {
                                        id: descText
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        text: modData ? modData.description : "No description available"
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Available Files"
                                    color: Theme.primaryAccent
                                    font.family: Theme.fontFamilyTitle
                                    font.pixelSize: 15
                                }

                                // ZZAR Files section header
                                Text {
                                    visible: modData && modData.files && modData.files.some(function(f) { return f.has_zzar })
                                    text: "ZZAR Files"
                                    color: Theme.primaryAccent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    opacity: 0.7
                                }

                                Repeater {
                                    model: modData ? modData.files.filter(function(f) { return f.has_zzar }) : []

                                    Rectangle {
                                        width: parent.width
                                        height: 72
                                        color: fileRowMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.1) : Theme.cardBackground
                                        radius: Theme.radiusMedium
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        property bool isActiveRow: modDialog.activeDownloadUrl === modelData.download_url
                                        property bool rowDownloading: isActiveRow && modDialog.isDownloading
                                        property bool rowInstalling: isActiveRow && modDialog.isInstalling
                                        property bool isInstalled: {
                                            modDialog.installedVersion  // force re-eval on update
                                            var ids = gameBananaPage.installedModIds
                                            var mid = modDialog.modData ? modDialog.modData.id : -1
                                            console.log("[isInstalled] modData.id=", mid, "installedModIds=", JSON.stringify(ids))
                                            return mid !== -1 && ids.indexOf(mid) !== -1
                                        }

                                        MouseArea {
                                            id: fileRowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 12
                                            anchors.topMargin: 10
                                            anchors.bottomMargin: 10
                                            spacing: 14

                                            Column {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    width: parent.width
                                                    text: modelData.name
                                                    color: Theme.textOnAccent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 15
                                                    elide: Text.ElideRight
                                                }

                                                Row {
                                                    spacing: 8

                                                    Text {
                                                        text: (modelData.size / 1024 / 1024).toFixed(2) + " MB"
                                                        color: Theme.textTertiary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                    }
                                                    Text {
                                                        text: "\u2022"
                                                        color: Theme.textTertiary
                                                        font.pixelSize: 12
                                                    }
                                                    Text {
                                                        text: modelData.downloads + " downloads"
                                                        color: Theme.textTertiary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                    }
                                                }
                                            }

                                            Item {
                                                height: Theme.buttonHeightLarge
                                                width: dlBtnLabel.implicitWidth + 32

                                                property bool busy: parent.parent.rowDownloading || parent.parent.rowInstalling
                                                property bool installed: parent.parent.isInstalled

                                                Rectangle {
                                                    id: dlBtnBg
                                                    anchors.fill: parent
                                                    color: parent.installed ? "#555555"
                                                        : dlMouse.pressed ? "#a8c800" : dlMouse.containsMouse ? "#e8ff33" : Theme.primaryAccent
                                                    radius: Theme.radiusMedium
                                                    scale: dlMouse.pressed && !parent.installed ? 0.95 : 1.0
                                                    opacity: parent.installed ? 0.5 : parent.busy ? 0.7 : 1.0
                                                    Behavior on color { ColorAnimation { duration: 100 } }
                                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                                    Rectangle {
                                                        visible: parent.parent.parent.parent.rowDownloading
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: parent.width * (downloadProgress / 100)
                                                        radius: Theme.radiusMedium
                                                        color: Theme.secondaryAccent
                                                        Behavior on width { NumberAnimation { duration: 100 } }
                                                    }
                                                }

                                                Text {
                                                    id: dlBtnLabel
                                                    anchors.centerIn: parent
                                                    text: parent.parent.parent.rowDownloading ? (downloadProgress + "%")
                                                        : parent.parent.parent.rowInstalling ? "Installing..."
                                                        : parent.installed ? "Installed"
                                                        : "\u2193  Install"
                                                    color: Theme.textOnAccent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeNormal
                                                    font.bold: false
                                                }

                                                MouseArea {
                                                    id: dlMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: parent.installed ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                    enabled: !parent.busy && !parent.installed
                                                    onClicked: {
                                                        modDialog.activeDownloadUrl = modelData.download_url
                                                        modDialog.isDownloading = true
                                                        modDialog.downloadProgress = 0
                                                        downloadRequested(
                                                            modelData.download_url,
                                                            modelData.name,
                                                            modData.name,
                                                            modData.id
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Other Files section header
                                Text {
                                    visible: modData && modData.files && modData.files.some(function(f) { return f.has_zzar }) && modData.files.some(function(f) { return !f.has_zzar })
                                    text: "Other Files"
                                    color: "#888888"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    opacity: 0.7
                                }

                                Repeater {
                                    model: modData ? modData.files.filter(function(f) { return !f.has_zzar }) : []

                                    Rectangle {
                                        width: parent.width
                                        height: 72
                                        color: fileRowMouse2.containsMouse ? Qt.lighter(Theme.cardBackground, 1.1) : Theme.cardBackground
                                        radius: Theme.radiusMedium
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        property bool isActiveRow: modDialog.activeDownloadUrl === modelData.download_url
                                        property bool rowDownloading: isActiveRow && modDialog.isDownloading
                                        property bool rowInstalling: isActiveRow && modDialog.isInstalling
                                        property bool isInstalled: {
                                            modDialog.installedVersion
                                            return modDialog.modData && gameBananaPage.installedModIds.indexOf(modDialog.modData.id) !== -1
                                        }

                                        MouseArea {
                                            id: fileRowMouse2
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 12
                                            anchors.topMargin: 10
                                            anchors.bottomMargin: 10
                                            spacing: 14

                                            Column {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 3

                                                Text {
                                                    width: parent.width
                                                    text: modelData.name
                                                    color: Theme.textOnAccent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 15
                                                    elide: Text.ElideRight
                                                }

                                                Row {
                                                    spacing: 8
                                                    Text {
                                                        text: (modelData.size / 1024 / 1024).toFixed(2) + " MB"
                                                        color: Theme.textTertiary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                    }
                                                    Text {
                                                        text: "\u2022"
                                                        color: Theme.textTertiary
                                                        font.pixelSize: 12
                                                    }
                                                    Text {
                                                        text: modelData.downloads + " downloads"
                                                        color: Theme.textTertiary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 12
                                                    }
                                                }
                                            }

                                            Item {
                                                height: Theme.buttonHeightLarge
                                                width: dlBtnLabel2.implicitWidth + 32

                                                property bool busy: parent.parent.rowDownloading || parent.parent.rowInstalling
                                                property bool installed: parent.parent.isInstalled

                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: parent.installed ? "#555555"
                                                        : dlMouse2.pressed ? "#a8c800" : dlMouse2.containsMouse ? "#e8ff33" : Theme.primaryAccent
                                                    radius: Theme.radiusMedium
                                                    scale: dlMouse2.pressed && !parent.installed ? 0.95 : 1.0
                                                    opacity: parent.installed ? 0.5 : parent.busy ? 0.7 : 1.0
                                                    Behavior on color { ColorAnimation { duration: 100 } }
                                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                                    Rectangle {
                                                        visible: parent.parent.parent.parent.rowDownloading
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: parent.width * (downloadProgress / 100)
                                                        radius: Theme.radiusMedium
                                                        color: Theme.secondaryAccent
                                                        Behavior on width { NumberAnimation { duration: 100 } }
                                                    }
                                                }

                                                Text {
                                                    id: dlBtnLabel2
                                                    anchors.centerIn: parent
                                                    text: parent.parent.parent.rowDownloading ? (downloadProgress + "%")
                                                        : parent.parent.parent.rowInstalling ? "Installing..."
                                                        : parent.installed ? "Installed"
                                                        : "\u2193  Install"
                                                    color: Theme.textOnAccent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeNormal
                                                    font.bold: false
                                                }

                                                MouseArea {
                                                    id: dlMouse2
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: parent.installed ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                    enabled: !parent.busy && !parent.installed
                                                    onClicked: {
                                                        modDialog.activeDownloadUrl = modelData.download_url
                                                        modDialog.isDownloading = true
                                                        modDialog.downloadProgress = 0
                                                        downloadRequested(
                                                            modelData.download_url,
                                                            modelData.name,
                                                            modData.name,
                                                            modData.id
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 60
                                    color: Theme.backgroundColor
                                    radius: Theme.radiusMedium
                                    visible: modData && (!modData.files || modData.files.length === 0)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "No downloadable files available"
                                        color: "#888888"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }
                            }

                            Item { height: 8 }
                        }
                    }
                }
            }
        }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 0
            verticalOffset: 8
            radius: 28
            samples: 25
            color: "#a0000000"
        }
    }



    // ZZAR chooser overlay — shown when multiple .zzar files are found in the archive
    Item {
        id: zzarChooser
        anchors.fill: parent
        visible: modDialog.pendingZZARNames.length > 0
        z: 2000

        // track which entries are checked; reset when chooser opens
        property var checkedNames: []
        onVisibleChanged: if (visible) checkedNames = []

        Rectangle {
            anchors.fill: parent
            color: "#cc000000"
            MouseArea { anchors.fill: parent }
        }

        Item {
            id: chooserPanel
            anchors.centerIn: parent
            width: Math.min(zzarChooser.width - 80, 480)
            height: chooserInner.height + 24

            scale: zzarChooser.visible ? 1.0 : 0.9
            opacity: zzarChooser.visible ? 1.0 : 0.0
            Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                id: chooserInner
                width: parent.width
                height: chooserLayout.implicitHeight + 48
                anchors.top: parent.top
                color: Theme.backgroundColor
                radius: 36.44

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 12
                    color: Theme.surfaceColor
                    radius: 30

                    ColumnLayout {
                        id: chooserLayout
                        anchors {
                            top: parent.top; left: parent.left; right: parent.right
                            margins: Theme.spacingMedium
                        }
                        spacing: 12

                        Image {
                            source: "../assets/YuFufuEat.png"
                            Layout.preferredWidth: 240
                            Layout.preferredHeight: 240
                            Layout.alignment: Qt.AlignHCenter
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }

                        // Header
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: "Multiple .zzar files found"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamilyTitle
                                font.pixelSize: 20
                            }

                            // close X
                            Item {
                                height: Theme.buttonHeight
                                width: Theme.buttonHeight

                                Rectangle {
                                    anchors.fill: parent
                                    color: chooserCloseMouse.pressed ? "#cc0000"
                                         : chooserCloseMouse.containsMouse ? "#ff3333"
                                         : Theme.backgroundColor
                                    radius: Theme.radiusMedium
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u2715"
                                    color: Theme.textPrimary
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: chooserCloseMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modDialog.pendingZZARNames = []
                                        modDialog.pendingZipPath = ""
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Select the files you want to install, then press Install."
                            color: "#aaaaaa"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        // File list with checkboxes
                        Repeater {
                            model: modDialog.pendingZZARNames

                            Item {
                                Layout.fillWidth: true
                                height: 52

                                property bool checked: zzarChooser.checkedNames.indexOf(modelData) !== -1

                                Rectangle {
                                    anchors.fill: parent
                                    color: rowHover.containsMouse
                                         ? Qt.lighter(Theme.cardBackground, 1.1)
                                         : Theme.cardBackground
                                    radius: Theme.radiusMedium
                                    border.color: parent.checked ? Theme.primaryAccent : "transparent"
                                    border.width: 2
                                    Behavior on color  { ColorAnimation { duration: 100 } }
                                    Behavior on border.color { ColorAnimation { duration: 100 } }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    // Checkbox circle
                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        color: parent.parent.checked ? Theme.primaryAccent : "transparent"
                                        border.color: parent.parent.checked ? Theme.primaryAccent : Theme.textTertiary
                                        border.width: 2
                                        Behavior on color        { ColorAnimation { duration: 100 } }
                                        Behavior on border.color { ColorAnimation { duration: 100 } }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideMiddle
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    id: rowHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var list = zzarChooser.checkedNames.slice()
                                        var idx = list.indexOf(modelData)
                                        if (idx === -1) list.push(modelData)
                                        else list.splice(idx, 1)
                                        zzarChooser.checkedNames = list
                                    }
                                }
                            }
                        }

                        // Action buttons row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Select All toggle
                            Item {
                                height: Theme.buttonHeight
                                width: selAllLabel.implicitWidth + 28

                                Rectangle {
                                    anchors.fill: parent
                                    color: selAllMouse.containsMouse
                                         ? Qt.lighter(Theme.cardBackground, 1.15)
                                         : Theme.cardBackground
                                    radius: Theme.radiusMedium
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    id: selAllLabel
                                    anchors.centerIn: parent
                                    text: zzarChooser.checkedNames.length === modDialog.pendingZZARNames.length
                                          ? "Deselect All" : "Select All"
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                MouseArea {
                                    id: selAllMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (zzarChooser.checkedNames.length === modDialog.pendingZZARNames.length)
                                            zzarChooser.checkedNames = []
                                        else
                                            zzarChooser.checkedNames = modDialog.pendingZZARNames.slice()
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Install button
                            Item {
                                height: Theme.buttonHeight
                                width: 130

                                Rectangle {
                                    anchors.fill: parent
                                    color: installSelMouse.pressed ? "#a8c800"
                                         : installSelMouse.containsMouse ? "#e8ff33"
                                         : Theme.primaryAccent
                                    radius: Theme.radiusMedium
                                    opacity: zzarChooser.checkedNames.length === 0 ? 0.4 : 1.0
                                    scale: installSelMouse.pressed ? 0.95 : 1.0
                                    Behavior on color   { ColorAnimation  { duration: 100 } }
                                    Behavior on scale   { NumberAnimation { duration: 100 } }
                                }
                                Text {
                                    id: installSelLabel
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    text: zzarChooser.checkedNames.length > 1
                                          ? "Install " + zzarChooser.checkedNames.length + " files"
                                          : "Install"
                                    color: Theme.textOnAccent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: installSelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: zzarChooser.checkedNames.length > 0
                                    onClicked: {
                                        var toInstall = zzarChooser.checkedNames.slice()
                                        var zip = modDialog.pendingZipPath
                                        modDialog.pendingZZARNames = []
                                        modDialog.pendingZipPath = ""
                                        zzarChooser.checkedNames = []
                                        for (var i = 0; i < toInstall.length; i++)
                                            modDialog.installChosenZZAR(zip, toInstall[i])
                                    }
                                }
                            }
                        }

                        Item { height: 4 }
                    }
                }

                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    horizontalOffset: 0
                    verticalOffset: 8
                    radius: 28
                    samples: 25
                    color: "#a0000000"
                }
            }
        }
    }

    onVisibleChanged: {
        if (!visible) {
            isDownloading = false
            isInstalling = false
            downloadProgress = 0
            activeDownloadUrl = ""
            pendingZZARNames = []
            pendingZipPath = ""
            if (videoLoader.item) videoLoader.item.stopVideo()
        }
    }

    onPreviewIndexChanged: {

        previewVideo.stop()
    }
}

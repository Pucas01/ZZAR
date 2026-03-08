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
    property var installedUrlMap: ({})
    property var installedDownloadUrls: []
    property var installedZZARsByUrl: ({})
    property var zzarTotalsByUrl: ({})
    property int installedVersion: 0

    signal downloadRequested(string downloadUrl, string filename, string modName, int modId)
    signal downloadToPathRequested(string downloadUrl, string filename)
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
            id: dialogInner
            anchors.fill: parent
            color: "#252525"
            radius: 20
            border.color: "#3c3d3f"
            border.width: 1

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
                            text: modData ? modData.name : qsTranslate("Application", "Mod Details")
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
                            minimumSize: 0.1
                            anchors.right: parent.right
                            anchors.rightMargin: 0

                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: 4
                                HoverHandler { id: gbDialogScrollHover }
                                color: parent.pressed ? "#d8fa00" : (gbDialogScrollHover.hovered ? "#aac800" : "#555555")
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
                                        text: qsTranslate("Application", "No Preview Available")
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
                                            text: qsTranslate("Application", "Mod Author")
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
                                    text: qsTranslate("Application", "Description")
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
                                        text: modData ? modData.description : qsTranslate("Application", "No description available")
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
                                    text: qsTranslate("Application", "Available Files")
                                    color: Theme.primaryAccent
                                    font.family: Theme.fontFamilyTitle
                                    font.pixelSize: 15
                                }

                                Row {
                                    visible: modData && modData.files && modData.files.some(function(f) { return f.has_zzar })
                                    spacing: 8

                                    Text {
                                        text: qsTranslate("Application", "ZZAR Files")
                                        color: Theme.primaryAccent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        opacity: 0.7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        visible: {
                                            modDialog.installedVersion
                                            if (!modData || !modData.files) return false
                                            var zzarFiles = modData.files.filter(function(f) { return f.has_zzar })
                                            var installedCount = zzarFiles.filter(function(f) {
                                                return modDialog.installedDownloadUrls.indexOf(f.download_url) !== -1
                                            }).length
                                            return installedCount > 0 && zzarFiles.length > 1
                                        }
                                        text: {
                                            modDialog.installedVersion
                                            if (!modData || !modData.files) return ""
                                            var zzarFiles = modData.files.filter(function(f) { return f.has_zzar })
                                            var installedCount = zzarFiles.filter(function(f) {
                                                return modDialog.installedDownloadUrls.indexOf(f.download_url) !== -1
                                            }).length
                                            return "(" + installedCount + "/" + zzarFiles.length + " " + qsTranslate("Application", "installed") + ")"
                                        }
                                        color: "#aaaaaa"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
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
                                            modDialog.installedVersion
                                            return modDialog.installedDownloadUrls.indexOf(modelData.download_url) !== -1
                                        }
                                        property int zzarTotal: {
                                            modDialog.installedVersion
                                            return modDialog.zzarTotalsByUrl[modelData.download_url] || 0
                                        }
                                        property int zzarInstalledCount: {
                                            modDialog.installedVersion
                                            var arr = modDialog.installedZZARsByUrl[modelData.download_url]
                                            return arr ? arr.length : 0
                                        }
                                        property bool partiallyInstalled: zzarTotal > 1 && zzarInstalledCount > 0 && !isInstalled

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
                                                width: Math.max(dlBtnLabel.implicitWidth, installingLabel.implicitWidth) + 32

                                                Text { id: installingLabel; text: qsTranslate("Application", "Installing..."); font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeNormal; visible: false }

                                                property bool busy: parent.parent.rowDownloading || parent.parent.rowInstalling
                                                property bool installed: parent.parent.isInstalled
                                                property bool partial: parent.parent.partiallyInstalled

                                                Rectangle {
                                                    id: dlBtnBg
                                                    anchors.fill: parent
                                                    color: parent.installed ? "#555555"
                                                        : dlMouse.pressed ? "#a8c800" : dlMouse.containsMouse ? "#e8ff33" : Theme.primaryAccent
                                                    radius: Theme.radiusMedium
                                                    scale: dlMouse.pressed && !parent.installed ? 0.95 : 1.0
                                                    opacity: parent.installed ? 0.5 : 1.0
                                                    Behavior on color { ColorAnimation { duration: 100 } }
                                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                                }

                                                Text {
                                                    id: dlBtnLabel
                                                    anchors.centerIn: parent
                                                    text: {
                                                        var row = parent.parent.parent
                                                        if (row.rowDownloading) return downloadProgress + "%"
                                                        if (row.rowInstalling) return qsTranslate("Application", "Installing...")
                                                        if (parent.installed) return qsTranslate("Application", "Installed")
                                                        if (parent.partial) return row.zzarInstalledCount + "/" + row.zzarTotal + " " + qsTranslate("Application", "installed")
                                                        return "\u2193  " + qsTranslate("Application", "Install")
                                                    }
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
                                            return modDialog.installedDownloadUrls.indexOf(modelData.download_url) !== -1
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
                                                        : "\u2193  " + qsTranslate("Application", "Download")
                                                    color: Theme.textOnAccent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeNormal
                                                    font.bold: false
                                                }

                                                MouseArea {
                                                    id: dlMouse2
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: !parent.busy
                                                    onClicked: {
                                                        modDialog.activeDownloadUrl = modelData.download_url
                                                        modDialog.isDownloading = true
                                                        modDialog.downloadProgress = 0
                                                        modDialog.downloadToPathRequested(
                                                            modelData.download_url,
                                                            modelData.name
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

    Item {
        id: zzarChooser
        anchors.fill: parent
        visible: modDialog.pendingZZARNames.length > 0
        z: 2000

        property var checkedNames: []
        property bool closing: false
        onVisibleChanged: if (visible) { checkedNames = []; closing = false }

        Timer {
            id: chooserHideTimer
            interval: 200
            onTriggered: {
                modDialog.pendingZZARNames = []
                modDialog.pendingZipPath = ""
                zzarChooser.closing = false
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            opacity: (!zzarChooser.closing && zzarChooser.visible) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Image {
                anchors.fill: parent
                source: "../assets/gradient.png"
                fillMode: Image.Stretch
                mipmap: true
                opacity: 0.6
            }

            MouseArea { anchors.fill: parent }
        }

        Rectangle {
            id: chooserCard
            width: Math.min(500, parent.width - 40)
            height: chooserCol.height + 60
            anchors.centerIn: parent
            color: "#252525"
            radius: 20
            border.color: "#3c3d3f"
            border.width: 1
            scale: (!zzarChooser.closing && zzarChooser.visible) ? 1.0 : 0.9
            opacity: (!zzarChooser.closing && zzarChooser.visible) ? 1.0 : 0.0
            Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Column {
                id: chooserCol
                width: parent.width - 60
                anchors.centerIn: parent
                spacing: 16

                Item { height: 10; width: 1 }

                Image {
                    source: "../assets/YuFufuEat.png"
                    width: 160
                    height: 160
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: qsTranslate("Application", "Multiple .zzar files found")
                    color: "#d8fa00"
                    font.family: "Alatsi"
                    font.pixelSize: 24
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: qsTranslate("Application", "Select the files you want to install, then press Install.")
                    color: "#ffffff"
                    font.family: "Alatsi"
                    font.pixelSize: 16
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.4
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: modDialog.pendingZZARNames

                        Item {
                            width: parent.width
                            height: 48

                            readonly property bool checked: zzarChooser.checkedNames.indexOf(modelData) !== -1

                            Rectangle {
                                anchors.fill: parent
                                color: rowHover.containsMouse ? "#3a3a3a" : "#2e2e2e"
                                radius: 10
                                border.color: checked ? "#d8fa00" : "transparent"
                                border.width: 2
                                Behavior on color        { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Rectangle {
                                    width: 20; height: 20; radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: checked ? "#d8fa00" : "transparent"
                                    border.color: checked ? "#d8fa00" : "#888888"
                                    border.width: 2
                                    Behavior on color        { ColorAnimation { duration: 100 } }
                                    Behavior on border.color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    width: parent.width - 46
                                    text: modelData
                                    color: "#ffffff"
                                    font.family: "Alatsi"
                                    font.pixelSize: 13
                                    elide: Text.ElideMiddle
                                    anchors.verticalCenter: parent.verticalCenter
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
                }

                RowLayout {
                    width: parent.width
                    spacing: 20

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 120
                        height: 45
                        color: "#3c3d3f"
                        radius: Theme.radiusMedium
                        scale: closeBtnMouse.pressed ? 0.97 : (closeBtnMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Application", "Cancel")
                            color: "#ffffff"
                            font.family: "Alatsi"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: closeBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                zzarChooser.closing = true
                                chooserHideTimer.start()
                            }
                        }
                    }

                    Rectangle {
                        width: 120
                        height: 45
                        color: "#d8fa00"
                        radius: Theme.radiusMedium
                        opacity: zzarChooser.checkedNames.length === 0 ? 0.4 : 1.0
                        scale: installSelMouse.pressed ? 0.97 : (installSelMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale   { NumberAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: zzarChooser.checkedNames.length > 1
                                  ? qsTranslate("Application", "Install") + " (" + zzarChooser.checkedNames.length + ")"
                                  : qsTranslate("Application", "Install")
                            color: "#000000"
                            font.family: "Alatsi"
                            font.pixelSize: 16
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
                                zzarChooser.closing = true
                                chooserHideTimer.start()
                                zzarChooser.checkedNames = []
                                for (var i = 0; i < toInstall.length; i++)
                                    modDialog.installChosenZZAR(zip, toInstall[i])
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { height: 5; width: 1 }
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
        if (videoLoader.item) videoLoader.item.stopVideo()
    }
}

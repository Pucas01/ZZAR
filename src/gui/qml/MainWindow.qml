import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtQuick.Shapes 1.15
import QtGraphicalEffects 1.15
import "../components"
import "."

ApplicationWindow {
    id: mainWindow

    visible: true
    width: 1440
    height: 1024
    minimumWidth: 1024
    minimumHeight: 768
    title: qsTranslate("Application", "ZZAR - Zenless Zone Zero Audio Replacer")

    property int currentTab: 0
    property bool modCreationEnabled: false

    onModCreationEnabledChanged: {
        if (!modCreationEnabled && (currentTab === 1 || currentTab === 2)) {
            currentTab = 0
        }
    }

    function showToast(message, isSuccess) {
        toastText.text = message
        toastBackground.color = isSuccess ? "#CDEE00" : "#e91a1a"
        toastText.color = isSuccess ? "#000000" : "#ffffff"
        toastIcon.color = isSuccess ? "#000000" : "#ffffff"
        toastAnimation.start()
    }

    function showSuccessToast(message) {
        showToast(message, true)
    }

    function showErrorToast(message) {
        showToast(message, false)
    }

    signal dialogConfirmed(string actionId)
    signal dialogCancelled(string actionId)
    signal conflictsResolved()
    signal languageWarningDontShowAgain(bool dontShow)
    signal moveLanguageToStreaming(string folderName)

    function showConfirmDialog(title, message, actionId, customSticker) {
        customDialog.title = title
        customDialog.message = message
        customDialog.actionId = actionId
        customDialog.isConfirmation = true
        customDialog.confirmText = qsTranslate("Application", "Confirm")
        customDialog.cancelText = qsTranslate("Application", "Cancel")
        customDialog.customStickerPath = customSticker || ""
        customDialog.visible = true
    }

    function showAlertDialog(title, message, customSticker) {
        customDialog.title = title
        customDialog.message = message
        customDialog.actionId = ""
        customDialog.isConfirmation = false
        customDialog.confirmText = qsTranslate("Application", "OK")
        customDialog.customStickerPath = customSticker || ""
        customDialog.visible = true
    }

    function showSuccessDialog(title, message, customSticker) {
        successDialog.title = title
        successDialog.message = message
        successDialog.customStickerPath = customSticker || ""
        successDialog.visible = true
    }

    function showWelcomeDialog() {
        welcomeDialog.show()
    }

    function showConflictResolutionDialog(conflicts) {
        conflictResolutionDialog.show(conflicts)
    }

    function showModConflictDialog(modConflicts, fileConflicts) {
        modConflictDialog.show(modConflicts, fileConflicts)
    }

    property string pendingLanguageWarning: ""
    property bool tutorialActive: false
    property int pendingTagDbCount: 0

    onPendingTagDbCountChanged: pendingTagDbTimer.restart()
    onTutorialActiveChanged: if (!tutorialActive) pendingTagDbTimer.restart()

    Timer {
        id: pendingTagDbTimer
        interval: 2000
        onTriggered: _tryShowPendingTagDb()
    }

    function _tryShowPendingTagDb() {
        if (pendingTagDbCount > 0 && !tutorialActive && !welcomeDialog.visible && !tutorialOverlay.visible) {
            audioBrowserPage.onNewTagDbAvailable(pendingTagDbCount)
            pendingTagDbCount = 0
        }
    }

    property string pendingMoveableFolders: ""

    function hideLanguageWarningDialog() {
        if (languageWarningDialog.visible) {
            languageWarningDialog.closing = true
            languageWarningHideTimer.start()
        }
    }

    function showMultipleLanguagesWarning(languages, moveableFolders) {
        if (tutorialActive || tutorialOverlay.visible) {
            pendingLanguageWarning = languages
            pendingMoveableFolders = moveableFolders || ""
            return
        }
        languageWarningDialog.setLanguages(languages, moveableFolders || "")
        languageWarningDialog.visible = true
    }

    function showUpdateDialog(version, changelog) {
        updateDialog.show(version, changelog)
    }

    function showTutorial() {
        tutorialActive = true
        tutorialOverlay.start()
    }

    function showLoadingPopup(message) {
        loadingPopup.message = message || qsTranslate("Application", "Processing...")
        loadingPopup.closing = false
        loadingPopup.visible = true
    }

    function hideLoadingPopup() {
        loadingPopup.closing = true
        loadingHideTimer.start()
    }

    property bool isDraggingMod: false

    function urlToLocalPath(url) {
        var path = url.toString()
        if (Qt.platform.os === "windows") {
            path = path.replace(/^file:\/\/\//, "")
        } else {
            path = path.replace(/^file:\/\//, "")
        }
        return decodeURIComponent(path)
    }

    Rectangle {
        id: mainContent
        anchors.fill: parent
        color: "#131416"

        Column {
            anchors.fill: parent
            anchors.topMargin: 12
            spacing: 0

            Item {
                width: parent.width
                height: 87
                Row {
                    id: logoRow
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingMedium

                    Image {
                        width: 75
                        height: 75
                        source: "../assets/ZZAR-Logo2.png"
                        fillMode: Image.PreserveAspectFit
                    }

                }

                Column {
                    anchors.left: logoRow.right
                    anchors.right: navBar_Frm.left
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        id: pageTitle
                        text: currentTab === 0 ? qsTranslate("Application", "Mod Manager") :
                              currentTab === 1 ? qsTranslate("Application", "Browser") :
                              currentTab === 2 ? qsTranslate("Application", "Converter") :
                              qsTranslate("Application", "Settings")
                        color: "#ffffff"
                        font.family: "Audiowide"
                        font.letterSpacing: 4
                        font.pixelSize: 40
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        elide: Text.ElideRight
                    }

                    Text {
                        id: pageSubtitle
                        text: currentTab === 0 ? qsTranslate("Application", "Install and manage .zzar mods") :
                              currentTab === 1 ? qsTranslate("Application", "Browse and manage audio files") :
                              currentTab === 2 ? qsTranslate("Application", "Convert audio files") :
                              qsTranslate("Application", "Configure application settings")
                        color: "#666666"
                        font.family: "Audiowide"
                        font.letterSpacing: 1.60
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: navBar_Frm
                    anchors.right: parent.right
                    anchors.rightMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                    height: 70
                    width: modCreationEnabled ? 325 : 175
                    color: "#3c3d3f"
                    radius: 20

                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }

                    Row {
                        id: navbar
                        anchors.centerIn: parent
                        spacing: 15

                        Item {
                            id: home
                            height: 60
                            width: 60

                            property bool hovered: false

                            Rectangle {
                                id: rectangle_8
                                anchors.fill: parent
                                color: "transparent"
                                radius: 15
                            }

                            Item {
                                id: home_1
                                anchors.centerIn: parent
                                height: 35
                                width: 35

                                Item {
                                    id: stadia_controller
                                    anchors.fill: parent

                                    Shape {
                                        id: stadia_controller_1
                                        x: 1
                                        y: 6
                                        height: 24
                                        width: 33

                                        ShapePath {
                                            id: stadia_controller_1_ShapePath0
                                            fillColor: currentTab === 0 ? "#d8fa00" : (home.hovered ? "#d8fa00" : "#ffffff")
                                            fillRule: ShapePath.WindingFill
                                            joinStyle: ShapePath.MiterJoin
                                            strokeColor: "#00000000"
                                            strokeStyle: ShapePath.SolidLine
                                            strokeWidth: 0.03

                                            PathSvg {
                                                id: stadia_controller_1_ShapePath0_PathSvg0
                                                path: "M 5.468463665316678 24 C 3.979931519078866 24 2.7090024100179892 23.46771708811362 1.6556766990428873 22.403150183009352 C 0.6023509880677851 21.338583277905084 0.050458721218285624 20.05039341243233 0 18.538582388810283 C 0 18.31181072625588 0.012614677484971103 18.088189568106582 0.037844038094113915 17.867717112143207 C 0.06307339870325673 17.647244656179833 0.10091743115817003 17.42362205625519 0.15137615237645566 17.19685039370079 L 3.330275487622839 4.497638011541892 C 3.696101191079007 3.174803365872601 4.408830621238291 2.0944882190133645 5.468463665316678 1.2566929314080186 C 6.528096709395065 0.4188976438026729 7.7391061088611295 0 9.101491502806033 0 L 23.86066648357287 0 C 25.223051877517776 0 26.434061637892682 0.4188976438026729 27.493694681971068 1.2566929314080186 C 28.553327726049453 2.0944882190133645 29.266057517117577 3.174803365872601 29.631883220573744 4.497638011541892 L 32.81077982644703 17.19685039370079 C 32.861238547665316 17.42362205625519 32.90539221965657 17.653543592437984 32.943236257750684 17.886614461583417 C 32.9810802958448 18.11968533072885 33 18.349606866911643 33 18.576378529466044 C 33 20.088189553088093 32.463876325311944 21.370078950416385 31.391628524799774 22.422047532449557 C 30.31938072428761 23.47401611448273 29.020070917055797 24 27.493694681971068 24 C 26.44667630409925 24 25.47849873286 23.729134702307032 24.589163863024726 23.187402439868357 C 23.699828993189453 22.645670177429682 23.03440422295277 21.902362493079476 22.592890454586776 20.957480603315698 L 21.533257771417226 18.7653549074188 C 21.39449629652574 18.500787982790488 21.19266061088611 18.299212313073824 20.927752349866516 18.160629632904772 C 20.66284408884692 18.02204695273572 20.37901387363107 17.95275590551181 20.07626156887816 17.95275590551181 L 12.885894973865387 17.95275590551181 C 12.583142669112476 17.95275590551181 12.29931245389663 18.02204695273572 12.034404192877032 18.160629632904772 C 11.769495931857435 18.299212313073824 11.567660968035485 18.500787982790488 11.428899493144 18.7653549074188 L 10.388188538602678 20.957480603315698 C 9.934060104030113 21.902362493079476 9.262328271371775 22.645670177429682 8.372993401536501 23.187402439868357 C 7.483658531701227 23.729134702307032 6.515482043188495 24 5.468463665316678 24 Z M 19.754587851292257 9.977952611727977 C 20.032110801075227 9.70078725138987 20.170871655654643 9.366929121843473 20.170871655654643 8.976377952755906 C 20.170871655654643 8.585826783668338 20.032110801075227 8.251968654121939 19.754587851292257 7.974803293783833 C 19.477064901509287 7.697637933445727 19.142775412433497 7.559055118110236 18.751720354007386 7.559055118110236 C 18.360665295581274 7.559055118110236 18.026377250140843 7.697637933445727 17.748854300357873 7.974803293783833 C 17.471331350574903 8.251968654121939 17.332569052360128 8.585826783668338 17.332569052360128 8.976377952755906 C 17.332569052360128 9.366929121843473 17.471331350574903 9.70078725138987 17.748854300357873 9.977952611727977 C 18.026377250140843 10.255117972066083 18.360665295581274 10.393700787401574 18.751720354007386 10.393700787401574 C 19.142775412433497 10.393700787401574 19.477064901509287 10.255117972066083 19.754587851292257 9.977952611727977 Z M 22.78211062813974 6.954330564483882 C 23.05963357792271 6.677165204145776 23.198395876137486 6.3433070745993785 23.198395876137486 5.952755905511811 C 23.198395876137486 5.562204736424244 23.05963357792271 5.228346606877845 22.78211062813974 4.951181246539739 C 22.50458767835677 4.674015886201633 22.17029963291634 4.535433070866142 21.779244574490228 4.535433070866142 C 21.388189516064116 4.535433070866142 21.053900026988327 4.674015886201633 20.776377077205357 4.951181246539739 C 20.498854127422387 5.228346606877845 20.36009182920761 5.562204736424244 20.36009182920761 5.952755905511811 C 20.36009182920761 6.3433070745993785 20.498854127422387 6.677165204145776 20.776377077205357 6.954330564483882 C 21.053900026988327 7.2314959248219886 21.388189516064116 7.3700787401574805 21.779244574490228 7.3700787401574805 C 22.17029963291634 7.3700787401574805 22.50458767835677 7.2314959248219886 22.78211062813974 6.954330564483882 Z M 22.78211062813974 13.001575379859744 C 23.05963357792271 12.724410019521638 23.198395876137486 12.390551169087567 23.198395876137486 12 C 23.198395876137486 11.609448830912433 23.05963357792271 11.275590701366035 22.78211062813974 10.998425341027929 C 22.50458767835677 10.721259980689823 22.17029963291634 10.58267716535433 21.779244574490228 10.58267716535433 C 21.388189516064116 10.58267716535433 21.053900026988327 10.721259980689823 20.776377077205357 10.998425341027929 C 20.498854127422387 11.275590701366035 20.36009182920761 11.609448830912433 20.36009182920761 12 C 20.36009182920761 12.390551169087567 20.498854127422387 12.724410019521638 20.776377077205357 13.001575379859744 C 21.053900026988327 13.27874074019785 21.388189516064116 13.417322834645669 21.779244574490228 13.417322834645669 C 22.17029963291634 13.417322834645669 22.50458767835677 13.27874074019785 22.78211062813974 13.001575379859744 Z M 25.809633404987224 9.977952611727977 C 26.087156354770194 9.70078725138987 26.22591720934961 9.366929121843473 26.22591720934961 8.976377952755906 C 26.22591720934961 8.585826783668338 26.087156354770194 8.251968654121939 25.809633404987224 7.974803293783833 C 25.532110455204254 7.697637933445727 25.197820966128464 7.559055118110236 24.806765907702353 7.559055118110236 C 24.41571084927624 7.559055118110236 24.08142280383581 7.697637933445727 23.80389985405284 7.974803293783833 C 23.52637690426987 8.251968654121939 23.387616049690454 8.585826783668338 23.387616049690454 8.976377952755906 C 23.387616049690454 9.366929121843473 23.52637690426987 9.70078725138987 23.80389985405284 9.977952611727977 C 24.08142280383581 10.255117972066083 24.41571084927624 10.393700787401574 24.806765907702353 10.393700787401574 C 25.197820966128464 10.393700787401574 25.532110455204254 10.255117972066083 25.809633404987224 9.977952611727977 Z M 11.949254970414662 12.387402151513287 C 12.157397188391089 12.179528131259708 12.26146782368645 11.924409453324447 12.26146782368645 11.622047244094489 L 12.26146782368645 10.053543451264149 L 13.831995841630226 10.053543451264149 C 14.134748146383137 10.053543451264149 14.390195903997462 9.949606159540611 14.598338121973889 9.741732139287032 C 14.806480339950316 9.533858119033454 14.910551697063356 9.278740161985862 14.910551697063356 8.976377952755906 C 14.910551697063356 8.674015743525949 14.806480339950316 8.418897786478357 14.598338121973889 8.211023766224779 C 14.390195903997462 8.0031497459712 14.134748146383137 7.899212454247662 13.831995841630226 7.899212454247662 L 12.26146782368645 7.899212454247662 L 12.26146782368645 6.330708661417323 C 12.26146782368645 6.028346452187366 12.157397188391089 5.773228495139775 11.949254970414662 5.565354474886195 C 11.741112752438235 5.357480454632616 11.48566571664159 5.253543523352916 11.182913411888679 5.253543523352916 C 10.880161107135768 5.253543523352916 10.624713349521443 5.357480454632616 10.416571131545016 5.565354474886195 C 10.20842891356859 5.773228495139775 10.104358278273226 6.028346452187366 10.104358278273226 6.330708661417323 L 10.104358278273226 7.899212454247662 L 8.53383026032945 7.899212454247662 C 8.23107795557654 7.899212454247662 7.975630919779896 8.0031497459712 7.767488701803468 8.211023766224779 C 7.55934648382704 8.418897786478357 7.455275848531678 8.674015743525949 7.455275848531678 8.976377952755906 C 7.455275848531678 9.278740161985862 7.55934648382704 9.533858119033454 7.767488701803468 9.741732139287032 C 7.975630919779896 9.949606159540611 8.23107795557654 10.053543451264149 8.53383026032945 10.053543451264149 L 10.104358278273226 10.053543451264149 L 10.104358278273226 11.622047244094489 C 10.104358278273226 11.924409453324447 10.20842891356859 12.179528131259708 10.416571131545016 12.387402151513287 C 10.624713349521443 12.595276171766866 10.880161107135768 12.699213463490404 11.182913411888679 12.699213463490404 C 11.48566571664159 12.699213463490404 11.741112752438235 12.595276171766866 11.949254970414662 12.387402151513287 Z"
                                            }

                                            Behavior on fillColor {
                                                ColorAnimation {
                                                    duration: Theme.animationDuration
                                                    easing.type: Theme.easingStandard
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: currentTab = 0
                            }
                        }

                        Item {
                            id: news
                            height: 60
                            width: 60
                            visible: modCreationEnabled

                            property bool hovered: false

                            Rectangle {
                                id: rectangle_9
                                anchors.fill: parent
                                color: "transparent"
                                radius: 15
                            }

                            Item {
                                id: audio_file
                                anchors.centerIn: parent
                                height: 35
                                width: 35

                                Shape {
                                    id: audio_file_1
                                    x: 6.16
                                    y: 3.28
                                    height: 28.44
                                    width: 22.68

                                    ShapePath {
                                        id: audio_file_1_ShapePath0
                                        fillColor: currentTab === 1 ? "#d8fa00" : (news.hovered ? "#d8fa00" : "#ffffff")
                                        fillRule: ShapePath.WindingFill
                                        joinStyle: ShapePath.MiterJoin
                                        strokeColor: "#00000000"
                                        strokeStyle: ShapePath.SolidLine
                                        strokeWidth: 0.03

                                        PathSvg {
                                            id: audio_file_1_ShapePath0_PathSvg0
                                            path: "M 9.515625289143218 24.48177138964335 C 10.451389169609943 24.48177138964335 11.244357784345569 24.159722216427326 11.89453143758214 23.515625 C 12.544705090818711 22.871527783572674 12.86979159147409 22.08767340828975 12.86979159147409 21.16406222184499 L 12.86979159147409 15.403645833333332 L 17.13541693689994 15.403645833333332 L 17.13541693689994 12.596353888511658 L 11.447916708127986 12.596353888511658 L 11.447916708127986 18.44791750113169 C 11.168402820625932 18.22916749243935 10.86458337863374 18.068142916696765 10.536458360420543 17.964844306310017 C 10.208333342207347 17.86154569592327 9.870000578276139 17.80989666779836 9.521458895160459 17.80989666779836 C 8.575729676723675 17.80989666779836 7.779358356940505 18.13498316332698 7.1323444577320165 18.785156806310017 C 6.485087477118903 19.435330449293055 6.161458291424813 20.225260990361374 6.161458291424813 21.154948472976685 C 6.161458291424813 22.084635955591995 6.486545487467725 22.871527783572674 7.136719140704297 23.515625 C 7.786892793940869 24.159722216427326 8.579861408676493 24.48177138964335 9.515625289143218 24.48177138964335 Z M 2.734375043122331 28.4375 C 1.982361146777964 28.4375 1.3386284336455692 28.169773239642378 0.8031770341103089 27.63432184855143 C 0.26772563457504883 27.09887045746048 0 26.455138884484768 0 25.703125 L 0 2.734375 C 0 1.982361115515232 0.26772563457504883 1.338629542539517 0.8031770341103089 0.8031781514485676 C 1.3386284336455692 0.26772676035761833 1.982361146777964 0 2.734375043122331 0 L 14.255209392609459 0 L 22.67708396911621 8.403646250565846 L 22.67708396911621 25.703125 C 22.67708396911621 26.455138884484768 22.40935720453642 27.09887045746048 21.87390580500116 27.63432184855143 C 21.338454405465903 28.169773239642378 20.694722822338246 28.4375 19.94270892599388 28.4375 L 2.734375043122331 28.4375 Z M 12.90625075984743 9.770833750565846 L 19.94270892599388 9.770833750565846 L 12.90625075984743 2.734375 L 12.90625075984743 9.770833750565846 Z"
                                        }

                                        Behavior on fillColor {
                                            ColorAnimation {
                                                duration: Theme.animationDuration
                                                easing.type: Theme.easingStandard
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: currentTab = 1
                            }
                        }

                        Item {
                            id: conversion
                            height: 60
                            width: 60
                            visible: modCreationEnabled

                            property bool hovered: false

                            Rectangle {
                                id: rectangle_7
                                anchors.fill: parent
                                color: "transparent"
                                radius: 15
                            }

                            Item {
                                id: conversion_icon
                                anchors.centerIn: parent
                                height: 35
                                width: 35

                                Image {
                                    id: conversion_image
                                    anchors.fill: parent
                                    source: "../assets/ConversionPageIcon.png"
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                ColorOverlay {
                                    anchors.fill: parent
                                    source: conversion_image
                                    color: currentTab === 2 ? "#d8fa00" : (conversion.hovered ? "#d8fa00" : "#ffffff")
                                    cached: true

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.animationDuration
                                            easing.type: Theme.easingStandard
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: currentTab = 2
                            }
                        }

                        Item {
                            id: others
                            height: 60
                            width: 60

                            property bool hovered: false

                            Rectangle {
                                id: rectangle_6
                                anchors.fill: parent
                                color: "transparent"
                                radius: 15
                            }

                            Item {
                                id: iconly_Bold_Filter
                                anchors.centerIn: parent
                                height: 27
                                width: 30.37

                                Item {
                                    id: filter
                                    height: 27
                                    width: 30.37

                                    Shape {
                                        id: _vector
                                        height: 27
                                        width: 30.37

                                        ShapePath {
                                            id: _vector_ShapePath0
                                            fillColor: currentTab === 3 ? "#d8fa00" : (others.hovered ? "#d8fa00" : "#ffffff")
                                            fillRule: ShapePath.WindingFill
                                            joinStyle: ShapePath.MiterJoin
                                            strokeColor: "#00000000"
                                            strokeStyle: ShapePath.SolidLine
                                            strokeWidth: 1

                                            PathSvg {
                                                id: _vector_ShapePath0_PathSvg0
                                                path: "M 25.15221540344901 16.735964430047776 C 28.037824253720522 16.735964430047776 30.374998092651367 19.03380828413089 30.374998092651367 21.8688106957049 C 30.374998092651367 24.70215524067138 28.037824253720522 27 25.15221540344901 27 C 22.268294111811908 27 19.92943126585387 24.70215524067138 19.92943126585387 21.8688106957049 C 19.92943126585387 19.03380828413089 22.268294111811908 16.735964430047776 25.15221540344901 16.735964430047776 Z M 12.276493171855146 19.679889420037775 C 13.540423533182787 19.679889420037775 14.56641808475897 20.687890693899238 14.56641808475897 21.929654780404338 C 14.56641808475897 23.169761181351006 13.540423533182787 24.179420140770905 12.276493171855146 24.179420140770905 L 2.289924550805631 24.179420140770905 C 1.0259941894779898 24.179420140770905 0 23.169761181351006 0 21.929654780404338 C 0 20.687890693899238 1.0259941894779898 19.679889420037775 2.289924550805631 19.679889420037775 L 12.276493171855146 19.679889420037775 Z M 5.222783051300553 0 C 8.108391901572066 0 10.445566102601106 2.2978440351322154 10.445566102601106 5.131188580098696 C 10.445566102601106 7.966190991672706 8.108391901572066 10.264034845755823 5.222783051300553 10.264034845755823 C 2.3388617596634504 10.264034845755823 4.518884982224506e-14 7.966190991672706 4.518884982224506e-14 5.131188580098696 C 4.518884982224506e-14 2.2978440351322154 2.3388617596634504 0 5.222783051300553 0 Z M 28.086760557332855 2.8830812673887602 C 29.349003450550637 2.8830812673887602 30.374998092651367 3.8910822696765766 30.374998092651367 5.131188580098696 C 30.374998092651367 6.372952757128345 29.349003450550637 7.380953216268862 28.086760557332855 7.380953216268862 L 18.100192298381533 7.380953216268862 C 16.83626193705389 7.380953216268862 15.81026738547771 6.372952757128345 15.81026738547771 5.131188580098696 C 15.81026738547771 3.8910822696765766 16.83626193705389 2.8830812673887602 18.100192298381533 2.8830812673887602 L 28.086760557332855 2.8830812673887602 Z"
                                            }

                                            Behavior on fillColor {
                                                ColorAnimation {
                                                    duration: Theme.animationDuration
                                                    easing.type: Theme.easingStandard
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: currentTab = 3
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 87

                StackLayout {
                    anchors.fill: parent
                    currentIndex: currentTab

                    ModManagerPage {
                        id: modManagerPage
                    }

                    AudioBrowserPage {
                        id: audioBrowserPage
                    }

                    AudioConversionPage {
                        id: audioConversionPage
                    }

                    SettingsPage {
                        id: settingsPage
                    }
                }
            }
        }

        ImportWizard {
            id: importWizard
            anchors.fill: parent
            z: 999
        }

        ModInfoDialog {
            id: modInfoDialog
            anchors.fill: parent
            z: 998
        }

        CustomDialog {
            id: customDialog
            anchors.fill: parent
            z: 2000
            onConfirmed: {
                if (actionId !== "") {
                    mainWindow.dialogConfirmed(actionId)
                }
            }
            onCancelled: {
                if (actionId !== "") {
                    mainWindow.dialogCancelled(actionId)
                }
            }
        }

        WelcomeDialog {
            id: welcomeDialog
            anchors.fill: parent
            z: 1500
            onVisibleChanged: if (!visible) mainWindow._tryShowPendingTagDb()
        }

        SuccessDialog {
            id: successDialog
            anchors.fill: parent
            z: 2000
        }

        UpdateDialog {
            id: updateDialog
            objectName: "updateDialog"
            anchors.fill: parent
            z: 2100
        }

        ConflictResolutionDialog {
            id: conflictResolutionDialog
            anchors.fill: parent
            z: 2500
            property var modManager: null
            onResolved: {
                mainWindow.conflictsResolved()
            }
            onCancelled: {
                console.log("Conflict resolution cancelled by user")
            }
        }

        ModConflictDialog {
            id: modConflictDialog
            anchors.fill: parent
            z: 2500
            property var modManager: null
            onResolved: {
                mainWindow.conflictsResolved()
            }
            onCancelled: {
                console.log("Mod conflict resolution cancelled by user")
            }
        }

        Item {
            id: languageWarningDialog
            anchors.fill: parent
            z: 2500
            visible: false
            property string languagesText: ""
            property string moveableFoldersStr: ""
            property bool dontShowAgainChecked: false
            property bool closing: false
            property string movingFolder: ""

            function setLanguages(languages, moveable) {
                languagesText = languages
                moveableFoldersStr = moveable || ""
                movingFolder = ""
            }

            Timer {
                id: languageWarningHideTimer
                interval: 200
                onTriggered: {
                    languageWarningDialog.visible = false
                    languageWarningDialog.closing = false
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                opacity: (!languageWarningDialog.closing && languageWarningDialog.visible) ? 1.0 : 0.0
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
                    onClicked: {}
                }
            }

            Rectangle {
                id: languageWarningDialogBox
                width: Math.min(550, parent.width - 40)
                height: languageContentCol.height + 60
                anchors.centerIn: parent
                color: "#252525"
                radius: 20
                border.color: "#3c3d3f"
                border.width: 1
                scale: (!languageWarningDialog.closing && languageWarningDialog.visible) ? 1.0 : 0.9
                opacity: (!languageWarningDialog.closing && languageWarningDialog.visible) ? 1.0 : 0.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Column {
                    id: languageContentCol
                    width: parent.width - 60
                    anchors.centerIn: parent
                    spacing: 20

                    Item { height: 10; width: 1 }
                    Image {
                        source: "../assets/GraceFuck.png"
                        width: 240
                        height: 240
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: qsTranslate("Application", "Oops! We found some files in the wrong place!")
                        color: "#d8fa00"
                        font.family: "Alatsi"
                        font.pixelSize: 22
                        font.bold: false
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: qsTranslate("Application", "Some language audio folders are in the Persistent folder instead of StreamingAssets.")
                        color: "#ffffff"
                        font.family: "Alatsi"
                        font.pixelSize: 15
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.3
                    }

                    Rectangle {
                        width: parent.width
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 8
                        border.color: Qt.rgba(255, 255, 255, 0.1)
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: langFolderColumn.height + 20

                        Column {
                            id: langFolderColumn
                            width: parent.width - 20
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: qsTranslate("Application", "Folders that need to be moved:")
                                color: "#aaaaaa"
                                font.family: "Alatsi"
                                font.pixelSize: 13
                                width: parent.width
                            }

                            Repeater {
                                model: languageWarningDialog.moveableFoldersStr.length > 0
                                       ? languageWarningDialog.moveableFoldersStr.split(", ") : []

                                Rectangle {
                                    width: langFolderColumn.width
                                    height: 50
                                    radius: 8
                                    color: Qt.rgba(255, 255, 255, 0.05)

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        Text {
                                            text: "• " + modelData
                                            color: "#d8fa00"
                                            font.family: "Alatsi"
                                            font.pixelSize: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - (moveBtn.visible || movingIndicator.visible ? 185 : 0)
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            id: moveBtn
                                            visible: languageWarningDialog.movingFolder === ""
                                            width: 170
                                            height: 36
                                            radius: 8
                                            color: moveBtnMouse.pressed ? "#a0c800" : (moveBtnMouse.containsMouse ? "#e0ff20" : "#d8fa00")
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTranslate("Application", "Move to Streaming")
                                                color: "#000000"
                                                font.family: "Alatsi"
                                                font.pixelSize: 14
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: moveBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    languageWarningDialog.movingFolder = modelData
                                                    mainWindow.moveLanguageToStreaming(modelData)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: movingIndicator
                                            visible: languageWarningDialog.movingFolder === modelData
                                            width: 170
                                            height: 36
                                            radius: 8
                                            color: Qt.rgba(255, 255, 255, 0.1)
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTranslate("Application", "Moving...")
                                                color: "#aaaaaa"
                                                font.family: "Alatsi"
                                                font.pixelSize: 14
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: qsTranslate("Application", "ZZAR needs these folders in StreamingAssets to work properly. Click \"Move to Streaming\" to fix this automatically.")
                        color: "#aaaaaa"
                        font.family: "Alatsi"
                        font.pixelSize: 13
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                        lineHeight: 1.3
                    }

                    Text {
                        text: qsTranslate("Application", "If you experience any audio oddities after moving, please repair your game files.")
                        color: "#888888"
                        font.family: "Alatsi"
                        font.pixelSize: 12
                        font.italic: true
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                        lineHeight: 1.3
                    }

                    Row {
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: languageWarningDialog.dontShowAgainChecked ? Theme.primaryAccent : "#3c3d3f"
                            border.color: languageWarningDialog.dontShowAgainChecked ? Theme.primaryAccent : "#666666"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: Theme.textOnAccent
                                font.pixelSize: 14
                                font.bold: true
                                visible: languageWarningDialog.dontShowAgainChecked
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    languageWarningDialog.dontShowAgainChecked = !languageWarningDialog.dontShowAgainChecked
                                }
                            }
                        }

                        Text {
                            text: qsTranslate("Application", "Don't show this warning again")
                            color: "#ffffff"
                            font.family: "Alatsi"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    languageWarningDialog.dontShowAgainChecked = !languageWarningDialog.dontShowAgainChecked
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        Item { width: (parent.width - 150) / 2; height: 1 }

                        Rectangle {
                            width: 150
                            height: 45
                            color: Theme.primaryAccent
                            radius: Theme.radiusMedium
                            scale: understandMouse.pressed ? 0.97 : (understandMouse.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                            Text {
                                anchors.centerIn: parent
                                text: qsTranslate("Application", "Got it")
                                color: Theme.textOnAccent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeNormal
                            }

                            MouseArea {
                                id: understandMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mainWindow.languageWarningDontShowAgain(languageWarningDialog.dontShowAgainChecked)
                                    languageWarningDialog.closing = true
                                    languageWarningHideTimer.start()
                                    languageWarningDialog.dontShowAgainChecked = false
                                }
                            }
                        }

                        Item { width: (parent.width - 150) / 2; height: 1 }
                    }

                    Item { height: 5; width: 1 }
                }
            }
        }

        TutorialOverlay {
            id: tutorialOverlay
            anchors.fill: parent
            z: 3000
            modCreationEnabled: mainWindow.modCreationEnabled
            appRoot: mainContent
            onRequestPageChange: mainWindow.currentTab = tabIndex
            onTutorialFinished: {
                mainWindow.tutorialActive = false
                if (mainWindow.pendingLanguageWarning !== "") {
                    mainWindow.showMultipleLanguagesWarning(mainWindow.pendingLanguageWarning, mainWindow.pendingMoveableFolders)
                    mainWindow.pendingLanguageWarning = ""
                    mainWindow.pendingMoveableFolders = ""
                }
            }
        }

        Rectangle {
            id: toastContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -80
            width: toastContent.width + 50
            height: 70
            radius: 35
            color: "transparent"
            z: 1000

            Rectangle {
                id: toastBackground
                anchors.fill: parent
                radius: 35
                color: "#CDEE00"

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    radius: 35
                    color: "#60000000"
                    z: -1
                }
            }

            Row {
                id: toastContent
                anchors.centerIn: parent
                spacing: 15

                Text {
                    id: toastIcon
                    color: "#000000"
                    font.family: "Alatsi"
                    font.pixelSize: 28
                    font.bold: false
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: toastText
                    text: ""
                    color: "#000000"
                    font.family: "Alatsi"
                    font.pixelSize: 22
                    font.bold: false
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            SequentialAnimation {
                id: toastAnimation

                NumberAnimation {
                    target: toastContainer
                    property: "anchors.topMargin"
                    to: 100
                    duration: 350
                    easing.type: Easing.OutBack
                }

                PauseAnimation {
                    duration: 3500
                }

                NumberAnimation {
                    target: toastContainer
                    property: "anchors.topMargin"
                    to: -80
                    duration: 300
                    easing.type: Easing.InQuad
                }
            }
        }

        Item {
            id: loadingPopup
            anchors.fill: parent
            z: 2600
            visible: false

            property string message: qsTranslate("Application", "Processing...")
            property bool closing: false

            Timer {
                id: loadingHideTimer
                interval: 200
                onTriggered: {
                    loadingPopup.visible = false
                    loadingPopup.closing = false
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                opacity: (!loadingPopup.closing && loadingPopup.visible) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }
            }

            Rectangle {
                width: Math.min(340, parent.width - 40)
                height: loadingCol.height + 50
                anchors.centerIn: parent
                color: "#252525"
                radius: 20
                border.color: "#3c3d3f"
                border.width: 1
                scale: (!loadingPopup.closing && loadingPopup.visible) ? 1.0 : 0.9
                opacity: (!loadingPopup.closing && loadingPopup.visible) ? 1.0 : 0.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Column {
                    id: loadingCol
                    width: parent.width - 50
                    anchors.centerIn: parent
                    spacing: 18

                    Item {
                        width: 40
                        height: 40
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            id: spinner
                            width: 40
                            height: 40
                            radius: 20
                            color: "transparent"
                            border.color: "#3c3d3f"
                            border.width: 4

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: "transparent"
                                border.color: "#d8fa00"
                                border.width: 4

                                visible: false
                                layer.enabled: true
                                layer.effect: Item {}
                            }

                            Canvas {
                                id: spinnerArc
                                anchors.fill: parent
                                property real angle: 0

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.beginPath()
                                    ctx.arc(width / 2, height / 2, 18, angle, angle + Math.PI * 0.75)
                                    ctx.strokeStyle = "#d8fa00"
                                    ctx.lineWidth = 4
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }

                                NumberAnimation on angle {
                                    from: 0
                                    to: Math.PI * 2
                                    duration: 1000
                                    loops: Animation.Infinite
                                }

                                onAngleChanged: requestPaint()
                            }
                        }
                    }

                    Text {
                        text: loadingPopup.message
                        color: "#ffffff"
                        font.family: "Alatsi"
                        font.pixelSize: 17
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        DropArea {
            id: globalDropArea
            anchors.fill: parent
            z: 900

            onEntered: {
                var hasZzar = false
                if (drag.hasUrls) {
                    for (var i = 0; i < drag.urls.length; i++) {
                        if (drag.urls[i].toString().toLowerCase().endsWith(".zzar")) {
                            hasZzar = true
                            break
                        }
                    }
                }
                if (hasZzar) {
                    drag.accept()
                    mainWindow.isDraggingMod = true
                } else {
                    drag.accepted = false
                }
            }

            onExited: {
                mainWindow.isDraggingMod = false
            }

            onDropped: {
                mainWindow.isDraggingMod = false
                if (drop.hasUrls) {
                    var installed = 0
                    for (var i = 0; i < drop.urls.length; i++) {
                        var filePath = mainWindow.urlToLocalPath(drop.urls[i])
                        if (filePath.toLowerCase().endsWith(".zzar")) {
                            console.log("[Drag & Drop] Installing mod: " + filePath)
                            modManagerBackend.installMod(filePath)
                            installed++
                        }
                    }
                    if (installed > 0) {
                        currentTab = 0
                        drop.accept()
                    }
                }
            }
        }

        Rectangle {
            id: dropOverlay
            anchors.fill: parent
            z: 901
            visible: false
            opacity: 0
            color: "#CC131416"

            property bool showOverlay: mainWindow.isDraggingMod

            onShowOverlayChanged: {
                if (showOverlay) {
                    fadeOut.stop()
                    visible = true
                    fadeIn.start()
                } else {
                    fadeIn.stop()
                    fadeOut.start()
                }
            }

            NumberAnimation {
                id: fadeIn
                target: dropOverlay
                property: "opacity"
                to: 1.0
                duration: 200
                easing.type: Easing.OutQuad
            }

            SequentialAnimation {
                id: fadeOut
                NumberAnimation { target: dropOverlay; property: "opacity"; to: 0.0; duration: 250; easing.type: Easing.InQuad }
                ScriptAction { script: dropOverlay.visible = false }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 30
                color: "transparent"
                radius: 20
                border.color: "#d8fa00"
                border.width: 3

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        text: "\u2B07"
                        color: "#d8fa00"
                        font.pixelSize: 64
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: qsTranslate("Application", "Drop .zzar mod(s) here to install")
                        color: "#d8fa00"
                        font.family: "Alatsi"
                        font.pixelSize: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}

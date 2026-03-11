import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "."

Item {
    id: root
    objectName: "conflictResolutionDialog"
    visible: false
    anchors.fill: parent
    z: 2500

    property var conflicts: []
    property var resolutions: ({})
    property var modifiedConflicts: ({})
    property bool closing: false

    signal resolved()
    signal cancelled()

    function updateConflictWinner(conflictIndex, newWinner) {
        var conflict = conflicts[conflictIndex]
        var oldWinner = conflict.winner_mod

        var newLosers = []
        for (var i = 0; i < conflict.loser_mods.length; i++) {
            if (conflict.loser_mods[i] !== newWinner) {
                newLosers.push(conflict.loser_mods[i])
            }
        }
        newLosers.push(oldWinner)

        conflict.winner_mod = newWinner
        conflict.loser_mods = newLosers

        var key = conflict.pck + ":" + conflict.file_id
        modifiedConflicts[key] = newWinner

        var temp = conflicts
        conflicts = []
        conflicts = temp
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        opacity: (!closing && visible) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }

        Image {
            anchors.fill: parent
            source: "../assets/" + assetsDir + "/gradient.png"
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
        id: dialogBox
        anchors.centerIn: parent
        width: Math.min(700, parent.width - 80)
        height: Math.min(650, parent.height - 80)
        color: Theme.surfaceColor
        radius: Theme.radiusMedium
        border.color: Theme.backgroundColor
        border.width: 1
        scale: (!closing && visible) ? 1.0 : 0.9
        opacity: (!closing && visible) ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }

        Column {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20

            Row {
                width: parent.width
                spacing: 15

                Column {
                    width: parent.width - 100
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: qsTranslate("Application", "Mod Conflicts Detected")
                        color: Theme.primaryAccent
                        font.family: Theme.fontFamilyTitle
                        font.pixelSize: 22
                    }

                    Text {
                        text: root.conflicts.length + " " + (root.conflicts.length !== 1 ? qsTranslate("Application", "conflicts") : qsTranslate("Application", "conflict")) + " " + qsTranslate("Application", "found")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }

                    Text {
                        text: qsTranslate("Application", "Select which mod should be used for each sound")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: mainColumn.height - 170
                color: Theme.surfaceDark
                radius: 12
                border.color: Theme.backgroundColor
                border.width: 1

                ListView {
                    id: conflictsList
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    spacing: 10
                    model: root.conflicts

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: parent.pressed ? Theme.primaryAccent : (parent.hovered ? Qt.darker(Theme.primaryAccent, 1.2) : Theme.textSecondary)
                        }
                    }

                    delegate: Rectangle {
                        id: conflictCard
                        width: conflictsList.width - 16
                        height: cardCol.implicitHeight + 24
                        color: Theme.surfaceColor
                        radius: 12
                        border.color: Theme.backgroundColor
                        border.width: 1

                        property int conflictIndex: index

                        Column {
                            id: cardCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 10

                            Row {
                                width: parent.width
                                spacing: 10

                                Rectangle {
                                    width: 3
                                    height: 32
                                    color: Theme.primaryAccent
                                    radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    spacing: 2
                                    width: parent.width - 20

                                    Text {
                                        text: modelData.sound_name || qsTranslate("Application", "File ID: ") + modelData.file_id
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: modelData.pck
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 40
                                color: Qt.rgba(Theme.secondaryAccent.r, Theme.secondaryAccent.g, Theme.secondaryAccent.b, 0.1)
                                radius: 8
                                border.color: Theme.secondaryAccent
                                border.width: 1

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {
                                        text: "●"
                                        color: Theme.secondaryAccent
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.winner_mod
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item { width: 1; height: 1; Layout.fillWidth: true }

                                }
                            }

                            Repeater {
                                model: modelData.loser_mods

                                Rectangle {
                                    width: cardCol.width
                                    height: 38
                                    color: altMouse.containsMouse ? Qt.rgba(Theme.primaryAccent.r, Theme.primaryAccent.g, Theme.primaryAccent.b, 0.08) : "transparent"
                                    radius: 8
                                    border.color: altMouse.containsMouse ? Theme.primaryAccent : Theme.textSecondary
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        Text {
                                            text: "○"
                                            color: altMouse.containsMouse ? Theme.primaryAccent : Theme.textSecondary
                                            font.pixelSize: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Text {
                                            text: modelData
                                            color: altMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: altMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.updateConflictWinner(conflictCard.conflictIndex, modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 15
                layoutDirection: Qt.RightToLeft

                Rectangle {
                    width: 160
                    height: Theme.buttonHeightLarge
                    color: Theme.primaryAccent
                    radius: Theme.radiusMedium
                    scale: applyMouse.pressed ? 0.97 : (applyMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Application", "Apply & Save")
                        color: Theme.textOnAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                        font.bold: true
                    }

                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var prefs = []
                            for (var i = 0; i < root.conflicts.length; i++) {
                                var conflict = root.conflicts[i]
                                prefs.push({
                                    pck: conflict.pck,
                                    file_id: String(conflict.file_id),
                                    winner_mod: conflict.winner_mod
                                })
                            }

                            if (modManager) {
                                modManager.saveConflictPreferences(JSON.stringify(prefs))
                            }

                            root.closing = true
                            root.resolved()
                            Qt.callLater(function() {
                                root.visible = false
                                root.closing = false
                            })
                        }
                    }
                }

                Rectangle {
                    width: 120
                    height: Theme.buttonHeightLarge
                    color: Theme.disabledAccent
                    radius: Theme.radiusMedium
                    scale: cancelMouse.pressed ? 0.97 : (cancelMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Application", "Cancel")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closing = true
                            root.cancelled()
                            Qt.callLater(function() {
                                root.visible = false
                                root.closing = false
                            })
                        }
                    }
                }
            }
        }
    }

    function show(conflictList) {
        conflicts = conflictList
        resolutions = {}
        modifiedConflicts = {}
        visible = true
    }
}

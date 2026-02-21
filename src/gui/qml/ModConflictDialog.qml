import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "."

Item {
    id: root
    objectName: "modConflictDialog"
    visible: false
    anchors.fill: parent
    z: 2500

    property var modConflicts: []
    property var fileConflicts: []
    property bool closing: false

    signal resolved()
    signal cancelled()

    function updateModWinner(conflictIndex, newWinner) {
        var conflict = modConflicts[conflictIndex]
        conflict.winner_mod = newWinner

        var temp = modConflicts
        modConflicts = []
        modConflicts = temp
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        opacity: (!closing && visible) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }

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
        id: dialogBox
        anchors.centerIn: parent
        width: Math.min(600, parent.width - 80)
        height: Math.min(550, parent.height - 80)
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

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "Mod Conflicts Detected"
                    color: Theme.primaryAccent
                    font.family: Theme.fontFamilyTitle
                    font.pixelSize: 22
                }

                Text {
                    text: root.modConflicts.length + " conflict" + (root.modConflicts.length !== 1 ? "s" : "") + " between mods"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }

                Text {
                    text: "Select which mod should take priority for each conflict"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    width: parent.width
                    wrapMode: Text.WordWrap
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
                    model: root.modConflicts

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
                                        text: modelData.mods[0] + "  vs  " + modelData.mods[1]
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: modelData.conflict_count + " conflicting file" + (modelData.conflict_count !== 1 ? "s" : "")
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            Repeater {
                                model: modelData.mods

                                Rectangle {
                                    width: cardCol.width
                                    height: 40
                                    radius: 8

                                    property bool isWinner: modelData === root.modConflicts[conflictCard.conflictIndex].winner_mod

                                    color: isWinner
                                        ? Qt.rgba(Theme.secondaryAccent.r, Theme.secondaryAccent.g, Theme.secondaryAccent.b, 0.1)
                                        : (modMouse.containsMouse ? Qt.rgba(Theme.primaryAccent.r, Theme.primaryAccent.g, Theme.primaryAccent.b, 0.08) : "transparent")
                                    border.color: isWinner
                                        ? Theme.secondaryAccent
                                        : (modMouse.containsMouse ? Theme.primaryAccent : Theme.textSecondary)
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        Text {
                                            text: isWinner ? "●" : "○"
                                            color: isWinner ? Theme.secondaryAccent : (modMouse.containsMouse ? Theme.primaryAccent : Theme.textSecondary)
                                            font.pixelSize: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Text {
                                            text: modelData
                                            color: isWinner ? Theme.textPrimary : (modMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.bold: isWinner
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: modMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.updateModWinner(conflictCard.conflictIndex, modelData)
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
                        text: "Apply & Save"
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
                            for (var i = 0; i < root.modConflicts.length; i++) {
                                var modConflict = root.modConflicts[i]
                                for (var j = 0; j < modConflict.files.length; j++) {
                                    var file = modConflict.files[j]
                                    prefs.push({
                                        pck: file.pck,
                                        file_id: String(file.file_id),
                                        winner_mod: modConflict.winner_mod
                                    })
                                }
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
                        text: "Cancel"
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

    function show(modConflictList, fileConflictList) {
        modConflicts = modConflictList
        fileConflicts = fileConflictList
        visible = true
    }
}

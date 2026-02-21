
import QtQuick 2.15
import QtQuick.Controls 2.15
import "../qml"

Rectangle {
    id: modCard

    property string modName: "Mod Name"
    property string modVersion: "1.0.0"
    property string modAuthor: "Author"
    property string modDescription: "Description"
    property string thumbnailUrl: ""
    property bool isEnabled: false

    signal enabledToggled(bool enabled)
    signal moreInfoClicked()

    implicitHeight: Theme.modCardHeight
    implicitWidth: parent.width
    color: Theme.cardBackground
    radius: Theme.radiusLarge

    state: mouseArea.containsMouse ? "hovered" : "normal"
    states: [
        State {
            name: "normal"
            PropertyChanges { target: modCard; scale: 1.0 }
        },
        State {
            name: "hovered"
            PropertyChanges { target: modCard; scale: 1.005 }
        }
    ]

    transitions: Transition {
        NumberAnimation { properties: "scale"; duration: Theme.animationDuration; easing.type: Theme.easingStandard }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onPressed: mouse.accepted = false
    }

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 0

        Rectangle {
            width: Theme.modThumbnailSize
            height: Theme.modThumbnailSize
            color: "#333"
            radius: 12

            Image {
                anchors.fill: parent
                anchors.margins: 4
                source: thumbnailUrl
                fillMode: Image.PreserveAspectCrop
                mipmap: true
                smooth: true
                visible: thumbnailUrl !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "No\nImage"
                color: "#888"
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                visible: thumbnailUrl === ""
            }
        }

        Column {
            width: parent.width - Theme.modThumbnailSize - 140 - 16
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 10
            spacing: 3.5

            Text {
                text: modName + " v" + modVersion
                color: Theme.textOnAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                elide: Text.ElideRight
                width: parent.width - parent.leftPadding
            }

            Text {
                text: "By: " + modAuthor
                color: Theme.textTertiary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                elide: Text.ElideRight
                width: parent.width - parent.leftPadding
            }

            Text {
                text: modDescription
                color: Theme.textTertiary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                elide: Text.ElideRight
                width: parent.width - parent.leftPadding
                wrapMode: Text.NoWrap
            }
        }

        Column {
            width: 121
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 8
            spacing: 9

            Rectangle {
                width: 121
                height: Theme.buttonHeightLarge
                color: isEnabled ? Theme.secondaryAccent : Theme.disabledAccent
                radius: Theme.radiusMedium

                Text {
                    anchors.centerIn: parent
                    text: isEnabled ? "Enabled" : "Disabled"
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                }

                scale: enableMouseArea.pressed ? 0.97 : (enableMouseArea.containsMouse ? 1.03 : 1.0)
                Behavior on scale {
                    NumberAnimation { duration: Theme.animationDuration }
                }

                MouseArea {
                    id: enableMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        isEnabled = !isEnabled
                        enabledToggled(isEnabled)
                    }
                }
            }

            Rectangle {
                width: 121
                height: Theme.buttonHeight
                color: Theme.primaryAccent
                radius: Theme.radiusMedium

                Text {
                    anchors.centerIn: parent
                    text: "More info"
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                }

                scale: infoMouseArea.pressed ? 0.97 : (infoMouseArea.containsMouse ? 1.03 : 1.0)
                Behavior on scale {
                    NumberAnimation { duration: Theme.animationDuration }
                }

                MouseArea {
                    id: infoMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: moreInfoClicked()
                }
            }
        }
    }
}

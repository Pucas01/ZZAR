
import QtQuick 2.15
import QtQuick.Controls 2.15
import "../qml"

Rectangle {
    id: navButton

    property bool isActive: false
    property Item iconContent: null

    signal clicked()

    implicitWidth: 68
    implicitHeight: 68

    color: Theme.surfaceDark
    radius: 18

    Item {
        anchors.fill: parent

        Loader {
            anchors.fill: parent
            sourceComponent: iconContent ? iconContentComponent : null
        }
    }

    Component {
        id: iconContentComponent
        Item {
            anchors.fill: parent
            children: [navButton.iconContent]
            Component.onCompleted: {
                if (navButton.iconContent) {
                    navButton.iconContent.parent = this
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.primaryAccent
        border.width: isActive ? 3 : 0
        radius: parent.radius
    }

    scale: mouseArea.pressed ? 0.95 : (mouseArea.containsMouse ? 1.05 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: Theme.animationDuration; easing.type: Theme.easingStandard }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: navButton.clicked()
    }
}


import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15
import "../qml"

MenuItem {
    id: control

    implicitWidth: Math.max(200, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: 36

    leftPadding: Theme.spacingMedium
    rightPadding: Theme.spacingMedium
    topPadding: Theme.spacingSmall
    bottomPadding: Theme.spacingSmall

    contentItem: Text {
        text: control.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: control.highlighted ? Theme.textOnAccent : Theme.textPrimary
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight

        Behavior on color {
            ColorAnimation { duration: Theme.animationDuration }
        }
    }

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 36
        color: control.highlighted ? Theme.primaryAccent : "transparent"
        radius: Theme.radiusSmall

        Behavior on color {
            ColorAnimation { duration: Theme.animationDuration }
        }

        scale: control.pressed ? 0.98 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Theme.easingStandard }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse.accepted = false
        hoverEnabled: true
    }
}

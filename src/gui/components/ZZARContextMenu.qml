
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15
import "../qml"

Menu {
    id: control

    delegate: MenuItem {
        id: menuItem

        implicitWidth: Math.max(200, contentItem.implicitWidth + leftPadding + rightPadding)
        implicitHeight: 36

        leftPadding: Theme.spacingMedium
        rightPadding: Theme.spacingMedium

        contentItem: Text {
            text: menuItem.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: menuItem.highlighted ? Theme.textOnAccent : Theme.textPrimary
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter

            Behavior on color {
                ColorAnimation { duration: Theme.animationDuration }
            }
        }

        background: Rectangle {
            implicitWidth: 200
            implicitHeight: 36
            color: menuItem.highlighted ? Theme.primaryAccent : "transparent"
            radius: Theme.radiusSmall

            Behavior on color {
                ColorAnimation { duration: Theme.animationDuration }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse.accepted = false
            hoverEnabled: true
        }
    }

    background: Rectangle {
        implicitWidth: 200
        color: Theme.surfaceColor
        border.color: Theme.cardBackground
        border.width: 1
        radius: Theme.radiusSmall

        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 4
            radius: 12
            samples: 16
            color: "#80000000"
            transparentBorder: true
        }
    }

    Component.onCompleted: {
        for (var i = 0; i < count; i++) {
            var item = itemAt(i)
            if (item && item.toString().indexOf("MenuSeparator") >= 0) {
                item.topPadding = Theme.spacingSmall
                item.bottomPadding = Theme.spacingSmall
                item.contentItem.implicitHeight = 1
                item.contentItem.implicitWidth = 200
                item.contentItem.color = Theme.cardBackground
            }
        }
    }
}

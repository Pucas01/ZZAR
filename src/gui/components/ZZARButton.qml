import QtQuick 2.15
import QtQuick.Controls 2.15
import "../qml"

Button {
    id: control

    property color buttonColor: Theme.primaryAccent
    property color textColor: Theme.textOnAccent
    property int buttonRadius: Theme.radiusMedium
    property int fontSize: Theme.fontSizeMedium
    property bool isLarge: false
    property bool isHuge: false

    implicitHeight: isHuge ? Theme.buttonHeightHuge : (isLarge ? Theme.buttonHeightLarge : Theme.buttonHeight)
    implicitWidth: contentItem.implicitWidth + Theme.spacingMedium * 2

    background: Rectangle {
        color: control.down ? Qt.darker(buttonColor, 1.1) :
               control.hovered ? Qt.lighter(buttonColor, 1.1) : buttonColor
        radius: buttonRadius

        Behavior on color {
            ColorAnimation { duration: Theme.animationDuration }
        }

        scale: control.down ? 0.97 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Theme.animationDuration; easing.type: Theme.easingStandard }
        }
    }

    contentItem: Text {
        text: control.text
        font.family: Theme.fontFamily
        font.pixelSize: fontSize
        color: textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse.accepted = false
    }
}

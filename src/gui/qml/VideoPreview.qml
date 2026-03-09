import QtQuick 2.15
import "."

Item {
    id: root

    property string videoSource: ""
    property bool isVideoMedia: false

    function stopVideo() {}

    Rectangle {
        anchors.fill: parent
        color: "#1A1A1A"
        visible: root.isVideoMedia

        Text {
            anchors.centerIn: parent
            text: "\u25B6"
            color: Theme.textSecondary
            font.pixelSize: 20
        }
    }
}

import QtQuick 2.15
import QtMultimedia 5.15
import "."

Item {
    id: root

    property string videoSource: ""
    property bool isVideoMedia: false

    function stopVideo() {
        video.stop()
    }

    Video {
        id: video
        anchors.fill: parent
        source: root.videoSource
        fillMode: VideoOutput.PreserveAspectFit
        autoPlay: true
        loops: MediaPlayer.Infinite
        muted: true
        visible: root.isVideoMedia

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (video.playbackState === MediaPlayer.PlayingState)
                    video.pause()
                else
                    video.play()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 48; height: 48; radius: 24
            color: "#99000000"
            visible: video.playbackState !== MediaPlayer.PlayingState && root.isVideoMedia

            Text {
                anchors.centerIn: parent
                text: "\u25B6"
                color: Theme.textPrimary
                font.pixelSize: 20
            }
        }
    }
}

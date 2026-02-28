import QtQuick 2.0

Slide {
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#1a1b26"

        Column {
            anchors.centerIn: parent
            spacing: 30

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Welcome to BlazeNeuro"
                font.pixelSize: 36
                font.bold: true
                color: "#c0caf5"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "A Debian-based Linux distribution\ndesigned to ignite your workflow."
                font.pixelSize: 18
                color: "#a9b1d6"
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Installing..."
                font.pixelSize: 14
                color: "#7aa2f7"
            }
        }
    }
}

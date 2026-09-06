import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property string message: qsTr("Loading...")

    implicitWidth: 200 * Theme.scale
    implicitHeight: 120 * Theme.scale

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.space16

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 36 * Theme.scale
            height: 36 * Theme.scale
            radius: 18 * Theme.scale
            color: "transparent"
            border.color: Theme.accentPrimary
            border.width: 3 * Theme.scale

            Rectangle {
                width: 10 * Theme.scale
                height: 10 * Theme.scale
                radius: 5 * Theme.scale
                color: Theme.accentPrimary
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
            }

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.visible
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.message
            font.pixelSize: Theme.sizeBody
            color: Theme.textSecondary
        }
    }
}

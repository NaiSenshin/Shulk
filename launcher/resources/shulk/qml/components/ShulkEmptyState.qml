import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property url iconSource: "qrc:/shulk/icons/chest.png"
    property string title: qsTr("Nothing here yet")
    property string description: qsTr("Add or download content to get started.")
    property string actionText: ""
    signal actionClicked()

    implicitWidth: 400 * Theme.scale
    implicitHeight: 250 * Theme.scale

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.space16
        width: Math.min(parent.width - Theme.space32, 420 * Theme.scale)

        BorderImage {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64 * Theme.scale
            Layout.preferredHeight: 64 * Theme.scale
            source: "qrc:/shulk/assets/mc/gui/slot.png"
            border { left: 4; top: 4; right: 4; bottom: 4 }
            smooth: false

            Image {
                anchors.fill: parent
                anchors.margins: 8
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: false
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            font.pixelSize: Theme.sizeTitle
            font.bold: true
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.description
            font.pixelSize: Theme.sizeBody
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        ShulkButton {
            visible: root.actionText.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space8
            text: root.actionText
            isPrimary: true
            onClicked: root.actionClicked()
        }
    }
}

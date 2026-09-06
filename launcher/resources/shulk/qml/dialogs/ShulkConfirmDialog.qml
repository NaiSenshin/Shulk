import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

ShulkDialog {
    id: root

    preferredWidth: 600 * Theme.scale
    preferredHeight: 300 * Theme.scale
    closeOnBackdropClick: false

    property string message: ""
    property string confirmText: qsTr("Delete")
    property string cancelText: qsTr("Cancel")
    property bool isDestructive: true

    signal confirmed()
    signal cancelled()

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(116 * Theme.scale, warningContent.implicitHeight + Theme.space24)
            radius: Theme.radiusMd
            color: root.isDestructive ? "#30171312" : Theme.bgSurfaceRaised
            border.color: root.isDestructive ? "#8FA93630" : Theme.borderSubtle
            border.width: 1

            RowLayout {
                id: warningContent
                anchors.fill: parent
                anchors.margins: Theme.space16
                spacing: Theme.space16

                Rectangle {
                    Layout.preferredWidth: 54 * Theme.scale
                    Layout.preferredHeight: 54 * Theme.scale
                    radius: Theme.radiusSm
                    color: root.isDestructive ? "#5AA93630" : Theme.bgDeep
                    border.color: root.isDestructive ? "#A9C8463E" : Theme.borderSubtle
                    border.width: 1

                    Image {
                        anchors.centerIn: parent
                        width: 34 * Theme.scale
                        height: 34 * Theme.scale
                        source: "qrc:/shulk/icons/redstone.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space6

                    Text {
                        Layout.fillWidth: true
                        text: root.isDestructive ? qsTr("PERMANENT ACTION") : qsTr("CONFIRM ACTION")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2 * Theme.scale
                        color: root.isDestructive ? "#FF8A80" : Theme.textSecondary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.message
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeBody
                        color: Theme.textPrimary
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            ShulkButton {
                id: cancelBtn
                Layout.fillWidth: true
                implicitHeight: 46 * Theme.scale
                text: root.cancelText
                variant: "secondary"
                activeFocusOnTab: true
                isFocused: root.focusIndex === 0
                onClicked: {
                    root.cancelled()
                    root.close()
                }
            }

            ShulkButton {
                id: confirmBtn
                Layout.fillWidth: true
                implicitHeight: 46 * Theme.scale
                text: root.confirmText
                variant: root.isDestructive ? "danger" : "play"
                activeFocusOnTab: true
                isFocused: root.focusIndex === 1
                onClicked: {
                    root.confirmed()
                    root.close()
                }
            }
        }
    }

    property int focusIndex: 0 // 0: cancel, 1: confirm

    function handleAction(action) {
        if (action === Theme.actionBack) {
            root.cancelled()
            root.close()
            return
        }
        if (action === Theme.actionLeft || action === Theme.actionUp) {
            focusIndex = 0
            cancelBtn.forceActiveFocus()
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        } else if (action === Theme.actionRight || action === Theme.actionDown) {
            focusIndex = 1
            confirmBtn.forceActiveFocus()
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        } else if (action === Theme.actionAccept) {
            if (focusIndex === 1) {
                confirmBtn.triggerClick()
            } else {
                cancelBtn.triggerClick()
            }
        }
    }

    onOpacityChanged: {
        if (opacity === 1) {
            focusIndex = 0
            cancelBtn.forceActiveFocus()
        }
    }
}

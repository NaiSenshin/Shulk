import QtQuick
import QtQuick.Layouts
import "../theme"

FocusScope {
    id: root

    property alias dialogTitle: titleText.text
    property alias contentItem: contentContainer.data
    property bool closeOnBackdropClick: true
    property real preferredWidth: 560 * Theme.scale
    property real preferredHeight: 0

    signal closed()

    anchors.fill: parent
    visible: opacity > 0
    opacity: 0

    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    // Modal background dimmer
    Rectangle {
        anchors.fill: parent
        color: "#B0000000"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.closeOnBackdropClick) {
                    root.close()
                }
            }
        }
    }

    // Centered launcher dialog
    Rectangle {
        id: dialogBox
        width: Math.min(parent.width - Theme.space32, root.preferredWidth)
        height: Math.min(parent.height - Theme.space32,
                         root.preferredHeight > 0
                         ? root.preferredHeight
                         : Math.max(220 * Theme.scale, contentColumn.implicitHeight + Theme.space48))
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bgSurface
        border.color: Theme.borderStrong
        border.width: 1

        scale: root.opacity
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
        }

        MouseArea {
            anchors.fill: parent
            // Eat clicks so clicking the dialog doesn't close it
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: Theme.space20
            spacing: Theme.space16

            // Header
            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                    height: titleText.implicitHeight

                    Text {
                        id: titleText
                        anchors.fill: parent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSubheading
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                }

                Rectangle {
                    width: 32 * Theme.scale
                    height: 32 * Theme.scale
                    radius: 2
                    color: closeMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurfaceRaised
                    border.color: closeMouse.containsMouse ? Theme.borderFocused : Theme.borderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "X"
                        font.pixelSize: 14 * Theme.scale
                        font.bold: true
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.borderSubtle
            }

            // Content
            Item {
                id: contentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    function open() {
        if (typeof shulkSound !== "undefined") {
            shulkSound.playOpen()
        }
        root.opacity = 1
        root.forceActiveFocus()
    }

    function close() {
        if (typeof shulkSound !== "undefined") {
            shulkSound.playDismiss()
        }
        root.opacity = 0
        root.closed()
    }

    Keys.onEscapePressed: (event) => {
        root.close()
        event.accepted = true
    }

    Keys.onBackPressed: (event) => {
        root.close()
        event.accepted = true
    }
}

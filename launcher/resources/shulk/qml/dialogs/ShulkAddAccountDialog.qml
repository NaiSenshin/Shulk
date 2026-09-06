// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"
import "../components"

ShulkDialog {
    id: root

    dialogTitle: qsTr("Microsoft Account Sign-In")

    // Focus Index: 0: Copy Code, 1: Open Browser, 2: Cancel / Close
    property int focusIndex: 0

    Connections {
        target: shulkAccounts
        function onLoginSuccessChanged() {
            if (shulkAccounts.loginSuccess) {
                if (typeof shulkSound !== "undefined") {
                    shulkSound.playLevelUp()
                }
                root.close()
            }
        }
    }

    onOpacityChanged: {
        if (opacity === 1) {
            focusIndex = 0
            shulkAccounts.startMicrosoftLogin()
        }
    }

    onClosed: {
        shulkAccounts.cancelMicrosoftLogin()
        focusIndex = 0
    }

    function handleAction(action) {
        if (action === Theme.actionBack) {
            shulkAccounts.cancelMicrosoftLogin()
            root.close()
            return
        }

        if (action === Theme.actionLeft || action === Theme.actionUp) {
            focusIndex = (focusIndex + 2) % 3
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        } else if (action === Theme.actionRight || action === Theme.actionDown) {
            focusIndex = (focusIndex + 1) % 3
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        } else if (action === Theme.actionAccept) {
            if (focusIndex === 0) {
                if (shulkAccounts.loginCode.length > 0) {
                    shulkAccounts.copyLoginCode()
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                } else if (shulkAccounts.loginError.length > 0) {
                    shulkAccounts.startMicrosoftLogin()
                }
            } else if (focusIndex === 1) {
                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                shulkAccounts.openBrowserLink()
            } else {
                root.close()
            }
        }
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space16

        // Subtitle Banner
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            Rectangle {
                Layout.preferredWidth: 36 * Theme.scale
                Layout.preferredHeight: 36 * Theme.scale
                radius: 4
                color: "#18191E"
                border.color: "#0F1012"
                border.width: 1

                Image {
                    anchors.centerIn: parent
                    source: "qrc:/shulk/icons/grass_block.png"
                    width: 22 * Theme.scale
                    height: 22 * Theme.scale
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: qsTr("Official Minecraft Authentication")
                    font.pixelSize: Theme.sizeBody
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: qsTr("Sign in via device code on any phone, PC, or tablet.")
                    font.pixelSize: Theme.sizeCaption
                    color: Theme.textSecondary
                }
            }
        }

        // Step 1: Open URL
        Rectangle {
            Layout.fillWidth: true
            height: 52 * Theme.scale
            radius: 4
            color: "#161820"
            border.color: (root.focusIndex === 1) ? Theme.focusRing : "#0D0E12"
            border.width: (root.focusIndex === 1) ? 2 : 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.space12
                spacing: Theme.space12

                Text {
                    text: qsTr("1. Visit:")
                    font.pixelSize: Theme.sizeCaption
                    color: Theme.textSecondary
                }

                Text {
                    Layout.fillWidth: true
                    text: shulkAccounts.loginUrl
                    font.pixelSize: Theme.sizeBody
                    font.bold: true
                    color: Theme.mcDiamond
                }

                ShulkButton {
                    text: qsTr("Open Browser")
                    variant: "secondary"
                    isFocused: root.focusIndex === 1
                    implicitHeight: 32 * Theme.scale
                    onClicked: shulkAccounts.openBrowserLink()
                }
            }
        }

        // Step 2: Giant Code Box
        Rectangle {
            Layout.fillWidth: true
            height: 72 * Theme.scale
            radius: 5
            color: "#13151C"
            border.color: (root.focusIndex === 0) ? Theme.focusRing : "#FFAA00"
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.space14
                spacing: Theme.space16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: qsTr("2. Enter Code:")
                        font.pixelSize: Theme.sizeSmall
                        color: Theme.textMuted
                    }

                    Text {
                        Layout.fillWidth: true
                        text: shulkAccounts.loginCode.length > 0 ? shulkAccounts.loginCode : qsTr("GENERATING CODE...")
                        font.pixelSize: 26 * Theme.scale
                        font.bold: true
                        color: "#FFAA00"
                        font.letterSpacing: 2 * Theme.scale
                    }
                }

                ShulkButton {
                    id: copyCodeBtn
                    text: qsTr("Copy Code")
                    variant: "play"
                    isFocused: root.focusIndex === 0
                    visible: shulkAccounts.loginCode.length > 0
                    implicitHeight: 36 * Theme.scale
                    onClicked: shulkAccounts.copyLoginCode()
                }
            }
        }

        // Live Status Indicator
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space10

            Rectangle {
                width: 10 * Theme.scale
                height: 10 * Theme.scale
                radius: 5 * Theme.scale
                color: shulkAccounts.loginError.length > 0 ? Theme.mcRedstone : Theme.mcEmerald

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                Layout.fillWidth: true
                text: shulkAccounts.loginStatus
                font.pixelSize: Theme.sizeCaption
                color: shulkAccounts.loginError.length > 0 ? Theme.mcRedstone : Theme.textSecondary
                elide: Text.ElideRight
            }
        }

        // Error message card if error occurred
        Rectangle {
            visible: shulkAccounts.loginError.length > 0
            Layout.fillWidth: true
            height: errorText.implicitHeight + Theme.space16
            radius: 3
            color: "#3B1414"
            border.color: Theme.mcRedstone
            border.width: 1

            Text {
                id: errorText
                anchors.fill: parent
                anchors.margins: Theme.space8
                text: shulkAccounts.loginError
                font.pixelSize: Theme.sizeCaption
                color: "#FF8888"
                wrapMode: Text.Wrap
            }
        }

        Item { Layout.preferredHeight: Theme.space4 }

        // Action Buttons Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            Item { Layout.fillWidth: true }

            ShulkButton {
                text: qsTr("Cancel (B)")
                variant: "secondary"
                isFocused: root.focusIndex === 2
                onClicked: root.close()
            }
        }
    }
}

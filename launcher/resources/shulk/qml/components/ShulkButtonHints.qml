// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    property string primaryAction: qsTr("Select")
    property alias primaryHintText: root.primaryAction
    property string secondaryAction: qsTr("Back")
    property alias secondaryHintText: root.secondaryAction
    property string playAction: qsTr("Quick Play")
    property string searchAction: qsTr("Search")
    property string menuAction: qsTr("Options")
    property string extraAction: ""
    property bool showBack: false

    implicitHeight: 48 * Theme.scale
    color: "#F20C0D0E"
    border.color: Theme.borderSubtle
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space24
        anchors.rightMargin: Theme.space24
        spacing: Theme.space24

        // Action Hints Row
        Row {
            spacing: Theme.space20
            Layout.alignment: Qt.AlignVCenter

            // A Button Hint
            Row {
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "a" }
                Text { text: root.primaryAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }

            // B Button Hint (When back is valid)
            Row {
                visible: root.showBack
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "b" }
                Text { text: root.secondaryAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }

            // X Button Hint
            Row {
                visible: root.playAction !== ""
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "x" }
                Text { text: root.playAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }

            // Y Button Hint
            Row {
                visible: root.searchAction !== ""
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "y" }
                Text { text: root.searchAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }

            // Start / Menu Button Hint
            Row {
                visible: root.menuAction !== ""
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "menu" }
                Text {
                    text: root.menuAction
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeBody
                    color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Extra Hint (e.g. LT / RT Switch Source)
            Row {
                visible: root.extraAction !== ""
                spacing: Theme.space8
                Row {
                    spacing: 2 * Theme.scale
                    ShulkControllerGlyph { glyph: "lt" }
                    ShulkControllerGlyph { glyph: "rt" }
                }
                Text { text: root.extraAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeCaption; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Item { Layout.fillWidth: true }

        // Status text / brand subtitle
        Text {
            text: typeof shulkLauncher !== "undefined" && shulkLauncher.statusMessage !== ""
                  ? shulkLauncher.statusMessage
                  : qsTr("Minecraft: Java Edition  |  Shulk for handhelds")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sizeSmall
            color: Theme.textMuted
            Layout.alignment: Qt.AlignVCenter
        }
    }
}

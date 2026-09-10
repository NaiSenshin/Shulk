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
                Item {
                    implicitWidth: aHintText.implicitWidth
                    implicitHeight: aHintText.implicitHeight
                    readonly property int off: Theme.getShadowOffset(aHintText.font.pixelSize)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { x: parent.off; y: parent.off; text: aHintText.text; font: aHintText.font; color: Theme.getShadowColor(aHintText.color) }
                    Text { id: aHintText; x: 0; y: 0; text: root.primaryAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary }
                }
            }

            // B Button Hint (When back is valid)
            Row {
                visible: root.showBack
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "b" }
                Item {
                    implicitWidth: bHintText.implicitWidth
                    implicitHeight: bHintText.implicitHeight
                    readonly property int off: Theme.getShadowOffset(bHintText.font.pixelSize)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { x: parent.off; y: parent.off; text: bHintText.text; font: bHintText.font; color: Theme.getShadowColor(bHintText.color) }
                    Text { id: bHintText; x: 0; y: 0; text: root.secondaryAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary }
                }
            }

            // X Button Hint
            Row {
                visible: root.playAction !== ""
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "x" }
                Item {
                    implicitWidth: xHintText.implicitWidth
                    implicitHeight: xHintText.implicitHeight
                    readonly property int off: Theme.getShadowOffset(xHintText.font.pixelSize)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { x: parent.off; y: parent.off; text: xHintText.text; font: xHintText.font; color: Theme.getShadowColor(xHintText.color) }
                    Text { id: xHintText; x: 0; y: 0; text: root.playAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary }
                }
            }

            // Y Button Hint
            Row {
                visible: root.searchAction !== ""
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "y" }
                Item {
                    implicitWidth: yHintText.implicitWidth
                    implicitHeight: yHintText.implicitHeight
                    readonly property int off: Theme.getShadowOffset(yHintText.font.pixelSize)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { x: parent.off; y: parent.off; text: yHintText.text; font: yHintText.font; color: Theme.getShadowColor(yHintText.color) }
                    Text { id: yHintText; x: 0; y: 0; text: root.searchAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary }
                }
            }

            // Start / Menu Button Hint
            Row {
                visible: root.menuAction !== ""
                spacing: Theme.space8
                ShulkControllerGlyph { glyph: "menu" }
                Item {
                    implicitWidth: menuHintText.implicitWidth
                    implicitHeight: menuHintText.implicitHeight
                    readonly property int off: Theme.getShadowOffset(menuHintText.font.pixelSize)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { x: parent.off; y: parent.off; text: menuHintText.text; font: menuHintText.font; color: Theme.getShadowColor(menuHintText.color) }
                    Text { id: menuHintText; x: 0; y: 0; text: root.menuAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; color: Theme.textSecondary }
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
                Item {
                    implicitWidth: extraHintText.implicitWidth
                    implicitHeight: extraHintText.implicitHeight
                    readonly property int off: Theme.getShadowOffset(extraHintText.font.pixelSize)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { x: parent.off; y: parent.off; text: extraHintText.text; font: extraHintText.font; color: Theme.getShadowColor(extraHintText.color) }
                    Text { id: extraHintText; x: 0; y: 0; text: root.extraAction; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeCaption; color: Theme.textSecondary }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Status text / brand subtitle
        Item {
            implicitWidth: statusTextItem.implicitWidth
            implicitHeight: statusTextItem.implicitHeight
            readonly property int sOff: Theme.getShadowOffset(statusTextItem.font.pixelSize)
            Layout.alignment: Qt.AlignVCenter

            Text {
                x: parent.sOff
                y: parent.sOff
                text: statusTextItem.text
                font: statusTextItem.font
                color: Theme.getShadowColor(statusTextItem.color)
            }

            Text {
                id: statusTextItem
                x: 0; y: 0
                text: typeof shulkLauncher !== "undefined" && shulkLauncher.statusMessage !== ""
                      ? shulkLauncher.statusMessage
                      : qsTr("Minecraft: Java Edition | Shulk %1").arg(typeof shulkLauncher !== "undefined" ? shulkLauncher.appVersion : "1.1.0")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeSmall
                color: Theme.textMuted
            }
        }
    }
}

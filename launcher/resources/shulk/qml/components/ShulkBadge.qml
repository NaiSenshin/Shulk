// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import "../theme"

Rectangle {
    id: root

    property string text: ""
    property color badgeColor: "#2B2D2E"
    property color textColor: Theme.textSecondary
    property bool isAccent: false

    implicitWidth: badgeText.implicitWidth + 14 * Theme.scale
    implicitHeight: 22 * Theme.scale
    radius: Theme.radiusSm
    color: isAccent ? "#243420" : badgeColor
    border.color: isAccent ? "#47683D" : Theme.borderSubtle
    border.width: 1

    Item {
        readonly property int badgeOffset: Theme.getShadowOffset(badgeText.font.pixelSize)
        anchors.centerIn: parent
        width: badgeText.implicitWidth
        height: badgeText.implicitHeight

        Text {
            x: parent.badgeOffset
            y: parent.badgeOffset
            text: root.text
            font.pixelSize: Theme.sizeSmall
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            color: Theme.getShadowColor(badgeText.color)
        }

        Text {
            id: badgeText
            x: 0
            y: 0
            text: root.text
            font.pixelSize: Theme.sizeSmall
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            color: isAccent ? "#9BD38B" : root.textColor
        }
    }
}

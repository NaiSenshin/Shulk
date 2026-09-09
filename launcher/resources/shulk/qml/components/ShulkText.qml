// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import "../theme"

Item {
    id: root

    // Proxy standard Text properties
    property alias text: mainText.text
    property alias color: mainText.color
    property alias font: mainText.font
    property alias horizontalAlignment: mainText.horizontalAlignment
    property alias verticalAlignment: mainText.verticalAlignment
    property alias wrapMode: mainText.wrapMode
    property alias elide: mainText.elide
    property alias maximumLineCount: mainText.maximumLineCount
    property alias lineHeight: mainText.lineHeight
    property alias lineHeightMode: mainText.lineHeightMode

    // Minecraft Drop Shadow configuration (down to right: authentic color/4 and size/8)
    property bool dropShadow: true
    property real shadowOffset: Theme.getShadowOffset(mainText.font.pixelSize)
    property color shadowColor: Theme.getShadowColor(mainText.color)

    implicitWidth: mainText.implicitWidth
    implicitHeight: mainText.implicitHeight

    // Drop Shadow Text (offset +X, +Y -> down to right)
    Text {
        id: shadowText
        x: root.dropShadow ? root.shadowOffset : 0
        y: root.dropShadow ? root.shadowOffset : 0
        width: mainText.width
        height: mainText.height
        visible: root.dropShadow && root.shadowColor !== "transparent"
        text: mainText.text
        color: root.shadowColor
        font: mainText.font
        horizontalAlignment: mainText.horizontalAlignment
        verticalAlignment: mainText.verticalAlignment
        wrapMode: mainText.wrapMode
        elide: mainText.elide
        maximumLineCount: mainText.maximumLineCount
        lineHeight: mainText.lineHeight
        lineHeightMode: mainText.lineHeightMode
    }

    // Foreground Text
    Text {
        id: mainText
        anchors.left: parent.left
        anchors.top: parent.top
        font.family: Theme.fontFamily
        font.pixelSize: Theme.sizeBody
        color: Theme.textPrimary
    }
}


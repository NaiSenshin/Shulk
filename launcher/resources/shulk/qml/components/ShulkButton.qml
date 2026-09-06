// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Controls
import "../theme"

FocusScope {
    id: root

    property string text: ""
    property string iconSource: ""
    property bool isPrimary: true
    property string variant: isPrimary ? "primary" : "secondary"
    property bool isDefault: false
    property bool isFocused: false
    property string shortcutHint: ""
    property alias isPressed: mouseArea.pressed

    signal clicked()

    implicitWidth: Math.max(118 * Theme.scale, contentRow.implicitWidth + Theme.space20 * 2)
    implicitHeight: 42 * Theme.scale
    activeFocusOnTab: true

    readonly property bool highlighted: activeFocus || isFocused || mouseArea.containsMouse
    readonly property color baseColor: {
        if (!enabled) return "#313233"
        if (variant === "play" || variant === "primary") return highlighted ? Theme.accentPlayHover : Theme.accentPlay
        if (variant === "danger") return highlighted ? "#C8463E" : "#A93630"
        if (variant === "ghost") return highlighted ? "#303233" : "transparent"
        return highlighted ? "#3A3C3D" : "#2B2D2E"
    }

    function triggerClick() {
        if (!root.enabled) return
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
        root.clicked()
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            triggerClick()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: root.baseColor
        border.color: root.highlighted ? Theme.borderFocused : (root.variant === "ghost" ? "transparent" : "#62000000")
        border.width: root.highlighted ? 2 : 1
        scale: mouseArea.pressed ? 0.975 : 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.highlighted ? 3 : 2
            height: 1
            visible: root.variant !== "ghost"
            color: root.variant === "play" || root.variant === "primary" ? "#4FFFFFFF" : "#28FFFFFF"
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Theme.space8

            Image {
                visible: root.iconSource !== ""
                width: 22 * Theme.scale
                height: 22 * Theme.scale
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: false
                opacity: root.enabled ? 1 : 0.45
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeBody
                font.weight: Font.DemiBold
                color: root.enabled ? Theme.textPrimary : Theme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                visible: root.shortcutHint !== ""
                width: shortcutText.implicitWidth + Theme.space8
                height: 20 * Theme.scale
                radius: Theme.radiusSm
                color: "#52000000"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: shortcutText
                    anchors.centerIn: parent
                    text: root.shortcutHint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeSmall
                    font.bold: true
                    color: Theme.textPrimary
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggerClick()
    }
}

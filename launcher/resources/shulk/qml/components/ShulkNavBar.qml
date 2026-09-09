// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

Rectangle {
    id: root

    property int currentIndex: 0
    property bool isFocused: false
    property int focusIndex: 1 // 0 = Account Pill, 1 = Exit Button
    signal tabSelected(int index)
    signal accountPillClicked()
    signal exitRequested()
    signal returnFocusRequested()

    implicitHeight: 72 * Theme.scale
    color: "#F20C0D0E"

    readonly property var tabs: [
        { name: qsTr("Home"), iconSource: "qrc:/shulk/icons/grass_block.png" },
        { name: qsTr("Library"), iconSource: "qrc:/shulk/icons/bookshelf.png" },
        { name: qsTr("Discover"), iconSource: "qrc:/shulk/icons/compass.png" },
        { name: qsTr("Settings"), iconSource: "qrc:/shulk/icons/repeater.png" }
    ]

    function handleAction(action) {
        if (action === 1 || action === Theme.actionUp) {
            return
        } else if (action === 2 || action === Theme.actionDown) {
            root.isFocused = false
            returnFocusRequested()
            if (typeof shulkSound !== "undefined") shulkSound.playFocus()
        } else if (action === 3 || action === Theme.actionLeft) {
            if (focusIndex > 0) {
                focusIndex--
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 4 || action === Theme.actionRight) {
            if (focusIndex < 1) {
                focusIndex++
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 5 || action === Theme.actionAccept) {
            if (focusIndex === 0) {
                root.isFocused = false
                accountPillClicked()
            } else if (focusIndex === 1) {
                root.isFocused = false
                exitRequested()
            }
        } else if (action === 6 || action === Theme.actionBack) {
            root.isFocused = false
            returnFocusRequested()
            if (typeof shulkSound !== "undefined") shulkSound.playFocus()
        }
    }

    function triggerSelect(index) {
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
        tabSelected(index)
    }

    function selectPrevious() { triggerSelect(currentIndex > 0 ? currentIndex - 1 : tabs.length - 1) }
    function selectNext() { triggerSelect(currentIndex < tabs.length - 1 ? currentIndex + 1 : 0) }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.borderSubtle
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space24
        anchors.rightMargin: Theme.space24
        spacing: Theme.space24

        RowLayout {
            Layout.fillHeight: true
            spacing: 12 * Theme.scale

            Image {
                Layout.preferredWidth: 38 * Theme.scale
                Layout.preferredHeight: 38 * Theme.scale
                Layout.alignment: Qt.AlignVCenter
                source: "qrc:/shulk/icons/shulk.png"
                fillMode: Image.PreserveAspectFit
                smooth: false
            }

            Item {
                Layout.alignment: Qt.AlignVCenter
                readonly property int brandOffset: Theme.getShadowOffset(24 * Theme.scale)
                implicitWidth: brandText.implicitWidth + brandOffset
                implicitHeight: brandText.implicitHeight + brandOffset

                Text {
                    x: parent.brandOffset
                    y: parent.brandOffset
                    text: qsTr("SHULK")
                    font.family: Theme.fontDisplay
                    font.pixelSize: 24 * Theme.scale
                    font.bold: true
                    font.letterSpacing: 1.5 * Theme.scale
                    color: Theme.getShadowColor(brandText.color)
                }

                Text {
                    id: brandText
                    text: qsTr("SHULK")
                    font.family: Theme.fontDisplay
                    font.pixelSize: 24 * Theme.scale
                    font.bold: true
                    font.letterSpacing: 1.5 * Theme.scale
                    color: Theme.textPrimary
                }
            }
        }

        Row {
            Layout.fillHeight: true
            spacing: Theme.space4

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 36 * Theme.scale
                height: 34 * Theme.scale
                radius: Theme.radiusSm
                color: previousTabMouse.containsMouse ? "#18FFFFFF" : "transparent"

                ShulkControllerGlyph {
                    anchors.centerIn: parent
                    glyph: "lb"
                }

                MouseArea {
                    id: previousTabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectPrevious()
                }
            }

            Repeater {
                model: root.tabs

                delegate: Item {
                    // Keep every navigation label in a stable slot. The selected
                    // label becomes bold, but must not reflow the whole bar.
                    width: 126 * Theme.scale
                    height: root.height
                    readonly property bool selected: root.currentIndex === index

                    Rectangle {
                        anchors.fill: parent
                        color: tabMouse.containsMouse ? "#18FFFFFF" : "transparent"
                    }

                    Row {
                        id: tabContent
                        anchors.centerIn: parent
                        spacing: Theme.space8

                        Image {
                            source: modelData.iconSource
                            width: 20 * Theme.scale
                            height: 20 * Theme.scale
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            opacity: selected ? 1 : 0.68
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            readonly property int tabOffset: Theme.getShadowOffset(navTabText.font.pixelSize)
                            readonly property int baselineAdj: Math.max(1, Math.round(navTabText.font.pixelSize * 0.12))
                            implicitWidth: navTabText.implicitWidth
                            implicitHeight: navTabText.implicitHeight
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                x: parent.tabOffset
                                y: parent.tabOffset + parent.baselineAdj
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeBody
                                font.weight: selected ? Font.Bold : Font.Medium
                                color: Theme.getShadowColor(navTabText.color)
                            }

                            Text {
                                id: navTabText
                                y: parent.baselineAdj
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeBody
                                font.weight: selected ? Font.Bold : Font.Medium
                                color: selected ? Theme.textPrimary : Theme.textSecondary
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 4 * Theme.scale
                        color: Theme.accentPlay
                        visible: selected
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerSelect(index)
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 36 * Theme.scale
                height: 34 * Theme.scale
                radius: Theme.radiusSm
                color: nextTabMouse.containsMouse ? "#18FFFFFF" : "transparent"

                ShulkControllerGlyph {
                    anchors.centerIn: parent
                    glyph: "rb"
                }

                MouseArea {
                    id: nextTabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectNext()
                }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: accountPill
            Layout.preferredHeight: 40 * Theme.scale
            Layout.preferredWidth: Math.min(210 * Theme.scale, accountRow.implicitWidth + Theme.space20)
            radius: Theme.radiusSm
            color: (root.isFocused && root.focusIndex === 0) ? Theme.bgSurfaceHover : (accountMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurfaceRaised)
            border.color: (root.isFocused && root.focusIndex === 0) ? Theme.borderFocused : (accountMouse.containsMouse ? Theme.borderStrong : Theme.borderSubtle)
            border.width: (root.isFocused && root.focusIndex === 0) ? 2 : 1

            ToolTip {
                text: shulkAccounts.hasActiveAccount ? qsTr("Account Settings") : qsTr("Sign In")
                visible: accountMouse.containsMouse || (root.isFocused && root.focusIndex === 0)
                delay: accountMouse.containsMouse ? 400 : 0
            }

            Row {
                id: accountRow
                anchors.centerIn: parent
                spacing: Theme.space8

                Rectangle {
                    width: 26 * Theme.scale
                    height: 26 * Theme.scale
                    color: Theme.bgDeep
                    clip: true

                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: shulkAccounts.hasActiveAccount
                                ? ("https://mc-heads.net/avatar/" + shulkAccounts.activeAccountName + "/32")
                                : "qrc:/shulk/icons/steve_head.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        onStatusChanged: {
                            if (status === Image.Error) {
                                source = "qrc:/shulk/icons/steve_head.png"
                            }
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Item {
                        readonly property int accOffset: Theme.getShadowOffset(accountNameText.font.pixelSize)
                        implicitWidth: accountNameText.implicitWidth + accOffset
                        implicitHeight: accountNameText.implicitHeight + accOffset

                        Text {
                            x: parent.accOffset
                            y: parent.accOffset
                            text: shulkAccounts.hasActiveAccount ? shulkAccounts.activeAccountName : qsTr("Sign in")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeCaption
                            font.weight: Font.DemiBold
                            color: Theme.getShadowColor(accountNameText.color)
                        }

                        Text {
                            id: accountNameText
                            text: shulkAccounts.hasActiveAccount ? shulkAccounts.activeAccountName : qsTr("Sign in")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeCaption
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                    }
                    Text {
                        text: shulkAccounts.hasActiveAccount ? qsTr("Microsoft account") : qsTr("Play online")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        color: Theme.textMuted
                    }
                }

                Text {
                    text: ">"
                    font.pixelSize: Theme.sizeHeader
                    color: Theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: accountMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.accountPillClicked()
            }
        }

        Rectangle {
            id: exitBtn
            Layout.preferredHeight: 40 * Theme.scale
            Layout.preferredWidth: 40 * Theme.scale
            radius: Theme.radiusSm
            color: (root.isFocused && root.focusIndex === 1) ? "#D63830" : (exitMouse.containsMouse ? "#C8463E" : "#241819")
            border.color: (root.isFocused && root.focusIndex === 1) ? "#FFFFFF" : (exitMouse.containsMouse ? "#FF5555" : "#503030")
            border.width: (root.isFocused && root.focusIndex === 1) ? 2 : 1

            ToolTip {
                text: qsTr("Quit Shulk")
                visible: exitMouse.containsMouse || (root.isFocused && root.focusIndex === 1)
                delay: exitMouse.containsMouse ? 400 : 0
            }

            Item {
                readonly property int exitOffset: Theme.getShadowOffset(18 * Theme.scale)
                readonly property int baselineAdj: Math.max(1, Math.round(18 * Theme.scale * 0.12))
                anchors.centerIn: parent
                implicitWidth: exitLabel.implicitWidth
                implicitHeight: exitLabel.implicitHeight

                Text {
                    x: parent.exitOffset
                    y: parent.exitOffset + parent.baselineAdj
                    text: "✕"
                    font.family: Theme.fontDisplay
                    font.pixelSize: 18 * Theme.scale
                    font.bold: true
                    color: Theme.getShadowColor(exitLabel.color)
                }

                Text {
                    id: exitLabel
                    y: parent.baselineAdj
                    text: "✕"
                    font.family: Theme.fontDisplay
                    font.pixelSize: 18 * Theme.scale
                    font.bold: true
                    color: (root.isFocused && root.focusIndex === 1) || exitMouse.containsMouse ? "#FFFFFF" : "#FF6666"
                }
            }

            MouseArea {
                id: exitMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    root.exitRequested()
                }
            }
        }
    }
}

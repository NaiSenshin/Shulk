// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

ShulkDialog {
    id: root

    dialogTitle: qsTr("Open Source Licenses & Attribution")
    preferredWidth: 680 * Theme.scale
    preferredHeight: 520 * Theme.scale
    closeOnBackdropClick: true

    property int focusIndex: 1 // 0: Web License, 1: Close

    onOpacityChanged: {
        if (opacity === 1) {
            root.focusIndex = 1
            licenseFlickable.contentY = 0
        }
    }

    function triggerAction() {
        if (typeof shulkSound !== "undefined") {
            shulkSound.playClick()
        }
        if (focusIndex === 0) {
            Qt.openUrlExternally("https://www.gnu.org/licenses/gpl-3.0.html")
        } else if (focusIndex === 1) {
            root.close()
        }
    }

    function handleAction(action) {
        if (action === Theme.actionBack) {
            root.close()
            return true
        }

        if (action === Theme.actionUp) {
            if (licenseFlickable.contentY > 0) {
                licenseFlickable.contentY = Math.max(0, licenseFlickable.contentY - 90 * Theme.scale)
                if (typeof shulkSound !== "undefined") shulkSound.playTick()
            }
            return true
        } else if (action === Theme.actionDown) {
            var maxY = Math.max(0, licenseFlickable.contentHeight - licenseFlickable.height)
            if (licenseFlickable.contentY < maxY) {
                licenseFlickable.contentY = Math.min(maxY, licenseFlickable.contentY + 90 * Theme.scale)
                if (typeof shulkSound !== "undefined") shulkSound.playTick()
            }
            return true
        } else if (action === Theme.actionLeft) {
            if (root.focusIndex > 0) {
                root.focusIndex--
                if (typeof shulkSound !== "undefined") shulkSound.playTick()
            }
            return true
        } else if (action === Theme.actionRight) {
            if (root.focusIndex < 1) {
                root.focusIndex++
                if (typeof shulkSound !== "undefined") shulkSound.playTick()
            }
            return true
        } else if (action === Theme.actionAccept) {
            root.triggerAction()
            return true
        }

        // Bumper quick page scroll
        if (action === 9 || action === 15) { // LB or LT
            licenseFlickable.contentY = Math.max(0, licenseFlickable.contentY - 240 * Theme.scale)
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
            return true
        } else if (action === 10 || action === 16) { // RB or RT
            var maxPageY = Math.max(0, licenseFlickable.contentHeight - licenseFlickable.height)
            licenseFlickable.contentY = Math.min(maxPageY, licenseFlickable.contentY + 240 * Theme.scale)
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
            return true
        }

        return false
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space12

        // Subheader notice
        Text {
            Layout.fillWidth: true
            text: qsTr("Shulk is free, open-source software built upon Prism Launcher and community projects.")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sizeCaption
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
        }

        // Scrollable content area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMd
            color: "#16181B"
            border.color: Theme.borderSubtle
            border.width: 1
            clip: true

            Flickable {
                id: licenseFlickable
                anchors.fill: parent
                anchors.margins: Theme.space12
                contentWidth: width - (scrollTrack.visible ? 14 * Theme.scale : 0)
                contentHeight: licenseCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Behavior on contentY {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }

                ColumnLayout {
                    id: licenseCol
                    width: parent.width
                    spacing: Theme.space14

                    // 1. Shulk Primary License
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: shulkCardCol.implicitHeight + Theme.space16
                        radius: Theme.radiusSm
                        color: "#1A222D"
                        border.color: Theme.mcDiamond
                        border.width: 1

                        ColumnLayout {
                            id: shulkCardCol
                            anchors.fill: parent
                            anchors.margins: Theme.space10
                            spacing: Theme.space6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space8

                                Item {
                                    implicitWidth: shulkTitle.implicitWidth
                                    implicitHeight: shulkTitle.implicitHeight
                                    Text {
                                        x: Theme.fontShadowOffset; y: Theme.fontShadowOffset
                                        text: shulkTitle.text; font: shulkTitle.font
                                        color: Theme.fontShadowDark
                                    }
                                    Text {
                                        id: shulkTitle
                                        text: "Shulk Launcher"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeBody
                                        font.bold: true
                                        color: Theme.mcDiamond
                                    }
                                }

                                ShulkBadge {
                                    text: "GPL-3.0-only"
                                    badgeColor: "#102835"
                                    textColor: Theme.mcDiamond
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Copyright (C) 2026 Shulk Contributors"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeCaption
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Shulk is licensed under the GNU General Public License v3.0 (GPL-3.0-only). Built as an independent handheld-first frontend designed for Steam Deck, Lenovo Legion Go, ASUS ROG Ally, and Linux handhelds.")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeCaption
                                color: Theme.textSecondary
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // 2. Upstream Lineage & Heritage
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: heritageCol.implicitHeight + Theme.space16
                        radius: Theme.radiusSm
                        color: "#1E2024"
                        border.color: Theme.borderSubtle
                        border.width: 1

                        ColumnLayout {
                            id: heritageCol
                            anchors.fill: parent
                            anchors.margins: Theme.space10
                            spacing: Theme.space6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space8

                                Item {
                                    implicitWidth: heritageTitle.implicitWidth
                                    implicitHeight: heritageTitle.implicitHeight
                                    Text {
                                        x: Theme.fontShadowOffset; y: Theme.fontShadowOffset
                                        text: heritageTitle.text; font: heritageTitle.font
                                        color: Theme.fontShadowDark
                                    }
                                    Text {
                                        id: heritageTitle
                                        text: "Upstream Lineage & Heritage"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeBody
                                        font.bold: true
                                        color: Theme.mcEmerald
                                    }
                                }

                                ShulkBadge {
                                    text: "Prism Core"
                                    isAccent: true
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Copyright (C) 2022-2026 Prism Launcher Contributors (GPL-3.0-only)\nCopyright (C) 2021-2022 PolyMC Contributors (GPL-3.0-only)\nCopyright (C) 2012-2021 MultiMC Contributors (Apache 2.0 / GPL-3.0)"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeCaption
                                color: Theme.textSecondary
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Shulk's backend core, launch execution pipeline, Microsoft authentication, modpack resolvers, and instance management are powered by the foundation developed by hundreds of open-source contributors from Prism Launcher, PolyMC, and MultiMC.")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeCaption
                                color: Theme.textMuted
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // 3. Core Open-Source Libraries
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: libsCol.implicitHeight + Theme.space16
                        radius: Theme.radiusSm
                        color: "#1E2024"
                        border.color: Theme.borderSubtle
                        border.width: 1

                        ColumnLayout {
                            id: libsCol
                            anchors.fill: parent
                            anchors.margins: Theme.space10
                            spacing: Theme.space6

                            Item {
                                implicitWidth: libsTitle.implicitWidth
                                implicitHeight: libsTitle.implicitHeight
                                Text {
                                    x: Theme.fontShadowOffset; y: Theme.fontShadowOffset
                                    text: libsTitle.text; font: libsTitle.font
                                    color: Theme.fontShadowDark
                                }
                                Text {
                                    id: libsTitle
                                    text: "Open Source Libraries & Frameworks"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space4

                                Text {
                                    Layout.fillWidth: true
                                    text: "• Qt 6 (The Qt Company) — LGPL-3.0 / GPL-3.0"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textSecondary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "• SDL2 (Simple DirectMedia Layer) — zlib License"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textSecondary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "• QuaZip (Sergey A. Tachenov) — LGPL-2.1"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textSecondary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "• tomlplusplus (Mark Gillard) — MIT License"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textSecondary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "• cmark (John MacFarlane) — BSD-2-Clause"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textSecondary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "• GameMode (Feral Interactive) — BSD-3-Clause"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textSecondary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "• libnbtplusplus — GPL-3.0-only"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }

                    // 4. Trademark & Asset Notice
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: noticeCol.implicitHeight + Theme.space16
                        radius: Theme.radiusSm
                        color: "#181A1D"
                        border.color: Theme.borderSubtle
                        border.width: 1

                        ColumnLayout {
                            id: noticeCol
                            anchors.fill: parent
                            anchors.margins: Theme.space10
                            spacing: Theme.space4

                            Text {
                                Layout.fillWidth: true
                                text: "NOT AN OFFICIAL MINECRAFT PRODUCT"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeSmall
                                font.bold: true
                                color: Theme.mcGold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("NOT APPROVED BY OR ASSOCIATED WITH MOJANG OR MICROSOFT. Minecraft is a registered trademark of Mojang Synergies AB. Mojangles typography, sound cues, and artwork are property of their respective creators.")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeCaption
                                color: Theme.textMuted
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // Scrollbar Track & Thumb
            Rectangle {
                id: scrollTrack
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 4 * Theme.scale
                width: 6 * Theme.scale
                radius: 3 * Theme.scale
                color: "#1E2228"
                visible: licenseFlickable.contentHeight > licenseFlickable.height

                Rectangle {
                    width: parent.width
                    radius: parent.radius
                    color: Theme.mcEmerald
                    y: (licenseFlickable.contentY / Math.max(1, licenseFlickable.contentHeight - licenseFlickable.height)) * (parent.height - height)
                    height: Math.max(20 * Theme.scale, (licenseFlickable.height / Math.max(1, licenseFlickable.contentHeight)) * parent.height)
                }
            }
        }

        // Bottom Action Row & Controller Hints
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            Text {
                text: qsTr("D-pad Up/Down / Bumpers: Scroll")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeCaption
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            ShulkButton {
                Layout.preferredWidth: 200 * Theme.scale
                implicitHeight: 40 * Theme.scale
                text: qsTr("🌐 View GPL-3.0 Online")
                variant: "secondary"
                isFocused: root.focusIndex === 0
                onClicked: {
                    root.focusIndex = 0
                    root.triggerAction()
                }
            }

            ShulkButton {
                Layout.preferredWidth: 120 * Theme.scale
                implicitHeight: 40 * Theme.scale
                text: qsTr("Close (B)")
                variant: "primary"
                isFocused: root.focusIndex === 1
                onClicked: {
                    root.focusIndex = 1
                    root.triggerAction()
                }
            }
        }
    }
}

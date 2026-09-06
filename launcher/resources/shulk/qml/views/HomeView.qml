// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"
import "../components"

FocusScope {
    id: root

    signal openProfile(var profile)
    signal createProfileRequested()
    signal openOptionsRequested(var profile)
    signal openFeaturedPackRequested(var pack)
    signal openDiscoverRequested()

    property int activeSection: 0
    property int heroBtnIdx: 0
    property int featuredIndex: 0
    property var lastPlayedProfile: {
        if (shulkProfiles.count === 0) return null
        var recent = shulkProfiles.getById(shulkProfiles.mostRecentId)
        return recent && recent.id ? recent : shulkProfiles.get(0)
    }
    readonly property var featuredPacks: shulkCreation.getHandheldRecommendedPacks()

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space24
        anchors.rightMargin: Theme.space24
        anchors.topMargin: Theme.space16
        anchors.bottomMargin: Theme.space12
        spacing: Theme.space16

        Rectangle {
            id: heroBanner
            Layout.fillWidth: true
            Layout.preferredHeight: 286 * Theme.scale
            radius: Theme.radiusLg
            color: Theme.bgSurface
            border.color: root.activeSection === 0 ? Theme.borderFocused : Theme.borderSubtle
            border.width: root.activeSection === 0 ? 2 : 1
            clip: true

            Image {
                anchors.fill: parent
                source: root.lastPlayedProfile && root.lastPlayedProfile.bannerUrl
                        ? root.lastPlayedProfile.bannerUrl
                        : "qrc:/shulk/assets/default_pack_banner.jpg"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "#FA0C0D0E" }
                    GradientStop { position: 0.42; color: "#D90C0D0E" }
                    GradientStop { position: 0.72; color: "#560C0D0E" }
                    GradientStop { position: 1.00; color: "#180C0D0E" }
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 62 * Theme.scale
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: "#C80C0D0E" }
                }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.space28
                anchors.topMargin: Theme.space24
                anchors.bottomMargin: Theme.space24
                width: Math.max(320 * Theme.scale, parent.width - 190 * Theme.scale)
                spacing: Theme.space8

                Text {
                    text: root.lastPlayedProfile ? qsTr("READY TO PLAY") : qsTr("WELCOME TO SHULK")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeSmall
                    font.letterSpacing: 1.8 * Theme.scale
                    font.weight: Font.Bold
                    color: "#9BD38B"
                }

                Text {
                    Layout.fillWidth: true
                    text: root.lastPlayedProfile ? root.lastPlayedProfile.name : qsTr("Minecraft: Java Edition")
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.sizeHero
                    color: Theme.textPrimary
                    style: Text.Outline
                    styleColor: "#A0000000"
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.lastPlayedProfile
                          ? qsTr("Minecraft %1%2").arg(root.lastPlayedProfile.minecraftVersion).arg(root.lastPlayedProfile.loaderType && root.lastPlayedProfile.loaderType !== "Vanilla" ? "  |  " + root.lastPlayedProfile.loaderType : "")
                          : qsTr("Create a profile, choose your version, and take Java Edition anywhere.")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeBody
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                }

                Row {
                    visible: root.lastPlayedProfile !== null
                    spacing: Theme.space6
                    ShulkBadge { text: root.lastPlayedProfile ? root.lastPlayedProfile.playTime : "" }
                    ShulkBadge { text: root.lastPlayedProfile ? root.lastPlayedProfile.lastPlayed : "" }
                    ShulkBadge { visible: root.lastPlayedProfile && root.lastPlayedProfile.modCount > 0; text: qsTr("%1 mods").arg(root.lastPlayedProfile ? root.lastPlayedProfile.modCount : 0) }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    spacing: Theme.space8

                    ShulkButton {
                        text: root.lastPlayedProfile
                              ? qsTr("View")
                              : qsTr("Create profile")
                        shortcutHint: ""
                        variant: "play"
                        isFocused: root.activeSection === 0 && root.heroBtnIdx === 0
                        implicitWidth: 172 * Theme.scale
                        implicitHeight: 46 * Theme.scale
                        onClicked: {
                            if (!root.lastPlayedProfile) root.createProfileRequested()
                            else root.openProfile(root.lastPlayedProfile)
                        }
                    }

                    ShulkButton {
                        visible: root.lastPlayedProfile !== null
                        text: qsTr("Options")
                        shortcutHint: qsTr("Menu")
                        variant: "secondary"
                        isFocused: root.activeSection === 0 && root.heroBtnIdx === 1
                        implicitWidth: 156 * Theme.scale
                        implicitHeight: 46 * Theme.scale
                        onClicked: root.openOptionsRequested(root.lastPlayedProfile)
                    }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.space16
                width: 120 * Theme.scale
                height: 32 * Theme.scale
                radius: Theme.radiusSm
                color: "#B70C0D0E"
                border.color: "#45FFFFFF"
                visible: root.lastPlayedProfile && root.lastPlayedProfile.isRunning
                Text {
                    anchors.centerIn: parent
                    text: qsTr("GAME RUNNING")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeSmall
                    font.bold: true
                    color: "#9BD38B"
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.activeSection = 0
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            Text {
                text: qsTr("Handheld Recommended")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeHeader
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }
            Rectangle {
                Layout.preferredWidth: curatedLabel.implicitWidth + Theme.space20
                Layout.preferredHeight: 28 * Theme.scale
                radius: Theme.radiusSm
                color: "#E8171819"
                border.color: "#80FFFFFF"
                border.width: 1

                Text {
                    id: curatedLabel
                    anchors.centerIn: parent
                    text: qsTr("CURATED FOR CONTROLLER PLAY")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeSmall
                    font.letterSpacing: 1.2 * Theme.scale
                    color: Theme.textPrimary
                }
            }
            Item { Layout.fillWidth: true }
        }

        ListView {
            id: featuredListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 180 * Theme.scale
            orientation: ListView.Horizontal
            spacing: Theme.space12
            clip: true
            model: root.featuredPacks
            currentIndex: root.featuredIndex
            rightMargin: Theme.space24

            delegate: Rectangle {
                id: packCard
                width: 282 * Theme.scale
                height: Math.min(featuredListView.height - Theme.space4, 194 * Theme.scale)
                radius: Theme.radiusMd
                color: cardMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                border.color: root.activeSection === 1 && root.featuredIndex === index ? Theme.borderFocused : Theme.borderSubtle
                border.width: root.activeSection === 1 && root.featuredIndex === index ? 2 : 1
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space12
                    spacing: Theme.space12

                    ColumnLayout {
                        Layout.preferredWidth: 78 * Theme.scale
                        Layout.fillHeight: true
                        spacing: Theme.space8

                        Rectangle {
                            Layout.preferredWidth: 76 * Theme.scale
                            Layout.preferredHeight: 76 * Theme.scale
                            color: Theme.bgDeep
                            border.color: Theme.borderSubtle
                            border.width: 1
                            Image {
                                anchors.fill: parent
                                anchors.margins: Theme.space6
                                source: modelData.iconUrl ? modelData.iconUrl : "qrc:/shulk/icons/grass_block_side.png"
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }
                        }
                        ShulkBadge { text: modelData.loader ? modelData.loader : "Fabric" }
                        Item { Layout.fillHeight: true }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.space6

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.author ? qsTr("by %1").arg(modelData.author) : qsTr("Community modpack")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeCaption
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.description ? modelData.description : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeCaption
                            color: Theme.textSecondary
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            ShulkButton {
                                Layout.fillWidth: true
                                text: modelData.comingSoon ? qsTr("Coming soon") : qsTr("View")
                                variant: modelData.comingSoon ? "secondary" : "play"
                                isFocused: root.activeSection === 1 && root.featuredIndex === index
                                implicitHeight: 34 * Theme.scale
                                enabled: !modelData.comingSoon
                                onClicked: if (!modelData.comingSoon) root.openFeaturedPackRequested(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.space12
                    anchors.rightMargin: Theme.space12
                    anchors.bottomMargin: 51 * Theme.scale
                    height: 1
                    color: Theme.borderSubtle
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    anchors.bottomMargin: 44 * Theme.scale
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.activeSection = 1
                        root.featuredIndex = index
                        if (!modelData.comingSoon) root.openFeaturedPackRequested(modelData)
                    }
                }
            }
        }
    }

    function handleAction(action) {
        if (action === 1 && activeSection === 1) { activeSection = 0; shulkSound.playFocus() }
        else if (action === 2 && activeSection === 0 && featuredPacks.length > 0) { activeSection = 1; shulkSound.playFocus() }
        else if (action === 3) {
            if (activeSection === 0 && heroBtnIdx > 0) { heroBtnIdx = 0; shulkSound.playFocus() }
            else if (activeSection === 1 && featuredIndex > 0) { featuredIndex--; featuredListView.positionViewAtIndex(featuredIndex, ListView.Beginning); shulkSound.playFocus() }
        } else if (action === 4) {
            if (activeSection === 0 && heroBtnIdx === 0 && lastPlayedProfile) { heroBtnIdx = 1; shulkSound.playFocus() }
            else if (activeSection === 1 && featuredIndex < featuredPacks.length - 1) { featuredIndex++; featuredListView.positionViewAtIndex(featuredIndex, ListView.Beginning); shulkSound.playFocus() }
        } else if (action === 5) {
            if (activeSection === 0) {
                if (!lastPlayedProfile) createProfileRequested()
                else if (heroBtnIdx === 0) openProfile(lastPlayedProfile)
                else openOptionsRequested(lastPlayedProfile)
            }
            else if (featuredIndex >= 0 && featuredIndex < featuredPacks.length && !featuredPacks[featuredIndex].comingSoon) openFeaturedPackRequested(featuredPacks[featuredIndex])
        } else if (action === 8) openDiscoverRequested()
        else if (action === 9 && activeSection === 0 && lastPlayedProfile) openOptionsRequested(lastPlayedProfile)
    }
}

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
    signal enterTopBarRequested()
    signal exitLauncherRequested()

    property int activeSection: 0
    property int heroBtnIdx: 0
    property int featuredIndex: 0
    property var lastPlayedProfile: {
        if (shulkProfiles.count === 0) return null
        var recent = shulkProfiles.getById(shulkProfiles.mostRecentId)
        return recent && recent.id ? recent : shulkProfiles.get(0)
    }
    readonly property var featuredPacks: shulkCreation.getHandheldRecommendedPacks()

    Item {
        anchors.fill: parent

        ColumnLayout {
            id: mainCol
            anchors.centerIn: parent
            width: Math.min(1280 * Theme.scale, parent.width - Theme.space32)
            spacing: Theme.space16

            Rectangle {
                id: heroBanner
                Layout.fillWidth: true
                Layout.preferredHeight: 272 * Theme.scale
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
                    anchors.topMargin: Theme.space20
                    anchors.bottomMargin: Theme.space20
                    width: Math.max(320 * Theme.scale, parent.width - 190 * Theme.scale)
                    spacing: Theme.space8

                    Item {
                        readonly property int readyOffset: Theme.getShadowOffset(readyLabel.font.pixelSize)
                        implicitWidth: readyLabel.implicitWidth + readyOffset
                        implicitHeight: readyLabel.implicitHeight + readyOffset

                        Text {
                            x: parent.readyOffset
                            y: parent.readyOffset
                            text: root.lastPlayedProfile ? qsTr("READY TO PLAY") : qsTr("WELCOME TO SHULK")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.letterSpacing: 1.8 * Theme.scale
                            font.weight: Font.Bold
                            color: Theme.getShadowColor(readyLabel.color)
                        }

                        Text {
                            id: readyLabel
                            text: root.lastPlayedProfile ? qsTr("READY TO PLAY") : qsTr("WELCOME TO SHULK")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.letterSpacing: 1.8 * Theme.scale
                            font.weight: Font.Bold
                            color: "#9BD38B"
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        readonly property int heroOffset: Theme.getShadowOffset(heroTitleText.font.pixelSize)
                        implicitHeight: heroTitleText.implicitHeight + heroOffset

                        Text {
                            x: parent.heroOffset
                            y: parent.heroOffset
                            width: heroTitleText.width
                            height: heroTitleText.height
                            text: root.lastPlayedProfile ? root.lastPlayedProfile.name : qsTr("Minecraft: Java Edition")
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.sizeHero
                            color: Theme.getShadowColor(heroTitleText.color)
                            elide: Text.ElideRight
                        }

                        Text {
                            id: heroTitleText
                            anchors.fill: parent
                            text: root.lastPlayedProfile ? root.lastPlayedProfile.name : qsTr("Minecraft: Java Edition")
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.sizeHero
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        readonly property int subOffset: Theme.getShadowOffset(heroSubtitleText.font.pixelSize)
                        implicitHeight: heroSubtitleText.implicitHeight + subOffset

                        Text {
                            x: parent.subOffset
                            y: parent.subOffset
                            width: heroSubtitleText.width
                            height: heroSubtitleText.height
                            text: heroSubtitleText.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.getShadowColor(heroSubtitleText.color)
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            id: heroSubtitleText
                            anchors.fill: parent
                            text: root.lastPlayedProfile
                                  ? qsTr("Minecraft %1%2").arg(root.lastPlayedProfile.minecraftVersion).arg(root.lastPlayedProfile.loaderType && root.lastPlayedProfile.loaderType !== "Vanilla" ? "  |  " + root.lastPlayedProfile.loaderType : "")
                                  : qsTr("Create a profile, choose your version, and take Java Edition anywhere.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textSecondary
                            wrapMode: Text.WordWrap
                        }
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
                            implicitWidth: 156 * Theme.scale
                            implicitHeight: 44 * Theme.scale
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
                            implicitWidth: 140 * Theme.scale
                            implicitHeight: 44 * Theme.scale
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
                    Item {
                        readonly property int runOffset: Theme.getShadowOffset(runningText.font.pixelSize)
                        anchors.centerIn: parent
                        implicitWidth: runningText.implicitWidth + runOffset
                        implicitHeight: runningText.implicitHeight + runOffset

                        Text {
                            x: parent.runOffset
                            y: parent.runOffset
                            text: qsTr("GAME RUNNING")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.bold: true
                            color: Theme.getShadowColor(runningText.color)
                        }

                        Text {
                            id: runningText
                            text: qsTr("GAME RUNNING")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.bold: true
                            color: "#9BD38B"
                        }
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
                Layout.leftMargin: featuredListView.leftMargin
                Layout.rightMargin: featuredListView.rightMargin
                spacing: Theme.space12

                Item {
                    readonly property int headerOffset: Theme.getShadowOffset(sectionHeaderText.font.pixelSize)
                    implicitWidth: sectionHeaderText.implicitWidth + headerOffset
                    implicitHeight: sectionHeaderText.implicitHeight + headerOffset

                    Text {
                        x: parent.headerOffset
                        y: parent.headerOffset
                        text: qsTr("Handheld Recommended")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeHeader
                        font.weight: Font.DemiBold
                        color: Theme.getShadowColor(sectionHeaderText.color)
                    }

                    Text {
                        id: sectionHeaderText
                        text: qsTr("Handheld Recommended")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeHeader
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                }
                Rectangle {
                    Layout.preferredWidth: curatedLabel.implicitWidth + Theme.space20 + Theme.getShadowOffset(Theme.sizeSmall)
                    Layout.preferredHeight: 28 * Theme.scale
                    radius: Theme.radiusSm
                    color: "#E8171819"
                    border.color: "#80FFFFFF"
                    border.width: 1

                    Item {
                        readonly property int curatedOffset: Theme.getShadowOffset(curatedLabel.font.pixelSize)
                        anchors.centerIn: parent
                        implicitWidth: curatedLabel.implicitWidth + curatedOffset
                        implicitHeight: curatedLabel.implicitHeight + curatedOffset

                        Text {
                            x: parent.curatedOffset
                            y: parent.curatedOffset
                            text: qsTr("CURATED FOR CONTROLLER PLAY")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.letterSpacing: 1.2 * Theme.scale
                            color: Theme.getShadowColor(curatedLabel.color)
                        }

                        Text {
                            id: curatedLabel
                            text: qsTr("CURATED FOR CONTROLLER PLAY")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.letterSpacing: 1.2 * Theme.scale
                            color: "#E2E8F0"
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            ListView {
                id: featuredListView
                Layout.fillWidth: true
                Layout.preferredHeight: 196 * Theme.scale
                orientation: ListView.Horizontal
                spacing: Theme.space12
                clip: true
                model: root.featuredPacks
                currentIndex: root.featuredIndex
                leftMargin: Math.max(0, Math.floor((width - (root.featuredPacks.length * (282 * Theme.scale + Theme.space12) - Theme.space12)) / 2))
                rightMargin: leftMargin

                delegate: Rectangle {
                    id: packCard
                    width: 282 * Theme.scale
                    height: 194 * Theme.scale
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

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: packNameText.implicitHeight + Theme.getShadowOffset(Theme.sizeBody)

                                Text {
                                    x: Theme.getShadowOffset(Theme.sizeBody)
                                    y: Theme.getShadowOffset(Theme.sizeBody)
                                    width: packNameText.width
                                    height: packNameText.height
                                    text: modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    font.weight: Font.Bold
                                    color: Theme.getShadowColor(Theme.textPrimary)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: packNameText
                                    anchors.fill: parent
                                    text: modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: packAuthorText.implicitHeight + Theme.getShadowOffset(Theme.sizeCaption)

                                Text {
                                    x: Theme.getShadowOffset(Theme.sizeCaption)
                                    y: Theme.getShadowOffset(Theme.sizeCaption)
                                    width: packAuthorText.width
                                    height: packAuthorText.height
                                    text: packAuthorText.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.getShadowColor(Theme.textMuted)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: packAuthorText
                                    anchors.fill: parent
                                    text: modelData.author ? qsTr("by %1").arg(modelData.author) : qsTr("Community modpack")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: packDescText.implicitHeight + Theme.getShadowOffset(Theme.sizeCaption)

                                Text {
                                    x: Theme.getShadowOffset(Theme.sizeCaption)
                                    y: Theme.getShadowOffset(Theme.sizeCaption)
                                    width: packDescText.width
                                    height: packDescText.height
                                    text: packDescText.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.getShadowColor(Theme.textMuted)
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: packDescText
                                    anchors.fill: parent
                                    text: modelData.description ? modelData.description : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeCaption
                                    color: Theme.textMuted
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
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
    }

    function handleAction(action) {
        var maxHero = root.lastPlayedProfile !== null ? 1 : 0
        if (action === 1 || action === Theme.actionUp) {
            if (activeSection === 1) {
                activeSection = 0
                shulkSound.playFocus()
            } else if (activeSection === 0) {
                enterTopBarRequested()
                shulkSound.playFocus()
            }
        } else if (action === 2 || action === Theme.actionDown) {
            if (activeSection === 0 && featuredPacks.length > 0) {
                activeSection = 1
                shulkSound.playFocus()
            }
        } else if (action === 3 || action === Theme.actionLeft) {
            if (activeSection === 0 && heroBtnIdx > 0) {
                heroBtnIdx--
                shulkSound.playFocus()
            } else if (activeSection === 1 && featuredIndex > 0) {
                featuredIndex--
                featuredListView.positionViewAtIndex(featuredIndex, ListView.Beginning)
                shulkSound.playFocus()
            }
        } else if (action === 4 || action === Theme.actionRight) {
            if (activeSection === 0 && heroBtnIdx < maxHero) {
                heroBtnIdx++
                shulkSound.playFocus()
            } else if (activeSection === 1 && featuredIndex < featuredPacks.length - 1) {
                featuredIndex++
                featuredListView.positionViewAtIndex(featuredIndex, ListView.Beginning)
                shulkSound.playFocus()
            }
        } else if (action === 5 || action === Theme.actionAccept) {
            if (activeSection === 0) {
                if (heroBtnIdx === 0) {
                    if (!lastPlayedProfile) createProfileRequested()
                    else openProfile(lastPlayedProfile)
                } else if (heroBtnIdx === 1 && lastPlayedProfile !== null) {
                    openOptionsRequested(lastPlayedProfile)
                }
            } else if (featuredIndex >= 0 && featuredIndex < featuredPacks.length && !featuredPacks[featuredIndex].comingSoon) {
                openFeaturedPackRequested(featuredPacks[featuredIndex])
            }
        } else if (action === 6 || action === Theme.actionBack) {
            exitLauncherRequested()
        } else if (action === 8 || action === Theme.actionSecondary) {
            openDiscoverRequested()
        } else if ((action === 9 || action === Theme.actionMenu) && activeSection === 0 && lastPlayedProfile) {
            openOptionsRequested(lastPlayedProfile)
        }
    }
}

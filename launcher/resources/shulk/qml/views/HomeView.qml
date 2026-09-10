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
    property int recentServerIndex: 0
    property var lastPlayedProfile: {
        if (shulkProfiles.count === 0) return null
        var recent = shulkProfiles.getById(shulkProfiles.mostRecentId)
        return recent && recent.id ? recent : shulkProfiles.get(0)
    }
    readonly property var featuredPacks: shulkCreation.getHandheldRecommendedPacks()

    // Proportions calibrated to match AI console target design (media_1789046926706.png)
    readonly property real availableContentH: Math.max(540, height)
    readonly property real bannerHeight: Math.round(Math.max(195, Math.min(235, availableContentH * 0.325))) * Theme.scale
    readonly property real featuredCardHeight: Math.round(Math.max(170, Math.min(204, availableContentH * 0.285))) * Theme.scale
    readonly property real jumpCardHeight: Math.round(Math.max(108, Math.min(124, availableContentH * 0.175))) * Theme.scale
    readonly property real homeSpacing: Math.round(Math.max(12, Math.min(16, availableContentH * 0.022))) * Theme.scale

    Connections {
        target: shulkRecentServers
        function onCountChanged() {
            if (root.recentServerIndex >= shulkRecentServers.count) {
                root.recentServerIndex = Math.max(0, shulkRecentServers.count - 1)
            }
            if (!shulkRecentServers.hasServers && root.activeSection === 2) {
                root.activeSection = 1
            }
        }
    }

    function ensureVisible() {
        if (mainFlickable.contentHeight <= mainFlickable.height) {
            mainFlickable.contentY = 0
            return
        }
        if (activeSection === 0) {
            mainFlickable.contentY = 0
        } else if (activeSection === 1) {
            var targetY1 = Math.max(0, featuredHeaderRow.y - Theme.space16)
            mainFlickable.contentY = Math.min(Math.max(0, mainFlickable.contentHeight - mainFlickable.height), targetY1)
        } else if (activeSection === 2) {
            mainFlickable.contentY = Math.max(0, mainFlickable.contentHeight - mainFlickable.height)
        }
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, mainCol.implicitHeight + 24 * Theme.scale)
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.DragOverBounds

        Behavior on contentY {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Item {
            width: mainFlickable.width
            height: Math.max(mainFlickable.height, mainCol.implicitHeight + 24 * Theme.scale)

            ColumnLayout {
                id: mainCol
                anchors.top: parent.top
                anchors.topMargin: 14 * Theme.scale
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(1280 * Theme.scale, parent.width - Theme.space32)
                spacing: root.homeSpacing

                Rectangle {
                    id: heroBanner
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.bannerHeight
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
                        height: 40 * Theme.scale
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: "#C80C0D0E" }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Theme.space20
                        anchors.topMargin: Theme.space12
                        anchors.bottomMargin: Theme.space12
                        width: Math.max(320 * Theme.scale, parent.width - 240 * Theme.scale)
                        spacing: 4 * Theme.scale

                        Row {
                            spacing: Theme.space8

                            Item {
                                readonly property int readyOffset: Theme.getShadowOffset(readyLabel.font.pixelSize)
                                implicitWidth: readyLabel.implicitWidth
                                implicitHeight: readyLabel.implicitHeight
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    x: parent.readyOffset
                                    y: parent.readyOffset
                                    text: root.lastPlayedProfile ? qsTr("READY TO PLAY") : qsTr("WELCOME TO SHULK")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSmall
                                    font.letterSpacing: 1.5 * Theme.scale
                                    font.weight: Font.Bold
                                    color: Theme.getShadowColor(readyLabel.color)
                                }

                                Text {
                                    id: readyLabel
                                    x: 0
                                    y: 0
                                    text: root.lastPlayedProfile ? qsTr("READY TO PLAY") : qsTr("WELCOME TO SHULK")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSmall
                                    font.letterSpacing: 1.5 * Theme.scale
                                    font.weight: Font.Bold
                                    color: "#9BD38B"
                                }
                            }

                            ShulkBadge {
                                visible: root.lastPlayedProfile !== null
                                text: root.lastPlayedProfile
                                      ? qsTr("Minecraft %1%2").arg(root.lastPlayedProfile.minecraftVersion).arg(root.lastPlayedProfile.loaderType && root.lastPlayedProfile.loaderType !== "Vanilla" ? " | " + root.lastPlayedProfile.loaderType : "")
                                      : ""
                            }
                            ShulkBadge { visible: root.lastPlayedProfile !== null; text: root.lastPlayedProfile ? root.lastPlayedProfile.playTime : "" }
                            ShulkBadge { visible: root.lastPlayedProfile && root.lastPlayedProfile.modCount > 0; text: qsTr("%1 mods").arg(root.lastPlayedProfile ? root.lastPlayedProfile.modCount : 0) }
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
                                font.pixelSize: Theme.sizeTitle
                                color: Theme.getShadowColor(heroTitleText.color)
                                elide: Text.ElideRight
                            }

                            Text {
                                id: heroTitleText
                                anchors.fill: parent
                                text: root.lastPlayedProfile ? root.lastPlayedProfile.name : qsTr("Minecraft: Java Edition")
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.sizeTitle
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
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
                                implicitWidth: 120 * Theme.scale
                                implicitHeight: 32 * Theme.scale
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
                                implicitWidth: 110 * Theme.scale
                                implicitHeight: 32 * Theme.scale
                                onClicked: root.openOptionsRequested(root.lastPlayedProfile)
                            }
                        }
                    }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Theme.space16
                    width: runningText.implicitWidth + Theme.space24
                    height: 30 * Theme.scale
                    radius: Theme.radiusSm
                    color: "#B70C0D0E"
                    border.color: "#45FFFFFF"
                    visible: root.lastPlayedProfile && root.lastPlayedProfile.isRunning
                    Item {
                        readonly property int runOffset: Theme.getShadowOffset(runningText.font.pixelSize)
                        anchors.centerIn: parent
                        width: runningText.implicitWidth
                        height: runningText.implicitHeight

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
                            x: 0
                            y: 0
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
                id: featuredHeaderRow
                Layout.fillWidth: true
                Layout.leftMargin: featuredListView.leftMargin
                Layout.rightMargin: featuredListView.rightMargin
                spacing: Theme.space12

                Item {
                    readonly property int headerOffset: Theme.getShadowOffset(sectionHeaderText.font.pixelSize)
                    implicitWidth: sectionHeaderText.implicitWidth
                    implicitHeight: sectionHeaderText.implicitHeight

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
                        x: 0
                        y: 0
                        text: qsTr("Handheld Recommended")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeHeader
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                }
                Rectangle {
                    Layout.preferredWidth: curatedLabel.implicitWidth + Theme.space16
                    Layout.preferredHeight: 24 * Theme.scale
                    radius: Theme.radiusSm
                    color: "#E8171819"
                    border.color: "#80FFFFFF"
                    border.width: 1

                    Item {
                        readonly property int curatedOffset: Theme.getShadowOffset(curatedLabel.font.pixelSize)
                        anchors.centerIn: parent
                        width: curatedLabel.implicitWidth
                        height: curatedLabel.implicitHeight

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
                            x: 0
                            y: 0
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
                Layout.preferredHeight: root.featuredCardHeight + 4 * Theme.scale
                orientation: ListView.Horizontal
                spacing: Theme.space12
                clip: true
                model: root.featuredPacks
                currentIndex: root.featuredIndex
                leftMargin: Math.max(0, Math.floor((width - (root.featuredPacks.length * (270 * Theme.scale + Theme.space12) - Theme.space12)) / 2))
                rightMargin: leftMargin

                delegate: Rectangle {
                    id: packCard
                    width: 270 * Theme.scale
                    height: root.featuredCardHeight
                    radius: Theme.radiusMd
                    color: cardMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                    border.color: root.activeSection === 1 && root.featuredIndex === index ? Theme.borderFocused : Theme.borderSubtle
                    border.width: root.activeSection === 1 && root.featuredIndex === index ? 2 : 1
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: Theme.space8

                        ColumnLayout {
                            Layout.preferredWidth: 50 * Theme.scale
                            Layout.fillHeight: true
                            spacing: Theme.space4

                            Rectangle {
                                Layout.preferredWidth: 48 * Theme.scale
                                Layout.preferredHeight: 48 * Theme.scale
                                color: Theme.bgDeep
                                border.color: Theme.borderSubtle
                                border.width: 1
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2 * Theme.scale
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
                            spacing: 2 * Theme.scale

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
                                implicitHeight: packDescText.implicitHeight + Theme.getShadowOffset(Theme.sizeSmall)

                                Text {
                                    x: Theme.getShadowOffset(Theme.sizeSmall)
                                    y: Theme.getShadowOffset(Theme.sizeSmall)
                                    width: packDescText.width
                                    height: packDescText.height
                                    text: packDescText.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSmall
                                    color: Theme.getShadowColor(Theme.textMuted)
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: packDescText
                                    anchors.fill: parent
                                    text: modelData.description ? modelData.description : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSmall
                                    color: Theme.textMuted
                                    maximumLineCount: 1
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
                                    implicitHeight: 28 * Theme.scale
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
                        anchors.leftMargin: Theme.space8
                        anchors.rightMargin: Theme.space8
                        anchors.bottomMargin: 38 * Theme.scale
                        height: 1
                        color: Theme.borderSubtle
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        anchors.bottomMargin: 34 * Theme.scale
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

            // -------------------------------------------------------------
            // SECTION 2: JUMP BACK IN (RECENT MULTIPLAYER SERVERS)
            // -------------------------------------------------------------
            RowLayout {
                id: jumpBackInHeaderRow
                Layout.fillWidth: true
                Layout.leftMargin: jumpBackInListView.leftMargin
                Layout.rightMargin: jumpBackInListView.rightMargin
                spacing: Theme.space12

                Item {
                    readonly property int headerOffset: Theme.getShadowOffset(jumpBackInHeaderText.font.pixelSize)
                    implicitWidth: jumpBackInHeaderText.implicitWidth
                    implicitHeight: jumpBackInHeaderText.implicitHeight

                    Text {
                        x: parent.headerOffset
                        y: parent.headerOffset
                        text: qsTr("Jump Back In")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeHeader
                        font.weight: Font.DemiBold
                        color: Theme.getShadowColor(jumpBackInHeaderText.color)
                    }

                    Text {
                        id: jumpBackInHeaderText
                        x: 0
                        y: 0
                        text: qsTr("Jump Back In")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeHeader
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                }

                Rectangle {
                    Layout.preferredWidth: jumpBackInBadgeText.implicitWidth + Theme.space16
                    Layout.preferredHeight: 24 * Theme.scale
                    radius: Theme.radiusSm
                    color: "#E8171819"
                    border.color: "#80FFFFFF"
                    border.width: 1

                    Item {
                        readonly property int badgeOffset: Theme.getShadowOffset(jumpBackInBadgeText.font.pixelSize)
                        anchors.centerIn: parent
                        width: jumpBackInBadgeText.implicitWidth
                        height: jumpBackInBadgeText.implicitHeight

                        Text {
                            x: parent.badgeOffset
                            y: parent.badgeOffset
                            text: qsTr("RECENT MULTIPLAYER SERVERS")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.letterSpacing: 1.2 * Theme.scale
                            color: Theme.getShadowColor(jumpBackInBadgeText.color)
                        }

                        Text {
                            id: jumpBackInBadgeText
                            x: 0
                            y: 0
                            text: qsTr("RECENT MULTIPLAYER SERVERS")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.letterSpacing: 1.2 * Theme.scale
                            color: "#E2E8F0"
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Cards ListView (when servers exist)
            ListView {
                id: jumpBackInListView
                visible: shulkRecentServers.hasServers
                Layout.fillWidth: true
                Layout.preferredHeight: root.jumpCardHeight + 2 * Theme.scale
                orientation: ListView.Horizontal
                spacing: Theme.space12
                clip: true
                interactive: false
                model: shulkRecentServers
                currentIndex: root.recentServerIndex

                readonly property int visibleCount: Math.min(3, Math.max(1, shulkRecentServers.count))
                readonly property real cardWidth: Math.floor((width - (visibleCount - 1) * spacing) / visibleCount)

                leftMargin: 0
                rightMargin: 0

                delegate: Rectangle {
                    id: serverCard
                    width: jumpBackInListView.cardWidth
                    height: root.jumpCardHeight
                    radius: Theme.radiusMd
                    color: serverCardMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                    border.color: root.activeSection === 2 && root.recentServerIndex === index ? Theme.borderFocused : Theme.borderSubtle
                    border.width: root.activeSection === 2 && root.recentServerIndex === index ? 2 : 1
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16 * Theme.scale
                        anchors.rightMargin: 16 * Theme.scale
                        anchors.topMargin: 14 * Theme.scale
                        anchors.bottomMargin: 14 * Theme.scale
                        spacing: 16 * Theme.scale

                        // Left: Server Icon in 56x56 Frame
                        Rectangle {
                            Layout.preferredWidth: 56 * Theme.scale
                            Layout.preferredHeight: 56 * Theme.scale
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8 * Theme.scale
                            color: "#121417"
                            border.color: "#2E333D"
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 48 * Theme.scale
                                height: 48 * Theme.scale
                                source: model.iconUrl ? model.iconUrl : "qrc:/shulk/icons/compass.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                asynchronous: true
                            }
                        }

                        // Middle: Server Information Column
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3 * Theme.scale

                            // Line 1: Server Name (Bold Mojangles)
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: serverNameText.implicitHeight + Theme.getShadowOffset(Theme.sizeSubheader)

                                Text {
                                    x: Theme.getShadowOffset(Theme.sizeSubheader)
                                    y: Theme.getShadowOffset(Theme.sizeSubheader)
                                    width: serverNameText.width
                                    height: serverNameText.height
                                    text: serverNameText.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSubheader
                                    font.weight: Font.Bold
                                    color: Theme.getShadowColor(Theme.textPrimary)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: serverNameText
                                    anchors.fill: parent
                                    text: model.serverName
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSubheader
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                            }

                            // Line 2: Subtitle / Instance Name
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: subtitleText.implicitHeight + Theme.getShadowOffset(Theme.sizeBody)

                                Text {
                                    x: Theme.getShadowOffset(Theme.sizeBody)
                                    y: Theme.getShadowOffset(Theme.sizeBody)
                                    width: subtitleText.width
                                    height: subtitleText.height
                                    text: subtitleText.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    color: Theme.getShadowColor(subtitleText.color)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: subtitleText
                                    anchors.fill: parent
                                    text: {
                                        if (!model.instanceExists) {
                                            return model.serverSubtitle ? model.serverSubtitle : qsTr("Friends Server")
                                        }
                                        var sub = model.serverSubtitle ? model.serverSubtitle : qsTr("Multiplayer")
                                        if (model.instanceName && model.instanceName.length > 0) {
                                            return sub + " • " + model.instanceName
                                        }
                                        return sub
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    color: "#94A3B8"
                                    elide: Text.ElideRight
                                }
                            }

                            // Line 3: Status / Players / Latency / Last Played
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8 * Theme.scale
                                Layout.alignment: Qt.AlignVCenter

                                // Online State (Instance exists)
                                Row {
                                    visible: model.instanceExists
                                    spacing: 8 * Theme.scale
                                    Layout.alignment: Qt.AlignVCenter

                                    // Silhouette / Icon + Player Count
                                    Row {
                                        spacing: 5 * Theme.scale
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: model.onlinePlayers >= 0 || model.isOnline

                                        // 2-person geometric silhouette icon matching AI reference
                                        Item {
                                            width: 14 * Theme.scale
                                            height: 10 * Theme.scale
                                            anchors.verticalCenter: parent.verticalCenter

                                            Rectangle {
                                                width: 4 * Theme.scale
                                                height: 4 * Theme.scale
                                                radius: 2 * Theme.scale
                                                x: 0
                                                y: 0
                                                color: "#94A3B8"
                                            }
                                            Rectangle {
                                                width: 7 * Theme.scale
                                                height: 4 * Theme.scale
                                                radius: 2 * Theme.scale
                                                x: -1 * Theme.scale
                                                y: 5 * Theme.scale
                                                color: "#94A3B8"
                                            }
                                            Rectangle {
                                                width: 3.5 * Theme.scale
                                                height: 3.5 * Theme.scale
                                                radius: 1.75 * Theme.scale
                                                x: 7.5 * Theme.scale
                                                y: 0.5 * Theme.scale
                                                color: "#64748B"
                                            }
                                            Rectangle {
                                                width: 6 * Theme.scale
                                                height: 3.5 * Theme.scale
                                                radius: 1.75 * Theme.scale
                                                x: 6.5 * Theme.scale
                                                y: 5.5 * Theme.scale
                                                color: "#64748B"
                                            }
                                        }

                                        Item {
                                            implicitWidth: onlineText.implicitWidth + Theme.getShadowOffset(Theme.sizeSmall)
                                            implicitHeight: onlineText.implicitHeight + Theme.getShadowOffset(Theme.sizeSmall)
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                x: Theme.getShadowOffset(Theme.sizeSmall)
                                                y: Theme.getShadowOffset(Theme.sizeSmall)
                                                text: onlineText.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeSmall
                                                color: Theme.getShadowColor(onlineText.color)
                                            }

                                            Text {
                                                id: onlineText
                                                x: 0
                                                y: 0
                                                text: model.playerCountText ? (model.playerCountText + " online") : (model.onlinePlayers >= 0 ? qsTr("%1 online").arg(model.onlinePlayers) : qsTr("Online"))
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeSmall
                                                color: "#E2E8F0"
                                            }
                                        }
                                    }

                                    // Signal Bars + Ping
                                    Row {
                                        spacing: 5 * Theme.scale
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: model.isOnline || model.pingMs > 0

                                        Row {
                                            spacing: 2 * Theme.scale
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle { width: 2.5 * Theme.scale; height: 3.5 * Theme.scale; color: "#22C55E"; radius: 0.5 }
                                            Rectangle { width: 2.5 * Theme.scale; height: 6 * Theme.scale; color: "#22C55E"; radius: 0.5 }
                                            Rectangle { width: 2.5 * Theme.scale; height: 8.5 * Theme.scale; color: "#22C55E"; radius: 0.5 }
                                            Rectangle { width: 2.5 * Theme.scale; height: 11 * Theme.scale; color: "#22C55E"; radius: 0.5 }
                                        }

                                        Item {
                                            implicitWidth: pingText.implicitWidth + Theme.getShadowOffset(Theme.sizeSmall)
                                            implicitHeight: pingText.implicitHeight + Theme.getShadowOffset(Theme.sizeSmall)
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                x: Theme.getShadowOffset(Theme.sizeSmall)
                                                y: Theme.getShadowOffset(Theme.sizeSmall)
                                                text: pingText.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeSmall
                                                color: Theme.getShadowColor(pingText.color)
                                            }

                                            Text {
                                                id: pingText
                                                x: 0
                                                y: 0
                                                text: model.pingText ? model.pingText : (model.pingMs > 0 ? qsTr("%1ms").arg(model.pingMs) : "24ms")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeSmall
                                                color: "#86EFAC"
                                            }
                                        }
                                    }

                                    // Last Played (Subtle)
                                    Item {
                                        visible: model.lastPlayedText && model.lastPlayedText.length > 0
                                        implicitWidth: lastPlayedSubtleText.implicitWidth + Theme.getShadowOffset(Theme.sizeSmall)
                                        implicitHeight: lastPlayedSubtleText.implicitHeight + Theme.getShadowOffset(Theme.sizeSmall)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            x: Theme.getShadowOffset(Theme.sizeSmall)
                                            y: Theme.getShadowOffset(Theme.sizeSmall)
                                            text: lastPlayedSubtleText.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            color: Theme.getShadowColor(lastPlayedSubtleText.color)
                                        }

                                        Text {
                                            id: lastPlayedSubtleText
                                            x: 0
                                            y: 0
                                            text: "• " + model.lastPlayedText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            color: "#38BDF8"
                                        }
                                    }
                                }

                                // Unavailable State
                                Row {
                                    visible: !model.instanceExists
                                    spacing: 4 * Theme.scale
                                    Layout.alignment: Qt.AlignVCenter

                                    Item {
                                        implicitWidth: unavailText.implicitWidth + Theme.getShadowOffset(Theme.sizeSmall)
                                        implicitHeight: unavailText.implicitHeight + Theme.getShadowOffset(Theme.sizeSmall)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            x: Theme.getShadowOffset(Theme.sizeSmall)
                                            y: Theme.getShadowOffset(Theme.sizeSmall)
                                            text: unavailText.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            color: Theme.getShadowColor(unavailText.color)
                                        }

                                        Text {
                                            id: unavailText
                                            x: 0
                                            y: 0
                                            text: qsTr("Instance unavailable • %1").arg(model.lastPlayedText ? model.lastPlayedText : "3d ago")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            color: "#F87171"
                                        }
                                    }
                                }
                            }
                        }

                        // Right: Join or Remove Button (prominently sized and vertically centered)
                        ShulkButton {
                            id: joinButton
                            Layout.preferredWidth: 84 * Theme.scale
                            Layout.preferredHeight: 36 * Theme.scale
                            Layout.alignment: Qt.AlignVCenter
                            text: model.instanceExists ? qsTr("Join") : qsTr("Remove")
                            variant: model.instanceExists ? "play" : "danger"
                            isFocused: root.activeSection === 2 && root.recentServerIndex === index
                            onClicked: {
                                if (model.instanceExists) {
                                    shulkLauncher.launchServer(model.instanceId, model.serverAddress)
                                } else {
                                    shulkRecentServers.removeRecent(index)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: serverCardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeSection = 2
                            root.recentServerIndex = index
                            if (model.instanceExists) {
                                shulkLauncher.launchServer(model.instanceId, model.serverAddress)
                            } else {
                                shulkRecentServers.removeRecent(index)
                            }
                        }
                    }
                }
            }

            // Empty State (when no recent servers played yet)
            Rectangle {
                id: jumpBackInEmptyState
                visible: !shulkRecentServers.hasServers
                Layout.fillWidth: true
                Layout.preferredHeight: 46 * Theme.scale
                Layout.leftMargin: jumpBackInListView.leftMargin
                Layout.rightMargin: jumpBackInListView.rightMargin
                radius: Theme.radiusMd
                color: "#18121519"
                border.color: Theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space20
                    anchors.rightMargin: Theme.space20
                    spacing: Theme.space16

                    BorderImage {
                        Layout.preferredWidth: 36 * Theme.scale
                        Layout.preferredHeight: 36 * Theme.scale
                        source: "qrc:/shulk/assets/mc/gui/slot.png"
                        border { left: 4; top: 4; right: 4; bottom: 4 }
                        smooth: false

                        Image {
                            anchors.centerIn: parent
                            width: 24 * Theme.scale
                            height: 24 * Theme.scale
                            source: "qrc:/shulk/icons/compass.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: emptyDescText.implicitHeight + Theme.getShadowOffset(Theme.sizeBody)

                        Text {
                            x: Theme.getShadowOffset(Theme.sizeBody)
                            y: Theme.getShadowOffset(Theme.sizeBody)
                            width: emptyDescText.width
                            height: emptyDescText.height
                            text: qsTr("Jump Back In — Servers you play will appear here.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.getShadowColor(emptyDescText.color)
                        }

                        Text {
                            id: emptyDescText
                            anchors.fill: parent
                            text: qsTr("Jump Back In — Servers you play will appear here.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }
    }
}

    function handleAction(action) {
        var maxHero = root.lastPlayedProfile !== null ? 1 : 0
        if (action === 1 || action === Theme.actionUp) {
            if (activeSection === 2) {
                if (featuredPacks.length > 0) {
                    activeSection = 1
                } else {
                    activeSection = 0
                }
                ensureVisible()
                shulkSound.playFocus()
            } else if (activeSection === 1) {
                activeSection = 0
                ensureVisible()
                shulkSound.playFocus()
            } else if (activeSection === 0) {
                enterTopBarRequested()
                shulkSound.playFocus()
            }
        } else if (action === 2 || action === Theme.actionDown) {
            if (activeSection === 0) {
                if (featuredPacks.length > 0) {
                    activeSection = 1
                    ensureVisible()
                    shulkSound.playFocus()
                } else if (shulkRecentServers.hasServers) {
                    activeSection = 2
                    ensureVisible()
                    shulkSound.playFocus()
                }
            } else if (activeSection === 1) {
                if (shulkRecentServers.hasServers) {
                    activeSection = 2
                    ensureVisible()
                    shulkSound.playFocus()
                }
            }
        } else if (action === 3 || action === Theme.actionLeft) {
            if (activeSection === 0 && heroBtnIdx > 0) {
                heroBtnIdx--
                shulkSound.playFocus()
            } else if (activeSection === 1 && featuredIndex > 0) {
                featuredIndex--
                featuredListView.positionViewAtIndex(featuredIndex, ListView.Beginning)
                shulkSound.playFocus()
            } else if (activeSection === 2 && recentServerIndex > 0) {
                recentServerIndex--
                jumpBackInListView.positionViewAtIndex(recentServerIndex, ListView.Beginning)
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
            } else if (activeSection === 2 && recentServerIndex < shulkRecentServers.count - 1) {
                recentServerIndex++
                jumpBackInListView.positionViewAtIndex(recentServerIndex, ListView.Beginning)
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
            } else if (activeSection === 1) {
                if (featuredIndex >= 0 && featuredIndex < featuredPacks.length && !featuredPacks[featuredIndex].comingSoon) {
                    openFeaturedPackRequested(featuredPacks[featuredIndex])
                }
            } else if (activeSection === 2) {
                if (recentServerIndex >= 0 && recentServerIndex < shulkRecentServers.count) {
                    var entry = shulkRecentServers.get(recentServerIndex)
                    if (entry.instanceExists) {
                        shulkLauncher.launchServer(entry.instanceId, entry.serverAddress)
                    } else {
                        shulkRecentServers.removeRecent(recentServerIndex)
                    }
                }
            }
        } else if (action === 6 || action === Theme.actionBack) {
            exitLauncherRequested()
        } else if (action === 7 || action === Theme.actionPrimary) {
            if (activeSection === 2 && recentServerIndex >= 0 && recentServerIndex < shulkRecentServers.count) {
                var sEntry = shulkRecentServers.get(recentServerIndex)
                if (sEntry.instanceExists) {
                    shulkLauncher.launchServer(sEntry.instanceId, sEntry.serverAddress)
                } else {
                    shulkRecentServers.removeRecent(recentServerIndex)
                }
            } else if (activeSection === 0 && lastPlayedProfile) {
                shulkLauncher.launch(lastPlayedProfile.id)
            }
        } else if (action === 8 || action === Theme.actionSecondary) {
            if (activeSection === 2 && recentServerIndex >= 0 && recentServerIndex < shulkRecentServers.count) {
                shulkRecentServers.removeRecent(recentServerIndex)
                shulkSound.playClick()
            } else {
                openDiscoverRequested()
            }
        } else if ((action === 9 || action === Theme.actionMenu)) {
            if (activeSection === 0 && lastPlayedProfile) {
                openOptionsRequested(lastPlayedProfile)
            } else if (activeSection === 2 && recentServerIndex >= 0 && recentServerIndex < shulkRecentServers.count) {
                shulkRecentServers.removeRecent(recentServerIndex)
                shulkSound.playClick()
            }
        }
    }
}

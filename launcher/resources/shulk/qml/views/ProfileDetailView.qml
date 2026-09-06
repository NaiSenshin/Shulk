import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.shulk.launcher
import "../theme"
import "../components"

FocusScope {
    id: root

    property var profile: null
    signal backRequested()
    signal openOptionsRequested(var profile)
    signal confirmDeleteModRequested(int index, string modName)
    signal confirmDeleteResourcePackRequested(int index, string packName)
    signal confirmDeleteShaderRequested(int index, string shaderName)
    signal confirmDeleteWorldRequested(int index, string worldName)

    // Focus state: 0 = Header Buttons, 1 = Sub-Navigation Tabs, 2 = Active Tab Content
    property int focusSection: 0
    property int headerBtnIdx: 0 // 0 = Play/Stop, 1 = Options
    property int activeTab: 0    // 0 = Overview, 1 = Mods, 2 = Resource Packs, 3 = Shaders, 4 = Worlds, 5 = Settings
    property int contentItemIdx: 0
    property int contentActionIdx: 0
    property bool addButtonFocused: false
    property int selectedRamIdx: 2 // Default 6 GB
    property bool contentBrowserOpen: false
    property string browserContentType: "mods"

    property var tabs: [
        qsTr("Overview"),
        qsTr("Mods") + (contentModel.modCount > 0 ? (" (" + contentModel.modCount + ")") : ""),
        qsTr("Resource Packs") + (contentModel.resourcePackCount > 0 ? (" (" + contentModel.resourcePackCount + ")") : ""),
        qsTr("Shaders") + (contentModel.shaderCount > 0 ? (" (" + contentModel.shaderCount + ")") : ""),
        qsTr("Worlds") + (contentModel.worldCount > 0 ? (" (" + contentModel.worldCount + ")") : ""),
        qsTr("Settings")
    ]

    // Instantiate Content Model for this profile
    property alias contentModel: contentModel

    function deleteMod(index) {
        if (contentModel && contentModel.mods) {
            contentModel.mods.deleteMod(index)
        }
    }

    function deleteResourcePack(index) {
        if (contentModel && contentModel.resourcePacks) {
            contentModel.resourcePacks.deletePack(index)
        }
    }

    function deleteShader(index) {
        if (contentModel && contentModel.shaders) {
            contentModel.shaders.deleteShader(index)
        }
    }

    function deleteWorld(index) {
        if (contentModel && contentModel.worlds) {
            contentModel.worlds.deleteWorld(index)
        }
    }

    ShulkContentModel {
        id: contentModel
        instanceId: root.profile ? root.profile.id : ""
    }

    onProfileChanged: {
        if (contentModel && root.profile) {
            contentModel.instanceId = root.profile.id
            contentModel.refreshAll()
        }
    }

    Component.onCompleted: {
        if (contentModel && root.profile) {
            contentModel.instanceId = root.profile.id
            contentModel.refreshAll()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgDeep
        opacity: 0.96
    }

    ColumnLayout {
        visible: !root.contentBrowserOpen
        anchors.fill: parent
        spacing: 0

        // Installed-pack hero, matching the Discover detail hierarchy.
        Item {
            id: installedBanner
            Layout.fillWidth: true
            Layout.preferredHeight: 190 * Theme.scale
            clip: true

            Image {
                anchors.fill: parent
                source: root.profile && root.profile.bannerUrl ? root.profile.bannerUrl : "qrc:/shulk/assets/default_pack_banner.jpg"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                opacity: 0.48
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#420E1015" }
                    GradientStop { position: 0.66; color: "#C00E1015" }
                    GradientStop { position: 1.0; color: Theme.bgDeep }
                }
            }

            RowLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.space16
                spacing: Theme.space12

                ShulkButton {
                    text: qsTr("Back to Library (B)")
                    implicitHeight: 34 * Theme.scale
                    implicitWidth: 170 * Theme.scale
                    onClicked: root.backRequested()
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: 28 * Theme.scale
                    Layout.preferredWidth: installStateText.implicitWidth + 24 * Theme.scale
                    radius: 4
                    color: root.profile && root.profile.isRunning ? "#20351F" : "#222736"
                    border.color: root.profile && root.profile.isRunning ? Theme.mcEmerald : "#38415C"

                    Text {
                        id: installStateText
                        anchors.centerIn: parent
                        text: root.profile && root.profile.isRunning ? qsTr("RUNNING") : qsTr("INSTALLED")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        font.bold: true
                        color: root.profile && root.profile.isRunning ? "#8FE27A" : Theme.mcDiamond
                    }
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space16
                anchors.bottomMargin: Theme.space12
                spacing: Theme.space16

                Rectangle {
                    Layout.preferredWidth: 72 * Theme.scale
                    Layout.preferredHeight: 72 * Theme.scale
                    radius: Theme.radiusMd
                    color: Theme.bgCard
                    border.color: Theme.borderSubtle
                    border.width: 1

                    Image {
                        anchors.centerIn: parent
                        width: 56 * Theme.scale
                        height: 56 * Theme.scale
                        source: root.profile
                                ? (root.profile.iconUrl
                                   ? root.profile.iconUrl
                                   : (root.profile.iconKey && root.profile.iconKey !== "grass" && root.profile.iconKey !== "default"
                                      ? ("image://insticons/" + root.profile.iconKey)
                                      : "qrc:/shulk/icons/grass_block_side.png"))
                                : "qrc:/shulk/icons/grass_block_side.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space4

                    Text {
                        Layout.fillWidth: true
                        text: root.profile ? root.profile.name : qsTr("Installed Modpack")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeTitle
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.profile && root.profile.authors ? qsTr("Installed profile by %1").arg(root.profile.authors) : qsTr("Installed Minecraft profile")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeBody
                        color: Theme.textSecondary
                    }

                    RowLayout {
                        spacing: Theme.space8
                        ShulkBadge { text: "MC " + (root.profile ? root.profile.minecraftVersion : ""); isAccent: true }
                        ShulkBadge {
                            visible: root.profile && root.profile.loaderType !== "Vanilla" && root.profile.loaderType !== ""
                            text: root.profile ? (root.profile.loaderType + " " + root.profile.loaderVersion) : ""
                        }
                        ShulkBadge { visible: contentModel.modCount > 0; text: qsTr("%1 Mods").arg(contentModel.modCount) }
                        Text {
                            text: (root.profile && root.profile.playTime.length > 0 ? qsTr("%1 played").arg(root.profile.playTime) : qsTr("Not played yet"))
                            font.pixelSize: Theme.sizeSmall
                            color: Theme.textMuted
                        }
                    }
                }

                RowLayout {
                    spacing: Theme.space12

                    ShulkButton {
                        id: playBtn
                        text: (root.profile && root.profile.isRunning) ? qsTr("Stop Game") : qsTr("Play Modpack")
                        variant: (root.profile && root.profile.isRunning) ? "danger" : "play"
                        implicitHeight: 42 * Theme.scale
                        implicitWidth: 180 * Theme.scale
                        isFocused: root.focusSection === 0 && root.headerBtnIdx === 0
                        onClicked: {
                            root.focusSection = 0
                            root.headerBtnIdx = 0
                            if (root.profile) {
                                if (root.profile.isRunning) shulkLauncher.kill(root.profile.id)
                                else shulkLauncher.launch(root.profile.id)
                            }
                        }
                    }

                    ShulkButton {
                        text: qsTr("Manage")
                        iconSource: "qrc:/shulk/controller/menu.png"
                        variant: "secondary"
                        implicitHeight: 42 * Theme.scale
                        implicitWidth: 140 * Theme.scale
                        isFocused: root.focusSection === 0 && root.headerBtnIdx === 1
                        onClicked: {
                            root.focusSection = 0
                            root.headerBtnIdx = 1
                            if (root.profile) root.openOptionsRequested(root.profile)
                        }
                    }
                }
            }
        }

        // Installed content command bar.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56 * Theme.scale
            color: Theme.bgCard
            border.color: Theme.borderSubtle
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space16
                anchors.rightMargin: Theme.space16
                spacing: Theme.space8

                Item {
                    Layout.preferredWidth: 40 * Theme.scale
                    Layout.preferredHeight: 40 * Theme.scale

                    ShulkControllerGlyph {
                        anchors.centerIn: parent
                        glyph: "lt"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectPreviousSection()
                    }
                }

                Repeater {
                    model: root.tabs
                    delegate: Rectangle {
                    id: tabItem
                    Layout.preferredHeight: 34 * Theme.scale
                    Layout.preferredWidth: tabText.implicitWidth + Theme.space24
                    radius: 4
                    color: root.activeTab === index ? "#2B354D" : (tabMouse.containsMouse ? "#1E2433" : "transparent")
                    border.color: root.activeTab === index ? "#46567D" : "transparent"
                    border.width: 1.5

                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: modelData
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeBody
                        font.bold: root.activeTab === index
                        color: root.activeTab === index ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof shulkSound !== "undefined") shulkSound.playClick()
                            root.focusSection = 2
                            root.activeTab = index
                            root.addButtonFocused = false
                        }
                    }
                    }
                }

                Item {
                    Layout.preferredWidth: 40 * Theme.scale
                    Layout.preferredHeight: 40 * Theme.scale

                    ShulkControllerGlyph {
                        anchors.centerIn: parent
                        glyph: "rt"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectNextSection()
                    }
                }

                Item { Layout.fillWidth: true }

                ShulkButton {
                    id: addContentButton
                    visible: root.activeTab >= 1 && root.activeTab <= 4
                    text: root.activeTab === 1 ? qsTr("Add Mod")
                          : root.activeTab === 2 ? qsTr("Add Resource Pack")
                          : root.activeTab === 3 ? qsTr("Add Shader Pack")
                          : qsTr("Add World")
                    variant: "play"
                    implicitHeight: 38 * Theme.scale
                    isFocused: root.focusSection === 1 && root.addButtonFocused
                    onClicked: {
                        root.focusSection = 1
                        root.addButtonFocused = true
                        root.addForActiveTab()
                    }
                }
            }
        }

        // Flatter content canvas, shared visually with Discover details.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                color: Theme.bgDeep
            }

            Rectangle {
                anchors.fill: parent
                color: "#08000000"
                visible: root.focusSection === 2
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.bgDeep
                clip: true

                StackLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space16
                    currentIndex: root.activeTab < 6 ? root.activeTab : 0

                    // Tab 0: OVERVIEW
                    ScrollView {
                        contentWidth: availableWidth
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: Theme.space16

                            // About & Description Card
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: descCol.implicitHeight + Theme.space28

                                Rectangle { anchors.fill: parent; radius: Theme.radiusMd; color: Theme.bgCard; border.color: Theme.borderSubtle; border.width: 1 }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: 2
                                    visible: false
                                }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: Theme.radiusMd; color: "transparent"; clip: true

                                    ColumnLayout {
                                        id: descCol
                                        anchors.fill: parent
                                        anchors.margins: Theme.space16
                                        spacing: Theme.space8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: qsTr("About this Profile")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeHeader
                                                font.bold: true
                                                color: Theme.textPrimary
                                                style: Text.Outline; styleColor: "#3F3F3F"
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                visible: root.profile && root.profile.authors ? root.profile.authors.length > 0 : false
                                                text: qsTr("Author: ") + (root.profile ? root.profile.authors : "")
                                                font.pixelSize: Theme.sizeCaption
                                                color: Theme.textGold
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.profile && root.profile.description ? root.profile.description : qsTr("No description provided.")
                                            font.pixelSize: Theme.sizeBody
                                            color: Theme.textSecondary
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }

                            Text {
                                text: qsTr("Profile Specifications")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeHeader
                                font.bold: true
                                color: Theme.textPrimary
                                style: Text.Outline; styleColor: "#3F3F3F"
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: specGrid.implicitHeight + Theme.space28

                                Rectangle { anchors.fill: parent; radius: Theme.radiusMd; color: Theme.bgCard; border.color: Theme.borderSubtle; border.width: 1 }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: 2
                                    visible: false
                                }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: Theme.radiusMd; color: "transparent"; clip: true

                                    GridLayout {
                                        id: specGrid
                                        anchors.fill: parent
                                        anchors.margins: Theme.space16
                                        columns: 2
                                        rowSpacing: Theme.space12
                                        columnSpacing: Theme.space24

                                        Text { text: qsTr("Profile Name:"); color: Theme.textSecondary; font.pixelSize: Theme.sizeBody; Layout.preferredWidth: 160 * Theme.scale }
                                        Text { text: root.profile ? root.profile.name : ""; color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.sizeBody }

                                        Text { text: qsTr("Minecraft Version:"); color: Theme.textSecondary; font.pixelSize: Theme.sizeBody }
                                        Text { text: root.profile ? root.profile.minecraftVersion : ""; color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.sizeBody }

                                        Text { text: qsTr("Mod Loader:"); color: Theme.textSecondary; font.pixelSize: Theme.sizeBody }
                                        Text { text: root.profile ? (root.profile.loaderType + " " + root.profile.loaderVersion) : "Vanilla"; color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.sizeBody }

                                        Text { text: qsTr("Installed Mods:"); color: Theme.textSecondary; font.pixelSize: Theme.sizeBody }
                                        Text { text: contentModel.modCount + qsTr(" mods installed"); color: Theme.textGold; font.bold: true; font.pixelSize: Theme.sizeBody }

                                        Text { text: qsTr("Worlds / Saves:"); color: Theme.textSecondary; font.pixelSize: Theme.sizeBody }
                                        Text { text: contentModel.worldCount + qsTr(" worlds found"); color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.sizeBody }

                                        Text { text: qsTr("Instance Path:"); color: Theme.textSecondary; font.pixelSize: Theme.sizeBody }
                                        Text { text: root.profile ? root.profile.instancePath : ""; color: Theme.textMuted; font.pixelSize: Theme.sizeSmall; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }

                    // Tab 1: MODS
                    Item {
                        ShulkEmptyState {
                            anchors.centerIn: parent
                            visible: contentModel.modCount === 0
                            iconSource: "qrc:/shulk/icons/redstone.png"
                            title: qsTr("No Mods Installed")
                            description: qsTr("Browse compatible mods for this Minecraft version and mod loader.")
                            actionText: qsTr("+ Add Mod")
                            onActionClicked: root.openContentBrowser("mods")
                        }

                        ListView {
                            id: modsListView
                            anchors.fill: parent
                            visible: contentModel.modCount > 0
                            spacing: Theme.space8
                            clip: true
                            model: contentModel.mods
                            currentIndex: root.contentItemIdx

                            delegate: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: 64 * Theme.scale

                                // 1. Solid Dark Outer Line
                                Rectangle { anchors.fill: parent; radius: Theme.radiusMd; color: modMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard; border.color: Theme.borderSubtle; border.width: 1 }

                                // 2. Gradient Border
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: 2
                                    visible: false
                                }

                                // 3. Stone Fill
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 2
                                    color: "transparent"
                                    clip: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.space8
                                        spacing: Theme.space12

                                        // Minecraft Slot Frame for Mod Indicator
                                        BorderImage {
                                            Layout.preferredWidth: 44 * Theme.scale
                                            Layout.preferredHeight: 44 * Theme.scale
                                            source: "qrc:/shulk/assets/mc/gui/slot.png"
                                            border { left: 4; top: 4; right: 4; bottom: 4 }
                                            horizontalTileMode: BorderImage.Stretch
                                            verticalTileMode: BorderImage.Stretch
                                            smooth: false

                                            Image {
                                                anchors.centerIn: parent
                                                width: 34 * Theme.scale
                                                height: 34 * Theme.scale
                                                source: model.iconUrl && model.iconUrl.length > 0
                                                        ? model.iconUrl
                                                        : "qrc:/shulk/icons/redstone.png"
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                                opacity: model.enabled ? 1.0 : 0.4
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: model.name
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeBody
                                                font.bold: true
                                                color: model.enabled ? Theme.textPrimary : Theme.textMuted
                                                style: Text.Outline; styleColor: "#3F3F3F"
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: (model.version && model.version.length > 0 ? (model.version + " | ") : "") + (model.fileSize ? model.fileSize : "")
                                                font.pixelSize: Theme.sizeSmall
                                                color: Theme.textMuted
                                            }
                                        }

                                        ShulkButton {
                                            text: model.enabled ? qsTr("Disable") : qsTr("Enable")
                                            variant: model.enabled ? "secondary" : "play"
                                            implicitHeight: 34 * Theme.scale
                                            isFocused: root.focusSection === 2 && root.activeTab === 1 && root.contentItemIdx === index && root.contentActionIdx === 0
                                            onClicked: contentModel.mods.toggleMod(index)
                                        }

                                        ShulkButton {
                                            text: qsTr("Delete")
                                            variant: "danger"
                                            implicitHeight: 34 * Theme.scale
                                            isFocused: root.focusSection === 2 && root.activeTab === 1 && root.contentItemIdx === index && root.contentActionIdx === 1
                                            onClicked: root.confirmDeleteModRequested(index, model.name)
                                        }
                                    }

                                    MouseArea {
                                        id: modMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            root.focusSection = 2
                                            root.contentItemIdx = index
                                            root.contentActionIdx = 0
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Tab 2: RESOURCE PACKS
                    Item {
                        ShulkEmptyState {
                            anchors.centerIn: parent
                            visible: contentModel.resourcePackCount === 0
                            iconSource: "qrc:/shulk/icons/grass_block.png"
                            title: qsTr("No Resource Packs")
                            description: qsTr("Browse compatible resource packs for this Minecraft version.")
                            actionText: qsTr("+ Add Resource Pack")
                            onActionClicked: root.openContentBrowser("resourcepacks")
                        }

                        ListView {
                            id: resourcePacksListView
                            anchors.fill: parent
                            visible: contentModel.resourcePackCount > 0
                            spacing: Theme.space8
                            clip: true
                            model: contentModel.resourcePacks
                            currentIndex: root.contentItemIdx

                            delegate: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: 64 * Theme.scale

                                Rectangle { anchors.fill: parent; radius: Theme.radiusMd; color: packMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard; border.color: Theme.borderSubtle; border.width: 1 }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: 2
                                    visible: false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 2
                                    color: "transparent"
                                    clip: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.space8
                                        spacing: Theme.space12

                                        BorderImage {
                                            Layout.preferredWidth: 44 * Theme.scale
                                            Layout.preferredHeight: 44 * Theme.scale
                                            source: "qrc:/shulk/assets/mc/gui/slot.png"
                                            border { left: 4; top: 4; right: 4; bottom: 4 }
                                            horizontalTileMode: BorderImage.Stretch
                                            verticalTileMode: BorderImage.Stretch
                                            smooth: false

                                            Image {
                                                anchors.centerIn: parent
                                                width: 34 * Theme.scale
                                                height: 34 * Theme.scale
                                                source: model.iconUrl && model.iconUrl.length > 0
                                                        ? model.iconUrl
                                                        : "qrc:/shulk/icons/grass_block.png"
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: model.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: true
                                            color: Theme.textPrimary
                                            style: Text.Outline; styleColor: "#3F3F3F"
                                            elide: Text.ElideRight
                                        }

                                        ShulkButton {
                                            text: model.enabled ? qsTr("Disable") : qsTr("Enable")
                                            variant: model.enabled ? "secondary" : "play"
                                            implicitHeight: 34 * Theme.scale
                                            isFocused: root.focusSection === 2 && root.activeTab === 2 && root.contentItemIdx === index && root.contentActionIdx === 0
                                            onClicked: contentModel.resourcePacks.togglePack(index)
                                        }

                                        ShulkButton {
                                            text: qsTr("Delete")
                                            variant: "danger"
                                            implicitHeight: 34 * Theme.scale
                                            isFocused: root.focusSection === 2 && root.activeTab === 2 && root.contentItemIdx === index && root.contentActionIdx === 1
                                            onClicked: root.confirmDeleteResourcePackRequested(index, model.name)
                                        }
                                    }

                                    MouseArea {
                                        id: packMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: { root.focusSection = 2; root.contentItemIdx = index; root.contentActionIdx = 0 }
                                    }
                                }
                            }
                        }
                    }

                    // Tab 3: SHADERS
                    Item {
                        ShulkEmptyState {
                            anchors.centerIn: parent
                            visible: contentModel.shaderCount === 0
                            iconSource: "qrc:/shulk/icons/spyglass.png"
                            title: qsTr("No Shader Packs")
                            description: qsTr("Browse compatible shader packs for this Minecraft version.")
                            actionText: qsTr("+ Add Shader Pack")
                            onActionClicked: root.openContentBrowser("shaderpacks")
                        }

                        ListView {
                            id: shadersListView
                            anchors.fill: parent
                            visible: contentModel.shaderCount > 0
                            spacing: Theme.space8
                            clip: true
                            model: contentModel.shaders
                            currentIndex: root.contentItemIdx

                            delegate: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: 64 * Theme.scale

                                Rectangle { anchors.fill: parent; radius: Theme.radiusMd; color: shaderMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard; border.color: Theme.borderSubtle; border.width: 1 }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: 2
                                    visible: false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 2
                                    color: "transparent"
                                    clip: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.space8
                                        spacing: Theme.space12

                                        BorderImage {
                                            Layout.preferredWidth: 44 * Theme.scale
                                            Layout.preferredHeight: 44 * Theme.scale
                                            source: "qrc:/shulk/assets/mc/gui/slot.png"
                                            border { left: 4; top: 4; right: 4; bottom: 4 }
                                            horizontalTileMode: BorderImage.Stretch
                                            verticalTileMode: BorderImage.Stretch
                                            smooth: false

                                            Image {
                                                anchors.centerIn: parent
                                                width: 34 * Theme.scale
                                                height: 34 * Theme.scale
                                                source: model.iconUrl && model.iconUrl.length > 0
                                                        ? model.iconUrl
                                                        : "qrc:/shulk/icons/spyglass.png"
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: model.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: true
                                            color: Theme.textPrimary
                                            style: Text.Outline; styleColor: "#3F3F3F"
                                            elide: Text.ElideRight
                                        }

                                        ShulkButton {
                                            text: qsTr("Delete")
                                            variant: "danger"
                                            implicitHeight: 34 * Theme.scale
                                            isFocused: root.focusSection === 2 && root.activeTab === 3 && root.contentItemIdx === index && root.contentActionIdx === 0
                                            onClicked: root.confirmDeleteShaderRequested(index, model.name)
                                        }
                                    }

                                    MouseArea {
                                        id: shaderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: { root.focusSection = 2; root.contentItemIdx = index; root.contentActionIdx = 0 }
                                    }
                                }
                            }
                        }
                    }

                    // Tab 4: WORLDS
                    Item {
                        ShulkEmptyState {
                            anchors.centerIn: parent
                            visible: contentModel.worldCount === 0
                            iconSource: "qrc:/shulk/icons/grass_block.png"
                            title: qsTr("No Worlds Found")
                            description: qsTr("Create a world in-game or add an existing Minecraft world zip.")
                            actionText: qsTr("+ Add World")
                            onActionClicked: contentModel.importWorld()
                        }

                        ListView {
                            id: worldsListView
                            anchors.fill: parent
                            visible: contentModel.worldCount > 0
                            spacing: Theme.space8
                            clip: true
                            model: contentModel.worlds
                            currentIndex: root.contentItemIdx

                            delegate: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: 64 * Theme.scale

                                Rectangle { anchors.fill: parent; radius: Theme.radiusMd; color: worldMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard; border.color: Theme.borderSubtle; border.width: 1 }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: 2
                                    visible: false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 2
                                    color: "transparent"
                                    clip: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.space8
                                        spacing: Theme.space12

                                        BorderImage {
                                            Layout.preferredWidth: 44 * Theme.scale
                                            Layout.preferredHeight: 44 * Theme.scale
                                            source: "qrc:/shulk/assets/mc/gui/slot.png"
                                            border { left: 4; top: 4; right: 4; bottom: 4 }
                                            horizontalTileMode: BorderImage.Stretch
                                            verticalTileMode: BorderImage.Stretch
                                            smooth: false

                                            Image {
                                                anchors.centerIn: parent
                                                width: 34 * Theme.scale
                                                height: 34 * Theme.scale
                                                source: model.iconPath ? model.iconPath : "qrc:/shulk/icons/grass_block.png"
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: false
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: model.name
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeBody
                                                font.bold: true
                                                color: Theme.textPrimary
                                                style: Text.Outline; styleColor: "#3F3F3F"
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: (model.gameMode.length > 0 ? (model.gameMode + " | ") : "") +
                                                      (model.size.length > 0 ? (model.size + " | ") : "") +
                                                      (model.lastPlayed.length > 0 ? (qsTr("Played: ") + model.lastPlayed) : "")
                                                font.pixelSize: Theme.sizeSmall
                                                color: Theme.textMuted
                                                elide: Text.ElideRight
                                            }
                                        }

                                        ShulkButton {
                                            text: qsTr("Play World")
                                            variant: "play"
                                            implicitHeight: 34 * Theme.scale
                                            isFocused: root.focusSection === 2 && root.activeTab === 4 && root.contentItemIdx === index && root.contentActionIdx === 0
                                            onClicked: {
                                                if (root.profile) {
                                                    shulkLauncher.launch(root.profile.id)
                                                }
                                            }
                                        }

                                        ShulkButton {
                                            text: qsTr("Delete")
                                            variant: "danger"
                                            implicitHeight: 34 * Theme.scale
                                            isFocused: root.focusSection === 2 && root.activeTab === 4 && root.contentItemIdx === index && root.contentActionIdx === 1
                                            onClicked: root.confirmDeleteWorldRequested(index, model.name)
                                        }
                                    }

                                    MouseArea {
                                        id: worldMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: { root.focusSection = 2; root.contentItemIdx = index; root.contentActionIdx = 0 }
                                    }
                                }
                            }
                        }
                    }

                    // Tab 5: SETTINGS
                    ScrollView {
                        contentWidth: availableWidth
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: Theme.space16

                            Text {
                                text: qsTr("Instance Performance & Java Settings")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeHeader
                                font.bold: true
                                color: Theme.textPrimary
                                style: Text.Outline; styleColor: "#3F3F3F"
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 180 * Theme.scale

                                Rectangle { anchors.fill: parent; radius: Theme.radiusMd; color: Theme.bgCard; border.color: Theme.borderSubtle; border.width: 1 }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: 2
                                    visible: false
                                }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 1; radius: Theme.radiusMd; color: "transparent"; clip: true

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.space16
                                        spacing: Theme.space12

                                        Text {
                                            text: qsTr("Memory Allocation (RAM)")
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: true
                                            color: Theme.textPrimary
                                        }

                                        Text {
                                            text: qsTr("Recommended for handhelds with mods: 4 GB to 6 GB.")
                                            font.pixelSize: Theme.sizeCaption
                                            color: Theme.textSecondary
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.space12

                                            Repeater {
                                                model: ["3 GB", "4 GB", "6 GB", "8 GB", "10 GB"]
                                                delegate: ShulkButton {
                                                    Layout.fillWidth: true
                                                    text: modelData
                                                    variant: (root.selectedRamIdx === index) ? "play" : "secondary"
                                                    isFocused: (root.focusSection === 2 && root.activeTab === 5 && root.selectedRamIdx === index)
                                                    onClicked: {
                                                        root.selectedRamIdx = index
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ContentBrowserView {
        id: contentBrowser
        anchors.fill: parent
        visible: root.contentBrowserOpen
        profile: root.profile
        contentType: root.browserContentType
        onBackRequested: root.contentBrowserOpen = false
        onContentInstalled: contentModel.refreshAll()
    }

    function openContentBrowser(type) {
        root.browserContentType = type
        root.contentBrowserOpen = true
    }

    function addForActiveTab() {
        if (root.activeTab === 1) root.openContentBrowser("mods")
        else if (root.activeTab === 2) root.openContentBrowser("resourcepacks")
        else if (root.activeTab === 3) root.openContentBrowser("shaderpacks")
        else if (root.activeTab === 4) contentModel.importWorld()
    }

    function refreshContent() {
        contentModel.refreshAll()
    }

    function contentCountForActiveTab() {
        if (root.activeTab === 1) return contentModel.modCount
        if (root.activeTab === 2) return contentModel.resourcePackCount
        if (root.activeTab === 3) return contentModel.shaderCount
        if (root.activeTab === 4) return contentModel.worldCount
        return 0
    }

    function actionCountForActiveTab() {
        if (root.activeTab === 1 || root.activeTab === 2 || root.activeTab === 4) return 2
        if (root.activeTab === 3) return 1
        return 0
    }

    function positionActiveContent() {
        if (root.activeTab === 1) modsListView.positionViewAtIndex(root.contentItemIdx, ListView.Beginning)
        else if (root.activeTab === 2) resourcePacksListView.positionViewAtIndex(root.contentItemIdx, ListView.Beginning)
        else if (root.activeTab === 3) shadersListView.positionViewAtIndex(root.contentItemIdx, ListView.Beginning)
        else if (root.activeTab === 4) worldsListView.positionViewAtIndex(root.contentItemIdx, ListView.Beginning)
    }

    function selectPreviousSection() {
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
        root.activeTab = root.activeTab > 0 ? root.activeTab - 1 : root.tabs.length - 1
        root.contentItemIdx = 0
        root.contentActionIdx = 0
        root.addButtonFocused = false
        if (root.focusSection === 1) root.focusSection = 2
    }

    function selectNextSection() {
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
        root.activeTab = root.activeTab < root.tabs.length - 1 ? root.activeTab + 1 : 0
        root.contentItemIdx = 0
        root.contentActionIdx = 0
        root.addButtonFocused = false
        if (root.focusSection === 1) root.focusSection = 2
    }

    function handleAction(action) {
        if (root.contentBrowserOpen) {
            contentBrowser.handleAction(action)
            return
        }
        if (action === 1) { // ActionNavigateUp
            if (root.focusSection === 2) {
                if (root.contentItemIdx > 0) {
                    root.contentItemIdx--
                    root.positionActiveContent()
                } else {
                    if (root.activeTab >= 1 && root.activeTab <= 4) {
                        root.focusSection = 1
                        root.addButtonFocused = true
                    } else {
                        root.focusSection = 0
                        root.addButtonFocused = false
                    }
                }
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else if (root.focusSection === 1) {
                root.focusSection = 0
                root.addButtonFocused = false
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 2) { // ActionNavigateDown
            if (root.focusSection === 0) {
                if (root.activeTab >= 1 && root.activeTab <= 4) {
                    root.focusSection = 1
                    root.addButtonFocused = true
                } else {
                    root.focusSection = 2
                    root.addButtonFocused = false
                }
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else if (root.focusSection === 1) {
                root.focusSection = 2
                root.contentItemIdx = 0
                root.contentActionIdx = 0
                root.addButtonFocused = false
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else if (root.focusSection === 2) {
                var maxIdx = 0
                if (root.activeTab === 1) maxIdx = contentModel.modCount - 1
                else if (root.activeTab === 2) maxIdx = contentModel.resourcePackCount - 1
                else if (root.activeTab === 3) maxIdx = contentModel.shaderCount - 1
                else if (root.activeTab === 4) maxIdx = contentModel.worldCount - 1

                if (root.contentItemIdx < maxIdx) {
                    root.contentItemIdx++
                    root.positionActiveContent()
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            }
        } else if (action === 3) { // ActionNavigateLeft
            if (root.focusSection === 0) {
                root.headerBtnIdx = 0
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else if (root.focusSection === 1) {
                // Section changes are reserved for LT/RT.
            } else if (root.focusSection === 2 && root.activeTab >= 1 && root.activeTab <= 4) {
                if (root.contentActionIdx > 0) {
                    root.contentActionIdx--
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (root.focusSection === 2 && root.activeTab === 5) {
                if (root.selectedRamIdx > 0) {
                    root.selectedRamIdx--
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            }
        } else if (action === 4) { // ActionNavigateRight
            if (root.focusSection === 0) {
                root.headerBtnIdx = 1
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else if (root.focusSection === 1) {
                // Section changes are reserved for LT/RT.
            } else if (root.focusSection === 2 && root.activeTab >= 1 && root.activeTab <= 4) {
                if (root.contentActionIdx < root.actionCountForActiveTab() - 1) {
                    root.contentActionIdx++
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (root.focusSection === 2 && root.activeTab === 5) {
                if (root.selectedRamIdx < 4) {
                    root.selectedRamIdx++
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            }
        } else if (action === 5) { // ActionAccept (A)
            if (root.focusSection === 0) {
                if (root.headerBtnIdx === 0) {
                    if (root.profile) {
                        if (typeof shulkSound !== "undefined") shulkSound.playLaunch()
                        if (root.profile.isRunning) shulkLauncher.kill(root.profile.id)
                        else shulkLauncher.launch(root.profile.id)
                    }
                } else if (root.headerBtnIdx === 1) {
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    if (root.profile) root.openOptionsRequested(root.profile)
                }
            } else if (root.focusSection === 1) {
                root.addForActiveTab()
            } else if (root.focusSection === 2) {
                if (root.activeTab === 1 && contentModel.modCount > root.contentItemIdx) {
                    if (root.contentActionIdx === 0) contentModel.mods.toggleMod(root.contentItemIdx)
                    else {
                        var selectedModName = contentModel.mods.data(contentModel.mods.index(root.contentItemIdx, 0), Qt.UserRole + 1)
                        root.confirmDeleteModRequested(root.contentItemIdx, selectedModName ? selectedModName : "selected mod")
                    }
                } else if (root.activeTab === 2 && contentModel.resourcePackCount > root.contentItemIdx) {
                    if (root.contentActionIdx === 0) contentModel.resourcePacks.togglePack(root.contentItemIdx)
                    else {
                        var pName = contentModel.resourcePacks.data(contentModel.resourcePacks.index(root.contentItemIdx, 0), Qt.UserRole + 1)
                        root.confirmDeleteResourcePackRequested(root.contentItemIdx, pName ? pName : "selected pack")
                    }
                } else if (root.activeTab === 3 && contentModel.shaderCount > root.contentItemIdx) {
                    var sName = contentModel.shaders.data(contentModel.shaders.index(root.contentItemIdx, 0), Qt.UserRole + 1)
                    root.confirmDeleteShaderRequested(root.contentItemIdx, sName ? sName : "selected shader")
                } else if (root.activeTab === 4 && root.profile) {
                    if (root.contentActionIdx === 0) {
                        if (typeof shulkSound !== "undefined") shulkSound.playLaunch()
                        shulkLauncher.launch(root.profile.id)
                    } else {
                        var selectedWorldName = contentModel.worlds.data(contentModel.worlds.index(root.contentItemIdx, 0), Qt.UserRole + 1)
                        root.confirmDeleteWorldRequested(root.contentItemIdx, selectedWorldName ? selectedWorldName : "selected world")
                    }
                }
            }
        } else if (action === 6) { // ActionBack (B)
            if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
            root.backRequested()
        } else if (action === 7) { // ActionPrimary (X - Quick Play or Delete in Content)
            if (root.focusSection === 2 && root.activeTab === 1 && contentModel.modCount > root.contentItemIdx) {
                var mName = contentModel.mods.data(contentModel.mods.index(root.contentItemIdx, 0), Qt.UserRole + 1)
                root.confirmDeleteModRequested(root.contentItemIdx, mName ? mName : "selected mod")
            } else if (root.focusSection === 2 && root.activeTab === 2 && contentModel.resourcePackCount > root.contentItemIdx) {
                var packName = contentModel.resourcePacks.data(contentModel.resourcePacks.index(root.contentItemIdx, 0), Qt.UserRole + 1)
                root.confirmDeleteResourcePackRequested(root.contentItemIdx, packName ? packName : "selected pack")
            } else if (root.focusSection === 2 && root.activeTab === 3 && contentModel.shaderCount > root.contentItemIdx) {
                var shaderName = contentModel.shaders.data(contentModel.shaders.index(root.contentItemIdx, 0), Qt.UserRole + 1)
                root.confirmDeleteShaderRequested(root.contentItemIdx, shaderName ? shaderName : "selected shader")
            } else if (root.focusSection === 2 && root.activeTab === 4 && contentModel.worldCount > root.contentItemIdx) {
                var wName = contentModel.worlds.data(contentModel.worlds.index(root.contentItemIdx, 0), Qt.UserRole + 1)
                root.confirmDeleteWorldRequested(root.contentItemIdx, wName ? wName : "selected world")
            } else {
                if (typeof shulkSound !== "undefined") shulkSound.playLaunch()
                if (root.profile) {
                    if (root.profile.isRunning) {
                        shulkLauncher.kill(root.profile.id)
                    } else {
                        shulkLauncher.launch(root.profile.id)
                    }
                }
            }
        } else if (action === 8) { // ActionSearch (Y - Add content)
            if (root.activeTab >= 1 && root.activeTab <= 4) {
                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                root.addForActiveTab()
            }
        } else if (action === 9) { // ActionMenu (Start - Options)
            if (typeof shulkSound !== "undefined") shulkSound.playClick()
            if (root.profile) {
                root.openOptionsRequested(root.profile)
            }
        } else if (action === Theme.actionTriggerLeft || action === 15) { // LT
            root.selectPreviousSection()
        } else if (action === Theme.actionTriggerRight || action === 16) { // RT
            root.selectNextSection()
        }
    }
}

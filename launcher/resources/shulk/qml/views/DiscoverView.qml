// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

FocusScope {
    id: root

    signal createProfileFromPack(string packName)

    property int activeSection: 0 // 0 = Platforms, 1 = Search, 2 = Content (Modpack Grid / Custom Builder)
    property int platformIndex: 0 // 0=Modrinth, 1=CurseForge, 2=FTB, 3=Technic, 4=ATLauncher, 5=Vanilla
    property int packIndex: 0
    property int customBuilderFocus: 0 // 0 = Name, 1 = Version Stepper, 2 = Loader Stepper, 3 = Create Button
    property string searchQuery: ""
    property var activeModpackDetail: null
    readonly property bool inPackDetail: activeModpackDetail !== null

    // Vanilla/Custom Builder State
    property var versions: shulkCreation.releaseVersions
    property var loaders: ["Fabric", "NeoForge", "Forge", "Quilt", "Vanilla"]
    property int selectedVersionIdx: 0
    property int selectedLoaderIdx: 0
    property string customProfileName: (versions && versions.length > 0) ? ("Minecraft " + versions[0]) : "Minecraft 26.2"

    readonly property var platforms: shulkCreation.platforms
    property var currentPacks: shulkCreation.getPacksForPlatform(platforms[platformIndex] ? platforms[platformIndex].id : "modrinth", searchQuery)

    function formatMarkdownInline(raw) {
        if (!raw) return ""
        var s = raw
        s = s.replace(/\*\*(.*?)\*\*/g, '<b style="color: #FFFFFF;">$1</b>')
        s = s.replace(/__(.*?)__/g, '<b style="color: #FFFFFF;">$1</b>')
        s = s.replace(/(^|[^\*])\*([^\*]+)\*([^\*]|$)/g, '$1<i style="color: #CBD5E1;">$2</i>$3')
        return s
    }

    function openPackDetails(pack) {
        root.activeModpackDetail = pack
    }

    // Responsive Grid Columns: fit available width cleanly without horizontal overflow
    readonly property int gridCols: Math.max(1, Math.min(3, Math.floor((mainScroll.width - Theme.space48) / (320 * Theme.scale + Theme.space16))))

    // Toast notification state
    property string toastMessage: ""
    property bool toastIsSuccess: true
    property bool toastVisible: false

    Timer {
        id: toastTimer
        interval: 4000
        onTriggered: root.toastVisible = false
    }

    Timer {
        id: searchDebounceTimer
        interval: 350
        repeat: false
        onTriggered: root.triggerLiveSearch()
    }

    Connections {
        target: shulkCreation
        function onSearchFinished(platform, results) {
            var platId = (platforms && platforms[platformIndex]) ? platforms[platformIndex].id : "modrinth"
            if (platform === platId) {
                root.currentPacks = results
            }
        }
        function onSearchFailed(platform, error) {
            if (root.searchQuery.length > 0) {
                root.toastMessage = qsTr("Note: Network search failed, showing cached packs.")
                root.toastIsSuccess = false
                root.toastVisible = true
                toastTimer.restart()
            }
        }
        function onProfileCreated(targetId) {
            root.toastMessage = qsTr("Modpack installed successfully. Available in Library and Home.")
            root.toastIsSuccess = true
            root.toastVisible = true
            toastTimer.restart()
            if (typeof shulkSound !== "undefined") shulkSound.playLevelUp()
        }
        function onProfileCreationFailed(error) {
            root.toastMessage = qsTr("Installation failed: %1").arg(error)
            root.toastIsSuccess = false
            root.toastVisible = true
            toastTimer.restart()
            if (typeof shulkSound !== "undefined") shulkSound.playError()
        }
    }

    onPlatformIndexChanged: {
        root.packIndex = 0
        root.customBuilderFocus = 0
        mainScroll.contentY = 0
        root.triggerLiveSearch()
        ensurePlatformVisible()
    }

    onPackIndexChanged: {
        ensurePackVisible()
    }

    onActiveSectionChanged: {
        if (root.activeSection === 0 || root.activeSection === 1) {
            mainScroll.contentY = 0
        } else if (root.activeSection === 2) {
            ensurePackVisible()
        }
    }

    onSearchQueryChanged: {
        root.packIndex = 0
        searchDebounceTimer.restart()
    }

    function triggerLiveSearch() {
        var platId = (platforms && platforms[platformIndex]) ? platforms[platformIndex].id : "modrinth"
        if (platId === "vanilla") {
            root.currentPacks = []
            return
        }
        shulkCreation.searchPlatform(platId, searchQuery)
    }

    function ensurePlatformVisible() {
        if (typeof platformScroll !== "undefined" && typeof platRepeater !== "undefined") {
            var activeChild = platRepeater.itemAt(root.platformIndex)
            if (activeChild) {
                if (activeChild.x < platformScroll.contentX) {
                    platformScroll.contentX = activeChild.x
                } else if (activeChild.x + activeChild.width > platformScroll.contentX + platformScroll.width) {
                    platformScroll.contentX = activeChild.x + activeChild.width - platformScroll.width
                }
            }
        }
    }

    function ensurePackVisible() {
        if (root.activeSection !== 2 || !root.currentPacks || root.currentPacks.length === 0) return
        if (root.platformIndex === 5) {
            mainScroll.contentY = 0
            return
        }

        var row = Math.floor(root.packIndex / root.gridCols)
        var cardHeight = 220 * Theme.scale
        var rowSpacing = Theme.space16
        var cardTop = packGrid.y + row * (cardHeight + rowSpacing)
        var cardBottom = cardTop + cardHeight
        var visibleHeight = mainScroll.height - (90 * Theme.scale)

        if (cardBottom > mainScroll.contentY + visibleHeight) {
            mainScroll.contentY = cardBottom - visibleHeight + Theme.space16
        } else if (cardTop < mainScroll.contentY + 40 * Theme.scale) {
            mainScroll.contentY = Math.max(0, cardTop - 40 * Theme.scale)
        }
    }

    Component.onCompleted: {
        root.triggerLiveSearch()
    }

    // Main Layout Flickable
    Flickable {
        id: mainScroll
        anchors.fill: parent
        visible: !root.inPackDetail
        contentWidth: width
        contentHeight: mainCol.implicitHeight + 40 * Theme.scale
        clip: true
        boundsBehavior: Flickable.DragOverBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            active: true
        }

        Behavior on contentY {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutQuad
            }
        }

        ColumnLayout {
            id: mainCol
            width: mainScroll.width
            spacing: Theme.space16

            Item { Layout.preferredHeight: Theme.space4 }

            // =========================================================
            // TITLE & SEARCH HEADER
            // =========================================================
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space24
                Layout.rightMargin: Theme.space24
                spacing: Theme.space16

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: qsTr("Discover")
                        font.pixelSize: Theme.sizeTitle
                        font.bold: true
                        color: Theme.textPrimary
                    }
                    Text {
                        text: qsTr("Browse modpacks across all platforms or create a custom profile")
                        font.pixelSize: Theme.sizeCaption
                        color: Theme.textSecondary
                    }
                }

                Item { Layout.fillWidth: true }

                // Search Bar Inset
                BorderImage {
                    id: searchBox
                    Layout.preferredWidth: 380 * Theme.scale
                    Layout.preferredHeight: 46 * Theme.scale
                    source: ((root.activeSection === 1) || searchInput.activeFocus) ? "qrc:/shulk/assets/mc/gui/text_field_highlighted.png" : "qrc:/shulk/assets/mc/gui/text_field.png"
                    border { left: 4; top: 4; right: 4; bottom: 4 }
                    horizontalTileMode: BorderImage.Stretch
                    verticalTileMode: BorderImage.Stretch
                    smooth: false

                    // Controller focus ring
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        color: "transparent"
                        border.color: Theme.mcDiamond
                        border.width: 2
                        radius: 2
                        visible: root.activeSection === 1
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: Theme.space8

                        Image {
                            source: "qrc:/shulk/icons/spyglass.png"
                            Layout.preferredWidth: 20 * Theme.scale
                            Layout.preferredHeight: 20 * Theme.scale
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textPrimary
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.searchQuery
                            onTextChanged: root.searchQuery = text

                            Text {
                                text: qsTr("Search modpacks... (Press Y)")
                                visible: !searchInput.text && !searchInput.activeFocus
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeBody
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            visible: searchInput.text.length > 0
                            text: "X"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            font.bold: true
                            MouseArea {
                                anchors.fill: parent
                                onClicked: searchInput.text = ""
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.activeSection = 1
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }

            // =========================================================
            // ACTIVE INSTALLATION / STATUS BANNER
            // =========================================================
            Rectangle {
                visible: shulkCreation.isCreating || root.toastVisible
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space24
                Layout.rightMargin: Theme.space24
                height: 42 * Theme.scale
                radius: 4
                color: shulkCreation.isCreating ? "#1B2433" : (root.toastIsSuccess ? "#17291F" : "#331616")
                border.color: shulkCreation.isCreating ? Theme.mcDiamond : (root.toastIsSuccess ? Theme.mcEmerald : Theme.mcRedstone)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space12
                    spacing: Theme.space12

                    Rectangle {
                        width: 12 * Theme.scale
                        height: 12 * Theme.scale
                        radius: 6 * Theme.scale
                        color: shulkCreation.isCreating ? Theme.mcDiamond : (root.toastIsSuccess ? Theme.mcEmerald : Theme.mcRedstone)

                        SequentialAnimation on opacity {
                            running: shulkCreation.isCreating
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: shulkCreation.isCreating ? shulkCreation.creationStatus : root.toastMessage
                        font.pixelSize: Theme.sizeCaption
                        font.bold: true
                        color: "#FFFFFF"
                        elide: Text.ElideRight
                    }
                }
            }
            // =========================================================
            // MODDING PLATFORM SELECTOR TABS (WITH LT / RT QUICK SWITCH)
            // =========================================================
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space24
                Layout.rightMargin: Theme.space24
                spacing: Theme.space8

                // LT Quick Switch Badge
                Rectangle {
                    visible: shulkInput.isController || shulkInput.inputMode === 1
                    Layout.preferredWidth: 36 * Theme.scale
                    Layout.preferredHeight: 34 * Theme.scale
                    radius: 4
                    color: "transparent"

                    ShulkControllerGlyph {
                        anchors.centerIn: parent
                        glyph: "lt"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.platformIndex > 0) {
                                root.platformIndex--
                                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                            }
                        }
                    }
                }

                Flickable {
                    id: platformScroll
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46 * Theme.scale
                    contentWidth: platRowContainer.implicitWidth + Theme.space12
                    clip: true
                    boundsBehavior: Flickable.DragOverBounds

                    Row {
                        id: platRowContainer
                        spacing: Theme.space8
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            id: platRepeater
                            model: root.platforms
                            delegate: Rectangle {
                                height: 40 * Theme.scale
                                width: platRow.implicitWidth + Theme.space16
                                radius: Theme.radiusSm
                                color: root.platformIndex === index ? Theme.bgSurfaceFocused : (platMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard)
                                border.color: (root.activeSection === 0 && root.platformIndex === index) ? Theme.borderFocused : Theme.borderSubtle
                                border.width: (root.activeSection === 0 && root.platformIndex === index) ? 2 : 1
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 3 * Theme.scale
                                    color: Theme.accentPlay
                                    visible: root.platformIndex === index
                                }

                                RowLayout {
                                    id: platRow
                                    anchors.centerIn: parent
                                    spacing: Theme.space8

                                    Image {
                                        source: modelData.icon
                                        Layout.preferredWidth: 18 * Theme.scale
                                        Layout.preferredHeight: 18 * Theme.scale
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                    }

                                    Text {
                                        text: modelData.name
                                        font.pixelSize: Theme.sizeBody
                                        font.bold: true
                                        color: root.platformIndex === index ? "#FFFFFF" : Theme.textPrimary
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: 18 * Theme.scale
                                        Layout.preferredWidth: platBadgeText.implicitWidth + 8
                                        radius: 3
                                        color: root.platformIndex === index ? "#20351F" : Theme.bgDeep
                                        border.color: root.platformIndex === index ? Theme.mcEmerald : Theme.borderSubtle
                                        border.width: 1

                                        Text {
                                            id: platBadgeText
                                            anchors.centerIn: parent
                                            text: modelData.badge
                                            font.pixelSize: Theme.sizeSmall
                                            font.bold: true
                                            color: root.platformIndex === index ? Theme.mcEmerald : Theme.textSecondary
                                        }
                                    }
                                }

                                MouseArea {
                                    id: platMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (typeof shulkSound !== "undefined") shulkSound.playClick()
                                        root.activeSection = 0
                                        root.platformIndex = index
                                    }
                                }
                            }
                        }
                    }
                }

                // RT Quick Switch Badge
                Rectangle {
                    visible: shulkInput.isController || shulkInput.inputMode === 1
                    Layout.preferredWidth: 36 * Theme.scale
                    Layout.preferredHeight: 34 * Theme.scale
                    radius: 4
                    color: "transparent"

                    ShulkControllerGlyph {
                        anchors.centerIn: parent
                        glyph: "rt"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.platformIndex < root.platforms.length - 1) {
                                root.platformIndex++
                                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                            }
                        }
                    }
                }
            }

            // =========================================================
            // PLATFORM SUMMARY BAR
            // =========================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space24
                Layout.rightMargin: Theme.space24
                Layout.preferredHeight: 46 * Theme.scale
                radius: Theme.radiusMd
                color: Theme.bgCard
                border.color: Theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space12
                    spacing: Theme.space12

                    Text {
                        text: (platforms[root.platformIndex] ? platforms[root.platformIndex].name : "")
                        font.pixelSize: Theme.sizeSubheading
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Text {
                        text: "- " + (platforms[root.platformIndex] ? platforms[root.platformIndex].tagline : "")
                        font.pixelSize: Theme.sizeCaption
                        color: Theme.textSecondary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.platformIndex !== 5 && !shulkCreation.isSearching
                        text: qsTr("%1 modpacks").arg(root.currentPacks ? root.currentPacks.length : 0)
                        font.pixelSize: Theme.sizeSmall
                        color: Theme.textGold
                    }
                }
            }

            // =========================================================
            // MODPACK CARDS GRID (PLATFORMS 0 TO 4)
            // =========================================================
            ColumnLayout {
                visible: root.platformIndex !== 5
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space24
                Layout.rightMargin: Theme.space24
                spacing: Theme.space16

                // Live Database Searching Status
                Rectangle {
                    visible: shulkCreation.isSearching
                    Layout.fillWidth: true
                    height: 180 * Theme.scale
                    radius: Theme.radiusMd
                    color: Theme.bgCard
                    border.color: Theme.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.space12

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 32 * Theme.scale
                            height: 32 * Theme.scale
                            radius: 16 * Theme.scale
                            color: "transparent"
                            border.color: Theme.accentShulk
                            border.width: 3

                            RotationAnimator on rotation {
                                from: 0; to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: shulkCreation.isSearching
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: shulkCreation.searchStatus
                            font.pixelSize: Theme.sizeSubheading
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Searching live platform database...")
                            font.pixelSize: Theme.sizeCaption
                            color: Theme.textMuted
                        }
                    }
                }

                // Empty Search State
                Rectangle {
                    visible: !shulkCreation.isSearching && root.currentPacks.length === 0
                    Layout.fillWidth: true
                    height: 160 * Theme.scale
                    radius: Theme.radiusMd
                    color: Theme.bgCard
                    border.color: Theme.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.space12

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("No modpacks found matching \"%1\"").arg(root.searchQuery)
                            font.pixelSize: Theme.sizeSubheading
                            color: Theme.textMuted
                        }

                        ShulkButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Clear Search")
                            variant: "secondary"
                            onClicked: root.searchQuery = ""
                        }
                    }
                }

                // Grid of Modpack Cards
                GridLayout {
                    id: packGrid
                    visible: !shulkCreation.isSearching && root.currentPacks.length > 0
                    Layout.fillWidth: true
                    columns: root.gridCols
                    columnSpacing: Theme.space16
                    rowSpacing: Theme.space16

                    Repeater {
                        model: root.currentPacks
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 235 * Theme.scale
                            scale: (root.activeSection === 2 && root.packIndex === index) ? 1.02 : 1.0

                            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

                            // Flat card surface shared with Home and Play.
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusMd
                                color: cardMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                                border.color: root.activeSection === 2 && root.packIndex === index ? Theme.borderFocused : Theme.borderSubtle
                                border.width: root.activeSection === 2 && root.packIndex === index ? 2 : 1
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: false
                            }

                        // Content layer.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: root.activeSection === 2 && root.packIndex === index ? 2 : 1
                            radius: Theme.radiusMd
                            color: "transparent"
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space14
                                spacing: Theme.space8

                                // Top Header Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.space12

                                    // Official Minecraft Item Slot Frame
                                    BorderImage {
                                        Layout.preferredWidth: 48 * Theme.scale
                                        Layout.preferredHeight: 48 * Theme.scale
                                        source: "qrc:/shulk/assets/mc/gui/slot.png"
                                        border { left: 4; top: 4; right: 4; bottom: 4 }
                                        horizontalTileMode: BorderImage.Stretch
                                        verticalTileMode: BorderImage.Stretch
                                        smooth: false

                                        Image {
                                            id: packIcon
                                            anchors.centerIn: parent
                                            width: 40 * Theme.scale
                                            height: 40 * Theme.scale
                                            source: (modelData.iconUrl && modelData.iconUrl.length > 0) ? modelData.iconUrl : "qrc:/shulk/icons/grass_block_side.png"
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            mipmap: true
                                            asynchronous: true
                                            onStatusChanged: {
                                                if (status === Image.Error) {
                                                    source = "qrc:/shulk/icons/grass_block_side.png"
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: true
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: qsTr("By %1 | %2 downloads").arg(modelData.author).arg(modelData.downloads)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            color: Theme.textMuted
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // Description (Fills available space up to the white line, strictly eliding with ...)
                                Item {
                                    id: descContainer
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    Text {
                                        id: descText
                                        anchors.fill: parent
                                        text: modelData.description ? modelData.description.replace(/\s+/g, ' ').trim() : ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeCaption
                                        color: Theme.textSecondary
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        maximumLineCount: Math.max(1, Math.min(3, Math.floor(descContainer.height / (fontMetrics.lineSpacing > 0 ? fontMetrics.lineSpacing : 16))))
                                    }

                                    FontMetrics {
                                        id: fontMetrics
                                        font: descText.font
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Theme.borderSubtle
                                }

                                // Badges & Install Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.space8

                                    ShulkBadge {
                                        text: "MC " + modelData.version
                                        isAccent: true
                                    }

                                    ShulkBadge {
                                        text: modelData.loader
                                        textColor: "#BFC7B9"
                                    }

                                    Item { Layout.fillWidth: true }

                                    ShulkButton {
                                        text: qsTr("View")
                                        variant: "play"
                                        implicitHeight: 36 * Theme.scale
                                        implicitWidth: 115 * Theme.scale
                                        isFocused: (root.activeSection === 2 && root.packIndex === index)
                                        onClicked: {
                                            if (typeof shulkSound !== "undefined") shulkSound.playClick()
                                            root.activeSection = 2
                                            root.packIndex = index
                                            root.activeModpackDetail = modelData
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: false
                                onClicked: {
                                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                                    root.activeSection = 2
                                    root.packIndex = index
                                    root.activeModpackDetail = modelData
                                }
                            }
                        }

                        // Selection is represented by the shared card border.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 5
                            color: "transparent"
                            border.color: Theme.mcDiamond
                            border.width: 2
                            visible: false
                        }
                    }
                }
                }
            }

            // =========================================================
            // VANILLA & CUSTOM PROFILE BUILDER (PLATFORM 5)
            // =========================================================
            Rectangle {
                visible: root.platformIndex === 5
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space24
                Layout.rightMargin: Theme.space24
                Layout.preferredHeight: customCol.implicitHeight + Theme.space32
                radius: Theme.radiusMd
                color: Theme.bgCard
                border.color: Theme.borderSubtle
                border.width: 1

                ColumnLayout {
                    id: customCol
                    anchors.fill: parent
                    anchors.margins: Theme.space24
                    spacing: Theme.space16

                    RowLayout {
                        spacing: Theme.space12
                        Image {
                            source: "qrc:/shulk/icons/bookshelf.png"
                            Layout.preferredWidth: 26 * Theme.scale
                            Layout.preferredHeight: 26 * Theme.scale
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                        }
                        Text {
                            text: qsTr("Configure Custom Minecraft Instance")
                            font.pixelSize: Theme.sizeHeader
                            font.bold: true
                            color: Theme.textPrimary
                        }
                    }

                    // Field 0: Instance Name
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space16

                        Text {
                            text: qsTr("Instance Name:");
                            color: (root.activeSection === 2 && root.customBuilderFocus === 0) ? "#FFFFFF" : Theme.textSecondary;
                            font.pixelSize: Theme.sizeBody;
                            font.bold: (root.activeSection === 2 && root.customBuilderFocus === 0)
                            Layout.preferredWidth: 160 * Theme.scale
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42 * Theme.scale
                            radius: 4
                            color: (root.activeSection === 2 && root.customBuilderFocus === 0) ? "#262B37" : "#121418"
                            border.color: (root.activeSection === 2 && root.customBuilderFocus === 0) ? Theme.focusRing : "#0A0B0E"
                            border.width: (root.activeSection === 2 && root.customBuilderFocus === 0) ? 2 : 1

                            TextInput {
                                id: customNameInput
                                anchors.fill: parent
                                anchors.margins: Theme.space10
                                font.pixelSize: Theme.sizeBody
                                font.bold: true
                                color: "#FFFFFF"
                                text: root.customProfileName
                                onTextChanged: root.customProfileName = text
                                verticalAlignment: TextInput.AlignVCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.activeSection = 2
                                    root.customBuilderFocus = 0
                                    customNameInput.forceActiveFocus()
                                }
                            }
                        }
                    }

                    // Field 1: Minecraft Version Stepper
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space16

                        Text {
                            text: qsTr("Minecraft Version:");
                            color: (root.activeSection === 2 && root.customBuilderFocus === 1) ? "#FFFFFF" : Theme.textSecondary;
                            font.pixelSize: Theme.sizeBody;
                            font.bold: (root.activeSection === 2 && root.customBuilderFocus === 1)
                            Layout.preferredWidth: 160 * Theme.scale
                        }

                        ShulkButton {
                            text: "<"
                            variant: "secondary"
                            implicitWidth: 44 * Theme.scale
                            implicitHeight: 42 * Theme.scale
                            onClicked: {
                                if (root.selectedVersionIdx < root.versions.length - 1) {
                                    root.selectedVersionIdx++
                                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42 * Theme.scale
                            radius: 4
                            color: (root.activeSection === 2 && root.customBuilderFocus === 1) ? "#262B37" : "#121418"
                            border.color: (root.activeSection === 2 && root.customBuilderFocus === 1) ? Theme.focusRing : "#0A0B0E"
                            border.width: (root.activeSection === 2 && root.customBuilderFocus === 1) ? 2 : 1

                            Text {
                                anchors.centerIn: parent
                                text: root.versions.length > root.selectedVersionIdx ? root.versions[root.selectedVersionIdx] : "26.2"
                                font.pixelSize: Theme.sizeSubheading
                                font.bold: true
                                color: Theme.mcDiamond
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.activeSection = 2
                                    root.customBuilderFocus = 1
                                }
                            }
                        }

                        ShulkButton {
                            text: ">"
                            variant: "secondary"
                            implicitWidth: 44 * Theme.scale
                            implicitHeight: 42 * Theme.scale
                            onClicked: {
                                if (root.selectedVersionIdx > 0) {
                                    root.selectedVersionIdx--
                                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                                }
                            }
                        }
                    }

                    // Field 2: Mod Loader Stepper
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space16

                        Text {
                            text: qsTr("Mod Loader:");
                            color: (root.activeSection === 2 && root.customBuilderFocus === 2) ? "#FFFFFF" : Theme.textSecondary;
                            font.pixelSize: Theme.sizeBody;
                            font.bold: (root.activeSection === 2 && root.customBuilderFocus === 2)
                            Layout.preferredWidth: 160 * Theme.scale
                        }

                        ShulkButton {
                            text: "<"
                            variant: "secondary"
                            implicitWidth: 44 * Theme.scale
                            implicitHeight: 42 * Theme.scale
                            onClicked: {
                                if (root.selectedLoaderIdx > 0) {
                                    root.selectedLoaderIdx--
                                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42 * Theme.scale
                            radius: 4
                            color: (root.activeSection === 2 && root.customBuilderFocus === 2) ? "#262B37" : "#121418"
                            border.color: (root.activeSection === 2 && root.customBuilderFocus === 2) ? Theme.focusRing : "#0A0B0E"
                            border.width: (root.activeSection === 2 && root.customBuilderFocus === 2) ? 2 : 1

                            Text {
                                anchors.centerIn: parent
                                text: root.loaders[root.selectedLoaderIdx]
                                font.pixelSize: Theme.sizeSubheading
                                font.bold: true
                                color: root.loaders[root.selectedLoaderIdx] === "Vanilla" ? "#FFFFFF" : Theme.mcEmerald
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.activeSection = 2
                                    root.customBuilderFocus = 2
                                }
                            }
                        }

                        ShulkButton {
                            text: ">"
                            variant: "secondary"
                            implicitWidth: 44 * Theme.scale
                            implicitHeight: 42 * Theme.scale
                            onClicked: {
                                if (root.selectedLoaderIdx < root.loaders.length - 1) {
                                    root.selectedLoaderIdx++
                                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: Theme.space8 }

                    // Field 3: Create Button
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }

                        ShulkButton {
                            text: qsTr("Create Instance")
                            variant: "play"
                            implicitHeight: 44 * Theme.scale
                            implicitWidth: 220 * Theme.scale
                            isFocused: (root.activeSection === 2 && root.customBuilderFocus === 3)
                            onClicked: {
                                if (typeof shulkSound !== "undefined") shulkSound.playLaunch()
                                var ver = root.versions.length > root.selectedVersionIdx ? root.versions[root.selectedVersionIdx] : "26.2"
                                var ldr = root.loaders[root.selectedLoaderIdx]
                                shulkCreation.createProfile(root.customProfileName, ver, ldr)
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 90 * Theme.scale }
        }
    }

    // =========================================================
    // GAMEPAD & CONTROLLER NAVIGATION ROUTER
    // =========================================================
    function handleAction(action) {
        if (root.inPackDetail) {
            return packDetailView.handleAction(action)
        }

        if (action === 1) { // ActionNavigateUp
            if (root.activeSection === 2) {
                if (root.platformIndex === 5) {
                    if (root.customBuilderFocus > 0) {
                        root.customBuilderFocus--
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    } else {
                        root.activeSection = 1
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    }
                } else {
                    if (root.packIndex - root.gridCols >= 0) {
                        root.packIndex -= root.gridCols
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    } else {
                        root.activeSection = 1
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    }
                }
            } else if (root.activeSection === 1) {
                root.activeSection = 0
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 2) { // ActionNavigateDown
            if (root.activeSection === 0) {
                root.activeSection = 1
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else if (root.activeSection === 1) {
                root.activeSection = 2
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else if (root.activeSection === 2) {
                if (root.platformIndex === 5) {
                    if (root.customBuilderFocus < 3) {
                        root.customBuilderFocus++
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    }
                } else {
                    if (root.packIndex + root.gridCols < root.currentPacks.length) {
                        root.packIndex += root.gridCols
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    }
                }
            }
        } else if (action === 3) { // ActionNavigateLeft
            if (root.activeSection === 0) {
                if (root.platformIndex > 0) {
                    root.platformIndex--
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (root.activeSection === 2) {
                if (root.platformIndex === 5) {
                    if (root.customBuilderFocus === 1 && root.selectedVersionIdx < root.versions.length - 1) {
                        root.selectedVersionIdx++
                        if (typeof shulkSound !== "undefined") shulkSound.playTick()
                    } else if (root.customBuilderFocus === 2 && root.selectedLoaderIdx > 0) {
                        root.selectedLoaderIdx--
                        if (typeof shulkSound !== "undefined") shulkSound.playTick()
                    }
                } else {
                    if (root.packIndex > 0) {
                        root.packIndex--
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    }
                }
            }
        } else if (action === 4) { // ActionNavigateRight
            if (root.activeSection === 0) {
                if (root.platformIndex < root.platforms.length - 1) {
                    root.platformIndex++
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (root.activeSection === 2) {
                if (root.platformIndex === 5) {
                    if (root.customBuilderFocus === 1 && root.selectedVersionIdx > 0) {
                        root.selectedVersionIdx--
                        if (typeof shulkSound !== "undefined") shulkSound.playTick()
                    } else if (root.customBuilderFocus === 2 && root.selectedLoaderIdx < root.loaders.length - 1) {
                        root.selectedLoaderIdx++
                        if (typeof shulkSound !== "undefined") shulkSound.playTick()
                    }
                } else {
                    if (root.packIndex < root.currentPacks.length - 1) {
                        root.packIndex++
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    }
                }
            }
        } else if (action === 5) { // ActionAccept (A)
            if (root.activeSection === 1) {
                searchInput.forceActiveFocus()
                if (typeof shulkSound !== "undefined") shulkSound.playClick()
            } else if (root.activeSection === 2) {
                if (root.platformIndex === 5) {
                    if (root.customBuilderFocus === 0) {
                        customNameInput.forceActiveFocus()
                    } else if (root.customBuilderFocus === 3) {
                        if (typeof shulkSound !== "undefined") shulkSound.playLaunch()
                        var ver = root.versions.length > root.selectedVersionIdx ? root.versions[root.selectedVersionIdx] : "26.2"
                        var ldr = root.loaders[root.selectedLoaderIdx]
                        shulkCreation.createProfile(root.customProfileName, ver, ldr)
                    }
                } else {
                    if (root.packIndex < root.currentPacks.length) {
                        if (typeof shulkSound !== "undefined") shulkSound.playClick()
                        root.activeModpackDetail = root.currentPacks[root.packIndex]
                    }
                }
            }
        } else if (action === 6) { // ActionBack (B)
            if (root.activeSection === 1) {
                searchInput.focus = false
                root.activeSection = 0
            } else if (root.activeSection === 2) {
                root.activeSection = 0
            }
            if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
        } else if (action === 7) { // ActionPrimary (X)
            // Quick Cycle Source with X button from anywhere!
            root.platformIndex = (root.platformIndex + 1) % root.platforms.length
            if (typeof shulkSound !== "undefined") shulkSound.playFocus()
        } else if (action === 8 || action === 10) { // ActionSecondary / ActionSearch (Y)
            root.activeSection = 1
            searchInput.forceActiveFocus()
            if (typeof shulkSound !== "undefined") shulkSound.playClick()
        } else if (action === 15) { // ActionTriggerLeft (LT / L2 / Q)
            if (root.platformIndex > 0) {
                root.platformIndex--
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 16) { // ActionTriggerRight (RT / R2 / E)
            if (root.platformIndex < root.platforms.length - 1) {
                root.platformIndex++
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        }
    }

    // In-App Modpack Detail & Overview View
    ModpackDetailView {
        id: packDetailView
        anchors.fill: parent
        visible: root.inPackDetail
        pack: root.activeModpackDetail
        onBackRequested: {
            root.activeModpackDetail = null
        }
        onInstallRequested: {
            if (root.activeModpackDetail) {
                var p = root.activeModpackDetail
                shulkCreation.installModpack(p.name, p.version, p.loader, p.iconUrl, p.bannerUrl, p.description, p.author,
                                             p.downloadUrl ? p.downloadUrl : "", p.id ? p.id : "",
                                             p.platform ? p.platform : "modrinth", p.packVersion ? p.packVersion : "")
                root.activeModpackDetail = null
            }
        }
    }
}

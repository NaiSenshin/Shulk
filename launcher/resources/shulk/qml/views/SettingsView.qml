import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"
import "../components"

FocusScope {
    id: root

    property int activeCategory: 0
    property int focusPane: 0 // 0: Category Sidebar, 1: Settings Content
    property int itemRow: 0
    property int itemCol: 0

    // Skin Viewer state
    property int skinViewMode: 0
    property int skinAccountIndex: 0
    property double skinCacheBuster: 0
    property bool inAccountSkinViewer: false

    // Panorama Dropdown state
    property bool panoramaDropdownOpen: false
    property int panoramaDropdownIndex: 0

    onActiveCategoryChanged: {
        inAccountSkinViewer = false
        panoramaDropdownOpen = false
        ensureCategoryVisible()
    }

    signal enterTopBarRequested()
    signal addAccountRequested()
    signal openPanoramaDialogRequested()
    signal confirmRemoveAccountRequested(int index, string name)

    function ensureCategoryVisible() {
        if (typeof categoryScroll !== "undefined" && typeof catRepeater !== "undefined") {
            var activeChild = catRepeater.itemAt(root.activeCategory)
            if (activeChild && categoryScroll.contentWidth > categoryScroll.width) {
                var targetX = activeChild.x - (categoryScroll.width - activeChild.width) / 2
                categoryScroll.contentX = Math.max(0, Math.min(categoryScroll.contentWidth - categoryScroll.width, targetX))
            }
        }
    }

    function cycleCategory(direction) {
        var next = root.activeCategory + direction
        while (next >= 0 && next < root.categories.length && root.categories[next].disabled) {
            next += direction
        }
        if (next >= 0 && next < root.categories.length) {
            root.activeCategory = next
            root.itemRow = 0
            root.itemCol = 0
            ensureCategoryVisible()
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        }
    }

    readonly property var ramPresets: [
        { label: "2 GB", val: 2048 },
        { label: "4 GB", val: 4096 },
        { label: "6 GB (Rec)", val: 6144 },
        { label: "8 GB", val: 8192 },
        { label: "10 GB", val: 10240 },
        { label: "12 GB", val: 12288 }
    ]

    readonly property var minRamPresets: [
        { label: "512 MB", val: 512 },
        { label: "1024 MB (1 GB)", val: 1024 },
        { label: "2048 MB (2 GB)", val: 2048 }
    ]

    readonly property var blurPresets: [
        { label: qsTr("Off (Sharp)"), val: 0 },
        { label: qsTr("Subtle (Default)"), val: 14 },
        { label: qsTr("Medium"), val: 24 },
        { label: qsTr("Heavy"), val: 40 }
    ]

    property var categories: [
        {
            id: "display",
            name: qsTr("Display & Scale"),
            iconSource: "qrc:/shulk/icons/grass_block.png",
            badge: "",
            tagline: qsTr("Window resolution, interface scaling, and Minecraft background panoramas"),
            disabled: false
        },
        {
            id: "controller",
            name: qsTr("Controller"),
            iconSource: "qrc:/shulk/icons/pickaxe.png",
            badge: qsTr("Coming Soon"),
            tagline: qsTr("Handheld gamepad mapping, stick deadzones, and rumble feedback"),
            disabled: true
        },
        {
            id: "audio",
            name: qsTr("Audio & Sounds"),
            iconSource: "qrc:/shulk/icons/noteblock.png",
            badge: "",
            tagline: qsTr("Master volume, UI sound effects, and audio output settings"),
            disabled: false
        },
        {
            id: "java",
            name: qsTr("Java & Memory"),
            iconSource: "qrc:/shulk/icons/redstone.png",
            badge: "",
            tagline: qsTr("Java runtime environment, JVM arguments, and RAM allocation"),
            disabled: false
        },
        {
            id: "accounts",
            name: qsTr("Accounts"),
            iconSource: "qrc:/shulk/icons/steve_head.png",
            badge: (typeof shulkAccounts !== "undefined" && shulkAccounts.count > 0) ? (shulkAccounts.count + " " + (shulkAccounts.count === 1 ? qsTr("Account") : qsTr("Accounts"))) : qsTr("0 Accounts"),
            tagline: qsTr("Microsoft Minecraft accounts, active player profile, and 3D skin viewer"),
            disabled: false
        },
        {
            id: "about",
            name: qsTr("About Shulk"),
            iconSource: "qrc:/shulk/icons/shulk.png",
            badge: "v1.1.0",
            tagline: qsTr("Application version, dual-channel updates, credits, and system info"),
            disabled: false
        }
    ]

    // Top-Level Pinned ColumnLayout (matching DiscoverView)
    ColumnLayout {
        id: rootCol
        anchors.fill: parent
        spacing: Theme.space16

        Item { Layout.preferredHeight: Theme.space4 }

        // =========================================================
        // 1. TITLE & INFO HEADER (matching DiscoverView pattern)
        // =========================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space24
            Layout.rightMargin: Theme.space24
            spacing: Theme.space16

            ColumnLayout {
                spacing: 2

                Item {
                    readonly property int shadowOff: Theme.getShadowOffset(Theme.sizeTitle)
                    implicitWidth: settingsTitleText.implicitWidth
                    implicitHeight: settingsTitleText.implicitHeight

                    Text {
                        x: parent.shadowOff
                        y: parent.shadowOff
                        text: qsTr("Settings")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeTitle
                        font.bold: true
                        color: Theme.getShadowColor(settingsTitleText.color)
                    }
                    Text {
                        id: settingsTitleText
                        x: 0; y: 0
                        text: qsTr("Settings")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeTitle
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                Item {
                    readonly property int shadowOff: Theme.getShadowOffset(Theme.sizeCaption)
                    implicitWidth: settingsSubText.implicitWidth
                    implicitHeight: settingsSubText.implicitHeight

                    Text {
                        x: parent.shadowOff
                        y: parent.shadowOff
                        text: qsTr("Configure display, interface scaling, audio, java runtime, and accounts")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeCaption
                        color: Theme.getShadowColor(settingsSubText.color)
                    }
                    Text {
                        id: settingsSubText
                        x: 0; y: 0
                        text: qsTr("Configure display, interface scaling, audio, java runtime, and accounts")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeCaption
                        color: Theme.textSecondary
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // =========================================================
        // 2. HORIZONTAL CATEGORY TABS (aligned with DiscoverView)
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
                        onClicked: root.cycleCategory(-1)
                    }
                }

                Flickable {
                    id: categoryScroll
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46 * Theme.scale
                    contentWidth: catRowContainer.implicitWidth + Theme.space12
                    clip: true
                    boundsBehavior: Flickable.DragOverBounds

                    Row {
                        id: catRowContainer
                        spacing: Theme.space8
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            id: catRepeater
                            model: root.categories
                            delegate: Rectangle {
                                height: 40 * Theme.scale
                                width: catTabRow.implicitWidth + Theme.space16
                                radius: Theme.radiusSm
                                color: root.activeCategory === index ? Theme.bgSurfaceFocused : (catTabMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard)
                                border.color: (root.focusPane === 0 && root.activeCategory === index) ? Theme.borderFocused : Theme.borderSubtle
                                border.width: (root.focusPane === 0 && root.activeCategory === index) ? 2 : 1
                                opacity: modelData.disabled ? 0.45 : 1.0
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                // Emerald underline indicator on active tab
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 3 * Theme.scale
                                    color: Theme.accentPlay
                                    visible: root.activeCategory === index
                                }

                                RowLayout {
                                    id: catTabRow
                                    anchors.centerIn: parent
                                    spacing: Theme.space8

                                    Image {
                                        source: modelData.iconSource
                                        Layout.preferredWidth: 18 * Theme.scale
                                        Layout.preferredHeight: 18 * Theme.scale
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                    }

                                    Item {
                                        implicitWidth: catTabNameText.implicitWidth
                                        implicitHeight: catTabNameText.implicitHeight
                                        readonly property int tabOff: Theme.getShadowOffset(catTabNameText.font.pixelSize)

                                        Text {
                                            x: parent.tabOff; y: parent.tabOff
                                            text: catTabNameText.text
                                            font: catTabNameText.font
                                            color: Theme.getShadowColor(catTabNameText.color)
                                        }
                                        Text {
                                            id: catTabNameText
                                            x: 0; y: 0
                                            text: modelData.name
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: root.activeCategory === index
                                            color: modelData.disabled ? "#7E828A" : (root.activeCategory === index ? "#FFFFFF" : Theme.textPrimary)
                                        }
                                    }

                                    Rectangle {
                                        visible: !!modelData.badge && modelData.badge.length > 0
                                        Layout.preferredHeight: 18 * Theme.scale
                                        Layout.preferredWidth: catBadgeText.implicitWidth + 8
                                        radius: 3
                                        color: modelData.disabled ? "#352A18" : (root.activeCategory === index ? "#20351F" : Theme.bgDeep)
                                        border.color: modelData.disabled ? "#8A6D3B" : (root.activeCategory === index ? Theme.mcEmerald : Theme.borderSubtle)
                                        border.width: 1

                                        Item {
                                            anchors.centerIn: parent
                                            implicitWidth: catBadgeText.implicitWidth
                                            implicitHeight: catBadgeText.implicitHeight
                                            readonly property int badgeOff: Theme.getShadowOffset(catBadgeText.font.pixelSize)

                                            Text {
                                                x: parent.badgeOff; y: parent.badgeOff
                                                text: catBadgeText.text
                                                font: catBadgeText.font
                                                color: Theme.getShadowColor(catBadgeText.color)
                                            }
                                            Text {
                                                id: catBadgeText
                                                x: 0; y: 0
                                                text: modelData.badge
                                                font.pixelSize: Theme.sizeSmall
                                                font.bold: true
                                                color: modelData.disabled ? "#FFAA00" : (root.activeCategory === index ? Theme.mcEmerald : Theme.textSecondary)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: catTabMouse
                                    anchors.fill: parent
                                    enabled: !modelData.disabled
                                    hoverEnabled: !modelData.disabled
                                    cursorShape: modelData.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.disabled) return
                                        root.activeCategory = index
                                        root.focusPane = 0
                                        if (typeof shulkSound !== "undefined") shulkSound.playClick()
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
                        onClicked: root.cycleCategory(1)
                    }
                }
        }

        // =========================================================
        // 3. CATEGORY SUMMARY BAR (matching DiscoverView)
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
                anchors.leftMargin: Theme.space16
                anchors.rightMargin: Theme.space16
                spacing: Theme.space12

                BorderImage {
                    Layout.preferredWidth: 30 * Theme.scale
                    Layout.preferredHeight: 30 * Theme.scale
                    source: "qrc:/shulk/assets/mc/gui/slot.png"
                    border { left: 4; top: 4; right: 4; bottom: 4 }
                    horizontalTileMode: BorderImage.Stretch
                    verticalTileMode: BorderImage.Stretch
                    smooth: false

                    Image {
                        anchors.centerIn: parent
                        width: 20 * Theme.scale
                        height: 20 * Theme.scale
                        source: root.categories[root.activeCategory].iconSource
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }
                }

                Item {
                    implicitWidth: catSummaryTitle.implicitWidth
                    implicitHeight: catSummaryTitle.implicitHeight
                    readonly property int off: Theme.getShadowOffset(catSummaryTitle.font.pixelSize)

                    Text {
                        x: parent.off; y: parent.off
                        text: catSummaryTitle.text
                        font: catSummaryTitle.font
                        color: Theme.getShadowColor(catSummaryTitle.color)
                    }
                    Text {
                        id: catSummaryTitle
                        x: 0; y: 0
                        text: root.categories[root.activeCategory].name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSubheading
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                Item {
                    implicitWidth: catSummaryTag.implicitWidth
                    implicitHeight: catSummaryTag.implicitHeight
                    readonly property int off: Theme.getShadowOffset(catSummaryTag.font.pixelSize)

                    Text {
                        x: parent.off; y: parent.off
                        text: catSummaryTag.text
                        font: catSummaryTag.font
                        color: Theme.getShadowColor(catSummaryTag.color)
                    }
                    Text {
                        id: catSummaryTag
                        x: 0; y: 0
                        text: "— " + root.categories[root.activeCategory].tagline
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeCaption
                        color: Theme.textSecondary
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        // =========================================================
        // 4. MAIN SETTINGS CONTENT CARD
        // =========================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.space24
            Layout.rightMargin: Theme.space24
            Layout.bottomMargin: Theme.space16
            radius: Theme.radiusMd
            color: Theme.bgCard
            border.color: root.focusPane === 1 ? Theme.borderFocused : Theme.borderSubtle
            border.width: root.focusPane === 1 ? 2 : 1

            StackLayout {
                id: settingsStack
                anchors.fill: parent
                anchors.margins: Theme.space20
                currentIndex: root.activeCategory

                    // ---------------------------------------------------------
                    // 0: DISPLAY & SCALING
                    // ---------------------------------------------------------
                    ScrollView {
                        contentWidth: availableWidth
                        clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: Theme.space16

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 39 * Theme.scale
                            Layout.topMargin: 1 * Theme.scale

                            Item {
                                implicitWidth: dispTitleText.implicitWidth
                                implicitHeight: dispTitleText.implicitHeight
                                readonly property int off: Theme.getShadowOffset(dispTitleText.font.pixelSize)

                                Text {
                                    x: parent.off; y: parent.off
                                    text: dispTitleText.text
                                    font: dispTitleText.font
                                    color: Theme.getShadowColor(dispTitleText.color)
                                }
                                Text {
                                    id: dispTitleText
                                    x: 0; y: 0
                                    text: qsTr("Display & Interface Scaling")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSubheading
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Active resolution & scale status banner
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38 * Theme.scale
                            radius: Theme.radiusMd
                            color: Theme.bgSurface
                            border.color: Theme.borderSubtle
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space8
                                spacing: Theme.space8

                                Image {
                                    Layout.preferredWidth: 20 * Theme.scale
                                    Layout.preferredHeight: 20 * Theme.scale
                                    source: "qrc:/shulk/icons/spyglass.png"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                }

                                Text {
                                    text: qsTr("Screen: %1x%2 | Effective Scale: %3x (%4%) | Mode: %5")
                                          .arg(shulkTheme.screenWidth)
                                          .arg(shulkTheme.screenHeight)
                                          .arg(shulkTheme.scaleFactor.toFixed(2))
                                          .arg(Math.round(shulkTheme.scaleFactor * 100))
                                          .arg(shulkTheme.customScaleFactor <= 0.0 ? qsTr("Auto-Detected") : qsTr("Manual Override"))
                                    font.pixelSize: Theme.sizeSmall
                                    color: Theme.textGold
                                    font.bold: true
                                }
                            }
                        }

                        // Row 0: Background Panorama Dropdown & Random Roll
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Background Panorama")
                                font.pixelSize: Theme.sizeSmall
                                font.bold: true
                                color: Theme.mcEmerald
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("Theme: %1").arg(shulkTheme.panoramaSetting === "random" ? qsTr("Random (Every Launch)") : shulkTheme.panoramaTitle)
                                font.pixelSize: Theme.sizeSmall
                                color: Theme.textSecondary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space12

                            // Panorama Dropdown Button
                            Rectangle {
                                id: panoramaDropdownBtn
                                Layout.fillWidth: true
                                Layout.maximumWidth: 420 * Theme.scale
                                height: 38 * Theme.scale
                                radius: Theme.radiusSm
                                readonly property bool isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 0

                                color: isFocused ? Theme.accentPlayHover : (dropdownMouse.containsMouse ? "#3A3C3D" : "#2B2D2E")
                                border.color: isFocused ? Theme.borderFocused : "#62000000"
                                border.width: isFocused ? 2 : 1

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: panoramaDropdownBtn.isFocused ? 3 : 2
                                    height: 1
                                    color: panoramaDropdownBtn.isFocused ? "#4FFFFFFF" : "#28FFFFFF"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space12
                                    anchors.rightMargin: Theme.space12
                                    spacing: Theme.space8

                                    Image {
                                        Layout.preferredWidth: 20 * Theme.scale
                                        Layout.preferredHeight: 20 * Theme.scale
                                        source: "qrc:/shulk/icons/compass.png"
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: ddActiveTitle.implicitHeight
                                        readonly property int ddOffset: Theme.getShadowOffset(ddActiveTitle.font.pixelSize)

                                        Text {
                                            x: parent.ddOffset
                                            y: parent.ddOffset
                                            width: parent.width - parent.ddOffset
                                            text: shulkTheme.panoramaSetting === "random" ? qsTr("Random (Every Launch)") : shulkTheme.panoramaTitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: true
                                            color: Theme.getShadowColor(ddActiveTitle.color)
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            id: ddActiveTitle
                                            x: 0
                                            y: 0
                                            width: parent.width
                                            text: shulkTheme.panoramaSetting === "random" ? qsTr("Random (Every Launch)") : shulkTheme.panoramaTitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: true
                                            color: panoramaDropdownBtn.isFocused ? "#FFFFAA" : Theme.textPrimary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    ShulkBadge {
                                        visible: shulkTheme.consolePanoramasUnlocked && shulkTheme.activePanoramaId.indexOf("console_") === 0
                                        text: qsTr("Console")
                                        badgeColor: "#2A1838"
                                        textColor: "#E9D5FF"
                                    }

                                    Text {
                                        text: ">"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeSmall
                                        font.bold: true
                                        color: panoramaDropdownBtn.isFocused ? "#FFFFAA" : Theme.textSecondary
                                    }
                                }

                                MouseArea {
                                    id: dropdownMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.focusPane = 1
                                        root.itemRow = 0
                                        root.itemCol = 0
                                        root.triggerAction()
                                    }
                                }
                            }

                            // Choose Random Button
                            ShulkButton {
                                text: qsTr("Choose Random")
                                variant: "play"
                                implicitHeight: 38 * Theme.scale
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 1
                                onClicked: {
                                    root.itemRow = 0
                                    root.itemCol = 1
                                    root.triggerAction()
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space4
                            Layout.bottomMargin: Theme.space4
                        }

                        // Row 1: Panorama Ambient Blur
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Background Panorama Blur")
                                font.pixelSize: Theme.sizeSmall
                                font.bold: true
                                color: Theme.mcEmerald
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("Current: %1 px").arg(shulkTheme.panoramaBlurRadius)
                                font.pixelSize: Theme.sizeSmall
                                color: Theme.textSecondary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space8

                            Repeater {
                                model: root.blurPresets
                                delegate: ShulkButton {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    isPrimary: (shulkTheme.panoramaBlurRadius === modelData.val)
                                    isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === index
                                    onClicked: {
                                        root.itemRow = 1
                                        root.itemCol = index
                                        root.triggerAction()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space4
                            Layout.bottomMargin: Theme.space4
                        }

                        // Row 2: Scale Factor Presets
                        Text {
                            text: qsTr("Interface Scaling Preset")
                            font.pixelSize: Theme.sizeSmall
                            font.bold: true
                            color: Theme.mcEmerald
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space8

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Auto (Device)")
                                isPrimary: shulkTheme.customScaleFactor <= 0.0
                                isFocused: root.focusPane === 1 && root.itemRow === 2 && root.itemCol === 0
                                onClicked: { root.itemRow = 2; root.itemCol = 0; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "1.0x (Deck)"
                                isPrimary: Math.abs(shulkTheme.customScaleFactor - 1.0) < 0.01
                                isFocused: root.focusPane === 1 && root.itemRow === 2 && root.itemCol === 1
                                onClicked: { root.itemRow = 2; root.itemCol = 1; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "1.35x (Ally)"
                                isPrimary: Math.abs(shulkTheme.customScaleFactor - 1.35) < 0.01
                                isFocused: root.focusPane === 1 && root.itemRow === 2 && root.itemCol === 2
                                onClicked: { root.itemRow = 2; root.itemCol = 2; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "1.70x (Go)"
                                isPrimary: Math.abs(shulkTheme.customScaleFactor - 1.70) < 0.01
                                isFocused: root.focusPane === 1 && root.itemRow === 2 && root.itemCol === 3
                                onClicked: { root.itemRow = 2; root.itemCol = 3; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "2.0x (TV)"
                                isPrimary: Math.abs(shulkTheme.customScaleFactor - 2.0) < 0.01
                                isFocused: root.focusPane === 1 && root.itemRow === 2 && root.itemCol === 4
                                onClicked: { root.itemRow = 2; root.itemCol = 4; root.triggerAction(); }
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // 1: CONTROLLER (DISABLED - COMING SOON)
                // ---------------------------------------------------------
                ScrollView {
                    contentWidth: availableWidth
                    clip: true
                    opacity: 0.4
                    enabled: false

                    ColumnLayout {
                        width: parent.width
                        spacing: Theme.space20

                        Rectangle {
                            Layout.fillWidth: true
                            height: 48 * Theme.scale
                            radius: Theme.radiusSm
                            color: "#281E10"
                            border.color: "#8A6D3B"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space8

                                Text {
                                    text: qsTr("Controller Configuration - Coming Soon")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    font.bold: true
                                    color: "#FFAA00"
                                }
                            }
                        }

                        Text {
                            text: qsTr("Controller Glyphs & Layout")
                            font.pixelSize: Theme.sizeSubheading
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: qsTr("Select button prompt style matching your handheld console or gamepad.")
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textSecondary
                        }

                        // Row 0: Controller Glyphs
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space12

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "Xbox (A / B / X / Y)"
                                isPrimary: shulkTheme.controllerType === "xbox"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 0
                                onClicked: { root.itemRow = 0; root.itemCol = 0; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "Steam Deck"
                                isPrimary: shulkTheme.controllerType === "deck"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 1
                                onClicked: { root.itemRow = 0; root.itemCol = 1; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("PlayStation (Cross / Circle / Square / Triangle)")
                                isPrimary: shulkTheme.controllerType === "playstation"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 2
                                onClicked: { root.itemRow = 0; root.itemCol = 2; root.triggerAction(); }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space8
                            Layout.bottomMargin: Theme.space8
                        }

                        Text {
                            text: qsTr("Handheld & Controller Tools")
                            font.pixelSize: Theme.sizeSmall
                            font.bold: true
                            color: Theme.mcEmerald
                        }

                        // Row 1: Controller Actions
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space12

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Test Controller Haptics / Fanfare")
                                variant: "play"
                                isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === 0
                                onClicked: { root.itemRow = 1; root.itemCol = 0; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Open Virtual Keyboard")
                                variant: "secondary"
                                isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === 1
                                onClicked: { root.itemRow = 1; root.itemCol = 1; root.triggerAction(); }
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // 2: AUDIO & SOUNDS
                // ---------------------------------------------------------
                ScrollView {
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: Theme.space16

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 39 * Theme.scale
                            Layout.topMargin: 1 * Theme.scale

                            Item {
                                implicitWidth: audioTitleText.implicitWidth
                                implicitHeight: audioTitleText.implicitHeight
                                readonly property int off: Theme.getShadowOffset(audioTitleText.font.pixelSize)

                                Text {
                                    x: parent.off; y: parent.off
                                    text: audioTitleText.text
                                    font: audioTitleText.font
                                    color: Theme.getShadowColor(audioTitleText.color)
                                }
                                Text {
                                    id: audioTitleText
                                    x: 0; y: 0
                                    text: qsTr("UI Sound Effects & Volume")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSubheading
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Item {
                            implicitWidth: audioDescText.implicitWidth
                            implicitHeight: audioDescText.implicitHeight
                            readonly property int off: Theme.getShadowOffset(audioDescText.font.pixelSize)

                            Text {
                                x: parent.off; y: parent.off
                                text: audioDescText.text
                                font: audioDescText.font
                                color: Theme.getShadowColor(audioDescText.color)
                            }
                            Text {
                                id: audioDescText
                                x: 0; y: 0
                                text: qsTr("Authentic Minecraft interface audio for controller navigation, card clicks, and launches.")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeBody
                                color: Theme.textSecondary
                            }
                        }

                        // Row 0: Sound Enable / Disable
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space12

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Sound Effects Enabled")
                                isPrimary: shulkSound.soundEnabled && shulkSound.volume > 0
                                variant: isPrimary ? "play" : "secondary"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 0
                                onClicked: { root.itemRow = 0; root.itemCol = 0; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Mute All Sounds")
                                isPrimary: !shulkSound.soundEnabled || shulkSound.volume === 0
                                variant: isPrimary ? "danger" : "secondary"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 1
                                onClicked: { root.itemRow = 0; root.itemCol = 1; root.triggerAction(); }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space4
                            Layout.bottomMargin: Theme.space4
                        }

                        // Row 1: Volume Levels
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Volume Level")
                                font.pixelSize: Theme.sizeSmall
                                font.bold: true
                                color: Theme.mcEmerald
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("Current: %1%").arg(shulkSound.soundEnabled ? shulkSound.volume : 0)
                                font.pixelSize: Theme.sizeSmall
                                color: Theme.textGold
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space8

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("0% (Mute)")
                                isPrimary: (!shulkSound.soundEnabled || shulkSound.volume === 0)
                                isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === 0
                                onClicked: { root.itemRow = 1; root.itemCol = 0; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "25%"
                                isPrimary: (shulkSound.soundEnabled && shulkSound.volume === 25)
                                isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === 1
                                onClicked: { root.itemRow = 1; root.itemCol = 1; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "50%"
                                isPrimary: (shulkSound.soundEnabled && shulkSound.volume === 50)
                                isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === 2
                                onClicked: { root.itemRow = 1; root.itemCol = 2; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "75%"
                                isPrimary: (shulkSound.soundEnabled && shulkSound.volume === 75)
                                isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === 3
                                onClicked: { root.itemRow = 1; root.itemCol = 3; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "100%"
                                isPrimary: (shulkSound.soundEnabled && shulkSound.volume === 100)
                                isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === 4
                                onClicked: { root.itemRow = 1; root.itemCol = 4; root.triggerAction(); }
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // 3: JAVA & MEMORY
                // ---------------------------------------------------------
                ScrollView {
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: Theme.space16

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 39 * Theme.scale
                            Layout.topMargin: 1 * Theme.scale

                            Item {
                                implicitWidth: javaTitleText.implicitWidth
                                implicitHeight: javaTitleText.implicitHeight
                                readonly property int off: Theme.getShadowOffset(javaTitleText.font.pixelSize)

                                Text {
                                    x: parent.off; y: parent.off
                                    text: javaTitleText.text
                                    font: javaTitleText.font
                                    color: Theme.getShadowColor(javaTitleText.color)
                                }
                                Text {
                                    id: javaTitleText
                                    x: 0; y: 0
                                    text: qsTr("Java Runtime & Memory (RAM)")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSubheading
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // RAM Info Banner
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38 * Theme.scale
                            radius: Theme.radiusMd
                            color: Theme.bgSurface
                            border.color: Theme.borderSubtle
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space8
                                spacing: Theme.space8

                                Image {
                                    Layout.preferredWidth: 20 * Theme.scale
                                    Layout.preferredHeight: 20 * Theme.scale
                                    source: "qrc:/shulk/icons/redstone.png"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                }

                                Text {
                                    text: qsTr("System RAM: %1 MB | Global Max Allocation: %2 MB (%3 GB)")
                                          .arg(shulkLauncher.systemRamMb)
                                          .arg(shulkLauncher.maxMemory)
                                          .arg((shulkLauncher.maxMemory / 1024).toFixed(1))
                                    font.pixelSize: Theme.sizeSmall
                                    color: Theme.textGold
                                    font.bold: true
                                }
                            }
                        }

                        // Row 0: Maximum RAM Allocation
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Maximum Memory Allocation (Max Heap)")
                                font.pixelSize: Theme.sizeSmall
                                font.bold: true
                                color: Theme.mcEmerald
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("Recommended for modpacks: 4 GB - 6 GB")
                                font.pixelSize: Theme.sizeSmall
                                color: Theme.textSecondary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space8

                            Repeater {
                                model: root.ramPresets
                                delegate: ShulkButton {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    isPrimary: (shulkLauncher.maxMemory === modelData.val)
                                    isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === index
                                    onClicked: {
                                        root.itemRow = 0
                                        root.itemCol = index
                                        root.triggerAction()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space4
                            Layout.bottomMargin: Theme.space4
                        }

                        // Row 1: Minimum RAM Allocation
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Initial Memory Allocation (Min Heap)")
                                font.pixelSize: Theme.sizeSmall
                                font.bold: true
                                color: Theme.mcEmerald
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("Current: %1 MB").arg(shulkLauncher.minMemory)
                                font.pixelSize: Theme.sizeSmall
                                color: Theme.textSecondary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space12

                            Repeater {
                                model: root.minRamPresets
                                delegate: ShulkButton {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    isPrimary: (shulkLauncher.minMemory === modelData.val)
                                    isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === index
                                    onClicked: {
                                        root.itemRow = 1
                                        root.itemCol = index
                                        root.triggerAction()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space4
                            Layout.bottomMargin: Theme.space4
                        }

                        // Row 2: Advanced Java Settings Button
                        Text {
                            text: qsTr("Advanced Java Runtimes & Arguments")
                            font.pixelSize: Theme.sizeSmall
                            font.bold: true
                            color: Theme.mcEmerald
                        }

                        ShulkButton {
                            Layout.fillWidth: true
                            text: qsTr("Open Prism Launcher Advanced Java Configuration")
                            variant: "play"
                            isFocused: root.focusPane === 1 && root.itemRow === 2 && root.itemCol === 0
                            onClicked: {
                                root.itemRow = 2
                                root.itemCol = 0
                                root.triggerAction()
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // 4: ACCOUNTS & SKIN VIEWER
                // ---------------------------------------------------------
                Item {
                    clip: true

                    // 4A: Accounts List View
                    ColumnLayout {
                        id: accountsListPane
                        anchors.fill: parent
                        spacing: Theme.space16
                        visible: !root.inAccountSkinViewer

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 39 * Theme.scale
                            Layout.topMargin: 1 * Theme.scale

                            Item {
                                implicitWidth: accountsTitleText.implicitWidth
                                implicitHeight: accountsTitleText.implicitHeight
                                readonly property int off: Theme.getShadowOffset(accountsTitleText.font.pixelSize)

                                Text {
                                    x: parent.off; y: parent.off
                                    text: accountsTitleText.text
                                    font: accountsTitleText.font
                                    color: Theme.getShadowColor(accountsTitleText.color)
                                }
                                Text {
                                    id: accountsTitleText
                                    x: 0; y: 0
                                    text: qsTr("Minecraft Accounts")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeSubheading
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Row 0: Add Account Button
                            ShulkButton {
                                text: qsTr("Add Microsoft Account")
                                variant: "play"
                                isFocused: root.focusPane === 1 && !root.inAccountSkinViewer && root.itemRow === 0 && root.itemCol === 0
                                onClicked: {
                                    root.itemRow = 0
                                    root.itemCol = 0
                                    root.triggerAction()
                                }
                            }
                        }

                        ListView {
                            id: accountsList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Theme.space8
                            model: shulkAccounts
                            clip: true

                            delegate: Rectangle {
                                width: ListView.view ? ListView.view.width : 0
                                height: 60 * Theme.scale
                                radius: Theme.radiusMedium
                                color: model.isActive ? "#1A2E28" : Theme.bgCard
                                border.color: model.isActive ? Theme.mcEmerald : Theme.borderSubtle
                                border.width: model.isActive ? 2 : 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space12
                                    spacing: Theme.space12

                                    Image {
                                        source: "https://mc-heads.net/avatar/" + model.username + "/64"
                                        Layout.preferredWidth: 28 * Theme.scale
                                        Layout.preferredHeight: 28 * Theme.scale
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                source = "qrc:/shulk/icons/steve_head.png"
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 2

                                        RowLayout {
                                            spacing: Theme.space8
                                            Item {
                                                implicitWidth: accountUserText.implicitWidth
                                                implicitHeight: accountUserText.implicitHeight

                                                Text {
                                                    x: Theme.fontShadowOffset
                                                    y: Theme.fontShadowOffset
                                                    text: model.username
                                                    font.pixelSize: Theme.sizeBody
                                                    font.bold: true
                                                    color: Theme.fontShadowDark
                                                }

                                                Text {
                                                    id: accountUserText
                                                    x: 0
                                                    y: 0
                                                    text: model.username
                                                    font.pixelSize: Theme.sizeBody
                                                    font.bold: true
                                                    color: Theme.textPrimary
                                                }
                                            }

                                            ShulkBadge {
                                                visible: model.isActive
                                                text: qsTr("Active Account")
                                                isAccent: true
                                            }
                                        }

                                        Item {
                                            implicitWidth: accountDescText.implicitWidth
                                            implicitHeight: accountDescText.implicitHeight

                                            Text {
                                                x: Theme.fontShadowOffset
                                                y: Theme.fontShadowOffset
                                                text: model.type + " | " + (model.ownsGame ? qsTr("Minecraft Owned") : qsTr("Offline"))
                                                font.pixelSize: Theme.sizeCaption
                                                color: Theme.fontShadowDark
                                            }

                                            Text {
                                                id: accountDescText
                                                x: 0
                                                y: 0
                                                text: model.type + " | " + (model.ownsGame ? qsTr("Minecraft Owned") : qsTr("Offline"))
                                                font.pixelSize: Theme.sizeCaption
                                                color: Theme.textSecondary
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    ShulkButton {
                                        text: qsTr("View Skin")
                                        variant: "secondary"
                                        implicitHeight: 34 * Theme.scale
                                        Layout.alignment: Qt.AlignRight
                                        isFocused: root.focusPane === 1 && !root.inAccountSkinViewer && root.itemRow === (index + 1) && root.itemCol === 0
                                        onClicked: {
                                            root.itemRow = index + 1
                                            root.itemCol = 0
                                            root.triggerAction()
                                        }
                                    }

                                    ShulkButton {
                                        visible: !model.isActive
                                        text: qsTr("Set Active")
                                        variant: "play"
                                        implicitHeight: 34 * Theme.scale
                                        Layout.alignment: Qt.AlignRight
                                        isFocused: root.focusPane === 1 && !root.inAccountSkinViewer && root.itemRow === (index + 1) && root.itemCol === 1
                                        onClicked: {
                                            root.itemRow = index + 1
                                            root.itemCol = 1
                                            root.triggerAction()
                                        }
                                    }

                                    ShulkButton {
                                        text: qsTr("Remove")
                                        variant: "danger"
                                        implicitHeight: 34 * Theme.scale
                                        Layout.alignment: Qt.AlignRight
                                        isFocused: root.focusPane === 1 && !root.inAccountSkinViewer && root.itemRow === (index + 1) && (model.isActive ? (root.itemCol === 1) : (root.itemCol === 2))
                                        onClicked: {
                                            root.itemRow = index + 1
                                            root.itemCol = model.isActive ? 1 : 2
                                            root.triggerAction()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 4B: Skin Viewer Sub-View
                    Item {
                        id: skinViewerTab
                        anchors.fill: parent
                        visible: root.inAccountSkinViewer
                        clip: true

                        readonly property var currentAccount: (shulkAccounts.count > 0 && root.skinAccountIndex >= 0 && root.skinAccountIndex < shulkAccounts.count)
                                                              ? shulkAccounts.getSkinDetails(root.skinAccountIndex)
                                                              : null
                        readonly property string accountUsername: currentAccount ? currentAccount.username : ""
                        readonly property string accountUuid: currentAccount ? currentAccount.uuid : ""
                        readonly property string skinVariant: currentAccount ? currentAccount.skinVariant : "classic"
                        readonly property bool isCurrentActive: currentAccount ? currentAccount.isActive : false

                        readonly property var viewModes: [
                            { label: qsTr("3D Model"), mode: 0 },
                            { label: qsTr("Front Body"), mode: 1 },
                            { label: qsTr("Head Avatar"), mode: 2 },
                            { label: qsTr("Skin Texture"), mode: 3 }
                        ]

                        function getPreviewUrl() {
                            if (!currentAccount || !accountUsername) {
                                if (root.skinViewMode === 0) return "https://mc-heads.net/player/MHF_Steve/512"
                                if (root.skinViewMode === 1) return "https://mc-heads.net/body/MHF_Steve/512"
                                if (root.skinViewMode === 2) return "https://mc-heads.net/avatar/MHF_Steve/256"
                                return "https://mc-heads.net/skin/MHF_Steve"
                            }
                            var base = "https://mc-heads.net/"
                            var buster = root.skinCacheBuster > 0 ? ("?" + root.skinCacheBuster) : ""
                            if (root.skinViewMode === 0) return base + "player/" + accountUsername + "/512" + buster
                            if (root.skinViewMode === 1) return base + "body/" + accountUsername + "/512" + buster
                            if (root.skinViewMode === 2) return base + "avatar/" + accountUsername + "/256" + buster
                            return base + "skin/" + accountUsername + buster
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.space12

                            // Sub-View Header Navigation: Back button + title
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space12

                                ShulkButton {
                                    text: qsTr("◀ Back to Accounts")
                                    variant: "secondary"
                                    implicitHeight: 34 * Theme.scale
                                    isFocused: root.focusPane === 1 && root.inAccountSkinViewer && root.itemRow === 0 && root.itemCol === 0
                                    onClicked: {
                                        root.itemRow = 0
                                        root.itemCol = 0
                                        root.triggerAction()
                                    }
                                }

                                Item {
                                    implicitWidth: breadcrumbText.implicitWidth
                                    implicitHeight: breadcrumbText.implicitHeight

                                    Text {
                                        x: Theme.fontShadowOffset
                                        y: Theme.fontShadowOffset
                                        text: skinViewerTab.accountUsername ? (skinViewerTab.accountUsername + " — " + qsTr("Skin Preview")) : qsTr("Skin Preview")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeBody
                                        font.bold: true
                                        color: Theme.fontShadowDark
                                    }

                                    Text {
                                        id: breadcrumbText
                                        x: 0
                                        y: 0
                                        text: skinViewerTab.accountUsername ? (skinViewerTab.accountUsername + " — " + qsTr("Skin Preview")) : qsTr("Skin Preview")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeBody
                                        font.bold: true
                                        color: Theme.mcGold
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // ACTIVE SKIN VIEWER
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Theme.space24

                                // Character Showcase Stage (Left Pane)
                                Rectangle {
                                    Layout.preferredWidth: 320 * Theme.scale
                                    Layout.fillHeight: true
                                    radius: Theme.radiusMd
                                    color: Theme.bgDeep
                                    border.color: Theme.borderSubtle
                                    border.width: 1
                                    clip: true

                                    // Pedestal gradient
                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "#00000000" }
                                            GradientStop { position: 0.7; color: "#14000000" }
                                            GradientStop { position: 1.0; color: "#40000000" }
                                        }
                                    }

                                    // Pedestal shadow
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 24 * Theme.scale
                                        width: 180 * Theme.scale
                                        height: 26 * Theme.scale
                                        radius: 13 * Theme.scale
                                        color: "#50000000"
                                        visible: root.skinViewMode <= 1
                                    }

                                    // Skin / Character Image
                                    Image {
                                        id: skinImg
                                        anchors.fill: parent
                                        anchors.margins: root.skinViewMode === 3 ? Theme.space20 : Theme.space12
                                        source: skinViewerTab.getPreviewUrl()
                                        fillMode: Image.PreserveAspectFit
                                        smooth: root.skinViewMode !== 3
                                        asynchronous: true

                                        BusyIndicator {
                                            anchors.centerIn: parent
                                            running: skinImg.status === Image.Loading
                                            visible: running
                                        }

                                        Item {
                                            anchors.centerIn: parent
                                            visible: skinImg.status === Image.Error
                                            width: errorLabelText.implicitWidth
                                            height: errorLabelText.implicitHeight

                                            Text {
                                                x: Theme.fontShadowOffset
                                                y: Theme.fontShadowOffset
                                                text: qsTr("Failed to load skin render")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeSmall
                                                color: Theme.fontShadowDark
                                            }

                                            Text {
                                                id: errorLabelText
                                                x: 0
                                                y: 0
                                                text: qsTr("Failed to load skin render")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeSmall
                                                color: Theme.textMuted
                                            }
                                        }
                                    }

                                    // View mode tag
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: Theme.space12
                                        height: 24 * Theme.scale
                                        width: modeTagText.implicitWidth + Theme.space16
                                        radius: Theme.radiusSm
                                        color: "#B00C0D0E"
                                        border.color: "#40FFFFFF"
                                        border.width: 1

                                        Item {
                                            anchors.centerIn: parent
                                            width: modeTagText.implicitWidth
                                            height: modeTagText.implicitHeight

                                            Text {
                                                x: Theme.fontShadowOffset
                                                y: Theme.fontShadowOffset
                                                text: skinViewerTab.viewModes[root.skinViewMode].label.toUpperCase()
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeSmall
                                                font.bold: true
                                                color: Theme.fontShadowDark
                                            }

                                            Text {
                                                id: modeTagText
                                                x: 0
                                                y: 0
                                                text: skinViewerTab.viewModes[root.skinViewMode].label.toUpperCase()
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.sizeSmall
                                                font.bold: true
                                                color: Theme.mcDiamond
                                            }
                                        }
                                    }
                                }

                                // Character Metadata & Controls (Right Pane)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Theme.space14

                                    // Username Header
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space10

                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: skinUsernameText.implicitHeight + Theme.fontShadowOffset

                                            Text {
                                                x: Theme.fontShadowOffset
                                                y: Theme.fontShadowOffset
                                                width: skinUsernameText.width
                                                height: skinUsernameText.height
                                                text: skinViewerTab.accountUsername
                                                font.family: Theme.fontDisplay
                                                font.pixelSize: Theme.sizeTitle
                                                font.bold: true
                                                color: Theme.fontShadowDark
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                id: skinUsernameText
                                                anchors.fill: parent
                                                text: skinViewerTab.accountUsername
                                                font.family: Theme.fontDisplay
                                                font.pixelSize: Theme.sizeTitle
                                                font.bold: true
                                                color: Theme.textPrimary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        ShulkBadge {
                                            visible: skinViewerTab.isCurrentActive
                                            text: qsTr("Active")
                                            isAccent: true
                                        }
                                    }

                                    // Specification Badges
                                    RowLayout {
                                        spacing: Theme.space8

                                        ShulkBadge {
                                            text: skinViewerTab.skinVariant === "slim" ? qsTr("Slim (3px Arms / Alex)") : qsTr("Classic (4px Arms / Steve)")
                                            isAccent: false
                                        }

                                        ShulkBadge {
                                            text: skinViewerTab.currentAccount ? (skinViewerTab.currentAccount.type.toUpperCase() + " ACCOUNT") : ""
                                            isAccent: false
                                        }
                                    }

                                    // UUID Display
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38 * Theme.scale
                                        radius: Theme.radiusSm
                                        color: Theme.bgDeep
                                        border.color: Theme.borderSubtle
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.space12
                                            anchors.rightMargin: Theme.space12
                                            spacing: Theme.space8

                                            Item {
                                                implicitWidth: uuidLabelText.implicitWidth
                                                implicitHeight: uuidLabelText.implicitHeight

                                                Text {
                                                    x: Theme.fontShadowOffset
                                                    y: Theme.fontShadowOffset
                                                    text: qsTr("UUID:")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.sizeSmall
                                                    color: Theme.fontShadowDark
                                                }

                                                Text {
                                                    id: uuidLabelText
                                                    x: 0
                                                    y: 0
                                                    text: qsTr("UUID:")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.sizeSmall
                                                    color: Theme.textMuted
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: skinViewerTab.accountUuid
                                                font.family: Theme.fontBody
                                                font.pixelSize: Theme.sizeCaption
                                                color: Theme.textSecondary
                                                elide: Text.ElideMiddle
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: Theme.borderSubtle
                                    }

                                    // View Mode Selector
                                    Item {
                                        implicitWidth: camModeText.implicitWidth
                                        implicitHeight: camModeText.implicitHeight

                                        Text {
                                            x: Theme.fontShadowOffset
                                            y: Theme.fontShadowOffset
                                            text: qsTr("Camera & Render Mode")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            font.bold: true
                                            color: Theme.fontShadowDark
                                        }

                                        Text {
                                            id: camModeText
                                            x: 0
                                            y: 0
                                            text: qsTr("Camera & Render Mode")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            font.bold: true
                                            color: Theme.mcEmerald
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space8

                                        Repeater {
                                            model: skinViewerTab.viewModes
                                            delegate: ShulkButton {
                                                Layout.fillWidth: true
                                                text: modelData.label
                                                variant: root.skinViewMode === modelData.mode ? "play" : "secondary"
                                                isFocused: root.focusPane === 1 && root.inAccountSkinViewer && root.itemRow === 1 && root.itemCol === index
                                                implicitHeight: 36 * Theme.scale
                                                onClicked: {
                                                    root.itemRow = 1
                                                    root.itemCol = index
                                                    root.triggerAction()
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: Theme.borderSubtle
                                    }

                                    // Account Switcher (if multiple accounts exist)
                                    Item {
                                        visible: shulkAccounts.count > 1
                                        implicitWidth: switchAccText.implicitWidth
                                        implicitHeight: switchAccText.implicitHeight

                                        Text {
                                            x: Theme.fontShadowOffset
                                            y: Theme.fontShadowOffset
                                            text: qsTr("Switch Account (%1 of %2)").arg(root.skinAccountIndex + 1).arg(shulkAccounts.count)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            font.bold: true
                                            color: Theme.fontShadowDark
                                        }

                                        Text {
                                            id: switchAccText
                                            x: 0
                                            y: 0
                                            text: qsTr("Switch Account (%1 of %2)").arg(root.skinAccountIndex + 1).arg(shulkAccounts.count)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            font.bold: true
                                            color: Theme.mcGold
                                        }
                                    }

                                    RowLayout {
                                        visible: shulkAccounts.count > 1
                                        Layout.fillWidth: true
                                        spacing: Theme.space8

                                        ShulkButton {
                                            Layout.fillWidth: true
                                            text: qsTr("◀ Previous Account")
                                            variant: "secondary"
                                            enabled: root.skinAccountIndex > 0
                                            isFocused: root.focusPane === 1 && root.inAccountSkinViewer && root.itemRow === 2 && root.itemCol === 0
                                            implicitHeight: 36 * Theme.scale
                                            onClicked: {
                                                root.itemRow = 2
                                                root.itemCol = 0
                                                root.triggerAction()
                                            }
                                        }

                                        ShulkButton {
                                            Layout.fillWidth: true
                                            text: qsTr("Next Account ▶")
                                            variant: "secondary"
                                            enabled: root.skinAccountIndex < shulkAccounts.count - 1
                                            isFocused: root.focusPane === 1 && root.inAccountSkinViewer && root.itemRow === 2 && root.itemCol === 1
                                            implicitHeight: 36 * Theme.scale
                                            onClicked: {
                                                root.itemRow = 2
                                                root.itemCol = 1
                                                root.triggerAction()
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    // Bottom Actions
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space8

                                        ShulkButton {
                                            visible: !skinViewerTab.isCurrentActive
                                            Layout.fillWidth: true
                                            text: qsTr("Set as Active Account")
                                            variant: "play"
                                            isFocused: root.focusPane === 1 && root.inAccountSkinViewer && (shulkAccounts.count > 1 ? (root.itemRow === 3 && root.itemCol === 0) : (root.itemRow === 2 && root.itemCol === 0))
                                            implicitHeight: 38 * Theme.scale
                                            onClicked: {
                                                root.itemRow = shulkAccounts.count > 1 ? 3 : 2
                                                root.itemCol = 0
                                                root.triggerAction()
                                            }
                                        }

                                        ShulkButton {
                                            Layout.fillWidth: true
                                            text: qsTr("Refresh Skin")
                                            variant: "secondary"
                                            isFocused: root.focusPane === 1 && root.inAccountSkinViewer && (shulkAccounts.count > 1 ? (root.itemRow === 3 && (skinViewerTab.isCurrentActive ? (root.itemCol === 0) : (root.itemCol === 1))) : (root.itemRow === 2 && (skinViewerTab.isCurrentActive ? (root.itemCol === 0) : (root.itemCol === 1))))
                                            implicitHeight: 38 * Theme.scale
                                            onClicked: {
                                                root.itemRow = shulkAccounts.count > 1 ? 3 : 2
                                                root.itemCol = skinViewerTab.isCurrentActive ? 0 : 1
                                                root.triggerAction()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // 5: ABOUT SHULK
                // ---------------------------------------------------------
                ScrollView {
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: Theme.space16

                        RowLayout {
                            spacing: Theme.space12

                            Image {
                                source: "qrc:/shulk/icons/shulk.png"
                                Layout.preferredWidth: 36 * Theme.scale
                                Layout.preferredHeight: 36 * Theme.scale
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }

                            Item {
                                implicitWidth: aboutTitleText.implicitWidth
                                implicitHeight: aboutTitleText.implicitHeight

                                Text {
                                    x: Theme.fontShadowOffset
                                    y: Theme.fontShadowOffset
                                    text: "Shulk"
                                    font.pixelSize: 32 * Theme.scale
                                    font.bold: true
                                    color: Theme.fontShadowDark
                                }

                                Text {
                                    id: aboutTitleText
                                    x: 0
                                    y: 0
                                    text: "Shulk"
                                    font.pixelSize: 32 * Theme.scale
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }
                        }

                        Item {
                            implicitWidth: aboutSubText.implicitWidth
                            implicitHeight: aboutSubText.implicitHeight

                            Text {
                                x: Theme.fontShadowOffset
                                y: Theme.fontShadowOffset
                                text: qsTr("Handheld Minecraft Java Edition Launcher - Version %1").arg(shulkLauncher.appVersion)
                                font.pixelSize: Theme.sizeBody
                                color: Theme.fontShadowDark
                            }

                            Text {
                                id: aboutSubText
                                x: 0
                                y: 0
                                text: qsTr("Handheld Minecraft Java Edition Launcher - Version %1").arg(shulkLauncher.appVersion)
                                font.pixelSize: Theme.sizeBody
                                color: Theme.accentPrimary
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: aboutDescText.implicitHeight + Theme.fontShadowOffset

                            Text {
                                x: Theme.fontShadowOffset
                                y: Theme.fontShadowOffset
                                width: aboutDescText.width
                                height: aboutDescText.height
                                text: aboutDescText.text
                                font.pixelSize: Theme.sizeBody
                                color: Theme.fontShadowDark
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                id: aboutDescText
                                anchors.fill: parent
                                text: qsTr("Shulk is a modern, handheld-first Minecraft launcher built for Steam Deck, ROG Ally, Lenovo Legion Go, and controller-driven living room PCs.")
                                font.pixelSize: Theme.sizeBody
                                color: Theme.textSecondary
                                wrapMode: Text.WordWrap
                            }
                        }

                        // -----------------------------------------------------
                        // Software Updates Section
                        // -----------------------------------------------------
                        Item {
                            implicitWidth: updateHeaderShulkText.implicitWidth
                            implicitHeight: updateHeaderShulkText.implicitHeight

                            Text {
                                x: Theme.fontShadowOffset
                                y: Theme.fontShadowOffset
                                text: qsTr("Software Updates")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeHeader
                                font.bold: true
                                color: Theme.fontShadowDark
                            }

                            Text {
                                id: updateHeaderShulkText
                                x: 0
                                y: 0
                                text: qsTr("Software Updates")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeHeader
                                font.bold: true
                                color: Theme.mcDiamond
                            }
                        }

                        // Channel Switcher & Check Button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space10

                            ShulkButton {
                                Layout.preferredWidth: 160 * Theme.scale
                                text: qsTr("Channel: Stable")
                                variant: shulkLauncher.updateChannel === "stable" ? "play" : "secondary"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 0
                                implicitHeight: 38 * Theme.scale
                                onClicked: { root.itemRow = 0; root.itemCol = 0; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.preferredWidth: 175 * Theme.scale
                                text: qsTr("Channel: Dev (Private)")
                                variant: shulkLauncher.updateChannel === "development" ? "play" : "secondary"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 1
                                implicitHeight: 38 * Theme.scale
                                onClicked: { root.itemRow = 0; root.itemCol = 1; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: shulkLauncher.isCheckingForUpdates ? qsTr("Checking...") : qsTr("Check for Updates")
                                variant: "primary"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 2
                                enabled: !shulkLauncher.isCheckingForUpdates
                                implicitHeight: 38 * Theme.scale
                                onClicked: { root.itemRow = 0; root.itemCol = 2; root.triggerAction(); }
                            }
                        }

                        // Status / Notification Box
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.max(42 * Theme.scale, updateStatusLayout.implicitHeight + Theme.space12)
                            radius: Theme.radiusSm
                            color: shulkLauncher.updateAvailable ? "#1A2E1A" : Theme.bgDeep
                            border.color: shulkLauncher.updateAvailable ? Theme.mcEmerald : Theme.borderSubtle
                            border.width: 1

                            RowLayout {
                                id: updateStatusLayout
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space14
                                anchors.rightMargin: Theme.space14
                                spacing: Theme.space10

                                Text {
                                    text: shulkLauncher.updateAvailable ? "★" : (shulkLauncher.isCheckingForUpdates ? "⏳" : "●")
                                    font.pixelSize: Theme.sizeBody
                                    color: shulkLauncher.updateAvailable ? Theme.mcEmerald : (shulkLauncher.isCheckingForUpdates ? Theme.mcGold : Theme.mcDiamond)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: shulkLauncher.updateStatusMessage ? shulkLauncher.updateStatusMessage : qsTr("Ready to check for updates.")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    color: shulkLauncher.updateAvailable ? Theme.textPrimary : Theme.textSecondary
                                    elide: Text.ElideRight
                                }

                                ShulkButton {
                                    visible: shulkLauncher.updateAvailable
                                    text: qsTr("Download Update")
                                    variant: "play"
                                    isFocused: root.focusPane === 1 && root.itemRow === 1 && root.itemCol === 0
                                    implicitHeight: 32 * Theme.scale
                                    onClicked: { root.itemRow = 1; root.itemCol = 0; root.triggerAction(); }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space4
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space12

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Shulk GitHub Repository")
                                variant: "secondary"
                                isFocused: root.focusPane === 1 && (shulkLauncher.updateAvailable ? (root.itemRow === 2 && root.itemCol === 0) : (root.itemRow === 1 && root.itemCol === 0))
                                onClicked: { root.itemRow = shulkLauncher.updateAvailable ? 2 : 1; root.itemCol = 0; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Visit Prism Launcher Website")
                                variant: "secondary"
                                isFocused: root.focusPane === 1 && (shulkLauncher.updateAvailable ? (root.itemRow === 2 && root.itemCol === 1) : (root.itemRow === 1 && root.itemCol === 1))
                                onClicked: { root.itemRow = shulkLauncher.updateAvailable ? 2 : 1; root.itemCol = 1; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Open Global Prism Launcher Settings")
                                variant: "secondary"
                                isFocused: root.focusPane === 1 && (shulkLauncher.updateAvailable ? (root.itemRow === 2 && root.itemCol === 2) : (root.itemRow === 1 && root.itemCol === 2))
                                onClicked: { root.itemRow = shulkLauncher.updateAvailable ? 2 : 1; root.itemCol = 2; root.triggerAction(); }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space8
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: aboutLicenseText.implicitHeight + Theme.fontShadowOffset

                            Text {
                                x: Theme.fontShadowOffset
                                y: Theme.fontShadowOffset
                                width: aboutLicenseText.width
                                height: aboutLicenseText.height
                                text: aboutLicenseText.text
                                font.pixelSize: Theme.sizeCaption
                                color: Theme.fontShadowDark
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                id: aboutLicenseText
                                anchors.fill: parent
                                text: qsTr("Open Source License Attribution:\nShulk is licensed under GPL-3.0-only. Built using the mature C++ backend foundation developed by the Prism Launcher, PolyMC, and MultiMC contributors.\n\nCopyright (C) 2026 Shulk Contributors\nCopyright (C) 2022-2026 Prism Launcher Contributors\nCopyright (C) 2021-2022 PolyMC Contributors\nCopyright (C) 2012-2021 MultiMC Contributors")
                                font.pixelSize: Theme.sizeCaption
                                color: Theme.textMuted
                            }
                        }
                    }
                }
            }
        }
    }
    // =========================================================================
    // CONTROLLER & KEYBOARD NAVIGATION ENGINE
    // =========================================================================

    function getMaxRows() {
        if (root.activeCategory === 0) return 3 // Scale, Blur, Panorama Row
        if (root.activeCategory === 1) return 2 // Glyphs, Actions
        if (root.activeCategory === 2) return 2 // Enable/Disable, Volume Levels
        if (root.activeCategory === 3) return 3 // Max RAM, Min RAM, Advanced
        if (root.activeCategory === 4) {
            if (root.inAccountSkinViewer) {
                return shulkAccounts.count > 1 ? 4 : 3 // Back, View modes, (Account switcher), Actions
            }
            return 1 + shulkAccounts.count // Add button + account rows
        }
        if (root.activeCategory === 5) return shulkLauncher.updateAvailable ? 3 : 2 // 0: Channels & Check, 1: (Download / Links), 2: (Links)
        return 1
    }

    function getMaxCols(row) {
        if (root.activeCategory === 0) {
            if (row === 0) return 2 // Dropdown button, Choose Random
            if (row === 1) return 4 // Off, Subtle, Medium, Heavy
            if (row === 2) return 5 // Auto, 1.0, 1.35, 1.70, 2.0
        } else if (root.activeCategory === 1) {
            if (row === 0) return 3 // Xbox, Deck, PlayStation
            if (row === 1) return 2 // Haptics, Virtual Keyboard
        } else if (root.activeCategory === 2) {
            if (row === 0) return 2 // Enable, Mute
            if (row === 1) return 5 // 0%, 25%, 50%, 75%, 100%
        } else if (root.activeCategory === 3) {
            if (row === 0) return root.ramPresets.length // 6
            if (row === 1) return root.minRamPresets.length // 3
            if (row === 2) return 1 // Advanced Settings
        } else if (root.activeCategory === 4) {
            if (root.inAccountSkinViewer) {
                if (row === 0) return 1 // [◀ Back to Accounts]
                if (row === 1) return 4 // 3D Model, Front, Head, Texture
                if (shulkAccounts.count > 1) {
                    if (row === 2) return 2 // Prev, Next
                    if (row === 3) {
                        var curAcc = shulkAccounts.get(root.skinAccountIndex)
                        return (curAcc && curAcc.isActive) ? 1 : 2
                    }
                } else {
                    if (row === 2) {
                        var curAcc1 = shulkAccounts.get(root.skinAccountIndex)
                        return (curAcc1 && curAcc1.isActive) ? 1 : 2
                    }
                }
                return 1
            }
            if (row === 0) return 1 // Add Account
            var accIdx = row - 1
            if (accIdx >= 0 && accIdx < shulkAccounts.count) {
                var acc = shulkAccounts.get(accIdx)
                return acc.isActive ? 2 : 3 // View Skin, (Set Active), Remove
            }
            return 1
        } else if (root.activeCategory === 5) {
            if (row === 0) return 3 // Stable, Dev, Check for Updates
            if (shulkLauncher.updateAvailable && row === 1) return 1 // Download Update
            return 3 // GitHub, Website, Global Settings
        }
        return 1
    }

    function triggerAction() {
        if (typeof shulkSound !== "undefined") {
            shulkSound.playClick()
        }

        if (root.activeCategory === 0) {
            // Display & Scale
            if (root.itemRow === 0) {
                // Panorama Selector Dialog & Random
                if (root.itemCol === 0) {
                    root.openPanoramaDialogRequested()
                } else if (root.itemCol === 1) {
                    shulkTheme.selectRandomPanorama()
                }
            } else if (root.itemRow === 1) {
                // Panorama Ambient Blur
                if (root.itemCol >= 0 && root.itemCol < root.blurPresets.length) {
                    shulkTheme.setPanoramaBlurRadius(root.blurPresets[root.itemCol].val)
                }
            } else if (root.itemRow === 2) {
                // Interface Scaling Presets
                var scales = [0.0, 1.0, 1.35, 1.70, 2.0]
                if (root.itemCol >= 0 && root.itemCol < scales.length) {
                    shulkTheme.setCustomScale(scales[root.itemCol])
                }
            }
        } else if (root.activeCategory === 1) {
            // Controller (Disabled)
            return
        } else if (root.activeCategory === 2) {
            // Audio & Sounds
            if (root.itemRow === 0) {
                if (root.itemCol === 0) {
                    shulkSound.soundEnabled = true
                    if (shulkSound.volume === 0) shulkSound.volume = 80
                    shulkSound.playClick()
                } else {
                    shulkSound.soundEnabled = false
                }
            } else if (root.itemRow === 1) {
                var vols = [0, 25, 50, 75, 100]
                if (root.itemCol >= 0 && root.itemCol < vols.length) {
                    var targetVol = vols[root.itemCol]
                    if (targetVol === 0) {
                        shulkSound.soundEnabled = false
                        shulkSound.volume = 0
                    } else {
                        shulkSound.soundEnabled = true
                        shulkSound.volume = targetVol
                        shulkSound.playClick()
                    }
                }
            }
        } else if (root.activeCategory === 3) {
            // Java & Memory
            if (root.itemRow === 0) {
                if (root.itemCol >= 0 && root.itemCol < root.ramPresets.length) {
                    shulkLauncher.maxMemory = root.ramPresets[root.itemCol].val
                }
            } else if (root.itemRow === 1) {
                if (root.itemCol >= 0 && root.itemCol < root.minRamPresets.length) {
                    shulkLauncher.minMemory = root.minRamPresets[root.itemCol].val
                }
            } else if (root.itemRow === 2) {
                shulkLauncher.showGlobalSettings("Java")
            }
        } else if (root.activeCategory === 4) {
            // Accounts & Skin Viewer
            if (root.inAccountSkinViewer) {
                if (root.itemRow === 0) {
                    // Back to Accounts
                    root.inAccountSkinViewer = false
                    root.itemRow = root.skinAccountIndex + 1
                    root.itemCol = 0
                } else if (root.itemRow === 1) {
                    // View mode
                    root.skinViewMode = root.itemCol
                } else if (shulkAccounts.count > 1 && root.itemRow === 2) {
                    // Account switcher
                    if (root.itemCol === 0 && root.skinAccountIndex > 0) root.skinAccountIndex--
                    else if (root.itemCol === 1 && root.skinAccountIndex < shulkAccounts.count - 1) root.skinAccountIndex++
                } else {
                    // Actions: Set Active or Refresh Skin
                    var curAcc = shulkAccounts.get(root.skinAccountIndex)
                    var isAct = curAcc && curAcc.isActive
                    if (!isAct && root.itemCol === 0) {
                        shulkAccounts.setDefaultAccount(root.skinAccountIndex)
                    } else {
                        root.skinCacheBuster = Date.now()
                    }
                }
            } else {
                if (root.itemRow === 0) {
                    root.addAccountRequested()
                } else {
                    var accIdx = root.itemRow - 1
                    var acc = shulkAccounts.get(accIdx)
                    if (acc) {
                        if (root.itemCol === 0) {
                            // View Skin
                            root.skinAccountIndex = accIdx
                            root.inAccountSkinViewer = true
                            root.focusPane = 1
                            root.itemRow = 0
                            root.itemCol = 0
                        } else if (root.itemCol === 1) {
                            if (!acc.isActive) {
                                shulkAccounts.setDefaultAccount(accIdx)
                            } else {
                                root.confirmRemoveAccountRequested(accIdx, acc.name)
                            }
                        } else if (root.itemCol === 2) {
                            root.confirmRemoveAccountRequested(accIdx, acc.name)
                        }
                    }
                }
            }
        } else if (root.activeCategory === 5) {
            // About Shulk
            if (root.itemRow === 0) {
                if (root.itemCol === 0) {
                    shulkLauncher.updateChannel = "stable"
                } else if (root.itemCol === 1) {
                    shulkLauncher.updateChannel = "development"
                } else if (root.itemCol === 2) {
                    shulkLauncher.checkForUpdates(true)
                }
            } else if (shulkLauncher.updateAvailable && root.itemRow === 1) {
                shulkLauncher.openUpdateDownload()
            } else {
                // Links row
                if (root.itemCol === 0) {
                    Qt.openUrlExternally("https://github.com/NaiSenshin/Shulk")
                } else if (root.itemCol === 1) {
                    Qt.openUrlExternally("https://prismlauncher.org")
                } else if (root.itemCol === 2) {
                    shulkLauncher.showGlobalSettings()
                }
            }
        }
    }

    Connections {
        target: shulkAccounts
        function onCountChanged() {
            if (shulkAccounts.count === 0) {
                root.inAccountSkinViewer = false
            }
            root.skinAccountIndex = Math.max(0, Math.min(root.skinAccountIndex, shulkAccounts.count - 1))
            if (root.activeCategory === 4 && root.focusPane === 1) {
                var maxR = getMaxRows()
                if (root.itemRow >= maxR) {
                    root.itemRow = Math.max(0, maxR - 1)
                }
                var maxC = getMaxCols(root.itemRow)
                if (root.itemCol >= maxC) {
                    root.itemCol = Math.max(0, maxC - 1)
                }
            }
        }
    }

    function handleAction(action) {
        // Quick Category Switch Triggers (LT / RT)
        if (action === 15) { // ActionTriggerLeft (LT)
            root.cycleCategory(-1)
            return true
        } else if (action === 16) { // ActionTriggerRight (RT)
            root.cycleCategory(1)
            return true
        }

        if (action === Theme.actionBack) {
            if (root.activeCategory === 4 && root.inAccountSkinViewer) {
                root.inAccountSkinViewer = false
                root.itemRow = root.skinAccountIndex + 1
                root.itemCol = 0
                if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
                return true
            }
            if (root.focusPane === 1) {
                root.focusPane = 0
                if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
                return true
            } else {
                root.enterTopBarRequested()
                if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
                return true
            }
        }

        if (root.focusPane === 0) {
            // CATEGORY TABS NAVIGATION
            if (action === Theme.actionLeft) {
                root.cycleCategory(-1)
                return true
            } else if (action === Theme.actionRight) {
                root.cycleCategory(1)
                return true
            } else if (action === Theme.actionDown || action === Theme.actionAccept) {
                root.focusPane = 1
                root.itemRow = 0
                root.itemCol = 0
                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                return true
            } else if (action === Theme.actionUp) {
                root.enterTopBarRequested()
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            }
        } else {
            // CONTENT NAVIGATION
            var maxR = getMaxRows()
            var maxC = getMaxCols(root.itemRow)

            if (action === Theme.actionUp) {
                if (root.itemRow > 0) {
                    root.itemRow--
                    root.itemCol = Math.min(root.itemCol, getMaxCols(root.itemRow) - 1)
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                } else {
                    // Up from top row of content returns to category tabs (unless in skin viewer)
                    if (!(root.activeCategory === 4 && root.inAccountSkinViewer)) {
                        root.focusPane = 0
                        if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                    }
                }
                return true
            } else if (action === Theme.actionDown) {
                if (root.itemRow < maxR - 1) {
                    root.itemRow++
                    root.itemCol = Math.min(root.itemCol, getMaxCols(root.itemRow) - 1)
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                }
                return true
            } else if (action === Theme.actionLeft) {
                if (root.itemCol > 0) {
                    root.itemCol--
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                } else {
                    if (root.activeCategory === 4 && root.inAccountSkinViewer) {
                        root.inAccountSkinViewer = false
                        root.itemRow = root.skinAccountIndex + 1
                        root.itemCol = 0
                        if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    }
                }
                return true
            } else if (action === Theme.actionRight) {
                if (root.itemCol < maxC - 1) {
                    root.itemCol++
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                }
                return true
            } else if (action === Theme.actionAccept) {
                triggerAction()
                return true
            } else if (action === Theme.actionPrimary) {
                if (root.activeCategory === 4 && !root.inAccountSkinViewer && root.itemRow > 0) {
                    var delIdx = root.itemRow - 1
                    if (delIdx < shulkAccounts.count) {
                        var accToDel = shulkAccounts.get(delIdx)
                        root.confirmRemoveAccountRequested(delIdx, accToDel.username)
                    }
                }
                return true
            }
        }
        return false
    }

}

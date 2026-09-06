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

    signal addAccountRequested()
    signal confirmRemoveAccountRequested(int index, string name)

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
        { name: qsTr("Display & Scale"), iconSource: "qrc:/shulk/icons/grass_block.png", disabled: false },
        { name: qsTr("Controller"), iconSource: "qrc:/shulk/icons/pickaxe.png", disabled: true },
        { name: qsTr("Audio & Sounds"), iconSource: "qrc:/shulk/icons/noteblock.png", disabled: false },
        { name: qsTr("Java & Memory"), iconSource: "qrc:/shulk/icons/redstone.png", disabled: false },
        { name: qsTr("Accounts"), iconSource: "qrc:/shulk/icons/steve_head.png", disabled: false },
        { name: qsTr("About Shulk"), iconSource: "qrc:/shulk/icons/book.png", disabled: false }
    ]

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Theme.space8
        anchors.leftMargin: Theme.space24
        anchors.rightMargin: Theme.space24
        height: 58 * Theme.scale
        radius: Theme.radiusMd
        color: Theme.bgCard
        border.color: Theme.borderSubtle
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space16
            anchors.rightMargin: Theme.space16
            spacing: Theme.space12

            Image {
                Layout.preferredWidth: 28 * Theme.scale
                Layout.preferredHeight: 28 * Theme.scale
                source: root.categories[root.activeCategory].iconSource
                fillMode: Image.PreserveAspectFit
                smooth: false
            }

            Item {
                Layout.preferredWidth: 320 * Theme.scale
                Layout.fillHeight: true
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: 9 * Theme.scale
                    text: qsTr("Settings")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeTitle
                    font.bold: true
                    color: Theme.textPrimary
                }
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: 34 * Theme.scale
                    text: root.categories[root.activeCategory].name
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeCaption
                    color: Theme.textSecondary
                }
            }

            Item { Layout.fillWidth: true }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space24
        anchors.rightMargin: Theme.space24
        anchors.bottomMargin: Theme.space16
        anchors.topMargin: 78 * Theme.scale
        spacing: Theme.space12

        // -------------------------------------------------------------
        // LEFT CATEGORY BAR
        // -------------------------------------------------------------
        Item {
            Layout.preferredWidth: 240 * Theme.scale
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.bgCard
                border.color: root.focusPane === 0 ? Theme.borderFocused : Theme.borderSubtle
                border.width: root.focusPane === 0 ? 2 : 1
            }
            Rectangle {
                anchors.fill: parent; anchors.margins: 1; radius: 2
                visible: false
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.focusPane === 0 ? 2 : 1
                radius: Theme.radiusMd
                color: "transparent"
                clip: true

                ListView {
                    id: categoryList
                    anchors.fill: parent
                    anchors.margins: Theme.space8
                    spacing: Theme.space8
                    model: root.categories
                    clip: true
                    interactive: false

                    delegate: Item {
                        width: ListView.view ? ListView.view.width : 0
                        height: 52 * Theme.scale
                        opacity: modelData.disabled ? 0.45 : 1.0

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSm
                            color: root.activeCategory === index ? Theme.bgSurfaceFocused : (catMouse.containsMouse && !modelData.disabled ? Theme.bgSurfaceHover : "transparent")
                            border.color: root.activeCategory === index && root.focusPane === 0 ? Theme.borderFocused : (root.activeCategory === index ? Theme.borderSubtle : "transparent")
                            border.width: root.activeCategory === index ? (root.focusPane === 0 ? 2 : 1) : 0
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 2
                            visible: false
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: root.activeCategory === index && root.focusPane === 0 ? 2 : 1
                            radius: Theme.radiusSm
                            color: "transparent"
                            clip: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space8
                                spacing: Theme.space12

                                BorderImage {
                                    Layout.preferredWidth: 34 * Theme.scale
                                    Layout.preferredHeight: 34 * Theme.scale
                                    source: "qrc:/shulk/assets/mc/gui/slot.png"
                                    border { left: 4; top: 4; right: 4; bottom: 4 }
                                    horizontalTileMode: BorderImage.Stretch
                                    verticalTileMode: BorderImage.Stretch
                                    smooth: false

                                    Image {
                                        anchors.centerIn: parent
                                        width: 22 * Theme.scale
                                        height: 22 * Theme.scale
                                        source: modelData.iconSource
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    RowLayout {
                                        spacing: Theme.space6
                                        Layout.fillWidth: true

                                        Text {
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: root.activeCategory === index
                                            color: modelData.disabled ? "#7E828A" : Theme.textPrimary
                                            style: (root.activeCategory === index) ? Text.Outline : Text.Normal
                                            styleColor: "#3F3F3F"
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            visible: !!modelData.disabled
                                            Layout.preferredHeight: 18 * Theme.scale
                                            Layout.preferredWidth: comingSoonText.implicitWidth + 8 * Theme.scale
                                            radius: 3
                                            color: "#352A18"
                                            border.color: "#8A6D3B"
                                            border.width: 1

                                            Text {
                                                id: comingSoonText
                                                anchors.centerIn: parent
                                                text: qsTr("Coming Soon")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 9 * Theme.scale
                                                font.bold: true
                                                color: "#FFAA00"
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }

                                Rectangle {
                                    visible: root.activeCategory === index && root.focusPane === 0
                                    Layout.preferredWidth: 8 * Theme.scale
                                    Layout.preferredHeight: 8 * Theme.scale
                                    color: Theme.mcDiamond
                                    rotation: 45
                                    Layout.rightMargin: Theme.space8
                                }
                            }

                            MouseArea {
                                id: catMouse
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
        }

        // -------------------------------------------------------------
        // RIGHT SETTINGS CONTENT
        // -------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.bgCard
                border.color: root.focusPane === 1 ? Theme.borderFocused : Theme.borderSubtle
                border.width: root.focusPane === 1 ? 2 : 1
            }
            Rectangle {
                anchors.fill: parent; anchors.margins: 1; radius: 2
                visible: false
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.focusPane === 1 ? 2 : 1
                radius: Theme.radiusMd
                color: "transparent"
                clip: true

                StackLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space24
                    currentIndex: root.activeCategory

                    // ---------------------------------------------------------
                    // 0: DISPLAY & SCALING
                    // ---------------------------------------------------------
                    ScrollView {
                        contentWidth: availableWidth
                        clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: Theme.space20

                        Text {
                            text: qsTr("Display & Interface Scaling")
                            font.pixelSize: Theme.sizeSubheading
                            font.bold: true
                            color: Theme.textPrimary
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

                        // Row 0: Scale Factor Presets
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
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 0
                                onClicked: root.triggerAction()
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "1.0x (Deck)"
                                isPrimary: Math.abs(shulkTheme.customScaleFactor - 1.0) < 0.01
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 1
                                onClicked: { root.itemRow = 0; root.itemCol = 1; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "1.35x (Ally)"
                                isPrimary: Math.abs(shulkTheme.customScaleFactor - 1.35) < 0.01
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 2
                                onClicked: { root.itemRow = 0; root.itemCol = 2; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "1.70x (Go)"
                                isPrimary: Math.abs(shulkTheme.customScaleFactor - 1.70) < 0.01
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 3
                                onClicked: { root.itemRow = 0; root.itemCol = 3; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: "2.0x (TV)"
                                isPrimary: Math.abs(shulkTheme.customScaleFactor - 2.0) < 0.01
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 4
                                onClicked: { root.itemRow = 0; root.itemCol = 4; root.triggerAction(); }
                            }
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

                        // Row 2 & 3: Background Panorama Presets
                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: qsTr("Background Panorama Theme")
                                    font.pixelSize: Theme.sizeSmall
                                    font.bold: true
                                    color: Theme.mcEmerald
                                }
                                Text {
                                    text: qsTr("Active: %1").arg(shulkTheme.panoramaTitle)
                                    font.pixelSize: Theme.sizeSmall
                                    color: Theme.textGold
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Row 2: Roll Random Button
                            ShulkButton {
                                text: qsTr("Choose Random")
                                variant: "play"
                                implicitHeight: 34 * Theme.scale
                                isFocused: root.focusPane === 1 && root.itemRow === 2 && root.itemCol === 0
                                onClicked: {
                                    root.itemRow = 2
                                    root.itemCol = 0
                                    root.triggerAction()
                                }
                            }
                        }

                        // Row 3: Panorama Grid
                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.space8

                            Repeater {
                                model: shulkTheme.availablePanoramas

                                delegate: ShulkButton {
                                    text: modelData.title
                                    isPrimary: (shulkTheme.panoramaSetting === modelData.id) || (modelData.id !== "random" && shulkTheme.panoramaSetting === "random" && shulkTheme.activePanoramaId === modelData.id)
                                    variant: isPrimary ? "primary" : "secondary"
                                    implicitHeight: 32 * Theme.scale
                                    isFocused: root.focusPane === 1 && root.itemRow === 3 && root.itemCol === index
                                    onClicked: {
                                        root.itemRow = 3
                                        root.itemCol = index
                                        root.triggerAction()
                                    }
                                }
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
                        spacing: Theme.space20

                        Text {
                            text: qsTr("UI Sound Effects & Volume")
                            font.pixelSize: Theme.sizeSubheading
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: qsTr("Authentic Minecraft interface audio for controller navigation, card clicks, and launches.")
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textSecondary
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
                        spacing: Theme.space20

                        Text {
                            text: qsTr("Java Runtime & Memory (RAM)")
                            font.pixelSize: Theme.sizeSubheading
                            font.bold: true
                            color: Theme.textPrimary
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
                // 4: ACCOUNTS
                // ---------------------------------------------------------
                ColumnLayout {
                    spacing: Theme.space16

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: qsTr("Minecraft Accounts")
                            font.pixelSize: Theme.sizeSubheading
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        // Row 0: Add Account Button
                        ShulkButton {
                            text: qsTr("Add Microsoft Account")
                            variant: "play"
                            isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 0
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
                                    source: "qrc:/shulk/icons/steve_head.png"
                                    Layout.preferredWidth: 24 * Theme.scale
                                    Layout.preferredHeight: 24 * Theme.scale
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                }

                                ColumnLayout {
                                    spacing: 2

                                    RowLayout {
                                        spacing: Theme.space8
                                        Text {
                                            text: model.username
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: true
                                            color: Theme.textPrimary
                                        }

                                        ShulkBadge {
                                            visible: model.isActive
                                            text: qsTr("Active Account")
                                            isAccent: true
                                        }
                                    }

                                    Text {
                                        text: model.type + " | " + (model.ownsGame ? qsTr("Minecraft Owned") : qsTr("Offline"))
                                        font.pixelSize: Theme.sizeCaption
                                        color: Theme.textSecondary
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                ShulkButton {
                                    visible: !model.isActive
                                    text: qsTr("Set Active")
                                    variant: "play"
                                    implicitHeight: 34 * Theme.scale
                                    Layout.alignment: Qt.AlignRight
                                    isFocused: root.focusPane === 1 && root.itemRow === (index + 1) && root.itemCol === 0
                                    onClicked: {
                                        root.itemRow = index + 1
                                        root.itemCol = 0
                                        root.triggerAction()
                                    }
                                }

                                ShulkButton {
                                    text: qsTr("Remove")
                                    variant: "danger"
                                    implicitHeight: 34 * Theme.scale
                                    Layout.alignment: Qt.AlignRight
                                    isFocused: root.focusPane === 1 && root.itemRow === (index + 1) && (model.isActive ? (root.itemCol === 0) : (root.itemCol === 1))
                                    onClicked: {
                                        root.itemRow = index + 1
                                        root.itemCol = model.isActive ? 0 : 1
                                        root.triggerAction()
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

                        Text {
                            text: "Shulk"
                            font.pixelSize: 32 * Theme.scale
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: qsTr("Handheld Minecraft Java Edition Launcher - Version %1").arg(shulkLauncher.appVersion)
                            font.pixelSize: Theme.sizeBody
                            color: Theme.accentPrimary
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Shulk is a modern, handheld-first Minecraft launcher built for Steam Deck, ROG Ally, Lenovo Legion Go, and controller-driven living room PCs.")
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textSecondary
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space12

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Shulk GitHub Repository")
                                variant: "play"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 0
                                onClicked: { root.itemRow = 0; root.itemCol = 0; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Visit Prism Launcher Website")
                                variant: "primary"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 1
                                onClicked: { root.itemRow = 0; root.itemCol = 1; root.triggerAction(); }
                            }

                            ShulkButton {
                                Layout.fillWidth: true
                                text: qsTr("Open Global Prism Launcher Settings")
                                variant: "secondary"
                                isFocused: root.focusPane === 1 && root.itemRow === 0 && root.itemCol === 2
                                onClicked: { root.itemRow = 0; root.itemCol = 2; root.triggerAction(); }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderSubtle
                            Layout.topMargin: Theme.space8
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Open Source License Attribution:\nShulk is licensed under GPL-3.0-only. Built using the mature C++ backend foundation developed by the Prism Launcher, PolyMC, and MultiMC contributors.\n\nCopyright (C) 2026 Shulk Contributors\nCopyright (C) 2022-2026 Prism Launcher Contributors\nCopyright (C) 2021-2022 PolyMC Contributors\nCopyright (C) 2012-2021 MultiMC Contributors")
                            font.pixelSize: Theme.sizeCaption
                            color: Theme.textMuted
                            wrapMode: Text.WordWrap
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
        if (root.activeCategory === 0) return 4 // Scale, Blur, Random, Panorama Grid
        if (root.activeCategory === 1) return 2 // Glyphs, Actions
        if (root.activeCategory === 2) return 2 // Enable/Disable, Volume Levels
        if (root.activeCategory === 3) return 3 // Max RAM, Min RAM, Advanced
        if (root.activeCategory === 4) return 1 + shulkAccounts.count // Add button + account rows
        if (root.activeCategory === 5) return 1 // Actions
        return 1
    }

    function getMaxCols(row) {
        if (root.activeCategory === 0) {
            if (row === 0) return 5 // Auto, 1.0, 1.35, 1.70, 2.0
            if (row === 1) return 4 // Off, Subtle, Medium, Heavy
            if (row === 2) return 1 // Roll Random
            if (row === 3) return shulkTheme.availablePanoramas.length // 11
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
            if (row === 0) return 1 // Add Account
            var accIdx = row - 1
            if (accIdx >= 0 && accIdx < shulkAccounts.count) {
                var acc = shulkAccounts.get(accIdx)
                return acc.isActive ? 1 : 2
            }
            return 1
        } else if (root.activeCategory === 5) {
            if (row === 0) return 3 // GitHub, Website, Global Settings
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
                var scales = [0.0, 1.0, 1.35, 1.70, 2.0]
                if (root.itemCol >= 0 && root.itemCol < scales.length) {
                    shulkTheme.setCustomScale(scales[root.itemCol])
                }
            } else if (root.itemRow === 1) {
                if (root.itemCol >= 0 && root.itemCol < root.blurPresets.length) {
                    shulkTheme.setPanoramaBlurRadius(root.blurPresets[root.itemCol].val)
                }
            } else if (root.itemRow === 2) {
                shulkTheme.selectRandomPanorama()
            } else if (root.itemRow === 3) {
                if (root.itemCol >= 0 && root.itemCol < shulkTheme.availablePanoramas.length) {
                    shulkTheme.setPanorama(shulkTheme.availablePanoramas[root.itemCol].id)
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
                        if (targetVol === 100) shulkSound.playLaunch()
                        else shulkSound.playClick()
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
            // Accounts
            if (root.itemRow === 0) {
                root.addAccountRequested()
            } else {
                var accIdx = root.itemRow - 1
                if (accIdx >= 0 && accIdx < shulkAccounts.count) {
                    var acc = shulkAccounts.get(accIdx)
                    if (acc.isActive || root.itemCol === 1) {
                        root.confirmRemoveAccountRequested(accIdx, acc.username)
                    } else {
                        shulkAccounts.setDefaultAccount(accIdx)
                    }
                }
            }
        } else if (root.activeCategory === 5) {
            // About Shulk
            if (root.itemRow === 0) {
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
        if (action === Theme.actionBack) {
            if (root.focusPane === 1) {
                root.focusPane = 0
                if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
                return true
            }
            return false
        }

        if (root.focusPane === 0) {
            // SIDEBAR NAVIGATION
            if (action === Theme.actionUp) {
                var nextUp = root.activeCategory - 1
                while (nextUp >= 0 && root.categories[nextUp].disabled) {
                    nextUp--
                }
                if (nextUp >= 0) {
                    root.activeCategory = nextUp
                    root.itemRow = 0
                    root.itemCol = 0
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                }
                return true
            } else if (action === Theme.actionDown) {
                var nextDown = root.activeCategory + 1
                while (nextDown < root.categories.length && root.categories[nextDown].disabled) {
                    nextDown++
                }
                if (nextDown < root.categories.length) {
                    root.activeCategory = nextDown
                    root.itemRow = 0
                    root.itemCol = 0
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                }
                return true
            } else if (action === Theme.actionRight || action === Theme.actionAccept) {
                if (!root.categories[root.activeCategory].disabled) {
                    root.focusPane = 1
                    root.itemRow = 0
                    root.itemCol = 0
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                }
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
                    // Return to category sidebar
                    root.focusPane = 0
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
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
                if (root.activeCategory === 4 && root.itemRow > 0) {
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

// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

FocusScope {
    id: root

    property var pack: null

    signal backRequested()
    signal installRequested()

    property var richDetails: null
    property int activeTab: 1 // 0 = Overview, 1 = Mods, 2 = Screenshots, 3 = Specifications
    property int focusedArea: 0 // 0 = Action Buttons, 1 = Tabs, 2 = Content
    property int actionBtnIndex: 0 // 0 = Install, 1 = Website, 2 = Back
    property string modSearchQuery: ""
    property var activeLightboxImage: null

    function formatMarkdownText(raw) {
        if (!raw) return ""
        var s = raw
        
        // If already HTML formatted (e.g. from CurseForge description API)
        if (/<(?:p|div|br|h[1-6]|ul|ol|table)\b/i.test(s)) {
            s = s.replace(/<img\b[^>]*src=["']https?:\/\/(?:www\.)?youtube\.com[^"']*["'][^>]*>/gi, '')
            s = s.replace(/<img\b[^>]*src=["']https?:\/\/youtu\.be[^"']*["'][^>]*>/gi, '')
            s = s.replace(/<a\b([^>]*)>/gi, '<a$1 style="color: #38BDF8; text-decoration: underline;">')
            return s
        }

        // 1. Resolve markdown reference links: [text][ref] and [ref]: url
        var refMap = {}
        var lines = s.split("\n")
        var cleanLines = []
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i]
            var m = line.match(/^\[([0-9a-zA-Z_\-]+)\]:\s*(\S+)/)
            if (m) {
                refMap[m[1]] = m[2]
            } else {
                cleanLines.push(line)
            }
        }
        s = cleanLines.join("\n")

        s = s.replace(/\[([^\]]+)\]\[([0-9a-zA-Z_\-]+)\]/g, function(match, txt, ref) {
            if (refMap[ref]) {
                return '<a href="' + refMap[ref] + '" style="color: #38BDF8; text-decoration: underline;">' + txt + '</a>'
            }
            return txt
        })

        // 2. Inline links [text](url)
        s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" style="color: #38BDF8; text-decoration: underline;">$1</a>')

        // 3. Bold: **text** or __text__ -> bright bold white
        s = s.replace(/\*\*(.*?)\*\*/g, '<b style="color: #FFFFFF;">$1</b>')
        s = s.replace(/__(.*?)__/g, '<b style="color: #FFFFFF;">$1</b>')

        // 4. Italic: *text*
        s = s.replace(/(^|[^\*])\*([^\*]+)\*([^\*]|$)/g, '$1<i style="color: #CBD5E1;">$2</i>$3')

        // 5. Headers: ### Heading, ## Heading, # Heading (styled with distinct color and margin)
        s = s.replace(/^###\s+(.*$)/gm, '<br/><font color="#55FFFF" size="+1"><b>$1</b></font><br/>')
        s = s.replace(/^##\s+(.*$)/gm, '<br/><font color="#55FFFF" size="+2"><b>$1</b></font><br/>')
        s = s.replace(/^#\s+(.*$)/gm, '<br/><font color="#FFAA00" size="+3"><b>$1</b></font><br/>')

        // 6. Bullet lists
        s = s.replace(/^[\*\-]\s+(.*$)/gm, '&nbsp;&nbsp;<font color="#55FFFF">-</font> $1')

        // 7. Line breaks
        s = s.replace(/\n\n+/g, '<br/><br/>')
        s = s.replace(/\n/g, '<br/>')

        return s
    }

    readonly property string effectiveName: (richDetails && richDetails.name) ? richDetails.name : (pack ? pack.name : "")
    readonly property string effectiveDesc: (richDetails && richDetails.description) ? richDetails.description : (pack ? pack.description : "")
    readonly property string effectiveBody: (richDetails && richDetails.body && richDetails.body.length > 0) ? richDetails.body : effectiveDesc
    readonly property string effectiveDescFormatted: formatMarkdownText(effectiveDesc)
    readonly property string effectiveBodyFormatted: formatMarkdownText(effectiveBody)
    readonly property string effectiveIcon: (richDetails && richDetails.iconUrl && richDetails.iconUrl.length > 0) ? richDetails.iconUrl : (pack && pack.iconUrl ? pack.iconUrl : "qrc:/shulk/icons/grass_block_side.png")
    readonly property string effectiveBanner: (pack && pack.bannerUrl && pack.bannerUrl.length > 0) ? pack.bannerUrl : "qrc:/shulk/assets/default_pack_banner.jpg"
    readonly property string effectiveWebsite: (richDetails && richDetails.websiteUrl) ? richDetails.websiteUrl : (pack && pack.websiteUrl ? pack.websiteUrl : "")
    readonly property var galleryItems: (richDetails && richDetails.gallery && richDetails.gallery.length > 0) ? richDetails.gallery : []
    readonly property var modsList: (richDetails && richDetails.mods && richDetails.mods.length > 0) ? richDetails.mods : []
    readonly property int totalModCount: (richDetails && richDetails.modCount) ? richDetails.modCount : modsList.length

    onPackChanged: {
        root.richDetails = null
        root.activeTab = 0
        root.modSearchQuery = ""
        root.activeLightboxImage = null
        if (pack && pack.platform && pack.id) {
            shulkCreation.fetchPackDetails(pack.platform, pack.id, pack.name || pack.safeName || "")
        }
    }

    Component.onCompleted: {
        if (pack && pack.platform && pack.id) {
            shulkCreation.fetchPackDetails(pack.platform, pack.id, pack.name || pack.safeName || "")
        }
    }

    Connections {
        target: shulkCreation
        function onPackDetailsLoaded(packId, details) {
            if (root.pack && (String(root.pack.id) === String(packId) || String(root.pack.slug) === String(packId) || String(root.pack.name) === String(packId))) {
                root.richDetails = details
            }
        }
    }

    // Background Gradient Wash
    Rectangle {
        anchors.fill: parent
        color: Theme.bgDeep
        opacity: 0.96
    }

    // Top Atmospheric Banner Header
    Item {
        id: bannerHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 180 * Theme.scale
        clip: true

        Image {
            id: bannerImg
            anchors.fill: parent
            source: root.effectiveBanner
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            opacity: 0.45
        }

        // Gradient fade into deep background
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#400E1015" }
                GradientStop { position: 0.7; color: "#C00E1015" }
                GradientStop { position: 1.0; color: Theme.bgDeep }
            }
        }

        // Top Header Navigation Bar
        RowLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.space16
            spacing: Theme.space12

            ShulkButton {
                text: qsTr("Back to Discover (B)")
                implicitHeight: 34 * Theme.scale
                implicitWidth: 180 * Theme.scale
                isFocused: (root.focusedArea === 0 && root.actionBtnIndex === 2)
                onClicked: {
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    root.backRequested()
                }
            }

            Item { Layout.fillWidth: true }

            // Platform Origin Badge
            Rectangle {
                Layout.preferredHeight: 28 * Theme.scale
                Layout.preferredWidth: platSourceRow.implicitWidth + 20 * Theme.scale
                radius: Theme.radiusMd
                color: Theme.bgCard
                border.color: Theme.borderSubtle
                border.width: 1

                RowLayout {
                    id: platSourceRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: qsTr("Source:")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        color: Theme.textSecondary
                    }

                    Text {
                        id: platSourceText
                        text: root.pack ? (root.pack.platform ? root.pack.platform.toUpperCase() : "MODPACK") : "MODPACK"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        font.bold: true
                        color: Theme.mcDiamond
                    }
                }
            }
        }

        // Modpack Identity Row
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.space16
            anchors.bottomMargin: Theme.space12
            spacing: Theme.space16

            // 64x64 3D Minecraft Recessed Slot for Icon
            Rectangle {
                Layout.preferredWidth: 64 * Theme.scale
                Layout.preferredHeight: 64 * Theme.scale
                radius: Theme.radiusMd
                color: Theme.bgCard
                border.color: Theme.borderSubtle
                border.width: 2

                Image {
                    anchors.centerIn: parent
                    width: 48 * Theme.scale
                    height: 48 * Theme.scale
                    source: root.effectiveIcon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }
            }

            // Title & Badges
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space4

                Text {
                    Layout.fillWidth: true
                    text: root.effectiveName
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeTitle
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                RowLayout {
                    spacing: Theme.space8

                    Text {
                        text: root.pack ? qsTr("By %1").arg(root.pack.author) : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeBody
                        color: Theme.textSecondary
                    }

                    Text {
                        text: "|"
                        color: Theme.textMuted
                    }

                    Text {
                        text: root.pack ? qsTr("%1 Downloads").arg(root.pack.downloads) : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeBody
                        font.bold: true
                        color: Theme.textGold
                    }

                    ShulkBadge {
                        text: root.pack ? "MC " + root.pack.version : "MC 1.21.1"
                        isAccent: true
                    }

                    ShulkBadge {
                        text: root.pack ? root.pack.loader : "Fabric"
                    }

                    ShulkBadge {
                        visible: root.totalModCount > 0
                        text: qsTr("%1 Mods").arg(root.totalModCount)
                    }
                }
            }
        }
    }

    // Action Command Bar & Tab Selector
    Rectangle {
        id: actionTabRow
        anchors.top: bannerHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 52 * Theme.scale
        color: Theme.bgCard
        border.color: Theme.borderSubtle
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space16
            anchors.rightMargin: Theme.space16
            spacing: Theme.space12

            // Prominent Emerald Install Button
            ShulkButton {
                text: qsTr("Install Modpack")
                variant: "play"
                implicitHeight: 38 * Theme.scale
                implicitWidth: 180 * Theme.scale
                isFocused: (root.focusedArea === 0 && root.actionBtnIndex === 0)
                onClicked: {
                    if (typeof shulkSound !== "undefined") shulkSound.playLaunch()
                    root.installRequested()
                }
            }

            // Official Website Link Button
            ShulkButton {
                visible: root.effectiveWebsite.length > 0
                text: qsTr("View on Web (Y)")
                implicitHeight: 38 * Theme.scale
                implicitWidth: 160 * Theme.scale
                isFocused: (root.focusedArea === 0 && root.actionBtnIndex === 1)
                onClicked: {
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    if (root.effectiveWebsite.length > 0) {
                        Qt.openUrlExternally(root.effectiveWebsite)
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Sub-Navigation Tabs (Overview / Mods / Screenshots / Specs)
            RowLayout {
                spacing: Theme.space8

                Item {
                    Layout.preferredWidth: 32 * Theme.scale
                    Layout.preferredHeight: 32 * Theme.scale

                    ShulkControllerGlyph {
                        anchors.centerIn: parent
                        glyph: "lt"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeTab > 0) {
                                root.activeTab--
                                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                            }
                        }
                    }
                }

                Repeater {
                    model: [
                        { name: qsTr("Overview"), idx: 0 },
                        { name: qsTr("Mods (%1)").arg(root.totalModCount), idx: 1 },
                        { name: qsTr("Gallery (%1)").arg(root.galleryItems.length), idx: 2, visible: root.galleryItems.length > 0 },
                        { name: qsTr("Specifications"), idx: 3 }
                    ]

                    delegate: Rectangle {
                        visible: modelData.visible !== false
                        Layout.preferredHeight: 34 * Theme.scale
                        Layout.preferredWidth: tabText.implicitWidth + 24 * Theme.scale
                        radius: 4
                        color: root.activeTab === modelData.idx ? "#2B354D" : (tabMouse.containsMouse ? "#1E2433" : "transparent")
                        border.color: (root.focusedArea === 1 && root.activeTab === modelData.idx) ? Theme.mcDiamond : (root.activeTab === modelData.idx ? "#46567D" : "transparent")
                        border.width: 1.5

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            font.bold: root.activeTab === modelData.idx
                            color: root.activeTab === modelData.idx ? "#FFFFFF" : Theme.textSecondary
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                                root.activeTab = modelData.idx
                                root.focusedArea = 1
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: 32 * Theme.scale
                    Layout.preferredHeight: 32 * Theme.scale

                    ShulkControllerGlyph {
                        anchors.centerIn: parent
                        glyph: "rt"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeTab < 3) {
                                root.activeTab++
                                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                            }
                        }
                    }
                }
            }
        }
    }

    // Content Body Flickable
    Flickable {
        id: contentFlick
        anchors.top: actionTabRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space16
        anchors.bottomMargin: Theme.space24
        contentWidth: width
        contentHeight: bodyCol.implicitHeight + 40 * Theme.scale
        clip: true
        boundsBehavior: Flickable.DragOverBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            active: true
        }

        Behavior on contentY {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        ColumnLayout {
            id: bodyCol
            width: contentFlick.width
            spacing: Theme.space20

            // =================================================================
            // TAB 0: OVERVIEW & HIGHLIGHTS
            // =================================================================
            ColumnLayout {
                visible: root.activeTab === 0
                Layout.fillWidth: true
                spacing: Theme.space16

                // Highlights Banner Box
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: highlightCol.implicitHeight + Theme.space24
                    radius: Theme.radiusMd
                    color: Theme.bgCard
                    border.color: Theme.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        id: highlightCol
                        anchors.fill: parent
                        anchors.margins: Theme.space16
                        spacing: Theme.space10

                        RowLayout {
                            spacing: Theme.space8
                            Image {
                                Layout.preferredWidth: 24 * Theme.scale
                                Layout.preferredHeight: 24 * Theme.scale
                                source: "qrc:/shulk/assets/mc/nether_star.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                            }
                            Text {
                                text: qsTr("About this Modpack")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeHeader
                                font.bold: true
                                color: Theme.mcEmerald
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.effectiveDescFormatted
                            textFormat: Text.RichText
                            font.family: Theme.fontFamily
                            font.pixelSize: 15 * Theme.scale
                            color: "#E2E8F0"
                            wrapMode: Text.WordWrap
                            lineHeight: 1.5
                            onLinkActivated: (link) => Qt.openUrlExternally(link)
                        }
                    }
                }

                // Screenshots Preview Strip (if available)
                ColumnLayout {
                    visible: root.galleryItems.length > 0
                    Layout.fillWidth: true
                    spacing: Theme.space8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Media Preview")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeHeader
                            font.bold: true
                            color: Theme.mcDiamond
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: qsTr("View all %1 screenshots").arg(root.galleryItems.length)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            color: Theme.mcDiamond
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeTab = 2
                                }
                            }
                        }
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 130 * Theme.scale
                        contentWidth: previewStripRow.implicitWidth
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.DragOverBounds

                        RowLayout {
                            id: previewStripRow
                            spacing: Theme.space12
                            height: parent.height

                            Repeater {
                                model: root.galleryItems.slice(0, 6)

                                delegate: Rectangle {
                                    Layout.preferredWidth: 200 * Theme.scale
                                    Layout.preferredHeight: 120 * Theme.scale
                                    radius: Theme.radiusMd
                                    color: Theme.bgCard
                                    border.color: Theme.borderSubtle
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.url
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        mipmap: true
                                        asynchronous: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (typeof shulkSound !== "undefined") shulkSound.playClick()
                                            root.activeLightboxImage = modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Included Mods Preview Strip
                ColumnLayout {
                    visible: root.modsList.length > 0
                    Layout.fillWidth: true
                    spacing: Theme.space8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Included Mods (%1)").arg(root.totalModCount)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeHeader
                            font.bold: true
                            color: Theme.textGold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: qsTr("Browse all %1 mods").arg(root.totalModCount)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            color: Theme.mcDiamond
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeTab = 1
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.min(2, Math.floor(contentFlick.width / (380 * Theme.scale))))
                        rowSpacing: Theme.space8
                        columnSpacing: Theme.space12

                        Repeater {
                            model: root.modsList.slice(0, 6)

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52 * Theme.scale
                                radius: Theme.radiusMd
                                color: Theme.bgCard
                                border.color: Theme.borderSubtle
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space8
                                    spacing: Theme.space10

                                    Rectangle {
                                        Layout.preferredWidth: 36 * Theme.scale
                                        Layout.preferredHeight: 36 * Theme.scale
                                        radius: 4
                                        color: Theme.bgSurface
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            source: (modelData.iconUrl && modelData.iconUrl.length > 0) ? modelData.iconUrl : "qrc:/shulk/icons/grass_block_side.png"
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            mipmap: true
                                            asynchronous: true
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
                                            text: modelData.description ? modelData.description : qsTr("Included mod")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeSmall
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Detailed Body / README
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: bodyTextCol.implicitHeight + Theme.space32
                    radius: Theme.radiusMd
                    color: Theme.bgCard
                    border.color: Theme.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        id: bodyTextCol
                        anchors.fill: parent
                        anchors.margins: Theme.space20
                        spacing: Theme.space12

                        RowLayout {
                            spacing: Theme.space8
                            Image {
                                Layout.preferredWidth: 24 * Theme.scale
                                Layout.preferredHeight: 24 * Theme.scale
                                source: "qrc:/shulk/icons/book.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                            }
                            Text {
                                text: qsTr("Project Overview & Features")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeHeader
                                font.bold: true
                                color: Theme.mcDiamond
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.borderSubtle
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.effectiveBodyFormatted
                            textFormat: Text.RichText
                            font.family: Theme.fontFamily
                            font.pixelSize: 14 * Theme.scale
                            color: "#CBD5E1"
                            wrapMode: Text.WordWrap
                            lineHeight: 1.6
                            onLinkActivated: (link) => Qt.openUrlExternally(link)
                        }
                    }
                }
            }

            // =================================================================
            // TAB 1: INCLUDED MODS LIST
            // =================================================================
            ColumnLayout {
                visible: root.activeTab === 1
                Layout.fillWidth: true
                spacing: Theme.space16

                // Search Bar for included mods
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40 * Theme.scale
                        radius: Theme.radiusMd
                        color: Theme.bgCard
                        border.color: modInput.activeFocus ? Theme.borderFocused : Theme.borderSubtle
                        border.width: 1.5

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space12
                            anchors.rightMargin: Theme.space12
                            spacing: Theme.space8

                            Image {
                                Layout.preferredWidth: 20 * Theme.scale
                                Layout.preferredHeight: 20 * Theme.scale
                                source: "qrc:/shulk/icons/spyglass.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                            }

                            TextInput {
                                id: modInput
                                Layout.fillWidth: true
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeBody
                                color: Theme.textPrimary
                                text: root.modSearchQuery
                                onTextChanged: root.modSearchQuery = text

                                Text {
                                    text: qsTr("Filter included mods...")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    color: Theme.textMuted
                                    visible: !modInput.text && !modInput.activeFocus
                                }
                            }
                        }
                    }

                    ShulkBadge {
                        text: qsTr("%1 Total Mods").arg(root.totalModCount)
                        isAccent: true
                    }
                }

                // Mods Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: Math.max(1, Math.min(2, Math.floor(contentFlick.width / (380 * Theme.scale))))
                    rowSpacing: Theme.space10
                    columnSpacing: Theme.space12

                    Repeater {
                        model: {
                            if (!root.modSearchQuery.trim()) return root.modsList
                            var q = root.modSearchQuery.trim().toLowerCase()
                            return root.modsList.filter(function(item) {
                                return (item.name && item.name.toLowerCase().indexOf(q) !== -1) ||
                                       (item.description && item.description.toLowerCase().indexOf(q) !== -1)
                            })
                        }

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64 * Theme.scale
                            radius: Theme.radiusMd
                            color: Theme.bgCard
                            border.color: Theme.borderSubtle
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space8
                                spacing: Theme.space10

                                Rectangle {
                                    Layout.preferredWidth: 44 * Theme.scale
                                    Layout.preferredHeight: 44 * Theme.scale
                                    radius: 4
                                    color: Theme.bgSurface
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: (modelData.iconUrl && modelData.iconUrl.length > 0) ? modelData.iconUrl : "qrc:/shulk/icons/grass_block_side.png"
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                        asynchronous: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space8

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.sizeBody
                                            font.bold: true
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                        }

                                        ShulkBadge {
                                            visible: !!modelData.clientSide
                                            text: modelData.clientSide ? modelData.clientSide : ""
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.description ? modelData.description : qsTr("Included modification")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeSmall
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 2: GALLERY & SCREENSHOTS
            // =================================================================
            ColumnLayout {
                visible: root.activeTab === 2
                Layout.fillWidth: true
                spacing: Theme.space16

                Text {
                    text: qsTr("Official Screenshots & Media (%1)").arg(root.galleryItems.length)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeHeader
                    font.bold: true
                    color: Theme.textPrimary
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: Math.max(1, Math.min(2, Math.floor(contentFlick.width / (400 * Theme.scale))))
                    rowSpacing: Theme.space16
                    columnSpacing: Theme.space16

                    Repeater {
                        model: root.galleryItems

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 240 * Theme.scale
                            radius: Theme.radiusMd
                            color: Theme.bgCard
                            border.color: Theme.borderSubtle
                            border.width: 1
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                Image {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    source: modelData.url
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                    asynchronous: true
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36 * Theme.scale
                                    color: Theme.bgSurface

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.title ? modelData.title : qsTr("Screenshot %1").arg(index + 1)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeCaption
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                                    root.activeLightboxImage = modelData
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 3: TECHNICAL SPECIFICATIONS
            // =================================================================
            ColumnLayout {
                visible: root.activeTab === 3
                Layout.fillWidth: true
                spacing: Theme.space16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: specsCol.implicitHeight + Theme.space32
                    radius: Theme.radiusMd
                    color: Theme.bgCard
                    border.color: Theme.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        id: specsCol
                        anchors.fill: parent
                        anchors.margins: Theme.space20
                        spacing: Theme.space16

                        Text {
                            text: qsTr("Technical Specifications")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeHeader
                            font.bold: true
                            color: Theme.mcDiamond
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.borderSubtle
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: Theme.space12
                            columnSpacing: Theme.space24

                            Text { text: qsTr("Target Minecraft Version:"); font.family: Theme.fontFamily; color: Theme.textSecondary }
                            Text { text: root.pack ? root.pack.version : "1.21.1"; font.family: Theme.fontFamily; font.bold: true; color: Theme.textPrimary }

                            Text { text: qsTr("Mod Loader:"); font.family: Theme.fontFamily; color: Theme.textSecondary }
                            Text { text: root.pack ? root.pack.loader : "Fabric"; font.family: Theme.fontFamily; font.bold: true; color: Theme.mcEmerald }

                            Text { text: qsTr("Included Modifications:"); font.family: Theme.fontFamily; color: Theme.textSecondary }
                            Text { text: qsTr("%1 Mods").arg(root.totalModCount); font.family: Theme.fontFamily; font.bold: true; color: Theme.textGold }

                            Text { text: qsTr("Platform Source:"); font.family: Theme.fontFamily; color: Theme.textSecondary }
                            Text { text: root.pack ? root.pack.platform.toUpperCase() : "MODRINTH"; font.family: Theme.fontFamily; font.bold: true; color: Theme.textGold }

                            Text { text: qsTr("Total Downloads:"); font.family: Theme.fontFamily; color: Theme.textSecondary }
                            Text { text: root.pack ? root.pack.downloads : "0"; font.family: Theme.fontFamily; font.bold: true; color: Theme.textPrimary }

                            Text { text: qsTr("License:"); font.family: Theme.fontFamily; color: Theme.textSecondary }
                            Text { text: (root.richDetails && root.richDetails.license) ? root.richDetails.license : "Open Source / Custom"; font.family: Theme.fontFamily; color: Theme.textPrimary }

                            Text { text: qsTr("Recommended Memory:"); font.family: Theme.fontFamily; color: Theme.textSecondary }
                            Text { text: "4096 MB - 6144 MB (Handheld Optimized)"; font.family: Theme.fontFamily; color: Theme.mcDiamond }
                        }
                    }
                }
            }
        }
    }

    // =================================================================
    // FULLSCREEN SCREENSHOT LIGHTBOX
    // =================================================================
    Rectangle {
        id: lightbox
        anchors.fill: parent
        color: "#E60B0C10"
        visible: root.activeLightboxImage !== null
        z: 9999

        MouseArea {
            anchors.fill: parent
            onClicked: root.activeLightboxImage = null
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 64 * Theme.scale, 960 * Theme.scale)
            spacing: Theme.space12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: root.activeLightboxImage ? (root.activeLightboxImage.title ? root.activeLightboxImage.title : qsTr("Screenshot")) : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeHeader
                    font.bold: true
                    color: Theme.textPrimary
                }

                ShulkButton {
                    text: qsTr("Close (B)")
                    implicitHeight: 34 * Theme.scale
                    implicitWidth: 110 * Theme.scale
                    onClicked: root.activeLightboxImage = null
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(root.height * 0.7, 540 * Theme.scale)
                radius: Theme.radiusMd
                color: Theme.bgCard
                border.color: Theme.borderSubtle
                border.width: 2
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.activeLightboxImage ? (root.activeLightboxImage.raw_url ? root.activeLightboxImage.raw_url : root.activeLightboxImage.url) : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !!(root.activeLightboxImage && root.activeLightboxImage.description)
                text: root.activeLightboxImage && root.activeLightboxImage.description ? root.activeLightboxImage.description : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeBody
                color: Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Controller Input Handler
    function handleAction(action) {
        if (root.activeLightboxImage !== null) {
            if (action === 6 || action === 5) { // B or A closes lightbox
                root.activeLightboxImage = null
                if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
                return true
            }
            return true
        }

        if (action === 6) { // ActionBack (B)
            if (typeof shulkSound !== "undefined") shulkSound.playClick()
            root.backRequested()
            return true
        }

        if (action === 8) { // ActionSecondary (Y)
            if (root.effectiveWebsite.length > 0) {
                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                Qt.openUrlExternally(root.effectiveWebsite)
                return true
            }
        }

        if (action === 15 || action === Theme.actionTriggerLeft) { // ActionTriggerLeft (LT)
            if (root.activeTab > 0) {
                root.activeTab--
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            }
        }

        if (action === 16 || action === Theme.actionTriggerRight) { // ActionTriggerRight (RT)
            if (root.activeTab < 3) {
                root.activeTab++
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            }
        }

        if (action === 7) { // ActionPrimary (X)
            // Cycle tabs with X button
            root.activeTab = (root.activeTab + 1) % 4
            if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            return true
        }

        if (action === 1) { // ActionNavigateUp
            if (root.focusedArea === 2) {
                if (contentFlick.contentY > 20) {
                    contentFlick.contentY = Math.max(0, contentFlick.contentY - 140 * Theme.scale)
                } else {
                    root.focusedArea = 0
                }
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            } else if (root.focusedArea === 1) {
                root.focusedArea = 0
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            }
        }

        if (action === 2) { // ActionNavigateDown
            if (root.focusedArea === 0) {
                root.focusedArea = 2
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            } else if (root.focusedArea === 2) {
                contentFlick.contentY = Math.min(contentFlick.contentHeight - contentFlick.height, contentFlick.contentY + 140 * Theme.scale)
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            }
        }

        if (action === 3) { // ActionNavigateLeft
            if (root.focusedArea === 0 && root.actionBtnIndex > 0) {
                root.actionBtnIndex--
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            } else if (root.focusedArea === 1 && root.activeTab > 0) {
                root.activeTab--
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            }
        }

        if (action === 4) { // ActionNavigateRight
            if (root.focusedArea === 0 && root.actionBtnIndex < 2) {
                root.actionBtnIndex++
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            } else if (root.focusedArea === 1 && root.activeTab < 3) {
                root.activeTab++
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            }
        }

        if (action === 5) { // ActionAccept (A)
            if (root.focusedArea === 0) {
                if (root.actionBtnIndex === 0) {
                    if (typeof shulkSound !== "undefined") shulkSound.playLaunch()
                    root.installRequested()
                    return true
                } else if (root.actionBtnIndex === 1) {
                    if (root.effectiveWebsite.length > 0) {
                        Qt.openUrlExternally(root.effectiveWebsite)
                        return true
                    }
                } else if (root.actionBtnIndex === 2) {
                    root.backRequested()
                    return true
                }
            } else {
                // If in content or tabs, pressing (A) triggers install as primary action
                if (typeof shulkSound !== "undefined") shulkSound.playLaunch()
                root.installRequested()
                return true
            }
        }

        return false
    }
}

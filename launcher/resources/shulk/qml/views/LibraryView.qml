// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.shulk.launcher
import "../theme"
import "../components"

FocusScope {
    id: root

    signal openProfile(var profile)
    signal createProfileRequested()
    signal openOptionsRequested(var profile)
    signal openSortRequested()

    property string searchQuery: ""
    property string sortType: "recent"
    property int gridIndex: 0
    property int activeSection: 0 // 0 = Grid, 1 = Toolbar
    property int toolbarIndex: 0  // 0 = Search, 1 = Sort & Filter, 2 = New Profile
    readonly property int gridColumns: Math.max(1, Math.floor(profileGrid.width / (284 * Theme.scale)))

    onSearchQueryChanged: { root.gridIndex = 0 }
    onSortTypeChanged: { root.gridIndex = 0 }

    ShulkProfileFilterModel {
        id: filteredProfiles
        sourceModel: shulkProfiles
        filterString: root.searchQuery
        sortType: root.sortType
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space24
        anchors.rightMargin: Theme.space24
        anchors.bottomMargin: Theme.space16
        anchors.topMargin: Theme.space8
        spacing: Theme.space16

        // Top Toolbar: Search & Actions
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            // Search Bar (Official Minecraft Text Field)
            BorderImage {
                Layout.fillWidth: true
                Layout.preferredHeight: 46 * Theme.scale
                source: ((root.activeSection === 1 && root.toolbarIndex === 0) || searchInput.activeFocus) ? "qrc:/shulk/assets/mc/gui/text_field_highlighted.png" : "qrc:/shulk/assets/mc/gui/text_field.png"
                border { left: 4; top: 4; right: 4; bottom: 4 }
                horizontalTileMode: BorderImage.Stretch
                verticalTileMode: BorderImage.Stretch
                smooth: false

                // Focus ring for controller
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    color: "transparent"
                    border.color: Theme.mcDiamond
                    border.width: 2
                    radius: 2
                    visible: (root.activeSection === 1 && root.toolbarIndex === 0)
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

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            text: qsTr("Search profiles... (Press Y)")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textMuted
                            visible: searchInput.text.length === 0
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textPrimary
                            text: root.searchQuery
                            onTextChanged: root.searchQuery = text
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    Rectangle {
                        visible: searchInput.text.length > 0
                        width: 20 * Theme.scale
                        height: 20 * Theme.scale
                        radius: 2
                        color: Theme.mcStoneDark

                        Text {
                            anchors.centerIn: parent
                            text: "X"
                            font.pixelSize: 10 * Theme.scale
                            color: Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                                searchInput.text = ""
                            }
                        }
                    }
                }
            }

            // Sort / Filter Button
            ShulkButton {
                text: qsTr("Sort & Filter")
                variant: "secondary"
                isFocused: (root.activeSection === 1 && root.toolbarIndex === 1)
                onClicked: {
                    root.openSortRequested()
                }
            }

            // New Profile Button
            ShulkButton {
                text: qsTr("New Profile")
                variant: "play"
                isFocused: (root.activeSection === 1 && root.toolbarIndex === 2)
                onClicked: {
                    root.createProfileRequested()
                }
            }
        }

        // Profile Grid or Empty State
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty State
            ShulkEmptyState {
                anchors.centerIn: parent
                visible: filteredProfiles.count === 0
                iconSource: "qrc:/shulk/icons/grass_block.png"
                title: qsTr("No Profiles Found")
                description: searchInput.text.length > 0 ? qsTr("No profiles match \"%1\".").arg(searchInput.text) : qsTr("Create your first Minecraft profile to start playing.")
                actionText: searchInput.text.length > 0 ? qsTr("Clear Search") : qsTr("Create Profile")
                onActionClicked: {
                    if (searchInput.text.length > 0) {
                        searchInput.text = ""
                    } else {
                        root.createProfileRequested()
                    }
                }
            }

            // Grid of Profiles
            GridView {
                id: profileGrid
                anchors.fill: parent
                visible: filteredProfiles.count > 0
                cellWidth: width / root.gridColumns
                cellHeight: 288 * Theme.scale
                clip: true
                boundsBehavior: Flickable.DragOverBounds
                model: filteredProfiles
                currentIndex: root.gridIndex

                delegate: Item {
                    width: profileGrid.cellWidth
                    height: profileGrid.cellHeight

                    ShulkCard {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(276 * Theme.scale, parent.width - Theme.space12)
                        height: parent.height - Theme.space12

                        cardTitle: model.name
                        iconKey: model.iconKey
                        iconUrl: model.iconUrl
                        bannerUrl: model.bannerUrl
                        description: model.description
                        minecraftVersion: model.minecraftVersion
                        loaderType: model.loaderType
                        loaderVersion: model.loaderVersion
                        lastPlayed: model.lastPlayed
                        playTime: model.playTime
                        modCount: model.modCount
                        isRunning: model.isRunning
                        isSelected: (root.gridIndex === index)

                        onCardClicked: {
                            root.gridIndex = index
                            var p = filteredProfiles.get(index)
                            root.openProfile(p)
                        }

                        onOptionsRequested: {
                            root.gridIndex = index
                            var p = filteredProfiles.get(index)
                            root.openOptionsRequested(p)
                        }

                        onCardDoubleClicked: {
                            root.gridIndex = index
                            var p = filteredProfiles.get(index)
                            root.openOptionsRequested(p)
                        }
                    }
                }
            }
        }
    }

    function triggerSearchFocus() {
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
        root.activeSection = 1
        root.toolbarIndex = 0
        searchInput.forceActiveFocus()
        if (typeof shulkInput !== "undefined") {
            shulkInput.openVirtualKeyboard()
        }
    }

    function handleAction(action) {
        var cols = root.gridColumns
        var count = filteredProfiles.count

        // -------------------------------------------------------------
        // SECTION 1: TOP TOOLBAR NAVIGATION
        // -------------------------------------------------------------
        if (root.activeSection === 1) {
            if (action === 2) { // ActionNavigateDown -> Return to Grid
                root.activeSection = 0
                searchInput.focus = false
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else if (action === 3) { // ActionNavigateLeft
                if (root.toolbarIndex > 0) {
                    root.toolbarIndex--
                    if (root.toolbarIndex === 0) searchInput.forceActiveFocus()
                    else searchInput.focus = false
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (action === 4) { // ActionNavigateRight
                if (root.toolbarIndex < 2) {
                    root.toolbarIndex++
                    searchInput.focus = false
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (action === 5) { // ActionAccept (A)
                if (root.toolbarIndex === 0) {
                    triggerSearchFocus()
                } else if (root.toolbarIndex === 1) {
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    root.openSortRequested()
                } else if (root.toolbarIndex === 2) {
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    root.createProfileRequested()
                }
            } else if (action === 6) { // ActionBack (B)
                root.activeSection = 0
                searchInput.focus = false
            }
            return
        }

        // -------------------------------------------------------------
        // SECTION 0: GRID NAVIGATION
        // -------------------------------------------------------------
        if (action === 1) { // ActionNavigateUp
            if (root.gridIndex >= cols) {
                root.gridIndex -= cols
                profileGrid.positionViewAtIndex(root.gridIndex, GridView.Beginning)
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else {
                // Navigate into Top Toolbar!
                root.activeSection = 1
                root.toolbarIndex = 0
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 2) { // ActionNavigateDown
            if (root.gridIndex + cols < count) {
                root.gridIndex += cols
                profileGrid.positionViewAtIndex(root.gridIndex, GridView.Beginning)
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 3) { // ActionNavigateLeft
            if (root.gridIndex > 0) {
                root.gridIndex--
                profileGrid.positionViewAtIndex(root.gridIndex, GridView.Beginning)
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 4) { // ActionNavigateRight
            if (root.gridIndex < count - 1) {
                root.gridIndex++
                profileGrid.positionViewAtIndex(root.gridIndex, GridView.Beginning)
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 5) { // ActionAccept (A)
            if (typeof shulkSound !== "undefined") shulkSound.playClick()
            if (count > 0 && root.gridIndex < count) {
                var p = filteredProfiles.get(root.gridIndex)
                root.openProfile(p)
            } else {
                root.createProfileRequested()
            }
        } else if (action === 8 || action === 10) { // ActionSecondary / ActionSearch (Y)
            triggerSearchFocus()
        } else if (action === 9) { // ActionMenu (Start)
            if (typeof shulkSound !== "undefined") shulkSound.playClick()
            if (count > 0 && root.gridIndex < count) {
                var p3 = filteredProfiles.get(root.gridIndex)
                root.openOptionsRequested(p3)
            }
        } else if (action === 13) { // ActionFilter
            if (typeof shulkSound !== "undefined") shulkSound.playClick()
            root.openSortRequested()
        }
    }
}

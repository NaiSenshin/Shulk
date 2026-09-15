import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

FocusScope {
    id: root

    property var profile: null
    property string contentType: "mods"
    property var results: []
    property int activeSection: 0 // 0 = Toolbar (Back, Search Field, Clear, Search Button), 1 = Results Grid
    property int toolbarIndex: 1  // 0 = Back, 1 = Search Field, 2 = Clear (X) / Search Button, 3 = Search Button
    property int selectedIndex: 0
    property string errorMessage: ""
    property string installedMessage: ""
    property string installingProjectId: ""

    signal backRequested()
    signal contentInstalled()

    readonly property string singularName: contentType === "mods" ? qsTr("Mod")
                                                 : contentType === "resourcepacks" ? qsTr("Resource Pack")
                                                 : qsTr("Shader Pack")
    readonly property string pluralName: contentType === "mods" ? qsTr("Mods")
                                               : contentType === "resourcepacks" ? qsTr("Resource Packs")
                                               : qsTr("Shader Packs")
    readonly property string contentIcon: contentType === "mods" ? "qrc:/shulk/icons/redstone.png"
                                               : contentType === "resourcepacks" ? "qrc:/shulk/icons/grass_block.png"
                                               : "qrc:/shulk/icons/spyglass.png"
    readonly property int gridColumns: width >= 1120 * Theme.scale ? 3 : 2

    function runSearch() {
        errorMessage = ""
        installedMessage = ""
        selectedIndex = 0
        shulkCreation.searchContent(contentType, searchField.text,
                                    profile ? profile.minecraftVersion : "",
                                    profile ? profile.loaderType : "")
    }

    function triggerSearchFocus() {
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
        root.activeSection = 0
        root.toolbarIndex = 1
        searchField.forceActiveFocus()
        searchField.selectAll()
        if (typeof shulkInput !== "undefined") {
            shulkInput.openVirtualKeyboard()
        }
    }

    function installSelected() {
        if (!profile || selectedIndex < 0 || selectedIndex >= results.length || shulkCreation.isContentInstalling)
            return
        var item = results[selectedIndex]
        installingProjectId = item.id
        errorMessage = ""
        installedMessage = ""
        shulkCreation.installContent(profile.id, contentType, item.id, item.name,
                                     profile.minecraftVersion, profile.loaderType)
    }

    function handleAction(action) {
        // (Y) - Direct Search Focus from anywhere
        if (action === 8 || action === 10) {
            triggerSearchFocus()
            return
        }

        // SECTION 0: TOP TOOLBAR
        if (root.activeSection === 0) {
            var hasClearBtn = searchField.text.length > 0
            var maxToolbar = hasClearBtn ? 3 : 2 // 0=Back, 1=Search, 2=(X if present else SearchBtn), 3=(SearchBtn if X)

            if (action === 1) { // ActionNavigateUp
                // Already at the top
            } else if (action === 2) { // ActionNavigateDown -> Results Grid
                if (searchField.activeFocus) {
                    searchField.focus = false
                }
                if (root.results.length > 0) {
                    root.activeSection = 1
                    if (root.selectedIndex < 0) root.selectedIndex = 0
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (action === 3) { // ActionNavigateLeft
                if (root.toolbarIndex > 0) {
                    root.toolbarIndex--
                    if (root.toolbarIndex === 1) {
                        searchField.forceActiveFocus()
                    } else {
                        searchField.focus = false
                    }
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (action === 4) { // ActionNavigateRight
                if (root.toolbarIndex < maxToolbar) {
                    root.toolbarIndex++
                    if (root.toolbarIndex === 1) {
                        searchField.forceActiveFocus()
                    } else {
                        searchField.focus = false
                    }
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
            } else if (action === 5) { // ActionAccept (A)
                var clearIdx = hasClearBtn ? 2 : -1
                var searchBtnIdx = hasClearBtn ? 3 : 2

                if (root.toolbarIndex === 0) {
                    if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
                    root.backRequested()
                } else if (root.toolbarIndex === 1) {
                    triggerSearchFocus()
                } else if (root.toolbarIndex === clearIdx) {
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    searchField.text = ""
                    searchField.forceActiveFocus()
                } else if (root.toolbarIndex === searchBtnIdx) {
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                    searchField.focus = false
                    root.runSearch()
                    if (root.results.length > 0) {
                        root.activeSection = 1
                        root.selectedIndex = 0
                    }
                }
            } else if (action === 6) { // ActionBack (B)
                if (searchField.activeFocus) {
                    searchField.focus = false
                    if (root.results.length > 0) root.activeSection = 1
                } else {
                    if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
                    root.backRequested()
                }
            }
            return
        }

        // SECTION 1: RESULTS GRID
        if (action === 1) { // ActionNavigateUp
            if (root.selectedIndex >= gridColumns) {
                root.selectedIndex -= gridColumns
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            } else {
                // Navigate into Top Search Bar!
                root.activeSection = 0
                root.toolbarIndex = 1
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 2) { // ActionNavigateDown
            if (root.selectedIndex + gridColumns < results.length) {
                root.selectedIndex += gridColumns
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 3) { // ActionNavigateLeft
            if (root.selectedIndex > 0) {
                root.selectedIndex--
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 4) { // ActionNavigateRight
            if (root.selectedIndex + 1 < results.length) {
                root.selectedIndex++
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
            }
        } else if (action === 5) { // ActionAccept (A)
            installSelected()
        } else if (action === 6) { // ActionBack (B)
            if (typeof shulkSound !== "undefined") shulkSound.playDismiss()
            root.backRequested()
        }

        if (results.length > 0 && root.selectedIndex >= 0)
            resultsGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    }

    onVisibleChanged: {
        if (visible) {
            root.activeSection = 0
            root.toolbarIndex = 1
            searchField.text = ""
            results = []
            runSearch()
        }
    }

    Connections {
        target: shulkCreation

        function onContentSearchFinished(type, foundResults) {
            if (type !== root.contentType) return
            root.results = foundResults
            if (foundResults.length > 0) {
                root.selectedIndex = 0
                if (root.activeSection !== 0) root.activeSection = 1
            } else {
                root.selectedIndex = -1
            }
        }

        function onContentSearchFailed(type, error) {
            if (type !== root.contentType) return
            root.results = []
            root.errorMessage = error
        }

        function onContentInstallFinished(type, displayName) {
            if (type !== root.contentType) return
            root.installingProjectId = ""
            root.installedMessage = qsTr("%1 was added to %2.").arg(displayName).arg(root.profile ? root.profile.name : qsTr("this profile"))
            root.contentInstalled()
        }

        function onContentInstallFailed(type, error) {
            if (type !== root.contentType) return
            root.installingProjectId = ""
            root.errorMessage = error
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space24
        spacing: Theme.space16

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            ShulkButton {
                text: qsTr("Back (B)")
                variant: "secondary"
                isFocused: root.activeSection === 0 && root.toolbarIndex === 0
                onClicked: {
                    root.activeSection = 0
                    root.toolbarIndex = 0
                    root.backRequested()
                }
            }

            Image {
                Layout.preferredWidth: 34 * Theme.scale
                Layout.preferredHeight: 34 * Theme.scale
                source: root.contentIcon
                fillMode: Image.PreserveAspectFit
                smooth: false
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                ShulkText {
                    text: qsTr("Add %1").arg(root.pluralName)
                    font.pixelSize: Theme.sizeTitle
                    font.bold: true
                    color: Theme.textPrimary
                }
                Item {
                    implicitWidth: subCompatText.implicitWidth
                    implicitHeight: subCompatText.implicitHeight
                    readonly property int off: Theme.getShadowOffset(subCompatText.font.pixelSize)

                    Text {
                        x: parent.off; y: parent.off
                        text: subCompatText.text
                        font: subCompatText.font
                        color: Theme.getShadowColor(subCompatText.color)
                    }
                    Text {
                        id: subCompatText
                        x: 0; y: 0
                        text: qsTr("Compatible with Minecraft %1 | %2").arg(root.profile ? root.profile.minecraftVersion : "").arg(root.profile ? root.profile.loaderType : "")
                        font.pixelSize: Theme.sizeCaption
                        color: Theme.textSecondary
                    }
                }
            }
        }

        // Minecraft-styled Search Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space8

            BorderImage {
                id: searchBox
                Layout.fillWidth: true
                Layout.preferredHeight: 46 * Theme.scale
                source: ((root.activeSection === 0 && root.toolbarIndex === 1) || searchField.activeFocus)
                        ? "qrc:/shulk/assets/mc/gui/text_field_highlighted.png"
                        : "qrc:/shulk/assets/mc/gui/text_field.png"
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
                    visible: (root.activeSection === 0 && root.toolbarIndex === 1)
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
                            text: qsTr("Search Modrinth for %1... (Press Y)").arg(root.pluralName.toLowerCase())
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textMuted
                            visible: searchField.text.length === 0 && !searchField.activeFocus
                        }

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textPrimary
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter
                            onAccepted: {
                                searchField.focus = false
                                root.runSearch()
                                if (root.results.length > 0) {
                                    root.activeSection = 1
                                    root.selectedIndex = 0
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: searchField.text.length > 0
                        width: 22 * Theme.scale
                        height: 22 * Theme.scale
                        radius: 2
                        color: (root.activeSection === 0 && root.toolbarIndex === 2) ? "#3A4560" : Theme.mcStoneDark
                        border.color: (root.activeSection === 0 && root.toolbarIndex === 2) ? Theme.mcDiamond : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "X"
                            font.family: Theme.fontDisplay
                            font.pixelSize: 11 * Theme.scale
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                                searchField.text = ""
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.IBeamCursor
                    onClicked: root.triggerSearchFocus()
                }
            }

            ShulkButton {
                id: searchBtn
                text: qsTr("Search")
                variant: "play"
                implicitHeight: 46 * Theme.scale
                isFocused: (root.activeSection === 0 && ((searchField.text.length > 0 && root.toolbarIndex === 3) || (searchField.text.length === 0 && root.toolbarIndex === 2)))
                onClicked: {
                    root.activeSection = 0
                    root.toolbarIndex = (searchField.text.length > 0) ? 3 : 2
                    searchField.focus = false
                    root.runSearch()
                    if (root.results.length > 0) {
                        root.activeSection = 1
                        root.selectedIndex = 0
                    }
                }
            }
        }

        Rectangle {
            visible: root.errorMessage.length > 0 || root.installedMessage.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 42 * Theme.scale
            radius: 3
            color: root.errorMessage.length > 0 ? "#4A1F1F" : "#203D22"
            border.color: root.errorMessage.length > 0 ? Theme.accentDanger : Theme.accentPlay
            Item {
                anchors.centerIn: parent
                implicitWidth: statusMsgText.implicitWidth
                implicitHeight: statusMsgText.implicitHeight
                readonly property int off: Theme.getShadowOffset(statusMsgText.font.pixelSize)

                Text {
                    x: parent.off; y: parent.off
                    text: statusMsgText.text
                    font: statusMsgText.font
                    color: Theme.getShadowColor(statusMsgText.color)
                }
                Text {
                    id: statusMsgText
                    x: 0; y: 0
                    text: root.errorMessage.length > 0 ? root.errorMessage : root.installedMessage
                    color: Theme.textPrimary
                    font.pixelSize: Theme.sizeCaption
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ShulkLoadingState {
                anchors.centerIn: parent
                visible: shulkCreation.isContentSearching
                message: qsTr("Searching %1...").arg(root.pluralName)
            }

            ShulkEmptyState {
                anchors.centerIn: parent
                visible: !shulkCreation.isContentSearching && root.results.length === 0
                iconSource: "qrc:/shulk/icons/spyglass.png"
                title: root.errorMessage.length > 0 ? qsTr("Search Failed") : qsTr("No Results")
                description: root.errorMessage.length > 0 ? root.errorMessage : qsTr("Try a different search for this Minecraft version.")
                actionText: qsTr("Search Again")
                onActionClicked: root.triggerSearchFocus()
            }

            GridView {
                id: resultsGrid
                anchors.fill: parent
                visible: !shulkCreation.isContentSearching && root.results.length > 0
                clip: true
                model: root.results
                cellWidth: width / root.gridColumns
                cellHeight: 150 * Theme.scale
                currentIndex: root.selectedIndex

                delegate: Item {
                    width: resultsGrid.cellWidth
                    height: resultsGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.space6
                        radius: Theme.radiusMd
                        color: cardMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
                        border.width: ((root.activeSection === 1 && root.selectedIndex === index) || cardMouse.containsMouse) ? 2 : 1
                        border.color: (root.activeSection === 1 && root.selectedIndex === index) ? Theme.mcDiamond : (cardMouse.containsMouse ? Theme.borderFocused : Theme.borderSubtle)

                        RowLayout {
                            z: 2
                            anchors.fill: parent
                            anchors.margins: Theme.space12
                            spacing: Theme.space12

                            BorderImage {
                                Layout.preferredWidth: 58 * Theme.scale
                                Layout.preferredHeight: 58 * Theme.scale
                                Layout.alignment: Qt.AlignTop
                                source: "qrc:/shulk/assets/mc/gui/slot.png"
                                border { left: 4; top: 4; right: 4; bottom: 4 }
                                smooth: false

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    source: modelData.iconUrl && modelData.iconUrl.length > 0 ? modelData.iconUrl : root.contentIcon
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Theme.space4

                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: cardTitleText.implicitHeight
                                    readonly property int off: Theme.getShadowOffset(cardTitleText.font.pixelSize)

                                    Text {
                                        x: parent.off; y: parent.off
                                        width: parent.width
                                        text: cardTitleText.text
                                        font: cardTitleText.font
                                        color: Theme.getShadowColor(cardTitleText.color)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        id: cardTitleText
                                        x: 0; y: 0
                                        width: parent.width
                                        text: modelData.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.sizeBody
                                        font.bold: true
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: cardAuthorText.implicitHeight
                                    readonly property int off: Theme.getShadowOffset(cardAuthorText.font.pixelSize)

                                    Text {
                                        x: parent.off; y: parent.off
                                        width: parent.width
                                        text: cardAuthorText.text
                                        font: cardAuthorText.font
                                        color: Theme.getShadowColor(cardAuthorText.color)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        id: cardAuthorText
                                        x: 0; y: 0
                                        width: parent.width
                                        text: qsTr("By %1 | %2 downloads").arg(modelData.author).arg(modelData.downloads)
                                        font.pixelSize: Theme.sizeSmall
                                        color: Theme.textGold
                                        elide: Text.ElideRight
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    readonly property int off: Theme.getShadowOffset(cardDescText.font.pixelSize)

                                    Text {
                                        x: parent.off; y: parent.off
                                        width: parent.width
                                        text: cardDescText.text
                                        font: cardDescText.font
                                        color: Theme.getShadowColor(cardDescText.color)
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                    }
                                    Text {
                                        id: cardDescText
                                        x: 0; y: 0
                                        width: parent.width
                                        text: modelData.description
                                        font.pixelSize: Theme.sizeCaption
                                        color: Theme.textSecondary
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                    }
                                }
                                ShulkButton {
                                    Layout.alignment: Qt.AlignRight
                                    text: root.installingProjectId === modelData.id ? qsTr("Adding...") : qsTr("+ Add")
                                    variant: "play"
                                    enabled: !shulkCreation.isContentInstalling
                                    implicitHeight: 32 * Theme.scale
                                    onClicked: {
                                        root.activeSection = 1
                                        root.selectedIndex = index
                                        root.installSelected()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            z: 1
                            onClicked: {
                                root.activeSection = 1
                                root.selectedIndex = index
                            }
                            onDoubleClicked: {
                                root.activeSection = 1
                                root.selectedIndex = index
                                root.installSelected()
                            }
                        }
                    }
                }
            }
        }
    }
}


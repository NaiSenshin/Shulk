// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"
import "../components"

ShulkDialog {
    id: root

    dialogTitle: root.showVersionBrowser ? qsTr("Choose a game version") : qsTr("Create a profile")
    preferredWidth: 760 * Theme.scale
    preferredHeight: 610 * Theme.scale
    closeOnBackdropClick: !shulkCreation.isCreating

    property int versionCategory: 0
    property string selectedVersion: ""
    property int selectedLoaderIdx: 0
    property bool showVersionBrowser: false
    property string versionSearchQuery: ""
    property int browserIndex: 0
    property int focusRow: 0 // name, version, loader, actions
    property int buttonIdx: 2
    property bool nameWasEdited: false
    property string errorMessage: ""

    readonly property var versions: shulkCreation.releaseVersions
    readonly property var loaders: shulkCreation.getCompatibleLoaders(selectedVersion)
    readonly property var currentVersionsList: {
        if (versionCategory === 1) return shulkCreation.snapshotVersions
        if (versionCategory === 2) return shulkCreation.betaVersions
        if (versionCategory === 3) return shulkCreation.alphaVersions
        return shulkCreation.releaseVersions
    }
    readonly property var filteredVersions: {
        var source = currentVersionsList
        var query = versionSearchQuery.trim().toLowerCase()
        if (!query.length) return source
        var result = []
        for (var i = 0; i < source.length; ++i) {
            if (source[i].toLowerCase().indexOf(query) !== -1) result.push(source[i])
        }
        return result
    }
    readonly property bool canCreate: nameInput.text.trim().length > 0
                                      && selectedVersion.length > 0
                                      && loaders.length > 0
                                      && !shulkCreation.isCreating

    Connections {
        target: shulkCreation

        function onProfileCreated(instanceId) {
            if (!root.visible) return
            if (typeof shulkSound !== "undefined") shulkSound.playLevelUp()
            root.close()
        }

        function onProfileCreationFailed(error) {
            if (!root.visible) return
            root.errorMessage = error
            root.focusRow = 3
            root.buttonIdx = 2
            createBtn.forceActiveFocus()
        }

        function onVersionsLoaded() {
            root.ensureSelection()
        }
    }

    contentItem: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.space16
            visible: !root.showVersionBrowser

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72 * Theme.scale
                radius: Theme.radiusMd
                color: Theme.bgSurfaceRaised
                border.color: Theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space12
                    spacing: Theme.space12

                    Rectangle {
                        Layout.preferredWidth: 46 * Theme.scale
                        Layout.preferredHeight: 46 * Theme.scale
                        color: Theme.bgDeep
                        border.color: Theme.borderSubtle
                        border.width: 1
                        Image {
                            anchors.fill: parent
                            anchors.margins: Theme.space6
                            source: "qrc:/shulk/icons/grass_block.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: qsTr("Minecraft: Java Edition")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Choose a version and mod loader. You can add mods and adjust Java settings later.")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeCaption
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space6

                Text {
                    text: qsTr("PROFILE NAME")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeSmall
                    font.letterSpacing: 1.2 * Theme.scale
                    font.weight: Font.Bold
                    color: root.focusRow === 0 ? Theme.textPrimary : Theme.textMuted
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48 * Theme.scale
                    radius: Theme.radiusSm
                    color: Theme.bgDeep
                    border.color: root.focusRow === 0 || nameInput.activeFocus ? Theme.borderFocused : Theme.borderSubtle
                    border.width: root.focusRow === 0 || nameInput.activeFocus ? 2 : 1

                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space12
                        anchors.rightMargin: Theme.space12
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeBody
                        color: Theme.textPrimary
                        selectionColor: Theme.accentPlay
                        selectedTextColor: Theme.textPrimary
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        maximumLength: 80
                        onTextEdited: {
                            root.nameWasEdited = true
                            root.errorMessage = ""
                        }
                        Keys.onReturnPressed: root.focusRow = 1
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space6

                Text {
                    text: qsTr("GAME VERSION")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeSmall
                    font.letterSpacing: 1.2 * Theme.scale
                    font.weight: Font.Bold
                    color: root.focusRow === 1 ? Theme.textPrimary : Theme.textMuted
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58 * Theme.scale
                    radius: Theme.radiusSm
                    color: versionMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurfaceRaised
                    border.color: root.focusRow === 1 ? Theme.borderFocused : Theme.borderSubtle
                    border.width: root.focusRow === 1 ? 2 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space12
                        anchors.rightMargin: Theme.space12
                        spacing: Theme.space12

                        Image {
                            source: "qrc:/shulk/icons/grass_block.png"
                            Layout.preferredWidth: 30 * Theme.scale
                            Layout.preferredHeight: 30 * Theme.scale
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: root.selectedVersion.length ? qsTr("Minecraft %1").arg(root.selectedVersion) : qsTr("Loading versions...")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeBody
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Latest stable release selected by default")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeSmall
                                color: Theme.textMuted
                            }
                        }
                        Text {
                            text: qsTr("Browse versions")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeCaption
                            font.weight: Font.DemiBold
                            color: root.focusRow === 1 || versionMouse.containsMouse ? "#9BD38B" : Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: versionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openVersionBrowser()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("MOD LOADER")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        font.letterSpacing: 1.2 * Theme.scale
                        font.weight: Font.Bold
                        color: root.focusRow === 2 ? Theme.textPrimary : Theme.textMuted
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.loaders.length === 1 ? qsTr("Only Vanilla is supported for this version") : qsTr("Optional")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        color: Theme.textMuted
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space8

                    Repeater {
                        model: root.loaders
                        delegate: ShulkButton {
                            Layout.fillWidth: true
                            text: modelData
                            variant: root.selectedLoaderIdx === index ? "play" : "secondary"
                            isFocused: root.focusRow === 2 && root.selectedLoaderIdx === index
                            implicitHeight: 44 * Theme.scale
                            onClicked: {
                                root.selectedLoaderIdx = index
                                root.focusRow = 2
                                root.errorMessage = ""
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.errorMessage.length > 0 || shulkCreation.isCreating ? 38 * Theme.scale : 1
                color: root.errorMessage.length > 0 ? "#2A1716" : (shulkCreation.isCreating ? "#1D2B1A" : Theme.borderSubtle)
                border.color: root.errorMessage.length > 0 ? "#7D3833" : (shulkCreation.isCreating ? "#47683D" : "transparent")
                border.width: root.errorMessage.length > 0 || shulkCreation.isCreating ? 1 : 0

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space12
                    anchors.rightMargin: Theme.space12
                    text: root.errorMessage.length > 0 ? root.errorMessage : shulkCreation.creationStatus
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeCaption
                    color: root.errorMessage.length > 0 ? "#FFB4AE" : "#B7E3AA"
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space8

                Text {
                    Layout.fillWidth: true
                    text: qsTr("A  Select    B  Cancel    X  Import pack    Y  Keyboard")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeSmall
                    color: Theme.textMuted
                }

                ShulkButton {
                    id: cancelBtn
                    text: qsTr("Cancel")
                    shortcutHint: "B"
                    variant: "secondary"
                    enabled: !shulkCreation.isCreating
                    isFocused: root.focusRow === 3 && root.buttonIdx === 0
                    implicitWidth: 126 * Theme.scale
                    onClicked: root.close()
                }

                ShulkButton {
                    id: importBtn
                    text: qsTr("Import modpack")
                    shortcutHint: "X"
                    variant: "secondary"
                    enabled: !shulkCreation.isCreating
                    isFocused: root.focusRow === 3 && root.buttonIdx === 1
                    implicitWidth: 166 * Theme.scale
                    onClicked: {
                        root.errorMessage = ""
                        shulkCreation.importModpackFile()
                    }
                }

                ShulkButton {
                    id: createBtn
                    text: shulkCreation.isCreating ? qsTr("Creating...") : qsTr("Create profile")
                    shortcutHint: "A"
                    variant: "play"
                    enabled: root.canCreate
                    isFocused: root.focusRow === 3 && root.buttonIdx === 2
                    implicitWidth: 178 * Theme.scale
                    onClicked: root.submitProfile()
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.space12
            visible: root.showVersionBrowser

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Select the Minecraft version this profile will use.")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeCaption
                    color: Theme.textSecondary
                }
                ShulkButton {
                    text: qsTr("Back")
                    shortcutHint: "B"
                    variant: "secondary"
                    implicitHeight: 36 * Theme.scale
                    onClicked: root.showVersionBrowser = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44 * Theme.scale
                radius: Theme.radiusSm
                color: Theme.bgDeep
                border.color: browserSearch.activeFocus ? Theme.borderFocused : Theme.borderSubtle
                border.width: browserSearch.activeFocus ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space12
                    anchors.rightMargin: Theme.space12
                    spacing: Theme.space8
                    Image {
                        Layout.preferredWidth: 22 * Theme.scale
                        Layout.preferredHeight: 22 * Theme.scale
                        source: "qrc:/shulk/icons/spyglass.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }
                    TextInput {
                        id: browserSearch
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeBody
                        color: Theme.textPrimary
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: {
                            root.versionSearchQuery = text
                            root.browserIndex = 0
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Search versions")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            color: Theme.textMuted
                            visible: browserSearch.text.length === 0
                        }
                    }
                    Text {
                        text: qsTr("Y  Keyboard")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space6
                Repeater {
                    model: [
                        { label: qsTr("Releases"), value: 0 },
                        { label: qsTr("Snapshots"), value: 1 },
                        { label: qsTr("Betas"), value: 2 },
                        { label: qsTr("Alphas"), value: 3 }
                    ]
                    delegate: ShulkButton {
                        Layout.fillWidth: true
                        text: modelData.label
                        variant: root.versionCategory === modelData.value ? "play" : "secondary"
                        implicitHeight: 36 * Theme.scale
                        onClicked: root.selectCategory(modelData.value)
                    }
                }
            }

            GridView {
                id: versionGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width / 3
                cellHeight: 54 * Theme.scale
                model: root.filteredVersions
                currentIndex: root.browserIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    width: versionGrid.cellWidth
                    height: versionGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        radius: Theme.radiusSm
                        color: versionMouseArea.containsMouse || root.selectedVersion === modelData ? Theme.bgSurfaceHover : Theme.bgSurfaceRaised
                        border.color: root.browserIndex === index ? Theme.borderFocused : (root.selectedVersion === modelData ? Theme.accentPlay : Theme.borderSubtle)
                        border.width: root.browserIndex === index ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space12
                            anchors.rightMargin: Theme.space12
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeBody
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Image {
                                visible: root.selectedVersion === modelData
                                Layout.preferredWidth: 18 * Theme.scale
                                Layout.preferredHeight: 18 * Theme.scale
                                source: "qrc:/shulk/assets/mc/emerald.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                            }
                        }

                        MouseArea {
                            id: versionMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.chooseVersion(modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredVersions.length === 0
                    text: qsTr("No versions match your search.")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeBody
                    color: Theme.textMuted
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("D-pad  Navigate    A  Select    LB / RB  Change category    B  Back")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeSmall
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    function ensureSelection() {
        if ((!selectedVersion || versions.indexOf(selectedVersion) < 0) && versions.length > 0) {
            selectedVersion = versions[0]
        }
        if (selectedLoaderIdx >= loaders.length) selectedLoaderIdx = 0
    }

    function openVersionBrowser() {
        showVersionBrowser = true
        versionCategory = 0
        versionSearchQuery = ""
        browserSearch.text = ""
        browserIndex = Math.max(0, filteredVersions.indexOf(selectedVersion))
        versionGrid.positionViewAtIndex(browserIndex, GridView.Center)
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
    }

    function selectCategory(category) {
        versionCategory = category
        browserIndex = 0
        versionGrid.positionViewAtBeginning()
        if (typeof shulkSound !== "undefined") shulkSound.playTick()
    }

    function chooseVersion(version) {
        selectedVersion = version
        selectedLoaderIdx = 0
        if (!nameWasEdited) nameInput.text = "Minecraft " + version
        showVersionBrowser = false
        focusRow = 1
        errorMessage = ""
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
    }

    function submitProfile() {
        if (!canCreate) {
            errorMessage = qsTr("Enter a profile name and select a Minecraft version.")
            return
        }
        errorMessage = ""
        var loader = loaders[selectedLoaderIdx]
        shulkCreation.createProfile(nameInput.text.trim(), selectedVersion, loader)
    }

    function handleAction(action) {
        if (action === Theme.actionBack) {
            if (showVersionBrowser) showVersionBrowser = false
            else if (!shulkCreation.isCreating) close()
            return
        }

        if (showVersionBrowser) {
            var columns = 3
            if (action === Theme.actionPrevTab) selectCategory((versionCategory + 3) % 4)
            else if (action === Theme.actionNextTab) selectCategory((versionCategory + 1) % 4)
            else if (action === Theme.actionUp && browserIndex >= columns) browserIndex -= columns
            else if (action === Theme.actionDown) {
                if (browserIndex + columns < filteredVersions.length) browserIndex += columns
                else if (browserIndex < filteredVersions.length - 1) browserIndex = filteredVersions.length - 1
            }
            else if (action === Theme.actionLeft && browserIndex > 0) browserIndex--
            else if (action === Theme.actionRight && browserIndex < filteredVersions.length - 1) browserIndex++
            else if (action === Theme.actionAccept && filteredVersions.length > 0) chooseVersion(filteredVersions[browserIndex])
            else if (action === Theme.actionSecondary) {
                browserSearch.forceActiveFocus()
                if (typeof shulkInput !== "undefined") shulkInput.openVirtualKeyboard()
            }
            versionGrid.positionViewAtIndex(browserIndex, GridView.Contain)
            return
        }

        if (action === Theme.actionUp) focusRow = Math.max(0, focusRow - 1)
        else if (action === Theme.actionDown) focusRow = Math.min(3, focusRow + 1)
        else if (action === Theme.actionLeft) {
            if (focusRow === 2 && selectedLoaderIdx > 0) selectedLoaderIdx--
            else if (focusRow === 3 && buttonIdx > 0) buttonIdx--
        } else if (action === Theme.actionRight) {
            if (focusRow === 2 && selectedLoaderIdx < loaders.length - 1) selectedLoaderIdx++
            else if (focusRow === 3 && buttonIdx < 2) buttonIdx++
        } else if (action === Theme.actionAccept) {
            if (focusRow === 0) {
                nameInput.forceActiveFocus()
                if (typeof shulkInput !== "undefined") shulkInput.openVirtualKeyboard()
            } else if (focusRow === 1) openVersionBrowser()
            else if (focusRow === 2) {
                focusRow = 3
                buttonIdx = 2
                if (typeof shulkSound !== "undefined") shulkSound.playClick()
            }
            else if (focusRow === 3) {
                if (buttonIdx === 0) cancelBtn.triggerClick()
                else if (buttonIdx === 1) importBtn.triggerClick()
                else createBtn.triggerClick()
            }
        } else if (action === Theme.actionPrimary && !shulkCreation.isCreating) {
            importBtn.triggerClick()
        } else if (action === Theme.actionSecondary && focusRow === 0) {
            nameInput.forceActiveFocus()
            if (typeof shulkInput !== "undefined") shulkInput.openVirtualKeyboard()
        }
        if (typeof shulkSound !== "undefined" && (action === Theme.actionUp || action === Theme.actionDown || action === Theme.actionLeft || action === Theme.actionRight)) shulkSound.playTick()
    }

    onSelectedVersionChanged: {
        if (selectedLoaderIdx >= loaders.length) selectedLoaderIdx = 0
    }

    onOpacityChanged: {
        if (opacity === 1) {
            ensureSelection()
            showVersionBrowser = false
            versionSearchQuery = ""
            browserIndex = 0
            focusRow = 0
            buttonIdx = 2
            nameWasEdited = false
            errorMessage = ""
            nameInput.text = selectedVersion.length ? "Minecraft " + selectedVersion : qsTr("New profile")
            nameInput.forceActiveFocus()
            nameInput.selectAll()
        }
    }
}

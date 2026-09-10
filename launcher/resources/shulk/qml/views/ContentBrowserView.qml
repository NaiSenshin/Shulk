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
        if (action === 1) {
            if (selectedIndex >= gridColumns) selectedIndex -= gridColumns
        } else if (action === 2) {
            if (selectedIndex + gridColumns < results.length) selectedIndex += gridColumns
        } else if (action === 3) {
            if (selectedIndex > 0) selectedIndex--
        } else if (action === 4) {
            if (selectedIndex + 1 < results.length) selectedIndex++
        } else if (action === 5) {
            installSelected()
        } else if (action === 6) {
            backRequested()
        } else if (action === 8) {
            searchField.forceActiveFocus()
            searchField.selectAll()
        }
        if (results.length > 0 && selectedIndex >= 0)
            resultsGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
    }

    onVisibleChanged: {
        if (visible) {
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
            root.selectedIndex = foundResults.length > 0 ? 0 : -1
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
                text: qsTr("Back")
                variant: "secondary"
                onClicked: root.backRequested()
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52 * Theme.scale
            radius: Theme.radiusMd
            color: Theme.bgCard
            border.color: searchField.activeFocus ? Theme.borderFocused : Theme.borderSubtle
            border.width: searchField.activeFocus ? 2 : 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.space8
                spacing: Theme.space8

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search Modrinth for %1...").arg(root.pluralName.toLowerCase())
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeBody
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textMuted
                    selectionColor: Theme.accentPlay
                    background: Item {}
                    onAccepted: root.runSearch()
                }

                ShulkButton {
                    text: qsTr("Search")
                    variant: "play"
                    onClicked: root.runSearch()
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
                onActionClicked: searchField.forceActiveFocus()
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
                        border.width: (root.selectedIndex === index || cardMouse.containsMouse) ? 2 : 1
                        border.color: (root.selectedIndex === index || cardMouse.containsMouse) ? Theme.borderFocused : Theme.borderSubtle

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
                            onClicked: root.selectedIndex = index
                            onDoubleClicked: {
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

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

ShulkDialog {
    id: root

    property var profile: null
    property bool renaming: false
    property int focusIndex: 0
    readonly property var optionButtons: [playBtn, folderBtn, duplicateBtn, renameBtn, deleteBtn]

    preferredWidth: 700 * Theme.scale
    preferredHeight: 440 * Theme.scale
    dialogTitle: renaming ? qsTr("Rename Profile") : qsTr("Profile Options")

    signal playRequested(string id)
    signal deleteRequested(string id)
    signal duplicateRequested(string id)
    signal renameRequested(string id, string newName)

    contentItem: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.space12
            visible: !root.renaming

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 104 * Theme.scale
                color: Theme.bgSurfaceRaised
                border.color: Theme.borderSubtle
                border.width: 1
                radius: Theme.radiusSm

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space12
                    spacing: Theme.space14

                    Rectangle {
                        Layout.preferredWidth: 76 * Theme.scale
                        Layout.preferredHeight: 76 * Theme.scale
                        color: Theme.bgDeep
                        border.color: Theme.borderStrong
                        border.width: 1

                        Image {
                            anchors.fill: parent
                            anchors.margins: Theme.space6
                            source: root.profile
                                    ? (root.profile.iconUrl
                                       ? root.profile.iconUrl
                                       : (root.profile.iconKey && root.profile.iconKey !== "grass" && root.profile.iconKey !== "default"
                                          ? "image://insticons/" + root.profile.iconKey
                                          : "qrc:/shulk/icons/grass_block_side.png"))
                                    : "qrc:/shulk/icons/grass_block_side.png"
                            fillMode: Image.PreserveAspectCrop
                            smooth: false
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space6

                        Text {
                            Layout.fillWidth: true
                            text: root.profile ? root.profile.name : ""
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeHeader
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.profile
                                  ? qsTr("Minecraft %1  |  %2")
                                        .arg(root.profile.minecraftVersion || qsTr("Unknown version"))
                                        .arg(root.profile.loaderType || qsTr("Vanilla"))
                                  : ""
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.profile && root.profile.modCount > 0
                                  ? qsTr("%1 mods installed").arg(root.profile.modCount)
                                  : qsTr("Ready to play")
                            color: root.profile && root.profile.modCount > 0 ? Theme.textGold : Theme.textGreen
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeCaption
                        }
                    }
                }
            }

            ShulkButton {
                id: playBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52 * Theme.scale
                text: root.profile && root.profile.isRunning ? qsTr("Profile Is Running") : qsTr("Play Profile")
                iconSource: "qrc:/shulk/assets/mc/diamond_sword.png"
                variant: "play"
                enabled: !(root.profile && root.profile.isRunning)
                onClicked: {
                    if (root.profile) root.playRequested(root.profile.id)
                    root.close()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space8

                ShulkButton {
                    id: folderBtn
                    Layout.fillWidth: true
                    text: qsTr("Open Folder")
                    iconSource: "qrc:/shulk/icons/chest.png"
                    isPrimary: false
                    onClicked: {
                        if (root.profile) shulkLauncher.openInstanceFolder(root.profile.id)
                        root.close()
                    }
                }

                ShulkButton {
                    id: duplicateBtn
                    Layout.fillWidth: true
                    text: qsTr("Duplicate")
                    iconSource: "qrc:/shulk/icons/bookshelf.png"
                    isPrimary: false
                    onClicked: {
                        if (root.profile) root.duplicateRequested(root.profile.id)
                        root.close()
                    }
                }

                ShulkButton {
                    id: renameBtn
                    Layout.fillWidth: true
                    text: qsTr("Rename")
                    iconSource: "qrc:/shulk/icons/book.png"
                    isPrimary: false
                    onClicked: root.beginRename()
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 68 * Theme.scale
                color: "#241513"
                border.color: "#703630"
                border.width: 1
                radius: Theme.radiusSm

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space10
                    spacing: Theme.space10

                    Image {
                        Layout.preferredWidth: 30 * Theme.scale
                        Layout.preferredHeight: 30 * Theme.scale
                        source: "qrc:/shulk/icons/redstone.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space4

                        Text {
                            text: qsTr("Delete this profile")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeBody
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Removes the profile and its local files.")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeCaption
                            elide: Text.ElideRight
                        }
                    }

                    ShulkButton {
                        id: deleteBtn
                        Layout.preferredWidth: 150 * Theme.scale
                        text: qsTr("Delete Profile")
                        variant: "danger"
                        onClicked: {
                            if (root.profile) root.deleteRequested(root.profile.id)
                            root.close()
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.space16
            visible: root.renaming

            Item { Layout.fillHeight: true }

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 58 * Theme.scale
                Layout.preferredHeight: 58 * Theme.scale
                source: "qrc:/shulk/icons/book.png"
                fillMode: Image.PreserveAspectFit
                smooth: false
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Choose a new name for this profile")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeBody
            }

            TextField {
                id: renameField
                Layout.fillWidth: true
                Layout.preferredHeight: 48 * Theme.scale
                selectByMouse: true
                color: Theme.textPrimary
                selectionColor: Theme.accentShulk
                selectedTextColor: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeBody
                placeholderText: qsTr("Profile name")
                background: Rectangle {
                    color: Theme.bgDeep
                    border.color: renameField.activeFocus ? Theme.borderFocused : Theme.borderStrong
                    border.width: renameField.activeFocus ? 2 : 1
                    radius: Theme.radiusSm
                }
                leftPadding: Theme.space12
                rightPadding: Theme.space12
                onAccepted: root.commitRename()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space8

                ShulkButton {
                    id: renameCancelBtn
                    Layout.fillWidth: true
                    text: qsTr("Cancel")
                    isPrimary: false
                    onClicked: root.cancelRename()
                }

                ShulkButton {
                    id: renameSaveBtn
                    Layout.fillWidth: true
                    text: qsTr("Save Name")
                    enabled: renameField.text.trim().length > 0
                    onClicked: root.commitRename()
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    property int renameFocusIndex: 0
    readonly property var renameButtons: [renameField, renameCancelBtn, renameSaveBtn]

    function beginRename() {
        renaming = true
        renameFocusIndex = 0
        renameField.text = profile ? profile.name : ""
        renameField.forceActiveFocus()
        renameField.selectAll()
        if (typeof shulkInput !== "undefined") shulkInput.openVirtualKeyboard()
    }

    function cancelRename() {
        renaming = false
        focusIndex = 3
        renameBtn.forceActiveFocus()
    }

    function commitRename() {
        var newName = renameField.text.trim()
        if (!profile || newName.length === 0) return
        if (newName !== profile.name) renameRequested(profile.id, newName)
        renaming = false
        close()
    }

    function handleAction(action) {
        if (renaming) {
            if (action === Theme.actionBack) {
                cancelRename()
                return
            }
            if (action === Theme.actionUp) {
                renameFocusIndex = 0
                renameField.forceActiveFocus()
                if (typeof shulkSound !== "undefined") shulkSound.playTick()
            } else if (action === Theme.actionDown) {
                if (renameFocusIndex === 0) {
                    renameFocusIndex = 1
                    renameCancelBtn.forceActiveFocus()
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                }
            } else if (action === Theme.actionLeft) {
                if (renameFocusIndex === 2) {
                    renameFocusIndex = 1
                    renameCancelBtn.forceActiveFocus()
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                }
            } else if (action === Theme.actionRight) {
                if (renameFocusIndex === 1) {
                    renameFocusIndex = 2
                    renameSaveBtn.forceActiveFocus()
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                }
            } else if (action === Theme.actionAccept) {
                if (renameFocusIndex === 1) renameCancelBtn.triggerClick()
                else if (renameFocusIndex === 2 || renameFocusIndex === 0) commitRename()
            }
            return
        }

        if (action === Theme.actionBack) {
            close()
            return
        }

        var newIndex = focusIndex
        if (action === Theme.actionUp) {
            if (focusIndex === 4) { // deleteBtn -> middle row (keep same horizontal column duplicateBtn)
                newIndex = 2
            } else if (focusIndex >= 1 && focusIndex <= 3) { // middle row -> playBtn
                newIndex = 0
            }
        } else if (action === Theme.actionDown) {
            if (focusIndex === 0) { // playBtn -> folderBtn
                newIndex = 1
            } else if (focusIndex >= 1 && focusIndex <= 3) { // middle row -> deleteBtn
                newIndex = 4
            }
        } else if (action === Theme.actionLeft) {
            if (focusIndex === 2) newIndex = 1
            else if (focusIndex === 3) newIndex = 2
        } else if (action === Theme.actionRight) {
            if (focusIndex === 1) newIndex = 2
            else if (focusIndex === 2) newIndex = 3
        } else if (action === Theme.actionAccept) {
            optionButtons[focusIndex].triggerClick()
            return
        }

        if (newIndex !== focusIndex) {
            focusIndex = newIndex
            optionButtons[focusIndex].forceActiveFocus()
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        }
    }

    onOpacityChanged: {
        if (opacity === 1) {
            renaming = false
            focusIndex = 0
            playBtn.forceActiveFocus()
        }
    }
}

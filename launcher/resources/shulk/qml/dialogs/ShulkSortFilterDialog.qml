import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

ShulkDialog {
    id: root

    property string currentSort: "recent"
    dialogTitle: qsTr("Sort & Filter Library")
    preferredHeight: 368 * Theme.scale

    signal sortSelected(string sortType)

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space8

        ShulkButton {
            id: recentBtn
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 38 * Theme.scale
            Layout.maximumHeight: 48 * Theme.scale
            text: qsTr("Recently Played")
            iconSource: root.currentSort === "recent" ? "qrc:/shulk/assets/mc/gui/checkbox_selected.png" : "qrc:/shulk/assets/mc/gui/checkbox.png"
            variant: root.currentSort === "recent" ? "play" : "secondary"
            onClicked: {
                root.sortSelected("recent")
                root.close()
            }
        }

        ShulkButton {
            id: nameBtn
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 38 * Theme.scale
            Layout.maximumHeight: 48 * Theme.scale
            text: qsTr("Profile Name (A-Z)")
            iconSource: root.currentSort === "name" ? "qrc:/shulk/assets/mc/gui/checkbox_selected.png" : "qrc:/shulk/assets/mc/gui/checkbox.png"
            variant: root.currentSort === "name" ? "play" : "secondary"
            onClicked: {
                root.sortSelected("name")
                root.close()
            }
        }

        ShulkButton {
            id: versionBtn
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 38 * Theme.scale
            Layout.maximumHeight: 48 * Theme.scale
            text: qsTr("Minecraft Version")
            iconSource: root.currentSort === "version" ? "qrc:/shulk/assets/mc/gui/checkbox_selected.png" : "qrc:/shulk/assets/mc/gui/checkbox.png"
            variant: root.currentSort === "version" ? "play" : "secondary"
            onClicked: {
                root.sortSelected("version")
                root.close()
            }
        }

        ShulkButton {
            id: loaderBtn
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 38 * Theme.scale
            Layout.maximumHeight: 48 * Theme.scale
            text: qsTr("Mod Loader")
            iconSource: root.currentSort === "loader" ? "qrc:/shulk/assets/mc/gui/checkbox_selected.png" : "qrc:/shulk/assets/mc/gui/checkbox.png"
            variant: root.currentSort === "loader" ? "play" : "secondary"
            onClicked: {
                root.sortSelected("loader")
                root.close()
            }
        }

        ShulkButton {
            id: playtimeBtn
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 38 * Theme.scale
            Layout.maximumHeight: 48 * Theme.scale
            text: qsTr("Total Playtime")
            iconSource: root.currentSort === "playtime" ? "qrc:/shulk/assets/mc/gui/checkbox_selected.png" : "qrc:/shulk/assets/mc/gui/checkbox.png"
            variant: root.currentSort === "playtime" ? "play" : "secondary"
            onClicked: {
                root.sortSelected("playtime")
                root.close()
            }
        }
    }

    property int focusIndex: 0
    readonly property var sortButtons: [recentBtn, nameBtn, versionBtn, loaderBtn, playtimeBtn]

    function handleAction(action) {
        if (action === Theme.actionBack) {
            root.close()
            return
        }
        if (action === Theme.actionUp) {
            if (focusIndex > 0) {
                focusIndex--
            } else {
                focusIndex = sortButtons.length - 1
            }
            sortButtons[focusIndex].forceActiveFocus()
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        } else if (action === Theme.actionDown) {
            if (focusIndex < sortButtons.length - 1) {
                focusIndex++
            } else {
                focusIndex = 0
            }
            sortButtons[focusIndex].forceActiveFocus()
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        } else if (action === Theme.actionAccept) {
            sortButtons[focusIndex].triggerClick()
        }
    }

    onOpacityChanged: {
        if (opacity === 1) {
            focusIndex = 0
            recentBtn.forceActiveFocus()
        }
    }
}

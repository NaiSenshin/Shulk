import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"
import "../components"

ShulkDialog {
    id: root

    property string errorTitle: qsTr("Launch Error")
    property string errorMessage: ""
    property string errorLog: ""
    property bool showLog: false

    dialogTitle: root.errorTitle

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space16

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            Image {
                Layout.preferredWidth: 32 * Theme.scale
                Layout.preferredHeight: 32 * Theme.scale
                source: "qrc:/shulk/icons/redstone.png"
                fillMode: Image.PreserveAspectFit
                smooth: false
            }

            Text {
                Layout.fillWidth: true
                text: root.errorMessage
                font.pixelSize: Theme.sizeBody
                color: Theme.textPrimary
                wrapMode: Text.WordWrap
            }
        }

        // Technical details expander
        Rectangle {
            visible: root.errorLog.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: root.showLog ? 140 * Theme.scale : 0
            radius: Theme.radiusMedium
            color: Theme.bgCard
            border.color: Theme.borderSubtle
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 150 }
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: Theme.space8

                TextArea {
                    text: root.errorLog
                    font.family: Theme.fontFamily
                    font.pixelSize: 11 * Theme.scale
                    color: Theme.textSecondary
                    readOnly: true
                    wrapMode: Text.WrapAnywhere
                    background: null
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space8
            spacing: Theme.space12

            ShulkButton {
                id: detailsBtn
                visible: root.errorLog.length > 0
                text: root.showLog ? qsTr("Hide Details") : qsTr("Show Details")
                onClicked: root.showLog = !root.showLog
            }

            ShulkButton {
                id: copyBtn
                visible: root.errorLog.length > 0
                text: qsTr("Copy Log")
                onClicked: {
                    shulkLauncher.copyToClipboard(root.errorMessage + "\n\n" + root.errorLog)
                }
            }

            ShulkButton {
                id: addAccountBtn
                visible: root.errorMessage.indexOf("account") !== -1 || root.errorMessage.indexOf("Account") !== -1
                text: qsTr("Add Account")
                variant: "play"
                onClicked: {
                    shulkLauncher.clearError()
                    root.close()
                    addAccountDialog.open()
                }
            }

            ShulkButton {
                id: okBtn
                text: qsTr("Dismiss")
                variant: "secondary"
                onClicked: {
                    shulkLauncher.clearError()
                    root.close()
                }
            }
        }
    }

    property int focusIndex: 0

    function getVisibleButtons() {
        var btns = []
        if (detailsBtn.visible) btns.push(detailsBtn)
        if (copyBtn.visible) btns.push(copyBtn)
        if (addAccountBtn.visible) btns.push(addAccountBtn)
        if (okBtn.visible) btns.push(okBtn)
        return btns
    }

    function handleAction(action) {
        if (action === Theme.actionBack) {
            shulkLauncher.clearError()
            root.close()
            return
        }

        var btns = getVisibleButtons()
        if (btns.length === 0) return

        if (action === Theme.actionLeft || action === Theme.actionUp) {
            focusIndex = Math.max(0, focusIndex - 1)
            btns[focusIndex].forceActiveFocus()
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        } else if (action === Theme.actionRight || action === Theme.actionDown) {
            focusIndex = Math.min(btns.length - 1, focusIndex + 1)
            btns[focusIndex].forceActiveFocus()
            if (typeof shulkSound !== "undefined") shulkSound.playTick()
        } else if (action === Theme.actionAccept) {
            if (focusIndex >= 0 && focusIndex < btns.length) {
                btns[focusIndex].triggerClick()
            }
        }
    }

    onOpacityChanged: {
        if (opacity === 1) {
            var btns = getVisibleButtons()
            if (btns.length > 0) {
                focusIndex = addAccountBtn.visible ? btns.indexOf(addAccountBtn) : (btns.length - 1)
                btns[focusIndex].forceActiveFocus()
            }
        }
    }
}

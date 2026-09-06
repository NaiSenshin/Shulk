import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

FocusScope {
    id: root

    property string cardTitle: ""
    property string iconKey: ""
    property string iconUrl: ""
    property string bannerUrl: ""
    property string description: ""
    property string minecraftVersion: ""
    property string loaderType: ""
    property string loaderVersion: ""
    property string playTime: ""
    property string lastPlayed: ""
    property int modCount: 0
    property bool isRunning: false
    property bool isSelected: false

    signal activated()
    signal optionsRequested()
    signal cardClicked()
    signal cardDoubleClicked()

    implicitWidth: 276 * Theme.scale
    implicitHeight: 280 * Theme.scale
    activeFocusOnTab: true

    readonly property bool highlighted: activeFocus || isSelected || mouseArea.containsMouse

    function triggerActivated() {
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
        activated()
        cardClicked()
    }
    function triggerOptions() {
        if (typeof shulkSound !== "undefined") shulkSound.playClick()
        optionsRequested()
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            triggerActivated(); event.accepted = true
        } else if (event.key === Qt.Key_M || event.key === Qt.Key_Menu) {
            triggerOptions(); event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: highlighted ? Theme.bgSurfaceHover : Theme.bgSurfaceRaised
        clip: true
        scale: root.highlighted ? 1.012 : 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 108 * Theme.scale
            clip: true

            Image {
                anchors.fill: parent
                source: root.bannerUrl ? root.bannerUrl : "qrc:/shulk/assets/default_pack_banner.jpg"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#10000000" }
                    GradientStop { position: 1; color: "#D8171819" }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space12
                width: 54 * Theme.scale
                height: 54 * Theme.scale
                color: "#E8171819"
                border.color: "#70FFFFFF"
                border.width: 1

                Image {
                    anchors.fill: parent
                    anchors.margins: Theme.space6
                    source: root.iconUrl
                            ? root.iconUrl
                            : (root.iconKey && root.iconKey !== "grass" && root.iconKey !== "default"
                               ? ("image://insticons/" + root.iconKey)
                               : "qrc:/shulk/icons/grass_block_side.png")
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                }
            }

            Rectangle {
                visible: root.isRunning
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.space8
                width: runningLabel.implicitWidth + Theme.space12
                height: 24 * Theme.scale
                radius: Theme.radiusSm
                color: Theme.accentPlay
                Text {
                    id: runningLabel
                    anchors.centerIn: parent
                    text: qsTr("RUNNING")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeSmall
                    font.bold: true
                    color: Theme.textPrimary
                }
            }
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.space12
            anchors.rightMargin: Theme.space12
            anchors.bottomMargin: Theme.space12
            anchors.topMargin: 116 * Theme.scale
            spacing: Theme.space8

            Text {
                Layout.fillWidth: true
                text: root.cardTitle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeHeader + Math.round(1 * Theme.scale)
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Row {
                spacing: Theme.space6
                ShulkBadge { text: root.minecraftVersion.length ? qsTr("Minecraft %1").arg(root.minecraftVersion) : qsTr("Minecraft"); isAccent: true }
                ShulkBadge { visible: root.loaderType !== "" && root.loaderType !== "Vanilla"; text: root.loaderType }
                ShulkBadge { visible: root.modCount > 0; text: qsTr("%1 mods").arg(root.modCount) }
            }

            Text {
                Layout.fillWidth: true
                text: root.playTime === qsTr("Never played") || root.playTime.length === 0
                      ? qsTr("Not played yet")
                      : qsTr("%1 played  /  Last played %2").arg(root.playTime).arg(root.lastPlayed)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeCaption
                color: Theme.textMuted
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.borderSubtle
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space8

                ShulkButton {
                    Layout.fillWidth: true
                    text: qsTr("View")
                    variant: "play"
                    isFocused: root.activeFocus || root.isSelected
                    implicitHeight: 42 * Theme.scale
                    onClicked: root.triggerActivated()
                }

                ShulkButton {
                    Layout.preferredWidth: 132 * Theme.scale
                    implicitWidth: 132 * Theme.scale
                    implicitHeight: 42 * Theme.scale
                    text: qsTr("Options")
                    shortcutHint: qsTr("Menu")
                    variant: "secondary"
                    onClicked: root.triggerOptions()
                }
            }
        }

        // Keep the focus treatment above the banner and all card content.
        // Drawing the border on the background item allowed the header image
        // to cover its top edge.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radiusMd
            color: "transparent"
            border.color: root.highlighted ? Theme.borderFocused : Theme.borderSubtle
            border.width: root.highlighted ? 2 : 1
            z: 100
        }
    }

    MouseArea {
        id: mouseArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 52 * Theme.scale
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggerActivated()
        onDoubleClicked: root.cardDoubleClicked()
    }
}

// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

ShulkDialog {
    id: root

    dialogTitle: qsTr("Select Background Panorama")
    preferredWidth: 640 * Theme.scale
    preferredHeight: 520 * Theme.scale
    closeOnBackdropClick: true

    property int selectedIndex: 0
    property int focusArea: 0 // 0: list, 1: randomBtn, 2: closeBtn

    onOpacityChanged: {
        if (opacity === 1) {
            var curId = shulkTheme.panoramaSetting
            var foundIdx = 0
            for (var i = 0; i < shulkTheme.availablePanoramas.length; ++i) {
                if (shulkTheme.availablePanoramas[i].id === curId) {
                    foundIdx = i
                    break
                }
            }
            root.selectedIndex = foundIdx
            root.focusArea = 0
            dialogPanoramaList.positionViewAtIndex(foundIdx, ListView.Center)
        }
    }

    function handleAction(action) {
        if (action === Theme.actionBack) {
            root.close()
            return true
        }

        if (focusArea === 0) {
            // List navigation
            if (action === Theme.actionUp) {
                if (selectedIndex > 0) {
                    selectedIndex--
                    dialogPanoramaList.positionViewAtIndex(selectedIndex, ListView.Contain)
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                }
                return true
            } else if (action === Theme.actionDown) {
                if (selectedIndex < shulkTheme.availablePanoramas.length - 1) {
                    selectedIndex++
                    dialogPanoramaList.positionViewAtIndex(selectedIndex, ListView.Contain)
                    if (typeof shulkSound !== "undefined") shulkSound.playTick()
                } else {
                    focusArea = 1
                    if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                }
                return true
            } else if (action === Theme.actionAccept) {
                if (selectedIndex >= 0 && selectedIndex < shulkTheme.availablePanoramas.length) {
                    shulkTheme.setPanorama(shulkTheme.availablePanoramas[selectedIndex].id)
                    root.close()
                    if (typeof shulkSound !== "undefined") shulkSound.playClick()
                }
                return true
            }
        } else if (focusArea === 1) {
            // Random button
            if (action === Theme.actionUp) {
                focusArea = 0
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            } else if (action === Theme.actionRight) {
                focusArea = 2
                if (typeof shulkSound !== "undefined") shulkSound.playTick()
                return true
            } else if (action === Theme.actionAccept) {
                shulkTheme.selectRandomPanorama()
                root.close()
                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                return true
            }
        } else if (focusArea === 2) {
            // Close button
            if (action === Theme.actionUp) {
                focusArea = 0
                if (typeof shulkSound !== "undefined") shulkSound.playFocus()
                return true
            } else if (action === Theme.actionLeft) {
                focusArea = 1
                if (typeof shulkSound !== "undefined") shulkSound.playTick()
                return true
            } else if (action === Theme.actionAccept) {
                root.close()
                return true
            }
        }
        return true
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space12

        // Scrollable Panorama Cards
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusSm
            color: "#16181B"
            border.color: Theme.borderSubtle
            border.width: 1
            clip: true

            ListView {
                id: dialogPanoramaList
                anchors.fill: parent
                anchors.margins: Theme.space6
                model: shulkTheme.availablePanoramas
                clip: true
                spacing: Theme.space4
                currentIndex: root.selectedIndex

                delegate: Rectangle {
                    id: dlgPItem
                    width: dialogPanoramaList.width
                    height: 48 * Theme.scale
                    radius: Theme.radiusSm

                    readonly property bool isSelected: (shulkTheme.panoramaSetting === modelData.id) || (modelData.id !== "random" && shulkTheme.panoramaSetting === "random" && shulkTheme.activePanoramaId === modelData.id)
                    readonly property bool isFocusedItem: (root.focusArea === 0 && root.selectedIndex === index) || dlgMouse.containsMouse

                    color: isFocusedItem ? "#2A4025" : (isSelected ? "#1D281E" : Theme.bgSurfaceRaised)
                    border.color: isFocusedItem ? Theme.mcEmerald : (isSelected ? "#366030" : Theme.borderSubtle)
                    border.width: isFocusedItem ? 2 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space12
                        anchors.rightMargin: Theme.space16
                        spacing: Theme.space12

                        // 3D Minecraft Slot with Cubemap Preview
                        Rectangle {
                            Layout.preferredWidth: 36 * Theme.scale
                            Layout.preferredHeight: 36 * Theme.scale
                            radius: 3
                            color: "#000000"
                            border.color: dlgPItem.isFocusedItem ? Theme.mcEmerald : Theme.borderSubtle
                            border.width: 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: modelData.previewUrl ? modelData.previewUrl : "qrc:/shulk/icons/compass.png"
                                fillMode: Image.PreserveAspectCrop
                                smooth: false
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Item {
                                Layout.fillWidth: true
                                height: dlgPTitle.implicitHeight
                                readonly property int pOff: Theme.getShadowOffset(dlgPTitle.font.pixelSize)

                                Text {
                                    x: parent.pOff; y: parent.pOff
                                    width: parent.width - parent.pOff
                                    text: modelData.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    font.bold: dlgPItem.isSelected || dlgPItem.isFocusedItem
                                    color: Theme.getShadowColor(dlgPTitle.color)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: dlgPTitle
                                    x: 0; y: 0
                                    width: parent.width
                                    text: modelData.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    font.bold: dlgPItem.isSelected || dlgPItem.isFocusedItem
                                    color: dlgPItem.isFocusedItem ? "#FFFFAA" : (dlgPItem.isSelected ? Theme.mcEmerald : Theme.textPrimary)
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: modelData.id === "random" ? qsTr("Randomizes the cubemap on every launch") : (modelData.isConsole ? qsTr("Legacy Console Edition world") : qsTr("Official Minecraft Release panorama"))
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeCaption
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }

                        ShulkBadge {
                            visible: !!modelData.isConsole
                            text: qsTr("Console Edition")
                            badgeColor: "#2A1838"
                            textColor: "#E9D5FF"
                        }

                        Rectangle {
                            visible: dlgPItem.isSelected
                            Layout.preferredWidth: 26 * Theme.scale
                            Layout.preferredHeight: 26 * Theme.scale
                            radius: 13 * Theme.scale
                            color: "#1B3B1A"
                            border.color: Theme.mcEmerald
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✔"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.sizeSmall
                                font.bold: true
                                color: Theme.mcEmerald
                            }
                        }
                    }

                    MouseArea {
                        id: dlgMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.focusArea = 0
                            root.selectedIndex = index
                        }
                        onClicked: {
                            shulkTheme.setPanorama(modelData.id)
                            root.close()
                            if (typeof shulkSound !== "undefined") shulkSound.playClick()
                        }
                    }
                }
            }
        }

        // Dialog Footer Actions
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space12

            ShulkButton {
                Layout.fillWidth: true
                implicitHeight: 42 * Theme.scale
                text: qsTr("🎲 Choose Random")
                variant: "play"
                isFocused: root.focusArea === 1
                onClicked: {
                    shulkTheme.selectRandomPanorama()
                    root.close()
                }
            }

            ShulkButton {
                Layout.preferredWidth: 160 * Theme.scale
                implicitHeight: 42 * Theme.scale
                text: qsTr("Close (B)")
                variant: "secondary"
                isFocused: root.focusArea === 2
                onClicked: root.close()
            }
        }
    }
}

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.shulk.launcher
import "theme"
import "components"
import "views"
import "dialogs"

ApplicationWindow {
    id: appWindow

    visible: true
    font.family: Theme.fontFamily
    width: 1280
    height: 800
    minimumWidth: 960
    minimumHeight: 600
    title: qsTr("Shulk")
    color: Theme.bgDeep

    property int activeNavTab: 0
    property var activeDetailProfile: null
    property bool inDetailView: activeDetailProfile !== null

    // Pending deletion data
    property string pendingDeleteType: "" // "profile", "mod", "world", "account"
    property string pendingDeleteId: ""
    property int pendingDeleteIndex: -1
    property string pendingDeleteName: ""

    // Central Controller & Action Router
    Connections {
        target: shulkInput
        function onActionTriggered(action) {
            // Modal dialogs intercept first with full controller handling
            if (errorDialog.visible) {
                errorDialog.handleAction(action)
                return
            }
            if (confirmDialog.visible) {
                confirmDialog.handleAction(action)
                return
            }
            if (optionsDialog.visible) {
                optionsDialog.handleAction(action)
                return
            }
            if (createProfileDialog.visible) {
                createProfileDialog.handleAction(action)
                return
            }
            if (sortDialog.visible) {
                sortDialog.handleAction(action)
                return
            }
            if (addAccountDialog.visible) {
                addAccountDialog.handleAction(action)
                return
            }

            if (launchOverlay.visible) {
                if (action === Theme.actionBack) {
                    shulkLauncher.kill(shulkLauncher.activeInstanceId)
                }
                return
            }

            // Select / View refreshes whichever local profile view is active.
            if (action === Theme.actionRefresh) {
                if (appWindow.inDetailView) detailView.refreshContent()
                else shulkProfiles.refresh()
                if (typeof shulkSound !== "undefined") shulkSound.playClick()
                return
            }

            // Global Tab switching (LB / RB) - always switches between main menus
            if (action === Theme.actionPrevTab) {
                if (discoverView.inPackDetail) {
                    discoverView.activeModpackDetail = null
                }
                navBar.selectPrevious()
                return
            } else if (action === Theme.actionNextTab) {
                if (discoverView.inPackDetail) {
                    discoverView.activeModpackDetail = null
                }
                navBar.selectNext()
                return
            }

            // Route to Detail View if active
            if (appWindow.inDetailView) {
                detailView.handleAction(action)
                return
            }

            // Route to active view
            if (appWindow.activeNavTab === 0) {
                homeView.handleAction(action)
            } else if (appWindow.activeNavTab === 1) {
                libraryView.handleAction(action)
            } else if (appWindow.activeNavTab === 2) {
                discoverView.handleAction(action)
            } else if (appWindow.activeNavTab === 3) {
                settingsView.handleAction(action)
            }
        }
    }

    // -------------------------------------------------------------
    // TRUE 3D MINECRAFT CUBEMAP SHADER
    // -------------------------------------------------------------
    Item {
        anchors.fill: parent
        z: -1
        clip: true

        Image {
            id: cubeAtlasImg
            anchors.fill: parent
            source: shulkTheme.panoramaCubeUrl
            fillMode: Image.Stretch
            visible: true
            z: 0
        }

        ShaderEffect {
            id: cubemapEffect
            anchors.fill: parent
            z: 1

            property var cubeAtlas: cubeAtlasImg
            property real yaw: 0.0
            property real pitch: 0.0
            property real aspect: width / height
            property real fov: 85.0

            fragmentShader: "qrc:/shulk/shaders/cubemap.frag.qsb"

            // 360-degree continuous yaw rotation (slow, peaceful ambient rotation)
            NumberAnimation on yaw {
                from: 0
                to: Math.PI * 2
                duration: 220000 // ~3.6 minutes per full rotation
                loops: Animation.Infinite
                running: appWindow.active && !launchOverlay.visible && appWindow.visibility !== Window.Minimized
            }

            // Minecraft sine-wave pitch sway (gentle horizon tilt)
            SequentialAnimation on pitch {
                loops: Animation.Infinite
                running: appWindow.active && !launchOverlay.visible && appWindow.visibility !== Window.Minimized
                NumberAnimation {
                    from: -0.16
                    to: 0.06
                    duration: 14000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.06
                    to: -0.16
                    duration: 14000
                    easing.type: Easing.InOutSine
                }
            }

        }

        // Ambient Atmospheric Vignette & Contrast
        Rectangle {
            anchors.fill: parent
            color: "#55111215"
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#C0111215" }
                GradientStop { position: 0.15; color: "#25111215" }
                GradientStop { position: 0.85; color: "#25111215" }
                GradientStop { position: 1.0; color: "#D5111215" }
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 0
        focus: true

        Keys.onPressed: (event) => {
            shulkInput.notifyKeyPressed(event.key, event.modifiers)

            if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_PageUp) {
                navBar.selectPrevious()
                event.accepted = true
            } else if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_PageDown) {
                navBar.selectNext()
                event.accepted = true
            } else if (event.key === Qt.Key_F11) {
                if (appWindow.visibility === Window.FullScreen) {
                    appWindow.showNormal()
                } else {
                    appWindow.showFullScreen()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
                if (appWindow.inDetailView) {
                    if (detailView.contentBrowserOpen) {
                        detailView.contentBrowserOpen = false
                    } else {
                        appWindow.activeDetailProfile = null
                    }
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Y || event.key === Qt.Key_Slash) {
                if (appWindow.activeNavTab === 1 && !appWindow.inDetailView) {
                    libraryView.triggerSearchFocus()
                    event.accepted = true
                }
            }
        }

        // TOP CONSOLE NAVIGATION BAR
        ShulkNavBar {
            id: navBar
            Layout.fillWidth: true
            currentIndex: appWindow.activeNavTab
            onTabSelected: (index) => {
                appWindow.activeDetailProfile = null
                discoverView.activeModpackDetail = null
                appWindow.activeNavTab = index
            }
            onAccountPillClicked: {
                if (shulkAccounts.hasActiveAccount) {
                    appWindow.activeDetailProfile = null
                    discoverView.activeModpackDetail = null
                    appWindow.activeNavTab = 3
                    settingsView.activeCategory = 4
                } else {
                    addAccountDialog.open()
                }
            }
        }

        // MAIN CONTENT STACK
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Main Views Stack (Home, Library, Discover, Settings)
            StackLayout {
                id: viewsStack
                anchors.fill: parent
                currentIndex: appWindow.activeNavTab
                visible: !appWindow.inDetailView

                HomeView {
                    id: homeView
                    onOpenProfile: (profile) => {
                        appWindow.activeDetailProfile = profile
                    }
                    onCreateProfileRequested: {
                        createProfileDialog.open()
                    }
                    onOpenOptionsRequested: (profile) => {
                        optionsDialog.profile = profile
                        optionsDialog.open()
                    }
                    onOpenFeaturedPackRequested: (pack) => {
                        appWindow.activeDetailProfile = null
                        appWindow.activeNavTab = 2
                        discoverView.openPackDetails(pack)
                    }
                    onOpenDiscoverRequested: {
                        appWindow.activeDetailProfile = null
                        appWindow.activeNavTab = 2
                    }
                }

                LibraryView {
                    id: libraryView
                    onOpenProfile: (profile) => {
                        appWindow.activeDetailProfile = profile
                    }
                    onCreateProfileRequested: {
                        createProfileDialog.open()
                    }
                    onOpenSortRequested: {
                        sortDialog.open()
                    }
                    onOpenOptionsRequested: (profile) => {
                        optionsDialog.profile = profile
                        optionsDialog.open()
                    }
                }

                DiscoverView {
                    id: discoverView
                }

                SettingsView {
                    id: settingsView
                    onAddAccountRequested: {
                        addAccountDialog.open()
                    }
                    onConfirmRemoveAccountRequested: (index, name) => {
                        appWindow.pendingDeleteType = "account"
                        appWindow.pendingDeleteIndex = index
                        appWindow.pendingDeleteName = name
                        confirmDialog.dialogTitle = qsTr("Remove Account")
                        confirmDialog.message = qsTr("Are you sure you want to remove account \"%1\"?").arg(name)
                        confirmDialog.confirmText = qsTr("Remove")
                        confirmDialog.open()
                    }
                }
            }

            // Dedicated Profile Detail Overlay View
            ProfileDetailView {
                id: detailView
                anchors.fill: parent
                visible: appWindow.inDetailView
                profile: appWindow.activeDetailProfile
                onBackRequested: {
                    appWindow.activeDetailProfile = null
                }
                onOpenOptionsRequested: (profile) => {
                    optionsDialog.profile = profile
                    optionsDialog.open()
                }
                onConfirmDeleteModRequested: (index, modName) => {
                    appWindow.pendingDeleteType = "mod"
                    appWindow.pendingDeleteIndex = index
                    appWindow.pendingDeleteName = modName
                    confirmDialog.dialogTitle = qsTr("Delete Mod")
                    confirmDialog.message = qsTr("Are you sure you want to delete mod \"%1\"? This removes the file permanently.").arg(modName)
                    confirmDialog.confirmText = qsTr("Delete")
                    confirmDialog.open()
                }
                onConfirmDeleteResourcePackRequested: (index, packName) => {
                    appWindow.pendingDeleteType = "resourcePack"
                    appWindow.pendingDeleteIndex = index
                    appWindow.pendingDeleteName = packName
                    confirmDialog.dialogTitle = qsTr("Delete Resource Pack")
                    confirmDialog.message = qsTr("Are you sure you want to delete resource pack \"%1\"? This removes the file permanently.").arg(packName)
                    confirmDialog.confirmText = qsTr("Delete")
                    confirmDialog.open()
                }
                onConfirmDeleteShaderRequested: (index, shaderName) => {
                    appWindow.pendingDeleteType = "shader"
                    appWindow.pendingDeleteIndex = index
                    appWindow.pendingDeleteName = shaderName
                    confirmDialog.dialogTitle = qsTr("Delete Shader")
                    confirmDialog.message = qsTr("Are you sure you want to delete shader \"%1\"? This removes the file permanently.").arg(shaderName)
                    confirmDialog.confirmText = qsTr("Delete")
                    confirmDialog.open()
                }
                onConfirmDeleteWorldRequested: (index, worldName) => {
                    appWindow.pendingDeleteType = "world"
                    appWindow.pendingDeleteIndex = index
                    appWindow.pendingDeleteName = worldName
                    confirmDialog.dialogTitle = qsTr("Delete World")
                    confirmDialog.message = qsTr("Are you sure you want to delete world save \"%1\"? This cannot be undone.").arg(worldName)
                    confirmDialog.confirmText = qsTr("Delete World")
                    confirmDialog.open()
                }
            }
        }

        // BOTTOM CONTROLLER BUTTON HINTS BAR
        ShulkButtonHints {
            Layout.fillWidth: true
            showBack: appWindow.inDetailView || (appWindow.activeNavTab === 2 && discoverView.inPackDetail) || (appWindow.activeNavTab === 3 && settingsView.focusPane === 1)
            primaryHintText: {
                if (detailView.contentBrowserOpen) return qsTr("Add Selected")
                if (appWindow.activeNavTab === 2 && discoverView.inPackDetail) return qsTr("Install Modpack")
                if (appWindow.inDetailView) return (detailView.activeTab >= 1 && detailView.activeTab <= 4) ? qsTr("Browse / Add") : qsTr("Select / Play")
                if (appWindow.activeNavTab === 2) return qsTr("View Details")
                if (appWindow.activeNavTab === 3) return settingsView.focusPane === 1 ? qsTr("Select / Apply") : qsTr("Enter Category")
                return qsTr("Select")
            }
            secondaryHintText: {
                if (detailView.contentBrowserOpen) return qsTr("Back to Profile")
                if (appWindow.activeNavTab === 2 && discoverView.inPackDetail) return qsTr("Back to Discover")
                if (appWindow.inDetailView) return qsTr("Back to Library")
                if (appWindow.activeNavTab === 3) return qsTr("Back to Categories")
                return qsTr("Back")
            }
            playAction: {
                if (detailView.contentBrowserOpen || (appWindow.activeNavTab === 2 && discoverView.inPackDetail) || appWindow.activeNavTab === 3) return ""
                if (appWindow.activeDetailProfile && appWindow.activeDetailProfile.isRunning) return qsTr("Stop Game")
                if (appWindow.activeNavTab === 1) return ""
                return appWindow.activeNavTab === 2 ? qsTr("Next Source") : qsTr("Quick Play")
            }
            searchAction: {
                if (detailView.contentBrowserOpen) return qsTr("Search")
                if (appWindow.activeNavTab === 2 && discoverView.inPackDetail) return qsTr("Website")
                if (appWindow.inDetailView) {
                    if (detailView.activeTab === 1) return qsTr("Add Mod")
                    if (detailView.activeTab === 2) return qsTr("Add Resource Pack")
                    if (detailView.activeTab === 3) return qsTr("Add Shader Pack")
                    if (detailView.activeTab === 4) return qsTr("Add World")
                    return ""
                }
                if (appWindow.activeNavTab === 3) return ""
                if (appWindow.activeNavTab === 2 || appWindow.activeNavTab === 1) return qsTr("Search")
                return qsTr("Browse Packs")
            }
            menuAction: {
                if (detailView.contentBrowserOpen || (appWindow.activeNavTab === 2 && discoverView.inPackDetail) || appWindow.activeNavTab === 2 || appWindow.activeNavTab === 3) return ""
                return qsTr("Options")
            }
            extraAction: (appWindow.activeNavTab === 2 && discoverView.inPackDetail) ? qsTr("Switch Tabs") : (appWindow.activeNavTab === 2 ? qsTr("Switch Source") : "")
        }
    }

    // -------------------------------------------------------------
    // MODAL DIALOGS & OVERLAYS
    // -------------------------------------------------------------

    // Generic Confirmation Dialog
    ShulkConfirmDialog {
        id: confirmDialog
        onConfirmed: {
            if (appWindow.pendingDeleteType === "profile") {
                if (appWindow.inDetailView && appWindow.activeDetailProfile && appWindow.activeDetailProfile.id === appWindow.pendingDeleteId) {
                    appWindow.activeDetailProfile = null
                }
                // Clear every UI reference before deletion. deleteProfile() is
                // synchronous and removing watched content folders can refresh
                // the detail models while the instance is being destroyed.
                if (optionsDialog.profile && optionsDialog.profile.id === appWindow.pendingDeleteId) {
                    optionsDialog.profile = null
                }
                shulkLauncher.deleteProfile(appWindow.pendingDeleteId)
            } else if (appWindow.pendingDeleteType === "account") {
                shulkAccounts.removeAccount(appWindow.pendingDeleteIndex)
            } else if (appWindow.pendingDeleteType === "mod") {
                if (detailView) {
                    detailView.deleteMod(appWindow.pendingDeleteIndex)
                }
            } else if (appWindow.pendingDeleteType === "resourcePack") {
                if (detailView) {
                    detailView.deleteResourcePack(appWindow.pendingDeleteIndex)
                }
            } else if (appWindow.pendingDeleteType === "shader") {
                if (detailView) {
                    detailView.deleteShader(appWindow.pendingDeleteIndex)
                }
            } else if (appWindow.pendingDeleteType === "world") {
                if (detailView) {
                    detailView.deleteWorld(appWindow.pendingDeleteIndex)
                }
            }
            appWindow.pendingDeleteType = ""
            appWindow.pendingDeleteIndex = -1
            appWindow.pendingDeleteId = ""
            appWindow.pendingDeleteName = ""
        }
        onCancelled: {
            appWindow.pendingDeleteType = ""
            appWindow.pendingDeleteIndex = -1
            appWindow.pendingDeleteId = ""
            appWindow.pendingDeleteName = ""
        }
    }

    // Profile Context Options Dialog
    ShulkProfileOptionsDialog {
        id: optionsDialog
        onPlayRequested: (id) => {
            shulkLauncher.launch(id)
        }
        onDeleteRequested: (id) => {
            appWindow.pendingDeleteType = "profile"
            appWindow.pendingDeleteId = id
            confirmDialog.dialogTitle = qsTr("Delete Profile")
            confirmDialog.message = qsTr("Delete \"%1\" and permanently remove its mods, worlds, settings, and local files?").arg(optionsDialog.profile ? optionsDialog.profile.name : id)
            confirmDialog.confirmText = qsTr("Delete Profile")
            confirmDialog.open()
        }
        onDuplicateRequested: (id) => {
            shulkLauncher.duplicateProfile(id, "")
        }
        onRenameRequested: (id, newName) => {
            shulkLauncher.renameProfile(id, newName)
        }
    }

    // Create Profile Dialog
    ShulkCreateProfileDialog {
        id: createProfileDialog
    }

    // Sort & Filter Dialog
    ShulkSortFilterDialog {
        id: sortDialog
        onSortSelected: (type) => {
            libraryView.sortType = type
        }
    }

    // Add Account Dialog
    ShulkAddAccountDialog {
        id: addAccountDialog
    }

    // Dedicated launch surface. Keep this intentionally restrained: launching a
    // large pack can take a while, so status and progress matter more than motion.
    Rectangle {
        id: launchOverlay
        anchors.fill: parent
        color: "#F20C0D0E"
        visible: opacity > 0
        opacity: shulkLauncher.isLaunching ? 1.0 : 0.0
        z: 9980

        readonly property int progressValue: Math.max(0, Math.min(100, shulkLauncher.launchProgress))

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 64 * Theme.scale, 620 * Theme.scale)
            height: 356 * Theme.scale
            color: Theme.bgSurface
            border.color: Theme.borderStrong
            border.width: 1
            radius: Theme.radiusLg
            clip: true

            // A single brand line gives the panel hierarchy without ornamental
            // animation or a game-like faux loading spinner.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 4 * Theme.scale
                color: Theme.accentPrimary
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space32
                anchors.rightMargin: Theme.space32
                anchors.topMargin: Theme.space28
                anchors.bottomMargin: Theme.space24
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space16

                    Rectangle {
                        Layout.preferredWidth: 58 * Theme.scale
                        Layout.preferredHeight: 58 * Theme.scale
                        color: Theme.bgSurfaceRaised
                        border.color: Theme.borderSubtle
                        border.width: 1
                        radius: Theme.radiusMd

                        Image {
                            anchors.centerIn: parent
                            width: 38 * Theme.scale
                            height: 38 * Theme.scale
                            source: "qrc:/shulk/icons/grass_block.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            mipmap: false
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space4

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("LAUNCHING MINECRAFT")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeSmall
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.4 * Theme.scale
                            color: Theme.accentShulkLight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: shulkLauncher.activeInstanceName.length > 0
                                  ? shulkLauncher.activeInstanceName
                                  : qsTr("Minecraft")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.sizeTitle
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: launchOverlay.progressValue + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeHeader
                        font.weight: Font.DemiBold
                        color: Theme.textSecondary
                    }
                }

                Item { Layout.preferredHeight: Theme.space28 }

                Text {
                    Layout.fillWidth: true
                    text: shulkLauncher.statusMessage.length > 0
                          ? shulkLauncher.statusMessage
                          : qsTr("Preparing game files...")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeBody
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space12
                    Layout.preferredHeight: 10 * Theme.scale
                    color: Theme.bgDeep
                    border.color: Theme.borderSubtle
                    border.width: 1
                    radius: Theme.radiusSm
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: Math.max(0, (parent.width - 4) * launchOverlay.progressValue / 100)
                        color: Theme.accentPrimary
                        radius: Theme.radiusSm

                        Behavior on width {
                            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.space16 }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space8

                    Rectangle {
                        Layout.preferredWidth: 8 * Theme.scale
                        Layout.preferredHeight: 8 * Theme.scale
                        radius: 4 * Theme.scale
                        color: Theme.accentShulkLight

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: launchOverlay.visible
                            NumberAnimation { from: 1.0; to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.35; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: launchOverlay.progressValue < 50
                              ? qsTr("Preparing the launcher environment")
                              : (launchOverlay.progressValue < 100
                                 ? qsTr("Minecraft is starting in the background")
                                 : qsTr("Waiting for the game window"))
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeCaption
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.borderSubtle
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space16
                    spacing: Theme.space12

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("You can safely cancel before the game window opens.")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeSmall
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }

                    ShulkButton {
                        Layout.preferredWidth: 132 * Theme.scale
                        text: qsTr("Cancel")
                        shortcutHint: (shulkInput.isController || shulkInput.inputMode === 1) ? "B" : "Esc"
                        variant: "secondary"
                        onClicked: shulkLauncher.kill(shulkLauncher.activeInstanceId)
                    }
                }
            }
        }
    }

    // Launch Error & Crash Dialog
    ShulkErrorDialog {
        id: errorDialog
        errorTitle: shulkLauncher.lastErrorTitle
        errorMessage: shulkLauncher.lastErrorMessage
        errorLog: shulkLauncher.lastErrorLog
    }

    // Auto-open error dialog when launcher encounters a launch failure
    Connections {
        target: shulkLauncher
        function onLastErrorChanged() {
            if (shulkLauncher.hasError) {
                errorDialog.open()
            }
        }
    }
}

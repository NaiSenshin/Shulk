// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration>

class ShulkLauncherController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool isAnyInstanceRunning READ isAnyInstanceRunning NOTIFY isAnyInstanceRunningChanged)
    Q_PROPERTY(bool isLaunching READ isLaunching NOTIFY isLaunchingChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(LaunchState launchState READ launchState NOTIFY launchStateChanged)
    Q_PROPERTY(QString activeInstanceId READ activeInstanceId NOTIFY activeInstanceIdChanged)
    Q_PROPERTY(QString activeInstanceName READ activeInstanceName NOTIFY activeInstanceNameChanged)
    Q_PROPERTY(int launchProgress READ launchProgress NOTIFY launchProgressChanged)
    Q_PROPERTY(QString lastErrorTitle READ lastErrorTitle NOTIFY lastErrorChanged)
    Q_PROPERTY(QString lastErrorMessage READ lastErrorMessage NOTIFY lastErrorChanged)
    Q_PROPERTY(QString lastErrorLog READ lastErrorLog NOTIFY lastErrorChanged)
    Q_PROPERTY(bool hasError READ hasError NOTIFY lastErrorChanged)
    Q_PROPERTY(int maxMemory READ maxMemory WRITE setMaxMemory NOTIFY memorySettingsChanged)
    Q_PROPERTY(int minMemory READ minMemory WRITE setMinMemory NOTIFY memorySettingsChanged)
    Q_PROPERTY(QString javaPath READ javaPath WRITE setJavaPath NOTIFY javaSettingsChanged)
    Q_PROPERTY(int systemRamMb READ systemRamMb CONSTANT)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(bool isCheckingForUpdates READ isCheckingForUpdates NOTIFY updateStatusChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateStatusChanged)
    Q_PROPERTY(QString updateLatestVersion READ updateLatestVersion NOTIFY updateStatusChanged)
    Q_PROPERTY(QString updateReleaseNotes READ updateReleaseNotes NOTIFY updateStatusChanged)
    Q_PROPERTY(QString updateDownloadUrl READ updateDownloadUrl NOTIFY updateStatusChanged)
    Q_PROPERTY(QString updateStatusMessage READ updateStatusMessage NOTIFY updateStatusChanged)
    Q_PROPERTY(QString updateChannel READ updateChannel WRITE setUpdateChannel NOTIFY updateChannelChanged)
    Q_PROPERTY(QString devToken READ devToken WRITE setDevToken NOTIFY devTokenChanged)

public:
    enum LaunchState {
        StateReady = 0,
        StatePreparing,
        StateCheckingFiles,
        StateDownloading,
        StateAuthenticating,
        StateLaunching,
        StateRunning,
        StateStopping,
        StateFailed
    };
    Q_ENUM(LaunchState)

    explicit ShulkLauncherController(QObject* parent = nullptr);

    bool isAnyInstanceRunning() const;
    bool isLaunching() const { return m_isLaunching; }
    QString statusMessage() const { return m_statusMessage; }
    LaunchState launchState() const { return m_launchState; }
    QString activeInstanceId() const { return m_activeInstanceId; }
    QString activeInstanceName() const { return m_activeInstanceName; }
    int launchProgress() const { return m_launchProgress; }
    QString lastErrorTitle() const { return m_lastErrorTitle; }
    QString lastErrorMessage() const { return m_lastErrorMessage; }
    QString lastErrorLog() const { return m_lastErrorLog; }
    bool hasError() const { return !m_lastErrorMessage.isEmpty(); }
    QString appVersion() const;

    Q_INVOKABLE void launch(const QString& instanceId);
    Q_INVOKABLE void launchServer(const QString& instanceId, const QString& serverAddress);
    void setRecentServerModel(class ShulkRecentServerModel* model) { m_recentServerModel = model; }
    Q_INVOKABLE void kill(const QString& instanceId);
    Q_INVOKABLE void deleteProfile(const QString& instanceId);
    Q_INVOKABLE void duplicateProfile(const QString& instanceId, const QString& newName);
    Q_INVOKABLE void renameProfile(const QString& instanceId, const QString& newName);
    Q_INVOKABLE void openInstanceFolder(const QString& instanceId);
    Q_INVOKABLE void clearError();
    Q_INVOKABLE void copyToClipboard(const QString& text);
    Q_INVOKABLE void notifyGameWindowOpened();
    Q_INVOKABLE void exitApplication();

    Q_INVOKABLE void showLegacyInstanceWindow(const QString& instanceId);
    Q_INVOKABLE void showGlobalSettings(const QString& category = QString());
    Q_INVOKABLE void showNewInstanceDialog();
    Q_INVOKABLE void showAccountsDialog();

    int maxMemory() const;
    void setMaxMemory(int mb);
    int minMemory() const;
    void setMinMemory(int mb);
    QString javaPath() const;
    void setJavaPath(const QString& path);
    int systemRamMb() const;

    // Updater API
    bool isCheckingForUpdates() const { return m_isCheckingForUpdates; }
    bool updateAvailable() const { return m_updateAvailable; }
    QString updateLatestVersion() const { return m_updateLatestVersion; }
    QString updateReleaseNotes() const { return m_updateReleaseNotes; }
    QString updateDownloadUrl() const { return m_updateDownloadUrl; }
    QString updateStatusMessage() const { return m_updateStatusMessage; }
    QString updateChannel() const { return m_updateChannel; }
    void setUpdateChannel(const QString& channel);
    QString devToken() const { return m_devToken; }
    void setDevToken(const QString& token);

    Q_INVOKABLE void checkForUpdates(bool userTriggered = true);
    Q_INVOKABLE void openUpdateDownload();

signals:
    void isAnyInstanceRunningChanged();
    void isLaunchingChanged();
    void statusMessageChanged();
    void launchStateChanged();
    void activeInstanceIdChanged();
    void activeInstanceNameChanged();
    void launchProgressChanged();
    void lastErrorChanged();
    void memorySettingsChanged();
    void javaSettingsChanged();
    void updateStatusChanged();
    void updateChannelChanged();
    void devTokenChanged();

    void launchStarted(const QString& instanceId);
    void launchSucceeded(const QString& instanceId);
    void gameWindowOpened();
    void launchFailed(const QString& instanceId, const QString& reason);
    void instanceTerminated(const QString& instanceId, int exitCode);

public slots:
    void updateRunningState();
    void setStatus(LaunchState state, const QString& message, int progress = -1);

private:
    void loadUpdaterSettings();
    void saveUpdaterSettings();

    bool m_isLaunching = false;
    QString m_statusMessage;
    LaunchState m_launchState = StateReady;
    QString m_activeInstanceId;
    QString m_activeInstanceName;
    int m_launchProgress = 0;
    QString m_lastErrorTitle;
    QString m_lastErrorMessage;
    QString m_lastErrorLog;

    // Updater state
    bool m_isCheckingForUpdates = false;
    bool m_updateAvailable = false;
    QString m_updateLatestVersion;
    QString m_updateReleaseNotes;
    QString m_updateDownloadUrl;
    QString m_updateStatusMessage;
    QString m_updateChannel = "stable"; // "stable" or "development"
    QString m_devToken;

    class ShulkRecentServerModel* m_recentServerModel = nullptr;
};

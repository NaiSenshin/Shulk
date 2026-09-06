// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QObject>
#include <QStringList>
#include <QtQmlIntegration>
#include <memory>

#include "tasks/Task.h"

namespace Meta {
class VersionList;
}

class ShulkCreationService : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QStringList releaseVersions READ releaseVersions NOTIFY versionsLoaded)
    Q_PROPERTY(QStringList snapshotVersions READ snapshotVersions NOTIFY versionsLoaded)
    Q_PROPERTY(QStringList betaVersions READ betaVersions NOTIFY versionsLoaded)
    Q_PROPERTY(QStringList alphaVersions READ alphaVersions NOTIFY versionsLoaded)
    Q_PROPERTY(QStringList allVersions READ allVersions NOTIFY versionsLoaded)
    Q_PROPERTY(QStringList supportedLoaders READ supportedLoaders CONSTANT)
    Q_PROPERTY(bool isCreating READ isCreating NOTIFY isCreatingChanged)
    Q_PROPERTY(QString creationStatus READ creationStatus NOTIFY creationStatusChanged)
    Q_PROPERTY(bool isSearching READ isSearching NOTIFY isSearchingChanged)
    Q_PROPERTY(QString searchStatus READ searchStatus NOTIFY searchStatusChanged)
    Q_PROPERTY(bool isContentSearching READ isContentSearching NOTIFY isContentSearchingChanged)
    Q_PROPERTY(bool isContentInstalling READ isContentInstalling NOTIFY isContentInstallingChanged)
    Q_PROPERTY(QString contentStatus READ contentStatus NOTIFY contentStatusChanged)

    Q_PROPERTY(QVariantList platforms READ getSupportedPlatforms CONSTANT)

public:
    explicit ShulkCreationService(QObject* parent = nullptr);

    QStringList releaseVersions() const { return m_releaseVersions; }
    QStringList snapshotVersions() const { return m_snapshotVersions; }
    QStringList betaVersions() const { return m_betaVersions; }
    QStringList alphaVersions() const { return m_alphaVersions; }
    QStringList allVersions() const { return m_allVersions; }
    QStringList supportedLoaders() const { return { "Fabric", "NeoForge", "Forge", "Quilt", "Vanilla" }; }
    bool isCreating() const { return m_isCreating; }
    QString creationStatus() const { return m_creationStatus; }
    bool isSearching() const { return m_isSearching; }
    QString searchStatus() const { return m_searchStatus; }
    bool isContentSearching() const { return m_isContentSearching; }
    bool isContentInstalling() const { return m_isContentInstalling; }
    QString contentStatus() const { return m_contentStatus; }

    Q_INVOKABLE void loadVersions();
    Q_INVOKABLE QString resolveLoaderVersion(const QString& loaderType, const QString& mcVersion);
    Q_INVOKABLE QStringList getCompatibleLoaders(const QString& mcVersion) const;
    Q_INVOKABLE QVariantList getSupportedPlatforms() const;
    Q_INVOKABLE QVariantList getHandheldRecommendedPacks() const;
    Q_INVOKABLE QVariantList getPacksForPlatform(const QString& platform, const QString& search = QString()) const;
    Q_INVOKABLE void searchPlatform(const QString& platform, const QString& query = QString());

    Q_INVOKABLE void createProfile(const QString& name,
                                   const QString& mcVersion,
                                   const QString& loaderType = "Fabric",
                                   const QString& loaderVersion = QString(),
                                   const QString& group = QString(),
                                   const QString& iconKey = "grass");

    Q_INVOKABLE void importModpackFile();

    Q_INVOKABLE void installModpack(const QString& name,
                                    const QString& mcVersion,
                                    const QString& loaderType,
                                    const QString& iconUrl = QString(),
                                    const QString& bannerUrl = QString(),
                                    const QString& description = QString(),
                                    const QString& author = QString(),
                                    const QString& downloadUrl = QString(),
                                    const QString& projectId = QString(),
                                    const QString& platform = QStringLiteral("modrinth"),
                                    const QString& packVersion = QString());

    Q_INVOKABLE void fetchPackDetails(const QString& platform, const QString& packId, const QString& extra = QString());
    Q_INVOKABLE void searchContent(const QString& contentType,
                                   const QString& query,
                                   const QString& minecraftVersion,
                                   const QString& loaderType);
    Q_INVOKABLE void installContent(const QString& instanceId,
                                    const QString& contentType,
                                    const QString& projectId,
                                    const QString& displayName,
                                    const QString& minecraftVersion,
                                    const QString& loaderType);

signals:
    void versionsLoaded();
    void isCreatingChanged();
    void creationStatusChanged();
    void isSearchingChanged();
    void searchStatusChanged();
    void searchFinished(const QString& platform, const QVariantList& results);
    void searchFailed(const QString& platform, const QString& error);
    void packDetailsLoaded(const QString& packId, const QVariantMap& details);
    void packDetailsFailed(const QString& packId, const QString& error);
    void contentSearchFinished(const QString& contentType, const QVariantList& results);
    void contentSearchFailed(const QString& contentType, const QString& error);
    void contentInstallFinished(const QString& contentType, const QString& displayName);
    void contentInstallFailed(const QString& contentType, const QString& error);
    void isContentSearchingChanged();
    void isContentInstallingChanged();
    void contentStatusChanged();
    void profileCreated(const QString& instanceId);
    void profileCreationFailed(const QString& error);

private:
    void loadFromDiskCache();
    void populateFromMetadataList(const std::shared_ptr<Meta::VersionList>& vlist);
    void startPackInstall(class InstanceTask* task, const QString& name, const QString& iconUrl);

    QStringList m_releaseVersions;
    QStringList m_snapshotVersions;
    QStringList m_betaVersions;
    QStringList m_alphaVersions;
    QStringList m_allVersions;
    bool m_isCreating = false;
    QString m_creationStatus;
    int m_lastCreationProgress = -1;
    bool m_isSearching = false;
    QString m_searchStatus;
    bool m_isContentSearching = false;
    bool m_isContentInstalling = false;
    QString m_contentStatus = tr("Ready");
    mutable QByteArray m_cachedAtlData;
    mutable bool m_atlFetching = false;
    Task::Ptr m_metaLoadTask;
};

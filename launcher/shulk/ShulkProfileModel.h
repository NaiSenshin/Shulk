// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QAbstractListModel>
#include <QSortFilterProxyModel>
#include <QList>
#include <QHash>
#include <QSet>
#include <QString>
#include <QVariantMap>

class InstanceList;
class MinecraftInstance;
class PackProfile;
class BaseInstance;
class QNetworkAccessManager;

class ShulkProfileModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString mostRecentId READ mostRecentId NOTIFY mostRecentIdChanged)
    Q_PROPERTY(bool hasProfiles READ hasProfiles NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        IconKeyRole,
        IconUrlRole,
        BannerUrlRole,
        DescriptionRole,
        AuthorsRole,
        WebsiteUrlRole,
        MinecraftVersionRole,
        LoaderTypeRole,
        LoaderVersionRole,
        LastPlayedRole,
        LastPlayedTimestampRole,
        PlayTimeRole,
        PlayTimeSecondsRole,
        ModCountRole,
        IsRunningRole,
        GroupRole,
        InstancePathRole
    };
    Q_ENUM(Roles)

    explicit ShulkProfileModel(QObject* parent = nullptr);
    ~ShulkProfileModel() override = default;

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool hasProfiles() const { return rowCount() > 0; }
    QString mostRecentId() const;

    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE QVariantMap getById(const QString& id) const;
    Q_INVOKABLE int indexOf(const QString& id) const;
    Q_INVOKABLE void refresh();

signals:
    void countChanged();
    void mostRecentIdChanged();
    void profileStateChanged(const QString& id, bool isRunning);

private slots:
    void onInstanceDataChanged(const QModelIndex& topLeft, const QModelIndex& bottomRight);
    void onInstanceRowsAboutToBeInserted(const QModelIndex& parent, int first, int last);
    void onInstanceRowsInserted(const QModelIndex& parent, int first, int last);
    void onInstanceRowsAboutToBeRemoved(const QModelIndex& parent, int first, int last);
    void onInstanceRowsRemoved(const QModelIndex& parent, int first, int last);
    void onInstanceModelAboutToBeReset();
    void onInstanceModelReset();

private:
    InstanceList* instanceList() const;
    MinecraftInstance* getInstanceAt(int row) const;
    PackProfile* loadedPackProfile(MinecraftInstance* inst) const;
    QString formatPlayTime(int64_t seconds) const;
    QString formatLastPlayed(int64_t timestampMs) const;
    void extractLoaderInfo(MinecraftInstance* inst, QString& loaderType, QString& loaderVersion) const;
    int countInstalledMods(MinecraftInstance* inst) const;
    QString extractDescription(MinecraftInstance* inst) const;
    QString extractBannerUrl(MinecraftInstance* inst) const;
    QString extractIconUrl(MinecraftInstance* inst) const;
    QString extractAuthors(MinecraftInstance* inst) const;
    QString extractWebsiteUrl(MinecraftInstance* inst) const;
    void requestManagedArtwork();

    QNetworkAccessManager* m_network = nullptr;
    QHash<QString, QString> m_managedBannerUrls;
    QSet<QString> m_pendingArtworkRequests;
    mutable QHash<QString, int> m_modCountCache;
};

class ShulkProfileFilterModel : public QSortFilterProxyModel {
    Q_OBJECT
    Q_PROPERTY(QString filterString READ filterString WRITE setFilterString NOTIFY filterStringChanged)
    Q_PROPERTY(QString sortType READ sortType WRITE setSortType NOTIFY sortTypeChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    explicit ShulkProfileFilterModel(QObject* parent = nullptr);

    QString filterString() const { return m_filterString; }
    void setFilterString(const QString& filter);

    QString sortType() const { return m_sortType; }
    void setSortType(const QString& sortType);

    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE QVariantMap getById(const QString& id) const;

protected:
    bool filterAcceptsRow(int source_row, const QModelIndex& source_parent) const override;
    bool lessThan(const QModelIndex& source_left, const QModelIndex& source_right) const override;

signals:
    void filterStringChanged();
    void sortTypeChanged();
    void countChanged();

private:
    QString m_filterString;
    QString m_sortType = "recent";
};

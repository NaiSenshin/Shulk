// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QByteArray>
#include <QDateTime>
#include <QVariantMap>

class ConcurrentTask;

struct ShulkRecentServerEntry {
    QString instanceId;
    QString serverAddress;
    QString serverName;
    QString description;       // Server MOTD
    QByteArray iconBytes;      // Cached raw PNG from servers.dat or SLP favicon
    qint64 lastPlayedTime = 0; // Unix timestamp in seconds
    int onlinePlayers = -1;    // -1 = unknown / offline
    int maxPlayers = -1;
    int pingMs = -1;           // -1 = unknown / offline
    bool isOnline = false;
    bool isPinged = false;
    int iconRevision = 0;
};

class ShulkRecentServerModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool hasServers READ hasServers NOTIFY countChanged)

public:
    enum Roles {
        InstanceIdRole = Qt::UserRole + 1,
        InstanceNameRole,
        InstanceExistsRole,
        InstanceIconUrlRole,
        ServerAddressRole,
        ServerNameRole,
        IconUrlRole,
        LastPlayedTextRole,
        LastPlayedTimestampRole,
        OnlinePlayersRole,
        MaxPlayersRole,
        PlayerCountTextRole,
        DescriptionRole,
        IsOnlineRole,
        IsPingedRole,
        StatusTextRole,
        PingMsRole,
        PingTextRole,
        ServerSubtitleRole
    };
    Q_ENUM(Roles)

    explicit ShulkRecentServerModel(QObject* parent = nullptr);
    ~ShulkRecentServerModel() override = default;

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool hasServers() const { return rowCount() > 0; }

    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE void removeRecent(int index);
    Q_INVOKABLE void clearRecents();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void pingRecentServers();

    void recordServerPlayed(const QString& instanceId, const QString& serverAddress,
                            const QString& serverName = QString(),
                            const QByteArray& iconBytes = QByteArray());

    // Populate metadata from instance's servers.dat if available
    void enrichFromServersDat(const QString& instanceId, const QString& serverAddress);
    Q_INVOKABLE void scanAllInstancesForServers();

    void pingServer(int index);
    void pingAll();

    QByteArray getIconBytes(const QString& serverAddress) const;

signals:
    void countChanged();
    void serversChanged();

private:
    void loadHistory();
    void saveHistory();
    QString historyFilePath() const;
    QString formatRelativeTime(qint64 timestampSecs) const;

    QList<ShulkRecentServerEntry> m_entries;
};

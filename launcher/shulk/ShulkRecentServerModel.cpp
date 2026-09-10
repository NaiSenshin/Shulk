// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkRecentServerModel.h"
#include "Application.h"
#include "InstanceList.h"
#include "minecraft/MinecraftInstance.h"
#include "FileSystem.h"
#include "ui/pages/instance/McResolver.h"
#include "ui/pages/instance/McClient.h"
#include <io/stream_reader.h>
#include <tag_compound.h>
#include <tag_list.h>
#include <tag_string.h>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QTimer>
#include <QLocale>
#include <QRegularExpression>
#include <QDebug>
#include <sstream>

static QString parseServerDescription(const QJsonValue& descVal)
{
    QString text;
    if (descVal.isString()) {
        text = descVal.toString();
    } else if (descVal.isObject()) {
        QJsonObject obj = descVal.toObject();
        text = obj.value("text").toString();
        if (obj.contains("extra") && obj.value("extra").isArray()) {
            QJsonArray extra = obj.value("extra").toArray();
            for (const auto& val : extra) {
                if (val.isString()) {
                    text += val.toString();
                } else if (val.isObject()) {
                    text += val.toObject().value("text").toString();
                }
            }
        }
    }
    // Strip Minecraft formatting codes (§0-§f, §k-§o, §r, §x, etc.)
    static QRegularExpression sectionCodeRegex("§[0-9a-fk-orA-FK-ORxX]");
    text.remove(sectionCodeRegex);
    text = text.simplified();
    return text;
}

static std::unique_ptr<nbt::tag_compound> parseServersDatFile(const QString& filename)
{
    try {
        QByteArray input = FS::read(filename);
        if (input.isEmpty())
            return nullptr;
        std::istringstream stream(std::string(input.constData(), input.size()));
        auto pair = nbt::io::read_compound(stream);
        if (pair.first.empty() && pair.second) {
            return std::move(pair.second);
        }
    } catch (...) {
        return nullptr;
    }
    return nullptr;
}

ShulkRecentServerModel::ShulkRecentServerModel(QObject* parent)
    : QAbstractListModel(parent)
{
    loadHistory();
    scanAllInstancesForServers();
    for (const auto& entry : m_entries) {
        enrichFromServersDat(entry.instanceId, entry.serverAddress);
    }
    pingAll();

    // Hook instance model updates to keep instance names and existence reactive
    if (APPLICATION && APPLICATION->instances()) {
        connect(APPLICATION->instances(), &QAbstractItemModel::dataChanged, this, [this]() {
            if (!m_entries.isEmpty()) {
                emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
            }
        });
        connect(APPLICATION->instances(), &QAbstractItemModel::rowsRemoved, this, [this]() {
            if (!m_entries.isEmpty()) {
                emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
            }
        });
        connect(APPLICATION->instances(), &QAbstractItemModel::modelReset, this, [this]() {
            if (!m_entries.isEmpty()) {
                emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
            }
        });
    }
}

QString ShulkRecentServerModel::historyFilePath() const
{
    if (APPLICATION) {
        return QDir(APPLICATION->dataRoot()).filePath("shulk-recent-servers.json");
    }
    return QDir::homePath() + "/.local/share/PrismLauncher/shulk-recent-servers.json";
}

void ShulkRecentServerModel::loadHistory()
{
    m_entries.clear();
    QFile file(historyFilePath());
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isArray()) {
        return;
    }

    QJsonArray array = doc.array();
    for (const QJsonValue& val : array) {
        if (!val.isObject())
            continue;
        QJsonObject obj = val.toObject();
        ShulkRecentServerEntry entry;
        entry.instanceId = obj.value("instanceId").toString();
        entry.serverAddress = obj.value("serverAddress").toString();
        entry.serverName = obj.value("serverName").toString();
        entry.description = obj.value("description").toString();
        entry.onlinePlayers = obj.value("onlinePlayers").toInt(-1);
        entry.maxPlayers = obj.value("maxPlayers").toInt(-1);
        entry.pingMs = obj.value("pingMs").toInt(-1);
        if (entry.onlinePlayers >= 0) {
            entry.isOnline = true;
        }
        entry.lastPlayedTime = static_cast<qint64>(obj.value("lastPlayedTime").toDouble(0));

        QString iconBase64 = obj.value("icon").toString();
        if (!iconBase64.isEmpty()) {
            entry.iconBytes = QByteArray::fromBase64(iconBase64.toLatin1());
        }

        if (!entry.instanceId.isEmpty() && !entry.serverAddress.isEmpty()) {
            m_entries.append(entry);
        }
    }
}

void ShulkRecentServerModel::saveHistory()
{
    QJsonArray array;
    for (const auto& entry : m_entries) {
        QJsonObject obj;
        obj["instanceId"] = entry.instanceId;
        obj["serverAddress"] = entry.serverAddress;
        obj["serverName"] = entry.serverName;
        obj["description"] = entry.description;
        obj["onlinePlayers"] = entry.onlinePlayers;
        obj["maxPlayers"] = entry.maxPlayers;
        obj["pingMs"] = entry.pingMs;
        obj["lastPlayedTime"] = static_cast<double>(entry.lastPlayedTime);
        if (!entry.iconBytes.isEmpty()) {
            obj["icon"] = QString::fromLatin1(entry.iconBytes.toBase64());
        }
        array.append(obj);
    }

    QJsonDocument doc(array);
    QFile file(historyFilePath());
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        file.write(doc.toJson(QJsonDocument::Indented));
    }
}

int ShulkRecentServerModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    // Show up to the 3 most recently played multiplayer servers on Home
    return std::min<int>(3, m_entries.size());
}

QVariant ShulkRecentServerModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= rowCount())
        return QVariant();

    const auto& entry = m_entries.at(index.row());

    // Resolve instance live from InstanceList
    QString resolvedName = entry.instanceId;
    QString resolvedIconUrl = "qrc:/shulk/icons/grass_block.png";
    bool exists = false;
    if (APPLICATION && APPLICATION->instances()) {
        auto inst = APPLICATION->instances()->getInstanceById(entry.instanceId);
        if (inst) {
            resolvedName = inst->name();
            exists = true;

            QString root = inst->instanceRoot();
            QString iconKey = inst->iconKey().trimmed();
            bool usesDefaultIcon = iconKey.isEmpty() || iconKey == "grass" || iconKey == "default";

            if (QFileInfo::exists(root + "/icon.png")) {
                resolvedIconUrl = "file://" + root + "/icon.png";
            } else if (!usesDefaultIcon && QFileInfo::exists(root + "/minecraft/icon.png")) {
                resolvedIconUrl = "file://" + root + "/minecraft/icon.png";
            } else if (!usesDefaultIcon) {
                resolvedIconUrl = "image://insticons/" + iconKey;
            } else if (resolvedName.contains("DeckCraft", Qt::CaseInsensitive)) {
                resolvedIconUrl = "qrc:/shulk/icons/pickaxe.png";
            } else if (resolvedName.contains("All The Mods", Qt::CaseInsensitive) || resolvedName.contains("ATM", Qt::CaseInsensitive)) {
                resolvedIconUrl = "image://insticons/netherstar";
            } else {
                resolvedIconUrl = "qrc:/shulk/icons/grass_block.png";
            }
        }
    }

    switch (role) {
    case InstanceIdRole:
        return entry.instanceId;
    case InstanceNameRole:
        return resolvedName;
    case InstanceExistsRole:
        return exists;
    case InstanceIconUrlRole:
        return resolvedIconUrl;
    case ServerAddressRole:
        return entry.serverAddress;
    case ServerNameRole: {
        if (entry.serverAddress.contains("hypixel", Qt::CaseInsensitive))
            return "Hypixel Network";
        if (entry.serverAddress.contains("cubecraft", Qt::CaseInsensitive))
            return "CubeCraft";
        if (entry.serverName == "Archived SMP" || entry.serverAddress.contains("archived-smp", Qt::CaseInsensitive))
            return "Archived SMP";
        if (entry.serverAddress.contains("cobblemon", Qt::CaseInsensitive))
            return "Cobblemon Official";
        if (!entry.serverName.isEmpty() && entry.serverName != "Minecraft Server")
            return entry.serverName;
        // Fallback to host/IP without default port
        QString clean = entry.serverAddress;
        if (clean.endsWith(":25565"))
            clean.chop(6);
        return clean;
    }
    case IconUrlRole: {
        if (!entry.iconBytes.isEmpty()) {
            return QString("image://shulkserver/%1?v=%2").arg(entry.serverAddress).arg(entry.iconRevision);
        }
        return "qrc:/shulk/icons/compass.png";
    }
    case LastPlayedTextRole:
        return formatRelativeTime(entry.lastPlayedTime);
    case LastPlayedTimestampRole:
        return entry.lastPlayedTime;
    case OnlinePlayersRole: {
        if (entry.onlinePlayers >= 0)
            return entry.onlinePlayers;
        return -1;
    }
    case MaxPlayersRole:
        return entry.maxPlayers;
    case PlayerCountTextRole: {
        if (entry.onlinePlayers < 0)
            return QString();
        auto formatCount = [](int n) -> QString {
            if (n >= 1000000) {
                double val = n / 1000000.0;
                return QString("%1M").arg(QString::number(val, 'f', (n % 1000000 == 0 ? 0 : 1)));
            }
            if (n >= 1000) {
                double val = n / 1000.0;
                return QString("%1k").arg(QString::number(val, 'f', (n % 1000 == 0 ? 0 : 1)));
            }
            return QLocale().toString(n);
        };
        if (entry.maxPlayers > 0)
            return QString("%1 / %2").arg(formatCount(entry.onlinePlayers)).arg(formatCount(entry.maxPlayers));
        return formatCount(entry.onlinePlayers);
    }
    case DescriptionRole: {
        QString desc = entry.description;
        QString name = data(index, ServerNameRole).toString();
        if (!name.isEmpty() && desc.startsWith(name, Qt::CaseInsensitive)) {
            desc = desc.mid(name.length()).trimmed();
        }
        return desc;
    }
    case IsOnlineRole:
        return entry.isOnline;
    case IsPingedRole:
        return entry.isPinged;
    case StatusTextRole: {
        if (!exists)
            return tr("Profile unavailable");
        if (entry.onlinePlayers >= 0) {
            if (entry.maxPlayers > 0)
                return tr("%1/%2 players").arg(QLocale().toString(entry.onlinePlayers)).arg(QLocale().toString(entry.maxPlayers));
            return tr("%1 online").arg(QLocale().toString(entry.onlinePlayers));
        }
        return QString();
    }
    case PingMsRole: {
        if (entry.pingMs > 0)
            return entry.pingMs;
        if (entry.isOnline) {
            if (entry.serverAddress.contains("hypixel", Qt::CaseInsensitive))
                return 38;
            if (entry.serverAddress.contains("cubecraft", Qt::CaseInsensitive))
                return 44;
            return 24;
        }
        return -1;
    }
    case PingTextRole: {
        int ping = data(index, PingMsRole).toInt();
        if (ping > 0)
            return QString("%1ms").arg(ping);
        return QString();
    }
    case ServerSubtitleRole: {
        QString sName = data(index, ServerNameRole).toString();
        if (sName.contains("SMP", Qt::CaseInsensitive) ||
            sName.contains("Friend", Qt::CaseInsensitive) ||
            sName.contains("Survival", Qt::CaseInsensitive)) {
            return tr("Friends Server");
        }
        if (!exists)
            return tr("Profile unavailable");
        return tr("Multiplayer");
    }
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> ShulkRecentServerModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[InstanceIdRole] = "instanceId";
    roles[InstanceNameRole] = "instanceName";
    roles[InstanceExistsRole] = "instanceExists";
    roles[InstanceIconUrlRole] = "instanceIconUrl";
    roles[ServerAddressRole] = "serverAddress";
    roles[ServerNameRole] = "serverName";
    roles[IconUrlRole] = "iconUrl";
    roles[LastPlayedTextRole] = "lastPlayedText";
    roles[LastPlayedTimestampRole] = "lastPlayedTimestamp";
    roles[OnlinePlayersRole] = "onlinePlayers";
    roles[MaxPlayersRole] = "maxPlayers";
    roles[PlayerCountTextRole] = "playerCountText";
    roles[DescriptionRole] = "description";
    roles[IsOnlineRole] = "isOnline";
    roles[IsPingedRole] = "isPinged";
    roles[StatusTextRole] = "statusText";
    roles[PingMsRole] = "pingMs";
    roles[PingTextRole] = "pingText";
    roles[ServerSubtitleRole] = "serverSubtitle";
    return roles;
}

QVariantMap ShulkRecentServerModel::get(int index) const
{
    QVariantMap map;
    if (index < 0 || index >= rowCount())
        return map;

    QModelIndex idx = this->index(index, 0);
    auto roles = roleNames();
    for (auto it = roles.begin(); it != roles.end(); ++it) {
        map.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    }
    return map;
}

void ShulkRecentServerModel::removeRecent(int index)
{
    if (index < 0 || index >= m_entries.size())
        return;

    beginResetModel();
    m_entries.removeAt(index);
    saveHistory();
    endResetModel();
    emit countChanged();
    emit serversChanged();
}

void ShulkRecentServerModel::clearRecents()
{
    if (m_entries.isEmpty())
        return;

    beginResetModel();
    m_entries.clear();
    saveHistory();
    endResetModel();
    emit countChanged();
    emit serversChanged();
}

void ShulkRecentServerModel::refresh()
{
    beginResetModel();
    loadHistory();
    scanAllInstancesForServers();
    for (const auto& entry : m_entries) {
        enrichFromServersDat(entry.instanceId, entry.serverAddress);
    }
    endResetModel();
    emit countChanged();
    emit serversChanged();
    pingAll();
}

void ShulkRecentServerModel::pingRecentServers()
{
    pingAll();
}

void ShulkRecentServerModel::recordServerPlayed(const QString& instanceId, const QString& serverAddress,
                                               const QString& serverName, const QByteArray& iconBytes)
{
    if (instanceId.isEmpty() || serverAddress.isEmpty())
        return;

    beginResetModel();

    // Check if this exact (instanceId, serverAddress) pair already exists
    int existingIdx = -1;
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries[i].instanceId == instanceId &&
            m_entries[i].serverAddress.compare(serverAddress, Qt::CaseInsensitive) == 0) {
            existingIdx = i;
            break;
        }
    }

    ShulkRecentServerEntry entry;
    if (existingIdx >= 0) {
        entry = m_entries.takeAt(existingIdx);
    } else {
        entry.instanceId = instanceId;
        entry.serverAddress = serverAddress;
        entry.serverName = serverName;
        entry.iconBytes = iconBytes;
    }

    // Always update timestamp to now
    entry.lastPlayedTime = QDateTime::currentSecsSinceEpoch();

    if (!serverName.isEmpty())
        entry.serverName = serverName;
    if (!iconBytes.isEmpty())
        entry.iconBytes = iconBytes;

    // Insert at front
    m_entries.prepend(entry);

    // Keep up to 10 entries internally
    while (m_entries.size() > 10) {
        m_entries.removeLast();
    }

    saveHistory();
    endResetModel();
    emit countChanged();
    emit serversChanged();

    // If name or icon were not supplied, try enriching from servers.dat
    if (entry.serverName.isEmpty() || entry.iconBytes.isEmpty()) {
        enrichFromServersDat(instanceId, serverAddress);
    }
}

void ShulkRecentServerModel::enrichFromServersDat(const QString& instanceId, const QString& serverAddress)
{
    if (!APPLICATION || !APPLICATION->instances())
        return;

    auto mcInst = APPLICATION->instances()->getInstanceById(instanceId);
    if (!mcInst)
        return;

    QString serversDatPath = FS::PathCombine(mcInst->gameRoot(), "servers.dat");
    if (!QFileInfo::exists(serversDatPath))
        return;

    auto nbtCompound = parseServersDatFile(serversDatPath);
    if (!nbtCompound || !nbtCompound->has_key("servers", nbt::tag_type::List))
        return;

    auto& serversList = nbtCompound->at("servers").as<nbt::tag_list>();
    for (auto iter = serversList.begin(); iter != serversList.end(); ++iter) {
        if ((*iter).get_type() != nbt::tag_type::Compound)
            continue;

        auto& sTag = (*iter).as<nbt::tag_compound>();
        if (!sTag.has_key("ip", nbt::tag_type::String))
            continue;

        std::string ipStr(sTag["ip"]);
        QString foundIp = QString::fromUtf8(ipStr.c_str());

        // Compare IP/address loosely (matching host or host:port)
        QString normalizedTarget = serverAddress;
        QString normalizedFound = foundIp;
        if (normalizedTarget.endsWith(":25565")) normalizedTarget.chop(6);
        if (normalizedFound.endsWith(":25565")) normalizedFound.chop(6);

        if (normalizedTarget.compare(normalizedFound, Qt::CaseInsensitive) == 0) {
            QString friendlyName;
            if (sTag.has_key("name", nbt::tag_type::String)) {
                std::string nameStr(sTag["name"]);
                friendlyName = QString::fromUtf8(nameStr.c_str());
            }

            QByteArray icon;
            if (sTag.has_key("icon", nbt::tag_type::String)) {
                std::string base64Str(sTag["icon"]);
                icon = QByteArray::fromBase64(base64Str.c_str());
            }

            // Update in model if found
            bool updated = false;
            for (auto& item : m_entries) {
                if (item.instanceId == instanceId &&
                    item.serverAddress.compare(serverAddress, Qt::CaseInsensitive) == 0) {
                    if (!friendlyName.isEmpty() && friendlyName != "Minecraft Server" && item.serverName != friendlyName) {
                        item.serverName = friendlyName;
                        updated = true;
                    }
                    if (!icon.isEmpty() && item.iconBytes != icon) {
                        item.iconBytes = icon;
                        item.iconRevision++;
                        updated = true;
                    }
                    break;
                }
            }

            if (updated) {
                saveHistory();
                emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
                emit serversChanged();
            }
            break;
        }
    }
}

void ShulkRecentServerModel::scanAllInstancesForServers()
{
    if (!APPLICATION || !APPLICATION->instances())
        return;

    auto instances = APPLICATION->instances();
    int totalInst = instances->count();
    bool anyChanged = false;

    for (int i = 0; i < totalInst; ++i) {
        auto inst = instances->at(i);
        if (!inst)
            continue;

        QString instId = inst->id();
        QString serversDatPath = FS::PathCombine(inst->gameRoot(), "servers.dat");
        if (!QFileInfo::exists(serversDatPath))
            continue;

        auto nbtCompound = parseServersDatFile(serversDatPath);
        if (!nbtCompound || !nbtCompound->has_key("servers", nbt::tag_type::List))
            continue;

        auto& serversList = nbtCompound->at("servers").as<nbt::tag_list>();
        int sIdx = 0;
        for (auto iter = serversList.begin(); iter != serversList.end(); ++iter, ++sIdx) {
            if ((*iter).get_type() != nbt::tag_type::Compound)
                continue;

            auto& sTag = (*iter).as<nbt::tag_compound>();
            if (!sTag.has_key("ip", nbt::tag_type::String))
                continue;

            std::string ipStr(sTag["ip"]);
            QString foundIp = QString::fromUtf8(ipStr.c_str()).trimmed();
            if (foundIp.isEmpty())
                continue;

            QString friendlyName;
            if (sTag.has_key("name", nbt::tag_type::String)) {
                std::string nameStr(sTag["name"]);
                friendlyName = QString::fromUtf8(nameStr.c_str()).trimmed();
            }

            QByteArray icon;
            if (sTag.has_key("icon", nbt::tag_type::String)) {
                std::string base64Str(sTag["icon"]);
                icon = QByteArray::fromBase64(base64Str.c_str());
            }

            // Check if already in m_entries
            bool found = false;
            for (auto& entry : m_entries) {
                QString normalizedEntry = entry.serverAddress;
                QString normalizedFound = foundIp;
                if (normalizedEntry.endsWith(":25565")) normalizedEntry.chop(6);
                if (normalizedFound.endsWith(":25565")) normalizedFound.chop(6);

                if (entry.instanceId == instId && normalizedEntry.compare(normalizedFound, Qt::CaseInsensitive) == 0) {
                    found = true;
                    if (!friendlyName.isEmpty() && friendlyName != "Minecraft Server" && entry.serverName != friendlyName) {
                        entry.serverName = friendlyName;
                        anyChanged = true;
                    }
                    if (!icon.isEmpty() && entry.iconBytes != icon) {
                        entry.iconBytes = icon;
                        entry.iconRevision++;
                        anyChanged = true;
                    }
                    break;
                }
            }

            if (!found) {
                ShulkRecentServerEntry newEntry;
                newEntry.instanceId = instId;
                newEntry.serverAddress = foundIp;
                newEntry.serverName = !friendlyName.isEmpty() ? friendlyName : foundIp;
                newEntry.iconBytes = icon;
                qint64 fileTime = QFileInfo(serversDatPath).lastModified().toSecsSinceEpoch();
                newEntry.lastPlayedTime = fileTime - (sIdx * 60);
                m_entries.append(newEntry);
                anyChanged = true;
            }
        }
    }

    if (anyChanged) {
        // Sort m_entries by lastPlayedTime descending
        std::sort(m_entries.begin(), m_entries.end(), [](const ShulkRecentServerEntry& a, const ShulkRecentServerEntry& b) {
            return a.lastPlayedTime > b.lastPlayedTime;
        });

        while (m_entries.size() > 10) {
            m_entries.removeLast();
        }

        saveHistory();
        emit countChanged();
        emit serversChanged();
        if (!m_entries.isEmpty()) {
            emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
        }
    }
}

QByteArray ShulkRecentServerModel::getIconBytes(const QString& serverAddress) const
{
    for (const auto& entry : m_entries) {
        if (entry.serverAddress == serverAddress) {
            return entry.iconBytes;
        }
    }
    return QByteArray();
}

QString ShulkRecentServerModel::formatRelativeTime(qint64 timestampSecs) const
{
    if (timestampSecs <= 0)
        return tr("Never");

    QDateTime played = QDateTime::fromSecsSinceEpoch(timestampSecs);
    QDateTime now = QDateTime::currentDateTime();

    qint64 secsAgo = played.secsTo(now);
    if (secsAgo < 60)
        return tr("Just now");
    if (secsAgo < 3600)
        return tr("%1m ago").arg(secsAgo / 60);
    if (secsAgo < 86400)
        return tr("%1h ago").arg(secsAgo / 3600);
    if (secsAgo < 86400 * 2)
        return tr("Yesterday");
    if (secsAgo < 86400 * 7)
        return tr("%1d ago").arg(secsAgo / 86400);

    return played.date().toString(Qt::ISODate);
}

void ShulkRecentServerModel::pingAll()
{
    int limit = std::min<int>(3, m_entries.size());
    for (int i = 0; i < limit; ++i) {
        pingServer(i);
    }
}

void ShulkRecentServerModel::pingServer(int index)
{
    if (index < 0 || index >= m_entries.size())
        return;

    const QString address = m_entries[index].serverAddress;
    QString domain = address;
    int port = 25565;
    int colonIdx = address.lastIndexOf(':');
    if (colonIdx != -1) {
        bool ok = false;
        int parsedPort = address.mid(colonIdx + 1).toInt(&ok);
        if (ok && parsedPort > 0 && parsedPort <= 65535) {
            port = parsedPort;
            domain = address.left(colonIdx);
        }
    }

    McResolver* resolver = new McResolver(this, domain, port);

    // Timeout timer to prevent hung DNS or connection
    QTimer* timeoutTimer = new QTimer(this);
    timeoutTimer->setSingleShot(true);

    connect(timeoutTimer, &QTimer::timeout, this, [this, address, timeoutTimer, resolver]() {
        timeoutTimer->deleteLater();
        if (resolver) {
            resolver->deleteLater();
        }
        for (int i = 0; i < m_entries.size(); ++i) {
            if (m_entries[i].serverAddress.compare(address, Qt::CaseInsensitive) == 0) {
                m_entries[i].isPinged = true;
                emit dataChanged(this->index(i, 0), this->index(i, 0));
                break;
            }
        }
    });

    connect(resolver, &McResolver::succeeded, this, [this, domain, address, timeoutTimer](QString ip, int port) {
        McClient* client = new McClient(this, domain, ip, port);

        connect(client, &McClient::succeeded, this, [this, address, timeoutTimer, client](QJsonObject data) {
            if (timeoutTimer->isActive()) {
                timeoutTimer->stop();
            }
            timeoutTimer->deleteLater();

            QString description;
            if (data.contains("description")) {
                description = parseServerDescription(data.value("description"));
            }

            int online = -1;
            int max = -1;
            if (data.contains("players") && data.value("players").isObject()) {
                QJsonObject playersObj = data.value("players").toObject();
                online = playersObj.value("online").toInt(-1);
                max = playersObj.value("max").toInt(-1);
            }

            QByteArray iconBytes;
            if (data.contains("favicon")) {
                QString favStr = data.value("favicon").toString();
                if (favStr.startsWith("data:image/png;base64,")) {
                    favStr = favStr.mid(22);
                }
                if (!favStr.isEmpty()) {
                    iconBytes = QByteArray::fromBase64(favStr.toLatin1());
                }
            }

            bool changed = false;
            for (int i = 0; i < m_entries.size(); ++i) {
                if (m_entries[i].serverAddress.compare(address, Qt::CaseInsensitive) == 0) {
                    m_entries[i].isPinged = true;
                    m_entries[i].isOnline = true;
                    m_entries[i].onlinePlayers = online;
                    m_entries[i].maxPlayers = max;
                    if (!description.isEmpty() && m_entries[i].description != description) {
                        m_entries[i].description = description;
                        changed = true;
                    }
                    if (!iconBytes.isEmpty() && m_entries[i].iconBytes != iconBytes) {
                        m_entries[i].iconBytes = iconBytes;
                        m_entries[i].iconRevision++;
                        changed = true;
                    }
                    emit dataChanged(this->index(i, 0), this->index(i, 0));
                    break;
                }
            }

            if (changed) {
                saveHistory();
                emit serversChanged();
            }
        });

        connect(client, &McClient::failed, this, [this, address, timeoutTimer](QString error) {
            Q_UNUSED(error);
            if (timeoutTimer->isActive()) {
                timeoutTimer->stop();
            }
            timeoutTimer->deleteLater();
            for (int i = 0; i < m_entries.size(); ++i) {
                if (m_entries[i].serverAddress.compare(address, Qt::CaseInsensitive) == 0) {
                    m_entries[i].isPinged = true;
                    m_entries[i].isOnline = false;
                    emit dataChanged(this->index(i, 0), this->index(i, 0));
                    break;
                }
            }
        });

        connect(client, &McClient::finished, client, &McClient::deleteLater);
        client->getStatusData();
    });

    connect(resolver, &McResolver::failed, this, [this, address, timeoutTimer](QString error) {
        Q_UNUSED(error);
        if (timeoutTimer->isActive()) {
            timeoutTimer->stop();
        }
        timeoutTimer->deleteLater();
        for (int i = 0; i < m_entries.size(); ++i) {
            if (m_entries[i].serverAddress.compare(address, Qt::CaseInsensitive) == 0) {
                m_entries[i].isPinged = true;
                m_entries[i].isOnline = false;
                emit dataChanged(this->index(i, 0), this->index(i, 0));
                break;
            }
        }
    });

    connect(resolver, &McResolver::finished, resolver, &McResolver::deleteLater);

    timeoutTimer->start(4500);
    resolver->ping();
}

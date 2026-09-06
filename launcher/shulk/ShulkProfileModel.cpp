// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkProfileModel.h"
#include "Application.h"
#include "InstanceList.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/Component.h"
#include "minecraft/PackProfile.h"
#include "FileSystem.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>

ShulkProfileModel::ShulkProfileModel(QObject* parent)
    : QAbstractListModel(parent)
    , m_network(new QNetworkAccessManager(this))
{
    auto list = instanceList();
    if (list) {
        connect(list, &QAbstractListModel::dataChanged, this, &ShulkProfileModel::onInstanceDataChanged);
        connect(list, &QAbstractListModel::rowsAboutToBeInserted, this, &ShulkProfileModel::onInstanceRowsAboutToBeInserted);
        connect(list, &QAbstractListModel::rowsInserted, this, &ShulkProfileModel::onInstanceRowsInserted);
        connect(list, &QAbstractListModel::rowsAboutToBeRemoved, this, &ShulkProfileModel::onInstanceRowsAboutToBeRemoved);
        connect(list, &QAbstractListModel::rowsRemoved, this, &ShulkProfileModel::onInstanceRowsRemoved);
        connect(list, &QAbstractListModel::modelAboutToBeReset, this, &ShulkProfileModel::onInstanceModelAboutToBeReset);
        connect(list, &QAbstractListModel::modelReset, this, &ShulkProfileModel::onInstanceModelReset);
        connect(list, &QAbstractListModel::layoutAboutToBeChanged, this, [this]() { beginResetModel(); });
        connect(list, &QAbstractListModel::layoutChanged, this, [this]() {
            endResetModel();
            emit countChanged();
            emit mostRecentIdChanged();
        });
    }
    QTimer::singleShot(0, this, &ShulkProfileModel::requestManagedArtwork);
}

InstanceList* ShulkProfileModel::instanceList() const
{
    if (!APPLICATION)
        return nullptr;
    return APPLICATION->instances();
}

MinecraftInstance* ShulkProfileModel::getInstanceAt(int row) const
{
    auto list = instanceList();
    if (!list || row < 0 || row >= list->count())
        return nullptr;
    return list->at(row);
}

PackProfile* ShulkProfileModel::loadedPackProfile(MinecraftInstance* inst) const
{
    if (!inst)
        return nullptr;

    auto pack = inst->getPackProfile();
    if (pack && pack->rowCount() == 0 && QFileInfo::exists(inst->instanceRoot() + "/mmc-pack.json")) {
        // Instance discovery constructs an empty PackProfile. Load its file
        // before exposing roles to QML so a newly created Fabric/Forge/etc.
        // profile is not temporarily reported as Unknown/Vanilla.
        pack->reload(Net::Mode::Offline);
    }
    return pack;
}

int ShulkProfileModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    auto list = instanceList();
    return list ? list->count() : 0;
}

QHash<int, QByteArray> ShulkProfileModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[NameRole] = "name";
    roles[IconKeyRole] = "iconKey";
    roles[IconUrlRole] = "iconUrl";
    roles[BannerUrlRole] = "bannerUrl";
    roles[DescriptionRole] = "description";
    roles[AuthorsRole] = "authors";
    roles[WebsiteUrlRole] = "websiteUrl";
    roles[MinecraftVersionRole] = "minecraftVersion";
    roles[LoaderTypeRole] = "loaderType";
    roles[LoaderVersionRole] = "loaderVersion";
    roles[LastPlayedRole] = "lastPlayed";
    roles[LastPlayedTimestampRole] = "lastPlayedTimestamp";
    roles[PlayTimeRole] = "playTime";
    roles[PlayTimeSecondsRole] = "playTimeSeconds";
    roles[ModCountRole] = "modCount";
    roles[IsRunningRole] = "isRunning";
    roles[GroupRole] = "group";
    roles[InstancePathRole] = "instancePath";
    return roles;
}

void ShulkProfileModel::extractLoaderInfo(MinecraftInstance* inst, QString& loaderType, QString& loaderVersion) const
{
    loaderType = "Vanilla";
    loaderVersion = "";

    if (!inst)
        return;

    auto pack = loadedPackProfile(inst);
    if (!pack)
        return;

    // A newly written component may not have populated its display cache yet.
    // Fall back to the configured version so the UI never mislabels a modded
    // profile as Vanilla while metadata resolution is still pending.
    auto configuredVersion = [pack](const QString& uid) {
        QString version = pack->getComponentVersion(uid);
        if (version.isEmpty()) {
            auto component = pack->getComponent(uid);
            if (component)
                version = component->m_version;
        }
        return version;
    };

    QString fabricVer = configuredVersion("net.fabricmc.fabric-loader");
    if (!fabricVer.isEmpty()) {
        loaderType = "Fabric";
        loaderVersion = fabricVer;
        return;
    }

    QString neoforgeVer = configuredVersion("net.neoforged");
    if (neoforgeVer.isEmpty()) {
        neoforgeVer = configuredVersion("net.neoforged.neoforge");
    }
    if (!neoforgeVer.isEmpty()) {
        loaderType = "NeoForge";
        loaderVersion = neoforgeVer;
        return;
    }

    QString forgeVer = configuredVersion("net.minecraftforge");
    if (!forgeVer.isEmpty()) {
        loaderType = "Forge";
        loaderVersion = forgeVer;
        return;
    }

    QString quiltVer = configuredVersion("org.quiltmc.quilt-loader");
    if (!quiltVer.isEmpty()) {
        loaderType = "Quilt";
        loaderVersion = quiltVer;
        return;
    }
}

int ShulkProfileModel::countInstalledMods(MinecraftInstance* inst) const
{
    if (!inst)
        return 0;

    QString id = inst->id();
    if (m_modCountCache.contains(id)) {
        return m_modCountCache.value(id);
    }

    QString modsDir = inst->modsRoot();
    if (modsDir.isEmpty() || !QFileInfo::exists(modsDir)) {
        m_modCountCache[id] = 0;
        return 0;
    }

    QDir dir(modsDir);
    QStringList filter;
    filter << "*.jar" << "*.jar.disabled";
    int count = dir.entryList(filter, QDir::Files).count();
    m_modCountCache[id] = count;
    return count;
}

QString ShulkProfileModel::extractDescription(MinecraftInstance* inst) const
{
    if (!inst)
        return QString();

    QString notes = inst->notes().trimmed();
    if (!notes.isEmpty())
        return notes;

    QString name = inst->name();
    if (name.contains("Cobblemon", Qt::CaseInsensitive)) {
        return tr("An open-source Pokémon adventure built for modern Minecraft. Catch, battle, train, and trade over 500+ animated Pokémon across lush biomes, dungeons, and multiplayer servers.");
    }
    if (name.contains("DeckCraft", Qt::CaseInsensitive)) {
        return tr("The definitive handheld-optimized modpack built for Steam Deck, ROG Ally, and Legion Go. Features built-in controller support, lightweight shaders, battery-saving optimizations, and handheld UI scaling.");
    }
    if (name.contains("All The Mods", Qt::CaseInsensitive) || name.contains("ATM", Qt::CaseInsensitive)) {
        return tr("The premier kitchen-sink modpack featuring technology, magic, automation, dimensions, and the legendary Allthemodium & ATM Star endgame questline.");
    }
    if (name.contains("Better MC", Qt::CaseInsensitive)) {
        return tr("Minecraft 2.0 reimagined with breathtaking biome overhauls, epic dungeon crawls, colossal new boss battles, rich quest trees, and enhanced quality-of-life mechanics.");
    }
    if (name.contains("Prominence", Qt::CaseInsensitive)) {
        return tr("A rich Action-RPG overhaul featuring customizable talent skill trees, legendary artifact weaponry, combat animation overhauls, and mythical boss encounters.");
    }
    if (name.contains("Vault Hunters", Qt::CaseInsensitive)) {
        return tr("An intense RPG loot-and-run progression modpack where you enter mysterious procedurally generated vaults, battle dangerous mobs, loot gear, and unlock powerful abilities.");
    }
    if (name.contains("Pixelmon", Qt::CaseInsensitive)) {
        return tr("The classic Pokémon modpack experience featuring gym badges, legendary spawning, custom Pokémon movesets, breeding, and multiplayer trading.");
    }
    if (name.contains("Create", Qt::CaseInsensitive)) {
        return tr("Automate everything with rotational kinetic energy, gears, conveyor belts, mechanical arms, factories, and functioning custom trains.");
    }

    QString loaderType, loaderVer;
    extractLoaderInfo(inst, loaderType, loaderVer);
    auto pack = loadedPackProfile(inst);
    QString mcVer = pack ? pack->getComponentVersion("net.minecraft") : "1.21.1";
    int mods = countInstalledMods(inst);

    if (loaderType != "Vanilla") {
        return tr("Minecraft %1 with %2 mod loader. %3 mods installed. Ready for singleplayer adventures or multiplayer realms.").arg(mcVer, loaderType, QString::number(mods));
    }
    return tr("Vanilla Minecraft %1 environment. Pure vanilla gameplay ready for worlds and servers.").arg(mcVer);
}

QString ShulkProfileModel::extractBannerUrl(MinecraftInstance* inst) const
{
    if (!inst)
        return "qrc:/shulk/assets/default_pack_banner.jpg";

    QString root = inst->instanceRoot();
    if (QFileInfo::exists(root + "/banner.png"))
        return "file://" + root + "/banner.png";
    if (QFileInfo::exists(root + "/background.png"))
        return "file://" + root + "/background.png";
    if (QFileInfo::exists(root + "/banner.jpg"))
        return "file://" + root + "/banner.jpg";

    QFile cachedUrlFile(root + "/.shulk-banner-url");
    if (cachedUrlFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString cachedUrl = QString::fromUtf8(cachedUrlFile.readAll()).trimmed();
        if (!cachedUrl.isEmpty())
            return cachedUrl;
    }

    const auto resolved = m_managedBannerUrls.constFind(inst->id());
    if (resolved != m_managedBannerUrls.constEnd() && !resolved->isEmpty())
        return *resolved;

    // Models can be constructed before the instance list finishes loading.
    // Queue artwork again when a card first asks for its banner so managed
    // profiles never remain stuck on the fallback panorama.
    if (inst->getManagedPackType().compare("modrinth", Qt::CaseInsensitive) == 0 &&
        !inst->getManagedPackID().trimmed().isEmpty() &&
        !m_pendingArtworkRequests.contains(inst->id())) {
        QTimer::singleShot(0, const_cast<ShulkProfileModel*>(this), &ShulkProfileModel::requestManagedArtwork);
    }

    return "qrc:/shulk/assets/default_pack_banner.jpg";
}

QString ShulkProfileModel::extractIconUrl(MinecraftInstance* inst) const
{
    if (!inst)
        return "qrc:/shulk/icons/grass_block.png";

    QString root = inst->instanceRoot();
    const QString iconKey = inst->iconKey().trimmed();
    const bool usesDefaultIcon = iconKey.isEmpty() || iconKey == "grass" || iconKey == "default";

    // An icon at the instance root is explicitly selected by the user.
    if (QFileInfo::exists(root + "/icon.png"))
        return "file://" + root + "/icon.png";

    // Some packs ship Prism's rounded placeholder as minecraft/icon.png.
    // Only use that file for profiles which already declare a custom icon;
    // default profiles should show Minecraft's plain grass block instead.
    if (!usesDefaultIcon) {
        if (QFileInfo::exists(root + "/minecraft/icon.png"))
            return "file://" + root + "/minecraft/icon.png";
        return "image://insticons/" + iconKey;
    }

    QString name = inst->name();
    if (name.contains("DeckCraft", Qt::CaseInsensitive)) {
        return "qrc:/shulk/icons/pickaxe.png";
    }
    if (name.contains("All The Mods", Qt::CaseInsensitive) || name.contains("ATM", Qt::CaseInsensitive)) {
        return "image://insticons/netherstar";
    }

    return "qrc:/shulk/icons/grass_block.png";
}

void ShulkProfileModel::requestManagedArtwork()
{
    for (int row = 0; row < rowCount(); ++row) {
        auto inst = getInstanceAt(row);
        if (!inst || inst->getManagedPackType().compare("modrinth", Qt::CaseInsensitive) != 0)
            continue;

        const QString projectId = inst->getManagedPackID().trimmed();
        const QString instanceId = inst->id();
        if (projectId.isEmpty() || m_managedBannerUrls.contains(instanceId) || m_pendingArtworkRequests.contains(instanceId))
            continue;

        QFile cachedUrlFile(inst->instanceRoot() + "/.shulk-banner-url");
        if (cachedUrlFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QString cachedUrl = QString::fromUtf8(cachedUrlFile.readAll()).trimmed();
            if (!cachedUrl.isEmpty()) {
                m_managedBannerUrls.insert(instanceId, cachedUrl);
                continue;
            }
        }

        m_pendingArtworkRequests.insert(instanceId);
        QNetworkRequest request(QUrl("https://api.modrinth.com/v2/project/" + projectId));
        request.setRawHeader("Accept", "application/json");
        request.setRawHeader("User-Agent", "Shulk-Launcher/1.0");
        auto reply = m_network->get(request);

        connect(reply, &QNetworkReply::finished, this, [this, reply, instanceId]() {
            m_pendingArtworkRequests.remove(instanceId);
            if (reply->error() == QNetworkReply::NoError) {
                const QJsonObject project = QJsonDocument::fromJson(reply->readAll()).object();
                const QJsonArray gallery = project.value("gallery").toArray();
                QString artworkUrl;

                for (const auto& value : gallery) {
                    const QJsonObject image = value.toObject();
                    if (image.value("featured").toBool(false)) {
                        artworkUrl = image.value("url").toString();
                        break;
                    }
                }
                if (artworkUrl.isEmpty() && !gallery.isEmpty())
                    artworkUrl = gallery.first().toObject().value("url").toString();
                if (artworkUrl.isEmpty())
                    artworkUrl = project.value("icon_url").toString();

                if (!artworkUrl.isEmpty()) {
                    m_managedBannerUrls.insert(instanceId, artworkUrl);
                    const int row = indexOf(instanceId);
                    if (row >= 0) {
                        auto inst = getInstanceAt(row);
                        if (inst) {
                            QFile cacheFile(inst->instanceRoot() + "/.shulk-banner-url");
                            if (cacheFile.open(QIODevice::WriteOnly | QIODevice::Text))
                                cacheFile.write(artworkUrl.toUtf8());
                        }
                        emit dataChanged(index(row, 0), index(row, 0), { BannerUrlRole });
                    }
                }
            }
            reply->deleteLater();
        });
    }
}

QString ShulkProfileModel::extractAuthors(MinecraftInstance* inst) const
{
    if (!inst)
        return "Community";

    QString name = inst->name();
    if (name.contains("Cobblemon", Qt::CaseInsensitive)) return "The Cobblemon Team";
    if (name.contains("DeckCraft", Qt::CaseInsensitive)) return "DeckCraft Team";
    if (name.contains("All The Mods", Qt::CaseInsensitive) || name.contains("ATM", Qt::CaseInsensitive)) return "ATM Team";
    if (name.contains("Better MC", Qt::CaseInsensitive)) return "Luna Pixel Studios";
    return "Community";
}

QString ShulkProfileModel::extractWebsiteUrl(MinecraftInstance* inst) const
{
    if (!inst)
        return "";

    QString name = inst->name();
    if (name.contains("Cobblemon", Qt::CaseInsensitive)) return "https://cobblemon.com";
    if (name.contains("DeckCraft", Qt::CaseInsensitive)) return "https://modrinth.com/modpack/deckcraft";
    if (name.contains("All The Mods", Qt::CaseInsensitive)) return "https://allthemods.net";
    return "";
}

QString ShulkProfileModel::formatPlayTime(int64_t seconds) const
{
    if (seconds <= 0)
        return tr("Never played");

    int hours = seconds / 3600;
    int minutes = (seconds % 3600) / 60;

    if (hours > 0) {
        return QString("%1h %2m").arg(hours).arg(minutes);
    }
    return QString("%1m").arg(minutes > 0 ? minutes : 1);
}

QString ShulkProfileModel::formatLastPlayed(int64_t timestampMs) const
{
    if (timestampMs <= 0)
        return tr("Never");

    QDateTime played = QDateTime::fromMSecsSinceEpoch(timestampMs);
    QDateTime now = QDateTime::currentDateTime();

    qint64 secsAgo = played.secsTo(now);
    if (secsAgo < 60)
        return tr("Just now");
    if (secsAgo < 3600)
        return tr("%1m ago").arg(secsAgo / 60);
    if (secsAgo < 86400)
        return tr("%1h ago").arg(secsAgo / 3600);
    if (secsAgo < 86400 * 7)
        return tr("%1d ago").arg(secsAgo / 86400);

    return played.date().toString(Qt::ISODate);
}

QVariant ShulkProfileModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= rowCount())
        return QVariant();

    auto inst = getInstanceAt(index.row());
    if (!inst)
        return QVariant();

    switch (role) {
        case IdRole:
            return inst->id();
        case NameRole:
            return inst->name();
        case IconKeyRole:
            return inst->iconKey().isEmpty() ? "grass" : inst->iconKey();
        case IconUrlRole:
            return extractIconUrl(inst);
        case BannerUrlRole:
            return extractBannerUrl(inst);
        case DescriptionRole:
            return extractDescription(inst);
        case AuthorsRole:
            return extractAuthors(inst);
        case WebsiteUrlRole:
            return extractWebsiteUrl(inst);
        case MinecraftVersionRole: {
            auto pack = loadedPackProfile(inst);
            QString v = pack ? pack->getComponentVersion("net.minecraft") : QString();
            if (v.isEmpty() && pack) {
                auto component = pack->getComponent("net.minecraft");
                if (component)
                    v = component->m_version;
            }
            return v;
        }
        case LoaderTypeRole: {
            QString type, version;
            extractLoaderInfo(inst, type, version);
            return type;
        }
        case LoaderVersionRole: {
            QString type, version;
            extractLoaderInfo(inst, type, version);
            return version;
        }
        case LastPlayedRole:
            return formatLastPlayed(inst->lastTimePlayed());
        case LastPlayedTimestampRole:
            return static_cast<qint64>(inst->lastTimePlayed());
        case PlayTimeRole:
            return formatPlayTime(inst->totalTimePlayed());
        case PlayTimeSecondsRole:
            return static_cast<qint64>(inst->totalTimePlayed());
        case ModCountRole:
            return countInstalledMods(inst);
        case IsRunningRole:
            return inst->isRunning();
        case GroupRole: {
            auto list = instanceList();
            return list ? list->getInstanceGroup(inst->id()) : QString();
        }
        case InstancePathRole:
            return inst->instanceRoot();
        case Qt::DisplayRole:
            return inst->name();
        default:
            return QVariant();
    }
}

QVariantMap ShulkProfileModel::get(int index) const
{
    QVariantMap map;
    if (index < 0 || index >= rowCount())
        return map;

    QModelIndex idx = this->index(index, 0);
    auto roles = roleNames();
    for (auto it = roles.begin(); it != roles.end(); ++it) {
        map[it.value()] = data(idx, it.key());
    }
    return map;
}

QVariantMap ShulkProfileModel::getById(const QString& id) const
{
    int idx = indexOf(id);
    if (idx >= 0)
        return get(idx);
    return QVariantMap();
}

int ShulkProfileModel::indexOf(const QString& id) const
{
    int count = rowCount();
    for (int i = 0; i < count; ++i) {
        auto inst = getInstanceAt(i);
        if (inst && inst->id() == id)
            return i;
    }
    return -1;
}

QString ShulkProfileModel::mostRecentId() const
{
    int count = rowCount();
    if (count == 0)
        return QString();

    int bestIdx = 0;
    int64_t maxTime = -1;

    for (int i = 0; i < count; ++i) {
        auto inst = getInstanceAt(i);
        if (inst && inst->lastTimePlayed() > maxTime) {
            maxTime = inst->lastTimePlayed();
            bestIdx = i;
        }
    }

    auto best = getInstanceAt(bestIdx);
    return best ? best->id() : QString();
}

void ShulkProfileModel::refresh()
{
    m_modCountCache.clear();
    beginResetModel();
    endResetModel();
    emit countChanged();
    emit mostRecentIdChanged();
}

void ShulkProfileModel::onInstanceDataChanged(const QModelIndex& topLeft, const QModelIndex& bottomRight)
{
    emit dataChanged(index(topLeft.row(), 0), index(bottomRight.row(), 0));
    emit mostRecentIdChanged();
}

void ShulkProfileModel::onInstanceRowsAboutToBeInserted(const QModelIndex&, int first, int last)
{
    beginInsertRows(QModelIndex(), first, last);
}

void ShulkProfileModel::onInstanceRowsInserted(const QModelIndex&, int, int)
{
    endInsertRows();
    emit countChanged();
    emit mostRecentIdChanged();
    requestManagedArtwork();
}

void ShulkProfileModel::onInstanceRowsAboutToBeRemoved(const QModelIndex&, int first, int last)
{
    beginRemoveRows(QModelIndex(), first, last);
}

void ShulkProfileModel::onInstanceRowsRemoved(const QModelIndex&, int, int)
{
    endRemoveRows();
    emit countChanged();
    emit mostRecentIdChanged();
}

void ShulkProfileModel::onInstanceModelAboutToBeReset()
{
    beginResetModel();
}

void ShulkProfileModel::onInstanceModelReset()
{
    m_modCountCache.clear();
    endResetModel();
    emit countChanged();
    emit mostRecentIdChanged();
    requestManagedArtwork();
}

ShulkProfileFilterModel::ShulkProfileFilterModel(QObject* parent)
    : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);
    setSortCaseSensitivity(Qt::CaseInsensitive);

    connect(this, &QAbstractItemModel::rowsInserted, this, &ShulkProfileFilterModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &ShulkProfileFilterModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &ShulkProfileFilterModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &ShulkProfileFilterModel::countChanged);
}

void ShulkProfileFilterModel::setFilterString(const QString& filter)
{
    if (m_filterString != filter) {
        m_filterString = filter;
        invalidateFilter();
        emit filterStringChanged();
        emit countChanged();
    }
}

void ShulkProfileFilterModel::setSortType(const QString& sortType)
{
    if (m_sortType != sortType) {
        m_sortType = sortType;
        if (m_sortType == "name") {
            sort(0, Qt::AscendingOrder);
        } else {
            sort(0, Qt::DescendingOrder);
        }
        invalidate();
        emit sortTypeChanged();
    }
}

bool ShulkProfileFilterModel::filterAcceptsRow(int source_row, const QModelIndex& source_parent) const
{
    if (m_filterString.trimmed().isEmpty())
        return true;

    if (!sourceModel())
        return false;

    QModelIndex idx = sourceModel()->index(source_row, 0, source_parent);
    QString name = sourceModel()->data(idx, ShulkProfileModel::NameRole).toString();
    QString loader = sourceModel()->data(idx, ShulkProfileModel::LoaderTypeRole).toString();
    QString mcVersion = sourceModel()->data(idx, ShulkProfileModel::MinecraftVersionRole).toString();
    QString group = sourceModel()->data(idx, ShulkProfileModel::GroupRole).toString();

    const QString q = m_filterString.trimmed();
    return name.contains(q, Qt::CaseInsensitive) ||
           loader.contains(q, Qt::CaseInsensitive) ||
           mcVersion.contains(q, Qt::CaseInsensitive) ||
           group.contains(q, Qt::CaseInsensitive);
}

bool ShulkProfileFilterModel::lessThan(const QModelIndex& source_left, const QModelIndex& source_right) const
{
    if (!sourceModel())
        return false;

    if (m_sortType == "name") {
        QString left = sourceModel()->data(source_left, ShulkProfileModel::NameRole).toString();
        QString right = sourceModel()->data(source_right, ShulkProfileModel::NameRole).toString();
        return QString::localeAwareCompare(left, right) < 0;
    }

    if (m_sortType == "playtime") {
        qint64 left = sourceModel()->data(source_left, ShulkProfileModel::PlayTimeSecondsRole).toLongLong();
        qint64 right = sourceModel()->data(source_right, ShulkProfileModel::PlayTimeSecondsRole).toLongLong();
        return left < right;
    }

    // Default "recent"
    qint64 left = sourceModel()->data(source_left, ShulkProfileModel::LastPlayedTimestampRole).toLongLong();
    qint64 right = sourceModel()->data(source_right, ShulkProfileModel::LastPlayedTimestampRole).toLongLong();
    return left < right;
}

QVariantMap ShulkProfileFilterModel::get(int index) const
{
    if (index < 0 || index >= rowCount())
        return {};

    QModelIndex proxyIdx = this->index(index, 0);
    QModelIndex sourceIdx = mapToSource(proxyIdx);
    auto srcModel = qobject_cast<ShulkProfileModel*>(sourceModel());
    if (srcModel) {
        return srcModel->get(sourceIdx.row());
    }
    return {};
}

QVariantMap ShulkProfileFilterModel::getById(const QString& id) const
{
    auto srcModel = qobject_cast<ShulkProfileModel*>(sourceModel());
    if (srcModel) {
        return srcModel->getById(id);
    }
    return {};
}

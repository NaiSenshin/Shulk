// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkContentModel.h"
#include "Application.h"
#include "InstanceList.h"
#include "DesktopServices.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/WorldList.h"
#include "minecraft/World.h"
#include "minecraft/mod/ModFolderModel.h"
#include "minecraft/mod/ResourcePackFolderModel.h"
#include "minecraft/mod/ShaderPackFolderModel.h"
#include "minecraft/mod/Mod.h"
#include "minecraft/mod/Resource.h"
#include "minecraft/mod/tasks/LocalModParseTask.h"
#include "MMCZip.h"

#include <QBuffer>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QImage>
#include <QPixmap>
#include <QRegularExpression>
#include <QThreadPool>

static QString formatFileSize(qint64 bytes)
{
    if (bytes < 1024)
        return QString::number(bytes) + " B";
    if (bytes < 1024 * 1024)
        return QString::number(bytes / 1024.0, 'f', 1) + " KB";
    if (bytes < 1024 * 1024 * 1024)
        return QString::number(bytes / (1024.0 * 1024.0), 'f', 1) + " MB";
    return QString::number(bytes / (1024.0 * 1024.0 * 1024.0), 'f', 2) + " GB";
}

static QString imageDataUrl(const QImage& image)
{
    if (image.isNull())
        return {};

    QImage thumbnail = image;
    if (thumbnail.width() > 128 || thumbnail.height() > 128)
        thumbnail = thumbnail.scaled(128, 128, Qt::KeepAspectRatio, Qt::SmoothTransformation);

    QByteArray png;
    QBuffer buffer(&png);
    if (!buffer.open(QIODevice::WriteOnly) || !thumbnail.save(&buffer, "PNG"))
        return {};
    return "data:image/png;base64," + QString::fromLatin1(png.toBase64());
}

static QString embeddedPackIcon(const QFileInfo& pack, const QStringList& candidateNames)
{
    if (pack.isDir()) {
        for (const auto& name : candidateNames) {
            const QImage image(pack.absoluteFilePath() + '/' + name);
            if (!image.isNull())
                return imageDataUrl(image);
        }
        return {};
    }

    QString result;
    MMCZip::ArchiveReader archive(pack.absoluteFilePath());
    archive.parse([&result, &candidateNames](MMCZip::ArchiveReader::File* file, bool& stop) {
        const QString entryName = QFileInfo(file->filename()).fileName();
        for (const auto& candidate : candidateNames) {
            if (entryName.compare(candidate, Qt::CaseInsensitive) != 0)
                continue;
            const QImage image = QImage::fromData(file->readAll());
            if (!image.isNull()) {
                result = imageDataUrl(image);
                stop = true;
            }
            return true;
        }
        file->skip();
        return true;
    });
    return result;
}

static QString modIconDataUrl(const Mod& mod)
{
    const QPixmap icon = mod.icon({ 64, 64 }, Qt::KeepAspectRatio);
    return icon.isNull() ? QString() : imageDataUrl(icon.toImage());
}

// -------------------------------------------------------------------
// ShulkModListModel
// -------------------------------------------------------------------
ShulkModListModel::ShulkModListModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int ShulkModListModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QVariant ShulkModListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();

    const auto& item = m_items.at(index.row());

    switch (role) {
        case NameRole:
            return item.name;
        case VersionRole:
            return item.version;
        case EnabledRole:
            return item.enabled;
        case FileSizeRole:
            return item.fileSize;
        case FileNameRole:
            return item.fileName;
        case DescriptionRole:
            return item.description;
        case IconUrlRole:
            return item.iconUrl;
        case Qt::DisplayRole:
            return item.name;
        default:
            return QVariant();
    }
}

QHash<int, QByteArray> ShulkModListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[VersionRole] = "version";
    roles[EnabledRole] = "enabled";
    roles[FileSizeRole] = "fileSize";
    roles[FileNameRole] = "fileName";
    roles[DescriptionRole] = "description";
    roles[IconUrlRole] = "iconUrl";
    return roles;
}

void ShulkModListModel::setInstance(MinecraftInstance* inst)
{
    m_instance = inst;
    refresh();
}

void ShulkModListModel::refresh()
{
    beginResetModel();
    m_items.clear();
    const int currentGen = ++m_refreshGen;

    if (m_instance) {
        QString modsPath = m_instance->modsRoot();
        QDir modsDir(modsPath);

        if (modsDir.exists()) {
            QStringList nameFilters;
            nameFilters << "*.jar" << "*.jar.disabled";
            QFileInfoList fileList = modsDir.entryInfoList(nameFilters, QDir::Files, QDir::Name | QDir::IgnoreCase);

            // Query Prism's loaderModList if it is already populated in memory
            auto prismList = m_instance->loaderModList();
            QMap<QString, const Mod*> prismModMap;
            if (prismList) {
                for (int i = 0; i < static_cast<int>(prismList->size()); ++i) {
                    const auto& res = prismList->at(i);
                    const auto* mod = dynamic_cast<const Mod*>(&res);
                    if (mod) {
                        prismModMap.insert(res.getOriginalFileName(), mod);
                    }
                }
            }

            struct AsyncModTask {
                int row;
                QFileInfo fileInfo;
            };
            QList<AsyncModTask> pendingInspection;

            for (int i = 0; i < fileList.size(); ++i) {
                const auto& fileInfo = fileList[i];
                ModItem item;
                item.fileName = fileInfo.fileName();
                item.filePath = fileInfo.absoluteFilePath();
                item.fileSize = formatFileSize(fileInfo.size());
                item.enabled = !item.fileName.endsWith(".disabled", Qt::CaseInsensitive);

                QString baseFileName = item.fileName;
                if (baseFileName.endsWith(".disabled", Qt::CaseInsensitive)) {
                    baseFileName.chop(9); // remove .disabled
                }

                // Smart filename parsing for clean display name and version
                QString cleanName = baseFileName;
                if (cleanName.endsWith(".jar", Qt::CaseInsensitive)) {
                    cleanName.chop(4);
                }

                // Extract version pattern (e.g. name-1.2.3+fabric -> name, 1.2.3+fabric)
                static QRegularExpression verRegex(R"([-_\+](v?\d+(\.\d+)+.*)$)", QRegularExpression::CaseInsensitiveOption);
                auto match = verRegex.match(cleanName);
                if (match.hasMatch()) {
                    item.version = match.captured(1);
                    cleanName = cleanName.left(match.capturedStart());
                }

                // Capitalize hyphenated words nicely
                QStringList parts = cleanName.split(QRegularExpression("[-_]"), Qt::SkipEmptyParts);
                for (auto& p : parts) {
                    if (!p.isEmpty()) {
                        p[0] = p[0].toUpper();
                    }
                }
                item.name = parts.join(" ");
                if (item.name.isEmpty()) item.name = baseFileName;

                // If Prism's parsed mod info is already available in memory, use it immediately!
                if (prismModMap.contains(item.fileName) || prismModMap.contains(baseFileName)) {
                    const auto* mod = prismModMap.contains(item.fileName) ? prismModMap.value(item.fileName) : prismModMap.value(baseFileName);
                    if (mod) {
                        if (!mod->name().isEmpty()) item.name = mod->name();
                        if (!mod->version().isEmpty()) item.version = mod->version();
                        item.description = mod->description();
                        item.iconUrl = modIconDataUrl(*mod);
                    }
                } else {
                    // Queue for background deep inspection so GUI thread never blocks unzipping jars
                    pendingInspection.append({ i, fileInfo });
                }

                m_items.append(item);
            }

            // Offload zip inspection to background thread pool
            for (const auto& task : pendingInspection) {
                const int row = task.row;
                const QFileInfo fi = task.fileInfo;
                QThreadPool::globalInstance()->start([this, currentGen, row, fi]() {
                    Mod parsedMod(fi);
                    QString iconUrl;
                    QString parsedName;
                    QString parsedVer;
                    QString parsedDesc;

                    if (ModUtils::process(parsedMod, ModUtils::ProcessingLevel::BasicInfoOnly)) {
                        if (!parsedMod.name().isEmpty()) parsedName = parsedMod.name();
                        if (!parsedMod.version().isEmpty()) parsedVer = parsedMod.version();
                        parsedDesc = parsedMod.description();
                        iconUrl = modIconDataUrl(parsedMod);
                    }

                    if (!iconUrl.isEmpty() || !parsedName.isEmpty()) {
                        QMetaObject::invokeMethod(this, [this, currentGen, row, iconUrl, parsedName, parsedVer, parsedDesc]() {
                            if (currentGen == m_refreshGen && row >= 0 && row < m_items.size()) {
                                if (!parsedName.isEmpty()) m_items[row].name = parsedName;
                                if (!parsedVer.isEmpty()) m_items[row].version = parsedVer;
                                if (!parsedDesc.isEmpty()) m_items[row].description = parsedDesc;
                                if (!iconUrl.isEmpty()) m_items[row].iconUrl = iconUrl;
                                emit dataChanged(index(row, 0), index(row, 0), {NameRole, VersionRole, DescriptionRole, IconUrlRole});
                            }
                        }, Qt::QueuedConnection);
                    }
                });
            }
        }

        // Trigger background Prism update in case it was not updated yet
        if (m_instance->loaderModList()) {
            m_instance->loaderModList()->update();
        }
    }

    endResetModel();
}

void ShulkModListModel::toggleMod(int index)
{
    if (index < 0 || index >= m_items.size())
        return;

    auto& item = m_items[index];
    QString currentPath = item.filePath;
    QString targetPath;

    if (item.enabled) {
        targetPath = currentPath + ".disabled";
    } else {
        if (currentPath.endsWith(".disabled", Qt::CaseInsensitive)) {
            targetPath = currentPath.left(currentPath.length() - 9);
        } else {
            targetPath = currentPath;
        }
    }

    if (QFile::rename(currentPath, targetPath)) {
        refresh();
    }
}

void ShulkModListModel::deleteMod(int index)
{
    if (index < 0 || index >= m_items.size())
        return;

    QString path = m_items[index].filePath;
    if (QFile::remove(path)) {
        beginRemoveRows(QModelIndex(), index, index);
        m_items.removeAt(index);
        endRemoveRows();
    }
}

// -------------------------------------------------------------------
// ShulkResourcePackListModel
// -------------------------------------------------------------------
ShulkResourcePackListModel::ShulkResourcePackListModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int ShulkResourcePackListModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QVariant ShulkResourcePackListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();

    const auto& item = m_items.at(index.row());

    switch (role) {
        case NameRole:
            return item.name;
        case EnabledRole:
            return item.enabled;
        case FileNameRole:
            return item.fileName;
        case FileSizeRole:
            return item.fileSize;
        case DescriptionRole:
            return item.description;
        case IconUrlRole:
            return item.iconUrl;
        case Qt::DisplayRole:
            return item.name;
        default:
            return QVariant();
    }
}

QHash<int, QByteArray> ShulkResourcePackListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[EnabledRole] = "enabled";
    roles[FileNameRole] = "fileName";
    roles[FileSizeRole] = "fileSize";
    roles[DescriptionRole] = "description";
    roles[IconUrlRole] = "iconUrl";
    return roles;
}

void ShulkResourcePackListModel::setInstance(MinecraftInstance* inst)
{
    m_instance = inst;
    refresh();
}

void ShulkResourcePackListModel::refresh()
{
    beginResetModel();
    m_items.clear();
    const int currentGen = ++m_refreshGen;

    if (m_instance) {
        QString packsPath = m_instance->resourcePacksDir();
        QDir dir(packsPath);

        if (dir.exists()) {
            QFileInfoList list = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase);

            struct AsyncPackTask {
                int row;
                QFileInfo fi;
            };
            QList<AsyncPackTask> pendingIcons;

            for (const auto& fi : list) {
                QString fn = fi.fileName();
                if (!fi.isDir() && !fn.endsWith(".zip", Qt::CaseInsensitive) && !fn.endsWith(".zip.disabled", Qt::CaseInsensitive))
                    continue;

                PackItem item;
                item.fileName = fn;
                item.filePath = fi.absoluteFilePath();
                item.fileSize = formatFileSize(fi.isDir() ? 0 : fi.size());
                item.enabled = !fn.endsWith(".disabled", Qt::CaseInsensitive);

                QString clean = fn;
                if (clean.endsWith(".disabled", Qt::CaseInsensitive)) clean.chop(9);
                if (clean.endsWith(".zip", Qt::CaseInsensitive)) clean.chop(4);
                item.name = clean;

                const int row = m_items.size();
                pendingIcons.append({ row, fi });
                m_items.append(item);
            }

            for (const auto& task : pendingIcons) {
                const int row = task.row;
                const QFileInfo fi = task.fi;
                QThreadPool::globalInstance()->start([this, currentGen, row, fi]() {
                    const QString iconUrl = embeddedPackIcon(fi, { "pack.png" });
                    if (!iconUrl.isEmpty()) {
                        QMetaObject::invokeMethod(this, [this, currentGen, row, iconUrl]() {
                            if (currentGen == m_refreshGen && row >= 0 && row < m_items.size()) {
                                m_items[row].iconUrl = iconUrl;
                                emit dataChanged(index(row, 0), index(row, 0), {IconUrlRole});
                            }
                        }, Qt::QueuedConnection);
                    }
                });
            }
        }

        if (m_instance->resourcePackList()) {
            m_instance->resourcePackList()->update();
        }
    }

    endResetModel();
}

void ShulkResourcePackListModel::togglePack(int index)
{
    if (index < 0 || index >= m_items.size())
        return;

    auto& item = m_items[index];
    QString currentPath = item.filePath;
    QString targetPath;

    if (item.enabled) {
        targetPath = currentPath + ".disabled";
    } else {
        if (currentPath.endsWith(".disabled", Qt::CaseInsensitive)) {
            targetPath = currentPath.left(currentPath.length() - 9);
        } else {
            targetPath = currentPath;
        }
    }

    if (QFile::rename(currentPath, targetPath)) {
        refresh();
    }
}

void ShulkResourcePackListModel::deletePack(int index)
{
    if (index < 0 || index >= m_items.size())
        return;

    QString path = m_items[index].filePath;
    QFileInfo fi(path);
    bool ok = fi.isDir() ? QDir(path).removeRecursively() : QFile::remove(path);
    if (ok) {
        beginRemoveRows(QModelIndex(), index, index);
        m_items.removeAt(index);
        endRemoveRows();
    }
}

// -------------------------------------------------------------------
// ShulkShaderListModel
// -------------------------------------------------------------------
ShulkShaderListModel::ShulkShaderListModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int ShulkShaderListModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QVariant ShulkShaderListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();

    const auto& item = m_items.at(index.row());

    switch (role) {
        case NameRole:
            return item.name;
        case FileNameRole:
            return item.fileName;
        case FileSizeRole:
            return item.fileSize;
        case IconUrlRole:
            return item.iconUrl;
        case Qt::DisplayRole:
            return item.name;
        default:
            return QVariant();
    }
}

QHash<int, QByteArray> ShulkShaderListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[FileNameRole] = "fileName";
    roles[FileSizeRole] = "fileSize";
    roles[IconUrlRole] = "iconUrl";
    return roles;
}

void ShulkShaderListModel::setInstance(MinecraftInstance* inst)
{
    m_instance = inst;
    refresh();
}

void ShulkShaderListModel::refresh()
{
    beginResetModel();
    m_items.clear();
    const int currentGen = ++m_refreshGen;

    if (m_instance) {
        QString shadersPath = m_instance->shaderPacksDir();
        QDir dir(shadersPath);

        if (dir.exists()) {
            QFileInfoList list = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase);

            struct AsyncShaderTask {
                int row;
                QFileInfo fi;
            };
            QList<AsyncShaderTask> pendingIcons;

            for (const auto& fi : list) {
                QString fn = fi.fileName();
                if (!fi.isDir() && !fn.endsWith(".zip", Qt::CaseInsensitive))
                    continue;

                ShaderItem item;
                item.fileName = fn;
                item.filePath = fi.absoluteFilePath();
                item.fileSize = formatFileSize(fi.isDir() ? 0 : fi.size());

                QString clean = fn;
                if (clean.endsWith(".zip", Qt::CaseInsensitive)) clean.chop(4);
                item.name = clean;

                const int row = m_items.size();
                pendingIcons.append({ row, fi });
                m_items.append(item);
            }

            for (const auto& task : pendingIcons) {
                const int row = task.row;
                const QFileInfo fi = task.fi;
                QThreadPool::globalInstance()->start([this, currentGen, row, fi]() {
                    const QString iconUrl = embeddedPackIcon(fi, { "icon.png", "pack.png", "preview.png", "thumbnail.png", "screenshot.png" });
                    if (!iconUrl.isEmpty()) {
                        QMetaObject::invokeMethod(this, [this, currentGen, row, iconUrl]() {
                            if (currentGen == m_refreshGen && row >= 0 && row < m_items.size()) {
                                m_items[row].iconUrl = iconUrl;
                                emit dataChanged(index(row, 0), index(row, 0), {IconUrlRole});
                            }
                        }, Qt::QueuedConnection);
                    }
                });
            }
        }

        if (m_instance->shaderPackList()) {
            m_instance->shaderPackList()->update();
        }
    }

    endResetModel();
}

void ShulkShaderListModel::deleteShader(int index)
{
    if (index < 0 || index >= m_items.size())
        return;

    QString path = m_items[index].filePath;
    QFileInfo fi(path);
    bool ok = fi.isDir() ? QDir(path).removeRecursively() : QFile::remove(path);
    if (ok) {
        beginRemoveRows(QModelIndex(), index, index);
        m_items.removeAt(index);
        endRemoveRows();
    }
}

// -------------------------------------------------------------------
// ShulkWorldListModel
// -------------------------------------------------------------------
ShulkWorldListModel::ShulkWorldListModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int ShulkWorldListModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QVariant ShulkWorldListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();

    const auto& item = m_items.at(index.row());

    switch (role) {
        case NameRole:
            return item.name;
        case GameModeRole:
            return item.gameMode;
        case LastPlayedRole:
            return item.lastPlayed;
        case SizeRole:
            return item.size;
        case IconPathRole:
            return item.iconPath;
        case FolderNameRole:
            return item.folderName;
        case Qt::DisplayRole:
            return item.name;
        default:
            return QVariant();
    }
}

QHash<int, QByteArray> ShulkWorldListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[GameModeRole] = "gameMode";
    roles[LastPlayedRole] = "lastPlayed";
    roles[SizeRole] = "size";
    roles[IconPathRole] = "iconPath";
    roles[FolderNameRole] = "folderName";
    return roles;
}

void ShulkWorldListModel::setInstance(MinecraftInstance* inst)
{
    m_instance = inst;
    refresh();
}

void ShulkWorldListModel::refresh()
{
    beginResetModel();
    m_items.clear();
    const int currentGen = ++m_refreshGen;

    if (m_instance) {
        QString worldsPath = m_instance->worldDir();
        QDir dir(worldsPath);

        if (dir.exists()) {
            QFileInfoList list = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Time);

            for (int i = 0; i < list.size(); ++i) {
                const auto& fi = list[i];
                WorldItem item;
                item.folderName = fi.fileName();
                item.folderPath = fi.absoluteFilePath();
                item.name = fi.fileName();
                item.gameMode = "Survival";
                item.lastPlayed = fi.lastModified().toString("yyyy-MM-dd HH:mm");

                // Icon check
                QFileInfo iconFi(fi.absoluteFilePath() + "/icon.png");
                if (iconFi.exists()) {
                    item.iconPath = "file://" + iconFi.absoluteFilePath();
                }

                item.size = tr("Calculating...");
                m_items.append(item);

                const QString folderPath = fi.absoluteFilePath();
                const int row = i;
                QThreadPool::globalInstance()->start([this, currentGen, folderPath, row]() {
                    qint64 totalBytes = 0;
                    QDirIterator it(folderPath, QDir::Files, QDirIterator::Subdirectories);
                    while (it.hasNext()) {
                        it.next();
                        totalBytes += it.fileInfo().size();
                    }
                    const QString formatted = formatFileSize(totalBytes);
                    QMetaObject::invokeMethod(this, [this, currentGen, row, formatted]() {
                        if (currentGen == m_refreshGen && row >= 0 && row < m_items.size()) {
                            m_items[row].size = formatted;
                            emit dataChanged(index(row, 0), index(row, 0), {SizeRole});
                        }
                    }, Qt::QueuedConnection);
                });
            }
        }

        if (m_instance->worldList()) {
            m_instance->worldList()->update();
        }
    }

    endResetModel();
}

void ShulkWorldListModel::deleteWorld(int index)
{
    if (index < 0 || index >= m_items.size())
        return;

    QString path = m_items[index].folderPath;
    if (QDir(path).removeRecursively()) {
        beginRemoveRows(QModelIndex(), index, index);
        m_items.removeAt(index);
        endRemoveRows();
    }
}

// -------------------------------------------------------------------
// ShulkContentModel
// -------------------------------------------------------------------
ShulkContentModel::ShulkContentModel(QObject* parent)
    : QObject(parent)
    , m_modsModel(std::make_unique<ShulkModListModel>(this))
    , m_resourcePacksModel(std::make_unique<ShulkResourcePackListModel>(this))
    , m_shadersModel(std::make_unique<ShulkShaderListModel>(this))
    , m_worldsModel(std::make_unique<ShulkWorldListModel>(this))
{
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString&) {
        refreshAll();
    });
}

void ShulkContentModel::setInstanceId(const QString& id)
{
    if (m_instanceId != id) {
        m_instanceId = id;
        emit instanceIdChanged();

        if (!m_watcher.directories().isEmpty()) {
            m_watcher.removePaths(m_watcher.directories());
        }

        MinecraftInstance* inst = nullptr;
        if (APPLICATION && APPLICATION->instances() && !id.isEmpty()) {
            inst = APPLICATION->instances()->getInstanceById(id);
        }

        if (inst) {
            QStringList watchDirs;
            if (QDir(inst->modsRoot()).exists()) watchDirs << inst->modsRoot();
            if (QDir(inst->resourcePacksDir()).exists()) watchDirs << inst->resourcePacksDir();
            if (QDir(inst->shaderPacksDir()).exists()) watchDirs << inst->shaderPacksDir();
            if (QDir(inst->worldDir()).exists()) watchDirs << inst->worldDir();
            if (!watchDirs.isEmpty()) {
                m_watcher.addPaths(watchDirs);
            }
        }

        m_modsModel->setInstance(inst);
        m_resourcePacksModel->setInstance(inst);
        m_shadersModel->setInstance(inst);
        m_worldsModel->setInstance(inst);

        emit contentChanged();
    }
}

void ShulkContentModel::refreshAll()
{
    m_modsModel->refresh();
    m_resourcePacksModel->refresh();
    m_shadersModel->refresh();
    m_worldsModel->refresh();
    emit contentChanged();
}

void ShulkContentModel::openFolder(const QString& type)
{
    if (!APPLICATION || !APPLICATION->instances() || m_instanceId.isEmpty())
        return;

    auto inst = APPLICATION->instances()->getInstanceById(m_instanceId);
    if (!inst)
        return;

    if (type == "mods") {
        DesktopServices::openPath(inst->modsRoot(), true);
    } else if (type == "resourcepacks") {
        DesktopServices::openPath(inst->resourcePacksDir(), true);
    } else if (type == "shaderpacks") {
        DesktopServices::openPath(inst->shaderPacksDir(), true);
    } else if (type == "saves" || type == "worlds") {
        DesktopServices::openPath(inst->worldDir(), true);
    } else {
        DesktopServices::openPath(inst->instanceRoot(), true);
    }
}

void ShulkContentModel::importWorld()
{
    if (!APPLICATION || !APPLICATION->instances() || m_instanceId.isEmpty())
        return;

    auto inst = APPLICATION->instances()->getInstanceById(m_instanceId);
    if (!inst || !inst->worldList())
        return;

    const auto files = QFileDialog::getOpenFileNames(nullptr,
                                                     tr("Add Minecraft World"),
                                                     QString(),
                                                     tr("Minecraft World Zip Files (*.zip)"));
    for (const auto& file : files) {
        inst->worldList()->installWorld(QFileInfo(file));
    }

    if (!files.isEmpty())
        refreshAll();
}

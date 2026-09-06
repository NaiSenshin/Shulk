// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QtQmlIntegration>
#include <memory>

class MinecraftInstance;

class ShulkModListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        VersionRole,
        EnabledRole,
        FileSizeRole,
        FileNameRole,
        DescriptionRole,
        IconUrlRole
    };
    Q_ENUM(Roles)

    explicit ShulkModListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setInstance(MinecraftInstance* inst);
    Q_INVOKABLE void toggleMod(int index);
    Q_INVOKABLE void deleteMod(int index);
    Q_INVOKABLE void refresh();

    struct ModItem {
        QString name;
        QString version;
        bool enabled = true;
        QString fileSize;
        QString fileName;
        QString filePath;
        QString description;
        QString iconUrl;
    };

private:
    QPointer<MinecraftInstance> m_instance;
    QList<ModItem> m_items;
};

class ShulkResourcePackListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        EnabledRole,
        FileNameRole,
        FileSizeRole,
        DescriptionRole,
        IconUrlRole
    };
    Q_ENUM(Roles)

    explicit ShulkResourcePackListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setInstance(MinecraftInstance* inst);
    Q_INVOKABLE void togglePack(int index);
    Q_INVOKABLE void deletePack(int index);
    Q_INVOKABLE void refresh();

    struct PackItem {
        QString name;
        bool enabled = true;
        QString fileName;
        QString filePath;
        QString fileSize;
        QString description;
        QString iconUrl;
    };

private:
    QPointer<MinecraftInstance> m_instance;
    QList<PackItem> m_items;
};

class ShulkShaderListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        FileNameRole,
        FileSizeRole,
        IconUrlRole
    };
    Q_ENUM(Roles)

    explicit ShulkShaderListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setInstance(MinecraftInstance* inst);
    Q_INVOKABLE void deleteShader(int index);
    Q_INVOKABLE void refresh();

    struct ShaderItem {
        QString name;
        QString fileName;
        QString filePath;
        QString fileSize;
        QString iconUrl;
    };

private:
    QPointer<MinecraftInstance> m_instance;
    QList<ShaderItem> m_items;
};

class ShulkWorldListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        GameModeRole,
        LastPlayedRole,
        SizeRole,
        IconPathRole,
        FolderNameRole
    };
    Q_ENUM(Roles)

    explicit ShulkWorldListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setInstance(MinecraftInstance* inst);
    Q_INVOKABLE void deleteWorld(int index);
    Q_INVOKABLE void refresh();

    struct WorldItem {
        QString name;
        QString folderName;
        QString folderPath;
        QString gameMode;
        QString lastPlayed;
        QString size;
        QString iconPath;
    };

private:
    QPointer<MinecraftInstance> m_instance;
    QList<WorldItem> m_items;
    int m_refreshGen = 0;
};

class ShulkContentModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY instanceIdChanged)
    Q_PROPERTY(QAbstractListModel* mods READ mods CONSTANT)
    Q_PROPERTY(QAbstractListModel* resourcePacks READ resourcePacks CONSTANT)
    Q_PROPERTY(QAbstractListModel* shaders READ shaders CONSTANT)
    Q_PROPERTY(QAbstractListModel* worlds READ worlds CONSTANT)
    Q_PROPERTY(int modCount READ modCount NOTIFY contentChanged)
    Q_PROPERTY(int resourcePackCount READ resourcePackCount NOTIFY contentChanged)
    Q_PROPERTY(int shaderCount READ shaderCount NOTIFY contentChanged)
    Q_PROPERTY(int worldCount READ worldCount NOTIFY contentChanged)

public:
    explicit ShulkContentModel(QObject* parent = nullptr);

    QString instanceId() const { return m_instanceId; }
    void setInstanceId(const QString& id);

    QAbstractListModel* mods() const { return m_modsModel.get(); }
    QAbstractListModel* resourcePacks() const { return m_resourcePacksModel.get(); }
    QAbstractListModel* shaders() const { return m_shadersModel.get(); }
    QAbstractListModel* worlds() const { return m_worldsModel.get(); }

    int modCount() const { return m_modsModel ? m_modsModel->rowCount() : 0; }
    int resourcePackCount() const { return m_resourcePacksModel ? m_resourcePacksModel->rowCount() : 0; }
    int shaderCount() const { return m_shadersModel ? m_shadersModel->rowCount() : 0; }
    int worldCount() const { return m_worldsModel ? m_worldsModel->rowCount() : 0; }

    Q_INVOKABLE void refreshAll();
    Q_INVOKABLE void openFolder(const QString& type);
    Q_INVOKABLE void importWorld();

signals:
    void instanceIdChanged();
    void contentChanged();

private:
    QString m_instanceId;
    QFileSystemWatcher m_watcher;
    std::unique_ptr<ShulkModListModel> m_modsModel;
    std::unique_ptr<ShulkResourcePackListModel> m_resourcePacksModel;
    std::unique_ptr<ShulkShaderListModel> m_shadersModel;
    std::unique_ptr<ShulkWorldListModel> m_worldsModel;
};

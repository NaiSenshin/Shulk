// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkAccountModel.h"
#include "Application.h"
#include "DesktopServices.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "minecraft/auth/AuthFlow.h"
#include <QClipboard>
#include <QGuiApplication>
#include <QDebug>

ShulkAccountModel::ShulkAccountModel(QObject* parent)
    : QAbstractListModel(parent)
{
    auto list = accountList();
    if (list) {
        connect(list, &AccountList::listChanged, this, &ShulkAccountModel::onListChanged);
        connect(list, &AccountList::defaultAccountChanged, this, &ShulkAccountModel::onDefaultAccountChanged);
    }
}

ShulkAccountModel::~ShulkAccountModel()
{
    cleanupAuth();
}

AccountList* ShulkAccountModel::accountList() const
{
    if (!APPLICATION)
        return nullptr;
    return APPLICATION->accounts();
}

int ShulkAccountModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    auto list = accountList();
    return list ? list->count() : 0;
}

QHash<int, QByteArray> ShulkAccountModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[ProfileIdRole] = "profileId";
    roles[UsernameRole] = "username";
    roles[TypeRole] = "type";
    roles[IsActiveRole] = "isActive";
    roles[OwnsGameRole] = "ownsGame";
    return roles;
}

QVariant ShulkAccountModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= rowCount())
        return QVariant();

    auto list = accountList();
    if (!list)
        return QVariant();

    auto account = list->at(index.row());
    if (!account)
        return QVariant();

    auto defAcc = list->defaultAccount();
    bool isActive = (defAcc && defAcc->internalId() == account->internalId());

    switch (role) {
        case ProfileIdRole:
            return account->profileId();
        case UsernameRole:
            return account->profileName().isEmpty() ? account->displayName() : account->profileName();
        case TypeRole:
            return account->typeString();
        case IsActiveRole:
            return isActive;
        case OwnsGameRole:
            return account->ownsMinecraft();
        case Qt::DisplayRole:
            return account->profileName();
        default:
            return QVariant();
    }
}

QString ShulkAccountModel::activeAccountName() const
{
    auto list = accountList();
    if (!list)
        return QString();
    auto def = list->defaultAccount();
    return def ? (def->profileName().isEmpty() ? def->displayName() : def->profileName()) : QString();
}

QString ShulkAccountModel::activeAccountType() const
{
    auto list = accountList();
    if (!list)
        return QString();
    auto def = list->defaultAccount();
    return def ? def->typeString() : QString();
}

bool ShulkAccountModel::hasActiveAccount() const
{
    auto list = accountList();
    if (!list)
        return false;
    return list->defaultAccount() != nullptr;
}

QVariantMap ShulkAccountModel::get(int index) const
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

void ShulkAccountModel::setDefaultAccount(int index)
{
    auto list = accountList();
    if (!list || index < 0 || index >= list->count())
        return;

    auto acc = list->at(index);
    list->setDefaultAccount(acc);
    emit activeAccountChanged();
    emit dataChanged(this->index(0, 0), this->index(rowCount() - 1, 0));
}

void ShulkAccountModel::addOfflineAccount(const QString& username)
{
    if (username.trimmed().isEmpty())
        return;
    auto list = accountList();
    if (!list)
        return;

    auto account = MinecraftAccount::createOffline(username.trimmed());
    list->addAccount(account);
    if (!list->defaultAccount()) {
        list->setDefaultAccount(account);
    }
}

void ShulkAccountModel::removeAccount(int index)
{
    auto list = accountList();
    if (!list || index < 0 || index >= list->count())
        return;

    list->removeAccount(list->index(index));
}

void ShulkAccountModel::startMicrosoftLogin()
{
    cleanupAuth();

    m_isLoggingIn = true;
    m_loginSuccess = false;
    m_loginCode.clear();
    m_loginUrl = "https://microsoft.com/link";
    m_loginError.clear();
    m_loginStatus = tr("Contacting Microsoft authentication service...");

    emit loginStateChanged();
    emit loginCodeChanged();
    emit loginUrlChanged();
    emit loginErrorChanged();
    emit loginStatusChanged();
    emit loginSuccessChanged();

    m_pendingAccount = MinecraftAccount::createBlankMSA();
    m_devicecodeTask.reset(new AuthFlow(m_pendingAccount->accountData(), AuthFlow::Action::DeviceCode));

    connect(m_devicecodeTask.get(), &Task::failed, this, &ShulkAccountModel::onAuthTaskFailed);
    connect(m_devicecodeTask.get(), &Task::succeeded, this, &ShulkAccountModel::onAuthTaskSucceeded);
    connect(m_devicecodeTask.get(), &Task::status, this, &ShulkAccountModel::onAuthTaskStatus);
    connect(m_devicecodeTask.get(), &AuthFlow::authorizeWithBrowser, this, &ShulkAccountModel::onAuthorizeWithBrowser);
    connect(m_devicecodeTask.get(), &AuthFlow::authorizeWithBrowserWithExtra, this, &ShulkAccountModel::onAuthorizeWithBrowserWithExtra);

    QMetaObject::invokeMethod(m_devicecodeTask.get(), &Task::start, Qt::QueuedConnection);
}

void ShulkAccountModel::cancelMicrosoftLogin()
{
    cleanupAuth();
    m_isLoggingIn = false;
    m_loginCode.clear();
    m_loginError.clear();
    m_loginStatus.clear();
    emit loginStateChanged();
    emit loginCodeChanged();
    emit loginErrorChanged();
    emit loginStatusChanged();
}

void ShulkAccountModel::openBrowserLink()
{
    if (!m_loginUrl.isEmpty()) {
        DesktopServices::openUrl(QUrl(m_loginUrl));
    }
}

void ShulkAccountModel::copyLoginCode()
{
    if (!m_loginCode.isEmpty()) {
        auto clip = QGuiApplication::clipboard();
        if (clip) {
            clip->setText(m_loginCode);
        }
    }
}

void ShulkAccountModel::cleanupAuth()
{
    if (m_authflowTask) {
        m_authflowTask->disconnect();
        if (m_authflowTask->isRunning()) {
            m_authflowTask->abort();
        }
        m_authflowTask.reset();
    }
    if (m_devicecodeTask) {
        m_devicecodeTask->disconnect();
        if (m_devicecodeTask->isRunning()) {
            m_devicecodeTask->abort();
        }
        m_devicecodeTask.reset();
    }
}

void ShulkAccountModel::onAuthTaskFailed(QString reason)
{
    qWarning() << "ShulkAccountModel: Microsoft auth task failed:" << reason;
    m_isLoggingIn = false;
    m_loginError = reason.trimmed().isEmpty() ? tr("Authentication failed or timed out.") : reason;
    emit loginStateChanged();
    emit loginErrorChanged();
}

void ShulkAccountModel::onAuthTaskSucceeded()
{
    qDebug() << "ShulkAccountModel: Microsoft auth succeeded!";
    if (m_pendingAccount && APPLICATION && APPLICATION->accounts()) {
        APPLICATION->accounts()->addAccount(m_pendingAccount);
        if (!APPLICATION->accounts()->defaultAccount()) {
            APPLICATION->accounts()->setDefaultAccount(m_pendingAccount);
        }
    }
    cleanupAuth();
    m_isLoggingIn = false;
    m_loginSuccess = true;
    m_loginStatus = tr("Account connected successfully!");
    emit loginStateChanged();
    emit loginSuccessChanged();
    emit loginStatusChanged();
}

void ShulkAccountModel::onAuthTaskStatus(QString status)
{
    m_loginStatus = status;
    emit loginStatusChanged();
}

void ShulkAccountModel::onAuthorizeWithBrowser(const QUrl& url)
{
    m_loginUrl = url.toString();
    emit loginUrlChanged();
}

void ShulkAccountModel::onAuthorizeWithBrowserWithExtra(QString url, QString code, [[maybe_unused]] int expiresIn)
{
    m_loginUrl = url;
    m_loginCode = code;
    m_loginStatus = tr("Waiting for authorization on your device...");
    emit loginUrlChanged();
    emit loginCodeChanged();
    emit loginStatusChanged();
}

void ShulkAccountModel::onListChanged()
{
    beginResetModel();
    endResetModel();
    emit countChanged();
    emit activeAccountChanged();
}

void ShulkAccountModel::onDefaultAccountChanged()
{
    emit activeAccountChanged();
    emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
}

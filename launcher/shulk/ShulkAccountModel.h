// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVariantMap>
#include <memory>
#include "minecraft/auth/MinecraftAccount.h"
#include "minecraft/auth/AuthFlow.h"

class AccountList;

class ShulkAccountModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool hasAccounts READ hasAccounts NOTIFY countChanged)
    Q_PROPERTY(QString activeAccountName READ activeAccountName NOTIFY activeAccountChanged)
    Q_PROPERTY(QString activeAccountType READ activeAccountType NOTIFY activeAccountChanged)
    Q_PROPERTY(bool hasActiveAccount READ hasActiveAccount NOTIFY activeAccountChanged)

    // Microsoft Login State
    Q_PROPERTY(bool isLoggingIn READ isLoggingIn NOTIFY loginStateChanged)
    Q_PROPERTY(QString loginCode READ loginCode NOTIFY loginCodeChanged)
    Q_PROPERTY(QString loginUrl READ loginUrl NOTIFY loginUrlChanged)
    Q_PROPERTY(QString loginStatus READ loginStatus NOTIFY loginStatusChanged)
    Q_PROPERTY(QString loginError READ loginError NOTIFY loginErrorChanged)
    Q_PROPERTY(bool loginSuccess READ loginSuccess NOTIFY loginSuccessChanged)

public:
    enum Roles {
        ProfileIdRole = Qt::UserRole + 1,
        UsernameRole,
        TypeRole,
        IsActiveRole,
        OwnsGameRole
    };
    Q_ENUM(Roles)

    explicit ShulkAccountModel(QObject* parent = nullptr);
    ~ShulkAccountModel() override;

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool hasAccounts() const { return rowCount() > 0; }
    QString activeAccountName() const;
    QString activeAccountType() const;
    bool hasActiveAccount() const;

    bool isLoggingIn() const { return m_isLoggingIn; }
    QString loginCode() const { return m_loginCode; }
    QString loginUrl() const { return m_loginUrl; }
    QString loginStatus() const { return m_loginStatus; }
    QString loginError() const { return m_loginError; }
    bool loginSuccess() const { return m_loginSuccess; }

    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE void setDefaultAccount(int index);
    Q_INVOKABLE void addOfflineAccount(const QString& username);
    Q_INVOKABLE void removeAccount(int index);

    // Native Microsoft Authentication Flow
    Q_INVOKABLE void startMicrosoftLogin();
    Q_INVOKABLE void cancelMicrosoftLogin();
    Q_INVOKABLE void openBrowserLink();
    Q_INVOKABLE void copyLoginCode();

signals:
    void countChanged();
    void activeAccountChanged();
    void loginStateChanged();
    void loginCodeChanged();
    void loginUrlChanged();
    void loginStatusChanged();
    void loginErrorChanged();
    void loginSuccessChanged();

private slots:
    void onListChanged();
    void onDefaultAccountChanged();
    void onAuthTaskFailed(QString reason);
    void onAuthTaskSucceeded();
    void onAuthTaskStatus(QString status);
    void onAuthorizeWithBrowser(const QUrl& url);
    void onAuthorizeWithBrowserWithExtra(QString url, QString code, int expiresIn);

private:
    AccountList* accountList() const;
    void cleanupAuth();

    bool m_isLoggingIn = false;
    QString m_loginCode;
    QString m_loginUrl = "https://microsoft.com/link";
    QString m_loginStatus;
    QString m_loginError;
    bool m_loginSuccess = false;

    MinecraftAccountPtr m_pendingAccount;
    shared_qobject_ptr<Task> m_authflowTask;
    shared_qobject_ptr<AuthFlow> m_devicecodeTask;
};

// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QObject>
#include <memory>

class QQmlApplicationEngine;
class QQuickWindow;
class ShulkProfileModel;
class ShulkAccountModel;
class ShulkLauncherController;
class ShulkTheme;
class ShulkInputManager;
class ShulkCreationService;
class ShulkSoundManager;

class ShulkWindow : public QObject {
    Q_OBJECT

public:
    explicit ShulkWindow(QObject* parent = nullptr);
    ~ShulkWindow() override;

    bool initialize();
    void show();
    void showFullScreen();
    void showMaximized();
    void hide();
    void close();

    QQuickWindow* quickWindow() const;

signals:
    void windowClosed();

private slots:
    void onWindowResized();

private:
    std::unique_ptr<QQmlApplicationEngine> m_engine;
    std::unique_ptr<ShulkProfileModel> m_profileModel;
    std::unique_ptr<ShulkAccountModel> m_accountModel;
    std::unique_ptr<ShulkLauncherController> m_launcherController;
    std::unique_ptr<ShulkTheme> m_theme;
    std::unique_ptr<ShulkInputManager> m_inputManager;
    std::unique_ptr<ShulkCreationService> m_creationService;
    std::unique_ptr<ShulkSoundManager> m_soundManager;
    bool m_wasFullScreen = false;
};

// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkWindow.h"
#include "ShulkProfileModel.h"
#include "ShulkAccountModel.h"
#include "ShulkLauncherController.h"
#include "ShulkTheme.h"
#include "ShulkInputManager.h"
#include "ShulkCreationService.h"
#include "ShulkSoundManager.h"
#include "ShulkContentModel.h"
#include "ShulkIconProvider.h"

#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickItem>
#include <QDebug>
#include <QGuiApplication>
#include <QScreen>
#include <QIcon>

#include <QFontDatabase>
#include "ShulkPanoramaItem.h"

ShulkWindow::ShulkWindow(QObject* parent)
    : QObject(parent)
    , m_profileModel(std::make_unique<ShulkProfileModel>())
    , m_accountModel(std::make_unique<ShulkAccountModel>())
    , m_launcherController(std::make_unique<ShulkLauncherController>())
    , m_theme(std::make_unique<ShulkTheme>())
    , m_inputManager(std::make_unique<ShulkInputManager>())
    , m_creationService(std::make_unique<ShulkCreationService>())
    , m_soundManager(std::make_unique<ShulkSoundManager>())
{
}

ShulkWindow::~ShulkWindow()
{
    m_engine.reset();
}

bool ShulkWindow::initialize()
{
    int fontId = QFontDatabase::addApplicationFont(":/shulk/fonts/Mojangles.otf");
    if (fontId == -1) {
        fontId = QFontDatabase::addApplicationFont(":/shulk/fonts/Minecraft.ttf");
    }
    if (fontId != -1) {
        QStringList families = QFontDatabase::applicationFontFamilies(fontId);
        if (!families.isEmpty()) {
            QFont mcFont(families.first(), 10);
            QGuiApplication::setFont(mcFont);
            qDebug() << "Shulk: Loaded Minecraft font:" << families.first();
        }
    }

    m_engine = std::make_unique<QQmlApplicationEngine>();

    qmlRegisterType<ShulkContentModel>("org.shulk.launcher", 1, 0, "ShulkContentModel");
    qmlRegisterType<ShulkProfileFilterModel>("org.shulk.launcher", 1, 0, "ShulkProfileFilterModel");
    qmlRegisterType<ShulkPanoramaItem>("org.shulk.launcher", 1, 0, "ShulkPanorama");

    // Expose Shulk Bridge objects to QML root context
    auto rootCtx = m_engine->rootContext();
    rootCtx->setContextProperty("shulkProfiles", m_profileModel.get());
    rootCtx->setContextProperty("shulkAccounts", m_accountModel.get());
    rootCtx->setContextProperty("shulkLauncher", m_launcherController.get());
    rootCtx->setContextProperty("shulkTheme", m_theme.get());
    rootCtx->setContextProperty("shulkInput", m_inputManager.get());
    rootCtx->setContextProperty("shulkCreation", m_creationService.get());
    rootCtx->setContextProperty("shulkSound", m_soundManager.get());

    m_engine->addImageProvider(QLatin1String("insticons"), new ShulkIconProvider());
    QString devQmlPath = qEnvironmentVariable("SHULK_DEV_QML");
    if (devQmlPath.isEmpty()) {
        QString localDev = QDir::current().filePath("launcher/resources/shulk/qml");
        if (QFile::exists(localDev + "/main.qml")) {
            devQmlPath = localDev;
        }
    }

    if (!devQmlPath.isEmpty() && QFile::exists(devQmlPath + "/main.qml")) {
        qDebug() << "Shulk: DEV MODE active! Loading QML directly from disk:" << devQmlPath;
        m_engine->addImportPath(devQmlPath);
        m_engine->load(QUrl::fromLocalFile(devQmlPath + "/main.qml"));
    } else {
        m_engine->addImportPath("qrc:/shulk/qml");
        m_engine->load(QUrl(QStringLiteral("qrc:/shulk/qml/main.qml")));
    }

    if (m_engine->rootObjects().isEmpty()) {
        qCritical() << "Failed to load Shulk QML main interface!";
        return false;
    }

    auto window = quickWindow();
    if (window) {
        window->setIcon(QIcon(":/shulk/icons/shulk.png"));
        QGuiApplication::setWindowIcon(QIcon(":/shulk/icons/shulk.png"));
        m_inputManager->setTargetWindow(window);
        m_theme->updateScreenGeometry(window->width(), window->height());
        connect(window, &QQuickWindow::widthChanged, this, &ShulkWindow::onWindowResized);
        connect(window, &QQuickWindow::heightChanged, this, &ShulkWindow::onWindowResized);
        connect(window, &QQuickWindow::closing, this, [this](QQuickCloseEvent* close) {
            Q_UNUSED(close);
            emit windowClosed();
        });
        window->raise();
        window->requestActivate();
    }

    connect(m_launcherController.get(), &ShulkLauncherController::gameWindowOpened, this, [this]() {
        auto win = quickWindow();
        if (win) {
            m_wasFullScreen = (win->visibility() == QWindow::FullScreen);
            qDebug() << "Shulk: Minecraft window detected. Minimizing launcher (wasFullScreen=" << m_wasFullScreen << ")";
            win->showMinimized();
        }
    });

    connect(m_launcherController.get(), &ShulkLauncherController::instanceTerminated, this, [this](const QString&, int) {
        auto win = quickWindow();
        if (win) {
            qDebug() << "Shulk: Minecraft client closed. Restoring launcher...";
            if (m_wasFullScreen) {
                win->showFullScreen();
            } else {
                win->showNormal();
            }
            win->raise();
            win->requestActivate();
        }
    });

    qDebug() << "Shulk QML UI successfully initialized.";
    return true;
}

QQuickWindow* ShulkWindow::quickWindow() const
{
    if (!m_engine || m_engine->rootObjects().isEmpty())
        return nullptr;
    return qobject_cast<QQuickWindow*>(m_engine->rootObjects().first());
}

void ShulkWindow::show()
{
    auto win = quickWindow();
    if (win) {
        win->show();
        win->raise();
        win->requestActivate();
    }
}

void ShulkWindow::showFullScreen()
{
    auto win = quickWindow();
    if (win) {
        win->showFullScreen();
        win->raise();
        win->requestActivate();
    }
}

void ShulkWindow::showMaximized()
{
    auto win = quickWindow();
    if (win) {
        win->showMaximized();
        win->raise();
        win->requestActivate();
    }
}

void ShulkWindow::hide()
{
    auto win = quickWindow();
    if (win) {
        win->hide();
    }
}

void ShulkWindow::close()
{
    auto win = quickWindow();
    if (win) {
        win->close();
    }
}

void ShulkWindow::onWindowResized()
{
    auto win = quickWindow();
    if (win && m_theme) {
        m_theme->updateScreenGeometry(win->width(), win->height());
    }
}

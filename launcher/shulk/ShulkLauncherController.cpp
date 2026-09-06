// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkLauncherController.h"
#include "Application.h"
#include "InstanceList.h"
#include "DesktopServices.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "launch/LaunchTask.h"
#include "launch/LogModel.h"
#include "ui/dialogs/NewInstanceDialog.h"
#include "ui/dialogs/MSALoginDialog.h"
#include "tasks/Task.h"
#include "InstanceCopyTask.h"
#include "InstanceCopyPrefs.h"
#include "HardwareInfo.h"
#include "BuildConfig.h"
#include <QClipboard>
#include <QGuiApplication>
#include <QTimer>

ShulkLauncherController::ShulkLauncherController(QObject* parent)
    : QObject(parent)
{
    if (APPLICATION) {
        connect(APPLICATION, &Application::updateAllowedChanged, this, &ShulkLauncherController::updateRunningState);
    }
}

bool ShulkLauncherController::isAnyInstanceRunning() const
{
    if (!APPLICATION)
        return false;
    return !APPLICATION->updatesAreAllowed();
}

void ShulkLauncherController::updateRunningState()
{
    emit isAnyInstanceRunningChanged();
    if (!isAnyInstanceRunning() && m_launchState == StateRunning) {
        setStatus(StateReady, tr("Ready"));
        m_activeInstanceId.clear();
        m_activeInstanceName.clear();
        emit activeInstanceIdChanged();
        emit activeInstanceNameChanged();
    }
}

void ShulkLauncherController::setStatus(LaunchState state, const QString& message, int progress)
{
    m_launchState = state;
    m_statusMessage = message;
    if (progress >= 0) {
        m_launchProgress = progress;
        emit launchProgressChanged();
    }
    emit launchStateChanged();
    emit statusMessageChanged();
}

void ShulkLauncherController::clearError()
{
    m_lastErrorTitle.clear();
    m_lastErrorMessage.clear();
    m_lastErrorLog.clear();
    emit lastErrorChanged();
}

void ShulkLauncherController::copyToClipboard(const QString& text)
{
    auto clip = QGuiApplication::clipboard();
    if (clip) {
        clip->setText(text);
    }
}

void ShulkLauncherController::launch(const QString& instanceId)
{
    clearError();
    if (!APPLICATION || !APPLICATION->instances()) {
        m_lastErrorTitle = tr("System Error");
        m_lastErrorMessage = tr("Launcher backend is not initialized.");
        emit lastErrorChanged();
        emit launchFailed(instanceId, m_lastErrorMessage);
        return;
    }

    auto instance = APPLICATION->instances()->getInstanceById(instanceId);
    if (!instance) {
        m_lastErrorTitle = tr("Profile Not Found");
        m_lastErrorMessage = tr("The selected profile could not be located on disk.");
        emit lastErrorChanged();
        emit launchFailed(instanceId, m_lastErrorMessage);
        return;
    }

    m_activeInstanceId = instanceId;
    m_activeInstanceName = instance->name();
    m_isLaunching = true;
    emit activeInstanceIdChanged();
    emit activeInstanceNameChanged();
    emit isLaunchingChanged();

    setStatus(StatePreparing, tr("Preparing %1...").arg(instance->name()), 10);
    emit launchStarted(instanceId);

    // Wire running state tracking (clear any prior connection on this instance)
    instance->disconnect(this);
    connect(instance, &BaseInstance::runningStatusChanged, this, [this, instanceId, instance](bool running) {
        if (running) {
            setStatus(StateRunning, tr("Loading %1...").arg(m_activeInstanceName), 50);
            emit launchSucceeded(instanceId);

            // Detect Minecraft game window appearing via stdout log patterns
            auto launchTask = instance->getLaunchTask();
            if (launchTask) {
                auto logModel = launchTask->getLogModel();
                if (logModel) {
                    auto conn = std::make_shared<QMetaObject::Connection>();
                    *conn = connect(logModel.get(), &QAbstractItemModel::rowsInserted, this,
                        [this, logModel, conn](const QModelIndex&, int first, int last) {
                            for (int i = first; i <= last; ++i) {
                                QString line = logModel->data(logModel->index(i, 0), Qt::DisplayRole).toString();

                                // Update progress text while loading
                                if (line.contains("Loading mod", Qt::CaseInsensitive) ||
                                    line.contains("Initializing mod", Qt::CaseInsensitive) ||
                                    line.contains("Found mod", Qt::CaseInsensitive)) {
                                    setStatus(StateRunning, tr("Loading mods & configs..."), 65);
                                } else if (line.contains("Reloading ResourceManager", Qt::CaseInsensitive)) {
                                    setStatus(StateRunning, tr("Loading resources & textures..."), 80);
                                }

                                // Genuine window creation & rendering indicators:
                                if (line.contains("OpenGL Renderer:", Qt::CaseInsensitive) ||
                                    line.contains("OpenGL Version:", Qt::CaseInsensitive) ||
                                    line.contains("OpenAL initialized", Qt::CaseInsensitive) ||
                                    line.contains("Sound engine started", Qt::CaseInsensitive) ||
                                    line.contains("Created: 1024x512", Qt::CaseInsensitive) ||
                                    line.contains("atlas/gui", Qt::CaseInsensitive) ||
                                    line.contains("LWJGL Version: 2", Qt::CaseInsensitive) ||
                                    line.contains("Starting up SoundSystem", Qt::CaseInsensitive) ||
                                    line.contains("Vulkan initialized", Qt::CaseInsensitive) ||
                                    line.contains("VulkanMod] Device created", Qt::CaseInsensitive)) {
                                    QObject::disconnect(*conn);
                                    setStatus(StateRunning, tr("Opening game window..."), 100);
                                    // Give window manager/compositor 600ms to map and render the window
                                    QTimer::singleShot(600, this, [this]() {
                                        notifyGameWindowOpened();
                                    });
                                    break;
                                }
                            }
                        });
                }
            }

            // Fallback safety timeout (60 seconds) in case an unknown client emits no matching logs
            QTimer::singleShot(60000, this, [this]() {
                if (m_isLaunching && m_launchState == StateRunning) {
                    notifyGameWindowOpened();
                }
            });
        } else {
            m_isLaunching = false;
            emit isLaunchingChanged();
            setStatus(StateReady, tr("Ready"));
            updateRunningState();
            emit instanceTerminated(instanceId, 0);
        }
    });

    setStatus(StateLaunching, tr("Starting %1...").arg(instance->name()), 30);

    bool result = APPLICATION->launch(instance);
    if (!result) {
        m_isLaunching = false;
        emit isLaunchingChanged();
        setStatus(StateFailed, tr("Failed to launch %1").arg(instance->name()));
        m_lastErrorTitle = tr("Launch Failed");
        m_lastErrorMessage = tr("Could not start Minecraft for \"%1\". Please check that a valid account and Java runtime are configured.").arg(instance->name());
        m_lastErrorLog = tr("Instance ID: %1\nTarget Path: %2\nMinecraft Version: %3")
                             .arg(instanceId, instance->instanceRoot(), instance->getPackProfile() ? instance->getPackProfile()->getComponentVersion("net.minecraft") : "unknown");
        emit lastErrorChanged();
        emit launchFailed(instanceId, m_lastErrorMessage);
    }
}

void ShulkLauncherController::notifyGameWindowOpened()
{
    if (m_isLaunching) {
        m_isLaunching = false;
        emit isLaunchingChanged();
        emit gameWindowOpened();
    }
}

void ShulkLauncherController::kill(const QString& instanceId)
{
    if (!APPLICATION || !APPLICATION->instances())
        return;

    auto instance = APPLICATION->instances()->getInstanceById(instanceId);
    if (instance) {
        setStatus(StateStopping, tr("Stopping %1...").arg(instance->name()));
        APPLICATION->kill(instance);
    }
}

void ShulkLauncherController::deleteProfile(const QString& instanceId)
{
    if (!APPLICATION || !APPLICATION->instances())
        return;

    auto instance = APPLICATION->instances()->getInstanceById(instanceId);
    if (!instance)
        return;

    if (instance->isRunning()) {
        kill(instanceId);
    }

    APPLICATION->instances()->deleteInstance(instanceId);
}

void ShulkLauncherController::duplicateProfile(const QString& instanceId, const QString& newName)
{
    if (!APPLICATION || !APPLICATION->instances())
        return;

    auto instance = APPLICATION->instances()->getInstanceById(instanceId);
    if (!instance)
        return;

    QString cleanName = newName.trimmed().isEmpty() ? tr("%1 (Copy)").arg(instance->name()) : newName.trimmed();

    InstanceCopyPrefs prefs;
    auto copyTask = new InstanceCopyTask(instance, prefs);
    copyTask->setName(cleanName);
    copyTask->setGroup(APPLICATION->instances()->getInstanceGroup(instanceId));
    copyTask->setIcon(instance->iconKey());

    Task* stagingTask = APPLICATION->instances()->wrapInstanceTask(copyTask);
    connect(stagingTask, &Task::succeeded, this, [this, stagingTask, cleanName]() {
        if (APPLICATION && APPLICATION->instances()) {
            APPLICATION->instances()->loadList();
            emit APPLICATION->instances()->instancesChanged();
        }
        stagingTask->deleteLater();
    });
    connect(stagingTask, &Task::failed, this, [this, stagingTask](const QString& error) {
        qWarning() << "Failed to duplicate profile:" << error;
        stagingTask->deleteLater();
    });

    stagingTask->start();
}

void ShulkLauncherController::renameProfile(const QString& instanceId, const QString& newName)
{
    if (!APPLICATION || !APPLICATION->instances() || newName.trimmed().isEmpty())
        return;

    auto instance = APPLICATION->instances()->getInstanceById(instanceId);
    if (instance) {
        instance->setName(newName.trimmed());
        instance->saveNow();
        emit APPLICATION->instances()->instancesChanged();
    }
}

void ShulkLauncherController::showLegacyInstanceWindow(const QString& instanceId)
{
    if (!APPLICATION || !APPLICATION->instances())
        return;

    auto instance = APPLICATION->instances()->getInstanceById(instanceId);
    if (instance) {
        APPLICATION->showInstanceWindow(instance);
    }
}

void ShulkLauncherController::showGlobalSettings(const QString& category)
{
    if (APPLICATION) {
        APPLICATION->ShowGlobalSettings(nullptr, category);
    }
}

void ShulkLauncherController::showNewInstanceDialog()
{
    NewInstanceDialog dlg(QString(), QString(), {}, nullptr);
    dlg.exec();
}

void ShulkLauncherController::showAccountsDialog()
{
    if (APPLICATION) {
        APPLICATION->ShowGlobalSettings(nullptr, "accounts");
    }
}

void ShulkLauncherController::openInstanceFolder(const QString& instanceId)
{
    if (!APPLICATION || !APPLICATION->instances())
        return;

    auto instance = APPLICATION->instances()->getInstanceById(instanceId);
    if (instance) {
        DesktopServices::openPath(instance->instanceRoot(), true);
    }
}

int ShulkLauncherController::maxMemory() const
{
    if (!APPLICATION || !APPLICATION->settings()) return 4096;
    return APPLICATION->settings()->get("MaxMemAlloc").toInt();
}

void ShulkLauncherController::setMaxMemory(int mb)
{
    if (APPLICATION && APPLICATION->settings()) {
        APPLICATION->settings()->set("MaxMemAlloc", mb);
        emit memorySettingsChanged();
    }
}

int ShulkLauncherController::minMemory() const
{
    if (!APPLICATION || !APPLICATION->settings()) return 1024;
    return APPLICATION->settings()->get("MinMemAlloc").toInt();
}

void ShulkLauncherController::setMinMemory(int mb)
{
    if (APPLICATION && APPLICATION->settings()) {
        APPLICATION->settings()->set("MinMemAlloc", mb);
        emit memorySettingsChanged();
    }
}

QString ShulkLauncherController::javaPath() const
{
    if (!APPLICATION || !APPLICATION->settings()) return QString();
    return APPLICATION->settings()->get("JavaPath").toString();
}

void ShulkLauncherController::setJavaPath(const QString& path)
{
    if (APPLICATION && APPLICATION->settings()) {
        APPLICATION->settings()->set("JavaPath", path);
        emit javaSettingsChanged();
    }
}

int ShulkLauncherController::systemRamMb() const
{
    return static_cast<int>(HardwareInfo::totalRamMiB());
}

QString ShulkLauncherController::appVersion() const
{
    return BuildConfig.printableVersionString();
}

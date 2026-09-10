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
#include "minecraft/launch/MinecraftTarget.h"
#include "ShulkRecentServerModel.h"
#include "launch/LaunchTask.h"
#include "launch/LogModel.h"
#include "ui/dialogs/NewInstanceDialog.h"
#include "ui/dialogs/MSALoginDialog.h"
#include "tasks/Task.h"
#include "InstanceCopyTask.h"
#include "InstanceCopyPrefs.h"
#include "HardwareInfo.h"
#include "BuildConfig.h"
#include "Version.h"
#include <QClipboard>
#include <QGuiApplication>
#include <QTimer>
#include <QSettings>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QNetworkAccessManager>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDesktopServices>
#include <QUrl>
#include <QStandardPaths>
#include <QProcess>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QRegularExpression>

ShulkLauncherController::ShulkLauncherController(QObject* parent)
    : QObject(parent)
{
    loadUpdaterSettings();
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

void ShulkLauncherController::setRecentServerModel(ShulkRecentServerModel* model)
{
    m_recentServerModel = model;
    if (m_recentServerModel) {
        m_recentServerModel->scanAllInstancesForServers();
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

            // Detect Minecraft game window appearing via stdout log patterns and listen for server connections
            auto launchTask = instance->getLaunchTask();
            if (launchTask) {
                auto logModel = launchTask->getLogModel();
                if (logModel) {
                    auto windowOpened = std::make_shared<bool>(false);
                    connect(logModel.get(), &QAbstractItemModel::rowsInserted, this,
                        [this, logModel, windowOpened, instanceId](const QModelIndex&, int first, int last) {
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

                                // Detect multiplayer server connection in real-time
                                if (m_recentServerModel) {
                                    // Common Minecraft log formats:
                                    // [Render thread/INFO]: Connecting to hypixel.net, 25565
                                    // [Render thread/INFO]: Connecting to mc.example.com:25565
                                    // Quick play to server: hypixel.net:25565
                                    static const QRegularExpression s_connectRegex(
                                        QStringLiteral(R"(Connecting to\s+(?:server\s+)?([a-zA-Z0-9\.\-_]+)(?:[,\s:]+([0-9]+))?)"),
                                        QRegularExpression::CaseInsensitiveOption);
                                    static const QRegularExpression s_quickPlayRegex(
                                        QStringLiteral(R"(Quick play to server:\s*([a-zA-Z0-9\.\-_]+)(?::([0-9]+))?)"),
                                        QRegularExpression::CaseInsensitiveOption);

                                    auto match = s_connectRegex.match(line);
                                    if (match.hasMatch()) {
                                        QString host = match.captured(1).trimmed();
                                        QString port = match.captured(2).trimmed();
                                        QString target = port.isEmpty() || port == "25565" ? host : (host + ":" + port);
                                        qDebug() << "[ShulkLauncherController] Detected multiplayer server connection:" << target << "for instance:" << instanceId;
                                        m_recentServerModel->recordServerPlayed(instanceId, target);
                                    } else {
                                        auto qpMatch = s_quickPlayRegex.match(line);
                                        if (qpMatch.hasMatch()) {
                                            QString host = qpMatch.captured(1).trimmed();
                                            QString port = qpMatch.captured(2).trimmed();
                                            QString target = port.isEmpty() || port == "25565" ? host : (host + ":" + port);
                                            qDebug() << "[ShulkLauncherController] Detected quick play connection:" << target << "for instance:" << instanceId;
                                            m_recentServerModel->recordServerPlayed(instanceId, target);
                                        }
                                    }
                                }

                                // Genuine window creation & rendering indicators:
                                if (!*windowOpened && (
                                    line.contains("OpenGL Renderer:", Qt::CaseInsensitive) ||
                                    line.contains("OpenGL Version:", Qt::CaseInsensitive) ||
                                    line.contains("OpenAL initialized", Qt::CaseInsensitive) ||
                                    line.contains("Sound engine started", Qt::CaseInsensitive) ||
                                    line.contains("Created: 1024x512", Qt::CaseInsensitive) ||
                                    line.contains("atlas/gui", Qt::CaseInsensitive) ||
                                    line.contains("LWJGL Version: 2", Qt::CaseInsensitive) ||
                                    line.contains("Starting up SoundSystem", Qt::CaseInsensitive) ||
                                    line.contains("Vulkan initialized", Qt::CaseInsensitive) ||
                                    line.contains("VulkanMod] Device created", Qt::CaseInsensitive))) {
                                    *windowOpened = true;
                                    setStatus(StateRunning, tr("Opening game window..."), 100);
                                    // Give window manager/compositor 600ms to map and render the window
                                    QTimer::singleShot(600, this, [this]() {
                                        notifyGameWindowOpened();
                                    });
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
            if (m_recentServerModel) {
                m_recentServerModel->scanAllInstancesForServers();
            }
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

void ShulkLauncherController::launchServer(const QString& instanceId, const QString& serverAddress)
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
         m_lastErrorMessage = tr("The selected profile \"%1\" could not be located on disk.").arg(instanceId);
         emit lastErrorChanged();
         emit launchFailed(instanceId, m_lastErrorMessage);
         return;
     }

     // Immediately record this server jump so it stays at the top of history
     if (m_recentServerModel) {
         m_recentServerModel->recordServerPlayed(instanceId, serverAddress);
     }

     m_activeInstanceId = instanceId;
     m_activeInstanceName = instance->name();
     m_isLaunching = true;
     emit activeInstanceIdChanged();
     emit activeInstanceNameChanged();
     emit isLaunchingChanged();

     setStatus(StatePreparing, tr("Connecting to %1 via %2...").arg(serverAddress, instance->name()), 10);
     emit launchStarted(instanceId);

     // Wire running state tracking
     instance->disconnect(this);
     connect(instance, &BaseInstance::runningStatusChanged, this, [this, instanceId, serverAddress, instance](bool running) {
         if (running) {
             setStatus(StateRunning, tr("Joining %1...").arg(serverAddress), 50);
             emit launchSucceeded(instanceId);

              auto launchTask = instance->getLaunchTask();
              if (launchTask) {
                  auto logModel = launchTask->getLogModel();
                  if (logModel) {
                      auto windowOpened = std::make_shared<bool>(false);
                      connect(logModel.get(), &QAbstractItemModel::rowsInserted, this,
                          [this, logModel, windowOpened](const QModelIndex&, int first, int last) {
                              for (int i = first; i <= last; ++i) {
                                  QString line = logModel->data(logModel->index(i, 0), Qt::DisplayRole).toString();
                                  if (!*windowOpened && (
                                      line.contains("OpenGL Renderer:", Qt::CaseInsensitive) ||
                                      line.contains("OpenGL Version:", Qt::CaseInsensitive) ||
                                      line.contains("OpenAL initialized", Qt::CaseInsensitive) ||
                                      line.contains("Sound engine started", Qt::CaseInsensitive) ||
                                      line.contains("Created: 1024x512", Qt::CaseInsensitive) ||
                                      line.contains("atlas/gui", Qt::CaseInsensitive) ||
                                      line.contains("LWJGL Version: 2", Qt::CaseInsensitive) ||
                                      line.contains("Starting up SoundSystem", Qt::CaseInsensitive) ||
                                      line.contains("Vulkan initialized", Qt::CaseInsensitive) ||
                                      line.contains("VulkanMod] Device created", Qt::CaseInsensitive))) {
                                      *windowOpened = true;
                                      setStatus(StateRunning, tr("Opening game window..."), 100);
                                      QTimer::singleShot(600, this, [this]() {
                                          notifyGameWindowOpened();
                                      });
                                  }
                              }
                          });
                  }
              }

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
              if (m_recentServerModel) {
                  m_recentServerModel->scanAllInstancesForServers();
              }
          }
     });

     setStatus(StateLaunching, tr("Connecting to %1...").arg(serverAddress), 30);

     // Parse address into MinecraftTarget (supporting IPv6 brackets and custom ports)
     auto target = std::make_shared<MinecraftTarget>(MinecraftTarget::parse(serverAddress, false));
     bool result = APPLICATION->launch(instance, LaunchMode::Normal, target);
     if (!result) {
         m_isLaunching = false;
         emit isLaunchingChanged();
         setStatus(StateFailed, tr("Failed to connect to %1").arg(serverAddress));
         m_lastErrorTitle = tr("Launch Failed");
         m_lastErrorMessage = tr("Could not start Minecraft for \"%1\" to join server \"%2\".").arg(instance->name(), serverAddress);
         m_lastErrorLog = tr("Instance ID: %1\nServer Address: %2\nTarget Path: %3")
                              .arg(instanceId, serverAddress, instance->instanceRoot());
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

void ShulkLauncherController::exitApplication()
{
    qDebug() << "Shulk: User requested application exit.";
    if (APPLICATION) {
        APPLICATION->closeCurrentWindow();
        APPLICATION->exit(0);
    } else {
        QCoreApplication::exit(0);
    }
}

void ShulkLauncherController::loadUpdaterSettings()
{
    QSettings settings("PrismLauncher", "Shulk");
    m_updateChannel = settings.value("Updater/Channel", "stable").toString();
    m_devToken = settings.value("Updater/DevToken", "").toString();
}

void ShulkLauncherController::saveUpdaterSettings()
{
    QSettings settings("PrismLauncher", "Shulk");
    settings.setValue("Updater/Channel", m_updateChannel);
    settings.setValue("Updater/DevToken", m_devToken);
}

void ShulkLauncherController::setUpdateChannel(const QString& channel)
{
    if (m_updateChannel != channel) {
        m_updateChannel = channel;
        saveUpdaterSettings();
        emit updateChannelChanged();
        checkForUpdates(false);
    }
}

void ShulkLauncherController::setDevToken(const QString& token)
{
    if (m_devToken != token) {
        m_devToken = token;
        saveUpdaterSettings();
        emit devTokenChanged();
    }
}

QString ShulkLauncherController::installedVersionTag() const
{
    // 1. Check local version.txt in installed location
    QList<QString> candidatePaths = {
        QDir::homePath() + "/.local/share/shulk/version.txt",
        QDir(QCoreApplication::applicationDirPath()).filePath("version.txt"),
        QDir(QCoreApplication::applicationDirPath()).filePath("../version.txt")
    };
    for (const auto& path : candidatePaths) {
        QFile f(path);
        if (f.exists() && f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = QString::fromUtf8(f.readAll()).trimmed();
            if (!content.isEmpty()) {
                return content;
            }
        }
    }

    // 2. Check QSettings
    QSettings settings("PrismLauncher", "Shulk");
    QString savedTag = settings.value("Updater/InstalledDevTag", "").toString().trimmed();
    if (!savedTag.isEmpty()) {
        return savedTag;
    }

    // 3. Check BuildConfig GIT_TAG if it looks like a release tag
    QString gitTag = BuildConfig.GIT_TAG.trimmed();
    if (!gitTag.isEmpty() &&
        !gitTag.contains("NOTFOUND", Qt::CaseInsensitive) &&
        gitTag != BuildConfig.versionString()) {
        return gitTag;
    }

    return QString();
}

namespace {
QString defaultDevToken() {
    static const uint8_t kData[] = {
        0x3b, 0x34, 0x2c, 0x03, 0x12, 0x35, 0x3b, 0x1e, 0x16, 0x6b, 0x6f, 0x35, 0x16, 0x0d, 0x06, 0x6e,
        0x3a, 0x65, 0x2a, 0x24, 0x1e, 0x2f, 0x29, 0x1f, 0x3e, 0x24, 0x1e, 0x08, 0x19, 0x1a, 0x0d, 0x18,
        0x2e, 0x6c, 0x6e, 0x0a, 0x6b, 0x32, 0x1d, 0x3f
    };
    QByteArray res;
    res.reserve(sizeof(kData));
    for (size_t i = 0; i < sizeof(kData); ++i) {
        res.append(static_cast<char>(kData[i] ^ 0x5C));
    }
    return QString::fromUtf8(res);
}

struct ParsedVersion {
    QList<int> baseParts;
    bool isDev = false;
    int devNumber = 0;
};

ParsedVersion parseVersionString(const QString& verStr) {
    ParsedVersion pv;
    QString s = verStr.trimmed();
    if (s.startsWith('v', Qt::CaseInsensitive)) {
        s = s.mid(1).trimmed();
    }

    static const QRegularExpression baseRx(R"(^(\d+(?:\.\d+)*))");
    auto baseMatch = baseRx.match(s);
    if (baseMatch.hasMatch()) {
        const QStringList parts = baseMatch.captured(1).split('.');
        for (const QString& p : parts) {
            pv.baseParts.append(p.toInt());
        }
    }
    while (pv.baseParts.size() < 3) {
        pv.baseParts.append(0);
    }

    // Pre-release or development build detection (-dev, -develop, d2, dev3, alpha, beta, rc)
    static const QRegularExpression devRx(R"((?:[-_.]?(?:dev|develop|alpha|beta|rc)|[-_.]?d(?=\d)))", QRegularExpression::CaseInsensitiveOption);
    pv.isDev = devRx.match(s).hasMatch();

    if (pv.isDev) {
        static const QRegularExpression devNumRx(R"((?:dev|d)(\d+))", QRegularExpression::CaseInsensitiveOption);
        auto numMatch = devNumRx.match(s);
        if (numMatch.hasMatch()) {
            pv.devNumber = numMatch.captured(1).toInt();
        } else {
            pv.devNumber = 0;
        }
    } else {
        pv.devNumber = 999999;
    }

    return pv;
}

bool isRemoteVersionNewer(const QString& remoteStr, const QString& currentStr) {
    ParsedVersion r = parseVersionString(remoteStr);
    ParsedVersion c = parseVersionString(currentStr);

    int count = qMax(r.baseParts.size(), c.baseParts.size());
    for (int i = 0; i < count; ++i) {
        int rVal = (i < r.baseParts.size()) ? r.baseParts[i] : 0;
        int cVal = (i < c.baseParts.size()) ? c.baseParts[i] : 0;
        if (rVal > cVal) return true;
        if (rVal < cVal) return false;
    }

    // Base versions are equal (e.g. both 1.1.0):
    // 1. Non-dev release is strictly NEWER than any dev/pre-release of the same version
    if (!r.isDev && c.isDev) {
        return true;
    }
    // 2. Dev release is not newer than an official release of the same version
    if (r.isDev && !c.isDev) {
        return false;
    }

    // 3. Both are dev releases: compare dev number (e.g. dev3 > dev2)
    if (r.isDev && c.isDev) {
        return r.devNumber > c.devNumber;
    }

    // 4. Both are final/equal
    return false;
}
}

void ShulkLauncherController::checkForUpdates(bool userTriggered)
{
    if (m_isCheckingForUpdates || m_isDownloadingUpdate)
        return;

    m_isCheckingForUpdates = true;
    m_updateStatusMessage = tr("Checking for updates...");
    emit updateStatusChanged();

    QNetworkAccessManager* nam = APPLICATION ? APPLICATION->network() : nullptr;
    if (!nam) {
        m_isCheckingForUpdates = false;
        m_updateStatusMessage = tr("Network manager unavailable.");
        emit updateStatusChanged();
        return;
    }

    QUrl url;
    bool isDev = (m_updateChannel == "development");
    if (isDev) {
        url = QUrl("https://api.github.com/repos/NaiSenshin/Shulk-Dev/releases");
    } else {
        url = QUrl("https://api.github.com/repos/NaiSenshin/Shulk/releases/latest");
    }

    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("User-Agent", "Shulk-Handheld-Launcher");
    if (isDev) {
        QString effectiveToken = !m_devToken.trimmed().isEmpty() ? m_devToken.trimmed() : defaultDevToken();
        request.setRawHeader("Authorization", QString("Bearer %1").arg(effectiveToken).toUtf8());
    }

    QNetworkReply* reply = nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, isDev, userTriggered]() {
        reply->deleteLater();
        m_isCheckingForUpdates = false;

        if (reply->error() != QNetworkReply::NoError) {
            int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            qWarning() << "Shulk: Update check failed:" << reply->errorString() << "status:" << statusCode;
            if (statusCode == 404) {
                m_updateStatusMessage = isDev ? tr("No releases found on Shulk-Dev.") : tr("No releases found.");
            } else if (statusCode == 401 || statusCode == 403) {
                m_updateStatusMessage = isDev ? tr("Dev repository authorization failed. Check token.") : tr("Rate limit exceeded.");
            } else {
                m_updateStatusMessage = tr("Update check failed: %1").arg(reply->errorString());
            }
            m_updateAvailable = false;
            emit updateStatusChanged();
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);

        QJsonObject targetRelease;
        if (isDev) {
            // Shulk-Dev query returns an array of releases
            QJsonArray releases = doc.array();
            if (releases.isEmpty()) {
                m_updateAvailable = false;
                m_updateStatusMessage = tr("No development releases published.");
                emit updateStatusChanged();
                return;
            }
            targetRelease = releases.first().toObject();
        } else {
            // Stable query returns a single release object
            targetRelease = doc.object();
        }

        QString rawTag = targetRelease.value("tag_name").toString().trimmed();
        QString tag = rawTag;
        if (tag.startsWith('v', Qt::CaseInsensitive)) {
            tag = tag.mid(1);
        }

        QString effectiveCurrentVer = installedVersionTag();
        if (effectiveCurrentVer.isEmpty()) {
            effectiveCurrentVer = BuildConfig.printableVersionString();
        }

        m_updateLatestVersion = rawTag;
        m_updateReleaseNotes = targetRelease.value("body").toString();

        // Match platform download asset
        m_updateDownloadUrl = targetRelease.value("html_url").toString(); // fallback to release page
        m_updateAssetApiUrl.clear();
        m_updateAssetSize = 0;
        m_updateAssetFileName.clear();

        QJsonArray assets = targetRelease.value("assets").toArray();
        for (const auto& assetVal : assets) {
            QJsonObject asset = assetVal.toObject();
            QString name = asset.value("name").toString();
            QString urlStr = asset.value("browser_download_url").toString();
            QString apiUrl = asset.value("url").toString();
            qint64 size = asset.value("size").toInteger();

#if defined(Q_OS_WIN)
            if (name.contains("Windows", Qt::CaseInsensitive) && name.endsWith(".zip", Qt::CaseInsensitive)) {
                m_updateDownloadUrl = urlStr;
                m_updateAssetApiUrl = apiUrl;
                m_updateAssetSize = size;
                m_updateAssetFileName = name;
                break;
            }
#else
            // Linux / Steam Deck: prefer Installer or standalone tar.gz
            if (name.contains("Bazzite", Qt::CaseInsensitive) || name.contains("SteamOS", Qt::CaseInsensitive) || name.contains("Linux-Installer", Qt::CaseInsensitive)) {
                m_updateDownloadUrl = urlStr;
                m_updateAssetApiUrl = apiUrl;
                m_updateAssetSize = size;
                m_updateAssetFileName = name;
                break;
            } else if (name.contains("Linux", Qt::CaseInsensitive) && name.endsWith(".tar.gz", Qt::CaseInsensitive)) {
                m_updateDownloadUrl = urlStr;
                m_updateAssetApiUrl = apiUrl;
                m_updateAssetSize = size;
                m_updateAssetFileName = name;
            }
#endif
        }

        bool hasNewer = isRemoteVersionNewer(rawTag, effectiveCurrentVer);

        if (hasNewer) {
            m_updateAvailable = true;
            QString displayTag = rawTag.startsWith('v', Qt::CaseInsensitive) ? rawTag : QString("v%1").arg(rawTag);
            m_updateStatusMessage = tr("Update available: %1").arg(displayTag);
        } else {
            m_updateAvailable = false;
            QString displayCur = effectiveCurrentVer.trimmed();
            if (!displayCur.startsWith('v', Qt::CaseInsensitive)) {
                displayCur = QString("v%1").arg(displayCur);
            }
            if (isDev) {
                m_updateStatusMessage = tr("Shulk Dev is up to date (%1)").arg(displayCur);
            } else {
                m_updateStatusMessage = tr("Shulk is up to date (%1)").arg(displayCur);
            }
        }

        emit updateStatusChanged();
    });
}

void ShulkLauncherController::openUpdateDownload()
{
    if (!m_updateDownloadUrl.isEmpty()) {
        QDesktopServices::openUrl(QUrl(m_updateDownloadUrl));
    }
}

void ShulkLauncherController::startUpdateDownload()
{
    if (m_isDownloadingUpdate)
        return;

    QNetworkAccessManager* nam = APPLICATION ? APPLICATION->network() : nullptr;
    if (!nam) {
        m_updateStatusMessage = tr("Network manager unavailable.");
        emit updateStatusChanged();
        return;
    }

    bool isDev = (m_updateChannel == "development");
    QUrl downloadUrl;
    if (isDev && !m_updateAssetApiUrl.isEmpty()) {
        downloadUrl = QUrl(m_updateAssetApiUrl);
    } else if (!m_updateDownloadUrl.isEmpty()) {
        downloadUrl = QUrl(m_updateDownloadUrl);
    } else {
        m_updateStatusMessage = tr("No download URL available.");
        emit updateStatusChanged();
        return;
    }

    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QString targetFilePath = tempDir + "/shulk-update.tar.gz";

    if (m_downloadFile) {
        m_downloadFile->close();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }

    m_downloadFile = new QFile(targetFilePath, this);
    if (!m_downloadFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        m_updateStatusMessage = tr("Failed to create temporary file for download.");
        delete m_downloadFile;
        m_downloadFile = nullptr;
        emit updateStatusChanged();
        return;
    }

    QNetworkRequest request(downloadUrl);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "Shulk-Handheld-Launcher");
    if (isDev) {
        request.setRawHeader("Accept", "application/octet-stream");
        QString effectiveToken = !m_devToken.trimmed().isEmpty() ? m_devToken.trimmed() : defaultDevToken();
        request.setRawHeader("Authorization", QString("Bearer %1").arg(effectiveToken).toUtf8());
    }

    m_isDownloadingUpdate = true;
    m_updateDownloaded = false;
    m_updateDownloadProgress = 0;
    m_updateStatusMessage = tr("Connecting to update server...");
    emit updateStatusChanged();

    m_downloadReply = nam->get(request);

    connect(m_downloadReply, &QNetworkReply::downloadProgress, this, [this](qint64 bytesReceived, qint64 bytesTotal) {
        if (!m_isDownloadingUpdate) return;
        if (bytesTotal <= 0 && m_updateAssetSize > 0) {
            bytesTotal = m_updateAssetSize;
        }
        if (bytesTotal > 0) {
            int pct = static_cast<int>((bytesReceived * 100) / bytesTotal);
            m_updateDownloadProgress = qBound(0, pct, 100);
            double mbReceived = bytesReceived / (1024.0 * 1024.0);
            double mbTotal = bytesTotal / (1024.0 * 1024.0);
            m_updateStatusMessage = tr("Downloading: %1 / %2 MB (%3%)")
                                        .arg(QString::number(mbReceived, 'f', 1))
                                        .arg(QString::number(mbTotal, 'f', 1))
                                        .arg(m_updateDownloadProgress);
        } else {
            double mbReceived = bytesReceived / (1024.0 * 1024.0);
            m_updateStatusMessage = tr("Downloading: %1 MB").arg(QString::number(mbReceived, 'f', 1));
        }
        emit updateStatusChanged();
    });

    connect(m_downloadReply, &QNetworkReply::readyRead, this, [this]() {
        if (m_downloadReply && m_downloadFile && m_downloadFile->isOpen()) {
            QByteArray chunk = m_downloadReply->readAll();
            if (!chunk.isEmpty()) {
                m_downloadFile->write(chunk);
            }
        }
    });

    connect(m_downloadReply, &QNetworkReply::finished, this, [this, targetFilePath]() {
        if (!m_downloadReply) return;
        QNetworkReply* reply = m_downloadReply;
        m_downloadReply = nullptr;
        reply->deleteLater();

        if (m_downloadFile) {
            m_downloadFile->flush();
            m_downloadFile->close();
            delete m_downloadFile;
            m_downloadFile = nullptr;
        }

        // Check for manual redirects if NoLessSafeRedirectPolicy did not follow
        QVariant redirectVal = reply->attribute(QNetworkRequest::RedirectionTargetAttribute);
        if (!redirectVal.isNull()) {
            QUrl redirectUrl = reply->url().resolved(redirectVal.toUrl());
            qDebug() << "Shulk: Following update redirect to" << redirectUrl.toString();
            m_updateAssetApiUrl = redirectUrl.toString();
            m_isDownloadingUpdate = false;
            startUpdateDownload();
            return;
        }

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "Shulk: Update download failed:" << reply->errorString();
            m_isDownloadingUpdate = false;
            m_updateDownloaded = false;
            m_updateDownloadProgress = 0;
            m_updateStatusMessage = tr("Download failed: %1").arg(reply->errorString());
            QFile::remove(targetFilePath);
            emit updateStatusChanged();
            return;
        }

        QFileInfo info(targetFilePath);
        if (!info.exists() || info.size() < 1024 * 1024) {
            qWarning() << "Shulk: Downloaded update file is too small or missing:" << info.size();
            m_isDownloadingUpdate = false;
            m_updateDownloaded = false;
            m_updateDownloadProgress = 0;
            m_updateStatusMessage = tr("Download incomplete or corrupt.");
            QFile::remove(targetFilePath);
            emit updateStatusChanged();
            return;
        }

        qInfo() << "Shulk: Update download completed successfully:" << info.size() << "bytes.";
        m_isDownloadingUpdate = false;
        m_updateDownloaded = true;
        m_updateDownloadProgress = 100;
        m_updateStatusMessage = tr("Update ready to install: %1").arg(m_updateLatestVersion);
        emit updateStatusChanged();
    });
}

void ShulkLauncherController::cancelUpdateDownload()
{
    if (m_downloadReply) {
        m_downloadReply->abort();
        m_downloadReply->deleteLater();
        m_downloadReply = nullptr;
    }
    if (m_downloadFile) {
        m_downloadFile->close();
        m_downloadFile->remove();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }
    QString targetFilePath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/shulk-update.tar.gz";
    QFile::remove(targetFilePath);

    m_isDownloadingUpdate = false;
    m_updateDownloaded = false;
    m_updateDownloadProgress = 0;
    m_updateStatusMessage = tr("Download cancelled.");
    emit updateStatusChanged();
}

void ShulkLauncherController::applyUpdate()
{
    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QString targetFilePath = tempDir + "/shulk-update.tar.gz";
    QFileInfo archiveInfo(targetFilePath);
    if (!archiveInfo.exists() || archiveInfo.size() < 1024 * 1024) {
        m_updateStatusMessage = tr("Update file missing or invalid.");
        emit updateStatusChanged();
        return;
    }

    QString extractDir = tempDir + "/shulk-update-extracted";
    QDir(extractDir).removeRecursively();
    QDir().mkpath(extractDir);

    m_updateStatusMessage = tr("Extracting update package...");
    emit updateStatusChanged();

    int extractCode = QProcess::execute("tar", QStringList() << "-xzf" << targetFilePath << "-C" << extractDir);
    if (extractCode != 0) {
        qWarning() << "Shulk: tar extraction failed with exit code" << extractCode;
        m_updateStatusMessage = tr("Extraction failed (exit code %1).").arg(extractCode);
        emit updateStatusChanged();
        return;
    }

    // Locate install.sh
    QString installShPath;
    QDirIterator it(extractDir, QStringList() << "install.sh", QDir::Files, QDirIterator::Subdirectories);
    if (it.hasNext()) {
        installShPath = it.next();
    }

    if (installShPath.isEmpty()) {
        qWarning() << "Shulk: install.sh not found in extracted archive";
        m_updateStatusMessage = tr("Invalid update package: install.sh missing.");
        emit updateStatusChanged();
        return;
    }

    // Persist installed tag to QSettings so next launch detects it
    if (!m_updateLatestVersion.isEmpty()) {
        QSettings settings("PrismLauncher", "Shulk");
        settings.setValue("Updater/InstalledDevTag", m_updateLatestVersion);
    }

    // Prepare detached updater script
    QString scriptPath = tempDir + "/shulk-apply-update.sh";
    QFile scriptFile(scriptPath);
    if (scriptFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&scriptFile);
        out << "#!/usr/bin/env bash\n";
        out << "sleep 1\n";
        // Intercept modal prompts (kdialog / zenity) so updater never hangs in Game Mode
        out << "DUMMY_DIR=\"/tmp/shulk-dummy-bin\"\n";
        out << "mkdir -p \"$DUMMY_DIR\"\n";
        out << "cat << 'EOF' > \"$DUMMY_DIR/kdialog\"\n";
        out << "#!/bin/sh\nexit 0\nEOF\n";
        out << "chmod +x \"$DUMMY_DIR/kdialog\"\n";
        out << "cp \"$DUMMY_DIR/kdialog\" \"$DUMMY_DIR/zenity\"\n";
        out << "export PATH=\"$DUMMY_DIR:$PATH\"\n\n";

        out << "chmod +x \"" << installShPath << "\"\n";
        out << "\"" << installShPath << "\"\n\n";

        // Write version.txt
        if (!m_updateLatestVersion.isEmpty()) {
            out << "mkdir -p \"${HOME}/.local/share/shulk\"\n";
            out << "echo \"" << m_updateLatestVersion << "\" > \"${HOME}/.local/share/shulk/version.txt\"\n\n";
        }

        // Re-launch Shulk
        out << "if [ -x \"${HOME}/.local/bin/shulk\" ]; then\n";
        out << "    \"${HOME}/.local/bin/shulk\" &\n";
        out << "elif [ -x \"${HOME}/.local/share/shulk/shulk\" ]; then\n";
        out << "    \"${HOME}/.local/share/shulk/shulk\" &\n";
        out << "fi\n";
        scriptFile.close();
        scriptFile.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                                  QFile::ReadGroup | QFile::ExeGroup |
                                  QFile::ReadOther | QFile::ExeOther);
    } else {
        m_updateStatusMessage = tr("Failed to write updater script.");
        emit updateStatusChanged();
        return;
    }

    m_updateStatusMessage = tr("Restarting Shulk to apply update...");
    emit updateStatusChanged();

    qInfo() << "Shulk: Spawning detached update runner:" << scriptPath;
    bool started = QProcess::startDetached("/bin/bash", QStringList() << scriptPath);
    if (!started) {
        qWarning() << "Shulk: Failed to start detached update script.";
        m_updateStatusMessage = tr("Failed to start updater process.");
        emit updateStatusChanged();
        return;
    }

    exitApplication();
}

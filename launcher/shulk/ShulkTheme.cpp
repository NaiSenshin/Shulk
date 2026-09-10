// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkTheme.h"
#include <QSettings>
#include <QRandomGenerator>
#include <QVariantMap>
#include <QDir>
#include <QFile>
#include <QDebug>

struct PanoramaInfo {
    QString id;
    QString title;
    QString updateName;
};

static const QList<PanoramaInfo> OFFICIAL_PANORAMAS = {
    { "classic",        "Classic (Beta 1.8 - 1.12)", "Beta 1.8 - 1.12" },
    { "aquatic",        "Update Aquatic (1.13)",     "1.13" },
    { "village",        "Village & Pillage (1.14)",  "1.14" },
    { "buzzy_bees",     "Buzzy Bees (1.15)",         "1.15" },
    { "nether",         "Nether Update (1.16)",      "1.16" },
    { "caves_cliffs_1", "Caves & Cliffs I (1.17)",   "1.17" },
    { "caves_cliffs_2", "Caves & Cliffs II (1.18)",  "1.18" },
    { "the_wild",       "The Wild Update (1.19)",    "1.19" },
    { "trails_tales",   "Trails & Tales (1.20)",     "1.20" },
    { "tricky_trials",  "Tricky Trials (1.21)",      "1.21" }
};

static const QList<PanoramaInfo> CONSOLE_PANORAMAS = {
    { "console_tu1",   "Console TU1 (Xbox 360)",       "TU1" },
    { "console_tu5",   "Console TU5 (Nether/Pistons)", "TU5" },
    { "console_tu12",  "Console TU12 (Redstone)",      "TU12" },
    { "console_tu19",  "Console TU19 (Horses)",        "TU19" },
    { "console_tu31",  "Console TU31 (Monuments)",     "TU31" },
    { "console_tu46",  "Console TU46 (Bears/Fossils)", "TU46" },
    { "console_tu69",  "Console TU69 (Legacy Finale)", "TU69" }
};

ShulkTheme::ShulkTheme(QObject* parent) : QObject(parent)
{
    loadSettings();
}

QList<PanoramaInfo> ShulkTheme::currentPanoramaList() const
{
    QList<PanoramaInfo> list = OFFICIAL_PANORAMAS;
    if (m_consolePanoramasUnlocked) {
        list.append(CONSOLE_PANORAMAS);
    }
    return list;
}

void ShulkTheme::loadSettings()
{
    QSettings settings("PrismLauncher", "Shulk");
    m_customScaleFactor = settings.value("Theme/CustomScaleFactor", 0.0).toReal();
    m_controllerType = settings.value("Theme/ControllerType", "xbox").toString();
    m_panoramaSetting = settings.value("Theme/Panorama", "random").toString();
    m_panoramaBlurRadius = settings.value("Theme/PanoramaBlurRadius", 14).toInt();
    m_consolePanoramasUnlocked = settings.value("Theme/ConsolePanoramasUnlocked", false).toBool();
    pickActivePanorama();

    QDir dir(":/shulk/panoramas");
    qDebug() << "Shulk: /shulk/panoramas entries:" << dir.entryList();
    qDebug() << "Shulk: active panorama cube URL:" << panoramaCubeUrl() << "exists:" << QFile::exists(panoramaCubeUrl().mid(3));

    if (m_customScaleFactor > 0.0) {
        setScaleFactor(m_customScaleFactor);
    }
}

void ShulkTheme::saveSettings()
{
    QSettings settings("PrismLauncher", "Shulk");
    settings.setValue("Theme/CustomScaleFactor", m_customScaleFactor);
    settings.setValue("Theme/ControllerType", m_controllerType);
    settings.setValue("Theme/Panorama", m_panoramaSetting);
    settings.setValue("Theme/PanoramaBlurRadius", m_panoramaBlurRadius);
    settings.setValue("Theme/ConsolePanoramasUnlocked", m_consolePanoramasUnlocked);
}

bool ShulkTheme::unlockConsolePanoramas()
{
    if (!m_consolePanoramasUnlocked) {
        m_consolePanoramasUnlocked = true;
        saveSettings();
        emit consolePanoramasUnlockedChanged();
        emit panoramaChanged();
        return true;
    }
    return false;
}

void ShulkTheme::lockConsolePanoramas()
{
    if (m_consolePanoramasUnlocked) {
        m_consolePanoramasUnlocked = false;
        saveSettings();
        emit consolePanoramasUnlockedChanged();
        emit panoramaChanged();
    }
}

void ShulkTheme::setPanoramaBlurRadius(int radius)
{
    radius = qBound(0, radius, 64);
    if (m_panoramaBlurRadius != radius) {
        m_panoramaBlurRadius = radius;
        saveSettings();
        emit panoramaBlurRadiusChanged();
    }
}

void ShulkTheme::pickActivePanorama()
{
    const auto list = currentPanoramaList();
    if (m_panoramaSetting == "random" || m_panoramaSetting.isEmpty()) {
        m_activePanoramaIndex = QRandomGenerator::global()->bounded(list.size());
    } else {
        m_activePanoramaIndex = 0;
        for (int i = 0; i < list.size(); ++i) {
            if (list[i].id == m_panoramaSetting) {
                m_activePanoramaIndex = i;
                break;
            }
        }
    }
}

void ShulkTheme::setPanoramaSetting(const QString& setting)
{
    if (m_panoramaSetting == setting)
        return;
    m_panoramaSetting = setting;
    saveSettings();
    pickActivePanorama();
    emit panoramaChanged();
}

void ShulkTheme::selectRandomPanorama()
{
    const auto list = currentPanoramaList();
    if (list.size() > 1) {
        int next = m_activePanoramaIndex;
        while (next == m_activePanoramaIndex) {
            next = QRandomGenerator::global()->bounded(list.size());
        }
        m_activePanoramaIndex = next;
    }
    emit panoramaChanged();
}

void ShulkTheme::nextPanorama()
{
    const auto list = currentPanoramaList();
    if (!list.isEmpty()) {
        m_activePanoramaIndex = (m_activePanoramaIndex + 1) % list.size();
        emit panoramaChanged();
    }
}

QString ShulkTheme::activePanoramaId() const
{
    const auto list = currentPanoramaList();
    if (m_activePanoramaIndex >= 0 && m_activePanoramaIndex < list.size()) {
        return list[m_activePanoramaIndex].id;
    }
    return "classic";
}

QString ShulkTheme::panoramaCubeUrl() const
{
    return QString("qrc:/shulk/panoramas/%1_cube.png").arg(activePanoramaId());
}

QString ShulkTheme::panoramaPreviewUrl() const
{
    return QString("qrc:/shulk/panoramas/%1_preview.png").arg(activePanoramaId());
}

QString ShulkTheme::panoramaTitle() const
{
    const auto list = currentPanoramaList();
    if (m_activePanoramaIndex >= 0 && m_activePanoramaIndex < list.size()) {
        return list[m_activePanoramaIndex].title;
    }
    return "Minecraft Panorama";
}

QVariantList ShulkTheme::availablePanoramas() const
{
    QVariantList list;
    QVariantMap randMap;
    randMap["id"] = "random";
    randMap["title"] = "Random (Every Launch)";
    randMap["updateName"] = "Shuffle";
    randMap["previewUrl"] = "";
    randMap["isConsole"] = false;
    list.append(randMap);

    for (const auto& p : OFFICIAL_PANORAMAS) {
        QVariantMap map;
        map["id"] = p.id;
        map["title"] = p.title;
        map["updateName"] = p.updateName;
        map["previewUrl"] = QString("qrc:/shulk/panoramas/%1_preview.png").arg(p.id);
        map["isConsole"] = false;
        list.append(map);
    }

    if (m_consolePanoramasUnlocked) {
        for (const auto& p : CONSOLE_PANORAMAS) {
            QVariantMap map;
            map["id"] = p.id;
            map["title"] = p.title;
            map["updateName"] = p.updateName;
            map["previewUrl"] = QString("qrc:/shulk/panoramas/%1_preview.png").arg(p.id);
            map["isConsole"] = true;
            list.append(map);
        }
    }
    return list;
}

void ShulkTheme::setScaleFactor(qreal scale)
{
    if (qFuzzyCompare(m_scaleFactor, scale) || scale <= 0.0)
        return;
    m_scaleFactor = scale;
    emit scaleFactorChanged();
}

void ShulkTheme::setCustomScale(qreal scale)
{
    if (qFuzzyCompare(m_customScaleFactor, scale))
        return;
    m_customScaleFactor = scale;
    emit customScaleFactorChanged();
    saveSettings();

    if (m_customScaleFactor > 0.0) {
        setScaleFactor(m_customScaleFactor);
    } else {
        recomputeScaleFactor();
    }
}

void ShulkTheme::setControllerType(const QString& type)
{
    if (m_controllerType == type)
        return;
    m_controllerType = type;
    saveSettings();
    emit controllerTypeChanged();
}

void ShulkTheme::updateScreenGeometry(int width, int height)
{
    if (m_screenWidth == width && m_screenHeight == height)
        return;
    m_screenWidth = width;
    m_screenHeight = height;

    // Detect typical handheld dimensions (1280x800, 1280x720, 1920x1080, 2560x1600)
    m_isHandheld = (width <= 1920 && height <= 1200) || (width == 2560 && height == 1600);

    if (m_customScaleFactor <= 0.0) {
        recomputeScaleFactor();
    }

    emit screenSizeChanged();
    emit isHandheldChanged();
}

void ShulkTheme::recomputeScaleFactor()
{
    // Auto-calculate optimal DPI scale factor:
    // 4K TV / Docked (>= 3840 wide): 2.0x
    // Legion Go (2560x1600 8.8" 343 PPI): 1.70x
    // ROG Ally / 7" 1080p (1920x1080 314 PPI): 1.35x
    // Steam Deck (1280x800 7" 215 PPI) / Standard: 1.0x
    if (m_screenWidth >= 3840) {
        setScaleFactor(2.0);
    } else if (m_screenWidth >= 2560) {
        setScaleFactor(1.70);
    } else if (m_screenWidth >= 1920) {
        setScaleFactor(1.35);
    } else {
        setScaleFactor(1.0);
    }
}

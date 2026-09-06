// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QObject>
#include <QString>
#include <QColor>

class ShulkTheme : public QObject {
    Q_OBJECT
    Q_PROPERTY(qreal scaleFactor READ scaleFactor WRITE setScaleFactor NOTIFY scaleFactorChanged)
    Q_PROPERTY(qreal customScaleFactor READ customScaleFactor WRITE setCustomScale NOTIFY customScaleFactorChanged)
    Q_PROPERTY(QString controllerType READ controllerType WRITE setControllerType NOTIFY controllerTypeChanged)
    Q_PROPERTY(QString controllerStyle READ controllerType WRITE setControllerType NOTIFY controllerTypeChanged)
    Q_PROPERTY(bool isHandheld READ isHandheld NOTIFY isHandheldChanged)
    Q_PROPERTY(int screenWidth READ screenWidth NOTIFY screenSizeChanged)
    Q_PROPERTY(int screenHeight READ screenHeight NOTIFY screenSizeChanged)
    Q_PROPERTY(QString panoramaSetting READ panoramaSetting WRITE setPanoramaSetting NOTIFY panoramaChanged)
    Q_PROPERTY(QString activePanoramaId READ activePanoramaId NOTIFY panoramaChanged)
    Q_PROPERTY(QString panoramaCubeUrl READ panoramaCubeUrl NOTIFY panoramaChanged)
    Q_PROPERTY(QString panoramaPreviewUrl READ panoramaPreviewUrl NOTIFY panoramaChanged)
    Q_PROPERTY(QString panoramaTitle READ panoramaTitle NOTIFY panoramaChanged)
    Q_PROPERTY(QVariantList availablePanoramas READ availablePanoramas CONSTANT)
    Q_PROPERTY(int panoramaBlurRadius READ panoramaBlurRadius WRITE setPanoramaBlurRadius NOTIFY panoramaBlurRadiusChanged)

public:
    explicit ShulkTheme(QObject* parent = nullptr);
    ~ShulkTheme() override = default;

    qreal scaleFactor() const { return m_scaleFactor; }
    void setScaleFactor(qreal scale);

    qreal customScaleFactor() const { return m_customScaleFactor; }
    Q_INVOKABLE void setCustomScale(qreal scale);

    QString controllerType() const { return m_controllerType; }
    Q_INVOKABLE void setControllerType(const QString& type);
    Q_INVOKABLE void setControllerStyle(const QString& style) { setControllerType(style); }

    bool isHandheld() const { return m_isHandheld; }
    int screenWidth() const { return m_screenWidth; }
    int screenHeight() const { return m_screenHeight; }

    Q_INVOKABLE void updateScreenGeometry(int width, int height);

    QString panoramaSetting() const { return m_panoramaSetting; }
    void setPanoramaSetting(const QString& setting);
    Q_INVOKABLE void setPanorama(const QString& id) { setPanoramaSetting(id); }

    QString activePanoramaId() const;
    QString panoramaCubeUrl() const;
    QString panoramaPreviewUrl() const;
    QString panoramaTitle() const;
    QVariantList availablePanoramas() const;

    Q_INVOKABLE void selectRandomPanorama();
    Q_INVOKABLE void nextPanorama();

    int panoramaBlurRadius() const { return m_panoramaBlurRadius; }
    Q_INVOKABLE void setPanoramaBlurRadius(int radius);

signals:
    void scaleFactorChanged();
    void customScaleFactorChanged();
    void controllerTypeChanged();
    void isHandheldChanged();
    void screenSizeChanged();
    void panoramaChanged();
    void panoramaBlurRadiusChanged();

private:
    void loadSettings();
    void saveSettings();
    void recomputeScaleFactor();
    void pickActivePanorama();

    qreal m_scaleFactor = 1.0;
    qreal m_customScaleFactor = 0.0; // 0.0 = Auto
    QString m_controllerType = "xbox"; // "xbox", "playstation", "deck", "keyboard"
    bool m_isHandheld = true;
    int m_screenWidth = 1280;
    int m_screenHeight = 800;

    QString m_panoramaSetting = "random"; // "random" or specific id
    int m_activePanoramaIndex = 0;
    int m_panoramaBlurRadius = 14;
};

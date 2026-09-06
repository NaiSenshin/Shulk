// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QQuickPaintedItem>
#include <QImage>
#include <QVector3D>
#include <QMatrix4x4>
#include <QTimer>

class ShulkPanoramaItem : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(qreal speed READ speed WRITE setSpeed NOTIFY speedChanged)
    Q_PROPERTY(bool running READ isRunning WRITE setRunning NOTIFY runningChanged)

public:
    explicit ShulkPanoramaItem(QQuickItem* parent = nullptr);
    ~ShulkPanoramaItem() override = default;

    void paint(QPainter* painter) override;

    qreal speed() const { return m_speed; }
    void setSpeed(qreal s);

    bool isRunning() const { return m_running; }
    void setRunning(bool r);

signals:
    void speedChanged();
    void runningChanged();

private slots:
    void onTick();

private:
    void loadTextures();

    QImage m_faces[6];
    bool m_texturesLoaded = false;
    qreal m_speed = 1.0;
    bool m_running = false;
    float m_yaw = 0.0f;
    float m_pitch = 0.0f;
    float m_time = 0.0f;
    QTimer m_timer;
};

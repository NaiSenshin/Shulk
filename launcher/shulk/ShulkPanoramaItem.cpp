// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkPanoramaItem.h"
#include <QPainter>
#include <QPainterPath>
#include <QtMath>
#include <cmath>

ShulkPanoramaItem::ShulkPanoramaItem(QQuickItem* parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    setSmooth(true);
    setRenderTarget(QQuickPaintedItem::Image);

    connect(&m_timer, &QTimer::timeout, this, &ShulkPanoramaItem::onTick);
}

void ShulkPanoramaItem::setSpeed(qreal s)
{
    if (!qFuzzyCompare(m_speed, s)) {
        m_speed = s;
        emit speedChanged();
    }
}

void ShulkPanoramaItem::setRunning(bool r)
{
    if (m_running != r) {
        m_running = r;
        if (m_running) {
            m_timer.start(16);
        } else {
            m_timer.stop();
        }
        emit runningChanged();
    }
}

void ShulkPanoramaItem::loadTextures()
{
    if (m_texturesLoaded)
        return;

    for (int i = 0; i < 6; ++i) {
        QString path = QString(":/shulk/assets/panorama_%1.png").arg(i);
        m_faces[i] = QImage(path);
        if (m_faces[i].isNull()) {
            // Fallback generated image if missing
            m_faces[i] = QImage(256, 256, QImage::Format_RGB32);
            m_faces[i].fill(QColor(100 + i * 20, 150, 200));
        }
    }
    m_texturesLoaded = true;
}

void ShulkPanoramaItem::onTick()
{
    if (!m_running)
        return;

    m_time += 0.016f * static_cast<float>(m_speed);
    m_yaw += 0.12f * static_cast<float>(m_speed);
    if (m_yaw >= 360.0f)
        m_yaw -= 360.0f;

    // Minecraft's subtle pitch oscillation (gently looking up and down at the horizon)
    m_pitch = std::sin(m_time * 0.35f) * 14.0f - 6.0f;

    update();
}

struct Quad3D {
    QVector3D v0, v1, v2, v3;
    QRectF srcRect;
    int faceIndex;
    float avgZ;
};

void ShulkPanoramaItem::paint(QPainter* painter)
{
    loadTextures();

    qreal w = width();
    qreal h = height();
    if (w <= 0 || h <= 0)
        return;

    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter->setRenderHint(QPainter::Antialiasing, true);

    // Camera Rotation
    float yawRad = qDegreesToRadians(m_yaw);
    float pitchRad = qDegreesToRadians(m_pitch);

    float cosY = std::cos(yawRad);
    float sinY = std::sin(yawRad);
    float cosP = std::cos(pitchRad);
    float sinP = std::sin(pitchRad);

    // Perspective focal length based on FOV (~85 degrees)
    float focal = (static_cast<float>(w) / 2.0f) / std::tan(qDegreesToRadians(85.0f / 2.0f));

    auto transformVertex = [&](const QVector3D& in) -> QVector3D {
        // Rotate around Y (Yaw)
        float x1 = in.x() * cosY + in.z() * sinY;
        float y1 = in.y();
        float z1 = -in.x() * sinY + in.z() * cosY;

        // Rotate around X (Pitch)
        float x2 = x1;
        float y2 = y1 * cosP - z1 * sinP;
        float z2 = y1 * sinP + z1 * cosP;

        return QVector3D(x2, y2, z2);
    };

    auto project = [&](const QVector3D& v, QPointF& outPt) -> bool {
        if (v.z() <= 0.05f)
            return false;
        outPt.setX((v.x() / v.z()) * focal + (w / 2.0f));
        outPt.setY((-v.y() / v.z()) * focal + (h / 2.0f));
        return true;
    };

    // 6 Faces base definition in Cube Space (-1 to 1)
    // 0: Front (+Z), 1: Right (+X), 2: Back (-Z), 3: Left (-X), 4: Top (+Y), 5: Bottom (-Y)
    struct FaceCorners {
        QVector3D tl, tr, br, bl;
    };

    FaceCorners corners[6] = {
        // Face 0: Front (+Z)
        { QVector3D(-1,  1,  1), QVector3D( 1,  1,  1), QVector3D( 1, -1,  1), QVector3D(-1, -1,  1) },
        // Face 1: Right (+X)
        { QVector3D( 1,  1,  1), QVector3D( 1,  1, -1), QVector3D( 1, -1, -1), QVector3D( 1, -1,  1) },
        // Face 2: Back (-Z)
        { QVector3D( 1,  1, -1), QVector3D(-1,  1, -1), QVector3D(-1, -1, -1), QVector3D( 1, -1, -1) },
        // Face 3: Left (-X)
        { QVector3D(-1,  1, -1), QVector3D(-1,  1,  1), QVector3D(-1, -1,  1), QVector3D(-1, -1, -1) },
        // Face 4: Top (+Y)
        { QVector3D(-1,  1, -1), QVector3D( 1,  1, -1), QVector3D( 1,  1,  1), QVector3D(-1,  1,  1) },
        // Face 5: Bottom (-Y)
        { QVector3D(-1, -1,  1), QVector3D( 1, -1,  1), QVector3D( 1, -1, -1), QVector3D(-1, -1, -1) }
    };

    const int GRID = 4; // 4x4 sub-quads per face for distortion-free perspective mapping
    QVector<Quad3D> visibleQuads;
    visibleQuads.reserve(6 * GRID * GRID);

    for (int f = 0; f < 6; ++f) {
        int imgW = m_faces[f].width();
        int imgH = m_faces[f].height();
        if (imgW <= 0 || imgH <= 0)
            continue;

        const auto& fc = corners[f];

        for (int gy = 0; gy < GRID; ++gy) {
            float v0 = static_cast<float>(gy) / GRID;
            float v1 = static_cast<float>(gy + 1) / GRID;

            for (int gx = 0; gx < GRID; ++gx) {
                float u0 = static_cast<float>(gx) / GRID;
                float u1 = static_cast<float>(gx + 1) / GRID;

                // Bilinear interpolation for 4 corner points
                auto lerpFace = [&](float u, float v) -> QVector3D {
                    QVector3D top = fc.tl * (1.0f - u) + fc.tr * u;
                    QVector3D bot = fc.bl * (1.0f - u) + fc.br * u;
                    return top * (1.0f - v) + bot * v;
                };

                QVector3D p0 = transformVertex(lerpFace(u0, v0));
                QVector3D p1 = transformVertex(lerpFace(u1, v0));
                QVector3D p2 = transformVertex(lerpFace(u1, v1));
                QVector3D p3 = transformVertex(lerpFace(u0, v1));

                // Backface culling check using cross product in camera space
                QVector3D norm = QVector3D::crossProduct(p1 - p0, p3 - p0);
                if (QVector3D::dotProduct(norm, p0) >= 0.0f)
                    continue; // Facing away from camera

                float avgZ = (p0.z() + p1.z() + p2.z() + p3.z()) / 4.0f;
                if (p0.z() > 0.05f && p1.z() > 0.05f && p2.z() > 0.05f && p3.z() > 0.05f) {
                    Quad3D q;
                    q.v0 = p0;
                    q.v1 = p1;
                    q.v2 = p2;
                    q.v3 = p3;
                    q.srcRect = QRectF(u0 * imgW, v0 * imgH, (u1 - u0) * imgW, (v1 - v0) * imgH);
                    q.faceIndex = f;
                    q.avgZ = avgZ;
                    visibleQuads.append(q);
                }
            }
        }
    }

    // Sort visible quads by depth (Painter's algorithm: furthest first)
    std::sort(visibleQuads.begin(), visibleQuads.end(), [](const Quad3D& a, const Quad3D& b) {
        return a.avgZ > b.avgZ;
    });

    // Render quads
    for (const auto& q : visibleQuads) {
        QPointF pt0, pt1, pt2, pt3;
        if (project(q.v0, pt0) && project(q.v1, pt1) && project(q.v2, pt2) && project(q.v3, pt3)) {
            QPolygonF dstQuad;
            dstQuad << pt0 << pt1 << pt2 << pt3;

            QPolygonF srcQuad;
            srcQuad << q.srcRect.topLeft()
                    << q.srcRect.topRight()
                    << q.srcRect.bottomRight()
                    << q.srcRect.bottomLeft();

            QTransform xform;
            if (QTransform::quadToQuad(srcQuad, dstQuad, xform)) {
                painter->setTransform(xform, false);
                painter->drawImage(q.srcRect, m_faces[q.faceIndex], q.srcRect);
            }
        }
    }

    painter->resetTransform();
}

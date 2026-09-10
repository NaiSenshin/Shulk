// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QQuickImageProvider>
#include <QPixmap>
#include "ShulkRecentServerModel.h"

class ShulkServerIconProvider : public QQuickImageProvider {
public:
    explicit ShulkServerIconProvider(ShulkRecentServerModel* model)
        : QQuickImageProvider(QQuickImageProvider::Pixmap)
        , m_model(model)
    {}

    QPixmap requestPixmap(const QString& id, QSize* size, const QSize& requestedSize) override
    {
        int w = requestedSize.width() > 0 ? requestedSize.width() : 64;
        int h = requestedSize.height() > 0 ? requestedSize.height() : 64;
        if (size) *size = QSize(w, h);

        QString cleanId = id.section('?', 0, 0);

        if (m_model) {
            QByteArray bytes = m_model->getIconBytes(cleanId);
            if (!bytes.isEmpty()) {
                QPixmap px;
                if (px.loadFromData(bytes)) {
                    return px.scaled(w, h, Qt::KeepAspectRatio, Qt::SmoothTransformation);
                }
            }
        }

        // Fallback transparent or compass
        QPixmap fallback(":/shulk/icons/compass.png");
        if (!fallback.isNull()) {
            return fallback.scaled(w, h, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }

        QPixmap blank(w, h);
        blank.fill(Qt::transparent);
        return blank;
    }

private:
    ShulkRecentServerModel* m_model;
};

#pragma once

#include <QQuickImageProvider>
#include <QFileInfo>
#include <QPixmap>
#include <QIcon>
#include <QMutex>
#include <QMutexLocker>
#include "Application.h"
#include "icons/IconList.h"
#include "InstanceList.h"

class ShulkIconProvider : public QQuickImageProvider {
public:
    ShulkIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    ~ShulkIconProvider() override = default;

    QPixmap requestPixmap(const QString& id, QSize* size, const QSize& requestedSize) override
    {
        static QMutex s_iconMutex;
        QMutexLocker locker(&s_iconMutex);

        int w = requestedSize.width() > 0 ? requestedSize.width() : 128;
        int h = requestedSize.height() > 0 ? requestedSize.height() : 128;

        if (size) {
            *size = QSize(w, h);
        }

        if (QFileInfo::exists(id)) {
            QPixmap pix(id);
            if (!pix.isNull()) {
                return pix.scaled(w, h, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }
        }

        if (APPLICATION && APPLICATION->instances()) {
            auto inst = APPLICATION->instances()->getInstanceById(id);
            if (inst) {
                QString customIcon = inst->instanceRoot() + "/icon.png";
                if (QFileInfo::exists(customIcon)) {
                    QPixmap pix(customIcon);
                    if (!pix.isNull()) {
                        return pix.scaled(w, h, Qt::KeepAspectRatio, Qt::SmoothTransformation);
                    }
                }
            }
        }

        if (!APPLICATION || !APPLICATION->icons()) {
            QPixmap fallback(w, h);
            fallback.fill(Qt::transparent);
            return fallback;
        }

        QIcon icon = APPLICATION->icons()->getIcon(id);
        if (icon.isNull()) {
            icon = APPLICATION->icons()->getIcon("grass");
        }

        return icon.pixmap(w, h);
    }
};

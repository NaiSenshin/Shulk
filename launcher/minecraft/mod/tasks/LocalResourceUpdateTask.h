// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Prism Launcher - Minecraft Launcher
 *  Copyright (c) 2022 flowln <flowlnlnln@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, version 3.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma once

#include <QDir>
#include <QFuture>
#include <QFutureWatcher>

#include "modplatform/ModIndex.h"
#include "tasks/Task.h"

class LocalResourceUpdateTask : public Task {
    Q_OBJECT
   public:
    using Ptr = shared_qobject_ptr<LocalResourceUpdateTask>;

    explicit LocalResourceUpdateTask(QDir index_dir, ModPlatform::IndexedPack project, ModPlatform::IndexedVersion version);

    QString resolvedSlug() const { return m_resolvedSlug; }

    auto canAbort() const -> bool override { return true; }
    auto abort() -> bool override;

   protected slots:
    //! Entry point for tasks.
    void executeTask() override;

   private slots:
    void finishUpdate();

   signals:
    void hasOldResource(QString name, QString filename);

   private:
    struct UpdateResult {
        bool success = false;
        bool hasOldResource = false;
        QString oldName;
        QString oldFilename;
        QString resolvedSlug;
    };

    QDir m_index_dir;
    ModPlatform::IndexedPack m_project;
    ModPlatform::IndexedVersion m_version;
    QString m_resolvedSlug;
    QFuture<UpdateResult> m_updateFuture;
    QFutureWatcher<UpdateResult> m_updateWatcher;
};

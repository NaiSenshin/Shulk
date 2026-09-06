// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Prism Launcher - Minecraft Launcher
 *  Copyright (c) 2022 flowln <flowlnlnln@gmail.com>
 *  Copyright (C) 2022 Sefa Eyeoglu <contact@scrumplex.net>
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

#include "LocalResourceUpdateTask.h"

#include "FileSystem.h"
#include "minecraft/mod/MetadataHandler.h"

#include <QtConcurrentRun>

#ifdef Q_OS_WIN32
#include <windows.h>
#endif

LocalResourceUpdateTask::LocalResourceUpdateTask(QDir index_dir, ModPlatform::IndexedPack project, ModPlatform::IndexedVersion version)
    : m_index_dir(index_dir), m_project(std::move(project)), m_version(std::move(version))
{
    connect(&m_updateWatcher, &QFutureWatcher<UpdateResult>::finished, this, &LocalResourceUpdateTask::finishUpdate);

    // Ensure a '.index' folder exists in the mods folder, and create it if it does not
    if (!FS::ensureFolderPathExists(index_dir.path())) {
        emitFailed(QString("Unable to create index directory at %1!").arg(index_dir.absolutePath()));
        return;
    }

#ifdef Q_OS_WIN32
    std::wstring wpath = index_dir.path().toStdWString();
    if (index_dir.dirName().startsWith('.')) {
        SetFileAttributesW(wpath.c_str(), FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_NOT_CONTENT_INDEXED);
    } else {
        // fix shaderpacks folder being hidden by Prism Launcher 10.0.1
        SetFileAttributesW(wpath.c_str(), FILE_ATTRIBUTE_NORMAL);
    }
#endif
}

void LocalResourceUpdateTask::executeTask()
{
    setStatus(tr("Updating index for resource:\n%1").arg(m_project.name));

    const QDir indexDir = m_index_dir;
    auto project = m_project;
    auto version = m_version;
    m_updateFuture = QtConcurrent::run(QThreadPool::globalInstance(), [indexDir, project = std::move(project), version = std::move(version)]() mutable {
        UpdateResult result;

        // Looking metadata up by project ID scans and parses every file in the
        // index. During a large pack install that becomes O(n^2). Slugs map
        // directly to their metadata filename, so use the constant-time path
        // whenever the provider supplied one.
        auto oldMetadata = project.slug.isEmpty() ? Metadata::get(indexDir, project.addonId)
                                                   : Metadata::get(indexDir, project.slug);
        if (oldMetadata.isValid()) {
            result.hasOldResource = true;
            result.oldName = oldMetadata.name;
            result.oldFilename = oldMetadata.filename;
            if (project.slug.isEmpty())
                project.slug = oldMetadata.slug;
        }

        result.resolvedSlug = project.slug;
        auto metadata = Metadata::create(indexDir, project, version);
        if (!metadata.isValid())
            return result;

        Metadata::update(indexDir, metadata);
        result.success = true;
        return result;
    });
    m_updateWatcher.setFuture(m_updateFuture);
}

void LocalResourceUpdateTask::finishUpdate()
{
    if (m_updateFuture.isCanceled()) {
        emitAborted();
        return;
    }

    const auto result = m_updateFuture.result();
    m_resolvedSlug = result.resolvedSlug;
    if (result.hasOldResource)
        emit hasOldResource(result.oldName, result.oldFilename);

    if (result.success) {
        emitSucceeded();
    } else {
        qCritical() << "Tried to update an invalid resource!";
        emitFailed(tr("Invalid metadata"));
    }
}

auto LocalResourceUpdateTask::abort() -> bool
{
    if (!m_updateFuture.isRunning())
        return false;
    m_updateFuture.cancel();
    return true;
}

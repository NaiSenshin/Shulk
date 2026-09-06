// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkCreationService.h"
#include "GZip.h"
#include "Application.h"
#include "InstanceList.h"
#include "FileSystem.h"
#include "meta/Index.h"
#include "meta/VersionList.h"
#include "meta/Version.h"
#include "tasks/Task.h"
#include "minecraft/VanillaInstanceCreationTask.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "settings/INISettingsObject.h"
#include "InstanceImportTask.h"
#include "InstanceTask.h"
#include "BuildConfig.h"
#include "Json.h"
#include "modplatform/atlauncher/ATLPackInstallTask.h"
#include "modplatform/ftb/FTBPackInstallTask.h"
#include "modplatform/ftb/FTBPackManifest.h"
#include "modplatform/technic/SingleZipPackInstallTask.h"
#include "modplatform/technic/SolderPackInstallTask.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QCryptographicHash>
#include <QFileDialog>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QUrlQuery>
#include <algorithm>
#include <functional>

namespace {
class ShulkAtlInteractionSupport final : public ATLauncher::UserInteractionSupport {
public:
    std::optional<QList<QString>> chooseOptionalMods(const ATLauncher::PackVersion&, QList<ATLauncher::VersionMod> mods) override
    {
        QList<QString> selected;
        for (const auto& mod : mods) {
            if (mod.selected || mod.recommended)
                selected.append(mod.name);
        }
        return selected;
    }

    QString chooseVersion(Meta::VersionList::Ptr versions, QString minecraftVersion) override
    {
        for (const auto& version : versions->versions()) {
            if (!version->isRecommended())
                continue;
            const auto requirements = version->requiredSet();
            const auto match = std::find_if(requirements.cbegin(), requirements.cend(), [&minecraftVersion](const Meta::Require& req) {
                return req.uid == "net.minecraft" && req.equalsVersion == minecraftVersion;
            });
            if (minecraftVersion.isEmpty() || match != requirements.cend())
                return version->descriptor();
        }
        return versions->versions().isEmpty() ? QString() : versions->versions().first()->descriptor();
    }

    void displayMessage(QString message) override { qInfo() << "ATLauncher install message:" << message; }
};
}

ShulkCreationService::ShulkCreationService(QObject* parent)
    : QObject(parent)
{
    loadVersions();
}

void ShulkCreationService::loadFromDiskCache()
{
    QStringList candidates;
    if (APPLICATION && APPLICATION->metacache()) {
        auto entry = APPLICATION->metacache()->resolveEntry("meta", "net.minecraft/index.json");
        if (entry) {
            candidates.append(entry->getFullPath());
        }
    }
    candidates.append(QDir::homePath() + "/.local/share/PrismLauncher/meta/net.minecraft/index.json");
    candidates.append(QDir::homePath() + "/.local/share/prismlauncher/meta/net.minecraft/index.json");

    for (const QString& metaPath : candidates) {
        if (QFile::exists(metaPath)) {
            QFile file(metaPath);
            if (file.open(QIODevice::ReadOnly)) {
                QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
                if (doc.isObject()) {
                    QJsonObject obj = doc.object();
                    QJsonArray versionsArray = obj["versions"].toArray();
                    QStringList releases;
                    QStringList snapshots;
                    QStringList betas;
                    QStringList alphas;
                    QStringList all;

                    for (const auto& vVal : versionsArray) {
                        QJsonObject vObj = vVal.toObject();
                        QString version = vObj["version"].toString();
                        QString type = vObj["type"].toString().toLower();
                        if (version.isEmpty()) continue;

                        all.append(version);
                        if (type == "release" || type.isEmpty()) {
                            if (!releases.contains(version)) releases.append(version);
                        } else if (type.contains("snapshot") || type.contains("experiment")) {
                            if (!snapshots.contains(version)) snapshots.append(version);
                        } else if (type.contains("beta")) {
                            if (!betas.contains(version)) betas.append(version);
                        } else if (type.contains("alpha")) {
                            if (!alphas.contains(version)) alphas.append(version);
                        }
                    }

                    if (!releases.isEmpty()) {
                        m_releaseVersions = releases;
                        m_snapshotVersions = snapshots;
                        m_betaVersions = betas;
                        m_alphaVersions = alphas;
                        m_allVersions = all;
                        emit versionsLoaded();
                        return;
                    }
                }
            }
        }
    }
}

void ShulkCreationService::populateFromMetadataList(const std::shared_ptr<Meta::VersionList>& vlist)
{
    if (!vlist) return;

    QStringList releases;
    QStringList snapshots;
    QStringList betas;
    QStringList alphas;
    QStringList all;

    for (int i = 0; i < vlist->count(); ++i) {
        auto ver = std::dynamic_pointer_cast<Meta::Version>(vlist->at(i));
        if (!ver) continue;

        QString desc = ver->descriptor();
        if (desc.isEmpty()) continue;

        all.append(desc);

        QString type = ver->type().toLower();
        if (type == "release" || type.isEmpty()) {
            if (!releases.contains(desc)) releases.append(desc);
        } else if (type.contains("snapshot") || type.contains("experiment")) {
            if (!snapshots.contains(desc)) snapshots.append(desc);
        } else if (type.contains("beta")) {
            if (!betas.contains(desc)) betas.append(desc);
        } else if (type.contains("alpha")) {
            if (!alphas.contains(desc)) alphas.append(desc);
        }
    }

    if (!releases.isEmpty()) {
        m_releaseVersions = releases;
        m_snapshotVersions = snapshots;
        m_betaVersions = betas;
        m_alphaVersions = alphas;
        m_allVersions = all;
        emit versionsLoaded();
    }
}

void ShulkCreationService::loadVersions()
{
    loadFromDiskCache();

    if (APPLICATION && APPLICATION->metadataIndex()) {
        auto vlist = APPLICATION->metadataIndex()->get("net.minecraft");
        if (vlist) {
            if (vlist->isLoaded() && vlist->count() > 0) {
                populateFromMetadataList(vlist);
            } else {
                m_metaLoadTask = vlist->getLoadTask();
                if (m_metaLoadTask) {
                    connect(m_metaLoadTask.get(), &Task::succeeded, this, [this, vlist]() {
                        populateFromMetadataList(vlist);
                    });
                    if (!m_metaLoadTask->isRunning()) {
                        m_metaLoadTask->start();
                    }
                }
            }
        }
    }

    emit versionsLoaded();
}

QString ShulkCreationService::resolveLoaderVersion(const QString& loaderType, const QString& mcVersion)
{
    if (loaderType == "Vanilla" || loaderType.isEmpty()) {
        return QString();
    }

    QString loaderUid;
    if (loaderType == "Fabric") loaderUid = "net.fabricmc.fabric-loader";
    else if (loaderType == "NeoForge") loaderUid = "net.neoforged";
    else if (loaderType == "Forge") loaderUid = "net.minecraftforge";
    else if (loaderType == "Quilt") loaderUid = "org.quiltmc.quilt-loader";

    if (loaderUid.isEmpty()) return QString();

    if (APPLICATION && APPLICATION->metadataIndex()) {
        auto loaderList = APPLICATION->metadataIndex()->get(loaderUid);
        if (loaderList) {
            if (!loaderList->isLoaded()) {
                loaderList->waitToLoad();
            }
            if (loaderList->isLoaded()) {
                auto ver = loaderList->getRecommendedForParent("net.minecraft", mcVersion);
                if (!ver) {
                    ver = loaderList->getLatestForParent("net.minecraft", mcVersion);
                }
                if (ver) {
                    return ver->descriptor();
                }
                if (loaderType == "Fabric" || loaderType == "Quilt") {
                    auto rec = loaderList->getRecommended();
                    if (rec) return rec->descriptor();
                    if (loaderList->count() > 0) {
                        return loaderList->at(0)->descriptor();
                    }
                }
            }
        }
    }

    // Static compatibility fallbacks
    if (loaderType == "Fabric") return "0.16.10";
    if (loaderType == "Quilt") return "0.26.4";
    if (loaderType == "NeoForge") {
        if (mcVersion.startsWith("26.2")) return "26.2.0";
        if (mcVersion.startsWith("26.1")) return "26.1.0";
        if (mcVersion.startsWith("26.")) return "26.0.0";
        if (mcVersion.startsWith("1.21.1")) return "21.1.93";
        if (mcVersion.startsWith("1.21")) return "21.0.167";
        if (mcVersion.startsWith("1.20.6")) return "20.6.119";
        if (mcVersion.startsWith("1.20.4")) return "20.4.237";
        return "21.1.93";
    }
    if (loaderType == "Forge") {
        if (mcVersion.startsWith("1.21.1")) return "51.0.33";
        if (mcVersion.startsWith("1.21")) return "51.0.33";
        if (mcVersion == "1.20.1") return "47.3.0";
        if (mcVersion == "1.19.2") return "43.3.0";
        if (mcVersion == "1.18.2") return "40.2.0";
        if (mcVersion == "1.16.5") return "36.2.39";
        if (mcVersion == "1.12.2") return "14.23.5.2860";
        if (mcVersion == "1.7.10") return "10.13.4.1614";
        return "47.3.0";
    }
    return QString();
}

QStringList ShulkCreationService::getCompatibleLoaders(const QString& mcVersion) const
{
    QStringList list;
    list.append("Vanilla");

    // Historical versions, snapshots, pre-releases, and release candidates do
    // not have dependable loader metadata. Offering loaders here produced
    // profiles with empty or incompatible components.
    static const QRegularExpression stableRelease(R"(^\d+\.\d+(?:\.\d+)?$)");
    if (!stableRelease.match(mcVersion).hasMatch()) {
        return list;
    }

    // NeoForge supports 1.20.2+ and 26.x+
    bool supportsNeoForge = false;
    if (mcVersion.startsWith("2") || mcVersion.startsWith("1.21") || mcVersion.startsWith("1.22") ||
        mcVersion == "1.20.2" || mcVersion == "1.20.3" || mcVersion == "1.20.4" || mcVersion == "1.20.5" || mcVersion == "1.20.6") {
        supportsNeoForge = true;
    }

    list.append("Fabric");
    if (supportsNeoForge) {
        list.append("NeoForge");
    }
    list.append("Forge");
    list.append("Quilt");

    return list;
}


QVariantList ShulkCreationService::getSupportedPlatforms() const
{
    return {
        QVariantMap{
            {"id", "modrinth"},
            {"name", "Modrinth"},
            {"tagline", "Open-Source & Lightweight Modpacks"},
            {"icon", "qrc:/icons/multimc/scalable/instances/modrinth.svg"},
            {"badge", "Fast & Modern"}
        },
        QVariantMap{
            {"id", "curseforge"},
            {"name", "CurseForge"},
            {"tagline", "World's Largest Modpack Library"},
            {"icon", "qrc:/icons/multimc/scalable/instances/flame.svg"},
            {"badge", "50k+ Packs"}
        },
        QVariantMap{
            {"id", "ftb"},
            {"name", "Feed The Beast (FTB)"},
            {"tagline", "Legendary Progression & Tech Packs"},
            {"icon", "qrc:/icons/multimc/scalable/instances/ftb_logo.svg"},
            {"badge", "Official FTB"}
        },
        QVariantMap{
            {"id", "technic"},
            {"name", "Technic"},
            {"tagline", "Classic Modpacks & Tekkit"},
            {"icon", "qrc:/icons/multimc/scalable/technic.svg"},
            {"badge", "Classic"}
        },
        QVariantMap{
            {"id", "atlauncher"},
            {"name", "ATLauncher"},
            {"tagline", "Community Curated Packs"},
            {"icon", "qrc:/icons/multimc/scalable/atlauncher.svg"},
            {"badge", "Curated"}
        },
        QVariantMap{
            {"id", "vanilla"},
            {"name", "Vanilla & Custom"},
            {"tagline", "Clean Minecraft with Loader Selection"},
            {"icon", "qrc:/shulk/icons/grass_block.png"},
            {"badge", "Custom"}
        }
    };
}

QVariantList ShulkCreationService::getHandheldRecommendedPacks() const
{
    // Deliberately curated rather than popularity-sorted. Stable Modrinth IDs
    // keep installs working when a project's title or URL slug changes.
    return {
        QVariantMap{
            {"id", "1KVo5zza"},
            {"slug", "fabulously-optimized"},
            {"platform", "modrinth"},
            {"name", "Fabulously Optimized"},
            {"author", "Fabulously Optimized"},
            {"version", "26.2"},
            {"loader", "Fabric"},
            {"downloads", "16.8M"},
            {"iconUrl", "https://cdn.modrinth.com/data/1KVo5zza/d8152911f8fd5d7e9a8c499fe89045af81fe816e_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/1KVo5zza/images/38f70f307f1a0b17d8ed4526d1636317e8c12d1d_350.webp"},
            {"websiteUrl", "https://modrinth.com/modpack/fabulously-optimized"},
            {"description", "Beautiful graphics, speedy performance, controller support, and familiar features in a lightweight package."}
        },
        QVariantMap{
            {"id", "4UVaSgwi"},
            {"slug", "deck-craft"},
            {"platform", "modrinth"},
            {"name", "DeckCraft"},
            {"author", "DeckCraft"},
            {"version", "26.1.2"},
            {"loader", "Fabric"},
            {"downloads", "2.8K"},
            {"iconUrl", "https://cdn.modrinth.com/data/4UVaSgwi/935edc7466c93a8c20c543e639a3f78195d4271e_96.webp"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"websiteUrl", "https://modrinth.com/modpack/deck-craft"},
            {"description", "Fast performance and seamless controller play tuned for Steam Deck, ROG Ally, and other handheld PCs."}
        },
        QVariantMap{
            {"id", "g9O0WaGR"},
            {"slug", "legacy-minecraft"},
            {"platform", "modrinth"},
            {"name", "Re-Console"},
            {"author", "Legacy4J Project"},
            {"version", "26.2"},
            {"loader", "Fabric"},
            {"downloads", "567.8K"},
            {"iconUrl", "https://cdn.modrinth.com/data/g9O0WaGR/18e9ae214e1ca1bd8874abbcf6784948e224e1e8.png"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"websiteUrl", "https://modrinth.com/modpack/legacy-minecraft"},
            {"description", "A modern continuation of the Legacy Console Edition experience with controller-first menus, content, and quality-of-life features."}
        },
        QVariantMap{
            {"id", "f63ynpri"},
            {"slug", "simply-legacy"},
            {"platform", "modrinth"},
            {"name", "Simply Legacy"},
            {"author", "Legacy4J Project"},
            {"version", "26.1.2"},
            {"loader", "Fabric"},
            {"downloads", "22.6K"},
            {"iconUrl", "https://cdn.modrinth.com/data/f63ynpri/79dd6a009a4cb101837b931234f4ba146837df85.png"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"websiteUrl", "https://modrinth.com/modpack/simply-legacy"},
            {"description", "A faithful and performant Legacy Console Edition experience made for PCs, Steam Deck, and handheld play."}
        },
        QVariantMap{
            {"id", "shulk-official-handheld-modpack"},
            {"platform", "shulk"},
            {"name", "Shulk - Official Handheld Modpack"},
            {"author", "Shulk"},
            {"version", "Coming soon"},
            {"loader", "Official"},
            {"downloads", ""},
            {"iconUrl", "qrc:/shulk/icons/grass_block_side.png"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"description", "The official Shulk handheld experience is currently in development."},
            {"comingSoon", true}
        }
    };
}

QVariantList ShulkCreationService::getPacksForPlatform(const QString& platform, const QString& search) const
{
    QVariantList list;

    if (platform == "modrinth") {
        list.append(QVariantMap{
            {"name", "Fabulously Optimized"},
            {"author", "Fabulously Optimized"},
            {"version", "1.21.1"},
            {"loader", "Fabric"},
            {"downloads", "3.2M"},
            {"iconUrl", "https://cdn.modrinth.com/data/1KVo5zza/d8152911f8fd5d7e9a8c499fe89045af81fe816e_96.webp"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"downloadUrl", "https://cdn.modrinth.com/data/1KVo5zza/versions/N276l2ON/Fabulously.Optimized-v6.5.0.mrpack"},
            {"description", "A simple Minecraft modpack focusing on performance and graphics enhancements, shaders, and controller support."}
        });
        list.append(QVariantMap{
            {"name", "Cobblemon Official"},
            {"author", "Cobblemon Team"},
            {"version", "1.21.1"},
            {"loader", "Fabric"},
            {"downloads", "3.5M"},
            {"iconUrl", "https://cdn.modrinth.com/data/MdwFAVRL/abfca1654a2d09bab85cbffcc9869938c951ee0e_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/MdwFAVRL/images/1867aa59320a9616e2bde500870c45c41247da3f_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/5FFgwNNP/versions/Lydu1ZNo/Cobblemon%20Modpack%20%5BFabric%5D%201.7.3.mrpack"},
            {"description", "Pokemon in Minecraft Java Edition with open-world catching, battling, breeding, and multiplayer trading."}
        });
        list.append(QVariantMap{
            {"name", "DeckCraft (Handheld Edition)"},
            {"author", "DeckCraft Team"},
            {"version", "1.21.1"},
            {"loader", "Fabric"},
            {"downloads", "500k"},
            {"iconUrl", "https://cdn.modrinth.com/data/COSYIi8z/19b20dd389b7e93faf2d19ed0fc47b199c492a2f_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/COSYIi8z/images/08af58e3d6e8ec5bfa12b693ace76faa755ab929_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/jIj64hLM/versions/nUGzR12q/DeckCraft%20-%20SteamDeck%20and%20Minecraft%201.21.1%20v1.mrpack"},
            {"description", "Pre-configured for Steam Deck, ROG Ally, and handheld players with native controller glyphs and battery optimizations."}
        });
        list.append(QVariantMap{
            {"name", "Simply Optimized"},
            {"author", "Moulberry"},
            {"version", "1.21.1"},
            {"loader", "Fabric"},
            {"downloads", "1.8M"},
            {"iconUrl", "https://cdn.modrinth.com/data/Aa5L6RtV/2d323306d1e5909c81b3da0d57e9899383106f77_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/Aa5L6RtV/images/7ba22237cb3370f1a6ec710f6ce11467da510f22_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/Aa5L6RtV/versions/gWVLabDn/Universalized%20Optimized%201.21.1.mrpack"},
            {"description", "Built with only performance mods without changing vanilla gameplay or mechanics."}
        });
        list.append(QVariantMap{
            {"name", "Prominence II RPG"},
            {"author", "Luna Pixel Studios"},
            {"version", "1.20.1"},
            {"loader", "Fabric"},
            {"downloads", "1.9M"},
            {"iconUrl", "https://cdn.modrinth.com/data/EGs3lC8D/a0d0d63375454061b73003d0a47dd92503604a64_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/EGs3lC8D/images/fb6811a55f3d2b30f927d5677b0e459b9a915c06_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/EGs3lC8D/versions/b5Nkqpbt/Prominence%E2%84%A2%20II%20Hasturian%20Era%20v4.0.3.mrpack"},
            {"description", "Action RPG with talent skill trees, custom bosses, artifacts, and combat mechanics."}
        });
        list.append(QVariantMap{
            {"name", "Medieval MC [Fabric]"},
            {"author", "Luna Pixel Studios"},
            {"version", "1.21.1"},
            {"loader", "Fabric"},
            {"downloads", "2.1M"},
            {"iconUrl", "https://cdn.modrinth.com/data/cad6ZNtm/58091d927baf593d482cd7ee738875c78fadf69e_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/cad6ZNtm/images/ef2cbafef5b5b29094e9f73fc0f074d0818e9508_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/xHPl4iUd/versions/p0nIux3p/Medieval%20MC%20%5BFABRIC%5D%201.20.1%20v27.mrpack"},
            {"description", "Medieval RPG adventure featuring dragons, quests, origins, and combat."}
        });
        list.append(QVariantMap{
            {"name", "Create: Perfect World"},
            {"author", "SHXRKIE"},
            {"version", "1.20.1"},
            {"loader", "Forge"},
            {"downloads", "1.2M"},
            {"iconUrl", "https://cdn.modrinth.com/data/vJbRF8m0/b2b494366e28aabaa1b127e302ded6b67c2d3e6a_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/vJbRF8m0/images/e7e6f9872e4b4fbf3448a5ae01c56cb3c0b89f81_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/vJbRF8m0/versions/bK14kNHE/Create%3A%20Perfect%20World%207.0.0.mrpack"},
            {"description", "Automation, contraptions, steam engines, and sprawling logistics with Create."}
        });
        list.append(QVariantMap{
            {"name", "Fear Nightfall"},
            {"author", "Luna Pixel Studios"},
            {"version", "1.20.1"},
            {"loader", "Fabric"},
            {"downloads", "1.5M"},
            {"iconUrl", "https://cdn.modrinth.com/data/59qxFo3W/b65b7626eff817f20c7ed07bc21ae6e05b56c93b.jpeg"},
            {"bannerUrl", "https://cdn.modrinth.com/data/59qxFo3W/images/d37803e488b0a1aebdb9f45610bcde89b023f055_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/59qxFo3W/versions/kFoOyRmJ/Fear%20Nightfall%20Remains%20of%20Chaos%20v1.0.11.mrpack"},
            {"description", "Survival horror modpack featuring sanity mechanics, eerie atmosphere, and horrifying beasts."}
        });
    } else if (platform == "curseforge") {
        list.append(QVariantMap{
            {"id", "452013"},
            {"name", "Better MC [Forge]"},
            {"author", "SHXRKIE"},
            {"version", "1.20.1"},
            {"loader", "Forge"},
            {"downloads", "8.5M"},
            {"iconUrl", "https://cdn.modrinth.com/data/shFhR8Vx/a19c2bcb51d38f32f138d3607e91cb2b7b8e387f_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/shFhR8Vx/images/d6872a088924b1767bdf8f2bb7dbe7cf82329241_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/4BV47HRn/versions/bdRIjRgs/Better%20MC%20%5BFORGE%5D%201.20.1%201.20.1%20v59.mrpack"},
            {"description", "The definitive Minecraft sequel experience with dungeons, bosses, quests, and new dimensions."}
        });
        list.append(QVariantMap{
            {"id", "925200"},
            {"name", "All The Mods 10"},
            {"author", "ATM Team"},
            {"version", "1.21.1"},
            {"loader", "NeoForge"},
            {"downloads", "2.8M"},
            {"iconUrl", "https://cdn.modrinth.com/data/q9VbtJRz/b1f9f692d831b8c0fb47c1c9457bc9e55dd56431_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/q9VbtJRz/images/a83ae22f46aa27f6cf4c2eaae3ca2db2e6db5832_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/s9ZgH1gR/versions/Z16kUa2c/All%20the%20Mods%2010-1.21.1-1.0.mrpack"},
            {"description", "The biggest, most polished all-in-one kitchen-sink modpack featuring the newest 1.21 tech and magic."}
        });
        list.append(QVariantMap{
            {"id", "389615"},
            {"name", "The Pixelmon Modpack"},
            {"author", "Pixelmon Team"},
            {"version", "1.20.2"},
            {"loader", "Forge"},
            {"downloads", "4.2M"},
            {"iconUrl", "https://cdn.modrinth.com/data/vwgtbO0y/e16493aab7b0a32a2c9920cb0d89ebe06c4b3726_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/vwgtbO0y/images/a41498bfe13063f69bbcc2fc9a64bf7589d81d6d_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/vwgtbO0y/versions/v9.2.8/Pixelmon%201.20.2.mrpack"},
            {"description", "The official Pixelmon modpack with Pokémon battling, gym leaders, catching, and multiplayer trading."}
        });
        list.append(QVariantMap{
            {"id", "466901"},
            {"name", "Prominence II RPG"},
            {"author", "Luna Pixel Studios"},
            {"version", "1.20.1"},
            {"loader", "Fabric"},
            {"downloads", "1.9M"},
            {"iconUrl", "https://cdn.modrinth.com/data/EGs3lC8D/a0d0d63375454061b73003d0a47dd92503604a64_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/EGs3lC8D/images/fb6811a55f3d2b30f927d5677b0e459b9a915c06_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/EGs3lC8D/versions/b5Nkqpbt/Prominence%E2%84%A2%20II%20Hasturian%20Era%20v4.0.3.mrpack"},
            {"description", "Action RPG with talent skill trees, custom bosses, artifacts, and combat mechanics."}
        });
        list.append(QVariantMap{
            {"id", "548970"},
            {"name", "Medieval MC [Fabric]"},
            {"author", "Luna Pixel Studios"},
            {"version", "1.21.1"},
            {"loader", "Fabric"},
            {"downloads", "2.1M"},
            {"iconUrl", "https://cdn.modrinth.com/data/cad6ZNtm/58091d927baf593d482cd7ee738875c78fadf69e_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/cad6ZNtm/images/ef2cbafef5b5b29094e9f73fc0f074d0818e9508_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/xHPl4iUd/versions/p0nIux3p/Medieval%20MC%20%5BFABRIC%5D%201.20.1%20v27.mrpack"},
            {"description", "Medieval RPG adventure featuring dragons, quests, origins, and combat."}
        });
        list.append(QVariantMap{
            {"id", "687131"},
            {"name", "Cobblemon Official"},
            {"author", "Cobblemon Team"},
            {"version", "1.21.1"},
            {"loader", "Fabric"},
            {"downloads", "3.5M"},
            {"iconUrl", "https://cdn.modrinth.com/data/MdwFAVRL/abfca1654a2d09bab85cbffcc9869938c951ee0e_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/MdwFAVRL/images/1867aa59320a9616e2bde500870c45c41247da3f_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/5FFgwNNP/versions/Lydu1ZNo/Cobblemon%20Modpack%20%5BFabric%5D%201.7.3.mrpack"},
            {"description", "Pokemon in Minecraft Java Edition with open-world catching, battling, breeding, and multiplayer trading."}
        });
        list.append(QVariantMap{
            {"id", "828343"},
            {"name", "Create: Perfect World"},
            {"author", "SHXRKIE"},
            {"version", "1.20.1"},
            {"loader", "Forge"},
            {"downloads", "1.2M"},
            {"iconUrl", "https://cdn.modrinth.com/data/vJbRF8m0/b2b494366e28aabaa1b127e302ded6b67c2d3e6a_96.webp"},
            {"bannerUrl", "https://cdn.modrinth.com/data/vJbRF8m0/images/e7e6f9872e4b4fbf3448a5ae01c56cb3c0b89f81_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/vJbRF8m0/versions/bK14kNHE/Create%3A%20Perfect%20World%207.0.0.mrpack"},
            {"description", "Automation, contraptions, steam engines, and sprawling logistics with Create."}
        });
        list.append(QVariantMap{
            {"id", "868037"},
            {"name", "Fear Nightfall"},
            {"author", "Luna Pixel Studios"},
            {"version", "1.20.1"},
            {"loader", "Fabric"},
            {"downloads", "1.5M"},
            {"iconUrl", "https://cdn.modrinth.com/data/59qxFo3W/b65b7626eff817f20c7ed07bc21ae6e05b56c93b.jpeg"},
            {"bannerUrl", "https://cdn.modrinth.com/data/59qxFo3W/images/d37803e488b0a1aebdb9f45610bcde89b023f055_350.webp"},
            {"downloadUrl", "https://cdn.modrinth.com/data/59qxFo3W/versions/kFoOyRmJ/Fear%20Nightfall%20Remains%20of%20Chaos%20v1.0.11.mrpack"},
            {"description", "Survival horror modpack featuring sanity mechanics, eerie atmosphere, and horrifying beasts."}
        });
    } else if (platform == "ftb") {
        list.append(QVariantMap{
            {"id", "100"},
            {"packVersion", "1.11.6"},
            {"name", "FTB Stoneblock 3"},
            {"author", "FTB Team"},
            {"version", "1.18.2"},
            {"loader", "Forge"},
            {"downloads", "2.8M"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/5b/5b10fbf6e78546a5a4be81a2d311718cc24d29e4277e747028d787d6fec0be46.webp"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/98/98b53e2120cbc2dca41d65b5aac42862671f1d8b76d8374cd2cdde32bc24bb6e.webp"},
            {"description", "Start in a world of solid subterranean stone and build an underground high-tech empire."}
        });
        list.append(QVariantMap{
            {"id", "129"},
            {"packVersion", "1.22.0"},
            {"name", "FTB Skies 2"},
            {"author", "FTB Team"},
            {"version", "1.20.1"},
            {"loader", "Forge"},
            {"downloads", "1.1M"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/49/4951517d1bd2376e48d280427f95fd313c7aa778bddff582296651cfae7d7a9a.png"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/fa/fa54bcbbac82b179cef82d8ec655242b08145489f245161e000cae2cbd2eeed5.webp"},
            {"description", "A skyblock adventure filled with magic, tech, quests, and floating islands."}
        });
        list.append(QVariantMap{
            {"id", "128"},
            {"packVersion", "1.21.1"},
            {"name", "FTB OceanBlock 2"},
            {"author", "FTB Team"},
            {"version", "1.20.1"},
            {"loader", "Forge"},
            {"downloads", "1.4M"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/fa/fae647b9fa950ab09081ca6b395ea02dd06c7532b09b22fc3eb035b3092f7f78.png"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/25/25a20642012b13646cb9ac144040d08483f5a7ad6fb8ef8df21d84cccc472dfe.png"},
            {"description", "Survive on a solitary ocean raft and delve into underwater ruins and high-tech structures."}
        });
        list.append(QVariantMap{
            {"id", "35"},
            {"packVersion", "3.7.0"},
            {"name", "FTB Revelation"},
            {"author", "FTB Team"},
            {"version", "1.12.2"},
            {"loader", "Forge"},
            {"downloads", "4.2M"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/5b/5b10fbf6e78546a5a4be81a2d311718cc24d29e4277e747028d787d6fec0be46.webp"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/fa/fa54bcbbac82b179cef82d8ec655242b08145489f245161e000cae2cbd2eeed5.webp"},
            {"description", "Large, all-around general gameplay modpack designed for optimal performance and stability."}
        });
        list.append(QVariantMap{
            {"id", "23"},
            {"packVersion", "3.1.0"},
            {"name", "FTB Infinity Evolved"},
            {"author", "FTB Team"},
            {"version", "1.7.10"},
            {"loader", "Forge"},
            {"downloads", "5.8M"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/22/225f0af85acc4fa904d3ff5e4e136e1985b94968191548e52ee73073d634c6b1.webp"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/70/70bbf9d88b162c1db8c020ba4456ebc439186964e91a08a1c4c2a8114bbeb675.webp"},
            {"description", "The definitive 1.7.10 kitchen-sink pack featuring Normal and Expert progression modes."}
        });
        list.append(QVariantMap{
            {"id", "119"},
            {"packVersion", "1.16.1"},
            {"name", "FTB Presents Direwolf20 1.20"},
            {"author", "FTB Team"},
            {"version", "1.20.1"},
            {"loader", "Forge"},
            {"downloads", "1.8M"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/49/4951517d1bd2376e48d280427f95fd313c7aa778bddff582296651cfae7d7a9a.png"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/27/277a26e6554e0905d344ae0b6053da08b37e2455e3cbbd1f06b16914bb2042cf.webp"},
            {"description", "Play along with Direwolf20 in his official YouTube let's play modpack series."}
        });
        list.append(QVariantMap{
            {"id", "132"},
            {"packVersion", "1.9.0"},
            {"name", "FTB Unstable 6"},
            {"author", "FTB Team"},
            {"version", "1.21.1"},
            {"loader", "NeoForge"},
            {"downloads", "350k"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/ed/edcf789ac64f2c0b4fb23c742269f36ebeb47342678e4e8f1f2c0d0fd5d878b0.webp"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/70/70bbf9d88b162c1db8c020ba4456ebc439186964e91a08a1c4c2a8114bbeb675.webp"},
            {"description", "Modern flagship FTB progression pack featuring the newest tech and automation mods."}
        });
        list.append(QVariantMap{
            {"id", "134"},
            {"packVersion", "1.9.1"},
            {"name", "FTB Skies: Aero"},
            {"author", "FTB Team"},
            {"version", "1.20.1"},
            {"loader", "Forge"},
            {"downloads", "1.9M"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/22/225f0af85acc4fa904d3ff5e4e136e1985b94968191548e52ee73073d634c6b1.webp"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/27/277a26e6554e0905d344ae0b6053da08b37e2455e3cbbd1f06b16914bb2042cf.webp"},
            {"description", "Airship exploration, sky islands, and high-altitude tech progression."}
        });
        list.append(QVariantMap{
            {"id", "88"},
            {"packVersion", "1.4.1"},
            {"name", "FTB Academy 1.16"},
            {"author", "FTB Team"},
            {"version", "1.16.5"},
            {"loader", "Forge"},
            {"downloads", "1.2M"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/5b/5b10fbf6e78546a5a4be81a2d311718cc24d29e4277e747028d787d6fec0be46.webp"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/98/98b53e2120cbc2dca41d65b5aac42862671f1d8b76d8374cd2cdde32bc24bb6e.webp"},
            {"description", "Interactive guided tutorial modpack designed to teach modded Minecraft to beginners."}
        });
        list.append(QVariantMap{
            {"id", "108"},
            {"packVersion", "1.5.2"},
            {"name", "FTB University 1.19"},
            {"author", "FTB Team"},
            {"version", "1.19.2"},
            {"loader", "Forge"},
            {"downloads", "880k"},
            {"iconUrl", "https://cdn.feed-the-beast.com/blob/49/4951517d1bd2376e48d280427f95fd313c7aa778bddff582296651cfae7d7a9a.png"},
            {"bannerUrl", "https://cdn.feed-the-beast.com/blob/fa/fa54bcbbac82b179cef82d8ec655242b08145489f245161e000cae2cbd2eeed5.webp"},
            {"description", "In-depth advanced quest-driven tutorial pack teaching complex tech, magic, and automation mods."}
        });
    } else if (platform == "technic") {
        list.append(QVariantMap{
            {"id", "tekkit-2"},
            {"name", "Tekkit 2"},
            {"author", "Technic Team"},
            {"version", "1.12.2"},
            {"loader", "Forge"},
            {"downloads", "1.2M"},
            {"iconUrl", "https://cdn.technicpack.net/platform2/pack-icons/1935271.png?1765909988"},
            {"bannerUrl", "https://cdn.technicpack.net/platform2/pack-backgrounds/1935271.jpg?1765909988"},
            {"description", "The official sequel to the iconic Tekkit with IndustrialCraft, BuildCraft, and Galacticraft."}
        });
        list.append(QVariantMap{
            {"id", "the-1710-pack"},
            {"name", "The 1.7.10 Pack"},
            {"author", "JonBams"},
            {"version", "1.7.10"},
            {"loader", "Forge"},
            {"downloads", "4.9M"},
            {"iconUrl", "https://cdn.technicpack.net/platform2/pack-icons/453902.png?1765911029"},
            {"bannerUrl", "https://cdn.technicpack.net/platform2/pack-backgrounds/453902.jpg?1765911029"},
            {"description", "One of the most popular packs in history with over 200 classic mods and quests."}
        });
        list.append(QVariantMap{
            {"id", "hexxit"},
            {"name", "Hexxit"},
            {"author", "Technic Team"},
            {"version", "1.12.2"},
            {"loader", "Forge"},
            {"downloads", "890k"},
            {"iconUrl", "https://cdn.technicpack.net/platform2/pack-icons/552552.png?1631992531"},
            {"bannerUrl", "https://cdn.technicpack.net/platform2/pack-backgrounds/552552.jpg?1631992531"},
            {"description", "Dungeons, towers, ancient gear, and old-school adventurous dungeon crawling."}
        });
        list.append(QVariantMap{
            {"id", "attack-of-the-bteam"},
            {"name", "Attack of the B-Team"},
            {"author", "B-Team"},
            {"version", "1.6.4"},
            {"loader", "Forge"},
            {"downloads", "3.4M"},
            {"iconUrl", "https://cdn.technicpack.net/platform2/pack-icons/552556.png?1631992549"},
            {"bannerUrl", "https://cdn.technicpack.net/platform2/pack-backgrounds/552556.jpg?1631992549"},
            {"description", "Crazy science, morphing, genetics, witchery, and wacky adventures."}
        });
        list.append(QVariantMap{
            {"id", "blightfall"},
            {"name", "Blightfall"},
            {"author", "Talonos"},
            {"version", "1.7.10"},
            {"loader", "Forge"},
            {"downloads", "1.1M"},
            {"iconUrl", "https://cdn.technicpack.net/platform2/pack-icons/592618.png?1706744314"},
            {"bannerUrl", "https://cdn.technicpack.net/platform2/pack-backgrounds/592618.jpg?1706744314"},
            {"description", "A story-driven adventure modpack about clearing an alien continent of purple taint."}
        });
    } else if (platform == "atlauncher") {
        list.append(QVariantMap{
            {"id", "23"},
            {"safeName", "SevTechAges"},
            {"name", "SevTech: Ages"},
            {"packVersion", "3.2.3"},
            {"author", "Darkosto"},
            {"version", "1.12.2"},
            {"loader", "Forge"},
            {"downloads", "4.1M"},
            {"iconUrl", "https://download.nodecdn.net/containers/atl/launcher/images/sevtechages.png"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"description", "The legendary era-based progression pack where you unlock technology from the Stone Age to Space."}
        });
        list.append(QVariantMap{
            {"id", "286"},
            {"safeName", "SkyFactory4"},
            {"name", "SkyFactory 4"},
            {"packVersion", "4.2.4"},
            {"author", "Darkosto"},
            {"version", "1.12.2"},
            {"loader", "Forge"},
            {"downloads", "3.8M"},
            {"iconUrl", "https://download.nodecdn.net/containers/atl/launcher/images/skyfactory4.png"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"description", "Full automation, tech, and magic starting on a solitary dirt tree in the void."}
        });
        list.append(QVariantMap{
            {"id", "1"},
            {"safeName", "ResonantRise"},
            {"name", "Resonant Rise"},
            {"packVersion", "5.0.0-pre.3"},
            {"author", "ATLauncher"},
            {"version", "1.12.2"},
            {"loader", "Forge"},
            {"downloads", "1.5M"},
            {"iconUrl", "https://download.nodecdn.net/containers/atl/launcher/images/resonantrise.png"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"description", "A long-running kitchen-sink pack with technology, magic, exploration, and automation."}
        });
        list.append(QVariantMap{
            {"id", "300"},
            {"safeName", "PixelmonMod"},
            {"name", "Pixelmon Mod"},
            {"packVersion", "Pixelmon-1.21.1-9.4.0"},
            {"author", "Pixelmon Team"},
            {"version", "1.21.1"},
            {"loader", "NeoForge"},
            {"downloads", "900k"},
            {"iconUrl", "https://download.nodecdn.net/containers/atl/launcher/images/pixelmonmod.png"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"description", "The official Pixelmon experience with Pokémon catching, battling, and exploration."}
        });
        list.append(QVariantMap{
            {"id", "116"},
            {"safeName", "Unabridged"},
            {"name", "Unabridged"},
            {"packVersion", "3.21.2"},
            {"author", "ATLauncher"},
            {"version", "1.7.10"},
            {"loader", "Forge"},
            {"downloads", "600k"},
            {"iconUrl", "https://download.nodecdn.net/containers/atl/launcher/images/unabridged.png"},
            {"bannerUrl", "qrc:/shulk/assets/default_pack_banner.jpg"},
            {"description", "A broad 1.7.10 mod collection built for exploration, technology, and magic."}
        });
    }

    for (int i = 0; i < list.size(); ++i) {
        auto m = list[i].toMap();
        m["platform"] = platform;
        if (!m.contains("id") || m["id"].toString().isEmpty()) {
            m["id"] = m["name"].toString().toLower().replace(' ', '-');
        }
        if (!m.contains("websiteUrl") || m["websiteUrl"].toString().isEmpty()) {
            if (platform == "modrinth") {
                m["websiteUrl"] = "https://modrinth.com/modpack/" + m["id"].toString();
            } else if (platform == "curseforge") {
                m["websiteUrl"] = "https://www.curseforge.com/minecraft/modpacks/" + m["id"].toString();
            } else if (platform == "ftb") {
                m["websiteUrl"] = "https://feed-the-beast.com/modpacks";
            } else if (platform == "technic") {
                m["websiteUrl"] = "https://www.technicpack.net";
            } else if (platform == "atlauncher") {
                m["websiteUrl"] = "https://atlauncher.com/packs";
            }
        }
        list[i] = m;
    }

    if (!search.trimmed().isEmpty()) {
        QVariantList filtered;
        QString q = search.trimmed().toLower();
        for (const auto& item : list) {
            auto m = item.toMap();
            if (m["name"].toString().toLower().contains(q) ||
                m["description"].toString().toLower().contains(q) ||
                m["author"].toString().toLower().contains(q)) {
                filtered.append(item);
            }
        }
        return filtered;
    }

    return list;
}

void ShulkCreationService::searchPlatform(const QString& platform, const QString& query)
{
    m_isSearching = true;
    m_searchStatus = tr("Searching %1 database...").arg(platform);
    emit isSearchingChanged();
    emit searchStatusChanged();

    QString cleanQuery = query.trimmed();

    if (platform == "modrinth") {
        QString urlStr;
        if (cleanQuery.isEmpty()) {
            urlStr = QString("%1/search?facets=[[\"project_type:modpack\"]]&index=downloads&limit=40").arg(BuildConfig.MODRINTH_PROD_URL);
        } else {
            urlStr = QString("%1/search?query=%2&facets=[[\"project_type:modpack\"]]&limit=40")
                         .arg(BuildConfig.MODRINTH_PROD_URL, QString::fromUtf8(QUrl::toPercentEncoding(cleanQuery)));
        }

        QNetworkRequest req((QUrl(urlStr)));
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk (Handheld Launcher)");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, platform, cleanQuery]() {
            reply->deleteLater();
            m_isSearching = false;
            m_searchStatus = tr("Ready");
            emit isSearchingChanged();
            emit searchStatusChanged();

            if (reply->error() != QNetworkReply::NoError) {
                qWarning() << "Shulk: Modrinth search error:" << reply->errorString();
                emit searchFailed(platform, reply->errorString());
                emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
                return;
            }

            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonArray hits = doc.object().value("hits").toArray();
            QVariantList results;

            for (const auto& hitVal : hits) {
                auto hit = hitVal.toObject();
                QVariantMap item;
                item["id"] = hit.value("project_id").toString();
                item["name"] = hit.value("title").toString();
                item["description"] = hit.value("description").toString();
                item["author"] = hit.value("author").toString();
                item["iconUrl"] = hit.value("icon_url").toString();

                qint64 dl = hit.value("downloads").toInteger();
                if (dl >= 1000000) item["downloads"] = QString::number(dl / 1000000.0, 'f', 1) + "M";
                else if (dl >= 1000) item["downloads"] = QString::number(dl / 1000.0, 'f', 0) + "k";
                else item["downloads"] = QString::number(dl);

                auto versions = hit.value("versions").toArray();
                item["version"] = versions.isEmpty() ? "1.21.1" : versions.last().toString();

                auto categories = hit.value("categories").toArray();
                QString loader = "Fabric";
                for (const auto& c : categories) {
                    QString s = c.toString().toLower();
                    if (s == "neoforge") { loader = "NeoForge"; break; }
                    if (s == "forge") { loader = "Forge"; break; }
                    if (s == "fabric") { loader = "Fabric"; break; }
                    if (s == "quilt") { loader = "Quilt"; break; }
                }
                item["loader"] = loader;

                auto gallery = hit.value("gallery").toArray();
                if (!gallery.isEmpty()) {
                    item["bannerUrl"] = gallery.first().toString();
                } else {
                    item["bannerUrl"] = "qrc:/shulk/assets/default_pack_banner.jpg";
                }

                item["downloadUrl"] = "";
                item["platform"] = "modrinth";
                item["websiteUrl"] = QString("https://modrinth.com/modpack/%1").arg(hit.value("slug").toString().isEmpty() ? item["id"].toString() : hit.value("slug").toString());
                results.append(item);
            }

            if (results.isEmpty()) {
                emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
            } else {
                emit searchFinished(platform, results);
            }
        });
        return;
    }

    if (platform == "curseforge") {
        QString urlStr;
        if (cleanQuery.isEmpty()) {
            urlStr = QString("%1/mods/search?gameId=432&classId=4471&sortField=2&sortOrder=desc&pageSize=40")
                         .arg(BuildConfig.FLAME_BASE_URL);
        } else {
            urlStr = QString("%1/mods/search?gameId=432&classId=4471&searchFilter=%2&sortField=2&sortOrder=desc&pageSize=40")
                         .arg(BuildConfig.FLAME_BASE_URL, QString::fromUtf8(QUrl::toPercentEncoding(cleanQuery)));
        }

        QNetworkRequest req((QUrl(urlStr)));
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        req.setRawHeader("x-api-key", BuildConfig.FLAME_API_KEY.toUtf8());
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, platform, cleanQuery]() {
            reply->deleteLater();
            m_isSearching = false;
            m_searchStatus = tr("Ready");
            emit isSearchingChanged();
            emit searchStatusChanged();

            if (reply->error() != QNetworkReply::NoError) {
                qWarning() << "Shulk: CurseForge search error:" << reply->errorString();
                emit searchFailed(platform, reply->errorString());
                emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
                return;
            }

            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonArray items = doc.object().value("data").toArray();
            QVariantList results;

            for (const auto& itVal : items) {
                auto it = itVal.toObject();
                QVariantMap item;
                item["id"] = QString::number(it.value("id").toInteger());
                item["name"] = it.value("name").toString();
                item["description"] = it.value("summary").toString();
                auto authors = it.value("authors").toArray();
                item["author"] = authors.isEmpty() ? "Unknown" : authors.first().toObject().value("name").toString();
                item["iconUrl"] = it.value("logo").toObject().value("thumbnailUrl").toString();

                qint64 dl = it.value("downloadCount").toInteger();
                if (dl >= 1000000) item["downloads"] = QString::number(dl / 1000000.0, 'f', 1) + "M";
                else if (dl >= 1000) item["downloads"] = QString::number(dl / 1000.0, 'f', 0) + "k";
                else item["downloads"] = QString::number(dl);

                auto indexes = it.value("latestFilesIndexes").toArray();
                QString mcVer = "1.20.1";
                QString loader = "Forge";
                if (!indexes.isEmpty()) {
                    mcVer = indexes.first().toObject().value("gameVersion").toString();
                    int lType = indexes.first().toObject().value("modLoader").toInt();
                    if (lType == 1) loader = "Forge";
                    else if (lType == 4) loader = "Fabric";
                    else if (lType == 6) loader = "NeoForge";
                    else if (lType == 5) loader = "Quilt";
                }
                item["version"] = mcVer;
                item["loader"] = loader;
                item["bannerUrl"] = "qrc:/shulk/assets/default_pack_banner.jpg";
                item["downloadUrl"] = "";
                item["platform"] = "curseforge";
                item["websiteUrl"] = it.value("links").toObject().value("websiteUrl").toString();

                results.append(item);
            }

            if (results.isEmpty()) {
                emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
            } else {
                emit searchFinished(platform, results);
            }
        });
        return;
    }

    if (platform == "technic") {
        QString urlStr;
        if (cleanQuery.isEmpty()) {
            urlStr = QString("%1trending?build=%2").arg(BuildConfig.TECHNIC_API_BASE_URL, BuildConfig.TECHNIC_API_BUILD);
        } else {
            urlStr = QString("%1search?build=%2&q=%3")
                         .arg(BuildConfig.TECHNIC_API_BASE_URL, BuildConfig.TECHNIC_API_BUILD, QString::fromUtf8(QUrl::toPercentEncoding(cleanQuery)));
        }

        QNetworkRequest req((QUrl(urlStr)));
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, platform, cleanQuery]() {
            reply->deleteLater();
            m_isSearching = false;
            m_searchStatus = tr("Ready");
            emit isSearchingChanged();
            emit searchStatusChanged();

            if (reply->error() != QNetworkReply::NoError) {
                qWarning() << "Shulk: Technic search error:" << reply->errorString();
                emit searchFailed(platform, reply->errorString());
                emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
                return;
            }

            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonArray items = doc.object().value("modpacks").toArray();
            QVariantList results;

            for (const auto& itVal : items) {
                auto it = itVal.toObject();
                QVariantMap item;
                item["id"] = it.value("slug").toString().isEmpty() ? it.value("name").toString() : it.value("slug").toString();
                item["name"] = it.value("displayName").toString().isEmpty() ? it.value("name").toString() : it.value("displayName").toString();
                item["description"] = it.value("description").toString();
                item["author"] = it.value("user").toString();
                item["iconUrl"] = it.value("iconUrl").toString();
                if (item["iconUrl"].toString().isEmpty()) item["iconUrl"] = it.value("icon").toObject().value("url").toString();
                item["bannerUrl"] = it.value("backgroundUrl").toString();
                if (item["bannerUrl"].toString().isEmpty()) item["bannerUrl"] = it.value("background").toObject().value("url").toString();
                item["version"] = it.value("minecraft").toString().isEmpty() ? "1.12.2" : it.value("minecraft").toString();
                item["loader"] = "Forge";

                qint64 dl = it.value("downloads").toInteger();
                if (dl >= 1000000) item["downloads"] = QString::number(dl / 1000000.0, 'f', 1) + "M";
                else if (dl >= 1000) item["downloads"] = QString::number(dl / 1000.0, 'f', 0) + "k";
                else item["downloads"] = QString::number(dl);

                item["downloadUrl"] = it.value("url").toString();
                item["platform"] = "technic";
                item["websiteUrl"] = it.value("url").toString();
                results.append(item);
            }

            if (results.isEmpty()) {
                emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
            } else {
                emit searchFinished(platform, results);
            }
        });
        return;
    }

    if (platform == "ftb") {
        m_isSearching = false;
        m_searchStatus = tr("Ready");
        emit isSearchingChanged();
        emit searchStatusChanged();
        emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
        return;
    }

    if (platform == "atlauncher") {
        auto parseAtlPacks = [this, platform, cleanQuery](const QByteArray& data) {
            m_isSearching = false;
            m_searchStatus = tr("Ready");
            emit isSearchingChanged();
            emit searchStatusChanged();

            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonArray packs = doc.array();
            QVariantList results;

            for (const auto& pVal : packs) {
                auto p = pVal.toObject();
                QString name = p.value("name").toString();
                QString desc = p.value("description").toString();
                const auto versions = p.value("versions").toArray();
                if (p.value("system").toBool() || p.value("type").toString() != "public" || versions.isEmpty())
                    continue;

                if (!cleanQuery.isEmpty()) {
                    if (!name.contains(cleanQuery, Qt::CaseInsensitive) &&
                        !desc.contains(cleanQuery, Qt::CaseInsensitive)) {
                        continue;
                    }
                }

                QVariantMap item;
                item["id"] = QString::number(p.value("id").toInteger());
                item["name"] = name;
                item["description"] = desc;
                item["author"] = "ATLauncher";
                const auto latest = versions.isEmpty() ? QJsonObject() : versions.first().toObject();
                item["version"] = latest.value("minecraft").toString("Latest");
                item["packVersion"] = latest.value("version").toString();
                item["loader"] = "Forge";
                item["downloads"] = "1M+";

                QString iconFile = p.value("launcherImage").toString();
                if (iconFile.isEmpty()) iconFile = p.value("image").toString();
                if (!iconFile.isEmpty()) {
                    item["iconUrl"] = QString("https://download.nodecdn.net/containers/atl/launcher/images/%1").arg(iconFile);
                } else {
                    item["iconUrl"] = "qrc:/icons/multimc/scalable/atlauncher.svg";
                }
                item["bannerUrl"] = "qrc:/shulk/assets/default_pack_banner.jpg";
                item["platform"] = "atlauncher";
                item["websiteUrl"] = "https://atlauncher.com/packs";

                results.append(item);
                if (results.size() >= 40) break;
            }

            if (results.isEmpty()) {
                emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
            } else {
                emit searchFinished(platform, results);
            }
        };

        if (!m_cachedAtlData.isEmpty()) {
            parseAtlPacks(m_cachedAtlData);
            return;
        }

        QString urlStr = QString("%1launcher/json/packsnew.json").arg(BuildConfig.ATL_DOWNLOAD_SERVER_URL);
        QNetworkRequest req((QUrl(urlStr)));
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, parseAtlPacks, platform, cleanQuery]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                m_isSearching = false;
                m_searchStatus = tr("Ready");
                emit isSearchingChanged();
                emit searchStatusChanged();
                emit searchFailed(platform, reply->errorString());
                emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
                return;
            }
            m_cachedAtlData = reply->readAll();
            parseAtlPacks(m_cachedAtlData);
        });
        return;
    }

    // Default fallback
    m_isSearching = false;
    m_searchStatus = tr("Ready");
    emit isSearchingChanged();
    emit searchStatusChanged();
    emit searchFinished(platform, getPacksForPlatform(platform, cleanQuery));
}

void ShulkCreationService::searchContent(const QString& contentType,
                                         const QString& query,
                                         const QString& minecraftVersion,
                                         const QString& loaderType)
{
    static const QHash<QString, QString> projectTypes = {
        { "mods", "mod" },
        { "resourcepacks", "resourcepack" },
        { "shaderpacks", "shader" }
    };

    const QString projectType = projectTypes.value(contentType);
    if (projectType.isEmpty()) {
        emit contentSearchFailed(contentType, tr("Unsupported content type."));
        return;
    }

    m_isContentSearching = true;
    m_contentStatus = tr("Searching Modrinth...");
    emit isContentSearchingChanged();
    emit contentStatusChanged();

    QJsonArray facets;
    facets.append(QJsonArray{QString("project_type:%1").arg(projectType)});
    if (!minecraftVersion.isEmpty())
        facets.append(QJsonArray{QString("versions:%1").arg(minecraftVersion)});

    const QString loader = loaderType.trimmed().toLower();
    if (contentType == "mods" && !loader.isEmpty() && loader != "vanilla")
        facets.append(QJsonArray{QString("categories:%1").arg(loader)});

    QUrl url(QString("%1/search").arg(BuildConfig.MODRINTH_PROD_URL));
    QUrlQuery urlQuery;
    if (!query.trimmed().isEmpty())
        urlQuery.addQueryItem("query", query.trimmed());
    urlQuery.addQueryItem("facets", QString::fromUtf8(QJsonDocument(facets).toJson(QJsonDocument::Compact)));
    urlQuery.addQueryItem("index", "downloads");
    urlQuery.addQueryItem("limit", "40");
    url.setQuery(urlQuery);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk (Handheld Launcher)");
    auto reply = APPLICATION->network()->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, contentType]() {
        reply->deleteLater();
        m_isContentSearching = false;
        m_contentStatus = tr("Ready");
        emit isContentSearchingChanged();
        emit contentStatusChanged();

        if (reply->error() != QNetworkReply::NoError) {
            emit contentSearchFailed(contentType, reply->errorString());
            return;
        }

        const QJsonDocument document = QJsonDocument::fromJson(reply->readAll());
        const QJsonArray hits = document.object().value("hits").toArray();
        QVariantList results;
        for (const auto& value : hits) {
            const QJsonObject hit = value.toObject();
            QVariantMap item;
            item["id"] = hit.value("project_id").toString();
            item["slug"] = hit.value("slug").toString();
            item["name"] = hit.value("title").toString();
            item["description"] = hit.value("description").toString();
            item["author"] = hit.value("author").toString();
            item["iconUrl"] = hit.value("icon_url").toString();
            const qint64 downloads = hit.value("downloads").toInteger();
            if (downloads >= 1000000)
                item["downloads"] = QString::number(downloads / 1000000.0, 'f', 1) + "M";
            else if (downloads >= 1000)
                item["downloads"] = QString::number(downloads / 1000.0, 'f', 0) + "k";
            else
                item["downloads"] = QString::number(downloads);
            results.append(item);
        }
        emit contentSearchFinished(contentType, results);
    });
}

void ShulkCreationService::installContent(const QString& instanceId,
                                          const QString& contentType,
                                          const QString& projectId,
                                          const QString& displayName,
                                          const QString& minecraftVersion,
                                          const QString& loaderType)
{
    if (m_isContentInstalling || !APPLICATION || !APPLICATION->instances())
        return;

    auto instance = APPLICATION->instances()->getInstanceById(instanceId);
    if (!instance) {
        emit contentInstallFailed(contentType, tr("The selected profile could not be found."));
        return;
    }
    if (contentType == "mods" && loaderType.compare("Vanilla", Qt::CaseInsensitive) == 0) {
        emit contentInstallFailed(contentType, tr("This profile needs Fabric, NeoForge, Forge, or Quilt before mods can be installed."));
        return;
    }

    QString targetDirectory;
    if (contentType == "mods")
        targetDirectory = instance->modsRoot();
    else if (contentType == "resourcepacks")
        targetDirectory = instance->resourcePacksDir();
    else if (contentType == "shaderpacks")
        targetDirectory = instance->shaderPacksDir();
    else {
        emit contentInstallFailed(contentType, tr("Unsupported content type."));
        return;
    }

    if (!QDir().mkpath(targetDirectory)) {
        emit contentInstallFailed(contentType, tr("Could not create the destination folder."));
        return;
    }

    struct ContentInstallState {
        QString instanceId;
        QString contentType;
        QString displayName;
        QString targetDirectory;
        QString minecraftVersion;
        QString loader;
        QSet<QString> visited;
        int dependenciesInstalled = 0;
        bool finished = false;
        std::function<void(const QString&, const QString&, const QString&, std::function<void()>)> installProject;
    };

    auto state = std::make_shared<ContentInstallState>();
    state->instanceId = instanceId;
    state->contentType = contentType;
    state->displayName = displayName;
    state->targetDirectory = targetDirectory;
    state->minecraftVersion = minecraftVersion;
    state->loader = loaderType.trimmed().toLower();

    m_isContentInstalling = true;
    m_contentStatus = tr("Finding a compatible version of %1...").arg(displayName);
    emit isContentInstallingChanged();
    emit contentStatusChanged();

    auto fail = [this, state](const QString& error) {
        if (state->finished)
            return;
        state->finished = true;
        state->installProject = {};
        m_isContentInstalling = false;
        m_contentStatus = tr("Ready");
        emit isContentInstallingChanged();
        emit contentStatusChanged();
        emit contentInstallFailed(state->contentType, error);
    };

    auto succeed = [this, state]() {
        if (state->finished)
            return;
        state->finished = true;
        state->installProject = {};
        m_isContentInstalling = false;
        m_contentStatus = state->dependenciesInstalled > 0
                              ? tr("%1 installed with %2 required dependencies")
                                    .arg(state->displayName)
                                    .arg(state->dependenciesInstalled)
                              : tr("%1 installed").arg(state->displayName);
        emit isContentInstallingChanged();
        emit contentStatusChanged();
        emit contentInstallFinished(state->contentType, state->displayName);
    };

    state->installProject = [this, state, fail](const QString& dependencyProjectId,
                                                const QString& dependencyVersionId,
                                                const QString& itemName,
                                                std::function<void()> done) {
        if (state->finished)
            return;

        const QString visitKey = dependencyVersionId.isEmpty() ? "project:" + dependencyProjectId : "version:" + dependencyVersionId;
        if (dependencyProjectId.isEmpty() && dependencyVersionId.isEmpty()) {
            done();
            return;
        }
        if (state->visited.contains(visitKey)) {
            done();
            return;
        }
        state->visited.insert(visitKey);

        QUrl versionUrl;
        const bool exactVersion = !dependencyVersionId.isEmpty();
        if (exactVersion) {
            versionUrl = QUrl(QString("%1/version/%2").arg(BuildConfig.MODRINTH_PROD_URL, dependencyVersionId));
        } else {
            versionUrl = QUrl(QString("%1/project/%2/version").arg(BuildConfig.MODRINTH_PROD_URL, dependencyProjectId));
            QUrlQuery query;
            if (!state->minecraftVersion.isEmpty())
                query.addQueryItem("game_versions", QString::fromUtf8(QJsonDocument(QJsonArray{state->minecraftVersion}).toJson(QJsonDocument::Compact)));
            if (state->contentType == "mods" && !state->loader.isEmpty() && state->loader != "vanilla")
                query.addQueryItem("loaders", QString::fromUtf8(QJsonDocument(QJsonArray{state->loader}).toJson(QJsonDocument::Compact)));
            versionUrl.setQuery(query);
        }

        QNetworkRequest versionRequest(versionUrl);
        versionRequest.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk (Handheld Launcher)");
        auto versionReply = APPLICATION->network()->get(versionRequest);
        connect(versionReply, &QNetworkReply::finished, this,
                [this, state, fail, versionReply, exactVersion, itemName, done = std::move(done)]() mutable {
            versionReply->deleteLater();
            if (state->finished)
                return;
            if (versionReply->error() != QNetworkReply::NoError) {
                fail(tr("Could not resolve required item %1: %2").arg(itemName, versionReply->errorString()));
                return;
            }

            QJsonParseError parseError;
            const auto document = QJsonDocument::fromJson(versionReply->readAll(), &parseError);
            if (parseError.error != QJsonParseError::NoError) {
                fail(tr("Modrinth returned invalid version data for %1.").arg(itemName));
                return;
            }

            QJsonObject version;
            if (exactVersion && document.isObject()) {
                version = document.object();
            } else if (document.isArray() && !document.array().isEmpty()) {
                version = document.array().first().toObject();
            }
            if (version.isEmpty()) {
                fail(tr("No compatible release of %1 was found for Minecraft %2 and %3.")
                         .arg(itemName, state->minecraftVersion, state->loader));
                return;
            }

            const QJsonArray files = version.value("files").toArray();
            QJsonObject chosenFile;
            for (const auto& fileValue : files) {
                const auto file = fileValue.toObject();
                if (chosenFile.isEmpty() || file.value("primary").toBool()) {
                    chosenFile = file;
                    if (file.value("primary").toBool())
                        break;
                }
            }

            const QUrl downloadUrl(chosenFile.value("url").toString());
            QString fileName = chosenFile.value("filename").toString();
            fileName.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
            const QByteArray expectedSha512 = chosenFile.value("hashes").toObject().value("sha512").toString().toLatin1().toLower();
            if (!downloadUrl.isValid() || fileName.isEmpty()) {
                fail(tr("The compatible release of %1 has no downloadable file.").arg(itemName));
                return;
            }

            auto installFile = [this, state, fail, itemName, downloadUrl, fileName, expectedSha512, done = std::move(done)]() mutable {
                if (state->finished)
                    return;

                const QString destination = QDir(state->targetDirectory).filePath(fileName);
                QFile existing(destination);
                if (existing.open(QIODevice::ReadOnly)) {
                    const bool matches = expectedSha512.isEmpty() ||
                                         QCryptographicHash::hash(existing.readAll(), QCryptographicHash::Sha512).toHex() == expectedSha512;
                    if (matches) {
                        qInfo() << "Shulk: required content already installed:" << fileName;
                        done();
                        return;
                    }
                }

                m_contentStatus = tr("Downloading %1...").arg(itemName);
                emit contentStatusChanged();
                QNetworkRequest downloadRequest(downloadUrl);
                downloadRequest.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk (Handheld Launcher)");
                auto downloadReply = APPLICATION->network()->get(downloadRequest);
                connect(downloadReply, &QNetworkReply::finished, this,
                        [this, state, fail, downloadReply, itemName, fileName, expectedSha512, done = std::move(done)]() mutable {
                    downloadReply->deleteLater();
                    if (state->finished)
                        return;
                    if (downloadReply->error() != QNetworkReply::NoError) {
                        fail(tr("Could not download %1: %2").arg(itemName, downloadReply->errorString()));
                        return;
                    }

                    const QByteArray payload = downloadReply->readAll();
                    if (!expectedSha512.isEmpty() &&
                        QCryptographicHash::hash(payload, QCryptographicHash::Sha512).toHex() != expectedSha512) {
                        fail(tr("The downloaded file for %1 failed its integrity check.").arg(itemName));
                        return;
                    }
                    if (!APPLICATION || !APPLICATION->instances() ||
                        !APPLICATION->instances()->getInstanceById(state->instanceId)) {
                        fail(tr("The profile was removed before the download finished."));
                        return;
                    }

                    QSaveFile output(QDir(state->targetDirectory).filePath(fileName));
                    if (!output.open(QIODevice::WriteOnly) || output.write(payload) != payload.size() || !output.commit()) {
                        fail(tr("Could not save %1 to the profile.").arg(itemName));
                        return;
                    }

                    qInfo() << "Shulk: installed content:" << fileName;
                    if (itemName != state->displayName)
                        ++state->dependenciesInstalled;
                    done();
                });
            };

            QJsonArray requiredDependencies;
            for (const auto& dependencyValue : version.value("dependencies").toArray()) {
                const auto dependency = dependencyValue.toObject();
                if (dependency.value("dependency_type").toString() == "required")
                    requiredDependencies.append(dependency);
            }

            auto dependencyIndex = std::make_shared<int>(0);
            auto installNext = std::make_shared<std::function<void()>>();
            std::weak_ptr<std::function<void()>> weakInstallNext = installNext;
            *installNext = [state, fail, requiredDependencies, dependencyIndex, weakInstallNext, installFile = std::move(installFile)]() mutable {
                if (state->finished)
                    return;
                if (*dependencyIndex >= requiredDependencies.size()) {
                    installFile();
                    return;
                }

                const auto dependency = requiredDependencies.at((*dependencyIndex)++).toObject();
                const QString childProjectId = dependency.value("project_id").toString();
                const QString childVersionId = dependency.value("version_id").toString();
                const QString childName = childProjectId.isEmpty() ? childVersionId : childProjectId;
                // Keep the continuation alive while the asynchronous child install runs.
                // The callable itself only holds a weak reference, so this does not form
                // a permanent self-reference after the dependency chain completes.
                const auto next = weakInstallNext.lock();
                if (!next) {
                    fail(QStringLiteral("Dependency installation was interrupted."));
                    return;
                }
                state->installProject(childProjectId, childVersionId, childName, [next]() { (*next)(); });
            };
            (*installNext)();
        });
    };

    state->installProject(projectId, QString(), displayName, succeed);
}

void ShulkCreationService::createProfile(const QString& name,
                                         const QString& mcVersion,
                                         const QString& loaderType,
                                         const QString& loaderVersion,
                                         const QString& group,
                                         const QString& iconKey)
{
    if (name.trimmed().isEmpty() || mcVersion.trimmed().isEmpty()) {
        emit profileCreationFailed(tr("Profile name and Minecraft version are required."));
        return;
    }

    if (!APPLICATION || !APPLICATION->instances()) {
        emit profileCreationFailed(tr("The profile library is not available."));
        return;
    }

    m_isCreating = true;
    m_creationStatus = tr("Creating profile \"%1\"...").arg(name);
    emit isCreatingChanged();
    emit creationStatusChanged();

    auto failCreation = [this](const QString& error) {
        m_isCreating = false;
        m_creationStatus = tr("Ready");
        emit isCreatingChanged();
        emit creationStatusChanged();
        emit profileCreationFailed(error);
    };

    QString cleanName = name.trimmed();
    QString targetId = cleanName.toLower();
    targetId.replace(QRegularExpression(R"([^a-z0-9._-]+)"), "_");
    targetId.remove(QRegularExpression(R"(^[._-]+|[._-]+$)"));
    if (targetId.isEmpty()) {
        targetId = "minecraft";
    }
    QString baseDir = APPLICATION->instances()->primaryDir();
    if (baseDir.isEmpty()) {
        failCreation(tr("The profile folder is not configured."));
        return;
    }
    QString targetDir = FS::PathCombine(baseDir, targetId);

    int suffix = 1;
    while (QDir(targetDir).exists()) {
        targetDir = FS::PathCombine(baseDir, QString("%1_%2").arg(targetId).arg(suffix++));
    }

    if (!QDir().mkpath(targetDir) ||
        !QDir().mkpath(FS::PathCombine(targetDir, "minecraft")) ||
        !QDir().mkpath(FS::PathCombine(targetDir, "minecraft", "mods"))) {
        failCreation(tr("Could not create the profile folder."));
        return;
    }

    // Write instance.cfg
    QString cfgPath = FS::PathCombine(targetDir, "instance.cfg");
    QString cfgContent = QString(
        "InstanceType=OneSix\n"
        "name=%1\n"
        "iconKey=%2\n"
        "%3"
        "totalTimePlayed=0\n"
        "lastTimePlayed=0\n"
    ).arg(cleanName, iconKey.isEmpty() ? "grass" : iconKey, group.isEmpty() ? "" : QString("group=%1\n").arg(group));

    QFile cfgFile(cfgPath);
    if (!cfgFile.open(QIODevice::WriteOnly | QIODevice::Text) || cfgFile.write(cfgContent.toUtf8()) < 0) {
        cfgFile.close();
        QDir(targetDir).removeRecursively();
        failCreation(tr("Could not write the profile configuration."));
        return;
    }
    cfgFile.close();

    // Build mmc-pack.json
    const QString normalizedLoader = loaderType.trimmed();
    QString loaderUid = "";
    if (normalizedLoader.compare("Fabric", Qt::CaseInsensitive) == 0) {
        loaderUid = "net.fabricmc.fabric-loader";
    } else if (normalizedLoader.compare("NeoForge", Qt::CaseInsensitive) == 0) {
        loaderUid = "net.neoforged";
    } else if (normalizedLoader.compare("Forge", Qt::CaseInsensitive) == 0) {
        loaderUid = "net.minecraftforge";
    } else if (normalizedLoader.compare("Quilt", Qt::CaseInsensitive) == 0) {
        loaderUid = "org.quiltmc.quilt-loader";
    }

    QString packJsonPath = FS::PathCombine(targetDir, "mmc-pack.json");
    QJsonObject packObj;
    packObj["formatVersion"] = 1;

    QJsonArray components;

    QJsonObject mcComp;
    mcComp["uid"] = "net.minecraft";
    mcComp["version"] = mcVersion;
    mcComp["cachedName"] = "Minecraft";
    mcComp["cachedVersion"] = mcVersion;
    mcComp["important"] = true;
    components.append(mcComp);

    if (!loaderUid.isEmpty()) {
        QJsonObject loaderComp;
        loaderComp["uid"] = loaderUid;
        QString chosenLoaderVersion = loaderVersion.trimmed();
        if (chosenLoaderVersion.isEmpty()) {
            chosenLoaderVersion = resolveLoaderVersion(normalizedLoader, mcVersion);
        }
        if (chosenLoaderVersion.isEmpty()) {
            QDir(targetDir).removeRecursively();
            failCreation(tr("No compatible %1 version was found for Minecraft %2.").arg(normalizedLoader, mcVersion));
            return;
        }
        loaderComp["version"] = chosenLoaderVersion;
        loaderComp["cachedVersion"] = chosenLoaderVersion;
        loaderComp["cachedName"] = normalizedLoader + " Loader";
        components.append(loaderComp);
    }

    packObj["components"] = components;

    QJsonDocument doc(packObj);
    QFile packFile(packJsonPath);
    if (!packFile.open(QIODevice::WriteOnly) || packFile.write(doc.toJson()) < 0) {
        packFile.close();
        QDir(targetDir).removeRecursively();
        failCreation(tr("Could not write the Minecraft version configuration."));
        return;
    }
    packFile.close();

    const QString createdInstanceId = QFileInfo(targetDir).fileName();

    // Refresh instances list to discover new profile, then load the component
    // file immediately so every Shulk view sees the selected game and loader.
    if (APPLICATION && APPLICATION->instances()) {
        APPLICATION->instances()->loadList();
        auto instance = APPLICATION->instances()->getInstanceById(createdInstanceId);
        if (instance && instance->getPackProfile()) {
            instance->getPackProfile()->reload(Net::Mode::Offline);
        }
    }

    m_isCreating = false;
    m_creationStatus = tr("Ready");
    emit isCreatingChanged();
    emit creationStatusChanged();
    emit profileCreated(createdInstanceId);
}

void ShulkCreationService::importModpackFile()
{
    if (m_isCreating || !APPLICATION || !APPLICATION->instances())
        return;

    QString startDirectory = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (startDirectory.isEmpty())
        startDirectory = QDir::homePath();

    const QString filter = tr("Supported modpacks (*.mrpack *.zip);;Modrinth packs (*.mrpack);;Modpack archives (*.zip)");
    const QUrl sourceUrl = QFileDialog::getOpenFileUrl(nullptr,
                                                       tr("Import a modpack"),
                                                       QUrl::fromLocalFile(startDirectory),
                                                       filter);
    if (!sourceUrl.isValid() || sourceUrl.isEmpty())
        return;
    if (!sourceUrl.isLocalFile()) {
        emit profileCreationFailed(tr("Choose a modpack file stored on this device."));
        return;
    }

    const QFileInfo sourceFile(sourceUrl.toLocalFile());
    const QString extension = sourceFile.suffix().toLower();
    if (!sourceFile.isFile() || (extension != "mrpack" && extension != "zip")) {
        emit profileCreationFailed(tr("Choose a valid .mrpack or .zip modpack file."));
        return;
    }

    const QString packName = sourceFile.completeBaseName().trimmed().isEmpty()
                                 ? tr("Imported Modpack")
                                 : sourceFile.completeBaseName().trimmed();

    m_isCreating = true;
    m_creationStatus = tr("Importing modpack \"%1\"...").arg(packName);
    emit isCreatingChanged();
    emit creationStatusChanged();

    auto importTask = new InstanceImportTask(sourceUrl, false, nullptr);
    importTask->setName(packName);
    importTask->setGroup("Modpacks");
    importTask->setIcon("default");
    importTask->setTargetDir(APPLICATION->instances()->primaryDir());

    auto stagingTask = APPLICATION->instances()->wrapInstanceTask(importTask);
    connect(stagingTask, &Task::succeeded, this, [this, packName]() {
        m_isCreating = false;
        m_creationStatus = tr("Ready");
        emit isCreatingChanged();
        emit creationStatusChanged();
        if (APPLICATION && APPLICATION->instances()) {
            APPLICATION->instances()->loadList();
            emit APPLICATION->instances()->instancesChanged();
        }
        emit profileCreated(packName);
    });
    connect(stagingTask, &Task::failed, this, [this](const QString& error) {
        m_isCreating = false;
        m_creationStatus = tr("Ready");
        emit isCreatingChanged();
        emit creationStatusChanged();
        emit profileCreationFailed(error);
    });
    connect(stagingTask, &Task::status, this, [this](const QString& status) {
        m_creationStatus = status;
        emit creationStatusChanged();
    });
    connect(stagingTask, &Task::progress, this, [this, packName](qint64 current, qint64 total) {
        if (total > 0) {
            const int percentage = static_cast<int>((current * 100) / total);
            m_creationStatus = tr("Importing %1 (%2%)...").arg(packName).arg(percentage);
            emit creationStatusChanged();
        }
    });
    stagingTask->start();
}

void ShulkCreationService::startPackInstall(InstanceTask* installTask, const QString& name, const QString& iconUrl)
{
    m_lastCreationProgress = -1;
    installTask->setName(name);
    installTask->setGroup("Modpacks");
    installTask->setIcon(iconUrl.isEmpty() ? "grass" : "icon");
    installTask->setTargetDir(APPLICATION->instances()->primaryDir());

    auto stagingTask = APPLICATION->instances()->wrapInstanceTask(installTask);
    connect(stagingTask, &Task::succeeded, this, [this, name, iconUrl]() {
        m_isCreating = false;
        m_creationStatus = tr("Ready");
        emit isCreatingChanged();
        emit creationStatusChanged();
        if (!iconUrl.isEmpty() && (iconUrl.startsWith("http://") || iconUrl.startsWith("https://"))) {
            for (int i = 0; i < APPLICATION->instances()->count(); ++i) {
                auto inst = APPLICATION->instances()->at(i);
                if (!inst || inst->name() != name)
                    continue;
                const QString targetDir = inst->instanceRoot();
                auto nam = new QNetworkAccessManager(this);
                auto reply = nam->get(QNetworkRequest(QUrl(iconUrl)));
                connect(reply, &QNetworkReply::finished, this, [reply, nam, targetDir]() {
                    if (reply->error() == QNetworkReply::NoError) {
                        QFile file(targetDir + "/icon.png");
                        if (file.open(QIODevice::WriteOnly))
                            file.write(reply->readAll());
                    }
                    reply->deleteLater();
                    nam->deleteLater();
                });
                break;
            }
        }
        emit profileCreated(name);
    });
    connect(stagingTask, &Task::failed, this, [this](const QString& error) {
        m_isCreating = false;
        m_creationStatus = tr("Ready");
        emit isCreatingChanged();
        emit creationStatusChanged();
        emit profileCreationFailed(error);
    });
    connect(stagingTask, &Task::status, this, [this](const QString& status) {
        // Extraction already supplies percentage progress. Relaying a unique
        // filename for every archive entry needlessly forces thousands of QML
        // text/layout updates on large packs.
        if (status.startsWith(QStringLiteral("Unpacking:")))
            return;
        m_creationStatus = status;
        emit creationStatusChanged();
    });
    connect(stagingTask, &Task::progress, this, [this, name](qint64 current, qint64 total) {
        if (total > 0) {
            const int percentage = static_cast<int>((current * 100) / total);
            if (percentage == m_lastCreationProgress)
                return;
            m_lastCreationProgress = percentage;
            m_creationStatus = tr("Installing %1 (%2%)...").arg(name).arg(percentage);
            emit creationStatusChanged();
        }
    });
    stagingTask->start();
}

void ShulkCreationService::installModpack(const QString& name,
                                          const QString& mcVersion,
                                          const QString& loaderType,
                                          const QString& iconUrl,
                                          const QString& bannerUrl,
                                          const QString& description,
                                          const QString& author,
                                          const QString& downloadUrl,
                                          const QString& projectId,
                                          const QString& platform,
                                          const QString& packVersion)
{
    if (name.trimmed().isEmpty())
        return;

    m_isCreating = true;
    m_creationStatus = tr("Installing modpack \"%1\"...").arg(name);
    emit isCreatingChanged();
    emit creationStatusChanged();

    QString cleanName = name.trimmed();

    if (platform == "curseforge" && downloadUrl.trimmed().isEmpty()) {
        const QString url = QString("%1/mods/%2/files?pageSize=50").arg(BuildConfig.FLAME_BASE_URL, projectId);
        QNetworkRequest request{ QUrl(url) };
        request.setRawHeader("x-api-key", BuildConfig.FLAME_API_KEY.toUtf8());
        request.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        auto reply = APPLICATION->network()->get(request);
        connect(reply, &QNetworkReply::finished, this, [this, reply, cleanName, mcVersion, loaderType, iconUrl, bannerUrl, description, author,
                                                        projectId, platform, packVersion]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("Could not load CurseForge releases: %1").arg(reply->errorString()));
                return;
            }
            const auto files = QJsonDocument::fromJson(reply->readAll()).object().value("data").toArray();
            QJsonObject chosen;
            for (const auto& value : files) {
                const auto file = value.toObject();
                const auto versions = file.value("gameVersions").toArray();
                bool compatible = mcVersion.isEmpty();
                for (const auto& version : versions) {
                    if (version.toString() == mcVersion) { compatible = true; break; }
                }
                if (compatible && file.value("releaseType").toInt(1) == 1) { chosen = file; break; }
                if (chosen.isEmpty() && compatible) chosen = file;
            }
            if (chosen.isEmpty()) {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("CurseForge has no compatible release for %1.").arg(cleanName));
                return;
            }
            QString fileUrl = chosen.value("downloadUrl").toString();
            const QString fileName = chosen.value("fileName").toString();
            const qint64 fileId = chosen.value("id").toInteger();
            if (fileUrl.isEmpty() && fileId > 0 && !fileName.isEmpty()) {
                const QString id = QString::number(fileId);
                fileUrl = QString("https://edge.forgecdn.net/files/%1/%2/%3")
                              .arg(id.left(id.size() - 3), id.right(3), QString::fromUtf8(QUrl::toPercentEncoding(fileName)));
            }
            if (fileUrl.isEmpty()) {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("CurseForge did not provide a downloadable file for %1.").arg(cleanName));
                return;
            }
            QMap<QString, QString> extraInfo{{"pack_id", projectId}, {"pack_version_id", QString::number(fileId)}};
            auto task = new InstanceImportTask(QUrl(fileUrl), true, nullptr, extraInfo);
            startPackInstall(task, cleanName, iconUrl);
        });
        return;
    }

    if (platform == "ftb") {
        bool validId = false;
        const int numericId = projectId.toInt(&validId);
        if (!validId) {
            m_isCreating = false;
            emit isCreatingChanged();
            emit profileCreationFailed(tr("FTB pack metadata is missing a valid pack ID."));
            return;
        }
        QNetworkRequest request{ QUrl(QString(BuildConfig.FTB_API_BASE_URL + "/modpack/%1").arg(numericId)) };
        auto reply = APPLICATION->network()->get(request);
        connect(reply, &QNetworkReply::finished, this, [this, reply, cleanName, iconUrl, packVersion]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("Could not load FTB pack metadata: %1").arg(reply->errorString()));
                return;
            }
            try {
                auto object = QJsonDocument::fromJson(reply->readAll()).object();
                FTB::Modpack pack;
                FTB::loadModpack(pack, object);
                QString version = packVersion;
                if (version.isEmpty() && !pack.versions.isEmpty())
                    version = pack.versions.last().name;
                if (version.isEmpty()) {
                    m_isCreating = false;
                    emit isCreatingChanged();
                    emit profileCreationFailed(tr("FTB has no installable release for %1.").arg(cleanName));
                    return;
                }
                startPackInstall(new FTB::PackInstallTask(pack, version), cleanName, iconUrl);
            } catch (const JSONValidationError& error) {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("Could not read FTB pack metadata: %1").arg(error.cause()));
            }
        });
        return;
    }

    if (platform == "technic") {
        const QString metadataUrl = QString("%1modpack/%2?build=%3").arg(BuildConfig.TECHNIC_API_BASE_URL, projectId,
                                                                         BuildConfig.TECHNIC_API_BUILD);
        auto reply = APPLICATION->network()->get(QNetworkRequest(QUrl(metadataUrl)));
        connect(reply, &QNetworkReply::finished, this, [this, reply, cleanName, iconUrl, projectId, mcVersion]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("Could not load Technic pack metadata: %1").arg(reply->errorString()));
                return;
            }
            const auto object = QJsonDocument::fromJson(reply->readAll()).object();
            const QString minecraft = object.value("minecraft").toString(mcVersion);
            const QString directUrl = object.value("url").toString();
            QString solderUrl = object.value("solder").toString();
            while (solderUrl.endsWith('/')) solderUrl.chop(1);
            const QString release = object.value("version").toString();
            if (!directUrl.isEmpty()) {
                startPackInstall(new Technic::SingleZipPackInstallTask(QUrl(directUrl), minecraft), cleanName, iconUrl);
            } else if (!solderUrl.isEmpty() && !release.isEmpty()) {
                startPackInstall(new Technic::SolderPackInstallTask(APPLICATION->network(), QUrl(solderUrl), projectId, release, minecraft),
                                 cleanName, iconUrl);
            } else {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("Technic did not provide an installable release for %1.").arg(cleanName));
            }
        });
        return;
    }

    if (platform == "atlauncher") {
        auto beginInstall = [this, cleanName, iconUrl](const QString& version) {
            if (version.isEmpty()) {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("ATLauncher has no installable release for %1.").arg(cleanName));
                return;
            }
            startPackInstall(new ATLauncher::PackInstallTask(new ShulkAtlInteractionSupport, cleanName, version), cleanName, iconUrl);
        };
        if (!packVersion.isEmpty()) {
            beginInstall(packVersion);
            return;
        }
        auto resolveVersion = [this, cleanName, beginInstall](const QByteArray& data) {
            const auto packs = QJsonDocument::fromJson(data).array();
            for (const auto& value : packs) {
                const auto pack = value.toObject();
                if (pack.value("name").toString().compare(cleanName, Qt::CaseInsensitive) != 0)
                    continue;
                const auto versions = pack.value("versions").toArray();
                beginInstall(versions.isEmpty() ? QString() : versions.first().toObject().value("version").toString());
                return;
            }
            beginInstall(QString());
        };
        if (!m_cachedAtlData.isEmpty()) {
            resolveVersion(m_cachedAtlData);
            return;
        }
        auto reply = APPLICATION->network()->get(QNetworkRequest(QUrl(BuildConfig.ATL_DOWNLOAD_SERVER_URL + "launcher/json/packsnew.json")));
        connect(reply, &QNetworkReply::finished, this, [this, reply, resolveVersion]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                m_isCreating = false;
                emit isCreatingChanged();
                emit profileCreationFailed(tr("Could not load ATLauncher releases: %1").arg(reply->errorString()));
                return;
            }
            m_cachedAtlData = reply->readAll();
            resolveVersion(m_cachedAtlData);
        });
        return;
    }

    if (!downloadUrl.isEmpty() && (downloadUrl.startsWith("http://") || downloadUrl.startsWith("https://"))) {
        QUrl sourceUrl(downloadUrl);
        auto importTask = new InstanceImportTask(sourceUrl, true, nullptr);
        startPackInstall(importTask, cleanName, iconUrl);
        return;
    }

    if (downloadUrl.trimmed().isEmpty()) {
        m_creationStatus = tr("Resolving package for \"%1\"...").arg(cleanName);
        emit creationStatusChanged();

        QString slug = projectId.trimmed();
        if (slug.isEmpty()) {
            slug = cleanName.toLower();
            slug.replace(" ", "-").replace(":", "").replace("'", "").replace("[", "").replace("]", "");
        }
        QUrl versionUrl(QString("%1/project/%2/version").arg(BuildConfig.MODRINTH_PROD_URL, slug));
        QUrlQuery query;
        if (!mcVersion.trimmed().isEmpty() && mcVersion.compare("Latest", Qt::CaseInsensitive) != 0)
            query.addQueryItem("game_versions", QString::fromUtf8(QJsonDocument(QJsonArray{mcVersion}).toJson(QJsonDocument::Compact)));
        if (!loaderType.trimmed().isEmpty() && loaderType.compare("Vanilla", Qt::CaseInsensitive) != 0)
            query.addQueryItem("loaders", QString::fromUtf8(QJsonDocument(QJsonArray{loaderType.toLower()}).toJson(QJsonDocument::Compact)));
        query.addQueryItem("include_changelog", "false");
        versionUrl.setQuery(query);
        QNetworkRequest req(versionUrl);
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this,
                [this, reply, cleanName, mcVersion, loaderType, iconUrl, bannerUrl, description, author, projectId, platform, packVersion]() {
            reply->deleteLater();
            if (reply->error() == QNetworkReply::NoError) {
                QByteArray data = reply->readAll();
                QJsonDocument doc = QJsonDocument::fromJson(data);
                QJsonArray versions = doc.array();
                if (!versions.isEmpty()) {
                    for (const auto& vVal : versions) {
                        auto files = vVal.toObject().value("files").toArray();
                        for (const auto& fVal : files) {
                            auto f = fVal.toObject();
                            QString fUrl = f.value("url").toString();
                            if (fUrl.endsWith(".mrpack", Qt::CaseInsensitive) || f.value("primary").toBool()) {
                                installModpack(cleanName, mcVersion, loaderType, iconUrl, bannerUrl, description, author, fUrl, projectId,
                                               platform, packVersion);
                                return;
                            }
                        }
                    }
                }
            }

            m_isCreating = false;
            m_creationStatus = tr("Ready");
            emit isCreatingChanged();
            emit creationStatusChanged();
            emit profileCreationFailed(tr("Could not find a downloadable release package for \"%1\".").arg(cleanName));
        });
        return;
    }

    m_isCreating = false;
    m_creationStatus = tr("Ready");
    emit isCreatingChanged();
    emit creationStatusChanged();
    emit profileCreationFailed(tr("This modpack does not have an active download package available."));
}

void ShulkCreationService::fetchPackDetails(const QString& platform, const QString& packId, const QString& extra)
{
    if (packId.isEmpty()) return;

    if (platform == "modrinth") {
        QString url = QString("%1/project/%2").arg(BuildConfig.MODRINTH_PROD_URL, packId);
        QNetworkRequest req((QUrl(url)));
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk (Handheld Launcher)");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, packId]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                emit packDetailsFailed(packId, reply->errorString());
                return;
            }
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            auto obj = doc.object();

            QVariantMap details;
            details["id"] = obj.value("id").toString();
            details["slug"] = obj.value("slug").toString();
            details["name"] = obj.value("title").toString();
            details["description"] = obj.value("description").toString();
            details["body"] = obj.value("body").toString();
            details["iconUrl"] = obj.value("icon_url").toString();
            details["downloads"] = obj.value("downloads").toInteger();
            details["followers"] = obj.value("followers").toInteger();
            details["websiteUrl"] = QString("https://modrinth.com/modpack/%1").arg(obj.value("slug").toString().isEmpty() ? packId : obj.value("slug").toString());
            details["license"] = obj.value("license").toObject().value("name").toString();
            details["clientSide"] = obj.value("client_side").toString();
            details["serverSide"] = obj.value("server_side").toString();

            QVariantList gallery;
            auto galArr = obj.value("gallery").toArray();
            for (const auto& gVal : galArr) {
                auto g = gVal.toObject();
                QVariantMap item;
                item["url"] = g.value("url").toString();
                item["raw_url"] = g.value("raw_url").toString().isEmpty() ? g.value("url").toString() : g.value("raw_url").toString();
                item["title"] = g.value("title").toString();
                item["description"] = g.value("description").toString();
                gallery.append(item);
            }
            details["gallery"] = gallery;

            // Concurrently query dependencies to get full list of included mods
            QString depsUrl = QString("%1/project/%2/dependencies").arg(BuildConfig.MODRINTH_PROD_URL, packId);
            QNetworkRequest depsReq((QUrl(depsUrl)));
            depsReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk (Handheld Launcher)");
            auto depsReply = APPLICATION->network()->get(depsReq);
            connect(depsReply, &QNetworkReply::finished, this, [this, depsReply, packId, details]() mutable {
                depsReply->deleteLater();
                if (depsReply->error() == QNetworkReply::NoError) {
                    QByteArray dData = depsReply->readAll();
                    QJsonDocument dDoc = QJsonDocument::fromJson(dData);
                    auto projs = dDoc.object().value("projects").toArray();
                    QVariantList modsList;
                    for (const auto& pVal : projs) {
                        auto p = pVal.toObject();
                        QVariantMap mod;
                        mod["name"] = p.value("title").toString();
                        mod["description"] = p.value("description").toString();
                        mod["iconUrl"] = p.value("icon_url").toString();
                        mod["clientSide"] = p.value("client_side").toString();
                        mod["serverSide"] = p.value("server_side").toString();
                        mod["slug"] = p.value("slug").toString();
                        modsList.append(mod);
                    }
                    details["mods"] = modsList;
                    details["modCount"] = modsList.size();
                }
                emit packDetailsLoaded(packId, details);
            });
        });
        return;
    }

    if (platform == "curseforge") {
        QString key = BuildConfig.FLAME_API_KEY;
        QString url = QString("%1/mods/%2").arg(BuildConfig.FLAME_BASE_URL, packId);
        QNetworkRequest req((QUrl(url)));
        req.setRawHeader("x-api-key", key.toUtf8());
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, packId, key]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                emit packDetailsFailed(packId, reply->errorString());
                return;
            }
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            auto dataObj = doc.object().value("data").toObject();

            auto detailsPtr = std::make_shared<QVariantMap>();
            auto& details = *detailsPtr;
            details["id"] = QString::number(dataObj.value("id").toInteger());
            details["name"] = dataObj.value("name").toString();
            details["description"] = dataObj.value("summary").toString();
            details["iconUrl"] = dataObj.value("logo").toObject().value("url").toString();
            details["downloads"] = dataObj.value("downloadCount").toInteger();
            details["websiteUrl"] = dataObj.value("links").toObject().value("websiteUrl").toString();

            QVariantList gallery;
            auto scrArr = dataObj.value("screenshots").toArray();
            for (const auto& sVal : scrArr) {
                auto s = sVal.toObject();
                QVariantMap item;
                item["url"] = s.value("url").toString();
                item["title"] = s.value("title").toString();
                item["description"] = s.value("description").toString();
                gallery.append(item);
            }
            details["gallery"] = gallery;

            // Fetch rich HTML description concurrently
            QString descUrl = QString("%1/mods/%2/description").arg(BuildConfig.FLAME_BASE_URL, packId);
            QNetworkRequest descReq((QUrl(descUrl)));
            descReq.setRawHeader("x-api-key", key.toUtf8());
            descReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
            auto descReply = APPLICATION->network()->get(descReq);
            connect(descReply, &QNetworkReply::finished, this, [this, descReply, packId, detailsPtr]() {
                descReply->deleteLater();
                if (descReply->error() == QNetworkReply::NoError) {
                    QByteArray dData = descReply->readAll();
                    QJsonDocument dDoc = QJsonDocument::fromJson(dData);
                    QString bodyHtml = dDoc.object().value("data").toString();
                    if (!bodyHtml.isEmpty()) {
                        (*detailsPtr)["body"] = bodyHtml;
                        emit packDetailsLoaded(packId, *detailsPtr);
                    }
                }
            });

            // Find download URL for manifest extraction
            qint64 mainFileId = dataObj.value("mainFileId").toInteger();
            QString downloadUrl;
            auto latestFiles = dataObj.value("latestFiles").toArray();
            for (const auto& fVal : latestFiles) {
                auto fObj = fVal.toObject();
                if (fObj.value("id").toInteger() == mainFileId) {
                    downloadUrl = fObj.value("downloadUrl").toString();
                    break;
                }
            }
            if (downloadUrl.isEmpty() && !latestFiles.isEmpty()) {
                downloadUrl = latestFiles.first().toObject().value("downloadUrl").toString();
            }

            auto fetchManifestAndMods = [this, packId, detailsPtr, key](const QString& dlUrl) {
                if (dlUrl.isEmpty()) {
                    emit packDetailsLoaded(packId, *detailsPtr);
                    return;
                }
                QString rangeUrl = dlUrl;
                rangeUrl.replace("https://edge.forgecdn.net", "https://mediafilez.forgecdn.net");
                rangeUrl.replace("http://edge.forgecdn.net", "https://mediafilez.forgecdn.net");

                QNetworkRequest zipReq((QUrl(rangeUrl)));
                zipReq.setRawHeader("Range", "bytes=0-262143");
                zipReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
                zipReq.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
                auto zipReply = APPLICATION->network()->get(zipReq);
                connect(zipReply, &QNetworkReply::finished, this, [this, zipReply, packId, detailsPtr, key]() {
                    zipReply->deleteLater();
                    QByteArray zipData = zipReply->readAll();
                    if (zipData.size() < 30 || !zipData.startsWith("PK\x03\x04")) {
                        emit packDetailsLoaded(packId, *detailsPtr);
                        return;
                    }

                    quint16 method = *reinterpret_cast<const quint16*>(zipData.constData() + 8);
                    quint32 compSize = *reinterpret_cast<const quint32*>(zipData.constData() + 18);
                    quint16 nameLen = *reinterpret_cast<const quint16*>(zipData.constData() + 26);
                    quint16 extraLen = *reinterpret_cast<const quint16*>(zipData.constData() + 28);
                    int offset = 30 + nameLen + extraLen;

                    if (offset + compSize > (quint32)zipData.size()) {
                        emit packDetailsLoaded(packId, *detailsPtr);
                        return;
                    }

                    QByteArray compressed = zipData.mid(offset, compSize);
                    QByteArray uncompressed;
                    bool ok = false;
                    if (method == 8) {
                        ok = GZip::inflateRaw(compressed, uncompressed);
                    } else if (method == 0) {
                        uncompressed = compressed;
                        ok = true;
                    }

                    if (!ok || uncompressed.isEmpty()) {
                        emit packDetailsLoaded(packId, *detailsPtr);
                        return;
                    }

                    QJsonDocument manifestDoc = QJsonDocument::fromJson(uncompressed);
                    auto filesArr = manifestDoc.object().value("files").toArray();
                    QJsonArray modIdsArr;
                    for (const auto& fVal : filesArr) {
                        int pId = fVal.toObject().value("projectID").toInt();
                        if (pId > 0) {
                            modIdsArr.append(pId);
                        }
                    }

                    if (modIdsArr.isEmpty()) {
                        emit packDetailsLoaded(packId, *detailsPtr);
                        return;
                    }

                    (*detailsPtr)["modCount"] = modIdsArr.size();

                    // Query CurseForge /v1/mods in batch to get official names, icons, and summaries
                    QJsonObject batchObj;
                    batchObj["modIds"] = modIdsArr;
                    QNetworkRequest batchReq((QUrl(QString("%1/mods").arg(BuildConfig.FLAME_BASE_URL))));
                    batchReq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
                    batchReq.setRawHeader("x-api-key", key.toUtf8());
                    batchReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");

                    auto batchReply = APPLICATION->network()->post(batchReq, QJsonDocument(batchObj).toJson(QJsonDocument::Compact));
                    connect(batchReply, &QNetworkReply::finished, this, [this, batchReply, packId, detailsPtr]() {
                        batchReply->deleteLater();
                        if (batchReply->error() == QNetworkReply::NoError) {
                            QByteArray bData = batchReply->readAll();
                            QJsonDocument bDoc = QJsonDocument::fromJson(bData);
                            auto mArr = bDoc.object().value("data").toArray();
                            QVariantList modsList;
                            for (const auto& mVal : mArr) {
                                auto m = mVal.toObject();
                                QVariantMap mod;
                                mod["name"] = m.value("name").toString();
                                mod["description"] = m.value("summary").toString();
                                auto logoObj = m.value("logo").toObject();
                                QString icon = logoObj.value("thumbnailUrl").toString();
                                if (icon.isEmpty()) icon = logoObj.value("url").toString();
                                mod["iconUrl"] = icon;
                                mod["websiteUrl"] = m.value("links").toObject().value("websiteUrl").toString();
                                modsList.append(mod);
                            }
                            (*detailsPtr)["mods"] = modsList;
                            (*detailsPtr)["modCount"] = modsList.size();
                        }
                        emit packDetailsLoaded(packId, *detailsPtr);
                    });
                });
            };

            if (downloadUrl.isEmpty() && mainFileId > 0) {
                QString dlUrlApi = QString("%1/mods/%2/files/%3/download-url").arg(BuildConfig.FLAME_BASE_URL, packId).arg(mainFileId);
                QNetworkRequest dlReq((QUrl(dlUrlApi)));
                dlReq.setRawHeader("x-api-key", key.toUtf8());
                dlReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
                auto dlReply = APPLICATION->network()->get(dlReq);
                connect(dlReply, &QNetworkReply::finished, this, [fetchManifestAndMods, dlReply]() mutable {
                    dlReply->deleteLater();
                    QString resUrl;
                    if (dlReply->error() == QNetworkReply::NoError) {
                        QByteArray d = dlReply->readAll();
                        resUrl = QJsonDocument::fromJson(d).object().value("data").toString();
                    }
                    fetchManifestAndMods(resUrl);
                });
            } else {
                fetchManifestAndMods(downloadUrl);
            }
        });
        return;
    }

    if (platform == "ftb") {
        QString url = QString("https://api.feed-the-beast.com/v1/modpacks/public/modpack/%1").arg(packId);
        QNetworkRequest req((QUrl(url)));
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, packId]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                emit packDetailsFailed(packId, reply->errorString());
                return;
            }
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            auto obj = doc.object();

            QVariantMap details;
            details["id"] = QString::number(obj.value("id").toInteger());
            details["name"] = obj.value("name").toString();
            details["description"] = obj.value("synopsis").toString();
            if (details["description"].toString().isEmpty()) {
                details["description"] = obj.value("description").toString();
            }
            details["body"] = obj.value("description").toString();
            details["downloads"] = obj.value("installs").toInteger();
            details["websiteUrl"] = QString("https://feed-the-beast.com/modpacks/%1").arg(packId);

            auto artArr = obj.value("art").toArray();
            for (const auto& aVal : artArr) {
                auto aObj = aVal.toObject();
                QString aType = aObj.value("type").toString();
                QString aUrl = aObj.value("url").toString();
                if (aType == "square" && details["iconUrl"].toString().isEmpty()) {
                    details["iconUrl"] = aUrl;
                } else if (aType == "splash" && details["bannerUrl"].toString().isEmpty()) {
                    details["bannerUrl"] = aUrl;
                }
            }
            if (details["iconUrl"].toString().isEmpty() && !artArr.isEmpty()) {
                details["iconUrl"] = artArr.first().toObject().value("url").toString();
            }

            auto versArr = obj.value("versions").toArray();
            if (versArr.isEmpty()) {
                emit packDetailsLoaded(packId, details);
                return;
            }
            qint64 versionId = versArr.last().toObject().value("id").toInteger();

            QString vUrl = QString("https://api.feed-the-beast.com/v1/modpacks/public/modpack/%1/%2").arg(packId).arg(versionId);
            QNetworkRequest vReq((QUrl(vUrl)));
            vReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
            auto vReply = APPLICATION->network()->get(vReq);
            connect(vReply, &QNetworkReply::finished, this, [this, vReply, packId, details]() mutable {
                vReply->deleteLater();
                if (vReply->error() != QNetworkReply::NoError) {
                    emit packDetailsLoaded(packId, details);
                    return;
                }
                QByteArray vData = vReply->readAll();
                QJsonDocument vDoc = QJsonDocument::fromJson(vData);
                auto filesArr = vDoc.object().value("files").toArray();

                QVariantList rawMods;
                QJsonArray cfIds;
                for (const auto& fVal : filesArr) {
                    auto f = fVal.toObject();
                    QString fName = f.value("name").toString();
                    QString fPath = f.value("path").toString();
                    if (!fName.endsWith(".jar", Qt::CaseInsensitive) && !fPath.contains("mods")) {
                        continue;
                    }
                    if (fName.endsWith(".jar.disabled", Qt::CaseInsensitive)) continue;

                    QString cleanName = fName;
                    if (cleanName.endsWith(".jar", Qt::CaseInsensitive)) {
                        cleanName.chop(4);
                    }

                    QVariantMap mod;
                    mod["name"] = cleanName;
                    mod["description"] = tr("Included modification");
                    mod["iconUrl"] = QString();

                    auto cfObj = f.value("curseforge").toObject();
                    int cfProj = cfObj.value("project").toInt();
                    if (cfProj == 0 && cfObj.value("project").isString()) {
                        cfProj = cfObj.value("project").toString().toInt();
                    }
                    if (cfProj > 0) {
                        mod["cfId"] = cfProj;
                        cfIds.append(cfProj);
                    }
                    rawMods.append(mod);
                }

                if (cfIds.isEmpty() || BuildConfig.FLAME_API_KEY.isEmpty()) {
                    details["mods"] = rawMods;
                    details["modCount"] = rawMods.size();
                    emit packDetailsLoaded(packId, details);
                    return;
                }

                QJsonObject batchObj;
                batchObj["modIds"] = cfIds;
                QNetworkRequest batchReq((QUrl(QString("%1/mods").arg(BuildConfig.FLAME_BASE_URL))));
                batchReq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
                batchReq.setRawHeader("x-api-key", BuildConfig.FLAME_API_KEY.toUtf8());
                batchReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");

                auto batchReply = APPLICATION->network()->post(batchReq, QJsonDocument(batchObj).toJson(QJsonDocument::Compact));
                connect(batchReply, &QNetworkReply::finished, this, [this, batchReply, packId, details, rawMods]() mutable {
                    batchReply->deleteLater();
                    if (batchReply->error() == QNetworkReply::NoError) {
                        QByteArray bData = batchReply->readAll();
                        QJsonDocument bDoc = QJsonDocument::fromJson(bData);
                        auto mArr = bDoc.object().value("data").toArray();
                        QHash<int, QJsonObject> cfMap;
                        for (const auto& mVal : mArr) {
                            auto m = mVal.toObject();
                            cfMap[m.value("id").toInt()] = m;
                        }

                        for (int i = 0; i < rawMods.size(); ++i) {
                            auto m = rawMods[i].toMap();
                            int cfId = m.value("cfId").toInt();
                            if (cfMap.contains(cfId)) {
                                const auto& cObj = cfMap.value(cfId);
                                m["name"] = cObj.value("name").toString();
                                m["description"] = cObj.value("summary").toString();
                                auto logoObj = cObj.value("logo").toObject();
                                QString icon = logoObj.value("thumbnailUrl").toString();
                                if (icon.isEmpty()) icon = logoObj.value("url").toString();
                                m["iconUrl"] = icon;
                                m["websiteUrl"] = cObj.value("links").toObject().value("websiteUrl").toString();
                                rawMods[i] = m;
                            }
                        }
                    }
                    details["mods"] = rawMods;
                    details["modCount"] = rawMods.size();
                    emit packDetailsLoaded(packId, details);
                });
            });
        });
        return;
    }

    if (platform == "technic") {
        QString url = QString("https://api.technicpack.net/modpack/%1?build=multimc").arg(packId);
        QNetworkRequest req((QUrl(url)));
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, packId]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                emit packDetailsFailed(packId, reply->errorString());
                return;
            }
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            auto obj = doc.object();

            QVariantMap details;
            details["id"] = packId;
            details["name"] = obj.value("displayName").toString().isEmpty() ? obj.value("name").toString() : obj.value("displayName").toString();
            details["description"] = obj.value("description").toString();
            details["iconUrl"] = obj.value("icon").toObject().value("url").toString();
            details["bannerUrl"] = obj.value("background").toObject().value("url").toString();
            details["downloads"] = obj.value("downloads").toInteger();
            details["websiteUrl"] = obj.value("url").toString().isEmpty() ? QString("https://www.technicpack.net/modpack/%1").arg(packId) : obj.value("url").toString();

            QString solder = obj.value("solder").toString().trimmed();
            if (solder.isEmpty()) {
                emit packDetailsLoaded(packId, details);
                return;
            }
            if (!solder.endsWith('/')) solder += '/';

            QString solderPackUrl = QString("%1modpack/%2").arg(solder, packId);
            QNetworkRequest spReq((QUrl(solderPackUrl)));
            spReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
            auto spReply = APPLICATION->network()->get(spReq);
            connect(spReply, &QNetworkReply::finished, this, [this, spReply, packId, details, solder]() mutable {
                spReply->deleteLater();
                if (spReply->error() != QNetworkReply::NoError) {
                    emit packDetailsLoaded(packId, details);
                    return;
                }
                QByteArray spData = spReply->readAll();
                QJsonDocument spDoc = QJsonDocument::fromJson(spData);
                auto spObj = spDoc.object();
                QString recBuild = spObj.value("recommended").toString();
                if (recBuild.isEmpty()) recBuild = spObj.value("latest").toString();
                if (recBuild.isEmpty()) {
                    auto bArr = spObj.value("builds").toArray();
                    if (!bArr.isEmpty()) recBuild = bArr.last().toString();
                }
                if (recBuild.isEmpty()) {
                    emit packDetailsLoaded(packId, details);
                    return;
                }

                QString bUrl = QString("%1modpack/%2/%3").arg(solder, packId, recBuild);
                QNetworkRequest bReq((QUrl(bUrl)));
                bReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
                auto bReply = APPLICATION->network()->get(bReq);
                connect(bReply, &QNetworkReply::finished, this, [this, bReply, packId, details]() mutable {
                    bReply->deleteLater();
                    if (bReply->error() == QNetworkReply::NoError) {
                        QByteArray bData = bReply->readAll();
                        QJsonDocument bDoc = QJsonDocument::fromJson(bData);
                        auto modsArr = bDoc.object().value("mods").toArray();
                        QVariantList modsList;
                        for (const auto& mVal : modsArr) {
                            auto mObj = mVal.toObject();
                            QString rawName = mObj.value("name").toString();
                            QString cleanName;
                            QStringList parts = rawName.split(QRegularExpression("[-_]"), Qt::SkipEmptyParts);
                            for (const auto& part : parts) {
                                if (!cleanName.isEmpty()) cleanName += " ";
                                QString p = part;
                                if (!p.isEmpty()) {
                                    p[0] = p[0].toUpper();
                                }
                                cleanName += p;
                            }
                            QString ver = mObj.value("version").toString();
                            QVariantMap mod;
                            mod["name"] = cleanName.isEmpty() ? rawName : cleanName;
                            mod["description"] = ver.isEmpty() ? tr("Included modification") : tr("Version %1").arg(ver);
                            mod["clientSide"] = ver;
                            mod["iconUrl"] = QString();
                            modsList.append(mod);
                        }
                        details["mods"] = modsList;
                        details["modCount"] = modsList.size();
                    }
                    emit packDetailsLoaded(packId, details);
                });
            });
        });
        return;
    }

    if (platform == "atlauncher") {
        auto resolveAtl = [this, packId, extra](const QByteArray& atlData) {
            QJsonDocument doc = QJsonDocument::fromJson(atlData);
            auto packs = doc.array();
            QJsonObject matchedPack;
            for (const auto& pVal : packs) {
                auto p = pVal.toObject();
                int id = p.value("id").toInt();
                QString name = p.value("name").toString();
                QString safeName = name;
                safeName.remove(QRegularExpression("[^A-Za-z0-9]"));

                if (QString::number(id) == packId ||
                    name.compare(packId, Qt::CaseInsensitive) == 0 ||
                    safeName.compare(packId, Qt::CaseInsensitive) == 0 ||
                    (!extra.isEmpty() && (name.compare(extra, Qt::CaseInsensitive) == 0 ||
                                          safeName.compare(extra, Qt::CaseInsensitive) == 0))) {
                    matchedPack = p;
                    break;
                }
            }

            if (matchedPack.isEmpty()) {
                emit packDetailsFailed(packId, tr("Modpack not found in ATLauncher database"));
                return;
            }

            QString name = matchedPack.value("name").toString();
            QString safeName = name;
            safeName.remove(QRegularExpression("[^A-Za-z0-9]"));
            QString description = matchedPack.value("description").toString();
            QString iconUrl = QString("%1launcher/images/%2.png").arg(BuildConfig.ATL_DOWNLOAD_SERVER_URL, safeName.toLower());

            auto versArr = matchedPack.value("versions").toArray();
            QString latestVer;
            if (!versArr.isEmpty()) {
                latestVer = versArr.first().toObject().value("version").toString();
            }

            QVariantMap details;
            details["id"] = packId;
            details["name"] = name;
            details["description"] = description;
            details["iconUrl"] = iconUrl;
            details["websiteUrl"] = QString("https://atlauncher.com/pack/%1").arg(safeName);

            if (latestVer.isEmpty()) {
                emit packDetailsLoaded(packId, details);
                return;
            }

            QString cfgUrl = QString("%1packs/%2/versions/%3/Configs.json").arg(BuildConfig.ATL_DOWNLOAD_SERVER_URL, safeName, latestVer);
            QNetworkRequest cfgReq((QUrl(cfgUrl)));
            cfgReq.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
            auto cfgReply = APPLICATION->network()->get(cfgReq);
            connect(cfgReply, &QNetworkReply::finished, this, [this, cfgReply, packId, details]() mutable {
                cfgReply->deleteLater();
                if (cfgReply->error() == QNetworkReply::NoError) {
                    QByteArray cData = cfgReply->readAll();
                    QJsonDocument cDoc = QJsonDocument::fromJson(cData);
                    auto mArr = cDoc.object().value("mods").toArray();
                    QVariantList modsList;
                    for (const auto& mVal : mArr) {
                        auto mObj = mVal.toObject();
                        if (mObj.value("hidden").toBool(false)) continue;
                        QVariantMap mod;
                        mod["name"] = mObj.value("name").toString();
                        mod["description"] = mObj.value("description").toString();
                        mod["version"] = mObj.value("version").toString();
                        mod["websiteUrl"] = mObj.value("website").toString();
                        mod["clientSide"] = mObj.value("version").toString();
                        mod["iconUrl"] = QString();
                        modsList.append(mod);
                    }
                    details["mods"] = modsList;
                    details["modCount"] = modsList.size();
                }
                emit packDetailsLoaded(packId, details);
            });
        };

        if (!m_cachedAtlData.isEmpty()) {
            resolveAtl(m_cachedAtlData);
            return;
        }

        QString urlStr = QString("%1launcher/json/packsnew.json").arg(BuildConfig.ATL_DOWNLOAD_SERVER_URL);
        QNetworkRequest req((QUrl(urlStr)));
        req.setHeader(QNetworkRequest::UserAgentHeader, "PrismLauncher/Shulk");
        auto reply = APPLICATION->network()->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, resolveAtl, packId]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                emit packDetailsFailed(packId, reply->errorString());
                return;
            }
            m_cachedAtlData = reply->readAll();
            resolveAtl(m_cachedAtlData);
        });
        return;
    }

    QVariantMap details;
    details["id"] = packId;
    details["platform"] = platform;
    emit packDetailsLoaded(packId, details);
}

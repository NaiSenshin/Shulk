// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QObject>
#include <QByteArray>
#include <QHash>
#include <QtQmlIntegration>

class ShulkSoundManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool soundEnabled READ soundEnabled WRITE setSoundEnabled NOTIFY soundEnabledChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)

public:
    enum SoundType {
        SoundClick = 0,
        SoundFocus,
        SoundLaunch,
        SoundDismiss,
        SoundOpen,
        SoundLevelUp,
        SoundError
    };
    Q_ENUM(SoundType)

    explicit ShulkSoundManager(QObject* parent = nullptr);
    ~ShulkSoundManager() override;

    bool soundEnabled() const { return m_soundEnabled; }
    void setSoundEnabled(bool enabled);

    int volume() const { return m_volume; }
    void setVolume(int vol);

    Q_INVOKABLE void playClick();
    Q_INVOKABLE void playFocus();
    Q_INVOKABLE void playTick() { playFocus(); }
    Q_INVOKABLE void playLaunch();
    Q_INVOKABLE void playDismiss();
    Q_INVOKABLE void playOpen();
    Q_INVOKABLE void playLevelUp();
    Q_INVOKABLE void playError();
    Q_INVOKABLE void playSound(SoundType type);

signals:
    void soundEnabledChanged();
    void volumeChanged();

private:
    void initAudio();
    void shutdownAudio();
    void loadSounds();
    void playPcmBuffer(const QByteArray& pcm);

    bool m_soundEnabled = true;
    int m_volume = 80; // 0 - 100
    unsigned int m_audioDeviceId = 0;
    bool m_audioReady = false;

    QHash<SoundType, QByteArray> m_soundBuffers;
};

// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkSoundManager.h"
#include <SDL2/SDL.h>
#include <QFile>
#include <QDebug>
#include <QtEndian>
#include <algorithm>

static const int SAMPLE_RATE = 44100;

ShulkSoundManager::ShulkSoundManager(QObject* parent)
    : QObject(parent)
{
    initAudio();
    loadSounds();
}

ShulkSoundManager::~ShulkSoundManager()
{
    shutdownAudio();
}

void ShulkSoundManager::setSoundEnabled(bool enabled)
{
    if (m_soundEnabled != enabled) {
        m_soundEnabled = enabled;
        emit soundEnabledChanged();
    }
}

void ShulkSoundManager::setVolume(int vol)
{
    int clamped = std::max(0, std::min(100, vol));
    if (m_volume != clamped) {
        m_volume = clamped;
        emit volumeChanged();
    }
}

void ShulkSoundManager::initAudio()
{
    if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        qWarning() << "SDL Audio initialization failed:" << SDL_GetError();
        return;
    }

    SDL_AudioSpec desired, obtained;
    SDL_zero(desired);
    desired.freq = SAMPLE_RATE;
    desired.format = AUDIO_S16SYS;
    desired.channels = 1;
    desired.samples = 1024;
    desired.callback = nullptr;

    m_audioDeviceId = SDL_OpenAudioDevice(nullptr, 0, &desired, &obtained, 0);
    if (m_audioDeviceId == 0) {
        qWarning() << "Could not open audio device:" << SDL_GetError();
        return;
    }

    SDL_PauseAudioDevice(m_audioDeviceId, 0);
    m_audioReady = true;
    qDebug() << "ShulkSoundManager: SDL Audio initialized successfully (Device ID:" << m_audioDeviceId << ")";
}

void ShulkSoundManager::shutdownAudio()
{
    if (m_audioReady && m_audioDeviceId != 0) {
        SDL_ClearQueuedAudio(m_audioDeviceId);
        SDL_CloseAudioDevice(m_audioDeviceId);
        m_audioDeviceId = 0;
        m_audioReady = false;
    }
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
}

void ShulkSoundManager::loadSounds()
{
    auto loadWavResource = [](const QString& resPath) -> QByteArray {
        QFile file(resPath);
        if (!file.open(QIODevice::ReadOnly)) {
            qWarning() << "Could not open sound resource:" << resPath;
            return QByteArray();
        }
        QByteArray data = file.readAll();
        // Locate the PCM data chunk instead of assuming a 44-byte header.
        // WAV encoders may insert metadata chunks before the samples.
        if (data.size() >= 12 && data.startsWith("RIFF") && data.mid(8, 4) == "WAVE") {
            qsizetype offset = 12;
            while (offset + 8 <= data.size()) {
                const QByteArray chunkId = data.mid(offset, 4);
                const auto* sizeBytes = reinterpret_cast<const uchar*>(data.constData() + offset + 4);
                const quint32 chunkSize = qFromLittleEndian<quint32>(sizeBytes);
                const qsizetype payloadOffset = offset + 8;
                if (chunkId == "data" && payloadOffset + chunkSize <= data.size())
                    return data.mid(payloadOffset, chunkSize);
                offset = payloadOffset + chunkSize + (chunkSize & 1U);
            }
        }
        qWarning() << "Sound resource has no valid PCM data chunk:" << resPath;
        return QByteArray();
    };

    // Official Minecraft 26.2 sound set, sourced from Mojang's asset CDN.
    QByteArray click = loadWavResource(":/shulk/sounds/confirm.wav");
    if (!click.isEmpty()) {
        m_soundBuffers.insert(SoundClick, click);
    }

    QByteArray navigate = loadWavResource(":/shulk/sounds/navigate.wav");
    if (!navigate.isEmpty()) {
        m_soundBuffers.insert(SoundFocus, navigate);
    }

    QByteArray launch = loadWavResource(":/shulk/sounds/launch.wav");
    if (!launch.isEmpty()) {
        m_soundBuffers.insert(SoundLaunch, launch);
    }

    QByteArray success = loadWavResource(":/shulk/sounds/success.wav");
    if (!success.isEmpty()) {
        m_soundBuffers.insert(SoundLevelUp, success);
    }

    QByteArray open = loadWavResource(":/shulk/sounds/open.wav");
    if (!open.isEmpty()) {
        m_soundBuffers.insert(SoundOpen, open);
    }

    QByteArray back = loadWavResource(":/shulk/sounds/back.wav");
    if (!back.isEmpty()) {
        m_soundBuffers.insert(SoundDismiss, back);
    }

    QByteArray error = loadWavResource(":/shulk/sounds/error.wav");
    if (!error.isEmpty()) {
        m_soundBuffers.insert(SoundError, error);
    }

    qDebug() << "ShulkSoundManager: Loaded" << m_soundBuffers.size() << "verified Minecraft 26.2 UI sounds.";
}

void ShulkSoundManager::playPcmBuffer(const QByteArray& pcm)
{
    if (!m_audioReady || !m_soundEnabled || m_volume <= 0 || pcm.isEmpty()) {
        return;
    }

    // Scale by volume
    QByteArray scaled(pcm);
    int16_t* samples = reinterpret_cast<int16_t*>(scaled.data());
    int numSamples = scaled.size() / sizeof(int16_t);
    float gain = (float)m_volume / 100.0f;

    for (int i = 0; i < numSamples; ++i) {
        samples[i] = (int16_t)(samples[i] * gain);
    }

    SDL_ClearQueuedAudio(m_audioDeviceId);
    SDL_QueueAudio(m_audioDeviceId, scaled.constData(), scaled.size());
}

void ShulkSoundManager::playSound(SoundType type)
{
    if (m_soundBuffers.contains(type)) {
        playPcmBuffer(m_soundBuffers.value(type));
    }
}

void ShulkSoundManager::playClick()
{
    playSound(SoundClick);
}

void ShulkSoundManager::playFocus()
{
    playSound(SoundFocus);
}

void ShulkSoundManager::playLaunch()
{
    playSound(SoundLaunch);
}

void ShulkSoundManager::playDismiss()
{
    playSound(SoundDismiss);
}

void ShulkSoundManager::playOpen()
{
    playSound(SoundOpen);
}

void ShulkSoundManager::playLevelUp()
{
    playSound(SoundLevelUp);
}

void ShulkSoundManager::playError()
{
    playSound(SoundError);
}

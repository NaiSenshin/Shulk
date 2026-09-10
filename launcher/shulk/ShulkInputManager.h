// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#pragma once

#include <QObject>
#include <QTimer>
#include <QHash>
#include <QPointer>
#include <QtQmlIntegration>

class QWindow;
struct _SDL_GameController;
typedef struct _SDL_GameController SDL_GameController;

class ShulkInputManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(InputMode inputMode READ inputMode WRITE setInputMode NOTIFY inputModeChanged)
    Q_PROPERTY(bool isController READ isController NOTIFY inputModeChanged)
    Q_PROPERTY(bool isTouch READ isTouch NOTIFY inputModeChanged)
    Q_PROPERTY(bool showFocusHighlight READ showFocusHighlight NOTIFY inputModeChanged)
    Q_PROPERTY(int connectedControllerCount READ connectedControllerCount NOTIFY controllersChanged)
    Q_PROPERTY(QString controllerName READ controllerName NOTIFY controllersChanged)
    Q_PROPERTY(bool isApplicationActive READ isApplicationActive NOTIFY applicationActiveChanged)

public:
    enum InputMode {
        Controller = 0,
        Keyboard = 1,
        Mouse = 2,
        Touch = 3
    };
    Q_ENUM(InputMode)

    enum LogicalAction {
        ActionNone = 0,
        ActionNavigateUp,
        ActionNavigateDown,
        ActionNavigateLeft,
        ActionNavigateRight,
        ActionAccept,          // A / Cross / Enter / Space
        ActionBack,            // B / Circle / Escape / Backspace
        ActionPrimary,         // X / Square / P (Quick Play)
        ActionSecondary,       // Y / Triangle / S (Search / Context)
        ActionMenu,            // Start / Menu / M / Context
        ActionSearch,          // Y / / / Ctrl+F
        ActionPrevTab,         // LB / L1 / [ / PageUp
        ActionNextTab,         // RB / R1 / ] / PageDown
        ActionFilter,          // F / R3
        ActionRefresh,         // F5 / Select
        ActionTriggerLeft,     // LT / L2 / Q
        ActionTriggerRight     // RT / R2 / E
    };
    Q_ENUM(LogicalAction)

    explicit ShulkInputManager(QObject* parent = nullptr);
    ~ShulkInputManager() override;

    void setTargetWindow(QWindow* window);
    bool isApplicationActive() const;

    InputMode inputMode() const { return m_inputMode; }
    void setInputMode(InputMode mode);

    bool isController() const { return m_inputMode == Controller; }
    bool isTouch() const { return m_inputMode == Touch; }
    bool showFocusHighlight() const { return m_inputMode == Controller || m_inputMode == Keyboard; }

    int connectedControllerCount() const;
    QString controllerName() const { return m_activeControllerName; }

    Q_INVOKABLE LogicalAction mapKeyToAction(int key, int modifiers = 0);
    Q_INVOKABLE void notifyKeyPressed(int key, int modifiers = 0);
    Q_INVOKABLE void openVirtualKeyboard();
    Q_INVOKABLE void notifyPointerMoved();
    Q_INVOKABLE void notifyTouchPressed();

signals:
    void inputModeChanged();
    void controllersChanged();
    void applicationActiveChanged();
    void actionTriggered(LogicalAction action);
    void actionReleased(LogicalAction action);
    void konamiCodeTriggered();

private slots:
    void pollGamepadEvents();

private:
    void initSDL();
    void shutdownSDL();
    void openController(int deviceIndex);
    void closeController(int joystickId);
    void handleButtonEvent(int button, bool pressed);
    void handleAxisEvent(int axis, int value);
    void dispatchKeyToQt(int key, bool pressed = true);
    bool checkKonamiCode(LogicalAction action, int rawKey = 0);

    QPointer<QWindow> m_targetWindow;
    InputMode m_inputMode = Controller;
    QTimer m_pollTimer;
    QHash<int, SDL_GameController*> m_controllers;
    QString m_activeControllerName;

    // Analog stick deflection tracking
    bool m_stickUpActive = false;
    bool m_stickDownActive = false;
    bool m_stickLeftActive = false;
    bool m_stickRightActive = false;
    bool m_triggerLeftActive = false;
    bool m_triggerRightActive = false;
    qint64 m_lastAxisRepeatTime = 0;

    // Easter Egg / Konami Code tracking
    int m_konamiStep = 0;
    qint64 m_lastKonamiTime = 0;
};

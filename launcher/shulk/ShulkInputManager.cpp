// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include "ShulkInputManager.h"
#include <SDL2/SDL.h>
#include <QGuiApplication>
#include <QWindow>
#include <QKeyEvent>
#include <QDateTime>
#include <QDesktopServices>
#include <QUrl>
#include <QDebug>
#include <QProcess>
#include <QStandardPaths>

ShulkInputManager::ShulkInputManager(QObject* parent)
    : QObject(parent)
{
    initSDL();

    // 60Hz / 16ms poll timer for responsive gamepad events
    connect(&m_pollTimer, &QTimer::timeout, this, &ShulkInputManager::pollGamepadEvents);
    m_pollTimer.start(16);
}

ShulkInputManager::~ShulkInputManager()
{
    m_pollTimer.stop();
    shutdownSDL();
}

void ShulkInputManager::initSDL()
{
    // Set hints for Steam Deck / Steam Controller compatibility
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
    SDL_SetHint(SDL_HINT_LINUX_JOYSTICK_DEADZONES, "1");

    if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK | SDL_INIT_EVENTS) != 0) {
        qWarning() << "SDL GameController initialization failed:" << SDL_GetError();
        return;
    }

    int numJoysticks = SDL_NumJoysticks();
    qDebug() << "SDL Gamepad Subsystem initialized. Connected joysticks:" << numJoysticks;

    for (int i = 0; i < numJoysticks; ++i) {
        if (SDL_IsGameController(i)) {
            openController(i);
        }
    }
}

void ShulkInputManager::shutdownSDL()
{
    for (auto controller : m_controllers) {
        if (controller) {
            SDL_GameControllerClose(controller);
        }
    }
    m_controllers.clear();
    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK | SDL_INIT_EVENTS);
}

void ShulkInputManager::openController(int deviceIndex)
{
    // Prevent opening same device multiple times
    for (auto* c : m_controllers) {
        if (c) {
            SDL_Joystick* j = SDL_GameControllerGetJoystick(c);
            if (j && SDL_JoystickGetDeviceInstanceID(deviceIndex) == SDL_JoystickInstanceID(j)) {
                return; // Already opened
            }
        }
    }

    SDL_GameController* controller = SDL_GameControllerOpen(deviceIndex);
    if (!controller) {
        return;
    }

    SDL_Joystick* joystick = SDL_GameControllerGetJoystick(controller);
    int instanceId = SDL_JoystickInstanceID(joystick);
    if (m_controllers.contains(instanceId)) {
        return;
    }

    m_controllers.insert(instanceId, controller);

    const char* name = SDL_GameControllerName(controller);
    m_activeControllerName = QString::fromUtf8(name ? name : "Gamepad");
    qDebug() << "Connected controller:" << m_activeControllerName << "(ID:" << instanceId << ")";

    setInputMode(Controller);
    emit controllersChanged();
}

void ShulkInputManager::closeController(int joystickId)
{
    if (m_controllers.contains(joystickId)) {
        SDL_GameController* controller = m_controllers.take(joystickId);
        if (controller) {
            SDL_GameControllerClose(controller);
        }
        qDebug() << "Disconnected controller ID:" << joystickId;

        if (m_controllers.isEmpty()) {
            m_activeControllerName.clear();
        }
        emit controllersChanged();
    }
}

int ShulkInputManager::connectedControllerCount() const
{
    return m_controllers.size();
}

void ShulkInputManager::setInputMode(InputMode mode)
{
    if (m_inputMode != mode) {
        m_inputMode = mode;
        emit inputModeChanged();
    }
}

void ShulkInputManager::setTargetWindow(QWindow* window)
{
    if (m_targetWindow) {
        disconnect(m_targetWindow, nullptr, this, nullptr);
    }
    m_targetWindow = window;
    if (m_targetWindow) {
        connect(m_targetWindow, &QWindow::activeChanged, this, [this]() {
            bool active = isApplicationActive();
            m_pollTimer.setInterval(active ? 16 : 250);
            emit applicationActiveChanged();
        });
    }
    m_pollTimer.setInterval(isApplicationActive() ? 16 : 250);
    emit applicationActiveChanged();
}

bool ShulkInputManager::isApplicationActive() const
{
    if (m_targetWindow) {
        return m_targetWindow->isActive();
    }
    return (QGuiApplication::applicationState() == Qt::ApplicationActive) && (QGuiApplication::focusWindow() != nullptr);
}

void ShulkInputManager::pollGamepadEvents()
{
    if (!m_targetWindow || !m_targetWindow->isActive()) {
        m_stickUpActive = false;
        m_stickDownActive = false;
        m_stickLeftActive = false;
        m_stickRightActive = false;
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_CONTROLLERDEVICEADDED) {
                openController(event.cdevice.which);
            } else if (event.type == SDL_CONTROLLERDEVICEREMOVED) {
                closeController(event.cdevice.which);
            }
        }
        return;
    }

    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_CONTROLLERDEVICEADDED:
                openController(event.cdevice.which);
                break;
            case SDL_CONTROLLERDEVICEREMOVED:
                closeController(event.cdevice.which);
                break;
            case SDL_CONTROLLERBUTTONDOWN:
                setInputMode(Controller);
                handleButtonEvent(event.cbutton.button, true);
                break;
            case SDL_CONTROLLERBUTTONUP:
                handleButtonEvent(event.cbutton.button, false);
                break;
            case SDL_CONTROLLERAXISMOTION:
                handleAxisEvent(event.caxis.axis, event.caxis.value);
                break;
            default:
                break;
        }
    }
}

void ShulkInputManager::handleButtonEvent(int button, bool pressed)
{
    LogicalAction action = ActionNone;

    switch (button) {
        case SDL_CONTROLLER_BUTTON_A:
            action = ActionAccept;
            break;
        case SDL_CONTROLLER_BUTTON_B:
            action = ActionBack;
            break;
        case SDL_CONTROLLER_BUTTON_X:
            action = ActionPrimary;
            break;
        case SDL_CONTROLLER_BUTTON_Y:
            action = ActionSecondary;
            break;
        case SDL_CONTROLLER_BUTTON_DPAD_UP:
            action = ActionNavigateUp;
            break;
        case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
            action = ActionNavigateDown;
            break;
        case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
            action = ActionNavigateLeft;
            break;
        case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
            action = ActionNavigateRight;
            break;
        case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
            action = ActionPrevTab;
            break;
        case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
            action = ActionNextTab;
            break;
        case SDL_CONTROLLER_BUTTON_START:
            action = ActionMenu;
            break;
        case SDL_CONTROLLER_BUTTON_BACK:
            action = ActionRefresh;
            break;
        case SDL_CONTROLLER_BUTTON_RIGHTSTICK:
            action = ActionFilter;
            break;
        default:
            break;
    }

    if (pressed) {
        if (action != ActionNone) {
            emit actionTriggered(action);
        }
    } else {
        if (action != ActionNone) {
            emit actionReleased(action);
        }
    }
}

void ShulkInputManager::handleAxisEvent(int axis, int value)
{
    const int DEADZONE = 18000;
    qint64 now = QDateTime::currentMSecsSinceEpoch();

    if (axis == SDL_CONTROLLER_AXIS_LEFTX) {
        bool left = value < -DEADZONE;
        bool right = value > DEADZONE;

        if (left && (!m_stickLeftActive || now - m_lastAxisRepeatTime > 220)) {
            setInputMode(Controller);
            m_stickLeftActive = true;
            m_lastAxisRepeatTime = now;
            emit actionTriggered(ActionNavigateLeft);
        } else if (!left) {
            m_stickLeftActive = false;
        }

        if (right && (!m_stickRightActive || now - m_lastAxisRepeatTime > 220)) {
            setInputMode(Controller);
            m_stickRightActive = true;
            m_lastAxisRepeatTime = now;
            emit actionTriggered(ActionNavigateRight);
        } else if (!right) {
            m_stickRightActive = false;
        }
    } else if (axis == SDL_CONTROLLER_AXIS_LEFTY) {
        bool up = value < -DEADZONE;
        bool down = value > DEADZONE;

        if (up && (!m_stickUpActive || now - m_lastAxisRepeatTime > 220)) {
            setInputMode(Controller);
            m_stickUpActive = true;
            m_lastAxisRepeatTime = now;
            emit actionTriggered(ActionNavigateUp);
        } else if (!up) {
            m_stickUpActive = false;
        }

        if (down && (!m_stickDownActive || now - m_lastAxisRepeatTime > 220)) {
            setInputMode(Controller);
            m_stickDownActive = true;
            m_lastAxisRepeatTime = now;
            emit actionTriggered(ActionNavigateDown);
        } else if (!down) {
            m_stickDownActive = false;
        }
    } else if (axis == SDL_CONTROLLER_AXIS_TRIGGERLEFT) {
        const int TRIGGER_DEADZONE = 16000;
        bool pressed = value > TRIGGER_DEADZONE;
        if (pressed && !m_triggerLeftActive) {
            setInputMode(Controller);
            m_triggerLeftActive = true;
            emit actionTriggered(ActionTriggerLeft);
        } else if (!pressed && m_triggerLeftActive) {
            m_triggerLeftActive = false;
            emit actionReleased(ActionTriggerLeft);
        }
    } else if (axis == SDL_CONTROLLER_AXIS_TRIGGERRIGHT) {
        const int TRIGGER_DEADZONE = 16000;
        bool pressed = value > TRIGGER_DEADZONE;
        if (pressed && !m_triggerRightActive) {
            setInputMode(Controller);
            m_triggerRightActive = true;
            emit actionTriggered(ActionTriggerRight);
        } else if (!pressed && m_triggerRightActive) {
            m_triggerRightActive = false;
            emit actionReleased(ActionTriggerRight);
        }
    }
}

ShulkInputManager::LogicalAction ShulkInputManager::mapKeyToAction(int key, int modifiers)
{
    Q_UNUSED(modifiers)
    switch (key) {
        case Qt::Key_Up:
        case Qt::Key_W:
            return ActionNavigateUp;
        case Qt::Key_Down:
        case Qt::Key_S:
            return ActionNavigateDown;
        case Qt::Key_Left:
        case Qt::Key_A:
            return ActionNavigateLeft;
        case Qt::Key_Right:
        case Qt::Key_D:
            return ActionNavigateRight;
        case Qt::Key_Return:
        case Qt::Key_Enter:
        case Qt::Key_Space:
            return ActionAccept;
        case Qt::Key_Escape:
        case Qt::Key_Back:
        case Qt::Key_Backspace:
            return ActionBack;
        case Qt::Key_X:
        case Qt::Key_P:
            return ActionPrimary;
        case Qt::Key_Y:
            return ActionSecondary;
        case Qt::Key_M:
        case Qt::Key_Menu:
            return ActionMenu;
        case Qt::Key_BracketLeft:
        case Qt::Key_PageUp:
            return ActionPrevTab;
        case Qt::Key_BracketRight:
        case Qt::Key_PageDown:
            return ActionNextTab;
        case Qt::Key_F:
            return ActionFilter;
        case Qt::Key_F5:
            return ActionRefresh;
        case Qt::Key_Q:
            return ActionTriggerLeft;
        case Qt::Key_E:
            return ActionTriggerRight;
        default:
            return ActionNone;
    }
}

void ShulkInputManager::notifyKeyPressed(int key, int modifiers)
{
    // Only map keyboard events when input mode is keyboard
    setInputMode(Keyboard);
    auto action = mapKeyToAction(key, modifiers);
    if (action != ActionNone) {
        emit actionTriggered(action);
    }
}

void ShulkInputManager::notifyPointerMoved()
{
    if (m_inputMode != Mouse) {
        setInputMode(Mouse);
    }
}

void ShulkInputManager::notifyTouchPressed()
{
    if (m_inputMode != Touch) {
        setInputMode(Touch);
    }
}

void ShulkInputManager::openVirtualKeyboard()
{
#if defined(Q_OS_WIN)
    // On Windows (ROG Ally, Legion Go), launch the On-Screen Keyboard or Touch Keyboard
    QString oskPath = QStandardPaths::findExecutable("osk.exe");
    if (!oskPath.isEmpty()) {
        QProcess::startDetached(oskPath, {});
    } else {
        QDesktopServices::openUrl(QUrl("steam://open/keyboard"));
    }
#else
    // On Steam Deck / SteamOS Gaming Mode, opening steam://open/keyboard summons the native OSK
    bool launched = QDesktopServices::openUrl(QUrl("steam://open/keyboard"));
    if (!launched) {
        // Fallback for standalone Linux handhelds / desktop mode
        QString maliit = QStandardPaths::findExecutable("maliit-keyboard");
        if (!maliit.isEmpty()) {
            QProcess::startDetached(maliit, {});
        } else {
            QString onboard = QStandardPaths::findExecutable("onboard");
            if (!onboard.isEmpty()) {
                QProcess::startDetached(onboard, {});
            }
        }
    }
#endif
}

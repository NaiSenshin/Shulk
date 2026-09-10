// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Shulk - Handheld Minecraft Java Launcher
 *  Copyright (C) 2026 Shulk Contributors
 */

#include <QTest>
#include <QSignalSpy>
#include "shulk/ShulkInputManager.h"
#include "shulk/ShulkTheme.h"

class KonamiCode_test : public QObject {
    Q_OBJECT

private slots:
    void testKonamiControllerSequence()
    {
        ShulkInputManager input;
        QSignalSpy spy(&input, &ShulkInputManager::konamiCodeTriggered);

        // Sequence: Up, Down, Up, Down, Left, Right, Left, Right, B, A
        const QList<int> keys = {
            Qt::Key_Up, Qt::Key_Down,
            Qt::Key_Up, Qt::Key_Down,
            Qt::Key_Left, Qt::Key_Right,
            Qt::Key_Left, Qt::Key_Right,
            Qt::Key_B, Qt::Key_A
        };

        for (int key : keys) {
            input.notifyKeyPressed(key);
        }

        QCOMPARE(spy.count(), 1);
    }

    void testKonamiResetOnMistake()
    {
        ShulkInputManager input;
        QSignalSpy spy(&input, &ShulkInputManager::konamiCodeTriggered);

        // Start correctly: Up, Down, Up
        input.notifyKeyPressed(Qt::Key_Up);
        input.notifyKeyPressed(Qt::Key_Down);
        input.notifyKeyPressed(Qt::Key_Up);
        // Mistake: X instead of Down
        input.notifyKeyPressed(Qt::Key_X);

        // Continue remaining sequence
        input.notifyKeyPressed(Qt::Key_Down);
        input.notifyKeyPressed(Qt::Key_Left);
        input.notifyKeyPressed(Qt::Key_Right);
        input.notifyKeyPressed(Qt::Key_Left);
        input.notifyKeyPressed(Qt::Key_Right);
        input.notifyKeyPressed(Qt::Key_B);
        input.notifyKeyPressed(Qt::Key_A);

        // Should not have triggered because of the early mistake
        QCOMPARE(spy.count(), 0);

        // Now do a clean sequence
        const QList<int> keys = {
            Qt::Key_Up, Qt::Key_Down,
            Qt::Key_Up, Qt::Key_Down,
            Qt::Key_Left, Qt::Key_Right,
            Qt::Key_Left, Qt::Key_Right,
            Qt::Key_B, Qt::Key_A
        };

        for (int key : keys) {
            input.notifyKeyPressed(key);
        }

        QCOMPARE(spy.count(), 1);
    }

    void testThemeConsolePanoramas()
    {
        ShulkTheme theme;
        // Start locked
        theme.lockConsolePanoramas();
        QCOMPARE(theme.consolePanoramasUnlocked(), false);

        int lockedCount = theme.availablePanoramas().size();
        // 1 random + 10 official = 11
        QCOMPARE(lockedCount, 11);

        // Unlock
        bool unlocked = theme.unlockConsolePanoramas();
        QCOMPARE(unlocked, true);
        QCOMPARE(theme.consolePanoramasUnlocked(), true);

        int unlockedCount = theme.availablePanoramas().size();
        // 11 + 7 console = 18
        QCOMPARE(unlockedCount, 18);

        // Set console panorama
        theme.setPanorama("console_tu1");
        QCOMPARE(theme.activePanoramaId(), QString("console_tu1"));
        QCOMPARE(theme.panoramaCubeUrl(), QString("qrc:/shulk/panoramas/console_tu1_cube.png"));
        QCOMPARE(theme.panoramaPreviewUrl(), QString("qrc:/shulk/panoramas/console_tu1_preview.png"));
        QCOMPARE(theme.panoramaTitle(), QString("Console TU1 (Xbox 360)"));
    }
};

QTEST_GUILESS_MAIN(KonamiCode_test)
#include "KonamiCode_test.moc"

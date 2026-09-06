// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Prism Launcher - Minecraft Launcher
 *  Copyright (C) 2024 Tayou <git@tayou.org>
 *  Copyright (C) 2024 TheKodeToad <TheKodeToad@proton.me>
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
 *
 * This file incorporates work covered by the following copyright and
 * permission notice:
 *
 *      Copyright 2013-2021 MultiMC Contributors
 *
 *      Licensed under the Apache License, Version 2.0 (the "License");
 *      you may not use this file except in compliance with the License.
 *      You may obtain a copy of the License at
 *
 *          http://www.apache.org/licenses/LICENSE-2.0
 *
 *      Unless required by applicable law or agreed to in writing, software
 *      distributed under the License is distributed on an "AS IS" BASIS,
 *      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *      See the License for the specific language governing permissions and
 *      limitations under the License.
 */
#include "DarkTheme.h"

#include <QObject>

QString DarkTheme::id()
{
    return "dark";
}

QString DarkTheme::name()
{
    return QObject::tr("Dark");
}

QPalette DarkTheme::colorScheme()
{
    QPalette darkPalette;
    darkPalette.setColor(QPalette::Window, QColor(0x1F, 0x22, 0x2A));
    darkPalette.setColor(QPalette::WindowText, Qt::white);
    darkPalette.setColor(QPalette::Base, QColor(0x14, 0x15, 0x18));
    darkPalette.setColor(QPalette::AlternateBase, QColor(0x1A, 0x1C, 0x22));
    darkPalette.setColor(QPalette::ToolTipBase, QColor(0x14, 0x15, 0x18));
    darkPalette.setColor(QPalette::ToolTipText, Qt::white);
    darkPalette.setColor(QPalette::Text, Qt::white);
    darkPalette.setColor(QPalette::Button, QColor(0x36, 0x39, 0x44));
    darkPalette.setColor(QPalette::ButtonText, Qt::white);
    darkPalette.setColor(QPalette::BrightText, QColor(0xFF, 0x55, 0x55));
    darkPalette.setColor(QPalette::Link, QColor(0x55, 0xFF, 0xFF));
    darkPalette.setColor(QPalette::Highlight, QColor(0x2E, 0xCC, 0x71));
    darkPalette.setColor(QPalette::HighlightedText, Qt::black);
    darkPalette.setColor(QPalette::PlaceholderText, QColor(0x7E, 0x82, 0x8A));
    return fadeInactive(darkPalette, fadeAmount(), fadeColor());
}

double DarkTheme::fadeAmount()
{
    return 0.5;
}

QColor DarkTheme::fadeColor()
{
    return QColor(0x1F, 0x22, 0x2A);
}

bool DarkTheme::hasStyleSheet()
{
    return true;
}

QString DarkTheme::appStyleSheet()
{
    return R"(
        QDialog, QMessageBox, QWidget {
            background-color: #1F222A;
            color: #FFFFFF;
            font-size: 11pt;
        }
        QPushButton {
            background-color: #383B46;
            color: #FFFFFF;
            border-top: 2px solid #6E727E;
            border-left: 2px solid #6E727E;
            border-right: 2px solid #141518;
            border-bottom: 2px solid #141518;
            border-radius: 2px;
            padding: 6px 14px;
            font-weight: bold;
            min-height: 24px;
        }
        QPushButton:hover {
            background-color: #4D5262;
            border-top: 2px solid #8B909E;
            border-left: 2px solid #8B909E;
        }
        QPushButton:pressed {
            background-color: #24262E;
            border-top: 2px solid #141518;
            border-left: 2px solid #141518;
            border-right: 2px solid #6E727E;
            border-bottom: 2px solid #6E727E;
        }
        QPushButton:default {
            background-color: #27AE60;
            border-top: 2px solid #58D68D;
            border-left: 2px solid #58D68D;
            border-right: 2px solid #145A32;
            border-bottom: 2px solid #145A32;
        }
        QPushButton:default:hover {
            background-color: #2ECC71;
            border-top: 2px solid #82E0AA;
            border-left: 2px solid #82E0AA;
        }
        QLineEdit, QTextEdit, QPlainTextEdit {
            background-color: #141518;
            color: #FFFFFF;
            border-top: 2px solid #0A0B0C;
            border-left: 2px solid #0A0B0C;
            border-right: 2px solid #373A44;
            border-bottom: 2px solid #373A44;
            border-radius: 2px;
            padding: 6px;
            selection-background-color: #55FFFF;
            selection-color: #000000;
        }
        QProgressBar {
            background-color: #141518;
            border: 2px solid #0A0B0C;
            border-radius: 2px;
            text-align: center;
            color: #FFFFFF;
            font-weight: bold;
        }
        QProgressBar::chunk {
            background-color: #2ECC71;
        }
        QScrollBar:vertical {
            background-color: #141518;
            width: 14px;
            margin: 0px;
        }
        QScrollBar::handle:vertical {
            background-color: #383B46;
            min-height: 20px;
            border-radius: 2px;
        }
        QToolTip {
            color: #FFFFFF;
            background-color: #101114;
            border: 2px solid #FFAA00;
            padding: 4px;
        }
    )";
}

QString DarkTheme::tooltip()
{
    return "";
}

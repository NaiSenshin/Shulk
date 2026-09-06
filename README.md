# Shulk - Handheld Minecraft Java Launcher

<p align="center">
  <img src="program_info/org.prismlauncher.PrismLauncher_256.png" alt="Shulk Logo" width="128" />
  <br />
  <b>Native, controller-driven Minecraft Java Edition launcher designed for handheld gaming PCs.</b>
  <br />
  <sub>Steam Deck • ROG Ally • Legion Go • SteamOS • Bazzite • Windows 11 Handhelds</sub>
</p>

---

## 🎮 Overview

**Shulk** is a modern, high-performance Minecraft Java Edition launcher built natively with **C++23** and **Qt 6 (QML / Qt Quick)** on top of Prism Launcher's mature backend architecture.

Unlike standard desktop launchers designed strictly for keyboard and mouse, Shulk is designed from the ground up for **handheld gaming consoles, controllers, and big-screen TV setups**.

---

## ✨ Features

- **🎯 First-Class Controller & Gamepad Navigation**:
  - Full 2D spatial navigation with Left Analog Stick and D-pad.
  - Native support for Xbox, Steam Deck, PlayStation, and Nintendo Switch button layouts and glyph hints.
  - Dedicated shoulder bumper navigation (`LB` / `RB`) for instant menu switching.
  - Smooth trigger cycling (`LT` / `RT`) through modpack tabs and discover sources.
  - Automatic on-screen keyboard (OSK) invocation (`steam://open/keyboard`, `maliit-keyboard`, Windows `osk.exe`).

- **📦 Universal Multi-Platform Modpack Hub**:
  - Browse, search, and 1-click install modpacks across all major Minecraft platforms:
    - **Modrinth**
    - **CurseForge**
    - **Feed The Beast (FTB)**
    - **Technic**
    - **ATLauncher**
    - **Vanilla & Custom** profile builder with full Minecraft version selector (Releases, Snapshots, Betas, Alphas).
  - High-performance package inspection: queries mod manifests, parses hundreds of included modifications, and displays rich mod cards with descriptions, versions, and icons.

- **🌌 Authentic 3D Minecraft Title Panoramas**:
  - GPU-accelerated cubemap skybox shader sampling authentic Mojang panorama cubemaps across 10 major Minecraft eras (Classic, Aquatic, Village & Pillage, Buzzy Bees, Nether, Caves & Cliffs, Wild, Trails & Tales, Tricky Trials).
  - Dynamic startup panorama shuffling and live real-time panorama rolling in Settings.
  - Configurable atmospheric background blur (`Off`, `Subtle`, `Medium`, `Heavy`).

- **🔊 Authentic Minecraft Sound System**:
  - Built-in UI audio playback powered by SDL2 Audio.
  - Faithful Minecraft sound effects: button clicks, wooden menu clicks, chest open/close transitions, and experience level-up fanfares on account logins.

- **🖥️ Handheld Display & Battery Ergonomics**:
  - Adaptive resolution scaling for 800p (Steam Deck), 1080p (ROG Ally), 1600p (Legion Go), and 4K docked living-room displays.
  - Background power saving: automatically throttles polling timers and pauses GPU shader animations when the window is inactive or Minecraft is running.
  - Seamless game launch overlay with auto-dimming, game window detection, and automatic restore upon game exit.

- **🔒 Secure Authentication**:
  - Streamlined Microsoft Device-Code authentication with giant on-screen codes, real-time polling, and direct browser links.

---

## 🚀 Building from Source

### Prerequisites

- **CMake** 3.22 or higher
- **Ninja** or GNU Make
- **C++23** compatible compiler (GCC 13+, Clang 17+, or MSVC 2022)
- **Qt 6.8+** (Core, Gui, Widgets, Quick, Qml, QuickControls2, QuickLayouts, Network, OpenGL, Svg, Concurrent, NetworkAuth)
- **SDL2** (libsdl2-dev)
- **zlib**

### Linux

```bash
# Clone repository
git clone https://github.com/NaiSenshin/Shulk.git
cd Shulk

# Configure build
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLauncher_EMBED_SECRETS=OFF

# Compile
cmake --build build --target prismlauncher -j$(nproc)

# Run
./build/prismlauncher
```

### Windows (MSYS2 / MinGW-w64)

```bash
# Inside MSYS2 UCRT64 / MINGW64 environment:
pacman -S mingw-w64-ucrt-x86_64-toolchain \
          mingw-w64-ucrt-x86_64-cmake \
          mingw-w64-ucrt-x86_64-ninja \
          mingw-w64-ucrt-x86_64-qt6-base \
          mingw-w64-ucrt-x86_64-qt6-declarative \
          mingw-w64-ucrt-x86_64-qt6-5compat \
          mingw-w64-ucrt-x86_64-SDL2

cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target prismlauncher
```

---

## 📄 License & Attributions

Shulk is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See [COPYING.md](COPYING.md) and [LICENSE](LICENSE) for full licensing terms.

Shulk is based on the open-source **Prism Launcher** and **MultiMC** codebases. All upstream copyright notices, licensing terms, and attributions are fully retained. Minecraft is a trademark of Mojang Synergies AB; Shulk is not affiliated with or endorsed by Mojang or Microsoft.

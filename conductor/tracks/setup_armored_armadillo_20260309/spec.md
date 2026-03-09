# Specification: Setup 'armored-armadillo' Emulation Host

## 1. Overview
Configure `armored-armadillo` (Minisforum HX100G) as a high-performance kiosk emulation PC using `cage`, `gamescope` (with FSR), and ES-DE on Wayland.

## 2. Target Environment
- **Host:** `armored-armadillo` (Ryzen 7 7840HS / Radeon 6650M).
- **User:** Dedicated `kiosk` user (UID/GID 1001).
- **Display Server:** `cage` launching `gamescope -f -e --fsr-upscaling 2 -- emulationstation`.

## 3. Recommended Core/Emulator Mapping (via cores.txt)

| System | Primary Emulator / Core | Note |
| :--- | :--- | :--- |
| **Arcade** | `FB Neo` / `MAME (Current)` | FB Neo preferred for RA |
| **NES** | `Mesen` | Most accurate per docs |
| **SNES** | `Snes9x` | High compatibility |
| **Mega Drive/CD** | `Genesis Plus GX` | Standard for Sega 16-bit |
| **32X** | `PicoDrive` | Required for 32X |
| **PS1** | `Beetle PSX HW` | HW accelerated Vulkan core |
| **Saturn** | `Beetle Saturn` | Accuracy focused |
| **Dreamcast** | `Flycast` | High performance |
| **N64** | `Mupen64Plus-Next` | Modern N64 core |
| **GC/Wii** | `Dolphin` | Standalone and Libretro |
| **PS2** | `LRPS2` | PCSX2-based core |
| **Handhelds** | `mGBA` (GBA), `Gambatte` (GB/C) | Standard cores |
| **3DS** | `Citra` | Standalone preferred |
| **Switch** | `Ryubing` (Standalone) | User requested Switch fork |
| **TeknoParrot** | **Bottles** | Isolated Windows environment |
| **PICO-8** | **Native Linux Binary** | Provided by user |
| **GZDoom** | `PrBoom` / Native | Native preferred for GZDoom |

## 4. Hardware & Software Optimizations
- **Gamescope:** Force FSR upscaling for all emulators and the frontend.
- **Bluetooth:** `services.joycond` enabled for 4x 8BitDo Ultimate 2C in Switch Mode.
- **Network:** Disable 2.4GHz WiFi kernel module to prevent interference.
- **Kiosk:** `cage` compositor launching ES-DE via Gamescope for seamless, full-screen FSR.

## 5. Storage
- All ROMs and BIOS files mapped to `/home/kiosk/roms`.

## 6. Acceptance Criteria
- [ ] System boots directly to ES-DE.
- [ ] 8BitDo controllers pair and function as Switch Pro Controllers.
- [ ] RetroArch configured with Vulkan and RetroAchievements.
- [ ] Kiosk user is restricted and optimized for gaming.

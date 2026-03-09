# Implementation Plan: Setup 'armored-armadillo' Emulation Host

## Phase 1: System Foundation
- [ ] Task: Create `kiosk` user (UID 1001) and groups.
- [ ] Task: Configure `cage` and `gamescope` in NixOS modules.
- [ ] Task: Apply Bluetooth (MT7922) and 2.4GHz WiFi disable fixes.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: System Foundation' (Protocol in workflow.md)

## Phase 2: Controller & Input
- [ ] Task: Enable `services.joycond` and add 8BitDo udev rules.
- [ ] Task: Configure auto-pairing for the 4 controllers.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Controller & Input' (Protocol in workflow.md)

## Phase 3: Emulator & Frontend
- [ ] Task: Install RetroArch with the mapped cores from `cores.txt`.
- [ ] Task: Install Standalone emulators (Dolphin, PCSX2, Citra, Ryubing).
- [ ] Task: Set up **Bottles** for TeknoParrot.
- [ ] Task: Configure ES-DE to launch all systems through Gamescope with FSR.
- [ ] Task: Configure native PICO-8 Linux binary path in ES-DE.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Emulator & Frontend' (Protocol in workflow.md)

## Phase 4: Final Validation
- [ ] Task: Perform cold boot and verify direct launch into ES-DE via Gamescope.
- [ ] Task: Verify 4x 8BitDo controller pairing and mapping in ES-DE and RetroArch.
- [ ] Task: Test sample ROMs for key systems (SNES, PS1, N64, GC).
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Final Validation' (Protocol in workflow.md)

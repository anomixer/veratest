# Apple II VERA Development — Master Session Summary & Architecture Guide

**Session Date**: 2026-09-05 ~ 2026-09-12  
**Target Environments**: Real Apple II (+64KB / //e / IIgs / Laser 128), [Apple2TS](https://apple2ts.com) Web Emulator, and [AppleWin](https://github.com/anomixer/AppleWin) Emulator  
**Hardware Interface**: VERA (Versatile Embedded Retro Adapter) FPGA Card on **Slot 2** (`$C0A0` / `$C200`) or **Slot 4** (`$C0C0` / `$C400`)  
**Active Projects Covered**:
1. `C:\dev\Time-Pilot\TimePilot-IIvera` (Arcade Port & 100% Zero-Disk Runtime Engine — Release v1.9-iivera)
2. `C:\dev\veratest` (7-in-1 Flagship Test Suite & 32MB 375-Image Mode 7 Slideshow Engine — Release v0.0.3)
3. `C:\dev\veramusic` (`veramusic`) (High-Fidelity Audio Engine, 16-Voice Grand Piano PSG, 8010 Hz PCM Streaming & VRAM Audio Player Suite)
4. `C:\dev\verasdedit` (PC-Tools-Style 6502 Hex Sector Editor for VERA SD/MMC SPI Controller — Release v1.0)

---

## 📋 Master Table of Contents

- [Apple II VERA Development — Master Session Summary \& Architecture Guide](#apple-ii-vera-development--master-session-summary--architecture-guide)
  - [📋 Master Table of Contents](#-master-table-of-contents)
  - [1. Executive Repository Status](#1-executive-repository-status)
  - [2. Project 1: Time Pilot IIvera (`c:\dev\Time-Pilot\TimePilot-IIvera`)](#2-project-1-time-pilot-iivera-cdevtime-pilottimepilot-iivera)
    - [2.1 Overview \& High-Level Accomplishments](#21-overview--high-level-accomplishments)
    - [2.2 Zero-Disk Runtime Engine Architecture](#22-zero-disk-runtime-engine-architecture)
    - [2.3 Stage Clear Audio Refinement (Elimination of Ah\~\~\~ Vocal)](#23-stage-clear-audio-refinement-elimination-of-ah-vocal)
    - [2.4 High Score Ranking Table 7-Digit Display \& Precision Alignment](#24-high-score-ranking-table-7-digit-display--precision-alignment)
    - [2.5 Stage 5 (A.D. 2001) Space UFO \& Mothership Palette Fix \& Alarm Pulsation](#25-stage-5-ad-2001-space-ufo--mothership-palette-fix--alarm-pulsation)
    - [2.6 Boss Progressive Smoke Billowing Physics](#26-boss-progressive-smoke-billowing-physics)
    - [2.7 Memory Safety, Linker Layout \& Zero Page Protection](#27-memory-safety-linker-layout--zero-page-protection)
    - [2.8 Bilingual Documentation \& Milestones](#28-bilingual-documentation--milestones)
    - [2.9 Git Commit History (`TimePilot-IIvera`)](#29-git-commit-history-timepilot-iivera)
    - [2.10 Official 4-Voice Hardware PSG Opening Theme \& Synchronized Stage 1 Timing](#210-official-4-voice-hardware-psg-opening-theme--synchronized-stage-1-timing)
    - [2.11 100% In-Memory Sprite Art \& Elimination of Mid-Game Disk I/O](#211-100-in-memory-sprite-art--elimination-of-mid-game-disk-io)
    - [2.12 Authentic Konami Arcade High Score BGM (4-Voice VRAM-Resident PSG) \& CX16 Fanfare](#212-authentic-konami-arcade-high-score-bgm-4-voice-vram-resident-psg--cx16-fanfare)
    - [2.13 High Score Screen Jitter \& Slow Music Fix (Lazy Redraw + SPEEDUP Calibration)](#213-high-score-screen-jitter--slow-music-fix-lazy-redraw--speedup-calibration)
    - [2.14 Arbitrary ProDOS Boot Drive Support (Drive 1, Drive 2, Drive n Transparent Loading)](#214-arbitrary-prodos-boot-drive-support-drive-1-drive-2-drive-n-transparent-loading)
    - [2.15 Unified Official Dual-Platform Distribution Targets](#215-unified-official-dual-platform-distribution-targets)
    - [2.16 Version 1.9: Upstream Stefan Wessels Integration, Native TPILOT.SYSTEM \& Critical Boot Fixes](#216-version-19-upstream-stefan-wessels-integration-native-tpilotsystem--critical-boot-fixes)
  - [3. Project 2: VERA Test Suite \& Slideshow (`c:\dev\veratest`)](#3-project-2-vera-test-suite--slideshow-cdevveratest)
    - [3.1 Overview \& High-Level Accomplishments](#31-overview--high-level-accomplishments)
    - [3.2 Hardware Architecture \& Dual-Port Slot Mapping](#32-hardware-architecture--dual-port-slot-mapping)
    - [3.3 7-in-1 Flagship Test Suite (`veratest.po`, 140KB Floppy)](#33-7-in-1-flagship-test-suite-veratestpo-140kb-floppy)
    - [3.4 32MB Fullscreen 375-Image Slideshow Engine (`slideshow.hdv`)](#34-32mb-fullscreen-375-image-slideshow-engine-slideshowhdv)
      - [3.4.1 File System Structure](#341-file-system-structure)
      - [3.4.2 Direct Block MLI ($80) Streaming Architecture](#342-direct-block-mli-80-streaming-architecture)
      - [3.4.3 Interactive Controls & Dual Status Display](#343-interactive-controls--dual-status-display)
      - [3.4.4 Direct Mode 7 Bitmap OSD Overlay & Zero-Artifact Palette LUTs](#344-direct-mode-7-bitmap-osd-overlay--zero-artifact-palette-luts)
      - [3.4.5 Space-Free Corner Badges & Pure Image MUTE Mode](#345-space-free-corner-badges--pure-image-mute-mode)
      - [3.4.6 PSG Shadow Register Table & Instant Unmute Restoration](#346-psg-shadow-register-table--instant-unmute-restoration)
      - [3.4.7 Cold-Boot & Clean Reboot Initialization](#347-cold-boot--clean-reboot-initialization)
      - [3.4.8 Acoustic Balancing for PSG Audio (`CANYON.ZSM`)](#348-acoustic-balancing-for-psg-audio-canyonzsm)
      - [3.4.9 5-Second Auto-Start Countdown in `startup.bas`](#349-5-second-auto-start-countdown-in-startupbas)
    - [3.5 3-Track X16 ZSM PSG Audio Streaming System](#35-3-track-x16-zsm-psg-audio-streaming-system)
    - [3.6 Standalone Zero-Dependency Build Architecture](#36-standalone-zero-dependency-build-architecture)
    - [3.7 Apple2TS & AppleWin Integration](#37-apple2ts--applewin-integration)
    - [3.8 Git Commit History (`veratest`)](#38-git-commit-history-veratest)
  - [4. Project 3: VERA Music Engine & Jukebox (`c:\dev\veramusic`, `veramusic`)](#4-project-3-vera-music-engine--jukebox-cdevveramusic-veramusic)
    - [4.1 Overview & High-Level Accomplishments](#41-overview--high-level-accomplishments-1)
    - [4.2 Hardware Audio Architecture & VERA Dual-Pipeline (16-Voice PSG + 8010 Hz PCM FIFO)](#42-hardware-audio-architecture--vera-dual-pipeline-16-voice-psg--8010-hz-pcm-fifo)
    - [4.3 VERA 128KB SRAM Pre-Load Player (`psgvram.asm`) — Zero Floppy Noise & Dual-Port Isolation](#43-vera-128kb-sram-pre-load-player-psgvramasm--zero-floppy-noise--dual-port-isolation)
    - [4.4 Chopin's *Fantaisie-Impromptu*: 100% Pure Acoustic Piano Additive Synthesis](#44-chopins-fantaisie-impromptu-100-pure-acoustic-piano-additive-synthesis)
    - [4.5 Direct-to-FIFO 8010 Hz PCM Streaming: *Space Debris* & *The Wellerman*](#45-direct-to-fifo-8010-hz-pcm-streaming-space-debris--the-wellerman)
    - [4.6 General MIDI Percussion & Michael Jackson's *Beat It* Guitar Riff Fix](#46-general-midi-percussion--michael-jacksons-beat-it-guitar-riff-fix)
    - [4.7 Smart Trailing Dead Silence Auto-Trim & ProDOS Block Conservation](#47-smart-trailing-dead-silence-auto-trim--prodos-block-conservation)
    - [4.8 Universal 5-Second Seeking, Master Volume Scaling & Stopwatch Engine](#48-universal-5-second-seeking-master-volume-scaling--stopwatch-engine)
    - [4.9 ProDOS Disk Formats: 140KB Floppy (`jukebox.po`) & 32MB Hard Disk (`jukebox.hdv`)](#49-prodos-disk-formats-140kb-floppy-jukeboxpo--32mb-hard-disk-jukeboxhdv)
    - [4.10 Standalone Build Toolchain & Zero-Dependency Conversion Pipeline](#410-standalone-build-toolchain--zero-dependency-conversion-pipeline)
    - [4.11 Git Commit History (`veramusic`)](#411-git-commit-history-veramusic)
  - [5. Project 4: VERA SD Sector Editor (`c:\dev\verasdedit`, `verasdedit`)](#5-project-4-vera-sd-sector-editor-cdevverasdedit-verasdedit)
    - [5.1 Overview & High-Level Accomplishments](#51-overview--high-level-accomplishments)
    - [5.2 Hardware Architecture & VERA SD/MMC SPI Controller (`$C21E`/`$C21F`)](#52-hardware-architecture--vera-sdmmc-spi-controller-c21ec21f)
    - [5.3 Dual-State Hex & ASCII Editor Engine](#53-dual-state-hex--ascii-editor-engine)
    - [5.4 Apple IIe 80-Column Text Display Interleaving Model](#54-apple-iie-80-column-text-display-interleaving-model)
    - [5.5 Critical Hard-Won 6502 Debugging Lessons](#55-critical-hard-won-6502-debugging-lessons)
      - [5.5.1 Assembler `CPX`/`CPY` Addressing-Mode Bug (Immediate vs Zero Page)](#551-assembler-cpxcpy-addressing-mode-bug-immediate-vs-zero-page)
      - [5.5.2 80-Column Display Init Softswitch Trap (`80STORE OFF`, `PAGE2 OFF`)](#552-80-column-display-init-softswitch-trap-80store-off-page2-off)
      - [5.5.3 RAMWRT/RAMRD Banking Leaks & Code/Scratch Buffer Separation (`$2E20`)](#553-ramwrtramrd-banking-leaks--codescratch-buffer-separation-2e20)
      - [5.5.4 Subroutine A-Register Clobbering in Hex Display Modes](#554-subroutine-a-register-clobbering-in-hex-display-modes)
      - [5.5.5 Assembler Dropping `label,Y` on `AND`/`ORA` (The 8-Byte Inverse Bug)](#555-assembler-dropping-labely-on-andora-the-8-byte-inverse-bug)
      - [5.5.6 SD Sector Write Persistence & Emulator `fflush` Synchronization](#556-sd-sector-write-persistence--emulator-fflush-synchronization)
    - [5.6 Standalone Zero-Dependency Build Pipeline & ProDOS 2.4.3 Integration](#56-standalone-zero-dependency-build-pipeline--prodos-243-integration)
    - [5.7 Git Commit History (`verasdedit`)](#57-git-commit-history-verasdedit)
  - [6. Verification Matrix \& Cross-Testing Results](#6-verification-matrix--cross-testing-results)
  - [7. Baseline State for Starting a New Session](#7-baseline-state-for-starting-a-new-session)

---

## 1. Executive Repository Status

| Repository | Path | Current Branch | HEAD Commit | Working Tree | Distribution Artifacts |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TimePilot-IIvera** | `c:\dev\Time-Pilot\TimePilot-IIvera` | `master` (synced with `fork/master`) | `9548e85` (1 commit ahead of `origin/master`) | Clean | `TimePilot-IIvera.hdv` (800KB), `TimePilot-IIvera-D1.po` (140KB), `TimePilot-IIvera-D2.po` (140KB) |
| **veratest** | `c:\dev\veratest` | `main` (synced with `origin/main`) | `5216fe1` (Tag `v0.0.3`) | Clean | `veratest.po` (140KB), `veratest.png`, `slideshow.hdv` (32MB), `slideshow.png` |
| **veramusic** | `c:\dev\veramusic` (`c:\dev\veramus`) | `master` (synced with `origin/master`) | `56bc9c0` (1 squashed commit) | Clean | `jukebox.po` (140KB), `jukebox.hdv` (32MB), `psgvram.bin`, `psgstream.bin`, `psgplay.bin`, `pcmstream.bin` |
| **verasdedit** | `c:\dev\verasdedit` | `master` (synced with `origin/master`) | `14eed58` | Clean | `verasdedit.po` (140KB bootable floppy), `VERASDEDIT.BIN` (3.5KB, load `$2000`) |

All four repositories are completely tested, committed, synchronized with their respective remotes, and ready for deployment.

---

## 2. Project 1: Time Pilot IIvera (`c:\dev\Time-Pilot\TimePilot-IIvera`)

### 2.1 Overview & High-Level Accomplishments
`TimePilot-IIvera` is a full port of Konami's legendary 1982 arcade classic *Time Pilot* to the Apple II family utilizing the VERA FPGA card. It bridges the gap between Stefan Wessels' Commander X16 version (`TimePilot-CX16`) and native 6502 Apple II hardware.

In this session, the project achieved major architectural and gameplay milestones:
1. **100% Zero-Disk Runtime Guarantee**: All PCM sound effects reside simultaneously in VERA VRAM Bank 0, completely eliminating disk seeks and drive motor noise during active gameplay.
2. **Official 4-Voice Hardware PSG Real-Time Game Start Theme (`AUDIO_GAME_START`)**: Promoted cycle-accurate PSG opening theme to the official standard release. Saved 45.7 KB (75%) of VRAM Bank 0 and 89 disk blocks. Synchronized to trigger cleanly when `STAGE 1 / PLAYER 1 / A.D. 1910` appears after radar sweep.
3. **100% In-Memory Sprite Art & Zero Mid-Game Disk I/O**: Loaded the entire 59,456-byte `art.blob` permanently into VRAM Bank 1 at startup. Completely eliminated `upload_stage_art()`, the `LOADING...` banner, and all inter-era transition latency.
4. **Authentic Konami Arcade High Score BGM (`AUDIO_HIGHSCORE`)**: Extracted authentic 4-voice PSG loop from arcade `name_entry.vgm`, packed into VRAM Bank 0 at `$D7F0` (2,372 bytes) with zero host CPU RAM consumption.
5. **High Score Screen Lazy Redraw & Tempo Calibration**: Gated `draw_hs_table()` with a dirty flag to slash per-frame VERA writes by $\ge 95\%$, eliminating input lag and restoring smooth 60 FPS cursor blink alongside calibrated `SPEEDUP = 1.06` BGM tempo.
6. **Arbitrary ProDOS Boot Drive Support (`Drive 1`, `Drive 2`, `Drive n`)**: Rewrote `disk_init()` to inspect volume size directly on `boot_unit` (`$BF30`) and bind all asset streaming to `boot_unit` in HDV mode. The hard disk image can now be booted or loaded from Drive 1, Drive 2, or any slot/drive without graphical tile corruption.
7. **High Score Ranking Table 7-Digit Support**: Fixed the 5-digit truncation bug ($\ge 100,000$ points) and strictly aligned the score's units digit under the `'G'` of `SCORE RANKING TABLE` at Column 16.
8. **Stage 5 Space Mothership & UFO Color Parity**: Fixed stale palette inheritance that turned the Mothership murky dark green, restoring authentic arcade electric Cyan (`0x00CF`) with authentic 8-frame Cyan/Magenta (`0x0C0C`) damage alarm flashing.
9. **Progressive Boss Damage Billowing Smoke**: Eliminated premature smoke on unhit bosses, implementing progressive health-gated smoke.
10. **Bilingual Documentation & Full Milestone Log**: Created synchronized bilingual `README.md` and detailed all 75 engineering milestones in `AGENTS.md`.

---

### 2.2 Zero-Disk Runtime Engine Architecture
To ensure seamless arcade responsiveness on real Apple II hardware with Floppy or Hard Disk controllers, all audio assets must reside in memory. Because Apple II main memory is constrained to 64KB (with `< 14 KB` free headroom), VERA's 128KB VRAM is utilized as high-speed audio sample RAM.

#### Dual-Bank VRAM Audio Packing
- **Bank 0 Audio Pool** (`$1000..$F5C5`, total 58,821 bytes / 61,440 bytes allocated):
  - `AUDIO_GAME_START` (7.10s, 35,500 bytes) — Initial launch melody
  - `AUDIO_TIMEWARP` (1.20s, 6,000 bytes) — Stage transition vortex
  - `AUDIO_BOMB` (0.60s, 3,000 bytes) — Anti-aircraft flak
  - `AUDIO_BIG_EXPLOSION` (1.38s, 6,900 bytes) — Boss destruction
  - `AUDIO_BOMB_ALERT` (0.90s, 4,500 bytes) — Danger siren
  - `AUDIO_RESCUE` (0.58s, 2,900 bytes) — Parachutist recovery
  - *Headroom*: 2,619 bytes free.
- **Bank 1 Audio Pool** (`$1200..$6F65`, total 23,909 bytes / 28,160 bytes allocated):
  - `AUDIO_FIRE` (0.16s, 800 bytes) — Player laser/cannon
  - `AUDIO_EXPLOSION` (0.70s, 3,500 bytes) — Small enemy explosion
  - `AUDIO_HIT` (0.12s, 600 bytes) — Bullet impact
  - `AUDIO_MAYDAY` (1.20s, 6,000 bytes) — Distress call
  - `AUDIO_WARNING` (1.00s, 5,000 bytes) — Boss arrival klaxon
  - `AUDIO_BONUS` (1.60s, 8,000 bytes) — Bonus squadron score
  - *Headroom*: 4,251 bytes safe headroom before Sprite RAM at `$8000`.

Result: **Zero disk reads occur from the moment the game starts until return to ProDOS.**

---

### 2.3 Stage Clear Audio Refinement (Elimination of Ah~~~ Vocal)
- **Investigation**: Previous builds introduced an "Ah~~~" female vocal sample during Stage Clear. Arcade reference audio confirms that the 1982 Konami cabinet uses pure AY-3-8910 / PSG synthesized rising arpeggio chords.
- **Implementation**:
  - `tools/mkpcm_blob.mjs`: Set `AUDIO_NEXT_LEVEL` to `maxSec: 0`, completely removing `next_level.pcm` from the binary payload.
  - `src/audio.c`: Rewrote `case AUDIO_NEXT_LEVEL:` to drive VERA PSG Channel 0 and Channel 3 with rising arpeggio frequencies (`sfxFreq = 680` and `860`), panning center (`0xC0`) with pulse waveform (`0x00`).

---

### 2.4 High Score Ranking Table 7-Digit Display & Precision Alignment
- **Problem**: Scores $\ge 100,000$ (e.g., `150400`) were truncated to 5 digits (`50400`) because `draw_hs_table()` used `for (int b = 4; b >= 0; b--)`.
- **Formatting & Alignment Requirement**:
  - Table Title `sRanking` (`"SCORE RANKING TABLE"`) is rendered at Row 5, Column 4.
  - Counting columns:
    ```text
    Col: 0123456789012345678901234
    Str:     SCORE RANKING TABLE
                   ^
               'G' is at Column 16
    ```
  - The units digit of the score MUST land exactly at Column 16 under `'G'`.
- **Implementation in `src/main.c`**:
  ```c
  /* 7-digit formatting with leading space padding */
  char sbuf[8];
  uint32_t val = highScore[i];
  for (int b = 6; b >= 0; b--) {
      sbuf[b] = (val % 10) + '0';
      val /= 10;
  }
  sbuf[7] = '\0';
  int z = 0;
  while (z < 6 && sbuf[z] == '0') {
      sbuf[z] = ' ';
      z++;
  }
  draw_text(y, 10, sbuf, hsColor[i]);
  draw_initials(y, 20, highInitials[i], hsColor[i]);
  ```
  - Starting at Column 10: length 7 spans columns 10, 11, 12, 13, 14, 15, 16.
  - The units digit (`sbuf[6]`) is located at **Column 16**, directly under `'G'`.
  - Initials at Column 20 leave a clean 3-space gutter (Columns 17, 18, 19).

---

### 2.5 Stage 5 (A.D. 2001) Space UFO & Mothership Palette Fix & Alarm Pulsation
- **Problem**: Arcade screenshots showed Stage 5 Mothership with an electric cyan core, windows, and perimeter, but in our build it rendered murky dark green.
- **Root Cause**:
  - Stage 5 Mothership (`boss4_frames`) and UFO (`enemy4_frames`) use **sprite palette index 14**.
  - In Stages 0..2, `update_propeller()` dynamically overwrote sprite palette index 14 (`PALETTE_ADDR + 60`) with sky color to make the player's propeller transparent.
  - In Stage 2 (1970), sky was dark green (`0x0063`). Upon entering Stage 5, `set_stage_palette()` only set `palette[0]` (black sky), leaving index 14 contaminated with the stale `0x0063` green!
- **Implementation**:
  1. **Palette Initialization in `src/main.c` (`set_stage_palette`)**:
     ```c
     vera_set_addr(VERA_INC_BANK1, (uint16_t)(PALETTE_ADDR + 32 + 14 * 2));
     if (stage == 4) {
         VERA.data0 = 0xCF; VERA.data0 = 0x00; /* 0x00CF = Electric Cyan */
     } else {
         VERA.data0 = (uint8_t)(c & 0xFF);
         VERA.data0 = (uint8_t)(c >> 8);
     }
     ```
  2. **Arcade Damage Alarm Flashing in `update_propeller()`**:
     ```c
     } else if (stage == 4) {
         if (bossOn && bossHp <= (BOSS_HP * 2) / 3) {
             if (!(frameCount & 7)) {
                 propState ^= 1;
                 vera_set_addr(VERA_INC_BANK1, (uint16_t)(PALETTE_ADDR + 32 + 14 * 2));
                 if (propState) {
                     VERA.data0 = 0xCF; VERA.data0 = 0x00; /* Electric Cyan */
                 } else {
                     VERA.data0 = 0x0C; VERA.data0 = 0x0C; /* Magenta Alarm */
                 }
             }
         } else if ((frameCount & 31) == 0) {
             vera_set_addr(VERA_INC_BANK1, (uint16_t)(PALETTE_ADDR + 32 + 14 * 2));
             VERA.data0 = 0xCF; VERA.data0 = 0x00;
         }
     }
     ```
  - When the Mothership drops to $\le 66\%$ health, the cockpit and core flash between electric Cyan (`0x00CF`) and Magenta (`0x0C0C`) every 8 frames.

---

### 2.6 Boss Progressive Smoke Billowing Physics
- Fixed a bug where a newly spawned boss emitted smoke immediately before taking any hits.
- Implemented health-gated progressive smoke billowing in `update_boss()`:
  - $\text{HP} > 66\%$: Clean flight, 0 smoke particles.
  - $33\% < \text{HP} \le 66\%$: Light gray trailing smoke.
  - $\text{HP} \le 33\%$: Heavy, turbulent black/orange billowing smoke with erratic flight tremor.

---

### 2.7 Memory Safety, Linker Layout & Zero Page Protection
- Linker: `llvm-mos` (`mos-apple2e-clang`) with custom link script (`src/link1000.ld`).
- Binary size: `MAIN.BIN` is 32,190 bytes (load base `$1400`, program ends at `$91BF`).
- Apple II ProDOS boundary: ProDOS file buffers reside at `$9600..$BFFF`. Our top address `$91BF` leaves **1,089 bytes of verified safe headroom below `$9600`**, completely free of `NO BUFFERS AVAILABLE` errors and zero memory corruption, and **over 11 KB below the ProDOS soft stack at `$BE00`**.
- Zero Page utilization: variables span `$00..$7C`, leaving zero page clean of conflict with Apple II ROM Monitor or ProDOS MLI call parameters.

---

### 2.8 Bilingual Documentation & Milestones
- `README.md`: Re-authored with top anchor navigation (`[English](#english) | [繁體中文](#繁體中文)`).
  - English section covers architecture, CX16 vs IIgs vs IIvera comparison, zero-disk runtime, build instructions, and full controls.
  - Traditional Chinese section details all 75 engineering milestones, technical breakthroughs, and hardware specifications.
- `AGENTS.md`: Updated to Milestone 75 (Arbitrary Boot Drive Support for HDV / ProDOS Images).

---

### 2.9 Git Commit History (`TimePilot-IIvera`)
```text
2d1bc55 (HEAD -> master, fork/master) fix(disk): support booting HDV from arbitrary drive (Drive 2 / Drive n)
e3570ed docs: update AGENTS.md + README for High Score BGM (entries 73-74) and MAIN.BIN footprint
01d5984 Fix HS screen jitter and slow BGM: lazy redraw + restore SPEEDUP=1.06
a44d25a Port CX16 stage clear fanfare (PCM) and arcade ranking entry BGM (4-voice PSG)
fbf9bcd Load all sprite art into VRAM Bank 1 at startup; eliminate mid-game disk streaming and LOADING
7958925 Update build.bat and build_hdv.mjs to generate only TimePilot-IIvera.hdv
111c3b6 Remove TimePilot-IIvera-test.hdv and unify build output to TimePilot-IIvera.hdv
7875c18 Promote 4-voice PSG opening theme to official standard release
848f193 Start opening theme when STAGE 1 announce is displayed
4de8d4d Play opening theme during radar sweep with smooth 60Hz timing
e99f82c fix(audio): Start opening theme after radar sweep to eliminate timing jitter and missed notes
a80e3c6 fix(audio): Scale PSG theme volume to 0x3F full range and route to primary channels 0..3
94ecdf3 feat(audio): Add 4-voice VERA PSG real-time game start theme and TimePilot-IIvera-test.hdv image
990ca44 docs: clarify tracked base templates (140kb.po, 800kb.hdv) in .gitignore
2f1c07a build(disk): rename floppy images to TimePilot-IIvera-D1.po and TimePilot-IIvera-D2.po
f893f60 docs: Add English and Traditional Chinese bilingual README with navigation and update AGENTS.md
04b872f fix(art): restore authentic arcade Cyan color and damage pulsation for Stage 5 Space Mothership
ee2d7b9 fix(ui): Support 7-digit scores in Ranking Table with units digit aligned under G of RANKING
cac3041 audio: Restore authentic Konami Stage Clear Ah~~~ vocal fanfare and optimize VRAM audio memory map
6a643ce fix(boss): eliminate premature smoke on unhit boss and implement progressive damage billowing
```

---

### 2.10 Official 4-Voice Hardware PSG Opening Theme & Synchronized Stage 1 Timing
- **Resource Savings & Architecture**:
  - Promoted the 4-Voice PSG opening theme to the official standard release across all distribution targets (`TimePilot-IIvera.hdv`, `TimePilot-IIvera-D1.po`, `TimePilot-IIvera-D2.po`).
  - Replaced the 45.7 KB PCM sample with a 1,740-byte cycle-accurate PSG event table (`src/theme_psg.h`).
  - Saved **45,719 bytes (75%) of VERA VRAM Bank 0**, freeing up 46 KB+ for sound effects and music tables.
  - Saved **89 ProDOS disk blocks (44.5 KB)** across HDV and floppy images.
- **Timing Synchronization**:
  - Opening theme playback triggers exactly when `STAGE 1 / PLAYER 1 / A.D. 1910` text appears after radar sweep completion.
  - Rock-solid 60Hz frame timing uninterrupted through 435 frames (~7.25s) while allowing smooth player heading rotation and propeller animation.

---

### 2.11 100% In-Memory Sprite Art & Elimination of Mid-Game Disk I/O
- **VRAM Reallocation**:
  - Relocated all remaining PCM sound effects (Coin, Bomb, Rocket, Boss, Timewarp, etc.) into VRAM Bank 0 (`$1000..$B70E`, 42,766 B).
  - VRAM Bank 1 (`$0000..$EFFF`, 61,440 B) is now 100% dedicated to sprite graphics.
- **Complete Boot-Time Art Loading**:
  - The entire `art.blob` (59,456 bytes = 117 blocks) is loaded into VRAM Bank 1 at startup.
  - All 5 eras of player fighters, enemy types, bosses, clouds, space asteroids, munitions, explosions, 3D logos, and HUD glyphs are permanently co-resident in VRAM.
- **Zero Disk Access Mid-Game**:
  - Completely removed dynamic disk streaming from `upload_stage_art()`.
  - Removed the `LOADING...` screen banner and eliminated inter-era delay and audio muting.
  - Hyperspace transitions (Stage 1 $\rightarrow$ 2 $\rightarrow$ 3 $\rightarrow$ 4 $\rightarrow$ 5) are instantaneous. On dual floppy, Disk 1 is never accessed after initial boot.
  - Code reduction: saved 686 bytes in `MAIN.BIN`.

---

### 2.12 Authentic Konami Arcade High Score BGM (4-Voice VRAM-Resident PSG) & CX16 Fanfare
- **CX16 Stage Clear Fanfare**: Restored Stefan Wessels' CX16 victory jingle (`AUDIO_NEXT_LEVEL`, 1.48s PCM sample) playing cleanly on stage boss defeat.
- **Arcade High Score Ranking BGM (`AUDIO_HIGHSCORE`)**:
  - Extracted 593 AY-3-8910 register events spanning ~7.72s at 60fps from arcade `name_entry.vgm` using `tools/gen_psg_highscore.mjs`.
  - Stored in VRAM Bank 0 at `$D7F0` (2,372 bytes packed in `pcm.blob`) as a VRAM-resident PSG event table.
  - **Zero Host RAM Used**: During initials entry, `highScorePsgService()` reads 4-byte events directly from VRAM Bank 0 into VERA PSG channels 0–3 every 60Hz frame with seamless looping.

---

### 2.13 High Score Screen Jitter & Slow Music Fix (Lazy Redraw + SPEEDUP Calibration)
- **Problem**: Users reported that the High Score initials entry screen felt jittery/stuttery (`頓頓的`) and the background music played noticeably too slow.
- **Root Cause of Jitter**: `draw_hs_table()` was executed on every single 60Hz frame in `state = 2`, writing 5 rows × 3 fields × ~8 chars = 120 VERA address setups + 240 VERA data writes every 16.6ms. On the 1.02 MHz 6502 CPU, this saturated frame time, starving `audioServiceAudio()` and dropping PSG music ticks.
- **Lazy Redraw Solution**: Replaced unconditional table drawing with a dirty-flag check (`titleClear`). The ranking table is rendered only once upon entering the screen; each 60Hz frame only updates the 3-character blinking initials cursor (`draw_initials()`). Slashed VERA write bandwidth by $\ge 95\%$.
- **Tempo Calibration**: Restored `SPEEDUP = 1.06` factor in `tools/gen_psg_highscore.mjs`, matching the arcade VGM tempo to CX16 reference playback.
- **Result**: Rock-solid 60 FPS cursor response and fluent, authentic BGM playback.

---

### 2.14 Arbitrary ProDOS Boot Drive Support (Drive 1, Drive 2, Drive n Transparent Loading)
- **Problem**: When `TimePilot-IIvera.hdv` was mounted in Drive 2 (e.g. Slot 7 Drive 2 `$F0`) alongside another volume in Drive 1 (e.g. `h32mb.2mg` `$70`), the screen displayed scrambled/corrupted graphics tiles upon launch.
- **Root Cause**: In `src/disk.c`, `disk_init()` assumed the boot volume was always Drive 1, executing `drive1_unit = boot_unit & 0x7F` and setting `art_unit = drive1_unit; pcm_unit = drive1_unit;`. Furthermore, it read volume directory block 2 from `drive1_unit`. When booted from Drive 2, it read volume headers and streamed sprite art (block 900) and audio (block 200) from the Drive 1 disk (`h32mb.2mg`), corrupting VRAM patterns.
- **Universal Multi-Drive Fix**:
  1. `disk_init()` reads volume block 2 directly from `boot_unit` (`*(volatile uint8_t *)0xBF30`).
  2. For HDV images (`total_blocks > 280`), `art_unit`, `pcm_unit`, `drive1_unit`, and `drive2_unit` are all assigned directly to `boot_unit`.
  3. All asset streaming (`disk_ensure()`) is strictly pinned to `boot_unit`.
  4. For dual 140KB floppy mode (`total_blocks <= 280`), `drive1_unit = boot_unit & 0x7F` and `drive2_unit = boot_unit | 0x80` remain paired to Drive 1 and Drive 2.
- **Result**: `TimePilot-IIvera.hdv` can be mounted, booted, or launched from Drive 1, Drive 2, or any arbitrary slot/drive without graphical glitching or device collision.

---

### 2.15 Unified Official Dual-Platform Distribution Targets
- **800KB Bootable ProDOS Hard Disk**:
  - `TimePilot-IIvera.hdv`: Full single-volume image containing `MAIN.BIN` (Slot 2), `MAIN4.BIN` (Slot 4), `STARTUP`, 4-voice PSG theme, VRAM High Score BGM, and all sprite art. Bootable from Drive 1 or Drive 2.
- **Dual 140KB 5.25" Floppy Disks**:
  - `TimePilot-IIvera-D1.po`: Boot volume in Drive 1 (PRODOS, BASIC.SYSTEM, STARTUP, Slot 2 binary, full sprite art). 249/280 blocks used (31 free).
  - `TimePilot-IIvera-D2.po`: Sound & Slot 4 volume in Drive 2 (PCM audio effects, Slot 4 binary). 177/280 blocks used (103 free).

---

### 2.16 Version 1.9: Upstream Stefan Wessels Integration, Native TPILOT.SYSTEM & Critical Boot Fixes
- **Upstream Collaboration & Main README Credit**:
  - Upstream creator Stefan Wessels ([StewBC/Time-Pilot](https://github.com/StewBC/Time-Pilot)) officially integrated the Apple II VERA port into the primary upstream repository (Commit `0870564`), crediting `anomixer` directly on the root `README.md`.
  - Added 14 commits of upstream improvements, arcade-parity physics, and structural refactoring.
- **Architectural Breakthrough: Native ProDOS SYS Direct Loader (`TPILOT.SYSTEM`)**:
  - Completely eliminated `BASIC.SYSTEM` and Applesoft BASIC (`startup.bas` / `startup_d1.bas`), saving memory overhead and launch latency.
  - ProDOS boots directly into `TPILOT.SYSTEM` at `$2000`, which presents a 40-column VERA card probe & control status screen on Text Page 1 (`$0400`).
  - Employs a compact 40-byte Page 3 (`$0300`) trampoline that streams `MAIN.BIN` (or `MAIN4.BIN`) directly to `$0800` via ProDOS MLI `READ_BLOCK` (`$80`) and jumps to `$0800`.
  - **Over 10 KB Memory Headroom**: Program RAM now spans `$0800..$B7FF` (45,056 bytes maximum), providing over 10 KB of safe headroom below the MLI disk window at `$B800` and eliminating HIMEM `$9600` constraints.
- **Cross-Platform Python 3 + CMake Build System**:
  - Replaced all Node.js build dependencies with self-contained Python 3 scripts (`build_hdv.py`, `build_disk.py`, `mkart.py`, `check_size.py`).
  - Standardized cross-platform builds across Windows, macOS, and Linux using `cmake -B build` and `cmake --build build`.
- **Arcade Parity & Physics Refinements**:
  - Restored authentic Konami arcade `rays[32][32]` beam deflection angle table.
  - Restored authentic 16-frame staggered squadron spawn intervals (enemies engage in pairs).
  - Era-specific collision hitboxes fine-tuned for authentic 1910–2001 dogfight feel (16/16/9/16/8).
  - Fixed 2-Player turn swapping on player death.
  - Added off-screen grace margins for bombs, rockets, and boomerangs matching the CX16 version.
- **Critical Boot & Stability Fixes**:
  1. **ProDOS BIN Header Stripping (`2002- BRK` Fix)**:
     - `mos-apple2-clang`'s default linker script emits a 4-byte ProDOS BIN header (`00 20 DC 09` = load address `$2000` + length).
     - ProDOS loads `.SYSTEM` (type `$FF`) files directly at `$2000` and executes `JMP $2000`. Without stripping, the first byte executed is `$00` (`BRK`), halting the machine with `2002- BRK`.
     - Both `build_hdv.py` and `build_disk.py` were patched to automatically detect and strip this header, allowing clean entry at `LDA #$00` (`$A9 $00`).
  2. **ProDOS MLI Register Preservation**:
     - ProDOS MLI calls (`JSR $BF00`) do not preserve the `X` and `Y` registers.
     - `src/loader.s` was patched to preserve `X` to `$3C9` before calling `JSR $BF00` and restore via `LDX $3C9` right after, preventing corruption of the 70-block loading loop.
- **Official GitHub Release v1.9-iivera**:
  - Tagged `v1.9-iivera` on commit `a7fa28c` (1 commit ahead of upstream `0870564`).
  - Released on GitHub with all 4 verified distribution assets: `TimePilot-IIvera.hdv` (800KB), `TimePilot-IIvera-D1.po` (140KB), `TimePilot-IIvera-D2.po` (140KB), and `TimePilot-IIvera-v1.9.zip` (230KB).

---

## 3. Project 2: VERA Test Suite & Slideshow (`c:\dev\veratest`)

### 3.1 Overview & High-Level Accomplishments
`veratest` is the official, comprehensive hardware verification suite and demonstration package for the VERA FPGA card installed on Apple II computers, the [Apple2TS](https://apple2ts.com) web emulator, and the [AppleWin](https://github.com/anomixer/AppleWin) desktop emulator.

Key features and deliverables in Release v0.0.3:
1. **7-in-1 Flagship Test Suite (`veratest.po`, 140KB bootable floppy)**: Complete hardware exercise across sprites, 4-voice polyphonic PSG sound, Mode 7 256-color RLE decoding, Mode 4 RPG tilemap with smooth wander camera, dual-layer parallax plasma starfield, The Matrix 256-color text code rain, and the newly added *Sonic The Hedgehog: Green Hill Zone* port.
2. **32MB Fullscreen 375-Image Slideshow Engine (`slideshow.hdv`)**: Pure 6502 Direct Block MLI (`$80`) streaming engine displaying 375 Mode 7 ($320 \times 240$ 8bpp) images and 375 custom palettes with continuous 60 Hz VERA VSYNC IRQ background music.
3. **Direct Mode 7 Bitmap On-Screen Display (OSD) Overlay**: High-performance status bar rendered directly into bottom scanlines (Row 29) of Mode 7 VRAM with precomputed zero-noise palette LUTs, sub-13ms image backup/restore, space-free corner badges, and a pure image MUTE mode leaving 232 pixels untouched.
4. **PSG Shadow Register Engine (`PSG_SHADOW`)**: 64-byte RAM shadow mirror restoring active PSG channel frequencies, waveforms, and stereo pans in under 0.1ms upon unmuting, eliminating pitch bends and screeches.
5. **Zero-Crash Cold-Boot & Reboot Safety**: Atomic initialization sequence blanking video and muting PSG before disk loading, guaranteeing 100% reliable system reboots without freezing.
6. **Automatic VERA to Apple II Native Display Return**: Seamless single-monitor auto-switching for AppleWin and physical monitors on demo exit (`VERA_DC_VID = 0` and softswitch restoration).
7. **Zero-Dependency Build Pipeline**: Pure Node.js build system containing an integrated two-pass 6502 assembler (`src/asm6502.mjs`) and an Applesoft BASIC tokenizing compiler (`src/applebasic.mjs`).
8. **Apple2TS & AppleWin Integration**: Registered in Apple2TS Disk Collection (`src/ui/devices/disk/newreleases.ts`) and verified on AppleWin VERA fork.

---

### 3.2 Hardware Architecture & Dual-Port Slot Mapping
VERA registers map into Apple II I/O space at `$C080 + ($10 * Slot)` and Slot ROM space at `$C000 + ($100 * Slot)`:

| Offset | Register Name | Description |
| :--- | :--- | :--- |
| `+$00` | `VERA_ADDR_L` | VRAM Address Bits [7:0] |
| `+$01` | `VERA_ADDR_M` | VRAM Address Bits [15:8] |
| `+$02` | `VERA_ADDR_H` | Bits [3:0]=Address [19:16], Bit 4=DECR, Bits [7:4]=Stride |
| `+$03` | `VERA_DATA0`  | Data Port 0 (Auto-increments per stride) |
| `+$04` | `VERA_DATA1`  | Data Port 1 (Independent VRAM pointer) |
| `+$05` | `VERA_CTRL`   | Bit 0=ADDRSEL, Bit 7=RESET |
| `+$06` | `VERA_IEN`    | Interrupt Enable (VSYNC, Line, Sprite Collisions) |
| `+$07` | `VERA_ISR`    | Interrupt Status Register |
| `+$09` | `VERA_DC_VIDEO` | Display Composer Video Control |
| `+$0A` | `VERA_DC_HSCALE`| Horizontal Scale (128 = 1.0x, 64 = 2.0x) |
| `+$0B` | `VERA_DC_VSCALE`| Vertical Scale (128 = 1.0x, 64 = 2.0x) |
| `+$0C` | `VERA_DC_BORDER`| Border Color Index |
| `+$0D` | `VERA_L0_CONFIG`| Layer 0 Configuration |

#### Dual-Port Slot Probing in Applesoft BASIC (`startup.bas`)
The `STARTUP` script automatically probes Slot 2 (`$C200`) and Slot 4 (`$C400`) by writing and reading back test patterns through `VERA_ADDR_L` (`$C0A0` vs `$C0C0`). It automatically launches the matching slot binary (`SPROUT.BIN` for Slot 2, `SPROUT4.BIN` for Slot 4).

---

### 3.3 7-in-1 Flagship Test Suite (`veratest.po`, 140KB Floppy)

```text
==============================================================================
   VERA FPGA TEST SUITE FOR APPLE II — 7-IN-1 DEMO DISK
==============================================================================
  1. 16-Sprite Bouncing Alien Animation (4bpp, 2x Scaling)
  2. 16-Sprite Demo + 4-Voice Polyphonic Stereo PSG Chiptune Player
  3. Real Rainbow Arc (Mode 7 256-Color Fullscreen 320x240 Bitmap via RLE)
  4. Mode 4 256-Color RPG Tilemap Engine (Centered Castle Wander Camera)
  5. Dual-Layer Parallax Energy Waves (Layer 0 Starfield + Layer 1 Plasma)
  6. The Matrix Digital Code Rain (256-Color Text Mode T256C=1 + Glitch)
  7. Sonic The Hedgehog: Green Hill Zone (Parallax, Sprites, PSG Audio)
==============================================================================
```

1. **Sprite Engine (`sprite.asm` / `SPROUT.BIN` & `SPROUT4.BIN`)**:
   - 16 hardware sprites bouncing smoothly across display boundaries with 2.0x hardware scaling.
   - Demonstrates sprite attribute registers at VRAM `$1FC00..$1FFFF` and pixel pattern RAM at `$10000`.
2. **4-Voice Polyphonic Stereo PSG Engine (`spritesnd.asm` / `SPRSND.BIN`)**:
   - 32-step arcade chiptune sequencer running in pure 6502 assembly.
   - **Voice 1** (`$1F9C0`): 25% Duty Pulse Wave, Left Channel (`0x40`), Lead Melody.
   - **Voice 2** (`$1F9C4`): Sawtooth Wave, Right Channel (`0x80`), Counter-Harmony & Stereo Widening.
   - **Voice 3** (`$1F9C8`): Triangle Wave, Center (`0xC0`), Slap / Disco Bassline.
   - **Voice 4** (`$1F9CC`): White Noise & Percussion, Center (`0xC0`), Kick + Snare + Hi-Hat with dynamic volume envelope decay.
3. **Mode 7 Fullscreen Rainbow Arc (`mode7.asm` / `MODE7.BIN`)**:
   - Displays a $320 \times 240$ 8bpp 256-color true rainbow arc (76,800 bytes).
   - Decompressed in sub-millisecond time from compressed payload using pure 6502 RLE stream decoding.
4. **Mode 4 256-Color RPG Tilemap Engine (`mode4.asm` / `TILEMAP.BIN`)**:
   - 8bpp color depth with $8 \times 8$ tile patterns and large world map.
   - Implements smooth horizontal and vertical scrolling wander camera centered on a castle landscape.
5. **Dual-Layer Parallax Starfield & Plasma Waves (`layer.asm` / `LAYER.BIN`)**:
   - Layer 0: Deep space parallax starfield drifting slowly.
   - Layer 1: High-speed turbulent plasma waves sweeping leftward at 3x speed, demonstrating true hardware multi-layer composition.
6. **The Matrix Digital Code Rain (`matrix.asm` / `MATRIX.BIN`)**:
   - VERA 256-color text mode (`T256C=1`).
   - Asynchronous multi-column green palette cycling with live random Katakana glitch mutations.
7. **Sonic The Hedgehog: Green Hill Zone Port (`sonic.asm` / `SONIC.BIN` & `SONIC4.BIN`)**:
   - Port of ZeroByte's Sega Genesis *Sonic The Hedgehog: Green Hill Zone* demo to Apple II VERA.
   - Dual-layer parallax scrolling: Layer 0 foreground loops continuously while Layer 1 distant mountains/clouds scroll at fractional speed.
   - 4-frame animated running Sonic hardware sprite with rolling ground dips (`Y_DIPS`).
   - Real-time animated sunflower tile swapping at VRAM `$0EB80` and 4-color cycling waterfall palette at `$1FA50`.
   - Authentic 16-channel PSG Green Hill Zone soundtrack driven by 60 Hz VERA VSYNC IRQ.
   - Assets compacted into a contiguous 103-block container (`SONIC.DAT`), streamed via ProDOS MLI in under 1.5 seconds.
   - Fits on 140KB floppy with 27 free blocks remaining.

#### Complete VRAM & Sprite Attribute Clean Reset (`CLR_64K`)
- Implemented high-performance 64KB unrolled block wiper (`CLR_64K`) across Bank 0 and Bank 1 in ~0.5s.
- Wipes all 128 sprite attribute slots (`$1FC00..$1FFFF`, Z-depth=0), completely eliminating ghost sprites and visual glitches when launching demos after sprite-intensive titles (such as *Time Pilot*).
- Silences all 16 PSG channels and blanks video output until setup completes atomically.

#### Automatic VERA to Apple II Native Display Return on Exit
- Added clean video disable (`LDA #$00; STA VERA_DC_VID`) and softswitch restoration to the key-press exit handlers across all seven showcases.
- Applesoft BASIC `startup.bas` disables VERA video (`POKE 49673, 0` for Slot 2, `POKE 50185, 0` for Slot 4) upon entering the menu and exiting to BASIC prompt.
- Causes AppleWin's `IsVideoOutputEnabled()` to return `false`, instantly restoring the native Apple II text screen on single-monitor systems.

---

### 3.4 32MB Fullscreen 375-Image Slideshow Engine (`slideshow.hdv`)

#### 3.4.1 File System Structure
The generated `slideshow.hdv` is an authentic 32 MiB ProDOS 2.4.3 volume named `SLIDESHOW`.
- **Root Directory**: Contains `PRODOS`, `STARTUP`, `SLIDESHOW.BIN`, `SLIDSHW4.BIN`, and `/DATA/`.
- **Subdirectory `/DATA/`**: Uses blocks 150–207 (58 blocks).
  - Block 150: Subdirectory header + first 12 file entries.
  - Blocks 151–207: Remaining entries using strict ProDOS 39-byte directory entries (13 entries per 512-byte block).
  - Registers all **750 files**: `VPAL001.BIN`..`VPAL375.BIN` (512-byte palettes) and `IMG001.BIN`..`IMG375.BIN` (76,800-byte Mode 7 bitmaps).
  - Fully compatible with standard ProDOS directory browsers (e.g. `CAT`, `Filer`).

#### 3.4.2 Direct Block MLI (`$80`) Streaming Architecture
For blistering image load times on 8-bit 6502, `slideshow.asm` bypasses the overhead of standard ProDOS pathname parsing:
- Images are stored contiguously starting at block 6000.
- Each image occupies a fixed 152-block slot:
  - 1 palette block (512 bytes $\rightarrow$ VERA Palette RAM `$1FA00`).
  - 1 image index block.
  - 150 consecutive bitmap blocks ($150 \times 512 = 76,800$ bytes $\rightarrow$ VRAM `$00000..$12BFF`).
- Streams blocks directly from the storage controller into VERA VRAM with zero intermediate memory copy buffers.

#### 3.4.3 Interactive Controls & Dual Status Display
- **Keyboard Navigation**:
  - `Right Arrow` / `Down Arrow` / `Space`: Next image.
  - `Left Arrow` (`$08` Backspace) / `Up Arrow` / `P`: Previous image.
  - `A`: Toggle Auto-Play (default 3-second interval).
  - `R`: Toggle Random Mode + Auto-Play.
  - `N`: Next audio soundtrack.
  - `M`: Toggle audio mute / play.
  - `O`: Toggle Mode 7 graphics On-Screen Display (OSD) overlay.
  - `Esc` / `Q`: Exit cleanly back to Applesoft BASIC menu.
- **Apple II Text Page 1 Dual-Display**:
  - In dual-monitor setups, `slideshow.asm` updates row 24 with `IMG: nnn/375` and `MUSIC: <name>`. When muted, row 24 is cleanly blanked.

#### 3.4.4 Direct Mode 7 Bitmap OSD Overlay & Zero-Artifact Palette LUTs
- **Direct Bitmap Rendering**: Renders status badges directly into Mode 7 bitmap VRAM on Row 29 (bottom 8 scanlines 232..239, VRAM `$12200..$12BFF`).
- **Optimal Palette LUTs**: Precomputed lookup tables (`PAL_FG_TABLE` and `PAL_BG_TABLE`) select the closest white and black color indices for each of the 375 custom palettes.
- **Zero Visual Artifacts**: Eliminates palette overwrite entirely, preventing white specks and noise in user artwork.
- **Instant Restore**: Backs up the original 2,560 bitmap bytes into Apple II RAM at `$5000..$59FF`, restoring in sub-13ms when OSD is toggled OFF (`'O'`).

#### 3.4.5 Space-Free Corner Badges & Pure Image MUTE Mode
- **Dual Corner Badges**: Left badge `MUSIC:<NAME>` (cols 0..11/13/14) and Right badge `IMG:xxx/375` (cols 29..39).
- **Middle Untouched Region**: Completely omits center columns 14..28 (120..136 pixels wide), guaranteeing zero black bar or text obstruction over central picture artwork.
- **Pure Image Mute Mode**: When Muted (`'M'`), the left `MUSIC:` badge is completely suppressed (`LEFT_BADGE_END = 0`), leaving columns 0..28 (**232 pixels wide out of 320, or 72.5% of the total screen width**) as 100% pristine original Mode 7 art.

#### 3.4.6 PSG Shadow Register Table & Instant Unmute Restoration
- **64-Byte RAM Shadow (`PSG_SHADOW`)**: Mirrors all 16 PSG voice writes (frequency, duty cycle, volume, stereo panning).
- **Instant Glitch-Free Unmute**: When toggling un-mute (`'M'`), `RESTORE_PSG_FROM_SHADOW` copies active voice states directly into VERA hardware in under 0.1ms, eliminating pitch distortion, dissonant chords, and screeching.

#### 3.4.7 Cold-Boot & Clean Reboot Initialization
- **Reboot Freeze Elimination**: Entry routine (`START`) blanks VERA video (`VERA_DC_VID = 0`), silences all 16 PSG channels, clears shadows, streams image 1, and only then atomically enables video output (`VERA_DC_VID = $11`) and starts the 60 Hz music IRQ.
- **Continuous 60 Hz Audio**: Music streaming continues without pauses or tempo hesitation across background image disk transfers.

#### 3.4.8 Acoustic Balancing for PSG Audio (`CANYON.ZSM`)
- Scaled noise percussion to 55% and boosted melodic voices to 130% in `slideshow_hdv.mjs`, producing a balanced, punchy acoustic mix.

#### 3.4.9 5-Second Auto-Start Countdown in `startup.bas`
- Selecting option `1` displays navigation controls and automatically starts after 5 seconds or immediately upon any keypress, matching arcade launcher convenience.

---

### 3.5 3-Track X16 ZSM PSG Audio Streaming System
Three Commander X16 ZSM soundtracks (`SB-INTRO`, `CANYON`, and `GREENHILL`) were parsed and converted at build time into pure VERA PSG streams:
- Stripped FM/YM2151 commands, preserving all 16-channel PSG voice registers, pan, frequency, volume, and waveform settings.
- Stored in fixed 600-block slots starting at HDV block 800.
- Streamed through a compact 512-byte buffer at `$4000`.
- Driven by the **VERA VSYNC IRQ at 60 Hz**:
  - Music playback continues uninterrupted during Direct Block MLI disk streaming without tempo hesitation.
  - VERA address registers (`VERA_ADDR_L/M/H`) are strictly saved and restored around each IRQ tick to prevent corruption of the active image loading stride.
  - Switching tracks or exiting automatically clears all 16 PSG channels.

---

### 3.6 Standalone Zero-Dependency Build Architecture
The `veratest` build system requires no external assembler or tool installations beyond Node.js:
- `src/asm6502.mjs`: High-performance two-pass 6502 assembler. Correctly evaluates labels, equates, zero page vs absolute addressing, and injects slot base constants (`VERA_BASE = $C200` or `$C400`).
- `src/applebasic.mjs` & `src/applebasic.inc`: Applesoft BASIC compiler that directly parses plain-text `startup.bas` into native Apple II binary memory-linked token streams (`NextPtr[2] + LineNo[2] + Tokens + 0x00`).
- `build.bat`:
  ```cmd
  build.bat veratest    :: Builds veratest.po & veratest.png
  build.bat slideshow   :: Builds slideshow.hdv & slideshow.png
  build.bat all         :: Builds both targets
  ```

---

### 3.7 Apple2TS & AppleWin Integration
- **Apple2TS**: Registered in `src/ui/devices/disk/newreleases.ts` resolving to GitHub Releases (`latest/download/veratest.po`).
- **AppleWin**: Fully verified on [AppleWin with VERA FPGA support](https://github.com/anomixer/AppleWin). Supports slot auto-probe on Slot 2 and Slot 4, and automatically returns to native Apple II video display upon exiting any showcase.

---

### 3.8 Git Commit History (`veratest`)
```text
5216fe1 (HEAD -> main, origin/main, tag: v0.0.3) feat(v0.0.3): 7-in-1 VERA flagship showcase & 32MB slideshow for Apple2TS and AppleWin
d248872 feat(v0.0.2): 6-in-1 flagship showcases, 32MB 375-image fullscreen slideshow engine, and zero-dependency build system
98304c0 Refactor build system into modular 6502 assembly and Applesoft BASIC architecture
8a2d040 docs: add AGENTS.md development and architecture guide
056478e (chore)README
e259417 Add acknowledgements and credits section to README
```

---

## 4. Project 3: VERA Music Engine & Jukebox (`c:\dev\veramusic`, `veramusic`)

### 4.1 Overview & High-Level Accomplishments
`veramusic` is an end-to-end music synthesis, audio streaming toolchain, and real-time playback system for the Apple II family equipped with an experimental VERA FPGA card in Slot 2 (`$C0A0`) or Slot 4 (`$C0C0`). It delivers studio-quality polyphonic sound and streaming audio previously thought impossible on an unaccelerated 1.02 MHz 6502 Apple II.

In this development session, the project achieved critical audio engineering breakthroughs:
1. **VERA 128KB SRAM Pre-Load Player (`psgvram.asm`)**: Pre-loads entire song streams (e.g. Chopin *Fantaisie-Impromptu*, 68.6 KB) directly into VERA's onboard 128 KB SRAM at startup in ~2.5 seconds. Enables 100% silent, stutter-free playback on standard 140KB 5.25" Disk II floppies with zero drive motor noise and microsecond instantaneous seeking.
2. **16-Voice Polyphonic PSG Grand Piano Additive Synthesis**: Developed a pure acoustic piano model using 100% pure triangle waves (`VERA_WAVE_TRI`, `$80`), completely eliminating synthetic pulse buzz. Features dynamic keyboard voicing separating right-hand melody (vol 48..63) and left-hand accompaniment (vol 36..56), overtone chorusing (+0.35 Hz body resonance), and octave sub-bass foundation layering.
3. **Direct-to-FIFO 8-Bit PCM Streaming (8,010 Hz)**: ProDOS direct disk block MLI (`READ_BLOCK` `$80`) streaming straight into VERA's 4 KB hardware FIFO buffer (`$1F9C0 + $1D`) at rate 21 (8,010.864 Hz). CPU utilization is under 5% on a 1.02 MHz 6502, buffered against drive seek latencies and protected with studio-grade TPDF dither.
4. **Space Debris Pure PCM Transition & 17 Ensoniq DOC Sample Extraction**: Extracted all 17 active instruments from Captain's iconic *Space Debris* MOD into standalone WAVs, implementing ProTracker Effect 9 sample-offset addressing and rendering a pure 8010 Hz PCM stream (`space_debris.pcm`) that preserves authentic analog-filtered bite while saving 80 disk blocks over hybrid formats.
5. **General MIDI Percussion & Michael Jackson's *Beat It* Riff Harmonic Fix**: GM Channel 9 drum synthesis (pitch-swept triangle kick, noise snare/hi-hats), plus resolving a jarring 26-occurrence Note 65 (F5) to Note 66 (F#5) transcription clash in the iconic synthesizer guitar riff to harmonize with the F# minor rhythm foundation.
6. **Smart Trailing Dead Silence Auto-Trim**: Automatic silence truncation with 1.0-second natural release tail in `mid2psg.mjs`, trimming 18.6s of dead silence and saving 2 ProDOS disk blocks on Chopin (reducing runtime to 5:02).
7. **Universal 5-Second Seeking (`[` / `]`), Shadow Mute (`P`/`M`), and Live Stopwatch**: Unified control paradigm across RAM, Disk, and VRAM players with shadow register tracking to prevent lost waveforms upon seeking, accompanied by a live `T: mm:ss.s  V: xx` display.
8. **ProDOS IRQ Vector Integrity & Clean BASIC Exit**: Preserved `OLD_L/OLD_H` at `$03FE/$03FF` to cleanly restore the ProDOS environment upon song completion or user quit (`ESC`/`Q`), returning cleanly via `RTS` to the Applesoft BASIC launcher.
9. **Comprehensive PSG Acoustic Loudness Boost (+20% to +35%)**: Overcame VERA's logarithmic hardware LUT attenuation by raising base volume floors and implementing analog `tanh` soft saturation, boosting classical piano presence to -11.1 dBFS RMS (+2.6 dB) matching modern listening standards.
10. **Dual ProDOS Distribution Targets & Single Clean Commit**: Packaged both a 140KB bootable floppy (`jukebox.po`) and a 32MB bootable hard disk (`jukebox.hdv`) with unified 40-column titles, automated via a zero-dependency build pipeline and consolidated into a clean master commit (`56bc9c0`).

---

### 4.2 Hardware Audio Architecture & VERA Dual-Pipeline (16-Voice PSG + 8010 Hz PCM FIFO)
The Apple II VERA card provides two independent hardware audio engines that mix directly inside the card's 16-bit DAC:

```
                  +----------------------------------------------+
                  |               VERA Audio Engine              |
                  |                                              |
[60Hz VSYNC IRQ] ---> [16-Channel PSG Synthesizer]               |
(Registers $1F9C0-|   4 bytes/voice: freq_lo, freq_hi, ctrl, wave|
 $1F9FF)          |   Pulse, Sawtooth, Triangle, Noise           |---+
                  |   Base clock: 25 MHz / 512 = 48,828.125 Hz   |   |
                  |                                              |   v
                  |                                              | [Hardware] ---> Audio Out
[ProDOS MLI $80] ---> [1-Channel 8-Bit PCM FIFO]                 | [16-Bit  ]      (Slot 2/4)
(Direct Blocks    |   4 KB Hardware FIFO buffer ($1F9C0 + $1D)   | [DAC Sum ]
 to $4000 Buffer) |   Rate register $1E (Rate 21 = 8,010.864 Hz) |---+
                  |   TPDF dithered signed 8-bit mono samples    |
                  +----------------------------------------------+
```

1. **16-Channel Programmable Sound Generator (PSG)**:
   - Memory mapped at `$1F9C0`..`$1F9FF` in VERA address space.
   - 4 bytes per voice: `[freq_lo, freq_hi, ctrl, wave]`.
   - Frequency math: $N = \text{round}(f \times 131,072 / 48,828.125) = \text{round}(f \times 2.68435456)$.
   - `ctrl`: Bit 7 = Right enable, Bit 6 = Left enable, Bits 5:0 = Volume (0..63, logarithmic DAC LUT).
   - `wave`: Bits 7:6 = Waveform (`00` = Pulse with duty cycle in bits 5:0, `01` = Sawtooth, `10` = Triangle, `11` = Noise).
2. **1-Channel 8-Bit Signed PCM FIFO**:
   - Port at `$1F9C0 + $1D` (`VERA_AUDIO_DATA`).
   - 4 KB hardware FIFO absorbs Apple II bus contention and disk seek latencies.
   - Rate register (`VERA_AUDIO_RATE`, `$1E`): Actual Hz = $(\text{rate} / 128) \times 48,828.125 \text{ Hz}$. Setting rate `21` (`$15`) produces exactly **8,010.864 Hz**.
   - Ctrl register (`VERA_AUDIO_CTRL`, `$1C`): Bit 7 = FIFO reset, Bit 5 = stereo/mono (0=mono), Bits 3:0 = volume (0..15).
3. **Absence of Yamaha YM2151 (OPM)**:
   - Unlike the Commander X16, the **Apple II VERA card has no YM2151 FM synthesizer**. All audio must be synthesized via the 16-channel PSG or streamed through the PCM FIFO.

---

### 4.3 VERA 128KB SRAM Pre-Load Player (`psgvram.asm`) — Zero Floppy Noise & Dual-Port Isolation
On real Apple II hardware, streaming audio from a standard 140KB 5.25" Disk II floppy introduces severe acoustic and timing challenges:
- Floppy track seeks take 100–300 ms, producing loud mechanical stepper motor chatter and causing audio FIFO starvation.
- To solve this, `psgvram.asm` loads the entire compressed 60 Hz PSG event stream (Chopin: 68.6 KB, 137 blocks) from disk into VERA's onboard 128KB SRAM (`$00000..$11200`) during boot.
- The pre-load takes only **~2.5 seconds** via ProDOS MLI `READ_BLOCK` (`$80`), after which the disk drive motor turns off completely.

#### Dual-Port Hardware Isolation
During playback, VERA's dual data ports are configured with independent pointers and strides:
- **Port 0 (`VERA_DATA0`)**: Bound to VRAM Stream Read Pointer (`$00000`, Stride +1). At every 60 Hz VSYNC tick, the 6502 reads frame header byte `[count]` and register/value pairs directly from `VERA_DATA0`.
- **Port 1 (`VERA_DATA1`)**: Bound to VERA PSG Register Space (`$1F9C0`, Stride 0). The 6502 pushes decoded register updates directly into `VERA_DATA1` without having to save, change, or restore VRAM address pointers.
- This complete architectural separation eliminates pointer thrashing and achieves execution times of `< 1.2 ms` per 60 Hz frame.

```
                    +------------------------------------+
                    |        VERA 128KB VRAM Space       |
                    |                                    |
Port 0 (DATA0) ---> | $00000 .. $11200: Stream Data      | (Stride = +1)
                    |                                    |
                    +------------------------------------+
                    |     VERA Register / I/O Space      |
                    |                                    |
Port 1 (DATA1) ---> | $1F9C0 .. $1F9FF: PSG Registers    | (Stride = 0)
                    +------------------------------------+
```

#### Stopwatch Tenths Precision & ProDOS IRQ Safety
- **True Divide-by-6 Stopwatch Math**: Replaced crude bit-shifting (`LSR; LSR`) with an exact divide-by-6 subtraction loop. This eliminated ASCII character corruptions (where tenths rendered as `: ; < = >`) and ensured perfectly smooth decimal tenths (`0.0` to `0.9`).
- **ProDOS IRQ Vector Integrity**: At startup (`IRQ_ON`), the existing ProDOS interrupt handler address at `$03FE/$03FF` is saved into `OLD_L/OLD_H`. On completion or user quit (`IRQ_OFF`), the vector is restored before executing `RTS`, preventing system crashes when returning to Applesoft BASIC.

---

### 4.4 Chopin's *Fantaisie-Impromptu*: 100% Pure Acoustic Piano Additive Synthesis
*Fantaisie-Impromptu, Op. 66* features 3,049 notes played at lightning speed with intense damper pedal resonance. Previous multi-waveform attempts (using pulse waves for hammer attack) produced harsh electronic buzzing that sounded like an alien synthesizer lead.

```
Frequency (Hz) | Synthesis Approach
---------------+---------------------------------------------------------
1000 - 4186 Hz | 100% Pure Triangle (VERA_WAVE_TRI, $80), Fast Felt Decay
 200 - 1000 Hz | 100% Pure Triangle, Dynamic Voicing (Vol 48..63)
  65 -  200 Hz | 100% Pure Triangle, Accompaniment Balance (Vol 36..56)
  30 -   65 Hz | Multi-Oscillator Additive Sub-Bass:
               |   - 1f Primary Fundamental (Note + 12 mapped)
               |   - 1f + 0.35 Hz Unison Detuned Body Resonance
               |   - Sub-Octave Fundamental (-12 st, Vol 63)
               |   - 2f Octave Harmonic (Vol 55..58)
```

1. **100% Pure Triangle Waveform Across All Notes**: Every single note from A0 (27.5 Hz) to C7 (2093 Hz) uses `VERA_WAVE_TRI` (`$80`). Non-triangle writes are strictly 0.
2. **Concert Grand Multi-Oscillator Additive Bass**:
   - In VERA's 16-bit DAC, 16 active voices sum together. During sixteenth-note runs, 12–16 voices sound simultaneously. When Chopin struck the climactic solo low C#1 (34.65 Hz at 1:03 and 4:03), a single voice was attenuated by $-24 \text{ dBFS}$ in AppleWin and monitor speakers.
   - We allocate **up to 6 harmonically aligned voices** simultaneously for sub-bass notes (`note < 30`):
     - $1f$ Fundamental (34.65 Hz, Vol 63)
     - $1f + 0.35$ Hz Unison Chorus Body (34.95 Hz, Vol 63)
     - $2f$ Octave Harmonic (69.30 Hz, Vol 58)
     - $2f + 0.45$ Hz Octave Chorus (69.75 Hz, Vol 55)
     - $3f$ 12th Harmonic (103.95 Hz, Vol 50)
   - DAC output power leaps from 2,044 to **14,080 (+17 dB)**.
3. **Sub-Bass Octave Alignment (`note < 36` -> `note + 12`)**:
   - Mapped primary pitch to Octave 2 while layering the sub-octave fundamental (-12 st). Note 25 (C#1) sounds with the same thunderous acoustic projection as the opening C#2 (Note 37) at 0:04.
4. **Classical Dynamic Voicing**:
   - Right-hand melody (`note >= 60`) mapped to **48..63** ($norm^{0.35}$) with 7 frames (~116 ms) attack hold time.
   - Left-hand accompaniment (`note < 60`) mapped to **36..56** ($norm^{0.45}$), providing a lush harmonic cushion that never overwhelms the melody.
5. **Master Dynamic Headroom via Soft Saturation**:
   - Replaced global linear peak attenuation with analog `tanh` soft saturation (reference 3.0 voice headroom). Climax peak energy soared from 4,800 to **27,139 / 32,767 (-1.6 dBFS, +15 dB boost)**, with RMS increasing to **-11.1 dBFS (+2.6 dB, +35% acoustic loudness)**.

---

### 4.5 Direct-to-FIFO 8010 Hz PCM Streaming: *Space Debris* & *The Wellerman*
For complex sampled compositions like *Space Debris* (Captain) and *The Wellerman* (Alexander Nakarada), streaming pre-rendered PCM directly into VERA's hardware FIFO delivers unmatched fidelity:
- **Direct Block MLI Streaming (`pcmstream.asm`)**: Uses ProDOS MLI `READ_BLOCK` (`$80`) to read 512-byte disk blocks sequentially into host buffer `$4000`, feeding VERA's FIFO data port (`$1D`).
- **Zero-Stutter 4KB FIFO Pre-Buffering**: Pre-fills 4 blocks (2,048 bytes, ~250 ms) into the VERA FIFO before starting the 60 Hz timer. Track-to-track seek latencies on hard disks and floppy controllers are completely hidden.
- **TPDF (Triangular Probability Density Function) Dither**: Converted via `wav2pcm.mjs` with TPDF dither, completely eliminating 8-bit harmonic truncation distortion and background quantization noise.
- **Minimal 6502 CPU Overhead**: 8,010 samples/sec translates to ~133 bytes per 60 Hz frame. Pushing bytes into VERA FIFO requires `< 4.5%` CPU time on a 1.02 MHz Apple II, leaving 95% CPU margin free.

---

### 4.6 General MIDI Percussion & Michael Jackson's *Beat It* Guitar Riff Fix
- **General MIDI Channel 9 Percussion Synthesis**:
  - `mid2psg.mjs` maps standard GM drum keys into specialized VERA PSG voice assignments:
    - Acoustic Bass Drum / Kick (Notes 35, 36): Rapid pitch-down swept triangle wave (`VERA_WAVE_TRI`, $120 \to 40 \text{ Hz}$).
    - Snare Drum / Rimshot (Notes 38, 40): White noise burst (`VERA_WAVE_NOISE`, `$C0`) with fast 3-frame exponential volume decay.
    - Closed / Open Hi-Hats, Ride, Crash: High-frequency filtered noise pulses.
- **Harmonic Correction on *Beat It* Riff**:
  - In *Beat It* (`music/BeatIt.mid`), the iconic synthesizer lead riff had an audible harmonic clash: in 26 separate instances across the intro and chorus, the second half of the phrase played Note 65 (F5, natural F).
  - In the song's native F# minor key, this natural F created a dissonant minor-second clash against the root F# rhythm guitar and bassline.
  - Corrected all 26 occurrences of Note 65 to **Note 66 (F#5)**, restoring the punchy, authentic rock timbre of the original record.

---

### 4.7 Smart Trailing Dead Silence Auto-Trim & ProDOS Block Conservation
- MIDI files often contain 15–30 seconds of trailing silence after the last note releases while waiting for sequencer tick markers.
- `tools/mid2psg.mjs` implements an intelligent scan:
  - Tracks the exact frame of the last note-off event.
  - Automatically adds a generous **1.0-second natural release tail** (60 frames) to let lingering damper reverberations decay gracefully to complete silence.
  - Truncates all subsequent dead frames and appends the `$FF` terminator.
- In Chopin's *Fantaisie-Impromptu*, this trimmed **18.6 seconds of dead silence**, reducing runtime from 5:21 down to **5:02**, shaving the file from 71,988 bytes to 71,052 bytes and saving 2 ProDOS disk blocks (now fits within 139 blocks).

---

### 4.8 Universal 5-Second Seeking, Master Volume Scaling & Stopwatch Engine
All four player engines (`psgvram.asm`, `psgstream.asm`, `psgplay.asm`, `pcmstream.asm`) share a standardized control scheme:
- **`]` Fast Forward (+5 Seconds)** / **`[` Rewind (-5 Seconds)**:
  - In 60 Hz PSG streams: Jumps $\pm 300$ frames in memory or disk.
  - In 8,010 Hz PCM streams: Jumps $\pm 78$ ProDOS 512-byte blocks.
  - **Shadow State Preservation**: When seeking across frames, all 64 VERA register writes are applied to the RAM `SHADOW` table. Upon completing the seek, `RESTORE_ALL` immediately pushes the updated frequencies, waveforms, and volumes to VERA hardware. This prevents voices from silencing permanently after seeking.
- **`+` / `-` 16-Level Master Volume Scaling**: Master volume index (0..15) dynamically scales voice amplitudes in real time without altering frequency or envelope states.
- **`P` / `M` Instant Pause & Shadow Mute**: Silences all PSG channels or halts the PCM stream clock, instantly restored upon unpause.
- **Live Stopwatch**: Row 23 live display: `T: mm:ss.s  V: xx`.

---

### 4.9 ProDOS Disk Formats: 140KB Floppy (`jukebox.po`) & 32MB Hard Disk (`jukebox.hdv`)
The build pipeline produces two ready-to-boot ProDOS disk images:

#### 1. Bootable 140KB Floppy (`jukebox.po`)
- Designed for standard 5.25" Disk II drives.
- Track 1: **Melody Demo** (RAM PSG, 0:30)
- Track 2: **Chopin: Fantaisie-Impromptu** (VERA RAM PSG, 5:02, 139 blocks)
- Uses `psgvram.asm` to pre-load Chopin into VRAM at startup; zero disk noise during playback; 44 free blocks remaining on the disk.

#### 2. Bootable 32MB Hard Disk (`jukebox.hdv`)
- Designed for hard disk emulators and CF/IDE cards.
- Track 1: **Melody Demo** (RAM PSG, 0:30)
- Track 2: **Chopin: Fantaisie-Impromptu** (VERA RAM PSG, 5:02)
- Track 3: **Michael Jackson: Beat It** (Stream PSG, 3:58, blocks 2500..3524)
- Track 4: **Captain: Space Debris** (Stream PCM, 5:05, blocks 5000..9786)
- Track 5: **Alexander Nakarada: The Wellerman** (Stream PCM, 2:00, blocks 600..2486)
- Track 6: **Exit to Applesoft BASIC**
- 58,372 free blocks remaining.

---

### 4.10 Standalone Build Toolchain & Zero-Dependency Conversion Pipeline
The build pipeline is automated via `build.bat` and zero-dependency Node.js tools:
- `tools/mid2psg.mjs`: High-precision SMF MIDI to 60 Hz PSG stream compiler with additive grand piano synthesis, dynamic voicing curves, and General MIDI drum synthesis.
- `tools/mod2psg.mjs`: 31-sample ProTracker MOD to PSG converter with tone portamento memory and arpeggio emulation.
- `tools/wav2pcm.mjs`: 16-bit WAV/MP3 to 8,010 Hz 8-bit signed PCM converter with studio TPDF dither and peak normalization.
- `tools/build_jukebox.mjs`: ProDOS directory and raw disk block allocator that packs binaries, menus, and streaming tracks into `.po` and `.hdv` filesystem images.
- **Build Commands**:
  ```cmd
  build.bat quick      :: Re-assembles players & packs jukebox.po / jukebox.hdv (< 3s)
  build.bat jukebox    :: Full clean rebuild of all MIDI/MOD/PCM sources and disk images
  ```

---

## 5. Project 4: VERA SD Sector Editor (`c:\dev\verasdedit`, `verasdedit`)

### 5.1 Overview & High-Level Accomplishments
`verasdedit` is a standalone, PC-Tools-style 6502 hex sector editor designed for the Apple II with a VERA expansion card installed in Slot 2. It communicates directly with the physical or emulated SD/MMC card image over the **VERA SD/MMC SPI interface** (`$C21E`/`$C21F`), completely bypassing standard Apple II disk controllers.

Originally developed inside the [AppleWin](https://github.com/anomixer/AppleWin) repository to exercise and verify emulator-side VERA SPI hardware behavior (`source\VERACard\`), it was subsequently split into its own independent repository (`c:\dev\verasdedit`). It serves as an essential bare-metal diagnostic, recovery, and disk forensic tool.

Key accomplishments:
1. **Direct VERA SPI Hardware Communication**: Issues raw SD command packets (CMD17 for single-block read, CMD24 for single-block write) directly to `$C21E`/`$C21F`. Auto-detects and displays LBA 800 (the standard FAT32 volume boot record) at startup.
2. **PC-Tools Style 80-Column Display**: Full-screen Apple IIe 80-column text UI displaying 512-byte sectors across two pages (256 bytes / 16 rows per page) with offset, hex bytes, and printable ASCII side-by-side.
3. **Dual-State Editor Architecture**: Clean modal separation between **Navigate State** (`IJKM` movement, `TAB` field toggle, `SPACE` page toggle, `L` hex LBA jump, `W` write) and **Edit State** (`0-F` nibble entry, ASCII printable character entry, `CR` accept, `ESC` discard).
4. **Precision Delta Tracking & Visual Highlights**:
   - 32-byte dirty bitmap (`$2F00`, 1 bit per byte) tracking modified bytes against the baseline sector buffer (`ORIGBUF` at `$3400`). Reverting an edit back to its original value automatically clears the dirty bit.
   - Changed bytes render in **inverse video** (`& 0x3F`).
   - The cursor cell continuously **flashes** (`& 0x3F | 0x40`), even when hovering over changed inverse bytes. In the hex column, only the active nibble under the cursor flashes, preserving the inverse rendering of the neighboring nibble.
5. **Rock-Solid ProDOS Integration**: Loads at `$2000` via Applesoft BASIC `STARTUP`, preserves ProDOS interrupt vectors, and returns cleanly to ProDOS via `RTS`/`BYE` upon pressing `Q`.

---

### 5.2 Hardware Architecture & VERA SD/MMC SPI Controller (`$C21E`/`$C21F`)
The VERA card on Apple II exposes an SPI host controller in Slot 2 I/O space at `$C21E` and `$C21F`:

| Address | Symbol | Direction | Description |
| :--- | :--- | :--- | :--- |
| `$C21E` | `VERA_SPI_DATA` | Read / Write | SPI Data Register (writing transmits 8 bits; reading returns received 8 bits) |
| `$C21F` | `VERA_SPI_CTRL` | Read / Write | SPI Control Register: Bit 0 = `/CS` (Chip Select, active low), Bit 1 = Slow Clock |

To read or write an arbitrary 512-byte Logical Block Address (LBA):
- **Command Transmission**: Asserts `/CS` low (`STA $C21F`), transmits a 6-byte command frame (Command index `0x40 | cmd`, 32-bit big-endian LBA argument, and CRC7 byte), and clocks SPI dummy bytes (`$FF`) until the SD card responds with status token `0x00` (R1 response).
- **Data Block Read (CMD17)**: Clocks until the data start token (`0xFE`) is received, reads 512 payload bytes into memory (`$3000..$31FF`), and discards the 16-bit CRC checksum.
- **Data Block Write (CMD24)**: Transmits start token `0xFE`, pushes 512 edited payload bytes over `$C21E`, sends a dummy CRC, checks the data response token (`0x05` = Accepted), and polls the SPI bus until the busy token (`$00`) clears.

---

### 5.3 Dual-State Hex & ASCII Editor Engine
The user interface implements a strict two-tier state machine:

```
                  +-----------------------------------+
                  |          NAVIGATE STATE           |
                  |                                   |
                  |  I / M   : Cursor Up / Down (±16) |
                  |  J / K   : Cursor Left / Right    |
                  |  TAB     : Toggle Hex / ASCII     |
                  |  SPACE   : Toggle Page 1 / Page 2 |
                  |  L       : Enter Hex LBA Input    |
                  |  W       : Write Sector (CMD24)   |
                  |  Q       : Return to ProDOS (RTS) |
                  +-----------------------------------+
                        |                       ^
                        | [E]                   | [CR] Accept / [ESC] Discard
                        v                       |
                  +-----------------------------------+
                  |            EDIT STATE             |
                  |                                   |
                  |  0 - F   : Hex Nibble Input       |
                  |  ASCII   : Printable Char Input   |
                  |  CR      : Accept Edit & Navigate |
                  |  ESC     : Discard Edit & Reload  |
                  +-----------------------------------+
```

- **Case Normalization (`NORMKEY`)**: Navigation command keys accept both uppercase and lowercase (`N`/`n`, `P`/`p`, `R`/`r`, `L`/`l`, `E`/`e`, `W`/`w`, `Q`/`q`). In Edit State, character inputs preserve case sensitivity so lowercase text can be entered as data.
- **W-Key Safety**: In Edit State, typing `'W'` enters the letter `'W'` as data. The write routine only triggers from Navigate State.

---

### 5.4 Apple IIe 80-Column Text Display Interleaving Model
On the Apple IIe, 80-column text mode does not use a contiguous linear video buffer. Instead, it interleaves **Auxiliary Memory** (even columns) and **Main Memory** (odd columns) within the standard Text Page 1 address space (`$0400..$07FF`):
- **Cell Base Formula**: For display row $R$ (0..23), the base address is:
  $$\text{Base}(R) = \$0400 + (R \ \& \ 7) \times \$80 + \lfloor R / 8 \rfloor \times \$28$$
- **Bank Switching (`PUTCH`)**: To print character $C$ at row $R$, column $X$:
  - If $X$ is even: Enables Auxiliary RAM write (`STA $C005`, `RAMWRTON`), writes byte $C$ to `Base(R) + (X >> 1)`.
  - If $X$ is odd: Enables Main RAM write (`STA $C004`, `RAMWRTOFF`), writes byte $C$ to `Base(R) + (X >> 1)`.

---

### 5.5 Critical Hard-Won 6502 Debugging Lessons

#### 5.5.1 Assembler `CPX`/`CPY` Addressing-Mode Bug (Immediate vs Zero Page)
- **Symptom**: Typing `800` in the `[L]` LBA input box sent out-of-range address `FF00FF00` to the SD card, causing "SD Read failed!" and drawing corrupted garbage on screen.
- **Root Cause**: The vendored assembler `asm6502.mjs` had a severe parser bug: it emitted **immediate addressing** (`E0`/`C0`) for every `CPX` and `CPY` instruction, completely ignoring zero-page syntax. When the code executed `CPX ZP_IBUFIDX`, the assembler encoded `E0 72` (comparing X directly to literal value 114) instead of `E4 72` (comparing X to memory contents at `$72`). As a result, the input string parse loop executed the wrong number of iterations.
- **Fix**: Updated `asm6502.mjs` to properly evaluate arguments: emitting `#imm` for literal hashes, `$zp` (`E4`/`C4`) for zero-page addresses/labels, and absolute otherwise.

#### 5.5.2 80-Column Display Init Softswitch Trap (`80STORE OFF`, `PAGE2 OFF`)
- **Symptom**: Enabling 80 columns via `$C00D` resulted in a garbled, completely inverse screen, even though text memory was written correctly.
- **Root Cause**: On the Apple IIe, the 80-column video generator chooses between Page 1 and Page 2 display buffers based on the state of the `PAGE2` softswitch (`$C054`/`$C055`), which is completely decoupled from `RAMWRT`. If `PAGE2` is left ON, the monitor renders Page 2 (`$0800`), showing uninitialized memory.
- **Fix**: Initialization must strictly execute:
  ```assembly
  STA $C00D   ; 80COL ON
  STA $C000   ; 80STORE OFF
  STA $C054   ; PAGE2 OFF (force display to read Page 1 at $0400)
  ```

#### 5.5.3 RAMWRT/RAMRD Banking Leaks & Code/Scratch Buffer Separation (`$2E20`)
- **Symptom**: Editing any byte caused the Apple II to execute corrupted instructions and crash into a `BRK` handler at `$2E02`.
- **Root Cause**:
  1. `PUTCH` continuously toggles `RAMWRT` to interleave characters across Aux/Main memory. Unless explicitly turned off (`STA $C004`), subsequent writes to variables or buffers silently land in Auxiliary RAM.
  2. The 16-byte ASCII row formatting buffer `SCRATCH` was placed at `$2E00`. As features were added, the code grew from 3.1 KB to 3,587 bytes (`$2000..$2E02`). When `DRAW_DATA` executed `STA SCRATCH,Y`, it overwrote the program's trailing `JMP EDIT_LOOP` instruction with sector data, causing the CPU to execute data bytes as opcodes.
- **Fix**:
  - Relocated `SCRATCH` to `$2E20`, safely above the highest assembled code address.
  - Enforced explicit `STA $C004` (`RAMWRTOFF`) before writing internal buffers and `STA $C002` (`RAMRDOFF`) before reading.

#### 5.5.4 Subroutine A-Register Clobbering in Hex Display Modes
- `HEX_DISPMODE` and `ASCII_DISPMODE` used the accumulator as a scratch calculation register. Calling them without preserving the source byte caused the hex display loop to render corrupted numbers. Fixed by always reloading the buffer byte from `($3000),Y` after display mode calls.

#### 5.5.5 Assembler Dropping `label,Y` on `AND`/`ORA` (The 8-Byte Inverse Bug)
- **Symptom**: Editing a single byte caused 8 consecutive bytes (e.g. `00..07` or `08..0F`) to all simultaneously turn inverse.
- **Root Cause**: In the 6502 architecture, `AND`, `ORA`, and `EOR` instructions do **not** support indexed-`Y` addressing (`label,Y` is invalid; only indexed-`X` exists). When `SET_DIRTY_BIT` attempted `ORA BIT_TABLE,Y`, the assembler silently dropped the label and `,Y`, resolving the expression as `ORA $0000` (`0D 00 00`). Because address `$0000` in zero page contained `$FF`, the operation ORed `$FF` into the dirty bitmap byte, setting all 8 bits at once.
- **Fix**: Eliminated the table lookup entirely. Implemented a self-contained shifting `BITMASK` routine:
  ```assembly
  BITMASK:
      LDA #$01
      CPY #$00
      BEQ BM_DONE
  BM_LOOP:
      ASL A
      DEY
      BNE BM_LOOP
  BM_DONE:
      RTS
  ```
  The dirty bit is then set via direct accumulator math without illegal addressing modes.

#### 5.5.6 SD Sector Write Persistence & Emulator `fflush` Synchronization
- **Symptom**: Sectors written via CMD24 in AppleWin appeared updated in memory, but reverting or power-cycling the emulator caused all edits to vanish.
- **Root Cause**: AppleWin's `VERASD::WriteBlock` used standard C runtime `fwrite()` to write modified sector bytes to the disk image file on host Windows. However, it omitted `fflush()`. If the emulator window was closed, the buffered writes were never committed to disk.
- **Fix**: Added explicit `fflush()` immediately following block write operations in `VERACard`.

---

### 5.6 Standalone Zero-Dependency Build Pipeline & ProDOS 2.4.3 Integration
The repository is completely standalone and requires only Node.js (ESM):
- `verasdedit.asm`: 6502 assembly source file (assembled size: 3,588 bytes, load address `$2000`).
- `verasdedit.mjs`: Build script that drives vendored `asm6502.mjs` and `applebasic.mjs`, packaging the compiled binary and `STARTUP` onto a pristine ProDOS 2.4.3 floppy image (`base/ProDOS_2_4_3.po`).
- `build.bat`: Windows one-click build script.
- **Build Output**:
  ```text
  Created verasdedit.po (143,360 bytes)
    VERASDEDIT.BIN: 3588 bytes (load $2000)
    STARTUP: 174 bytes
  ```

---

### 5.7 Git Commit History (`verasdedit`)
```text
14eed58 (HEAD -> master, origin/master) VeraSDEdit: 6502 hex sector editor for VERA SD/MMC SPI (renamed from VeraSDView)
```

---

## 6. Verification Matrix & Cross-Testing Results

| Test Scenario | Target Binary | Environment | Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Zero-Disk Runtime Sound** | `MAIN.BIN` (TimePilot) | Apple2TS & Real HW | All 12 PCM samples resident in VRAM; 0 disk reads during play | **PASS** |
| **4-Voice PSG Opening Theme** | `MAIN.BIN` (TimePilot) | Apple2TS & Real HW | Synchronized Stage 1 announce start; rock-solid 60Hz playback through 435 frames | **PASS** |
| **100% In-Memory Sprite Art** | `MAIN.BIN` (TimePilot) | Apple2TS & Real HW | Complete `art.blob` resident in VRAM Bank 1; zero mid-game disk I/O, no LOADING banner | **PASS** |
| **High Score BGM & Lazy Redraw** | `MAIN.BIN` (TimePilot) | Apple2TS | Rock-solid 60 FPS initials entry cursor blink; 4-voice PSG loop plays at authentic tempo | **PASS** |
| **Multi-Drive / Drive 2 Boot** | `TimePilot-IIvera.hdv` | Apple2TS (S7 D2) | `boot_unit` correctly resolved; zero tile scrambling when running alongside other disks in Drive 1 | **PASS** |
| **Dual-Drive 140KB Floppy Boot** | `TimePilot-IIvera-D1/D2` | Apple2TS (S6 D1/D2) | Boots Disk 1, accesses sound & Slot 4 binary from Disk 2; Disk 1 never accessed after boot | **PASS** |
| **Score Ranking Table (7 Digits)** | `MAIN.BIN` (TimePilot) | Apple2TS | Scores $\ge 100,000$ render fully; units digit aligned under 'G' at Col 16 | **PASS** |
| **Stage 5 Mothership Color** | `MAIN.BIN` (TimePilot) | Apple2TS | Authentic Cyan (`0x00CF`) core/rim, damage alarm flashes Magenta (`0x0C0C`) | **PASS** |
| **Stage Clear Fanfare** | `MAIN.BIN` (TimePilot) | Apple2TS | Authentic CX16 fanfare (PCM); clean transition | **PASS** |
| **Dual-Port Hardware Probe** | `STARTUP` (veratest) | Apple2TS & AppleWin (Slot 2/4) | Correctly identifies active VERA slot and launches matching binary | **PASS** |
| **7-in-1 Flagship Test Suite** | `veratest.po` | Apple2TS & AppleWin | All 7 showcases run smoothly without visual artifacts or memory corruption | **PASS** |
| **Sonic Green Hill Zone Port** | `SONIC.BIN` / `SONIC4.BIN` | Apple2TS & AppleWin | Dual-layer parallax, 4-frame sprite, rolling ground dips, sunflower swapping, 60Hz PSG | **PASS** |
| **Complete VRAM & Ghost Sprite Reset** | `SPROUT.BIN` / `SPRSND.BIN` | Apple2TS & AppleWin | `CLR_64K` clears all 128 sprite attribute slots and 128KB VRAM; zero ghost sprites | **PASS** |
| **Native Display Return on Exit** | All Showcases (veratest) | AppleWin & Apple2TS | `VERA_DC_VID = 0` instantly restores Apple II text screen on single-monitor setups | **PASS** |
| **32MB Direct Block MLI** | `slideshow.hdv` | Apple2TS & AppleWin | 375 images load via MLI $80; continuous 60 Hz VSYNC PSG music plays with zero jitter | **PASS** |
| **Mode 7 Direct Bitmap OSD Overlay** | `slideshow.asm` | Apple2TS & AppleWin | Row 29 corner badges render with precomputed LUTs; 0% palette overwriting | **PASS** |
| **Pure Image MUTE Mode** | `slideshow.asm` | Apple2TS & AppleWin | Mute suppresses left badge; 232 pixels wide (72.5% of screen) pristine untouched art | **PASS** |
| **PSG Shadow Unmute Engine** | `slideshow.asm` | Apple2TS & AppleWin | Unmute restores 16 voices in <0.1ms without pitch bends or screeching | **PASS** |
| **Cold-Boot & Clean Reboot Safety** | `slideshow.asm` | Apple2TS & AppleWin | Blank video + silence PSG on entry prevents lockup across repeated reboots | **PASS** |
| **ProDOS Directory Compatibility** | `slideshow.hdv` | ProDOS Filer / CAT | `/DATA/` lists 750 files (`IMG001..375`, `VPAL001..375`) without errors | **PASS** |
| **VERA SRAM Pre-load Player** | `psgvram.bin` (Chopin) | Apple2TS & Real HW | 68.6KB stream preloaded into VERA SRAM in ~2.5s; 100% silent, stutter-free 140KB floppy playback | **PASS** |
| **Pure Acoustic Piano Timbre** | `psgvram.bin` / `psgstream.bin` | Apple2TS & AppleWin | 100% pure triangle waves; 0 pulse buzz; additive chorus and sub-bass fundamental layering | **PASS** |
| **Piano Loudness & Dynamic Voicing** | `mid2psg.mjs` (Chopin) | Apple2TS & AppleWin | Melody boosted to 48..63; accompaniment balanced to 36..56; RMS boosted +2.6 dB (-11.1 dBFS) | **PASS** |
| **Direct-to-FIFO 8010 Hz PCM Streaming** | `pcmstream.bin` (Space Debris / Wellerman) | Apple2TS & AppleWin | ProDOS direct block MLI ($80) to VERA FIFO ($1D); < 5% 6502 CPU load; TPDF dither | **PASS** |
| **Beat It Guitar Riff Pitch Accuracy** | `STREAMB.BIN` (Beat It) | Apple2TS & AppleWin | 26 instances of Note 65 (F5) transposed to Note 66 (F#5); 0 dissonant clashes against F# bass | **PASS** |
| **Universal 5-Second Seeking & Shadow State** | `[` / `]` across all players | Apple2TS & AppleWin | Instantaneous $\pm$5s seek; shadow registers preserved; zero audio dropouts or muted instruments | **PASS** |
| **Smart Trailing Silence Auto-Trim** | `mid2psg.mjs` (Chopin) | Apple2TS & AppleWin | Trims 18.6s dead silence with 1.0s natural tail; saves 2 ProDOS blocks (139 blocks total) | **PASS** |
| **Stopwatch Tenths Display Math** | `psgvram.bin` / all players | Apple2TS & AppleWin | True divide-by-6 loop eliminates `: ; < = >` characters; smooth, accurate tenths display | **PASS** |
| **ProDOS Clean Exit & IRQ Restoration** | `psgvram.bin` / all players | Apple2TS & AppleWin | Restores `OLD_L/OLD_H` vector at `$03FE/$03FF`; silences PSG; clean RTS return to Applesoft BASIC | **PASS** |
| **Dual-Slot VERA Auto-Probe** | `startup.bas` / `startup_po.bas` | Apple2TS & AppleWin (Slot 2/4) | Auto-detects Slot 2 (`$C0A0`) vs Slot 4 (`$C0C0`) scratch register and loads corresponding binary | **PASS** |
| **VERA SD SPI Direct Read** | `VERASDEDIT.BIN` | AppleWin & Real HW | Successfully mounts SD image via `$C21E/$C21F`; reads LBA 800 (FAT32 boot sector) | **PASS** |
| **80-Column Hex/ASCII Display** | `VERASDEDIT.BIN` | AppleWin & Real HW | Interleaved AUX/MAIN text rendering; 0 display corruption with `80STORE`/`PAGE2` OFF | **PASS** |
| **SD Sector Write (CMD24) & Persistence** | `VERASDEDIT.BIN` | AppleWin & Real HW | Modified sectors write back over SPI via CMD24; changes persist across power cycles | **PASS** |
| **Dirty Tracking & Inverse/Flash Display** | `VERASDEDIT.BIN` | AppleWin & Real HW | True delta against `ORIGBUF`; changed bytes inverse; active cursor cell & nibble flash | **PASS** |
| **Assembler Zero Page `CPX`/`CPY`** | `asm6502.mjs` (verasdedit) | Build Node.js test | Emits `E4`/`C4` for zero-page labels; LBA parsing hex input resolves 100% accurately | **PASS** |
| **Code/Scratch Buffer Separation** | `VERASDEDIT.BIN` | AppleWin & Real HW | `SCRATCH` at `$2E20` cleanly separated from code end (`$2E02`); 0 code smashing on edit | **PASS** |

---

## 7. Baseline State for Starting a New Session

When starting a new session, the development environment is in a completely stable, clean state:

1. **All Four Repositories Synchronized**:
   - `c:\dev\Time-Pilot\TimePilot-IIvera`: Commit `a7fa28c` (Tag `v1.9-iivera`, 1 commit ahead of upstream `0870564`), working tree clean.
   - `c:\dev\veratest`: Commit `0e493f7` on `main`, working tree clean.
   - `c:\dev\veramusic` (`c:\dev\veramus`): Commit `56bc9c0` on `master` (synced with `origin/master`), working tree clean.
   - `c:\dev\verasdedit`: Commit `14eed58` on `master` (synced with `origin/master`), working tree clean.
2. **Build Outputs Generated & Verified**:
   - `TimePilot-IIvera.hdv` (800KB bootable hard disk image ready to run)
   - `TimePilot-IIvera-D1.po` (140KB bootable floppy Disk 1 ready to run)
   - `TimePilot-IIvera-D2.po` (140KB bootable floppy Disk 2 ready to run)
   - `TimePilot-IIvera-v1.9.zip` (230KB all-in-one distribution archive)
   - `veratest.po` (140KB bootable floppy image ready to run)
   - `veratest.png` (560x384 preview screenshot for Apple2TS Disk Collection)
   - `slideshow.hdv` (32MB bootable hard disk image ready to run)
   - `slideshow.png` (560x384 preview screenshot for Slideshow Showcase)
   - `jukebox.po` (140KB bootable floppy image with VERA SRAM pre-load player)
   - `jukebox.hdv` (32MB bootable hard disk image with full 5-track lineup)
   - `psgvram.bin` / `psgvram4.bin` (VERA SRAM pre-load player binaries)
   - `psgstream.bin` / `psgstream4.bin` (MLI direct block stream PSG player binaries)
   - `psgplay.bin` / `psgplay4.bin` (Host RAM-resident PSG player binaries)
   - `pcmstream.bin` / `pcmstream4.bin` (Direct block stream PCM player binaries)
   - `verasdedit.po` (140KB bootable floppy image with full 6502 hex editor)
   - `VERASDEDIT.BIN` (3.5KB binary, load `$2000`)
3. **Documentation Current**:
   - `Time-Pilot\TimePilot-IIvera\README.md` (Bilingual English & Traditional Chinese, CMake + Python pipeline)
   - `Time-Pilot\TimePilot-IIvera\AGENTS.md` (Updated with CMake pipeline, memory map, and ProDOS gotchas)
   - `veratest\README.md` & `veratest\AGENTS.md` (Complete architectural, hardware & build reference through Release v0.0.3)
   - `veramusic\README.md` & `veramusic\AGENTS.md` (Complete audio synthesis, streaming, and player reference through Milestone 22)
   - `verasdedit\AGENTS.md` (Complete 6502 hex editor architecture and VERA SD SPI debugging lessons)
   - `c:\dev\veratest\docs\vera-session.md` (This master document, updated through September 12, 2026)




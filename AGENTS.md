# VERA Test Demo for Apple II — Developer & Agent Guide

This document serves as the comprehensive architectural reference, hardware specification, and development history for the **`veratest`** repository.

---

## 📖 1. Project Overview

- **Repository**: [https://github.com/anomixer/veratest](https://github.com/anomixer/veratest)
- **Target Platform**: Apple II computers (Apple IIe, Apple IIgs, Laser 128), [Apple2TS](https://apple2ts.com) web emulator, and [AppleWin](https://github.com/anomixer/AppleWin) emulator.
- **Hardware Target**: VERA (Versatile Embedded Retro Adapter) FPGA Expansion Card installed on **Slot 2** (`$C200`) or **Slot 4** (`$C400`).
- **Build Output**:
  - `veratest.po` (140KB ProDOS 2.4.3 bootable disk image)
  - `veratest.png` (560x384 preview screenshot for Apple2TS Disk Collection)
  - `slideshow.hdv` (32MB 375-image fullscreen Mode 7 hard disk image)
  - `slideshow.png` (560x384 preview screenshot for Slideshow Showcase)

---

## ⚙️ 2. VERA Hardware Architecture on Apple II

### 2.1 I/O Slot Mapping
The VERA registers map to the Apple II Slot I/O space at `$C080 + ($10 * Slot)` or Slot ROM space `$C000 + ($100 * Slot)`:

| Offset | Register Name | Description |
| :--- | :--- | :--- |
| `+$00` | `VERA_ADDR_L` | VRAM Address Bits [7:0] |
| `+$01` | `VERA_ADDR_M` | VRAM Address Bits [15:8] |
| `+$02` | `VERA_ADDR_H` | Bits [3:0]=Address [19:16], Bit 4=DECR, Bits [7:4]=Auto-Increment Stride |
| `+$03` | `VERA_DATA0`  | Data Port 0 (Auto-increments according to stride) |
| `+$04` | `VERA_DATA1`  | Data Port 1 |
| `+$05` | `VERA_CTRL`   | Bit 0=ADDRSEL (0=Port 0, 1=Port 1), Bit 7=RESET |
| `+$06` | `VERA_IEN`    | Interrupt Enable Register |
| `+$07` | `VERA_ISR`    | Interrupt Status Register |
| `+$08` | `VERA_IRQLINE_L` | Scanline IRQ Target [7:0] |
| `+$09` | `VERA_DC_VIDEO`  | DC Video Control (Bit 7=Current Field, Bits 6:5=Output, Bit 3=Layer 1, Bit 2=Layer 0, Bit 0=Sprites) |
| `+$0A` | `VERA_DC_HSCALE` | Horizontal Subsampling Scale (128 = 1.0x, 64 = 2.0x) |
| `+$0B` | `VERA_DC_VSCALE` | Vertical Subsampling Scale (128 = 1.0x, 64 = 2.0x) |
| `+$0C` | `VERA_DC_BORDER` | Border Color Index (0..255) |
| `+$0D` | `VERA_L0_CONFIG` | Layer 0 Configuration & Color Mode |
| `+$0E` | `VERA_L0_MAPBASE`| Layer 0 Tilemap Base Address |
| `+$0F` | `VERA_L0_TILEBASE`| Layer 0 Tile/Bitmap Base Address & Dimension |

### 2.2 VRAM Memory Map (128 KB)
- `$00000 - $12BFF`: Mode 7 256-Color Fullscreen Bitmap Buffer ($320 \times 240$ 8bpp = 76,800 bytes).
- `$00000 - $00FFF`: Tilemap Buffer for Mode 4 and Text Modes.
- `$08000 - $09FFF`: Tile Pattern Graphics and Custom Fonts.
- `$10000 - $1F7FF`: 8bpp Tile Graphics & Sprite Pixel Graphics Patterns.
- `$1F9C0 - $1F9FF`: 16-Channel Programmable Sound Generator (PSG) Registers.
- `$1FA00 - $1FBFF`: 256-Color Palette (512 bytes, 12-bit Little-Endian RGB: `[G4 B4] [0 R4]`).
- `$1FC00 - $1FFFF`: 128 Sprite Attribute Entries (8 bytes per sprite $\times$ 128 = 1024 bytes).

---

## 🎵 3. 4-Voice Stereo Polyphonic PSG Chiptune Engine

The sound demo in `SPRSND.BIN` runs a 32-step arcade chiptune engine written in pure 6502 assembly:

| Voice | VRAM Address | Waveform | Stereo Panning | Role & Sound Design |
| :--- | :--- | :--- | :--- | :--- |
| **Voice 1** | `$1F9C0` | 25% Duty Pulse Wave | Left Channel (`0x40`) | Lead Melody with vibrant chiptune resonance |
| **Voice 2** | `$1F9C4` | Sawtooth Wave | Right Channel (`0x80`) | Counter-Harmony & Stereo Widening |
| **Voice 3** | `$1F9C8` | Triangle Wave | Center (`0xC0`) | Punchy Slap / Disco Bassline |
| **Voice 4** | `$1F9CC` | White Noise & Percussion | Center (`0xC0`) | Kick Drum + Snare Noise + Hi-Hats with dynamic volume envelope decay |

---

## 🛠️ 4. Build System & Modular Architecture

The project uses a pure Node.js zero-dependency, fully modular build architecture:

```bash
# Build 140KB floppy disk & preview
build.bat veratest
# Build 32MB hard disk image & preview
build.bat slideshow
# Build both images
build.bat all
```

### 4.1 Project Directory Structure
```text
veratest/
├── veratest.po                # 140KB ProDOS 2.4.3 bootable disk image
├── veratest.png               # 560x384 preview screenshot for Apple2TS Disk Collection
├── slideshow.hdv              # 32MB 375-image fullscreen Mode 7 hard disk image
├── slideshow.png              # 560x384 preview screenshot for Slideshow Showcase
├── assets/                    # Self-contained ProDOS 2.4.3 and 32MB blank disk images
└── src/
    ├── asm6502.mjs            # Standalone two-pass 6502 assembler
    ├── applebasic.mjs         # Standalone Applesoft BASIC compiler
    ├── applebasic.inc         # Applesoft BASIC token table
    ├── vera.inc               # VERA register offsets and Apple II hardware softswitches
    │
    ├── veratest/              # 🎮 7-in-1 Flagship Test Suite & Showcase
    │   ├── veratest.mjs       # 140KB ProDOS 2.4.3 floppy builder & PNG renderer
    │   ├── startup.bas        # Applesoft BASIC dual-port hardware probe and menu script
    │   ├── sprite.asm         # 16-Sprite 4bpp crystal alien bouncing animation
    │   ├── spritesnd.asm      # 16-Sprite + 4-Voice stereo PSG chiptune audio player
    │   ├── mode7.asm          # Mode 7 256-color fullscreen bitmap with 6502 RLE decompressor
    │   ├── mode4.asm          # Mode 4 256-color RPG tilemap engine with centered castle wander camera
    │   ├── layer.asm          # Dual-Layer parallax starfield & high-speed plasma storm
    │   ├── matrix.asm         # The Matrix digital code rain with 256-color palette cycling
    │   ├── sonic.asm          # Sonic The Hedgehog Green Hill Zone dual-layer engine with PSG music player
    │   ├── build_sonic_dat.mjs# Sonic asset packager, palette builder, and ZSM converter
    │   ├── sonic.dat          # Compacted 103-block Sonic asset container
    │   ├── mode4-*.bin        # Mode 4 palette and tilemap binary assets
    │   ├── rainbow_rle.mjs    # Mode 7 rainbow pattern generator and RLE compressor
    │   └── preview.mjs        # 560x384 PNG preview screenshot generator
    │
    └── slideshow/             # 🖼️ 32MB Fullscreen 375-Image Slideshow Engine
        ├── slideshow.asm      # Pure 6502 Direct Block MLI ($80) streaming engine
        ├── startup.bas        # Interactive Applesoft BASIC menu script
        ├── slideshow_hdv.mjs  # 32MB hard disk image volume generator & PNG renderer
        ├── preview.mjs        # 560x384 PNG preview screenshot generator
        └── data/              # 375 Mode 7 images (IMG001~375) and 375 palettes (VPAL001~375)
```

### 4.2 Key Technical Achievements:
1. **Dedicated 6502 Assembler Module (`src/asm6502.mjs`)**:
   - Two-pass assembler guaranteeing identical byte-length calculations between symbol resolution and code emission.
   - Supports standard assembly comments (`;` and `//`), equate definitions (`EQU`, `=`), and hex data formats (`HEX`, `!byte`, `.byte`).
   - Dynamically injects slot base constants (`VERA_BASE = $C200` or `$C400`) from `src/vera.inc`.
2. **Dedicated Applesoft BASIC Compiler (`src/applebasic.mjs`)**:
   - Parses plain-text `startup.bas` directly into native Apple II binary memory-linked format (`NextPtr[2] + LineNo[2] + Tokens + 0x00`).
   - Strips non-string whitespace (`$20`) matching native Apple II ROM tokenizer behavior, eliminating syntax errors.
3. **ProDOS 2.4.3 File System Engine & Direct Block MLI (`$80`) Streaming**:
   - Formats standard 140KB floppy and 32MB hard disk images with Volume Headers and Block Allocation Bitmaps.
   - Direct Block MLI (`$80`) engine in `slideshow.asm` directly streams consecutive 512-byte sectors from disk blocks into VERA VRAM without pathname parsing or file buffer overhead.
4. **Applesoft BASIC `STARTUP` Programs**:
   - Dual-port signature probing across Slot 2 and Slot 4.
   - Automatically executes corresponding Slot 2 or Slot 4 binary routines.

### 4.3 Slideshow ProDOS Layout

The generated `slideshow.hdv` is a bootable 32 MiB ProDOS 2.4.3 volume named `SLIDESHOW`. Its root directory contains the system files, `STARTUP`, `SLIDESHOW.BIN`, `SLIDSHW4.BIN`, and the standard `/DATA/` subdirectory. `/DATA/` contains 750 registered files. The 375-image set combines the original `DATA` 75 images with the first 300 images from `DATA-EXTENDED`:

- `VPAL001.BIN`–`VPAL375.BIN`: 512-byte VERA palettes.
- `IMG001.BIN`–`IMG375.BIN`: 76,800-byte ($320 \times 240$) Mode 7 bitmap files.

The `/DATA/` directory uses blocks 150–207 (58 blocks). Block 150 contains the subdirectory header plus the first 12 entries; blocks 151–207 contain the remaining entries, using the ProDOS 39-byte entry length and 13 entries per block. This alignment is important for CAT and other ProDOS directory browsers.

For playback speed, the image payloads use a fixed contiguous layout beginning at block 6000. Each 152-block slot contains one palette block, one image index block, and 150 consecutive bitmap blocks. `slideshow.asm` reads the palette and bitmap blocks with ProDOS Direct Block MLI `$80`, then streams them to VERA without pathname parsing or a large file buffer.

Three X16 ZSM soundtracks (`SB-INTRO`, `CANYON`, and `GREENHILL`) are converted at build time to individual VERA PSG streams, in that order. The converter follows the ZSM command widths, including batched YM2151 writes and extension commands, while omitting non-VERA FM/extension data. Fixed 600-block music slots begin at HDV block 800 and are streamed through a single 512-byte buffer at `$4000`; the image area begins at block 6000. The player advances the active stream from the VERA VSYNC IRQ at approximately 60 Hz, including while image blocks are being copied, so image loading does not alter the music tempo. `N` selects the next soundtrack, EOF advances to the next soundtrack (or a random soundtrack in Random mode), switching tracks clears the PSG first, VERA address registers are preserved around each music tick, all PSG channels are cleared on exit, and `M` toggles mute.

The source archive contains additional ZSM files, but they are intentionally excluded from this port because they are FM-only or not reliably audible through the Apple II VERA PSG path. The packaged playlist is limited to the three tested tracks above.

Auto-play is enabled by default with a three-second interval. The launcher displays the slideshow controls after option `1` is selected and automatically launches after 5 seconds or upon any keypress. Slideshow controls are Right/Down (Space is also supported) for next, Left/Up (or `P`) for previous, `N` for next soundtrack, `A` for auto-play, `R` for random mode plus auto-play, `O` to toggle the Layer 1 on-screen display (OSD) status bar, `M` for mute/playback, and `Esc`/`Q` to return to BASIC. On Apple II, the left arrow is reported as key code `$08` (Backspace).

Dual status reporting is provided for both single-monitor and multi-monitor setups:
- The slideshow binary writes the current image as `IMG: nnn/375` to Apple II text page 1 (row 24) and `MUSIC: <name>` to the bottom-left.
- In graphics mode, the OSD status bar is rendered directly onto the bottom 8 scanlines of the Mode 7 bitmap (Row 29, scanlines 232..239, VRAM `$12200..$12BFF`): `MUSIC: <NAME>    [MODE]   IMG: nnn / 375`. Precomputed palette LUT tables (`PAL_FG_TABLE` and `PAL_BG_TABLE`) pick optimal white text and black background color indices for each of the 375 custom palettes with 0% palette overwriting and 0% visual noise. When OSD is toggled OFF with `'O'`, the original 2,560 bitmap bytes backed up at RAM `$5000..$59FF` are restored into VRAM in ~12ms.
- In `CANYON.ZSM`, PSG channels are acoustics-balanced (noise percussion attenuated to 55%, melodic voices boosted to 130%) to ensure balanced volume between rhythm and lead.

---

## 🚀 5. Integration with Apple2TS

- **Disk Collection Entry**: Registered in `src/ui/devices/disk/newreleases.ts`.
- **Download URL**: Always resolves to the latest GitHub Release asset:
  ```text
  https://github.com/anomixer/veratest/releases/latest/download/veratest.po
  ```
- **Zero Repo Bloat**: The disk image lives in `anomixer/veratest` releases; Apple2TS repository remains completely lightweight.

---

## 📜 6. Development Log & Milestones

1. **Initial VERA Core Verification**: Created basic 6502 test harness for VERA registers, dual data ports, and palette loading.
2. **Sprite Bouncing Engine**: Built 16-sprite 4bpp bouncing animation with 2x hardware scaling.
3. **Instant RLE Mode 7 Arc**: Implemented 256-color true rainbow arc with sub-millisecond 6502 RLE decompressor.
4. **4-Voice Polyphonic Sound**: Engineered full PSG chiptune player with stereo panning and dynamic envelope decay.
5. **Standalone Repository**: Extracted build tool into `anomixer/veratest` with GitHub Actions and release distribution.
6. **PR #395 Submission**: Opened upstream Pull Request to `ct6502/apple2ts`.
7. **Full Modular Architecture Refactoring**:
   - Extracted 6502 assembly sources into standalone files (`src/sprite.asm`, `src/spritesnd.asm`, `src/mode7.asm`, `src/vera.inc`).
   - Extracted Applesoft BASIC menu into human-readable plain-text `src/startup.bas` with token definitions `src/applebasic.inc`.
   - Modularized 6502 assembler and BASIC tokenizer engines into `src/asm6502.mjs` and `src/applebasic.mjs`.
   - Streamlined `build.mjs` into a lean, readable pipeline script.
8. **Release v0.0.2: 6-in-1 Flagship Showcase Expansion**:
   - Mode 4 256-Color RPG Tilemap Engine (`TILEMAP.BIN` / `TILEMAP4.BIN`) with 8bpp color depth and centered castle wandering camera.
   - Dual-Layer Parallax Scrolling (`LAYER.BIN` / `LAYER4.BIN`) with discrete deep space starfield on Layer 0 and 3x high-speed plasma waves on Layer 1.
   - The Matrix Digital Code Rain (`MATRIX.BIN` / `MATRIX4.BIN`) using 256-color text mode (`T256C=1`), multi-track asynchronous palette cycling, and live Katakana glitch mutations.
   - Seamless BASIC menu navigation with text speed restoration (`$F1=255`).
9. **32MB ProDOS 2.4.3 Hard Disk Slideshow Showcase (`slideshow.hdv`)**:
   - Ported 375 Mode 7 ($320 \times 240$ 8bpp) fullscreen images and 375 custom palettes from Commander X16.
   - Built full ProDOS file system structure with `/DATA/` subdirectory registering all 750 image and palette files (`IMG001`~`375`, `VPAL001`~`375`), fully readable in standard ProDOS file browsers.
   - Pure 6502 assembly ProDOS MLI Direct Block (`$80`) streaming engine (`src/slideshow/slideshow.asm`) with interactive keyboard controls (Space/Arrows=Next/Prev, A=Auto, R=Random, ESC=Exit) and zero-flicker palette transitions.
   - Self-contained build script (`src/slideshow/slideshow_hdv.mjs`) and 560x384 preview generator (`src/slideshow/preview.mjs`).
10. **Sprite Demos Complete VRAM & Attribute Clean Reset (`sprite.asm` / `spritesnd.asm`)**:
    - Eliminated ghost sprites and visual artifacts when launching Sprite Demo 1 and Demo 2 after running sprite-intensive titles (such as *Time Pilot*).
    - Blanked display composer (`VERA_DC_VID = 0`), disabled residual layers (`L0_CFG = 0`, `L1_CFG = 0`), and reset border color.
    - Implemented high-performance 64KB unrolled block wiper (`CLR_64K`) to completely zero out all 128 KB of VRAM across Bank 0 and Bank 1 in ~0.5s:
      - Wiped all 128 sprite attribute slots (`$1FC00..$1FFFF`) to `Z-depth = 0`, permanently disabling uninitialized sprites 16..127.
      - Wiped entire 64KB sprite pattern and VRAM data space, eliminating residual pixel art.
      - Silenced all 16 PSG sound generator channels (`$1F9C0..$1F9FF`) and cleared 256 palette registers (`$1FA00..$1FBFF`).
    - Atomically enabled video (`VERA_DC_VID = $41`) only after full VRAM wipe, palette load, sprite 0..15 setup, and pattern upload.
11. **Automatic VERA to Apple II Native Display Return on Exit (`startup.bas` & All Showcases)**:
    - Implemented seamless single-monitor auto-switching compatibility for AppleWin and Apple II video monitors.
    - Added clean video disable (`LDA #$00; STA VERA_DC_VID`) to the key-press exit handlers across all six showcases (`sprite.asm`, `spritesnd.asm`, `mode7.asm`, `mode4.asm`, `layer.asm`, `matrix.asm`).
    - Added key-press pause to `mode7.asm` so users can view the rainbow arc before returning to BASIC.
    - Updated Applesoft BASIC `startup.bas` to enforce VERA video disable (`POKE 49673, 0` for Slot 2, `POKE 50185, 0` for Slot 4) upon entering the menu and exiting to BASIC prompt, causing AppleWin's `IsVideoOutputEnabled()` to return `false` and instantly restore the Apple II text screen.
12. **Release v0.0.3: 7-in-1 Flagship Showcase & Sonic Green Hill Zone Port (`sonic.asm` / `sonic.dat`)**:
    - Ported ZeroByte's Sega Genesis *Sonic The Hedgehog: Green Hill Zone* demo to the Apple II VERA expansion card.
    - Implemented dual-layer parallax scrolling with fractional background speed, Sonic running 4-frame hardware sprite animation with rolling ground bobbing dips (`Y_DIPS`), 4-color cycling water palette at `$1FA50`, and real-time sunflower VRAM tile swapping at `$0EB80`.
    - Integrated 60 Hz VERA VSYNC IRQ driving authentic 16-channel PSG Green Hill Zone polyphonic chiptune audio.
    - Compacted all assets, palette, and PSG stream into a contiguous 103-block container (`SONIC.DAT`), streamed via ProDOS MLI in 512-byte blocks into VERA VRAM in under 1.5 seconds.
    - Fits comfortably on the 140KB floppy disk with 27 free blocks remaining, zero corruption to Apple II Zero Page or system vectors, and instantaneous text screen restoration on exit.
13. **Direct Mode 7 Bitmap OSD Overlay, 5s Auto-Launcher & CANYON Volume Rebalance (`slideshow.asm` / `startup.bas` / `slideshow_hdv.mjs`)**:
    - Engineered high-performance graphics-mode On-Screen Display (OSD) overlay rendered directly into Mode 7 bitmap VRAM on Row 29 (bottom 8 scanlines, VRAM `$12200..$12BFF`).
    - Row 29 displays a crisp 40-column status bar: `MUSIC: <NAME>    [MODE]   IMG: nnn / 375` (supporting `[AUTO]`, `[RANDOM]`, `[MANUAL]`, and `[MUTED]`).
    - Precomputed optimal FG (white) and BG (black) palette LUTs (`PAL_FG_TABLE` & `PAL_BG_TABLE`) across all 375 custom palettes, ensuring 0% palette overwriting and eliminating white speckle noise artifacts.
    - Saves the original 2,560 bitmap bytes into Apple II RAM `$5000..$59FF` on load, allowing instant sub-13ms restoration on OSD toggle OFF (`'O'`), and sub-23ms rendering on OSD toggle ON.
    - Enhanced `startup.bas` launcher with a 5-second auto-countdown or immediate keypress bypass upon selecting option `1`, matching Time Pilot single-monitor launcher behavior.
    - Rebalanced `CANYON.ZSM` PSG audio: scaled noise percussion to 55% and boosted melodic voices to 130% in `slideshow_hdv.mjs` compiler for a balanced, punchy acoustic mix.
14. **Corner OSD Badges, PSG Shadow Unmute Engine & Text Mode [MUTE] (`slideshow.asm` / `slideshow_hdv.mjs`)**:
    - Fixed HDV `slotBase` 1-off image indexing mismatch in `slideshow_hdv.mjs` (`i * 152` vs `(i - 1) * 152`), perfectly aligning image palettes with `palette_lut.inc` and guaranteeing crisp white text across all 375 custom palettes.
    - Redesigned Row 29 OSD to render dual corner badges (left badge cols 0..15: `MUSIC: <NAME>`, right badge cols 26..39: `IMG: nnn / 375`), completely skipping center columns 16..25 (80 pixels) to preserve central image art (e.g. swan feathers) without any black bar obstruction.
    - Engineered 64-byte RAM shadow register table (`PSG_SHADOW`) mirroring all 16 PSG voice writes. When unmuting (`'M'`), `RESTORE_PSG_FROM_SHADOW` instantly restores all voice frequencies, waveforms, volumes, and stereo pans to VERA hardware in under 0.1ms, eliminating dropped notes, dissonant buzzing, and pitch distortion.
15. **Ultra-Compact OSD, Clean Reboot Initialization & Pure Image Mute Mode (`slideshow.asm` / `startup.bas`)**:
    - Compacted OSD strings to space-free formatting: left badge `MUSIC:<NAME>` (cols 0..11/13/14) and right badge `IMG:xxx/375` (cols 29..39), expanding the middle untouched picture region to 120..136 pixels wide.
    - Restructured entry initialization (`START`): blanks VERA video (`VERA_DC_VID = 0`), silences all 16 PSG channels (`SILENCE_PSG`), clears shadows, loads image 1, and only then atomically turns on video output (`VERA_DC_VID = $11`) and enables 60 Hz music IRQ, completely resolving reboot freeze.
    - Preserved continuous 60 Hz music streaming across background image copy without pauses or stutter.
    - When Muted (`'M'`), the left `MUSIC:` badge is completely suppressed (`LEFT_BADGE_END = 0`), leaving columns 0..28 (232 pixels wide out of 320!) as 100% untouched original Mode 7 artwork, while blanking row 24 in Apple II text mode.




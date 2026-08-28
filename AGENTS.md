# VERA Test Demo for Apple II — Developer & Agent Guide

This document serves as the comprehensive architectural reference, hardware specification, and development history for the **`veratest`** repository.

---

## 📖 1. Project Overview

- **Repository**: [https://github.com/anomixer/veratest](https://github.com/anomixer/veratest)
- **Target Platform**: Apple II computers (Apple IIe, Apple IIgs, Laser 128) and [Apple2TS](https://apple2ts.com) web emulator.
- **Hardware Target**: VERA (Versatile Embedded Retro Adapter) FPGA Expansion Card installed on **Slot 2** (`$C200`) or **Slot 4** (`$C400`).
- **Build Output**:
  - `veratest.po` (140KB ProDOS 2.4.3 bootable disk image)
  - `veratest.png` (560x384 preview screenshot for Apple2TS Disk Collection)

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
- `$10000 - $1F7FF`: Sprite Pixel Graphics Patterns (16x16 4bpp Crystal Alien).
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

## 🛠️ 4. Build System & Modular Architecture (`src/` & `build.mjs`)

The project uses a pure Node.js zero-dependency, fully modular build architecture:

```bash
# Build the ProDOS disk image and preview screenshot
npm run build
# or
node build.mjs
```

### 4.1 Project Directory Structure
```text
veratest/
├── build.mjs             # Ultra-lean build pipeline (~160 lines): orchestrates assembly, builds ProDOS, renders PNG
├── veratest.po           # 140KB ProDOS 2.4.3 bootable disk image
├── veratest.png          # 560x384 preview screenshot for Apple2TS Disk Collection
└── src/
    ├── asm6502.mjs       # [Standalone 6502 Assembler Engine] Two-Pass, labels, addressing modes, instruction encoder
    ├── applebasic.mjs    # [Standalone Applesoft BASIC Compiler] Tokenizer & memory-linked binary compiler
    ├── applebasic.inc    # Applesoft BASIC keyword token definitions ($80 ~ $EA)
    ├── startup.bas       # [Plain-text] Human-readable Applesoft BASIC startup menu & hardware probe script
    ├── vera.inc          # VERA register offsets and Apple II hardware softswitch constants
    ├── sprite.asm        # 16-Sprite 4bpp glowing crystal alien bouncing animation
    ├── spritesnd.asm     # 16-Sprite + 4-Voice stereo PSG chiptune audio player
    ├── mode7.asm         # Mode 7 256-color fullscreen bitmap with 6502 RLE decompressor
    ├── rainbow_rle.mjs   # Mode 7 256-color rainbow pattern generator and RLE compressor
    └── preview.mjs       # Standalone 560x384 PNG preview screenshot generator and CRC32 encoder
```

### 4.2 Key Technical Achievements:
1. **Dedicated 6502 Assembler Module (`src/asm6502.mjs`)**:
   - Two-pass assembler guaranteeing identical byte-length calculations between symbol resolution and code emission.
   - Supports standard assembly comments (`;` and `//`), equate definitions (`EQU`, `=`), and hex data formats (`HEX`, `!byte`, `.byte`).
   - Dynamically injects slot base constants (`VERA_BASE = $C200` or `$C400`) from `src/vera.inc`.
2. **Dedicated Applesoft BASIC Compiler (`src/applebasic.mjs`)**:
   - Parses plain-text `startup.bas` directly into native Apple II binary memory-linked format (`NextPtr[2] + LineNo[2] + Tokens + 0x00`), eliminating manual hex token authoring.
3. **ProDOS 2.4.3 File System Engine**:
   - Formats standard 140KB ProDOS 2.4.3 disks with proper Volume Header, Block allocation bitmap, and file entry pointers.
   - Enforces sector boundary checks (`offset + 0x27 <= 512`) to prevent sector table corruption.
   - Sets Access Byte to `$C3` (unlocked) to ensure all binary routines and BASIC scripts can be read, written, and executed.
4. **Applesoft BASIC `STARTUP` Program (`src/startup.bas`)**:
   - Implements bulletproof dual-port signature probing across Slot 2 and Slot 4:
     ```basic
     30 S = 0
     31 POKE 49669,1: IF PEEK(49669) = 1 THEN GOTO 34: GOTO 45
     34 POKE 49669,0: IF PEEK(49669) = 0 THEN GOTO 37: GOTO 45
     37 POKE 49664,0: POKE 49665,0: POKE 49666,0: POKE 49667,222
     41 IF PEEK(49667) = 222 THEN GOTO 43: GOTO 45
     43 POKE 49667,111: IF PEEK(49667) = 111 THEN S = 2
     ```
   - Automatically executes the corresponding Slot 2 or Slot 4 binary routines (`SPRITE.BIN`, `SPRSND.BIN`, `MODE7.BIN`).

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


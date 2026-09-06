# VERA Test Demo Disk & Slideshow for Apple II

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/anomixer/veratest)
[![Release](https://img.shields.io/github/v/release/anomixer/veratest?color=purple)](https://github.com/anomixer/veratest/releases)
[![Apple2TS Compatible](https://img.shields.io/badge/Apple2TS-compatible-blue.svg)](https://apple2ts.com)
[![AppleWin Compatible](https://img.shields.io/badge/AppleWin-compatible-orange.svg)](https://github.com/anomixer/AppleWin)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Interactive 7-in-1 test suite and 375-image fullscreen 256-color slideshow for the **VERA (Versatile Embedded Retro Adapter)** FPGA expansion card on **Apple II** computers (compatible with both [Apple2TS](https://apple2ts.com) web emulator and [AppleWin](https://github.com/anomixer/AppleWin) emulator with VERA card).

| 🎮 7-in-1 Flagship Test Suite (`veratest.po`) | 🖼️ 32MB 375-Image Slideshow (`slideshow.hdv`) |
| :---: | :---: |
| ![VERA Test Demo](veratest.png) | ![VERA Slideshow Demo](slideshow.png) |

---

## 🚀 Emulators & Hardware Compatibility

### 🌐 Apple2TS Web Emulator
You can run this demo disk directly in your browser without any installation:
👉 **[Launch VERA Test on Apple2TS](https://apple2ts.com)**

*(In Apple2TS, ensure the VERA Card is installed in Slot 2 or Slot 4, and open the "VERA Monitor" tab to watch the 640x480 VGA output!)*

### 💻 AppleWin Emulator & Real Apple II Hardware
Fully compatible with [AppleWin](https://github.com/anomixer/AppleWin) (with VERA card emulation) and physical Apple II computers (Apple IIe, Apple IIgs, Laser 128) with a VERA FPGA card in **Slot 2** (`$C200`) or **Slot 4** (`$C400`):
- **Seamless Single-Monitor Auto-Switching**: Automatically disables VERA video output (`VERA_DC_VID = 0`) on menu entry and upon pressing `ESC`/`Q` in any showcase, allowing AppleWin to cleanly restore the native Apple II text screen with zero display corruption.
- **Dual-Port Hardware Signature Probing**: Automatically detects whether the VERA card is in Slot 2 or Slot 4 and dynamically launches the corresponding 6502 binary (`SLIDESHOW.BIN` / `SLIDSHW4.BIN`, `SONIC.BIN` / `SONIC4.BIN`, etc.).
- **Clean Boot & Cold-Reset Safety**: Blanks display composer and zeroes out all 16 PSG sound channels on entry, completely eliminating ghost sprites, audio buzzing, and reboot freeze.

---

## 🎮 7-in-1 Flagship Showcases

| # | Showcase Name | Tech Highlights & Features |
|---|---|---|
| **1** | **16-Sprite Bouncing Alien** | 16 hardware sprites with 4bpp crystal alien pixel graphics, 2.0x hardware scaling, and smooth border bouncing physics. |
| **2** | **Sprite Demo + Stereo PSG Chiptune** | 16 bouncing sprites accompanied by a 4-voice polyphonic PSG chiptune engine (Pulse lead, Saw counter-harmony, Triangle bass, Noise drums) with dynamic ADSR decay. |
| **3** | **Real Rainbow Arc (Mode 7)** | Fullscreen 256-color Mode 7 bitmap ($320 \times 240$ 8bpp) decompressed in sub-millisecond time using pure 6502 RLE stream decoding. |
| **4** | **Mode 4 256-Color RPG Tilemap** | Authentic Mode 4 tilemap engine featuring 8bpp $8 \times 8$ tiles, centered castle landscape, and smooth horizontal scrolling wander camera. |
| **5** | **Dual-Layer Parallax Energy Waves** | VERA dual-layer hardware capability demonstration: Layer 0 background starfield + Layer 1 high-speed plasma wave array scrolling leftward with 3D parallax depth. |
| **6** | **The Matrix Digital Code Rain** | 256-color text mode (`T256C=1`) palette-cycling engine with multi-track, multi-speed green waterfalls and live Katakana glitch mutations. |
| **7** | **Sonic The Hedgehog: Green Hill Zone** | Sega Genesis classic ported from Commander X16: dual-layer parallax scrolling, 4-frame animated hardware sprites with ground level bobbing, shimmering water palette cycling, rotating sunflower VRAM swapping, and 60 Hz VERA PSG Green Hill Zone polyphonic chiptune BGM. |

---

## 🛠️ Zero-Dependency Modular Build System

This repository contains a self-contained, zero-dependency Node.js toolchain that compiles both 6502 assembly and Applesoft BASIC directly from plain-text source files:

```bash
# 1. Build standard 140KB bootable ProDOS floppy disk (veratest.po & veratest.png)
build.bat veratest
# or: node src/veratest/veratest.mjs

# 2. Build standalone 32MB 375-Image 256-Color ProDOS Hard Disk (slideshow.hdv & slideshow.png)
build.bat slideshow
# or: node src/slideshow/slideshow_hdv.mjs

# 3. Build all targets
build.bat all
```

### 📂 Repository Structure
- `assets/`: Authentic ProDOS 2.4.3 baseline floppy (`ProDOS 2.4.3.po`) and 32MB hard disk baseline (`ProDOS 2.4.3.hdv`).
- `src/`: Shared compiler infrastructure and hardware definitions:
  - `asm6502.mjs`: Standalone zero-dependency two-pass 6502 assembler.
  - `applebasic.mjs`: Standalone Applesoft BASIC tokenizer and memory-linked binary compiler.
  - `applebasic.inc`: Applesoft BASIC keyword token definitions.
  - `vera.inc`: VERA register offsets and Apple II hardware softswitch constants.
- `src/veratest/`: Flagship 7-in-1 test suite & demo showcases:
  - `veratest.mjs`: 140KB ProDOS 2.4.3 floppy builder & PNG renderer.
  - `startup.bas`: Applesoft BASIC dual-port hardware probe and launcher menu.
  - `sprite.asm`: 16-Sprite 4bpp bouncing alien animation.
  - `spritesnd.asm`: 16-Sprite + 4-voice polyphonic stereo PSG chiptune audio player.
  - `mode7.asm`: Mode 7 256-color fullscreen bitmap with 6502 RLE decompressor.
  - `mode4.asm`: Mode 4 256-color RPG tilemap engine with wandering camera.
  - `layer.asm`: Dual-Layer parallax deep space starfield & high-speed plasma storm.
  - `matrix.asm`: The Matrix digital code rain stream simulator with 256-color palette cycling.
  - `sonic.asm`: Sonic The Hedgehog Green Hill Zone dual-layer engine with PSG music player.
  - `build_sonic_dat.mjs` & `sonic.dat`: Sonic asset packager, palette builder, and ZSM converter.
  - `rainbow_rle.mjs` & `preview.mjs`: RLE compressor and preview screenshot generator.
- `src/slideshow/`: 32MB 375-Image Mode 7 ($320 \times 240$ 8bpp) Fullscreen Slideshow engine:
  - `slideshow.asm`: Pure 6502 ProDOS MLI Direct Block ($80) streaming engine.
  - `startup.bas`: Interactive BASIC launcher menu.
  - `slideshow_hdv.mjs`: 32MB hard disk image volume generator & PNG renderer.
  - `preview.mjs`: 560x384 PNG preview screenshot generator.
  - `data/`: 375 Mode 7 images (`IMG001.BIN` ~ `IMG375.BIN`) and 375 palettes (`VPAL001.BIN` ~ `VPAL375.BIN`); the set contains the original `DATA` 75 plus the first 300 from `DATA-EXTENDED`.

### ProDOS Slideshow Disk Layout

`slideshow.hdv` is a bootable 32 MiB ProDOS 2.4.3 volume named `SLIDESHOW`. Its root directory contains the system files, `STARTUP`, the Slot 2 and Slot 4 slideshow binaries, and a standard `/DATA/` subdirectory. `/DATA/` registers all 750 assets as ordinary ProDOS files:

```text
/SLIDESHOW/DATA/
  VPAL001.BIN ... VPAL375.BIN   512-byte palettes
  IMG001.BIN  ... IMG375.BIN    76,800-byte Mode 7 bitmaps
```

The directory occupies blocks 150–207 (58 blocks), with a correctly aligned subdirectory header and multi-block directory entries. For fast playback, each image slot is also laid out contiguously from block 6000: one palette block, one image index block, and 150 bitmap blocks. The 6502 engine uses Direct Block MLI `$80` to read that layout directly into VERA VRAM; it does not depend on pathname parsing during playback.

Three original X16 ZSM soundtracks (`SB-INTRO`, `CANYON`, and `GREENHILL`) are bundled and converted during the build into VERA PSG streams, in that order. Fixed 600-block music slots begin at block 800 and are streamed through a 512-byte buffer at `$4000`, while the 375-image area begins at block 6000. YM2151 FM commands are skipped because the Apple2TS VERA platform exposes the VERA PSG instead. Music starts with the slideshow and advances from the VERA VSYNC IRQ, so image loading does not alter its tempo; `M` toggles mute/playback, `N` selects the next soundtrack, and each song automatically advances to the next one at EOF (or a random soundtrack in Random mode). Switching tracks clears the PSG first to prevent residual notes.

The source archive also contains other ZSM files, but they are not packaged because they are FM-only or not reliably audible through the Apple II VERA PSG path. The Apple II playlist intentionally keeps the three tested PSG tracks above.

Auto-play is enabled by default and advances every 3 seconds. During playback, use Right/Down (Space is also supported) for the next image, Left/Up (or `P`) for the previous image, `N` for the next soundtrack, `A` to toggle auto-play, `R` to toggle random mode and auto-play together, `O` to toggle the on-screen display (OSD) status bar overlay, and `Esc` or `Q` to return to BASIC. On Apple II, the left arrow is reported as key code `$08` (Backspace). The launcher prints the slideshow controls after option `1` is selected and automatically continues after 5 seconds or upon any keypress.

The slideshow engine provides dual status reporting:
- **On-Screen Display (OSD Overlay)**: Pure Mode 7 bitmap overlay (`O` key to toggle) rendered on scanlines 232..239 (Row 29) using precomputed palette LUTs (`PAL_FG_TABLE` & `PAL_BG_TABLE`) ensuring 0% palette overwriting:
  - **Dual Ultra-Compact Corner Badges**:
    - Left corner: `MUSIC:<NAME>` (columns 0..11, 0..13, or 0..14)
    - Right corner: `IMG:xxx/375` (columns 29..39)
    - **Untouched Center Artwork**: Columns 12/14/15 through 28 (120 to 136 pixels wide!) are completely skipped by VERA hardware address jumps, preserving the original bitmap artwork without any black box.
  - **Pure Image Mute Mode (`M` key)**: Suppresses the left music badge entirely, leaving columns 0 through 28 (**232 pixels wide out of 320!**) as 100% untouched Mode 7 art.
  - **PSG Shadow Unmute Engine**: Uses a 64-byte RAM shadow register table (`PSG_SHADOW`) to instantaneously restore all 16 voices with zero pitch glitching or lost notes upon unmuting.
- **Apple II Native Text Screen**: Displays `MUSIC:<name>` at the lower-left (`$07D0`) and `IMG:xxx/375` at the lower-right (`$07ED..$07F7`), blanking the left side when muted.

Soundtrack balance is tuned specifically for the VERA PSG. In particular, `CANYON` has its PSG melodic channels boosted and noise percussion dynamically attenuated so that the rhythm and lead stay in perfect acoustic balance.

### X16 VERA vs. Apple II VERA Audio

The original X16 slideshow uses a hybrid sound system. VERA PSG and YM2151 are separate sound sources, so the Apple II port cannot reproduce the original mix using VERA PSG alone:

| Feature | Commander X16 slideshow | Apple II / Apple2TS port |
| :--- | :--- | :--- |
| VERA PSG | Up to 16 channels | 16 channels |
| YM2151 FM | 8 FM channels; `CANYON.ZSM` contains data for all 8 | Not present in the VERA card interface |
| ZSM PSG writes | Played | Played |
| ZSM YM2151/FM writes | Played | Omitted during conversion |
| Audible result | Full hybrid PSG + FM arrangement | PSG-only arrangement, typically perceived as fewer prominent voices |

The FM-like voices heard in the X16 version are YM2151 channels, not additional VERA channels. The port preserves the VERA PSG portion and intentionally skips YM2151 commands because Apple2TS currently exposes the VERA PSG audio path, but not a YM2151 device. Exact audio parity would require YM2151 emulation or an FM-to-PSG approximation.

#### X16 Slideshow Music Porting Status

| Track | Original ZSM content | Apple II port status |
| :--- | :--- | :--- |
| `SB-INTRO` | PSG + FM | Bundled; PSG portion played, first track |
| `CANYON` | PSG + FM | Bundled; PSG portion played |
| `GREENHILL` | PSG + FM | Bundled; PSG portion played |
| `GAZE` | PSG + FM | Not bundled; PSG portion was not reliably audible in testing |
| `12DAYS` | FM-only | Not bundled; requires YM2151/FM support |
| `FUSION` | FM-only + extension data | Not bundled; requires YM2151/FM support |
| `GUILE` | FM-only | Not bundled; requires YM2151/FM support |
| `VALK` | FM-only | Not bundled; requires YM2151/FM support |

The packaged playlist is intentionally limited to the three tested tracks: `SB-INTRO`, `CANYON`, and `GREENHILL`.

---

## 🙏 Special Acknowledgements & Credits

Special thanks to the original creators, engineers, and contributors whose work made VERA and its TypeScript emulation possible:

- **[Frank van den Hoef](https://github.com/fvdhoef/vera-module)** – Creator and hardware designer of the VERA FPGA system.
- **[Michael Steil](https://github.com/mist64)** – Commander X16 emulator architecture and core implementation.
- **[David Murray (The 8-Bit Guy)](https://www.the8bitguy.com/)** – Creator and visionary of the Commander X16 project.
- **[Anthony Henry (ahenry3068)](https://github.com/ahenry3068)** – Creator of the original Commander X16 75-Image Fullscreen 256-Color Slideshow and Bitmap Assets.
- **[ZeroByte (ZeroByteOrg)](https://github.com/ZeroByteOrg/sonicdemo)** – Creator of the original *Sonic The Hedgehog: Green Hill Zone* dual-layer parallax engine and demo for Commander X16.
- **[Mike Morrison](https://github.com/code-bythepound)** – Porting the VERA core to TypeScript and adapting it for Apple II / web emulation.
- **[Chris Torrence (ct6502)](https://github.com/ct6502)** – Creator of the [Apple2TS](https://apple2ts.com) web emulator ecosystem.
- **[Original X16 Demo Authors](https://github.com/X16Community/x16-demo)**:
  - Mode 4 RPG Tilemap Demo & Graphics Assets.
  - Scrolling Electricity Dual-Layer Demo.
  - Matriculate Text 256-Color Palette-Cycling Matrix Engine.

---

## 📄 License

MIT License © 2026 [anomixer](https://github.com/anomixer).

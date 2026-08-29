# VERA Test Demo Disk & Slideshow for Apple II

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/anomixer/veratest)
[![Apple2TS Compatible](https://img.shields.io/badge/Apple2TS-compatible-blue.svg)](https://apple2ts.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Interactive 6-in-1 test suite and 375-image fullscreen 256-color slideshow for the **VERA (Versatile Embedded Retro Adapter)** FPGA expansion card on **Apple II** computers and the [Apple2TS](https://apple2ts.com) web emulator.

| 🎮 6-in-1 Flagship Test Suite (`veratest.po`) | 🖼️ 32MB 375-Image Slideshow (`slideshow.hdv`) |
| :---: | :---: |
| ![VERA Test Demo](veratest.png) | ![VERA Slideshow Demo](slideshow.png) |

---

## 🚀 Live Demo on Apple2TS

You can run this demo disk directly in your browser without any installation:
👉 **[Launch VERA Test on Apple2TS](https://apple2ts.com)**

*(In Apple2TS, ensure the VERA Card is installed in Slot 2 or Slot 4, and open the "VERA Monitor" tab to watch the 640x480 VGA output!)*

---

## 🎮 6-in-1 Flagship Showcases

| # | Showcase Name | Tech Highlights & Features |
|---|---|---|
| **1** | **16-Sprite Bouncing Alien** | 16 hardware sprites with 4bpp crystal alien pixel graphics, 2.0x hardware scaling, and smooth border bouncing physics. |
| **2** | **Sprite Demo + Stereo PSG Chiptune** | 16 bouncing sprites accompanied by a 4-voice polyphonic PSG chiptune engine (Pulse lead, Saw counter-harmony, Triangle bass, Noise drums) with dynamic ADSR decay. |
| **3** | **Real Rainbow Arc (Mode 7)** | Fullscreen 256-color Mode 7 bitmap ($320 \times 240$ 8bpp) decompressed in sub-millisecond time using pure 6502 RLE stream decoding. |
| **4** | **Mode 4 256-Color RPG Tilemap** | Authentic Mode 4 tilemap engine featuring 8bpp $8 \times 8$ tiles, centered castle landscape, and smooth horizontal scrolling wander camera. |
| **5** | **Dual-Layer Parallax Energy Waves** | VERA dual-layer hardware capability demonstration: Layer 0 background starfield + Layer 1 high-speed plasma wave array scrolling leftward with 3D parallax depth. |
| **6** | **The Matrix Digital Code Rain** | 256-color text mode (`T256C=1`) palette-cycling engine with multi-track, multi-speed green waterfalls and live Katakana glitch mutations. |

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
- `src/veratest/`: Flagship 6-in-1 test suite & demo showcases:
  - `veratest.mjs`: 140KB ProDOS 2.4.3 floppy builder & PNG renderer.
  - `startup.bas`: Applesoft BASIC dual-port hardware probe and launcher menu.
  - `sprite.asm`: 16-Sprite 4bpp bouncing alien animation.
  - `spritesnd.asm`: 16-Sprite + 4-voice polyphonic stereo PSG chiptune audio player.
  - `mode7.asm`: Mode 7 256-color fullscreen bitmap with 6502 RLE decompressor.
  - `mode4.asm`: Mode 4 256-color RPG tilemap engine with wandering camera.
  - `layer.asm`: Dual-Layer parallax deep space starfield & high-speed plasma storm.
  - `matrix.asm`: The Matrix digital code rain stream simulator with 256-color palette cycling.
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

Auto-play is enabled by default and advances every 3 seconds. During playback, use Right/Down (Space is also supported) for the next image, Left/Up (or `P`) for the previous image, `N` for the next soundtrack, `A` to toggle auto-play, `R` to toggle random mode and auto-play together, and `Esc` or `Q` to return to BASIC. On Apple II, the left arrow is reported as key code `$08` (Backspace). The launcher prints the slideshow controls after option `1` is selected.

The independent Apple II text display shows the current image number in its lower-right corner as `IMG: nnn/375` (one space after the colon).

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
- **[Mike Morrison](https://github.com/code-bythepound)** – Porting the VERA core to TypeScript and adapting it for Apple II / web emulation.
- **[Chris Torrence (ct6502)](https://github.com/ct6502)** – Creator of the [Apple2TS](https://apple2ts.com) web emulator ecosystem.
- **[Original X16 Demo Authors](https://github.com/X16Community/x16-demo)**:
  - Mode 4 RPG Tilemap Demo & Graphics Assets.
  - Scrolling Electricity Dual-Layer Demo.
  - Matriculate Text 256-Color Palette-Cycling Matrix Engine.

---

## 📄 License

MIT License © 2026 [anomixer](https://github.com/anomixer).

# VERA Test Demo Disk for Apple II

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/anomixer/veratest)
[![Apple2TS Compatible](https://img.shields.io/badge/Apple2TS-compatible-blue.svg)](https://apple2ts.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Interactive 6-in-1 test suite and hardware demo disk for the **VERA (Versatile Embedded Retro Adapter)** FPGA expansion card on **Apple II** computers and the [Apple2TS](https://apple2ts.com) web emulator.

![VERA Test Demo](veratest.png)

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
# Build the bootable ProDOS disk image (veratest.po)
node build.mjs
# or
npm run build
```

### Source Tree
- `src/asm6502.mjs`: Standalone two-pass 6502 assembler.
- `src/applebasic.mjs`: Standalone Applesoft BASIC tokenizer and binary compiler.
- `src/startup.bas`: Human-readable Applesoft BASIC startup menu & hardware probe script.
- `src/sprite.asm`: 16-sprite bouncing animation.
- `src/spritesnd.asm`: 16-sprite + 4-voice stereo PSG chiptune engine.
- `src/mode7.asm`: Mode 7 256-color bitmap with 6502 RLE decompressor.
- `src/mode4.asm`: Mode 4 RPG tilemap engine.
- `src/layer.asm`: Dual-layer parallax deep space starfield and plasma waves.
- `src/matrix.asm`: The Matrix digital code rain stream simulator.

---

## 🙏 Special Acknowledgements & Credits

Special thanks to the original creators, engineers, and contributors whose work made VERA and its TypeScript emulation possible:

- **[Frank van den Hoef](https://github.com/fvdhoef/vera-module)** – Creator and hardware designer of the VERA FPGA system.
- **[Michael Steil](https://github.com/mist64)** – Commander X16 emulator architecture and core implementation.
- **[David Murray (The 8-Bit Guy)](https://www.the8bitguy.com/)** – Creator and visionary of the Commander X16 project.
- **[Mike Morrison](https://github.com/code-bythepound)** – Porting the VERA core to TypeScript and adapting it for Apple II / web emulation.
- **[Chris Torrence (ct6502)](https://github.com/ct6502)** – Creator of the [Apple2TS](https://apple2ts.com) web emulator ecosystem.
- **[Original X16 Demo Authors](https://github.com/X16Community/x16-demo)**:
  - Mode 4 RPG Tilemap Demo & Graphics Assets.
  - Scrolling Electricity Dual-Layer Demo.
  - Matriculate Text 256-Color Palette-Cycling Matrix Engine.

---

## 📄 License

MIT License © 2026 [anomixer](https://github.com/anomixer).

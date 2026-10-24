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
| **2** | **Sprite Demo + Stereo PSG/FM Chiptune** | 16 bouncing sprites accompanied by a 4-voice polyphonic PSG chiptune engine (Pulse lead, Saw counter-harmony, Triangle bass, Noise drums) with dynamic ADSR decay, plus YM2151 FM kick and snare/hat voices copied from the *Space Battle* soundtrack whenever the FM chip is present (auto-detected; PSG-only otherwise). The FM chip carries percussion only — the lead and bass stay pure PSG. |
| **3** | **Real Rainbow Arc (Mode 7)** | Fullscreen 256-color Mode 7 bitmap ($320 \times 240$ 8bpp) decompressed in sub-millisecond time using pure 6502 RLE stream decoding. |
| **4** | **Mode 4 256-Color RPG Tilemap** | Authentic Mode 4 tilemap engine featuring 8bpp $8 \times 8$ tiles, centered castle landscape, and smooth horizontal scrolling wander camera. |
| **5** | **Dual-Layer Parallax Energy Waves** | VERA dual-layer hardware capability demonstration: Layer 0 background starfield + Layer 1 high-speed plasma wave array scrolling leftward with 3D parallax depth. |
| **6** | **The Matrix Digital Code Rain** | 256-color text mode (`T256C=1`) palette-cycling engine with multi-track, multi-speed green waterfalls and live Katakana glitch mutations. |
| **7** | **Sonic The Hedgehog: Green Hill Zone** | Sega Genesis classic ported from Commander X16: dual-layer parallax scrolling, 4-frame animated hardware sprites with ground level bobbing, shimmering water palette cycling, rotating sunflower VRAM swapping, and the original 60 Hz Green Hill Zone ZSM arrangement played as VERA PSG plus YM2151 FM (FM auto-detected; the PSG part alone plays when no FM chip is present). |

---

## 🛠️ Modular Build System

The Node.js toolchain compiles 6502 assembly and Applesoft BASIC from source. Both disk images are packaged with the bundled `tools/cadius.exe`. Set the `CADIUS` environment variable to use a different Cadius executable.

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
- `tools/cadius.exe`: Bundled ProDOS-aware utility used to package both disk images.
- `src/`: Shared compiler infrastructure and hardware definitions:
  - `asm6502.mjs`: Standalone zero-dependency two-pass 6502 assembler.
  - `applebasic.mjs`: Standalone Applesoft BASIC tokenizer and memory-linked binary compiler.
  - `applebasic.inc`: Applesoft BASIC keyword token definitions.
  - `vera.inc`: VERA register offsets and Apple II hardware softswitch constants.
  - `vera_fm.inc`: YM2151 FM chip detect/reset/write/silence routines shared by every player.
  - `zsm2vera.mjs`: ZSM to VZM stream converter (PSG writes, batched FM register pairs, delays).
  - `music_streams.mjs`: Build-time SB-INTRO/CANYON/GREENHILL `.vzm` generation for the slideshow.
- `src/veratest/`: Flagship 7-in-1 test suite & demo showcases:
  - `veratest.mjs`: Cadius-based 140KB ProDOS floppy packager & PNG renderer.
  - `startup.bas`: Applesoft BASIC dual-port hardware probe and launcher menu.
  - `sprite.asm`: 16-Sprite 4bpp bouncing alien animation.
  - `spritesnd.asm`: 16-Sprite + 4-voice polyphonic stereo PSG chiptune player, with a YM2151 FM drum layer (kick + snare/hat lifted from `SB-INTRO.ZSM`).
  - `mode7.asm`: Mode 7 256-color fullscreen bitmap with 6502 RLE decompressor.
  - `mode4.asm`: Mode 4 256-color RPG tilemap engine with wandering camera.
  - `layer.asm`: Dual-Layer parallax deep space starfield & high-speed plasma storm.
  - `matrix.asm`: The Matrix digital code rain stream simulator with 256-color palette cycling.
  - `sonic.asm`: Sonic The Hedgehog Green Hill Zone dual-layer engine with the original PSG+FM ZSM music player.
  - `sonic_music.inc` & `build_sonic_dat.mjs` & `sonic.dat`: Sonic asset packager (88 blocks, palette/tiles/sprites), plus the generated music-stream descriptors.
  - `SONICMUS.BIN`: the 35-block PSG+FM Green Hill stream, stored as a real ProDOS `BIN` file with aux `$4800` and `BLOAD`ed by `STARTUP` before `BRUN SONIC.BIN`.
  - `rainbow_rle.mjs` & `preview.mjs`: RLE compressor and preview screenshot generator.
- `src/slideshow/`: 32MB 375-Image Mode 7 ($320 \times 240$ 8bpp) Fullscreen Slideshow engine:
  - `slideshow.asm`: Pure 6502 ProDOS file-level asset streaming engine.
  - `startup.bas`: Interactive BASIC launcher menu.
  - `slideshow_hdv.mjs`: 32MB hard disk image volume generator & PNG renderer.
  - `preview.mjs`: 560x384 PNG preview screenshot generator.
  - `data/`: 375 Mode 7 images (`IMG001.BIN` ~ `IMG375.BIN`) and 375 palettes (`VPAL001.BIN` ~ `VPAL375.BIN`); the set contains the original `DATA` 75 plus the first 300 from `DATA-EXTENDED`.

### ProDOS Slideshow Disk Layout

`slideshow.hdv` is a bootable 32 MiB ProDOS 2.4.3 volume named `SLIDESHOW`. Its root directory contains the system files, `STARTUP`, the Slot 2 and Slot 4 slideshow binaries, a `/DATA/` music directory, and three image directories. The image files are split into groups of 125 so each catalog stays manageable for Copy II Plus:

```text
/SLIDESHOW/DATA/                 SBINTRO.VZM / CANYON.VZM / GREENHILL.VZM (PSG+FM streams)
/SLIDESHOW/DATA1/                VPAL001.BIN ... VPAL125.BIN and IMG001.BIN ... IMG125.BIN
/SLIDESHOW/DATA2/                VPAL126.BIN ... VPAL250.BIN and IMG126.BIN ... IMG250.BIN
/SLIDESHOW/DATA3/                VPAL251.BIN ... VPAL375.BIN and IMG251.BIN ... IMG375.BIN
```

Both packaged images use Cadius for ProDOS file/catalog allocation. The 7-in-1 floppy's programs, launcher, `SONIC.DAT` and `SONICMUS.BIN` are ordinary ProDOS files; the launcher `BLOAD`s the music stream to `$4800` and Sonic opens its 88-block data container with MLI `OPEN`/`READ`/`CLOSE`. (The stream deliberately avoids `$4000..$41FF`, a 512-byte BASIC/ProDOS scratch buffer that is overwritten during `BLOAD`.) The slideshow selects `/DATA1`, `/DATA2`, or `/DATA3` from the image number and resolves each palette and image through its ProDOS directory entry and seedling/sapling index. It then uses MLI `READ_BLOCK` on those file-allocated blocks to stream the 76,800-byte image directly to VERA without loading it into Apple II RAM. Music uses MLI `OPEN`/`READ` from `/DATA`. Neither program relies on fixed physical block numbers or contiguous allocation. The generated ProDOS 8 subdirectory headers are adjusted to use the `$75` compatibility marker required by ProDOS 8.

To install the 7-in-1 suite on another ProDOS volume, copy `STARTUP`, all demo `.BIN` files, `SONIC.DAT`, and `SONICMUS.BIN` into the same target directory, then launch `STARTUP` with that directory as the ProDOS prefix. The floppy builder preserves `PRODOS` and `BASIC.SYSTEM` from its bootable baseline and uses Cadius to remove other baseline utilities and add the generated app files.

For file-level installation on another ProDOS volume, copy the slideshow files and all four directories (`DATA`, `DATA1`, `DATA2`, and `DATA3`) together. The loader follows the active ProDOS prefix, so the app can run from a nested directory such as `/VERASD/SLIDESHOW/`.

Three original X16 ZSM soundtracks (`SB-INTRO`, `CANYON`, and `GREENHILL`) are bundled and converted during the build into VERA PSG + YM2151 FM streams, in that order. The streams are stored as `SBINTRO.VZM`, `CANYON.VZM`, and `GREENHILL.VZM` under `/DATA`. Every ZSM tick is encoded as one record: a PSG write, a batched YM2151 register-pair block, or a delay, so the FM arrangement is preserved instead of being discarded. The YM2151 key register `$08` is passed through byte-for-byte: it is an **operator mask in bits 6..3 plus the channel in bits 2..0**, the chip ignores bit 7, and a zero mask releases the operators, so the tracker's own key-on/key-off pairs drive the envelopes exactly as the original ZSM does (this is the same write stream `veramusic`'s melodius player forwards). Every tick of all three songs was compared against the raw ZSM by replaying the PSG *and* FM writes and diffing the resulting register image: 0 mismatched ticks out of 3,192 / 7,570 / 20,385, with identical `$08` write sequences. On startup the program probes `$Cs20`/`$Cs21` for the FM chip. With the FM chip the player forwards the YM2151 writes to `$Cs20`/`$Cs21`; without one it drops those records and plays exactly the PSG part. Music starts with the slideshow and advances from the VERA VSYNC IRQ at 60 Hz, so image loading does not alter its tempo; `M` toggles mute/playback, `N` selects the next soundtrack, and each song automatically advances to the next one at EOF (or a random soundtrack in Random mode). Switching tracks silences the PSG, resets the FM chip, and clears the stored key-on state before the new stream starts, so no residual notes survive a track change.

The source archive also contains other ZSM files; the packaged playlist is limited to the three tracks that were verified both as PSG and as FM arrangements.

Auto-play is enabled by default and advances every 3 seconds. During playback, use Right/Down (Space is also supported) for the next image, Left/Up (or `P`) for the previous image, `N` for the next soundtrack, `A` to toggle auto-play, `R` to toggle random mode and auto-play together, `O` to toggle the on-screen display (OSD) status bar overlay, `+`/`=` and `-`/`_` to raise/lower the master volume (0..15, default 12), and `Esc` or `Q` to return to BASIC. On Apple II, the left arrow is reported as key code `$08` (Backspace). The launcher prints the slideshow controls after option `1` is selected and automatically continues after 5 seconds or upon any keypress.

The master volume moves the PSG and the YM2151 together, so one key press changes the whole soundtrack. PSG voice levels (register `+2`, level in bits 5..0, stereo pan in bits 7..6) are scaled at play time as `(level * volume + 8) >> 4` with the pan carried through untouched, and the 64-byte `PSG_SHADOW` keeps the unscaled stream values so a volume change can re-send all 16 voices immediately. The OPM has no global volume register, so the player mirrors the 32 operator total-level bytes (`$60..$7F`) and adds an offset from a table matched to the PSG amplitude law — `127, 32, 24, 19, 16, 14, 11, 10, 8, 7, 5, 4, 3, 2, 2, 0` for volumes 0..15 (0.75 dB per step: the default 12 is about −2.25 dB, 15 is exactly as the tracker authored it, 0 is silent) — then rewrites all 32 levels from that mirror. One detail matters here: the OPM total level is a **7-bit** field, so bit 7 of a stream byte is ignored by the chip and has to be masked off before the offset is added. `GREENHILL` writes levels like `$8A` and `$94` on its carriers; without the mask those look "already above `$7F`" and get clamped to `$7F`, i.e. muted, which is exactly how that track lost its FM half while the other two kept theirs.

The slideshow engine provides dual status reporting:
- **On-Screen Display (OSD Overlay)**: Pure Mode 7 bitmap overlay (`O` key to toggle) rendered on scanlines 232..239 (Row 29) using precomputed palette LUTs (`PAL_FG_TABLE` & `PAL_BG_TABLE`) ensuring 0% palette overwriting:
  - **Dual Ultra-Compact Corner Badges**:
    - Left corner: `MUSIC:<NAME>` (columns 0..11, 0..13, or 0..14)
    - Right corner: `IMG:xxx/375` (columns 29..39)
    - **Untouched Center Artwork**: Columns 12/14/15 through 28 (120 to 136 pixels wide!) are completely skipped by VERA hardware address jumps, preserving the original bitmap artwork without any black box.
  - **Pure Image Mute Mode (`M` key)**: Suppresses the left music badge entirely, leaving columns 0 through 28 (**232 pixels wide out of 320!**) as 100% untouched Mode 7 art.
  - **PSG + FM Shadow Unmute Engine**: Uses a 64-byte RAM shadow register table (`PSG_SHADOW`) plus an 8-byte FM key-on shadow (`FM_KEYS`) to instantaneously restore all 16 PSG voices and every sounding FM channel with zero pitch glitching or lost notes upon unmuting.
- **Apple II Native Text Screen**: Displays `MUSIC:<name>` at the lower-left (`$07D0`), the master volume as ` VOL:nn` in the middle (`$07E0..$07E6`), and `IMG:xxx/375` at the lower-right (`$07ED..$07F7`), blanking the left side when muted.

Soundtrack balance is tuned for the VERA mix. In particular, `CANYON` has its PSG melodic channels boosted and noise percussion dynamically attenuated so that the rhythm and lead stay in balance, and the same per-track balance also applies when the YM2151 FM chip adds the FM arrangement on top of it.

### X16 VERA vs. Apple II VERA Audio

The original X16 slideshow uses a hybrid sound system: VERA PSG plus a YM2151 (OPM) FM chip. The Apple II VERA card carries the YM2151 (OPM) FM core, and the port handles both the FM+PSG case and a card whose FM aperture does not answer:

| Feature | Commander X16 slideshow | Apple II VERA with FM Chip | Apple II VERA without FM Chip |
| :--- | :--- | :--- | :--- |
| VERA PSG | Up to 16 channels | 16 channels | 16 channels |
| YM2151 FM | 8 FM channels; `CANYON.ZSM` contains data for all 8 | Same 8 channels, forwarded to `$Cs20`/`$Cs21` | FM absent; the FM records are skipped |
| ZSM PSG writes | Played | Played | Played |
| ZSM YM2151/FM writes | Played | Played (batched register pairs carried in the VZM stream) | Dropped during playback, not during conversion |
| Audible result | Full hybrid PSG + FM arrangement | Full hybrid PSG + FM arrangement | PSG-only arrangement |
| Master volume (`+`/`-`) | Mixer levels, set outside the program | One knob scales PSG and FM together (0..15, default 12) | Same knob, PSG only |

The FM part is detected at startup by writing `$5A`/`$A5` to `$Cs20`/`$Cs21` and reading them back: if the bytes do not echo, the card has no FM chip and the two apertures are just the VERA address latches. Nothing is lost at build time either way — every ZSM tick is encoded in the VZM stream as a PSG write, a batched FM register pair or a delay, so the same `/DATA` files drive a card with or without the FM chip. The slideshow shows the result as an `F` (FM detected) or `P` (PSG only) marker next to the music name in the OSD and on the Apple II text page, and both `STARTUP` menus print the probe result as `STATUS: YM2151 (OPM) FM CHIP FOUND` or `STATUS: NO YM2151 (OPM) FM CHIP FOUND`.

#### X16 Slideshow Music Porting Status

| Track | Original ZSM content | Apple II port status |
| :--- | :--- | :--- |
| `SB-INTRO` | PSG + FM | Bundled; full PSG + FM playback (first track) |
| `CANYON` | PSG + FM | Bundled; full PSG + FM playback |
| `GREENHILL` | PSG + FM | Bundled; full PSG + FM playback |
| `GAZE` | PSG + FM | Not bundled; PSG portion was not reliably audible in testing |
| `12DAYS` | FM-only | Not bundled; plays on the FM chip only, silent on PSG-only cards |
| `FUSION` | FM-only + extension data | Not bundled; extension data is not supported by the converter |
| `GUILE` | FM-only | Not bundled; plays on the FM chip only |
| `VALK` | FM-only | Not bundled; plays on the FM chip only |

The packaged playlist is intentionally limited to the three tracks that were verified end to end: `SB-INTRO`, `CANYON`, and `GREENHILL`.

#### The VZM Stream Format (ZSM → A2VERA)

The Apple II players do not parse ZSM. During the build, `src/zsm2vera.mjs` converts every X16 `.ZSM` into a **VZM** stream — a compact format designed for the Apple II + VERA case (hence "A2VERA"). It carries the song tick by tick: all PSG writes, then the batched YM2151 register pairs, then the delay that ends the tick. Nothing is discarded at build time, so the same `/DATA` file feeds a card with or without the FM chip.

| Leading byte | Meaning | Followed by |
| :--- | :--- | :--- |
| `$00..$7F` | Delay: byte `N` adds `N` further ticks after the current one (`$00` = next tick). A ZSM delay of `D` is stored as `D - 1`. | — |
| `$80..$BF` | PSG register write, register `= byte & $3F` (`$1F9C0 + reg`) | 1 byte value |
| `$C0..$DF` | YM2151 batch, pair count `= (byte & $1F) + 1` | `count` × (register, value) |
| `$E0..$FE` | Padding so no record straddles a 512-byte block; the player skips it | — |
| `$FF` | End of stream; playback restarts at offset 0 (loop) | — |

There is no header: the length comes from the ProDOS file size (or the block count emitted into `sonic_music.inc`). The YM2151 key register `$08` is stored verbatim — an operator mask in bits 6..3 plus the channel in bits 2..0, mask 0 = release — because rewriting it breaks note retriggering.

| Track | Source `.ZSM` | VZM | Blocks |
| :--- | ---: | ---: | ---: |
| `SB-INTRO` | 346,425 B | 347,136 B | 678 |
| `CANYON` | 129,168 B | 124,416 B | 243 |
| `GREENHILL` | 22,337 B | 18,432 B | 36 |

`node src/verify_music_streams.mjs` rebuilds the three streams, checks the bytes match the packaged `.vzm` files, and replays each converted stream against its source `.ZSM` tick by tick: 0 mismatched ticks across 31,147 ticks. Playing the raw `.ZSM` on the Apple II is also possible — that is what `veramusic`'s melodius jukebox does — but it needs a full ZSM decoder in the player and more disk space (`GREENHILL.ZSM` is 44 blocks against 36 for its VZM, and this 140 KB demo floppy only has 4 blocks free).

---

## 🙏 Special Acknowledgements & Credits

Special thanks to the original creators, engineers, and contributors whose work made VERA and its TypeScript emulation possible:

- **[Frank van den Hoef](https://github.com/fvdhoef/vera-module)** – Creator and hardware designer of the VERA FPGA system.
- **[Michael Steil](https://github.com/mist64)** – Commander X16 emulator architecture and core implementation.
- **[David Murray (The 8-Bit Guy)](https://www.the8bitguy.com/)** – Creator and visionary of the Commander X16 project.
- **[Michael Morrison](https://github.com/code-bythepound)** – Initiator of the A2VERA project, who ported the VERA core to TypeScript and adapted it for both Apple II and web emulation.
- **[Chris Torrence (ct6502)](https://github.com/ct6502)** – Creator of the [Apple2TS](https://apple2ts.com) web emulator ecosystem.
- **[Anthony Henry (ahenry3068)](https://github.com/ahenry3068)** – Creator of the original Commander X16 75-Image Fullscreen 256-Color Slideshow and Bitmap Assets.
- **[ZeroByte (ZeroByteOrg)](https://github.com/ZeroByteOrg/sonicdemo)** – Creator of the original *Sonic The Hedgehog: Green Hill Zone* dual-layer parallax engine and demo for Commander X16.
- **[Original X16 Demo Authors](https://github.com/X16Community/x16-demo)**:
  - Mode 4 RPG Tilemap Demo & Graphics Assets.
  - Scrolling Electricity Dual-Layer Demo.
  - Matriculate Text 256-Color Palette-Cycling Matrix Engine.

---

## 📚 Architecture & Development Guides

* **[Apple II VERA Master Session & Architecture Guide](docs/vera-session.md)**: Comprehensive multi-project engineering guide covering both *Time Pilot IIvera* (Release v1.9) and *veratest* (zero-disk streaming, PSG audio synthesis, memory layouts, Mode 7 OSD, and hardware gotchas).
* **[AI Agent & Developer Guide](AGENTS.md)**: Detailed memory maps, softswitches, MLI calling conventions, and testing procedures for `veratest`.

---

## 🌐 Apple II VERA Resources

- **[Awesome A2VERA](https://github.com/anomixer/awesome-a2vera)** – A curated list of awesome A2VERA (Apple II VERA) resources.

---

## 📄 License

MIT License © 2026 [anomixer](https://github.com/anomixer).


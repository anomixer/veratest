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

### 2.3 YM2151 (OPM) FM Chip
The VERA EV1 board has the YM2151 (OPM) FM core built in. When the chip is not present, the two FM aperture bytes alias the VERA address registers, which is exactly how software detects it:

| Register | Offset | Description |
| :--- | :--- | :--- |
| `YM_REG`  | `VERA_BASE + $20` | YM2151 register select (aliases `VERA_ADDR_L` when no FM chip is fitted) |
| `YM_DATA` | `VERA_BASE + $21` | YM2151 data write (aliases `VERA_ADDR_M` when no FM chip is fitted) |

Detection saves `$Cs20`/`$Cs21`, writes `$5A`/`$A5`, reads both back, and compares. Equal means the bytes are plain VERA latches, so there is no FM chip; otherwise the chip is there and the writes go through. The saved values are then restored.

The FM chip is programmed with `$08` key on/off (**operator mask in bits 6..3, channel in bits 2..0 — bit 7 is ignored by the chip, a zero mask releases the operators**), `$20+ch` pan/feedback/algorithm, `$28+ch`/`$30+ch` key code/fraction, and the per-operator blocks at `$40`, `$60`, `$80`, `$A0`, `$C0`, `$E0` (offset `(operator * 8) + channel`). `src/vera_fm.inc` provides `VERA_FM_DETECT`, `VERA_FM_RESET`, `VERA_FM_WRITE` (which also tracks the last `$08` value per channel so the caller can silence everything on exit) and `VERA_FM_KEY_OFF_ALL` / `VERA_FM_RESTORE_KEYS`.

---

## 🎵 3. 4-Voice Stereo Polyphonic PSG + YM2151 FM Chiptune Engine

The sound demo in `SPRSND.BIN` runs a 32-step arcade chiptune engine written in pure 6502 assembly:

| Voice | VRAM Address | Waveform | Stereo Panning | Role & Sound Design |
| :--- | :--- | :--- | :--- | :--- |
| **Voice 1** | `$1F9C0` | 25% Duty Pulse Wave | Left Channel (`0x40`) | Lead Melody with vibrant chiptune resonance |
| **Voice 2** | `$1F9C4` | Sawtooth Wave | Right Channel (`0x80`) | Counter-Harmony & Stereo Widening |
| **Voice 3** | `$1F9C8` | Triangle Wave | Center (`0xC0`) | Punchy Slap / Disco Bassline |
| **Voice 4** | `$1F9CC` | White Noise & Percussion | Center (`0xC0`) | Kick Drum + Snare Noise + Hi-Hats with dynamic volume envelope decay |

### 3.1 Optional FM Layer
`VERA_FM_DETECT` runs before the video composer is enabled. When the FM chip answers, the demo puts **only percussion** on the chip — FM channels 0 and 1 are left silent on purpose, because the PSG already carries the lead and bass and an FM copy of them is heard as a detuned second player rather than as a harmony.

`FM_LOAD_PATCH` programs channel 2 with the slideshow soundtrack's **kick** voice and channel 3 with its **snare/hat** voice, using the register values `SB-INTRO.ZSM` writes to its own drum channels (`$20` = `$F8` / `$FC`, `$40` = `$0F 02 03 01` / `$25 05 74 74`, carrier TL `$04` / `$0A` — the soundtrack's `$18`/`$1F` would be inaudible under the full-scale PSG drums). `FM_STEP` follows the PSG drum grid: a `$00` pulse-wave step triggers the kick, a `$C0` noise step the snare.

- The kick is not a static tone: `FM_DRUM_TICK` advances the soundtrack's pitch dive once per video frame, walking key code `32 → 2A → 22 → 1A → 12 → 0A → 02` and key fraction `68 → 78 → 88 → 98 → A8 → B8 → C8` over six frames after the key-on, exactly like the ZSM's channel-2 writes. `FM_KICK_IDX` holds the next dive step (0 = idle).
- Each hit is re-keyed the way the tracker does it: `$08` with mask 0 first (release), then the new key code/fraction, then `$08` with mask `$0F` (key on).
- Without an FM chip `FM_PRESENT` stays 0, no `$Ct20`/`$Ct21` write is issued, and the music is the plain 4-voice PSG arrangement.
- On exit the FM key registers are silenced through `VERA_FM_KEY_OFF_ALL`, so returning to BASIC does not leave a note ringing.

The slide show's own VZM streams still carry every FM note of `SB-INTRO`, `CANYON` and `GREENHILL`; only demo 2's hand-written engine is drums-only.

---

## 🛠️ 4. Build System & Modular Architecture

The project uses a modular Node.js build architecture. Both disk images are packaged with the bundled `tools/cadius.exe`; set `CADIUS` to override its path.

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
├── tools/cadius.exe           # ProDOS-aware disk image/file packager
└── src/
    ├── asm6502.mjs            # Standalone two-pass 6502 assembler
    ├── applebasic.mjs         # Standalone Applesoft BASIC compiler
    ├── applebasic.inc         # Applesoft BASIC token table
    ├── vera.inc               # VERA register offsets and Apple II hardware softswitches
    ├── vera_fm.inc            # YM2151 FM chip detect/reset/write/silence routines
    ├── zsm2vera.mjs           # ZSM -> VZM converter (PSG writes, batched FM pairs, delays)
    ├── music_streams.mjs      # Build-time SB-INTRO/CANYON/GREENHILL .vzm generation
    ├── verify_music_streams.mjs # Regenerate the .vzm streams and diff them against the raw ZSM, tick by tick
    │
    ├── veratest/              # 🎮 7-in-1 Flagship Test Suite & Showcase
    │   ├── veratest.mjs       # Cadius-based 140KB ProDOS floppy packager & PNG renderer
    │   ├── startup.bas        # Applesoft BASIC dual-port hardware probe and menu script
    │   ├── sprite.asm         # 16-Sprite 4bpp crystal alien bouncing animation
    │   ├── spritesnd.asm      # 16-Sprite + 4-Voice stereo PSG chiptune player with FM drum layer
    │   ├── mode7.asm          # Mode 7 256-color fullscreen bitmap with 6502 RLE decompressor
    │   ├── mode4.asm          # Mode 4 256-color RPG tilemap engine with centered castle wander camera
    │   ├── layer.asm          # Dual-Layer parallax starfield & high-speed plasma storm
    │   ├── matrix.asm         # The Matrix digital code rain with 256-color palette cycling
    │   ├── sonic.asm          # Sonic Green Hill Zone dual-layer engine with PSG+FM ZSM player
    │   ├── build_sonic_dat.mjs# Sonic asset packager, palette builder, and ZSM (FM+PSG) converter
    │   ├── sonic.dat          # Compacted Sonic asset container (88 blocks, no music)
    │   ├── sonic_music.inc    # GENERATED music stream descriptors (base address, block count)
    │   ├── mode4-*.bin        # Mode 4 palette and tilemap binary assets
    │   ├── rainbow_rle.mjs    # Mode 7 rainbow pattern generator and RLE compressor
    │   └── preview.mjs        # 560x384 PNG preview screenshot generator
    │
    └── slideshow/             # 🖼️ 32MB Fullscreen 375-Image Slideshow Engine
        ├── slideshow.asm      # Pure 6502 file-level ProDOS streaming engine
        ├── startup.bas        # Interactive Applesoft BASIC menu script
        ├── slideshow_hdv.mjs  # Cadius-based HDV packager & PNG renderer
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
3. **Cadius ProDOS Packaging & File-Level Streaming**:
   - Both the 140KB floppy and 32MB hard disk are packaged with Cadius; it creates catalog entries, storage indexes, and volume bitmaps.
   - The 7-in-1 Sonic demo opens `SONIC.DAT` with ProDOS MLI file calls. The slideshow resolves image/palette blocks from each ProDOS file's catalog entry and index, then uses MLI `READ_BLOCK` to stream those allocated blocks directly to VERA without assuming contiguous physical layout.
4. **Applesoft BASIC `STARTUP` Programs**:
   - Dual-port signature probing across Slot 2 and Slot 4.
   - Automatically executes corresponding Slot 2 or Slot 4 binary routines.

### 4.3 Slideshow ProDOS Layout

The generated `slideshow.hdv` is a bootable 32 MiB ProDOS 2.4.3 volume named `SLIDESHOW`. Its root directory contains the system files, `STARTUP`, `SLIDESHOW.BIN`, `SLIDSHW4.BIN`, a `/DATA/` music directory, and `/DATA1/` through `/DATA3/` image directories. Each image directory contains 125 palettes and 125 bitmaps, covering all 375 images while keeping catalogs manageable for Copy II Plus. The image set combines the original `DATA` 75 images with the first 300 images from `DATA-EXTENDED`:

- `VPAL001.BIN`–`VPAL375.BIN`: 512-byte VERA palettes.
- `IMG001.BIN`–`IMG375.BIN`: 76,800-byte ($320 \times 240$) Mode 7 bitmap files.

Both builders use the bundled Cadius executable. The floppy builder copies the ProDOS baseline, renames the volume to `VERATEST`, removes non-boot files through Cadius, and adds the app files with their ProDOS types and auxiliary load addresses. The HDV builder copies its ProDOS baseline, renames the volume, removes `BITSY.BOOT` and `QUIT.SYSTEM`, then uses Cadius to create `/DATA/` and `/DATA1/` through `/DATA3/` and add the app and asset files. Cadius allocates directory and data blocks and writes ProDOS metadata. The HDV build changes each new subdirectory header's compatibility marker from `$76` to `$75`, which ProDOS 8 requires.

`slideshow.asm` selects `/DATA1/`, `/DATA2/`, or `/DATA3/` from the image number, locates `VPALnnn.BIN` and `IMGnnn.BIN` through ProDOS directory entries, reads their seedling/sapling allocation metadata, and streams those file-allocated blocks with MLI `READ_BLOCK` directly into VERA. It does not assume image blocks are contiguous or load the 76,800-byte bitmap into Apple II RAM. Music streams continue to use MLI `OPEN`/`READ` from `/DATA/`. Cadius allocates blocks dynamically, so asset placement is not tied to fixed HDV block numbers.

File-level installation requires copying `DATA`, `DATA1`, `DATA2`, and `DATA3` alongside the app binaries. The loader follows the ProDOS prefix path, including when the app is installed in a nested directory on another volume.

Three X16 ZSM soundtracks (`SB-INTRO`, `CANYON`, and `GREENHILL`) are converted at build time by `src/zsm2vera.mjs` into VERA PSG **and** YM2151 FM streams (`SBINTRO.VZM`, `CANYON.VZM`, `GREENHILL.VZM`) in `/DATA`. The converter follows ZSM command widths, including batched YM2151 writes and extension commands, and encodes each tick as one record: a PSG write (`$80..$BF`), a batched FM register-pair block (`$C0..$DF`) or a delay (`$00..$7F`); `$E0..$FE` is stream padding and `$FF` ends/restarts the song. Nothing is dropped any more — the FM arrangement is carried in the stream and only skipped at run time when no FM chip is present. The player advances the active stream from the VERA VSYNC IRQ at approximately 60 Hz, including while image blocks are being copied, so image loading does not alter the music tempo. `N` selects the next soundtrack, EOF advances to the next soundtrack (or a random soundtrack in Random mode), switching tracks silences the PSG, resets the FM chip and clears the FM key-on shadow first, VERA address registers are preserved around each music tick, all PSG channels and FM key registers are cleared on exit, and `M` toggles mute.

#### Double-buffered music stream

The player keeps **two** 512-byte tick buffers, `MUSIC_BUF_A` at `$4000` and `MUSIC_BUF_B` at `$4200`; `MUSIC_ACTIVE` (`$2B`) selects the one being decoded. When the IRQ's stream pointer passes the midpoint of the active block (`MUSIC_PTR_H` reaches `MUSIC_MID_H`, `$41` or `$43`), the tick sets `MUSIC_REFILL_PENDING`. `MAIN_LOOP` calls `SERVICE_MUSIC_REQUESTS`, which runs `REFILL_MUSIC_BUFFER`: it picks the inactive buffer, issues one MLI `READ` of the next 512-byte block into it, then publishes it with a short `SEI` window (`MUSIC_REFILL_PENDING = 0`, `MUSIC_NEXT_READY = 1`, `CLI`).

At the end of the active block (`MUSIC_PTR_H` reaching `MUSIC_END_H`, `$42` or `$44`) the IRQ calls `MUSIC_SWITCH_BLOCK`. When `MUSIC_NEXT_READY = 1` it flips `MUSIC_ACTIVE`, points `MUSIC_PTR_L/H`, `MUSIC_MID_H` and `MUSIC_END_H` at the other buffer (`$40/$41/$42` or `$42/$43/$44`), requests the next refill and continues decoding **the same tick**: `TICK_MUSIC` and `MUSIC_DECODE` both resume from the new buffer, so no tick is lost or delayed at a block boundary. The earlier single-buffer player returned from the IRQ at the boundary, dropped that tick and suppressed ticks through `MUSIC_HOLD` until the foreground refilled the buffer (up to the ~16.6 ms idle delay plus any image-load time). Because the FM tracks cross a block boundary roughly every 0.5 s, that produced the periodic FM stutter heard while the slideshow streamed images.

If the foreground has not published the prefetched block yet (`MUSIC_NEXT_READY = 0`), `MUSIC_SWITCH_BLOCK` sets `MUSIC_REFILL_PENDING` and returns `C=1`; the tick is then deferred one frame instead of being decoded from a half-filled buffer. A headless run of the final player measured 75 block switches and **0** deferred switches over ~30 s of `SB-INTRO` playback, one switch per 512-byte block as expected.

The source archive contains additional ZSM files, but they are intentionally excluded from this port because they are FM-only or not reliably audible through the Apple II VERA PSG path. The packaged playlist is limited to the three tested tracks above.

`slideshow.asm` also renders an `F` / `P` mode character next to the music name (`MUSIC:<NAME>   F` in the OSD, and the same character after the name on the text page) so the operator can tell at a glance whether the YM2151 FM chip was detected (`F` = FM+PSG) or the player fell back to PSG only (`P`).

Auto-play is enabled by default with a three-second interval. The launcher displays the slideshow controls after option `1` is selected and automatically launches after 5 seconds or upon any keypress. Slideshow controls are Right/Down (Space is also supported) for next, Left/Up (or `P`) for previous, `N` for next soundtrack, `A` for auto-play, `R` for random mode plus auto-play, `O` to toggle the Layer 1 on-screen display (OSD) status bar, `M` for mute/playback, `+`/`=` and `-`/`_` for master volume (0..15, default 12), and `Esc`/`Q` to return to BASIC. On Apple II, the left arrow is reported as key code `$08` (Backspace).

Master volume is applied to both halves of the soundtrack at once. Every PSG volume write (register `+2` of each voice, level in bits 5..0, stereo pan in bits 7..6) is scaled at play time as `(level * volume + 8) >> 4` with the pan bits carried through unchanged, while the 64-byte `PSG_SHADOW` keeps the unscaled stream values so a volume change can re-derive and re-send all 16 voices. The YM2151 has no global volume register, so `FM_TL_BASE` (`$3B30`) mirrors the 32 operator total-level registers (`$60..$7F`) and `FM_ATTEN_TAB` supplies a TL offset per volume step, matched to the PSG amplitude law so both halves move together: `127, 32, 24, 19, 16, 14, 11, 10, 8, 7, 5, 4, 3, 2, 2, 0` for volumes 0..15 (0.75 dB per TL step, so the default 12 is about −2.25 dB and volume 0 is silent, while 15 is exactly as the tracker authored it); every applied change rewrites all 32 levels from that mirror. Pressing `+`/`-` recomputes the attenuation, restores the PSG voices from the shadow and re-sends the FM total levels under a short `SEI`, so a volume change is heard immediately without a note drop. One hardware detail is easy to get wrong here: the OPM total level is a **7-bit** field (`ymfm_opm.h` → `op_total_level` = `bitfield(0x60, 0, 7)`), so bit 7 of a stream byte is ignored by the chip and must be masked off (`FM_ATTENUATE` does `AND #$7F`) *before* the attenuation is added and saturated. Without that mask, a legitimate level such as `$8A` looks like "already above `$7F`" and gets clamped to `$7F`, i.e. muted — `GREENHILL` writes those values on its carriers from the first tick, which is exactly why its FM half went silent while `SB-INTRO` and `CANYON` still had FM. The volume in force is shown on the Apple II text page as ` VOL:nn` (row 24, columns 16..22), which keeps the graphics OSD badges compact.

Dual status reporting is provided for both single-monitor and multi-monitor setups:
- The slideshow binary writes the current image as `IMG: nnn/375` to Apple II text page 1 (row 24, `$07D0..$07F7`), `MUSIC: <name>` to the bottom-left and the volume as ` VOL:nn` in between.
- In graphics mode, the OSD status bar is rendered directly onto the bottom 8 scanlines of the Mode 7 bitmap (Row 29, scanlines 232..239, VRAM `$12200..$12BFF`): `MUSIC: <NAME>    [MODE]   IMG: nnn / 375`. Precomputed palette LUT tables (`PAL_FG_TABLE` and `PAL_BG_TABLE`) pick optimal white text and black background color indices for each of the 375 custom palettes with 0% palette overwriting and 0% visual noise. When OSD is toggled OFF with `'O'`, the original 2,560 bitmap bytes backed up at RAM `$5000..$59FF` are restored into VRAM in ~12ms.
- In `CANYON.ZSM`, PSG channels are acoustics-balanced (noise percussion attenuated to 55%, melodic voices boosted to 130%) to ensure balanced volume between rhythm and lead.

### 4.4 The VZM Stream Format (ZSM → A2VERA)

The Apple II players never parse ZSM. At build time `src/zsm2vera.mjs` converts each X16 `.ZSM` into a **VZM** ("VERA ZSM") stream — a compact, A2VERA-specific derivative that both `slideshow.asm` and `sonic.asm` decode with a handful of `CMP`/`AND` branches. The conversion keeps every PSG *and* YM2151 write in original order, so nothing is dropped at build time; the FM half is only skipped at run time when no FM chip is present.

Why a derived format instead of reading the raw `.ZSM` on the 6502:

- **No ZSM parser in the player.** ZSM has a 16-byte header and variable-length commands (including `EXTCMD`, whose payload length lives in the command itself). VZM is one length byte per record.
- **YM2151 writes are pre-batched.** A YM2151 register write is two I/O accesses (register select, then data). One ZSM tick often carries a dozen scattered pairs; VZM packs them into at most 32-pair batches that the IRQ drains in a tight loop.
- **PSG and FM are separated per tick**, so a PSG-only card can skip the FM half with one branch.
- **Every record is confined to one 512-byte ProDOS block** (`$E0..$FE` pads the remainder), so an MLI `READ` of one block always yields a complete, decodable tick buffer.
- **Per-track mix curves are baked in** (CANYON's percussion/melody balance), which would otherwise have to be recomputed every frame on a 1 MHz 6502.
- **Redundant writes are dropped**, which is where the size win on dense FM streams comes from. The stream has no header: its length comes from the ProDOS file size (or the `SONICMUS.BIN` block count in `sonic_music.inc`).

| Leading byte | Meaning | Followed by |
| :--- | :--- | :--- |
| `$00..$7F` | Delay. The writes above belong to the current tick; byte `N` adds `N` further ticks (`$00` = the next record starts on the following tick). A ZSM delay of `D` ticks is stored as `D - 1`, so a tick is never counted twice. | — |
| `$80..$BF` | PSG register write: register `= byte & $3F` (`$1F9C0 + reg`) | 1 byte value |
| `$C0..$DF` | YM2151 batch: pair count `= (byte & $1F) + 1` | `count` × (register, value) |
| `$E0..$FE` | Alignment padding, skipped by the player | — |
| `$FF` | End of stream; the player restarts from offset 0 (loop) | — |

Within one tick the converter emits all PSG writes first, then the FM batches in their original order, then the delay record that closes the tick. The YM2151 key register `$08` is stored **verbatim** and never de-duplicated: it is an operator mask in bits 6..3 plus the channel in bits 2..0, a zero mask releases the operators, and a repeated identical write is a legitimate retrigger (see §2.3 and §17).

The first 48 bytes of `src/slideshow/data/greenhill.vzm` are a complete, real example:

```text
83 3f  PSG $3 = $3F       87 3f  PSG $7 = $3F       8b 3f  PSG $B = $3F
8f c0  PSG $F = $C0       80 3a  PSG $0 = $3A       81 09  PSG $1 = $09
84 5f  PSG $4 = $5F       85 0a  PSG $5 = $0A       88 f0  PSG $8 = $F0
89 94  PSG $9 = $94       8c f0  PSG $C = $F0       8d 94  PSG $D = $94
8e f3  PSG $E = $F3       df 08 00 08 03 08 01 ...  FM batch: 32 pairs
```

That `df 08 00 ...` batch is the opening bar: the song releases every FM channel (`$08` with mask 0) before the first note-on. An earlier converter turned those releases into key-ons, which is exactly why the FM part decayed once and then went silent.

| Track | Source `.ZSM` | VZM | Blocks | Ticks | FM writes | `$08` writes |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| `SB-INTRO` | 346,425 B | 347,136 B | 678 | 20,385 | 20,075 | 8,366 |
| `CANYON` | 129,168 B | 124,416 B | 243 | 7,570 | 4,081 | 2,543 |
| `GREENHILL` | 22,337 B | 18,432 B | 36 | 3,192 | 6,561 | 1,890 |

`node src/verify_music_streams.mjs` rebuilds all three streams with the production balance curves, asserts the bytes equal the packaged `.vzm` files, and then replays both the raw ZSM and the converted stream tick by tick, diffing the PSG image, the YM2151 image and the `$08` sequence: 0 mismatched ticks out of 31,147 total.

Raw `.ZSM` playback on the Apple II is also possible (that is what `veramusic`'s melodius player does), but it needs a full ZSM decoder in the player binary and more disk space: `GREENHILL.ZSM` alone is 44 ProDOS blocks against 36 for its VZM, and the 140 KB demo floppy only has 4 blocks free.

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
   - Packaged the 375 images, 375 palettes, and three music files into `/DATA/` with Cadius so ProDOS creates directory and file allocation metadata.
   - Pure 6502 assembly file-level ProDOS streaming engine (`src/slideshow/slideshow.asm`) with interactive keyboard controls (Space/Arrows=Next/Prev, A=Auto, R=Random, ESC=Exit) and zero-flicker palette transitions.
   - Cadius-based HDV builder (`src/slideshow/slideshow_hdv.mjs`) and 560x384 preview generator (`src/slideshow/preview.mjs`).
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
    - Compacted all assets, palette, and PSG stream into one 103-block ProDOS file (`SONIC.DAT`), opened and streamed sequentially with MLI `OPEN`/`READ`/`CLOSE` in 512-byte chunks.
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

16. **Cadius Packaging and File-Level Asset Access Across Both Targets**:
    - Replaced the floppy builder's manual ProDOS directory, bitmap, and allocation writes with Cadius operations against the bootable ProDOS baseline; the output volume is named `VERATEST`.
    - Bundled `tools/cadius.exe` and configured both floppy and HDV builders to use it by default, with `CADIUS` as an override.
    - Sonic loads `SONIC.DAT` using ProDOS `OPEN`/`READ`/`CLOSE`. The slideshow resolves image and palette allocation through ProDOS catalog/index entries and reads those allocated blocks, without fixed physical block or contiguity assumptions.

17. **VERA FM Chip Support (`feat/verafm`)**:
    - Added `src/vera_fm.inc`: `$Cs20`/`$Cs21` signature detection (write `$5A`/`$A5`, read back, restore), chip reset, a `VERA_FM_WRITE` helper that tracks the last `$08` key value per channel, and `VERA_FM_KEY_OFF_ALL` / `VERA_FM_RESTORE_KEYS` for clean exits.
    - Added `src/zsm2vera.mjs` and `src/music_streams.mjs`: ZSM tracks are now converted to a compact VZM byte stream that keeps both the PSG writes and the batched YM2151 register pairs (`SB-INTRO` 678 blocks / `CANYON` 243 / `GREENHILL` 36), instead of discarding the FM half.
    - `slideshow.asm` streams those VZM files from `/DATA`, decodes PSG and FM records in one 512-byte tick buffer, mutes/restores FM together with PSG, resets the FM chip on track change and exit, and shows an `F`/`P` mode character in the OSD and text page.
    - `sonic.asm` decodes the same VZM format with a 60 Hz VERA VSYNC IRQ player, so demo 7 plays the original Green Hill FM arrangement plus PSG. The 18,432-byte stream (`GREENHILL.VZM`, 36 blocks) is no longer copied into RAM by the demo: it ships as `SONICMUS.BIN` (ProDOS type `BIN`, aux `$4800`, 36 blocks) and the `STARTUP` menu `BLOAD`s it before `BRUN SONIC.BIN`. In-demo MLI `READ`s are only used for the 88-block asset container `SONIC.DAT`.
    - Three root causes were found for demo 7's earlier noise-only output. First, the VZM FM batch header stores `count - 1` (`$C0..$DF`), but both players used it as the pair count, so every batch decoded one pair short and — for one-pair batches — underflowed to 255 and ran away through the stream. Both decoders now use `count = (byte & $1F) + 1`. Second, and this was the one that made the FM part die after a few seconds: the OPM key register `$08` is *operator mask in bits 6..3, channel in bits 2..0*, the chip ignores bit 7 and a **zero mask releases the operators**. An earlier version "translated" the register into a hypothetical bit-7 key flag and rewrote every key-off into a key-on (mask `$0F`); each channel was therefore keyed on once, its envelope decayed and never re-triggered — heard as "the music stops after a moment". `src/zsm2vera.mjs` now forwards `$08` **verbatim** and never de-duplicates it (a repeated identical key-on is a legitimate retrigger). The reference implementation agrees: `veramusic/tools/zsm2psg.mjs` treats a non-zero mask as key-on and ymfm (`source/ymfm/ymfm_opm.cpp`, `channel = bitfield(data,0,3); opmask = bitfield(data,3,4)`) derives the key state from the mask only.
    - The converter was then re-verified against the raw ZSM by replaying the PSG *and* FM writes tick by tick and comparing the resulting register image: **0 mismatched ticks** out of 3,192 (`GREENHILL`), 7,570 (`CANYON`) and 20,385 (`SB-INTRO`), with the `$08` write sequence identical in all three songs (1,890 / 2,543 / 8,366 key writes). The player therefore hands the FM chip exactly the writes the tracker emitted — the same writes melodius forwards — so the FM arrangement sounds like the original ZSM.
    - Verified in AppleWin (slot 2 VERA + slot 7 HD, `-m`): all 36 music blocks stay byte-identical to the source `.vzm` while playing, the stream pointer advances at the original tempo (≈274 B/s, 3,191 ticks ≈ 53 s per loop), and the `$08` shadow shows masks going on and off (key-ons and releases) instead of latching on.
    - The check is checked in as `src/verify_music_streams.mjs` (`node src/verify_music_streams.mjs`): it rebuilds the three streams with the production balance curves, asserts the bytes match the packaged `.vzm` files, then diffs the register image and the `$08` sequence tick by tick, so a converter regression fails the tool instead of shipping.
    - A third fix keeps the music safe from ProDOS: `$4000..$41FF` is a 512-byte BASIC/ProDOS scratch buffer that is clobbered during the `BLOAD`s, which is why the stream now loads at `$4800` instead of `$4000`.
    - `spritesnd.asm` adds FM percussion when the FM chip is present and nothing else: `FM_LOAD_PATCH` programs channel 2 with the kick voice and channel 3 with the snare/hat voice lifted from `SB-INTRO.ZSM`, `FM_STEP` triggers them on the PSG drum grid, and `FM_DRUM_TICK` replays the soundtrack's six-frame key-code/key-fraction dive (`32 → 02`, `68 → C8`) once per video frame so the kick thumps instead of beeping. FM channels 0 and 1 stay silent: the earlier versions doubled the PSG lead/bass with an FM patch (`fm_notes.mjs`, `FM_LAST0`/`FM_LAST1`), first as a loud "wong wong" drone, then as an inaudible −24 dB layer, and both read as a detuned second player rather than a harmony, so the melody layer and its generated tables were removed along with the `fm_notes.mjs` build step.
    - Both `STARTUP` menus report the probe result as `STATUS: YM2151 (OPM) FM CHIP FOUND` or `STATUS: NO YM2151 (OPM) FM CHIP FOUND` (the probe reports the chip itself), and every demo A/B test in AppleWin shows a clear level and timbre difference between FM enabled and disabled.

18. **Double-Buffered Music Stream for Stutter-Free Slideshow Playback (`src/slideshow/slideshow.asm`)**:
    - The single 512-byte tick buffer made every block boundary cost a music tick: the IRQ returned at the end of the block, dropped that tick, and `MUSIC_HOLD` suppressed further ticks until the foreground refilled the buffer (up to the ~16.6 ms idle delay, longer while image blocks were streamed). The FM tracks cross a block boundary about every 0.5 s, so the FM layer audibly stuttered while images were shown.
    - The player now keeps two tick buffers (`MUSIC_BUF_A` at `$4000`, `MUSIC_BUF_B` at `$4200`) and asks for a prefetch from the IRQ once the active pointer passes the block midpoint. `MAIN_LOOP`'s `SERVICE_MUSIC_REQUESTS` reads the next block into the inactive buffer and publishes it atomically under `SEI`.
    - At the block end the IRQ switches buffers and continues decoding the same tick (`TICK_MUSIC` / `MUSIC_DECODE`), so no tick is dropped or delayed; a late prefetch defers one frame instead of decoding a half-filled buffer. A headless AppleWin run measured 75 block switches and 0 deferred switches over ~30 s of `SB-INTRO` playback.
    - **End of stream is a normal event, not a disk error.** Because the prefetch runs one block ahead, the last block of a track always asks ProDOS for a block past the end of the file; ProDOS answers with a short/zero-length transfer (the MLI `END OF FILE` condition, `$27`). The first version treated that as a read failure and went through `CANYON_LOAD_FAIL`, which set `MUSIC_MUTE` and left the last FM chord ringing with no track change — audible as "the tail never stops and the next song never starts". `REFILL_MUSIC_BUFFER` now recognises the short read and writes an `$FF` terminator at the start of the inactive buffer, so the pending switch decodes `$FF`, `MUSIC_RESTART` advances `MUSIC_INDEX` and `MUSIC_SELECT` silences the PSG and resets the FM chip exactly as at a stream's own `$FF`. The single-buffer player never prefetched past the end, which is why the bug only appeared with double buffering. Verified with a test volume whose first track is the 53-second `GREENHILL` stream: `MUSIC_INDEX` moved 0 → 1 → 2 (`SB-INTRO` → `CANYON` → `GREENHILL`) with `MUSIC_MUTE = 0` and the OSD name following along.

19. **Master Volume Control for PSG + FM (`src/slideshow/slideshow.asm` / `src/slideshow/startup.bas`)**:
    - Added `+`/`=` (key codes `$2B`, `$3D`) and `-`/`_` (`$2D`, `$5F`) as master volume up/down; `MUSIC_VOL` lives at `$440F` (page `$44`, next to `FM_KEYS`, because zero page `$20-$29` is the ROM text-window state) and the range is clamped to 0..15 with a default of 12.
    - PSG scaling happens where the voice registers reach VERA: `MUSIC_PSG_WRITE` and `RESTORE_PSG_FROM_SHADOW` scale the level field (`(level * vol + 8) >> 4`) and OR the pan bits back, so the pan is never touched. `PSG_SHADOW` keeps the original stream values, which is what lets `+`/`-` re-derive every voice immediately; volume 0 leaves just the pan (silence) and volume 15 passes the stream bytes through untouched.
    - The YM2151 has no global volume, so `FM_TL_BASE` (`$3B30`, 32 bytes) mirrors the operator total-level registers `$60..$7F` and `FM_ATTEN_TAB` maps volume to a TL offset matched to the PSG amplitude law, so both halves move together: `127, 32, 24, 19, 16, 14, 11, 10, 8, 7, 5, 4, 3, 2, 2, 0` for volumes 0..15 (0.75 dB per TL step; default 12 is about −2.25 dB, 15 is exactly as the tracker authored it, 0 is silent). Every stream write to `$60..$7F` is captured as a base value and sent out attenuated; `FM_APPLY_VOLUME` rewrites all 32 levels from the mirror. Two placement/capture bugs had to be fixed first: `FM_TL_BASE` must not live at `$4410` (that range sat on top of the OSD name strings), and the register byte has to be taken from the stream itself (`STA VOL_TMP` before `MUSIC_ADVANCE_1`) because `$Cs20` cannot be read back — the earlier `LDX YM_REG` left the mirror all-zero, so `FM_APPLY_VOLUME` kept writing TL 3 across every operator and the FM half played at a fixed, tracker-independent loudness that buried the PSG (heard as "the knob only moves FM, PSG is almost gone").
    - `VOLUME_UP`/`VOLUME_DOWN` recompute the attenuation, then re-send the PSG shadow and the FM levels inside one short `SEI` block (skipped while `MUSIC_MUTE` is set, so a volume change never unmutes) and update the readout.
    - The volume readout is text-page only, at row 24 columns 16..22 (`$07E0..$07E6`, ` VOL:nn`), between the music badge and `IMG: nnn/375`; the graphics OSD keeps its compact `MUSIC:<NAME> F` / `IMG: nnn/375` badges. `RESET_FM_TL_SHADOW` re-zeroes the mirror at start and after every `VERA_FM_RESET`.
    - The launcher documents the new keys (`  [+/-]  : VOLUME UP/DOWN`) on both the pre-launch screen and the ABOUT page, and the previously over-long menu lines were shortened so no launcher string exceeds 40 columns.
    - `GREENHILL` still dropped its FM half after the capture fix above. The remaining cause was the saturation step in `FM_ATTENUATE`: it compared the raw stream byte against `$80` and clamped anything at or above it to `$7F`. The OPM total level is a **7-bit** field (`ymfm_opm.h` → `op_total_level` = `bitfield(0x60, 0, 7)`), so the chip ignores bit 7 — but the streams leave it set in places (`$8A`, `$94`, `$9D`) and `GREENHILL` writes those levels on its carriers from the first tick, so every one of them became maximum attenuation, i.e. silence. `FM_ATTENUATE` now masks bit 7 first (`AND #$7F`), then adds `FM_ATTEN` and saturates, which is exactly what the chip does. `SB-INTRO` and `CANYON` rarely use such values, which is why only the third track lost its FM.
    - That fix was verified from the chip's own output instead of by ear: a test volume whose first track is the `GREENHILL` stream, run headless in AppleWin with `-fm-wav-dump`, produces an almost all-zero WAV before the fix and peaks at 13,676 (≈ −7.6 dBFS) after it — about +13 dB, FM present for the whole loop. The regenerated `src/slideshow/data/greenhill.vzm` is byte-identical to the committed one (SHA256 `D5675A0F…679AC1BC5`), so the stream itself was never the problem.
    - Headless AppleWin verification (slot 2 VERA, 24 M cycles, `-save-state` + `-vera-dump`): the default run reports `MUSIC_VOL = 12`, `FM_ATTEN = 3`, `MUSIC_MUTE = 0`, the PSG block `$1F9C0..` holding live voice data with the pan bits intact, `MUSIC_NEXT_READY = 1` (prefetch running) and the text page showing `MUSIC:SB-INTRO F VOL:12      IMG:004/375`. `FM_TL_BASE` and `FM_KEYS` are still all-zero at that point because `SB-INTRO`'s FM arrangement only enters at stream offset 31,232 (~114 s at ≈274 B/s), so the first minutes of track 1 are PSG-only *by content* — `CANYON` and `GREENHILL` carry FM from the first tick.




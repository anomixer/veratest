// =============================================================================
// SONIC.DAT packager
// =============================================================================
//
// Packs the Sonic assets and the PSG+FM Green Hill music stream into one
// ProDOS-friendly container.  The music comes last so the sequential MLI
// reader can load it with a single destination pointer, and the block count is
// exported through sonic_music.inc for the 6502 driver.
// =============================================================================

import fs from "fs"
import path from "path"
import { fileURLToPath, pathToFileURL } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const defaultDir = "C:/dev/emu/x16emu/x16/SDCARD/DEMOS/SONIC"
const x16SonicDir = fs.existsSync(defaultDir) ? defaultDir : "C:/dev/sonicdemo"
const outDatPath = path.join(__dirname, "sonic.dat")

// Block 0: 512-byte Palette
// Blocks 1..2: 1024-byte Flower frames
// Blocks 3..10: 8 blocks (4096 bytes) BG tilemap
// Blocks 11..18: 8 blocks (4096 bytes) FG tilemap
// Blocks 19..82: 64 blocks (32768 bytes) Tileset
// Blocks 83..87: 5 blocks (2560 bytes) Sprites
// Blocks 88..: PSG+FM Music stream (block padded)
const MUSIC_LOAD_ADDR = 0x4800

// 1. Load Raw Assets (Strip 2-byte CBM PRG load address header)
const loadPrgData = (filename) => {
  const p = path.join(x16SonicDir, filename)
  if (!fs.existsSync(p)) {
    throw new Error(`Asset not found: ${p}. Ensure x16emu DEMOS/SONIC assets are present.`)
  }
  const buf = fs.readFileSync(p)
  return buf.subarray(2)
}

// 2. Palette Data from demo.asm (80 colors = 160 bytes, 12-bit RGB little endian)
const paletteWords = [
  0x09f, 0x000, 0x229, 0x44b, 0x66d, 0x99f, 0xfff, 0xbbb,
  0x999, 0x444, 0xfb9, 0xb64, 0xf00, 0x900, 0x400, 0xff0,

  0x009, 0x000, 0x242, 0x464, 0x696, 0x9d9, 0xfff, 0xbbb,
  0x999, 0x444, 0xbf9, 0xb64, 0xff0, 0x990, 0x440, 0xf00,

  0x09f, 0x200, 0xfff, 0x620, 0x940, 0xd60, 0xf90, 0xfd0,
  0x69b, 0x69f, 0x9bf, 0xbdf, 0x040, 0x060, 0x4b0, 0x9f0,

  0x29d, 0x20b, 0x24d, 0x69f, 0xbdf, 0xdff, 0xfff, 0xdbf,
  0xb9f, 0x96f, 0x9f0, 0x4b0, 0x200, 0x620, 0xd60, 0xfd0,

  0x000, 0x000, 0xfff, 0xeac, 0x97d, 0x18c, 0x6ad, 0x9ef,
  0x5cb, 0x3c8, 0xac5, 0xfc5, 0xfb5, 0xf85, 0xf64, 0xf54
]

const buildPalette = () => {
  const palBuf = new Uint8Array(512) // Full 256-color palette buffer initialized to 0
  for (let i = 0; i < paletteWords.length; i++) {
    const w = paletteWords[i]
    // Little-endian VERA RGB format: Byte 0: [G4 B4], Byte 1: [0 R4]
    const r = (w >> 8) & 0x0F
    const g = (w >> 4) & 0x0F
    const b = w & 0x0F
    palBuf[i * 2] = (g << 4) | b
    palBuf[i * 2 + 1] = r
  }
  return palBuf
}

export const buildSonicDat = () => {
  const bgData = loadPrgData("BG.BIN")            // 4096 bytes
  const fgData = loadPrgData("FG.BIN")            // 4096 bytes
  const tilesData = loadPrgData("TILESET.BIN")    // 32768 bytes
  const spritesData = loadPrgData("SPRITES.BIN")  // 2560 bytes
  const flowerData = loadPrgData("FLOWER.BIN")    // 1024 bytes

  // 3. Load the generated VZM stream (VERA PSG + YM2151 FM) shared with the
  // slideshow, so both demos play exactly the same Green Hill arrangement.
  const musicPath = path.resolve(__dirname, "..", "slideshow", "data", "greenhill.vzm")
  if (!fs.existsSync(musicPath)) {
    throw new Error(`Green Hill VZM stream not found at ${musicPath}! Build the music streams first.`)
  }
  const music = fs.readFileSync(musicPath)
  if (music.length % 512 !== 0) {
    throw new Error(`Green Hill stream must be block padded (got ${music.length} bytes)`)
  }
  const musicBlocks = music.length / 512
  if (MUSIC_LOAD_ADDR + music.length > 0xbc00) {
    throw new Error(
      `Green Hill stream ends at $${(MUSIC_LOAD_ADDR + music.length).toString(16)}, too large for the RAM window`
    )
  }

  // The Green Hill stream is no longer packed into SONIC.DAT: it ships as its own
  // BLOAD-able binary (SONICMUS.BIN, load address $4000) so the 6502 loader never
  // has to shadow ProDOS file buffers with a 17.9 KB self-modifying RAM copy.
  const assetBlocks = 1 + 2 + 8 + 8 + 64 + 5 // 88 blocks
  const totalBlocks = assetBlocks
  const dat = new Uint8Array(totalBlocks * 512)

  let blk = 0

  // Block 0: Palette (1 block)
  dat.set(buildPalette(), blk * 512)
  blk += 1

  // Blocks 1..2: Flower frames (2 blocks)
  dat.set(flowerData, blk * 512)
  blk += 2

  // Blocks 3..10: BG tilemap (8 blocks)
  dat.set(bgData, blk * 512)
  blk += 8

  // Blocks 11..18: FG tilemap (8 blocks)
  dat.set(fgData, blk * 512)
  blk += 8

  // Blocks 19..82: Tileset (64 blocks)
  dat.set(tilesData, blk * 512)
  blk += 64

  // Blocks 83..87: Sprites (5 blocks)
  dat.set(spritesData, blk * 512)
  blk += 5

  // The music tail lives in SONICMUS.BIN (see veratest.mjs) and is BLOADed by the
  // STARTUP menu, so this container holds only the video/sprite assets.

  fs.writeFileSync(outDatPath, dat)
  fs.writeFileSync(
    path.join(__dirname, "sonic_music.inc"),
    [
      "; ============================================================================",
      "; GENERATED by build_sonic_dat.mjs - do not edit by hand.",
      "; Size and load address of the PSG+FM Green Hill stream, which ships as",
      "; SONICMUS.BIN and is BLOADed to $4000 before the demo starts.",
      "; ============================================================================",
      "",
      `MUSIC_BLOCKS = ${musicBlocks}`,
      `MUSIC_LOAD_ADDR = $${MUSIC_LOAD_ADDR.toString(16)}`,
      "",
    ].join("\n")
  )

  console.log(`Successfully generated ${outDatPath}:`)
  console.log(`  Total blocks: ${totalBlocks} (${dat.length} bytes)`)
  console.log(`  Palette: block 0 (512 B)`)
  console.log(`  Flower:  blocks 1..2 (1024 B)`)
  console.log(`  BG map:  blocks 3..10 (${bgData.length} B)`)
  console.log(`  FG map:  blocks 11..18 (${fgData.length} B)`)
  console.log(`  Tileset: blocks 19..82 (${tilesData.length} B)`)
  console.log(`  Sprites: blocks 83..87 (${spritesData.length} B)`)
  console.log(`  Music:   ${music.length} B (PSG+FM) shipped separately as SONICMUS.BIN at $${MUSIC_LOAD_ADDR.toString(16)}`)

  return { totalBlocks, musicBlocks, bytes: dat.length, music }
}

// Allow `node src/veratest/build_sonic_dat.mjs` for standalone refreshes.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  buildSonicDat()
}

import fs from "fs"
import path from "path"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const defaultDir = "C:/dev/emu/x16emu/x16/SDCARD/DEMOS/SONIC"
const x16SonicDir = fs.existsSync(defaultDir) ? defaultDir : "C:/dev/sonicdemo"
const outDatPath = path.join(__dirname, "sonic.dat")

// 1. Load Raw Assets (Strip 2-byte CBM PRG load address header)
const loadPrgData = (filename) => {
  const p = path.join(x16SonicDir, filename)
  if (!fs.existsSync(p)) {
    throw new Error(`Asset not found: ${p}. Ensure x16emu DEMOS/SONIC assets are present.`)
  }
  const buf = fs.readFileSync(p)
  return buf.subarray(2)
}

const bgData = loadPrgData("BG.BIN")          // 4096 bytes
const fgData = loadPrgData("FG.BIN")          // 4096 bytes
const tilesData = loadPrgData("TILESET.BIN")  // 32768 bytes
const spritesData = loadPrgData("SPRITES.BIN")// 2560 bytes
const flowerData = loadPrgData("FLOWER.BIN")  // 1024 bytes

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

// 3. Load PSG Music Stream from verified greenhill_embedded.bin
const greenhillPath = path.resolve(__dirname, "..", "slideshow", "data", "greenhill_embedded.bin")
if (!fs.existsSync(greenhillPath)) {
  throw new Error(`Verified Green Hill PSG stream not found at ${greenhillPath}!`)
}
const psgMusic = fs.readFileSync(greenhillPath)

// 4. Layout of SONIC.DAT:
// Block 0: 512-byte Palette
// Blocks 1..2: 1024-byte Flower frames
// Blocks 3..17: 15 blocks (7680 bytes) PSG Music stream (padded with 0xFF)
// Blocks 18..25: 8 blocks (4096 bytes) BG tilemap
// Blocks 26..33: 8 blocks (4096 bytes) FG tilemap
// Blocks 34..97: 64 blocks (32768 bytes) Tileset
// Blocks 98..102: 5 blocks (2560 bytes) Sprites
const totalBlocks = 1 + 2 + 15 + 8 + 8 + 64 + 5 // 103 blocks = 52,736 bytes
const dat = new Uint8Array(totalBlocks * 512)

let blk = 0

// Block 0: Palette (1 block)
dat.set(palBuf, blk * 512)
blk += 1

// Blocks 1..2: Flower frames (2 blocks)
dat.set(flowerData, blk * 512)
blk += 2

// Blocks 3..17: PSG Music (15 blocks, 7680 bytes)
dat.fill(0xFF, blk * 512, (blk + 15) * 512)
dat.set(psgMusic, blk * 512)
blk += 15

// Blocks 18..25: BG tilemap (8 blocks)
dat.set(bgData, blk * 512)
blk += 8

// Blocks 26..33: FG tilemap (8 blocks)
dat.set(fgData, blk * 512)
blk += 8

// Blocks 34..97: Tileset (64 blocks)
dat.set(tilesData, blk * 512)
blk += 64

// Blocks 98..102: Sprites (5 blocks)
dat.set(spritesData, blk * 512)
blk += 5

fs.writeFileSync(outDatPath, dat)
console.log(`Successfully generated ${outDatPath}:`)
console.log(`  Total blocks: ${totalBlocks} (${dat.length} bytes)`)
console.log(`  Palette: block 0 (512 B)`)
console.log(`  Flower:  blocks 1..2 (1024 B)`)
console.log(`  Music:   blocks 3..17 (${psgMusic.length} B)`)
console.log(`  BG map:  blocks 18..25 (${bgData.length} B)`)
console.log(`  FG map:  blocks 26..33 (${fgData.length} B)`)
console.log(`  Tileset: blocks 34..97 (${tilesData.length} B)`)
console.log(`  Sprites: blocks 98..102 (${spritesData.length} B)`)

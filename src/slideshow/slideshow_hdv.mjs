import fs from "fs"
import path from "path"
import { fileURLToPath } from "url"
import { assembleAsmFile } from "../asm6502.mjs"
import { compileApplesoftBasic } from "../applebasic.mjs"
import { generateSlideshowPreviewPng } from "./preview.mjs"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(__dirname, "../..")
const srcDir = path.resolve(projectRoot, "src")
const slideshowDir = path.resolve(srcDir, "slideshow")
const x16SlideshowDataDir = path.resolve(slideshowDir, "data")
const baseHdvPath = path.resolve(projectRoot, "assets/ProDOS 2.4.3.hdv")

// Convert the X16 ZSM stream to the compact VERA-PSG stream consumed by the
// Apple II player. YM2151 commands are ignored because Apple2TS exposes the
// VERA PSG, not the X16 FM chip.
const MUSIC_NAMES = ["SB-INTRO", "CANYON", "GREENHILL"]
const MUSIC_START_BLOCK = 800
const MUSIC_SLOT_BLOCKS = 600
const BLOCK_SIZE = 512
const compileZsmStream = (name) => {
  const raw = fs.readFileSync(path.resolve(x16SlideshowDataDir, `${name}.ZSM`))
  const embeddedPath = path.resolve(x16SlideshowDataDir, `${name.toLowerCase()}_embedded.bin`)
  const stream = []
  let ptr = 16

  while (ptr < raw.length) {
    const command = raw[ptr++]

    if (command < 0x40) {
      const value = raw[ptr++]
      // Keep two-byte PSG writes inside one 512-byte disk block so the
      // 6502 streaming player never has to handle a split record.
      if ((stream.length & 0x1FF) === 0x1FF) stream.push(0)
      stream.push(0x80 | command, value)
      continue
    }

    if (command === 0x40) {
      // EXTCMD: the following byte contains the extension channel and the
      // number of payload bytes.  The Apple II port has no PCM/FM extension.
      const ext = raw[ptr++]
      ptr += ext & 0x3F
      continue
    }

    if (command < 0x80) {
      // FM write: low six bits specify the number of register/value pairs.
      // Skip the complete batch; consuming only one pair desynchronizes the
      // stream and produces the exact delayed garbage heard in the port.
      ptr += (command & 0x3F) * 2
      continue
    }

    if (command === 0x80) break

    // Delay commands encode 1..127 ticks as 0x81..0xFF.  The compact player
    // stores the remaining tick count, so subtract one from each chunk.
    let delay = command & 0x7F
    while (delay > 0) {
      const chunk = Math.min(delay, 127)
      stream.push(chunk - 1)
      delay -= chunk
    }
  }

  stream.push(0xFF)
  fs.writeFileSync(embeddedPath, Buffer.from(stream))
  return { data: Buffer.from(stream), path: embeddedPath }
}

const musicStreams = MUSIC_NAMES.map(name => {
  const result = compileZsmStream(name)
  console.log(`  🎵 Converting ${name}.ZSM to VERA PSG stream (${result.data.length} bytes)...`)
  if (Math.ceil(result.data.length / BLOCK_SIZE) > MUSIC_SLOT_BLOCKS) {
    throw new Error(`${name}.ZSM exceeds the ${MUSIC_SLOT_BLOCKS}-block music slot`)
  }
  return result.data
})

console.log("🚀 Building 32MB ProDOS 2.4.3 Slideshow Hard Disk Image (Ultra-Reliable Direct Block Architecture)...")

// 1. Compile 6502 Assembly Slideshow Engine for Slot 2 & Slot 4
console.log("  ⚙️ Compiling SLIDESHOW.BIN (Slot 2 & Slot 4)...")
const slideshow2 = assembleAsmFile(slideshowDir, "slideshow.asm", 2, 0x2000)
const slideshow4 = assembleAsmFile(slideshowDir, "slideshow.asm", 4, 0x2000)

// 2. Compile Applesoft BASIC Startup Menu
console.log("  ⚙️ Compiling STARTUP BASIC script...")
const startup = compileApplesoftBasic(slideshowDir, "startup.bas")

// 3. Initialize 32MB ProDOS Hard Disk using authentic ProDOS 2.4.3.hdv baseline
const TOTAL_BLOCKS = 65535
const disk = new Uint8Array(TOTAL_BLOCKS * BLOCK_SIZE)

if (!fs.existsSync(baseHdvPath)) {
  throw new Error(`Base ProDOS 2.4.3.hdv not found at ${baseHdvPath}!`)
}

// Copy the clean, bootable 32MB ProDOS baseline (includes PRODOS, CLOCK.SYSTEM, BITSY.BOOT, QUIT.SYSTEM, BASIC.SYSTEM)
const baseData = fs.readFileSync(baseHdvPath)
disk.set(baseData)

// 4. Setup Volume Directory Header in Block 2
const VOL_NAME = "SLIDESHOW"
const volBase = 2 * BLOCK_SIZE
disk[volBase + 0x04] = 0xF0 | (VOL_NAME.length & 0x0F)
for (let i = 0; i < 15; i++) {
  disk[volBase + 0x05 + i] = i < VOL_NAME.length ? VOL_NAME.charCodeAt(i) : 0x00
}

// Filter base entries: remove QUIT.SYSTEM and BITSY.BOOT so ProDOS directly launches BASIC.SYSTEM -> STARTUP
const preservedBaseEntries = []
for (let i = 1; i <= 12; i++) {
  const off = volBase + 4 + i * 39
  const stLen = disk[off]
  if (stLen === 0) continue
  const nameLen = stLen & 0x0F
  const name = String.fromCharCode(...disk.subarray(off + 1, off + 1 + nameLen))
  const entryData = disk.slice(off, off + 39)

  if (name === "QUIT.SYSTEM" || name === "BITSY.BOOT") {
    console.log(`  🗑️ Removed ${name} to enable direct BASIC STARTUP boot!`)
  } else {
    preservedBaseEntries.push(entryData)
  }
}

// Clear old entries in Block 2
for (let i = 1; i <= 12; i++) {
  disk.fill(0, volBase + 4 + i * 39, volBase + 4 + (i + 1) * 39)
}

// Rewrite preserved entries (e.g. PRODOS, CLOCK.SYSTEM, BASIC.SYSTEM)
for (let i = 0; i < preservedBaseEntries.length; i++) {
  const off = volBase + 4 + (i + 1) * 39
  disk.set(preservedBaseEntries[i], off)
}

// 5. Block Allocation Tracker (Blocks 0..99 reserved for bootloader & base system files)
let nextFreeBlock = 100
let allocatedBlocks = new Set()
for (let b = 0; b < 100; b++) allocatedBlocks.add(b)

function allocateBlock() {
  while (allocatedBlocks.has(nextFreeBlock)) {
    nextFreeBlock++
  }
  const b = nextFreeBlock++
  allocatedBlocks.add(b)
  return b
}

function allocateProDosData(data) {
  const size = data.length
  let keyBlock = 0
  let totalBlocks = 0
  let storageType = 1

  if (size === 0) {
    storageType = 1
    keyBlock = allocateBlock()
    totalBlocks = 1
  } else if (size <= 512) {
    storageType = 1
    keyBlock = allocateBlock()
    disk.set(data, keyBlock * BLOCK_SIZE)
    totalBlocks = 1
  } else {
    storageType = 2
    keyBlock = allocateBlock()
    const indexData = new Uint8Array(512)
    const numDataBlocks = Math.ceil(size / 512)
    totalBlocks = 1 + numDataBlocks

    for (let i = 0; i < numDataBlocks; i++) {
      const dataBlock = allocateBlock()
      const chunk = data.subarray(i * 512, Math.min(size, (i + 1) * 512))
      disk.set(chunk, dataBlock * BLOCK_SIZE)
      indexData[i] = dataBlock & 0xFF
      indexData[i + 256] = (dataBlock >> 8) & 0xFF
    }
    disk.set(indexData, keyBlock * BLOCK_SIZE)
  }

  return { storageType, keyBlock, totalBlocks, eof: size }
}

// 6. Add App Files: STARTUP, SLIDESHOW.BIN, SLIDSHW4.BIN to Root Directory
let rootEntries = []

function addRootEntry(filename, fileType, auxType, fileInfo) {
  rootEntries.push({
    name: filename.toUpperCase(),
    storageType: fileInfo.storageType,
    fileType,
    keyBlock: fileInfo.keyBlock,
    totalBlocks: fileInfo.totalBlocks,
    eof: fileInfo.eof,
    auxType,
  })
}

console.log("  📦 Adding STARTUP, SLIDESHOW.BIN, SLIDSHW4.BIN to Root Directory...")
addRootEntry("STARTUP", 0xFC, 0x0801, allocateProDosData(startup))
addRootEntry("SLIDESHOW.BIN", 0x06, 0x2000, allocateProDosData(slideshow2))
addRootEntry("SLIDSHW4.BIN", 0x06, 0x2000, allocateProDosData(slideshow4))

// Reserve fixed-size music slots so the 6502 player can switch songs without
// pathname parsing. Each slot is large enough for the bundled ZSM streams.
for (let i = 0; i < musicStreams.length; i++) {
  const musicData = musicStreams[i]
  const slotStart = MUSIC_START_BLOCK + i * MUSIC_SLOT_BLOCKS
  disk.set(musicData, slotStart * BLOCK_SIZE)
  for (let b = 0; b < MUSIC_SLOT_BLOCKS; b++) allocatedBlocks.add(slotStart + b)
}
console.log(`  🎼 Packed ${musicStreams.length} music streams in blocks ${MUSIC_START_BLOCK}-${MUSIC_START_BLOCK + musicStreams.length * MUSIC_SLOT_BLOCKS - 1}...`)

// 7. Discover all paired slideshow assets bundled in the repository.
const imageNumbers = fs.readdirSync(x16SlideshowDataDir)
  .filter(name => /^IMG\d{3}\.BIN$/i.test(name))
  .map(name => Number(name.slice(3, 6)))
  .sort((a, b) => a - b)
const START_IMAGE_BLOCK = 6000
const MAX_IMAGE_COUNT = Math.floor((TOTAL_BLOCKS - START_IMAGE_BLOCK) / 152)
if (imageNumbers.length > MAX_IMAGE_COUNT) {
  throw new Error(`Too many slideshow images: ${imageNumbers.length}; 32MB HDV supports ${MAX_IMAGE_COUNT}`)
}
for (const imageNumber of imageNumbers) {
  const numStr = imageNumber.toString().padStart(3, "0")
  if (!fs.existsSync(path.join(x16SlideshowDataDir, `VPAL${numStr}.BIN`))) {
    throw new Error(`Missing palette for IMG${numStr}.BIN`)
  }
}

// 8. Setup /DATA Subdirectory (enough blocks for every registered asset)
const SUBDIR_START_BLOCK = 150
const DATA_ENTRY_COUNT = imageNumbers.length * 2
const SUBDIR_BLOCK_COUNT = 1 + Math.ceil(Math.max(0, DATA_ENTRY_COUNT - 12) / 13)
for (let b = 0; b < SUBDIR_BLOCK_COUNT; b++) {
  const blkNum = SUBDIR_START_BLOCK + b
  allocatedBlocks.add(blkNum)
  disk.fill(0, blkNum * BLOCK_SIZE, (blkNum + 1) * BLOCK_SIZE)
  // Double-linked directory blocks
  const prevBlk = b === 0 ? 0 : blkNum - 1
  const nextBlk = b === SUBDIR_BLOCK_COUNT - 1 ? 0 : blkNum + 1
  disk[blkNum * BLOCK_SIZE + 0x00] = prevBlk & 0xFF
  disk[blkNum * BLOCK_SIZE + 0x01] = (prevBlk >> 8) & 0xFF
  disk[blkNum * BLOCK_SIZE + 0x02] = nextBlk & 0xFF
  disk[blkNum * BLOCK_SIZE + 0x03] = (nextBlk >> 8) & 0xFF
}

// Subdirectory Header in Block 150 Entry 0 (Offset subBase + 4)
const subBase = SUBDIR_START_BLOCK * BLOCK_SIZE
const subHeader = subBase + 4
const SUB_NAME = "DATA"
disk[subHeader + 0x00] = 0xE0 | (SUB_NAME.length & 0x0F)
for (let i = 0; i < 15; i++) {
  disk[subHeader + 0x01 + i] = i < SUB_NAME.length ? SUB_NAME.charCodeAt(i) : 0x00
}
disk[subHeader + 0x1E] = 0xC3
disk[subHeader + 0x1F] = 0x27 // Entry Length (39)
disk[subHeader + 0x20] = 0x0D // Entries per block (13)
disk[subHeader + 0x21] = DATA_ENTRY_COUNT & 0xFF // Active file count
disk[subHeader + 0x22] = (DATA_ENTRY_COUNT >> 8) & 0xFF
disk[subHeader + 0x23] = 0x02 // Parent Pointer (Volume Block 2)
disk[subHeader + 0x24] = 0x00
disk[subHeader + 0x25] = preservedBaseEntries.length + rootEntries.length + 1 // Parent Entry Num
disk[subHeader + 0x26] = 0x27 // Parent Entry Length (39)

// Add DATA Directory Entry to Root Directory
addRootEntry("DATA", 0x0F, 0x0200, {
  storageType: 0x0D,
  keyBlock: SUBDIR_START_BLOCK,
  totalBlocks: SUBDIR_BLOCK_COUNT,
  eof: SUBDIR_BLOCK_COUNT * 512
})

// 9. Store every image and palette sequentially (152 blocks per slot).
console.log(`  📁 Packing ${DATA_ENTRY_COUNT} Files (${imageNumbers.length} Images & ${imageNumbers.length} Palettes) into /DATA/ directory (Starting Block ${START_IMAGE_BLOCK})...`)

let dataEntries = []

for (let i = 0; i < imageNumbers.length; i++) {
  const numStr = imageNumbers[i].toString().padStart(3, "0")
  const imgName = `IMG${numStr}.BIN`
  const palName = `VPAL${numStr}.BIN`

  const palPath = path.join(x16SlideshowDataDir, palName)
  const imgPath = path.join(x16SlideshowDataDir, imgName)

  // Each image slot = 152 blocks:
  //   Block 0       : Palette Data (512B) -> VPALxxx.BIN KeyBlock
  //   Block 1       : Image Index Block (512B) -> IMGxxx.BIN KeyBlock
  //   Blocks 2..151 : Image Bitmap Data (76,800B)
  const slotBase = START_IMAGE_BLOCK + (i - 1) * 152
  const palBlock = slotBase
  const imgIndexBlock = slotBase + 1
  const imgDataStartBlock = slotBase + 2

  // 1. Palette Data
  if (fs.existsSync(palPath)) {
    const palData = fs.readFileSync(palPath)
    disk.set(palData, palBlock * BLOCK_SIZE)
    allocatedBlocks.add(palBlock)
  }

  dataEntries.push({
    name: palName,
    storageType: 1, // Standard File
    fileType: 0x06, // BIN
    keyBlock: palBlock,
    totalBlocks: 1,
    eof: 512,
    auxType: 0x2000
  })

  // 2. Image Data + Index Block
  if (fs.existsSync(imgPath)) {
    const imgData = fs.readFileSync(imgPath)
    const indexData = new Uint8Array(512)

    for (let blk = 0; blk < 150; blk++) {
      const dataBlkNum = imgDataStartBlock + blk
      const chunk = imgData.subarray(blk * 512, (blk + 1) * 512)
      disk.set(chunk, dataBlkNum * BLOCK_SIZE)
      allocatedBlocks.add(dataBlkNum)

      indexData[blk] = dataBlkNum & 0xFF
      indexData[blk + 256] = (dataBlkNum >> 8) & 0xFF
    }

    disk.set(indexData, imgIndexBlock * BLOCK_SIZE)
    allocatedBlocks.add(imgIndexBlock)
  }

  dataEntries.push({
    name: imgName,
    storageType: 2, // Sapling / Index File
    fileType: 0x06, // BIN
    keyBlock: imgIndexBlock,
    totalBlocks: 151,
    eof: 76800,
    auxType: 0x2000
  })
}

console.log(`  ✅ Successfully packed all ${dataEntries.length} files into /DATA/ (${SUBDIR_BLOCK_COUNT} directory blocks)!`)

// 10. Write /DATA Subdirectory Entries (all dynamically allocated directory blocks)
for (let i = 0; i < dataEntries.length; i++) {
  const entry = dataEntries[i]
  let blkIdx, entryInBlk

  if (i < 12) {
    // Block 0: Entry 0 is Subdir Header, files in Entry 1..12
    blkIdx = 0
    entryInBlk = i + 1
  } else {
    // Blocks 1..11: All 13 entries (Entry 0..12) are files
    const rem = i - 12
    blkIdx = 1 + Math.floor(rem / 13)
    entryInBlk = rem % 13
  }

  const targetBlkNum = SUBDIR_START_BLOCK + blkIdx
  const entryOffset = targetBlkNum * BLOCK_SIZE + 4 + entryInBlk * 39

  disk[entryOffset + 0x00] = (entry.storageType << 4) | (entry.name.length & 0x0F)
  for (let j = 0; j < 15; j++) {
    disk[entryOffset + 0x01 + j] = j < entry.name.length ? entry.name.charCodeAt(j) : 0x00
  }
  disk[entryOffset + 0x10] = entry.fileType
  disk[entryOffset + 0x11] = entry.keyBlock & 0xFF
  disk[entryOffset + 0x12] = (entry.keyBlock >> 8) & 0xFF
  disk[entryOffset + 0x13] = entry.totalBlocks & 0xFF
  disk[entryOffset + 0x14] = (entry.totalBlocks >> 8) & 0xFF
  disk[entryOffset + 0x15] = entry.eof & 0xFF
  disk[entryOffset + 0x16] = (entry.eof >> 8) & 0xFF
  disk[entryOffset + 0x17] = (entry.eof >> 16) & 0xFF
  disk[entryOffset + 0x1E] = 0xC3
  disk[entryOffset + 0x1F] = entry.auxType & 0xFF
  disk[entryOffset + 0x20] = (entry.auxType >> 8) & 0xFF
  disk[entryOffset + 0x25] = SUBDIR_START_BLOCK & 0xFF
  disk[entryOffset + 0x26] = (SUBDIR_START_BLOCK >> 8) & 0xFF
}

// 10. Write App Root Directory Entries
for (let i = 0; i < rootEntries.length; i++) {
  const entry = rootEntries[i]
  const entryIndex = preservedBaseEntries.length + 1 + i // Appends right after preserved base system files
  const entryOffset = volBase + 4 + entryIndex * 39

  disk[entryOffset + 0x00] = (entry.storageType << 4) | (entry.name.length & 0x0F)
  for (let j = 0; j < 15; j++) {
    disk[entryOffset + 0x01 + j] = j < entry.name.length ? entry.name.charCodeAt(j) : 0x00
  }
  disk[entryOffset + 0x10] = entry.fileType
  disk[entryOffset + 0x11] = entry.keyBlock & 0xFF
  disk[entryOffset + 0x12] = (entry.keyBlock >> 8) & 0xFF
  disk[entryOffset + 0x13] = entry.totalBlocks & 0xFF
  disk[entryOffset + 0x14] = (entry.totalBlocks >> 8) & 0xFF
  disk[entryOffset + 0x15] = entry.eof & 0xFF
  disk[entryOffset + 0x16] = (entry.eof >> 8) & 0xFF
  disk[entryOffset + 0x17] = (entry.eof >> 16) & 0xFF
  disk[entryOffset + 0x1E] = 0xC3
  disk[entryOffset + 0x1F] = entry.auxType & 0xFF
  disk[entryOffset + 0x20] = (entry.auxType >> 8) & 0xFF
  disk[entryOffset + 0x25] = 2
  disk[entryOffset + 0x26] = 0
}

// Update Root Directory File Count
const totalRootFiles = preservedBaseEntries.length + rootEntries.length
disk[volBase + 0x25] = totalRootFiles & 0xFF
disk[volBase + 0x26] = (totalRootFiles >> 8) & 0xFF

// 9. Update ProDOS BitMap (Block 6..21, 16 blocks)
for (let b = 0; b < 16; b++) {
  const bmpOffset = (6 + b) * BLOCK_SIZE
  for (let byteIdx = 0; byteIdx < BLOCK_SIZE; byteIdx++) {
    let byteVal = 0
    for (let bit = 0; bit < 8; bit++) {
      const blockNum = (b * BLOCK_SIZE + byteIdx) * 8 + (7 - bit)
      if (blockNum < TOTAL_BLOCKS && !allocatedBlocks.has(blockNum)) {
        byteVal |= (1 << bit)
      }
    }
    disk[bmpOffset + byteIdx] = byteVal
  }
}

// 10. Write Output Files
const hdvPath = path.resolve(projectRoot, "slideshow.hdv")
const written = safeWriteFileSync(hdvPath, disk)
if (written) {
  console.log(`\n🎉 Successfully generated 32MB ProDOS Hard Disk: ${hdvPath} (${disk.length} bytes)`)
}

// Clean up any legacy .2mg image if present
const twoMgPath = path.resolve(projectRoot, "slideshow.2mg")
if (fs.existsSync(twoMgPath)) {
  fs.unlinkSync(twoMgPath)
}

// 11. Generate slideshow.png preview screenshot
generateSlideshowPreviewPng(projectRoot)

function safeWriteFileSync(filePath, data) {
  try {
    fs.writeFileSync(filePath, data)
    return true
  } catch (err) {
    if (err.code === "EBUSY" || err.code === "EPERM") {
      console.warn(`\n⚠️  [FILE LOCKED] ${filePath} is currently open/locked by your emulator!`)
      console.warn(`    Please eject/unmount the disk in Apple2TS or reload the emulator to apply changes.`)
      try {
        fs.writeFileSync(`${filePath}.new`, data)
        console.warn(`    Saved temporary copy to: ${filePath}.new\n`)
      } catch (_) {}
      return false
    }
    throw err
  }
}

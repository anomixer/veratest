import fs from "fs"
import path from "path"
import { fileURLToPath } from "url"
import { assembleAsmFile } from "./src/asm6502.mjs"
import { compileApplesoftBasic } from "./src/applebasic.mjs"
import { generateRainbowRleData } from "./src/rainbow_rle.mjs"
import { generatePreviewPng } from "./src/preview.mjs"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = __dirname
const srcDir = path.join(rootDir, "src")

// Build Mode 7 Real Rainbow Arc Binary with instant 6502 RLE decompressor
const buildMode7Binary = (slot = 2) => {
  const rleData = generateRainbowRleData()
  const codeBytes = assembleAsmFile(srcDir, "mode7.asm", slot, 0x2000)
  return new Uint8Array([...codeBytes, ...rleData])
}

// Build ProDOS 2.4.3 Disk Image
const buildProDosDisk = () => {
  const basePoPath = fs.existsSync(path.join(rootDir, "assets", "ProDOS 2.4.3.po"))
    ? path.join(rootDir, "assets", "ProDOS 2.4.3.po")
    : path.resolve(rootDir, "../apple2ts/public/disks/ProDOS 2.4.3.po")
  const disk = new Uint8Array(fs.readFileSync(basePoPath))

  const bitmap = disk.subarray(6 * 512, 7 * 512)
  const isBlockFree = (b) => (bitmap[Math.floor(b / 8)] & (1 << (7 - (b % 8)))) !== 0
  const markBlockUsed = (b) => { bitmap[Math.floor(b / 8)] &= ~(1 << (7 - (b % 8))) }

  let freeBlockSearch = 7
  const allocateBlock = () => {
    while (freeBlockSearch < 280) {
      if (isBlockFree(freeBlockSearch)) {
        const b = freeBlockSearch++
        markBlockUsed(b)
        disk.fill(0, b * 512, (b + 1) * 512)
        return b
      }
      freeBlockSearch++
    }
    throw new Error("Disk full: no free blocks")
  }

  let fileCount = 0
  let currBlock = 2

  while (currBlock !== 0) {
    const blk = disk.subarray(currBlock * 512, (currBlock + 1) * 512)
    const next = blk[0x02] | (blk[0x03] << 8)

    for (let offset = (currBlock === 2 ? 0x2B : 0x04); offset + 0x27 <= 512; offset += 0x27) {
      const storageAndLen = blk[offset]
      if (storageAndLen === 0) continue
      const nameLen = storageAndLen & 0x0F
      const name = String.fromCharCode(...blk.subarray(offset + 1, offset + 1 + nameLen))

      if (name === "PRODOS" || name === "BASIC.SYSTEM") {
        fileCount++
        continue
      }

      const storageType = storageAndLen >> 4
      const keyBlock = blk[offset + 0x11] | (blk[offset + 0x12] << 8)
      const numBlocks = blk[offset + 0x13] | (blk[offset + 0x14] << 8)

      if (storageType === 1) {
        bitmap[Math.floor(keyBlock / 8)] |= (1 << (7 - (keyBlock % 8)))
      } else if (storageType === 2) {
        const indexBlk = disk.subarray(keyBlock * 512, (keyBlock + 1) * 512)
        for (let i = 0; i < numBlocks; i++) {
          const dBlk = indexBlk[i] | (indexBlk[256 + i] << 8)
          if (dBlk > 0) bitmap[Math.floor(dBlk / 8)] |= (1 << (7 - (dBlk % 8)))
        }
        bitmap[Math.floor(keyBlock / 8)] |= (1 << (7 - (keyBlock % 8)))
      }

      blk.fill(0, offset, offset + 0x27)
    }
    currBlock = next
  }

  const addFile = (name, type, aux, data) => {
    const size = data.length
    const numDataBlocks = Math.ceil(size / 512) || 1

    let keyBlock = 0
    let blocksUsed = 0
    let storageType = 1

    if (numDataBlocks === 1) {
      storageType = 1
      keyBlock = allocateBlock()
      blocksUsed = 1
      disk.set(data, keyBlock * 512)
    } else {
      storageType = 2
      keyBlock = allocateBlock()
      blocksUsed = 1 + numDataBlocks
      const indexBlock = new Uint8Array(512)
      for (let i = 0; i < numDataBlocks; i++) {
        const dataBlk = allocateBlock()
        indexBlock[i] = dataBlk & 0xFF
        indexBlock[256 + i] = (dataBlk >> 8) & 0xFF
        const chunk = data.subarray(i * 512, Math.min((i + 1) * 512, size))
        disk.set(chunk, dataBlk * 512)
      }
      disk.set(indexBlock, keyBlock * 512)
    }

    let blkNum = 2
    let found = false

    while (blkNum !== 0 && !found) {
      const blk = disk.subarray(blkNum * 512, (blkNum + 1) * 512)
      const next = blk[0x02] | (blk[0x03] << 8)
      const startOff = (blkNum === 2 ? 0x2B : 0x04)

      for (let off = startOff; off + 0x27 <= 512; off += 0x27) {
        if (blk[off] === 0) {
          blk[off] = (storageType << 4) | (name.length & 0x0F)
          for (let i = 0; i < name.length; i++) blk[off + 1 + i] = name.charCodeAt(i)
          blk[off + 0x10] = type
          blk[off + 0x11] = keyBlock & 0xFF
          blk[off + 0x12] = (keyBlock >> 8) & 0xFF
          blk[off + 0x13] = blocksUsed & 0xFF
          blk[off + 0x14] = (blocksUsed >> 8) & 0xFF
          blk[off + 0x15] = size & 0xFF
          blk[off + 0x16] = (size >> 8) & 0xFF
          blk[off + 0x17] = (size >> 16) & 0xFF
          blk[off + 0x1E] = 0xC3 // Access: Fully UNLOCKED (Read, Write, Rename, Destroy)
          blk[off + 0x1F] = aux & 0xFF
          blk[off + 0x20] = (aux >> 8) & 0xFF
          blk[off + 0x25] = 0x02 // Header pointer
          blk[off + 0x26] = 0x00
          fileCount++
          found = true
          break
        }
      }
      blkNum = next
    }
  }

  // 1. Assemble 6502 routines from src/*.asm
  const sprite2 = assembleAsmFile(srcDir, "sprite.asm", 2, 0x2000)
  const sprite4 = assembleAsmFile(srcDir, "sprite.asm", 4, 0x2000)
  const spritesnd2 = assembleAsmFile(srcDir, "spritesnd.asm", 2, 0x2000)
  const spritesnd4 = assembleAsmFile(srcDir, "spritesnd.asm", 4, 0x2000)
  const mode72 = buildMode7Binary(2)
  const mode74 = buildMode7Binary(4)

  // 2. Compile Applesoft BASIC from src/startup.bas
  const startup = compileApplesoftBasic(srcDir, "startup.bas")

  // 3. Write binary files into ProDOS image
  addFile("SPRITE.BIN", 0x06, 0x2000, sprite2)
  addFile("SPRITE4.BIN", 0x06, 0x2000, sprite4)
  addFile("SPRSND.BIN", 0x06, 0x2000, spritesnd2)
  addFile("SPRSND4.BIN", 0x06, 0x2000, spritesnd4)
  addFile("MODE7.BIN", 0x06, 0x2000, mode72)
  addFile("MODE74.BIN", 0x06, 0x2000, mode74)
  addFile("STARTUP", 0xFC, 0x0801, startup)

  disk[2 * 512 + 0x25] = fileCount & 0xFF
  disk[2 * 512 + 0x26] = (fileCount >> 8) & 0xFF

  const outPathRoot = path.join(rootDir, "veratest.po")
  fs.writeFileSync(outPathRoot, disk)
  console.log(`\nSuccessfully created 100% genuine ProDOS VERA test disk: ${outPathRoot} (${disk.length} bytes)`)
  console.log(`Total Active Files: ${fileCount}`)
  console.log(`  - SPRITE.BIN   Size=${sprite2.length} bytes`)
  console.log(`  - SPRITE4.BIN  Size=${sprite4.length} bytes`)
  console.log(`  - SPRSND.BIN   Size=${spritesnd2.length} bytes (4-Voice Stereo PSG Chiptune)`)
  console.log(`  - SPRSND4.BIN  Size=${spritesnd4.length} bytes (4-Voice Stereo PSG Chiptune)`)
  console.log(`  - MODE7.BIN    Size=${mode72.length} bytes (Instant RLE Rainbow Arc)`)
  console.log(`  - MODE74.BIN   Size=${mode74.length} bytes (Instant RLE Rainbow Arc)`)
  console.log(`  - STARTUP      Size=${startup.length} bytes (Compiled from src/startup.bas)`)

  // Auto-sync to Apple2TS if repo is present
  const apple2tsPublicDisks = path.resolve(rootDir, "../apple2ts/public/disks")
  if (fs.existsSync(apple2tsPublicDisks)) {
    fs.writeFileSync(path.join(apple2tsPublicDisks, "veratest.po"), disk)
    console.log(`  -> Synced to ${path.join(apple2tsPublicDisks, "veratest.po")}`)
  }

  // 4. Generate veratest.png preview screenshot
  generatePreviewPng(rootDir)
}

buildProDosDisk()

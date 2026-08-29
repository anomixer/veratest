import fs from "fs"
import path from "path"
import { fileURLToPath } from "url"
import { assembleAsmFile } from "../asm6502.mjs"
import { compileApplesoftBasic } from "../applebasic.mjs"
import { generateRainbowRleData } from "./rainbow_rle.mjs"
import { generatePreviewPng } from "./preview.mjs"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const veratestDir = __dirname
const srcDir = path.resolve(veratestDir, "..")
const projectRoot = path.resolve(srcDir, "..")

// Build Mode 7 Real Rainbow Arc Binary with instant 6502 RLE decompressor
const buildMode7Binary = (slot = 2) => {
  const rleData = generateRainbowRleData()
  const codeBytes = assembleAsmFile(veratestDir, "mode7.asm", slot, 0x2000)
  return new Uint8Array([...codeBytes, ...rleData])
}

// Build Mode 4 Tilemap Binary with Palette, Tilemap and Tiles assets
const buildMode4Binary = (slot = 2) => {
  const codeBytes = assembleAsmFile(veratestDir, "mode4.asm", slot, 0x2000)
  const pal = fs.readFileSync(path.join(veratestDir, "mode4-palette.bin"))
  const map = fs.readFileSync(path.join(veratestDir, "mode4-tilemap.bin"))
  const til = fs.readFileSync(path.join(veratestDir, "mode4-tiles.bin"))
  return new Uint8Array([...codeBytes, ...pal, ...map, ...til])
}

// Build ProDOS 2.4.3 Disk Image
const buildProDosDisk = () => {
  const basePoPath = path.join(projectRoot, "assets", "ProDOS 2.4.3.po")
  if (!fs.existsSync(basePoPath)) {
    throw new Error(`Base ProDOS 2.4.3.po not found at ${basePoPath}!`)
  }
  const disk = new Uint8Array(fs.readFileSync(basePoPath))

  const bitmap = disk.subarray(6 * 512, 7 * 512)
  const isBlockFree = (b) => (bitmap[Math.floor(b / 8)] & (1 << (7 - (b % 8)))) !== 0
  const markBlockUsed = (b) => { bitmap[Math.floor(b / 8)] &= ~(1 << (7 - (b % 8))) }
  const markBlockFree = (b) => { bitmap[Math.floor(b / 8)] |= (1 << (7 - (b % 8))) }

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

    for (let i = 0; i < 13; i++) {
      const off = 4 + i * 39
      if (currBlock === 2 && i === 0) continue

      const stLen = blk[off]
      if (stLen === 0) continue

      const nameLen = stLen & 0x0F
      const name = String.fromCharCode(...blk.subarray(off + 1, off + 1 + nameLen))

      if (name === "PRODOS" || name === "BASIC.SYSTEM") {
        fileCount++
        continue
      }

      const stType = (stLen >> 4) & 0x0F
      const keyBlk = blk[off + 0x11] | (blk[off + 0x12] << 8)

      if (stType === 1) {
        markBlockFree(keyBlk)
      } else if (stType === 2) {
        const idxBlk = disk.subarray(keyBlk * 512, (keyBlk + 1) * 512)
        markBlockFree(keyBlk)
        for (let b = 0; b < 256; b++) {
          const db = idxBlk[b] | (idxBlk[b + 256] << 8)
          if (db !== 0) markBlockFree(db)
        }
      }

      blk.fill(0, off, off + 39)
    }
    currBlock = next
  }

  const addFile = (filename, type, aux, data) => {
    const size = data.length
    let stType, keyBlock

    if (size <= 512) {
      stType = 1
      keyBlock = allocateBlock()
      disk.set(data, keyBlock * 512)
    } else {
      stType = 2
      keyBlock = allocateBlock()
      const indexBlk = disk.subarray(keyBlock * 512, (keyBlock + 1) * 512)
      const numBlocks = Math.ceil(size / 512)
      for (let i = 0; i < numBlocks; i++) {
        const db = allocateBlock()
        const chunk = data.subarray(i * 512, Math.min(size, (i + 1) * 512))
        disk.set(chunk, db * 512)
        indexBlk[i] = db & 0xFF
        indexBlk[i + 256] = (db >> 8) & 0xFF
      }
    }

    const blocksUsed = stType === 1 ? 1 : 1 + Math.ceil(size / 512)

    let blkNum = 2
    let found = false

    while (blkNum !== 0 && !found) {
      const blk = disk.subarray(blkNum * 512, (blkNum + 1) * 512)
      const next = blk[0x02] | (blk[0x03] << 8)

      for (let i = 0; i < 13; i++) {
        const off = 4 + i * 39
        if (blkNum === 2 && i === 0) continue

        if (blk[off] === 0) {
          blk[off] = (stType << 4) | (filename.length & 0x0F)
          for (let c = 0; c < 15; c++) {
            blk[off + 1 + c] = c < filename.length ? filename.charCodeAt(c) : 0x00
          }
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

  // 1. Assemble 6502 Showcases
  const sprite2   = assembleAsmFile(veratestDir, "sprite.asm", 2, 0x2000)
  const sprite4   = assembleAsmFile(veratestDir, "sprite.asm", 4, 0x2000)
  const spritesnd2= assembleAsmFile(veratestDir, "spritesnd.asm", 2, 0x2000)
  const spritesnd4= assembleAsmFile(veratestDir, "spritesnd.asm", 4, 0x2000)
  const mode72    = buildMode7Binary(2)
  const mode74    = buildMode7Binary(4)
  const mode42    = buildMode4Binary(2)
  const mode44    = buildMode4Binary(4)
  const layer2    = assembleAsmFile(veratestDir, "layer.asm", 2, 0x2000)
  const layer4    = assembleAsmFile(veratestDir, "layer.asm", 4, 0x2000)
  const matrix2   = assembleAsmFile(veratestDir, "matrix.asm", 2, 0x2000)
  const matrix4   = assembleAsmFile(veratestDir, "matrix.asm", 4, 0x2000)

  // 2. Compile Applesoft BASIC Startup Menu
  const startup = compileApplesoftBasic(veratestDir, "startup.bas")

  // 3. Write all files into ProDOS image
  addFile("SPRITE.BIN",   0x06, 0x2000, sprite2)
  addFile("SPRITE4.BIN",  0x06, 0x2000, sprite4)
  addFile("SPRSND.BIN",   0x06, 0x2000, spritesnd2)
  addFile("SPRSND4.BIN",  0x06, 0x2000, spritesnd4)
  addFile("MODE7.BIN",    0x06, 0x2000, mode72)
  addFile("MODE74.BIN",   0x06, 0x2000, mode74)
  addFile("TILEMAP.BIN",  0x06, 0x2000, mode42)
  addFile("TILEMAP4.BIN", 0x06, 0x2000, mode44)
  addFile("LAYER.BIN",    0x06, 0x2000, layer2)
  addFile("LAYER4.BIN",   0x06, 0x2000, layer4)
  addFile("MATRIX.BIN",   0x06, 0x2000, matrix2)
  addFile("MATRIX4.BIN",  0x06, 0x2000, matrix4)
  addFile("STARTUP",      0xFC, 0x0801, startup)

  disk[2 * 512 + 0x25] = fileCount & 0xFF
  disk[2 * 512 + 0x26] = (fileCount >> 8) & 0xFF

  const outPathRoot = path.join(projectRoot, "veratest.po")
  const written = safeWriteFileSync(outPathRoot, disk)
  if (written) {
    console.log(`\nSuccessfully created 100% genuine ProDOS VERA test disk: ${outPathRoot} (${disk.length} bytes)`)
  }
  console.log(`Total Active Files: ${fileCount}`)
  console.log(`  - SPRITE.BIN / 4   Size=${sprite2.length} bytes (16-Sprite Bouncing)`)
  console.log(`  - SPRSND.BIN / 4   Size=${spritesnd2.length} bytes (4-Voice Stereo PSG Chiptune)`)
  console.log(`  - MODE7.BIN / 4    Size=${mode72.length} bytes (Instant RLE Rainbow Arc)`)
  console.log(`  - TILEMAP.BIN / 4  Size=${mode42.length} bytes (Mode 4 256-Color RPG Tilemap)`)
  console.log(`  - LAYER.BIN / 4    Size=${layer2.length} bytes (Dual-Layer Electric Storm)`)
  console.log(`  - MATRIX.BIN / 4   Size=${matrix2.length} bytes (Matrix Digital Rain)`)
  console.log(`  - STARTUP          Size=${startup.length} bytes (Applesoft BASIC Menu)`)

  // 4. Generate veratest.png preview screenshot
  generatePreviewPng(projectRoot)
}

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

buildProDosDisk()

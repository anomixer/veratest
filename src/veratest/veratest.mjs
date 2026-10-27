import fs from "fs"
import os from "os"
import path from "path"
import { execFileSync } from "child_process"
import { fileURLToPath } from "url"
import { assembleAsmFile } from "../asm6502.mjs"
import { compileApplesoftBasic } from "../applebasic.mjs"
import { updateFmProbe } from "../update_fm_probe.mjs"
import { buildMusicStreams } from "../music_streams.mjs"
import { buildSonicDat } from "./build_sonic_dat.mjs"
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

// Build the 140KB ProDOS disk through Cadius. Preserve the system boot files
// from the ProDOS baseline, while Cadius handles every directory/file update.
const buildProDosDisk = () => {
  const basePoPath = path.join(projectRoot, "assets", "ProDOS 2.4.3.po")
  if (!fs.existsSync(basePoPath)) {
    throw new Error(`Base ProDOS 2.4.3.po not found at ${basePoPath}!`)
  }

  // The Sonic demo plays the same PSG+FM Green Hill stream as the slideshow, so
  // refresh the converted streams and SONIC.DAT (and its block count include)
  // before any 6502 source is assembled.
  console.log("  🎵 Converting X16 ZSM soundtracks to VERA PSG+FM streams...")
  buildMusicStreams()
  console.log("  📦 Packing SONIC.DAT with the PSG+FM Green Hill stream...")
  const sonicInfo = buildSonicDat()

  const cadius = process.env.CADIUS || path.join(projectRoot, "tools", "cadius.exe")
  if (!fs.existsSync(cadius) && !process.env.CADIUS) {
    throw new Error(`Cadius not found at ${cadius}; set CADIUS or install Cadius on PATH.`)
  }
  const volumeName = "VERATEST"
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "veratest-po-"))
  const imagePath = path.join(tempRoot, "veratest.po")
  const stageDir = path.join(tempRoot, "files")
  fs.mkdirSync(stageDir)

  const runCadius = (...args) => execFileSync(cadius, args, { stdio: "inherit" })
  const listRootEntries = (image) => {
    const disk = fs.readFileSync(image)
    const entries = []
    const visited = new Set()
    let blockNumber = 2
    while (blockNumber && !visited.has(blockNumber)) {
      visited.add(blockNumber)
      const blockOffset = blockNumber * 512
      if (blockOffset + 512 > disk.length) throw new Error("Invalid ProDOS directory chain")
      const block = disk.subarray(blockOffset, blockOffset + 512)
      const nextBlock = block[2] | (block[3] << 8)
      const firstSlot = blockNumber === 2 ? 1 : 0
      for (let slot = firstSlot; slot < 13; slot++) {
        const offset = 4 + slot * 39
        const storageName = block[offset]
        const storageType = storageName >> 4
        const nameLength = storageName & 0x0F
        if (!storageType || !nameLength) continue
        const name = block.toString("ascii", offset + 1, offset + 1 + nameLength)
        entries.push({ name, isDirectory: storageType === 0x0D })
      }
      blockNumber = nextBlock
    }
    return entries
  }

  try {
    fs.copyFileSync(basePoPath, imagePath)
    runCadius("RENAMEVOLUME", imagePath, volumeName)

    // Keep only the two files required to boot ProDOS/BASIC.SYSTEM. Remove
    // bundled utilities from the baseline through Cadius so its bitmap and
    // catalog remain consistent.
    for (const entry of listRootEntries(imagePath)) {
      if (entry.name === "PRODOS" || entry.name === "BASIC.SYSTEM") continue
      const command = entry.isDirectory ? "DELETEFOLDER" : "DELETEFILE"
      runCadius(command, imagePath, `/${volumeName}/${entry.name}`)
    }

    const addFile = (filename, type, aux, data) => {
      const suffix = `#${type.toString(16).padStart(2, "0")}${aux.toString(16).padStart(4, "0")}`
      const sourcePath = path.join(stageDir, `${filename}${suffix}`)
      fs.writeFileSync(sourcePath, data)
      runCadius("ADDFILE", imagePath, `/${volumeName}`, sourcePath)
    }

    const sprite2 = assembleAsmFile(veratestDir, "sprite.asm", 2, 0x2000)
    const sprite4 = assembleAsmFile(veratestDir, "sprite.asm", 4, 0x2000)
    const spritesnd2 = assembleAsmFile(veratestDir, "spritesnd.asm", 2, 0x2000)
    const spritesnd4 = assembleAsmFile(veratestDir, "spritesnd.asm", 4, 0x2000)
    const mode72 = buildMode7Binary(2)
    const mode74 = buildMode7Binary(4)
    const mode42 = buildMode4Binary(2)
    const mode44 = buildMode4Binary(4)
    const layer2 = assembleAsmFile(veratestDir, "layer.asm", 2, 0x2000)
    const layer4 = assembleAsmFile(veratestDir, "layer.asm", 4, 0x2000)
    const matrix2 = assembleAsmFile(veratestDir, "matrix.asm", 2, 0x2000)
    const matrix4 = assembleAsmFile(veratestDir, "matrix.asm", 4, 0x2000)
    const sonic2 = assembleAsmFile(veratestDir, "sonic.asm", 2, 0x2000)
    const sonic4 = assembleAsmFile(veratestDir, "sonic.asm", 4, 0x2000)
    const sonicDat = fs.readFileSync(path.join(veratestDir, "sonic.dat"))
    const sonicMusic = sonicInfo.music
    updateFmProbe()
    const startup = compileApplesoftBasic(veratestDir, "startup.bas")

    const programs = [
      ["SPRITE.BIN", 0x06, 0x2000, sprite2], ["SPRITE4.BIN", 0x06, 0x2000, sprite4],
      ["SPRSND.BIN", 0x06, 0x2000, spritesnd2], ["SPRSND4.BIN", 0x06, 0x2000, spritesnd4],
      ["MODE7.BIN", 0x06, 0x2000, mode72], ["MODE74.BIN", 0x06, 0x2000, mode74],
      ["TILEMAP.BIN", 0x06, 0x2000, mode42], ["TILEMAP4.BIN", 0x06, 0x2000, mode44],
      ["LAYER.BIN", 0x06, 0x2000, layer2], ["LAYER4.BIN", 0x06, 0x2000, layer4],
      ["MATRIX.BIN", 0x06, 0x2000, matrix2], ["MATRIX4.BIN", 0x06, 0x2000, matrix4],
      ["SONIC.BIN", 0x06, 0x2000, sonic2], ["SONIC4.BIN", 0x06, 0x2000, sonic4],
      ["SONICMUS.BIN", 0x06, 0x4800, sonicMusic],
      ["SONIC.DAT", 0x00, 0x0000, sonicDat], ["STARTUP", 0xFC, 0x0801, startup],
    ]
    for (const [name, type, aux, data] of programs) addFile(name, type, aux, data)

    runCadius("CHECKVOLUME", imagePath)
    runCadius("CATALOG", imagePath)
    const outputPath = path.join(projectRoot, "veratest.po")
    safeWriteFileSync(outputPath, fs.readFileSync(imagePath))
    console.log(`Successfully created Cadius ProDOS disk: ${outputPath}`)
    console.log(`Total application files: ${programs.length}`)
    console.log(`  - SONIC.DAT: ${sonicDat.length} bytes (Sonic asset container)`)
    console.log(`  - SONICMUS.BIN: ${sonicMusic.length} bytes (PSG+FM Green Hill stream, $4800)`)
  } finally {
    fs.rmSync(tempRoot, { recursive: true, force: true })
  }

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

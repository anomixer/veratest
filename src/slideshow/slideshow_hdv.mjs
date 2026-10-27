import fs from "fs"
import path from "path"
import os from "os"
import { execFileSync } from "child_process"
import { fileURLToPath } from "url"
import { assembleAsmFile } from "../asm6502.mjs"
import { compileApplesoftBasic } from "../applebasic.mjs"
import { updateFmProbe } from "../update_fm_probe.mjs"
import { buildMusicStreams } from "../music_streams.mjs"
import { generateSlideshowPreviewPng } from "./preview.mjs"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(__dirname, "../..")
const srcDir = path.resolve(projectRoot, "src")
const slideshowDir = path.resolve(srcDir, "slideshow")
const x16SlideshowDataDir = path.resolve(slideshowDir, "data")
const baseHdvPath = path.resolve(projectRoot, "assets/ProDOS 2.4.3.hdv")

// Convert the X16 ZSM streams (VERA PSG + YM2151 FM) into the compact "VZM"
// stream consumed by the Apple II player.  Both the PSG and the FM portions are
// preserved: the player detects the optional FM daughterboard at run time and
// simply skips the $C0-$DF FM batches when no YM2151 is installed.
const MUSIC_NAMES = ["SB-INTRO", "CANYON", "GREENHILL"]
const MUSIC_FILES = ["SBINTRO.VZM", "CANYON.VZM", "GREENHILL.VZM"]
const BLOCK_SIZE = 512

const musicTracks = buildMusicStreams()
const musicStreams = MUSIC_NAMES.map((name, index) => {
  const track = musicTracks.find(t => t.name === name)
  if (!track || track.data.length % BLOCK_SIZE !== 0) {
    throw new Error(`Music stream for ${name} is missing or not block padded`)
  }
  return track.data
})

console.log("🚀 Building 32MB ProDOS 2.4.3 Slideshow Hard Disk Image with Cadius...")

// 0. Precompute optimal FG (white) and BG (black) color indices for all 375 palettes
const generatePaletteLut = () => {
  const fgLut = []
  const bgLut = []
  for (let i = 1; i <= 375; i++) {
    const num = String(i).padStart(3, "0")
    const palData = fs.readFileSync(path.join(x16SlideshowDataDir, `VPAL${num}.BIN`))
    let maxL = -1, maxIdx = 0, minL = 999999, minIdx = 0
    for (let c = 0; c < 256; c++) {
      const gb = palData[c * 2]
      const r = palData[c * 2 + 1] & 0x0F
      const g = (gb >> 4) & 0x0F
      const b = gb & 0x0F
      const lum = r * 30 + g * 59 + b * 11
      if (lum > maxL) { maxL = lum; maxIdx = c; }
      if (lum < minL) { minL = lum; minIdx = c; }
    }
    fgLut.push(maxIdx)
    bgLut.push(minIdx)
  }
  let out = "; Precomputed Optimal FG and BG Color Indices for 375 Palettes\n"
  out += "PAL_FG_TABLE:\n"
  for (let i = 0; i < 375; i += 16) {
    const chunk = fgLut.slice(i, Math.min(i + 16, 375)).map(v => v.toString(16).padStart(2, "0")).join(" ")
    out += "    HEX " + chunk + "\n"
  }
  out += "PAL_BG_TABLE:\n"
  for (let i = 0; i < 375; i += 16) {
    const chunk = bgLut.slice(i, Math.min(i + 16, 375)).map(v => v.toString(16).padStart(2, "0")).join(" ")
    out += "    HEX " + chunk + "\n"
  }
  fs.writeFileSync(path.join(slideshowDir, "palette_lut.inc"), out)
}
generatePaletteLut()

// 1. Compile 6502 Assembly Slideshow Engine for Slot 2 & Slot 4
console.log("  ⚙️ Compiling SLIDESHOW.BIN (Slot 2 & Slot 4)...")
const slideshow2 = assembleAsmFile(slideshowDir, "slideshow.asm", 2, 0x2000)
const slideshow4 = assembleAsmFile(slideshowDir, "slideshow.asm", 4, 0x2000)
// The binary is loaded at $2000 and must not reach the runtime block buffer at
// $3C00 (DATA_BUF); keep that invariant checked at build time.
const SLIDESHOW_LOAD_LIMIT = 0x3c00
for (const [name, binary] of [["SLIDESHOW.BIN", slideshow2], ["SLIDSHW4.BIN", slideshow4]]) {
  if (0x2000 + binary.length > SLIDESHOW_LOAD_LIMIT) {
    throw new Error(`${name} ends at $${(0x2000 + binary.length).toString(16)} but must stay below $${SLIDESHOW_LOAD_LIMIT.toString(16)}`)
  }
}

// 2. Compile Applesoft BASIC Startup Menu
console.log("  ⚙️ Compiling STARTUP BASIC script...")
updateFmProbe()
const startup = compileApplesoftBasic(slideshowDir, "startup.bas")

// 3. Build the HDV through Cadius. Let the ProDOS-aware utility create file
// entries, subdirectories, timestamps, allocation indexes, and the volume bitmap.
const imageNumbers = fs.readdirSync(x16SlideshowDataDir)
  .filter(name => /^IMG\d{3}\.BIN$/i.test(name))
  .map(name => Number(name.slice(3, 6)))
  .sort((a, b) => a - b)
if (imageNumbers.length !== 375 || imageNumbers.some((number, index) => number !== index + 1)) {
  throw new Error(`Expected contiguous IMG001.BIN through IMG375.BIN; found ${imageNumbers.length} images`)
}
for (const imageNumber of imageNumbers) {
  const numStr = imageNumber.toString().padStart(3, "0")
  const imagePath = path.join(x16SlideshowDataDir, `IMG${numStr}.BIN`)
  const palettePath = path.join(x16SlideshowDataDir, `VPAL${numStr}.BIN`)
  if (!fs.existsSync(palettePath)) throw new Error(`Missing palette for IMG${numStr}.BIN`)
  if (fs.statSync(imagePath).size !== 76800) throw new Error(`IMG${numStr}.BIN must be exactly 76800 bytes`)
  if (fs.statSync(palettePath).size !== 512) throw new Error(`VPAL${numStr}.BIN must be exactly 512 bytes`)
}
if (!fs.existsSync(baseHdvPath)) {
  throw new Error(`Base ProDOS 2.4.3.hdv not found at ${baseHdvPath}!`)
}

const hdvPath = path.resolve(projectRoot, "slideshow.hdv")
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "veratest-slideshow-"))
const appStage = path.join(tempRoot, "app")
const dataStage = path.join(tempRoot, "data")
const imageStages = ["data1", "data2", "data3"].map(name => path.join(tempRoot, name))
const volumeName = "SLIDESHOW"
const bundledCadius = path.join(projectRoot, "tools", "cadius.exe")
const cadius = process.env.CADIUS || (fs.existsSync(bundledCadius) ? bundledCadius : "cadius.exe")

function runCadius(...args) {
  execFileSync(cadius, args, { stdio: "inherit" })
}

function stageFile(directory, filename, data, fileType, auxType) {
  const metadataSuffix = `#${fileType.toString(16).padStart(2, "0")}${auxType.toString(16).padStart(4, "0")}`
  fs.writeFileSync(path.join(directory, `${filename}${metadataSuffix}`), data)
}

function setProDos8SubdirectoryMarker(imagePath, directoryName) {
  const fd = fs.openSync(imagePath, "r+")
  try {
    const rootBlock = Buffer.alloc(BLOCK_SIZE)
    fs.readSync(fd, rootBlock, 0, BLOCK_SIZE, 2 * BLOCK_SIZE)
    let directoryBlock = 0

    for (let slot = 1; slot <= 12; slot++) {
      const offset = 4 + slot * 39
      const storageType = rootBlock[offset] >> 4
      const nameLength = rootBlock[offset] & 0x0F
      const name = rootBlock.toString("ascii", offset + 1, offset + 1 + nameLength)
      if (storageType === 0x0D && name === directoryName) {
        directoryBlock = rootBlock[offset + 0x11] | (rootBlock[offset + 0x12] << 8)
        break
      }
    }
    if (directoryBlock === 0) throw new Error(`Cadius did not create /${directoryName}`)

    const header = Buffer.alloc(BLOCK_SIZE)
    fs.readSync(fd, header, 0, BLOCK_SIZE, directoryBlock * BLOCK_SIZE)
    if (header[4] >> 4 !== 0x0E || header.toString("ascii", 5, 5 + (header[4] & 0x0F)) !== directoryName) {
      throw new Error(`Invalid ProDOS subdirectory header for /${directoryName}`)
    }
    const markerOffset = directoryBlock * BLOCK_SIZE + 4 + 0x10
    if (header[4 + 0x10] !== 0x76 && header[4 + 0x10] !== 0x75) {
      throw new Error(`Unexpected ProDOS subdirectory marker $${header[4 + 0x10].toString(16)}`)
    }
    fs.writeSync(fd, Buffer.from([0x75]), 0, 1, markerOffset)
  } finally {
    fs.closeSync(fd)
  }
}

try {
  fs.mkdirSync(appStage)
  fs.mkdirSync(dataStage)
  for (const imageStage of imageStages) fs.mkdirSync(imageStage)
  fs.copyFileSync(baseHdvPath, hdvPath)

  runCadius("RENAMEVOLUME", hdvPath, volumeName)
  runCadius("DELETEFILE", hdvPath, `/${volumeName}/BITSY.BOOT`)
  runCadius("DELETEFILE", hdvPath, `/${volumeName}/QUIT.SYSTEM`)

  stageFile(appStage, "STARTUP", startup, 0xFC, 0x0801)
  stageFile(appStage, "SLIDESHOW.BIN", slideshow2, 0x06, 0x2000)
  stageFile(appStage, "SLIDSHW4.BIN", slideshow4, 0x06, 0x2000)
  for (let i = 0; i < musicStreams.length; i++) {
    stageFile(dataStage, MUSIC_FILES[i], musicStreams[i], 0x06, 0x2000)
  }
  for (const imageNumber of imageNumbers) {
    const numStr = imageNumber.toString().padStart(3, "0")
    const imageStageIndex = Math.floor((imageNumber - 1) / 125)
    for (const filename of [`VPAL${numStr}.BIN`, `IMG${numStr}.BIN`]) {
      stageFile(imageStages[imageStageIndex], filename, fs.readFileSync(path.join(x16SlideshowDataDir, filename)), 0x06, 0x2000)
    }
  }

  runCadius("ADDFOLDER", hdvPath, `/${volumeName}`, appStage, "--quiet")
  runCadius("CREATEFOLDER", hdvPath, `/${volumeName}/DATA`, "-V")
  setProDos8SubdirectoryMarker(hdvPath, "DATA")
  runCadius("ADDFOLDER", hdvPath, `/${volumeName}/DATA`, dataStage, "--quiet")
  for (let i = 0; i < imageStages.length; i++) {
    const directoryName = `DATA${i + 1}`
    runCadius("CREATEFOLDER", hdvPath, `/${volumeName}/${directoryName}`, "-V")
    setProDos8SubdirectoryMarker(hdvPath, directoryName)
    runCadius("ADDFOLDER", hdvPath, `/${volumeName}/${directoryName}`, imageStages[i], "--quiet")
  }
  runCadius("CHECKVOLUME", hdvPath)
} finally {
  const tempPrefix = path.resolve(os.tmpdir()) + path.sep + "veratest-slideshow-"
  if (!path.resolve(tempRoot).startsWith(tempPrefix)) {
    throw new Error(`Refusing to remove unexpected staging path: ${tempRoot}`)
  }
  fs.rmSync(tempRoot, { recursive: true, force: true })
}

console.log(`\nSuccessfully generated 32MB ProDOS Hard Disk: ${hdvPath} (${fs.statSync(hdvPath).size} bytes)`)

// Clean up any legacy .2mg image if present
const twoMgPath = path.resolve(projectRoot, "slideshow.2mg")
if (fs.existsSync(twoMgPath)) fs.unlinkSync(twoMgPath)

// Generate slideshow.png preview screenshot
generateSlideshowPreviewPng(projectRoot)

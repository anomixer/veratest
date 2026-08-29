import fs from "fs"
import path from "path"
import zlib from "zlib"

// Generate high quality 560x384 PNG screenshot for Slideshow preview
export const generateSlideshowPreviewPng = (projectRoot) => {
  const width = 560
  const height = 384
  const rgba = Buffer.alloc(width * height * 4)

  const dataDir = path.join(projectRoot, "src", "slideshow", "data")
  const palPath = path.join(dataDir, "VPAL001.BIN")
  const imgPath = path.join(dataDir, "IMG001.BIN")

  if (!fs.existsSync(palPath) || !fs.existsSync(imgPath)) {
    console.warn("⚠️ Preview assets (IMG001/VPAL001) not found, skipping slideshow.png generation.")
    return
  }

  const palData = fs.readFileSync(palPath)
  const imgData = fs.readFileSync(imgPath)

  // 1. Decode 256-color 12-bit RGB palette into 24-bit RGBA
  const palette = []
  for (let i = 0; i < 256; i++) {
    const gb = palData[i * 2]
    const r = palData[i * 2 + 1] & 0x0F
    const g = (gb >> 4) & 0x0F
    const b = gb & 0x0F
    palette.push([r * 17, g * 17, b * 17, 255])
  }

  // 2. Scale 320x240 bitmap to 560x384 canvas
  const srcW = 320
  const srcH = 240

  for (let y = 0; y < height; y++) {
    const srcY = Math.min(srcH - 1, Math.floor((y / height) * srcH))
    for (let x = 0; x < width; x++) {
      const srcX = Math.min(srcW - 1, Math.floor((x / width) * srcW))
      const colorIdx = imgData[srcY * srcW + srcX]
      const [pr, pg, pb, pa] = palette[colorIdx] || [0, 0, 0, 255]

      const off = (y * width + x) * 4
      rgba[off] = pr
      rgba[off + 1] = pg
      rgba[off + 2] = pb
      rgba[off + 3] = pa
    }
  }

  // 3. CRC32 Calculation
  const crcTable = new Uint32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) {
      c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1)
    }
    crcTable[n] = c >>> 0
  }
  const calcCrc32 = (buf) => {
    let c = 0xFFFFFFFF
    for (let i = 0; i < buf.length; i++) {
      c = (c >>> 8) ^ crcTable[(c ^ buf[i]) & 0xFF]
    }
    return (c ^ 0xFFFFFFFF) >>> 0
  }

  // 4. PNG Encoding
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
  const chunk = (type, data) => {
    const typeBuf = Buffer.from(type, "ascii")
    const lenBuf = Buffer.alloc(4)
    lenBuf.writeUInt32BE(data.length, 0)
    const toCrc = Buffer.concat([typeBuf, data])
    const crcVal = calcCrc32(toCrc)
    const crcBuf = Buffer.alloc(4)
    crcBuf.writeUInt32BE(crcVal, 0)
    return Buffer.concat([lenBuf, typeBuf, data, crcBuf])
  }

  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(width, 0)
  ihdr.writeUInt32BE(height, 4)
  ihdr[8] = 8
  ihdr[9] = 6
  ihdr[10] = 0
  ihdr[11] = 0
  ihdr[12] = 0

  const rowLen = width * 4
  const rawData = Buffer.alloc(height * (rowLen + 1))
  for (let y = 0; y < height; y++) {
    rawData[y * (rowLen + 1)] = 0
    rgba.copy(rawData, y * (rowLen + 1) + 1, y * rowLen, (y + 1) * rowLen)
  }

  const idatData = zlib.deflateSync(rawData)
  const pngBuf = Buffer.concat([
    sig,
    chunk("IHDR", ihdr),
    chunk("IDAT", idatData),
    chunk("IEND", Buffer.alloc(0))
  ])

  const pngPath = path.join(projectRoot, "slideshow.png")
  fs.writeFileSync(pngPath, pngBuf)
  console.log(`  - slideshow.png Size=${pngBuf.length} bytes (${width}x${height} preview image)`)
}

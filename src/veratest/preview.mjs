import fs from "fs"
import path from "path"
import zlib from "zlib"

// Generate high quality 560x384 PNG screenshot for Disk Collection preview
export const generatePreviewPng = (rootDir) => {
  const width = 560
  const height = 384
  const rgba = Buffer.alloc(width * height * 4)

  // Palette RGBA lookup
  const palette = [
    [0x00, 0x00, 0x00, 0xFF], // 0: Black
    [0x20, 0x60, 0xA0, 0xFF], // 1: Sky Blue
    [0xF0, 0x00, 0x00, 0xFF], // 2: Red
    [0xF0, 0x80, 0x00, 0xFF], // 3: Orange
    [0xF0, 0xE0, 0x00, 0xFF], // 4: Yellow
    [0x00, 0xE0, 0x00, 0xFF], // 5: Green
    [0x00, 0x80, 0xFF, 0xFF], // 6: Blue
    [0x20, 0x00, 0xC0, 0xFF], // 7: Indigo
    [0x80, 0x00, 0x80, 0xFF], // 8: Violet
    [0x10, 0x40, 0x00, 0xFF], // 9: Grass Green
    [0xFF, 0xFF, 0xFF, 0xFF], // 10: White
    [0xFF, 0xEE, 0x22, 0xFF], // 11: Sprite Yellow
    [0x44, 0xEE, 0xFF, 0xFF], // 12: Sprite Cyan
  ]

  // Render Rainbow background
  for (let y = 0; y < height; y++) {
    const dy = (height - 20) - y
    for (let x = 0; x < width; x++) {
      const dx = Math.abs((width / 2) - x)
      const r = Math.sqrt(dx * dx + dy * dy)
      let colIdx = 1 // Sky Blue
      if (y >= height - 40) {
        colIdx = 9 // Grass
      } else if (r >= 140 && r < 260) {
        const band = Math.floor((259 - r) / 17.1)
        colIdx = Math.max(0, Math.min(6, band)) + 2
      }
      const [pr, pg, pb, pa] = palette[colIdx]
      const off = (y * width + x) * 4
      rgba[off] = pr
      rgba[off + 1] = pg
      rgba[off + 2] = pb
      rgba[off + 3] = pa
    }
  }

  // Render 16x16 sprite stamp
  const spriteMap = [
    "0000001111000000",
    "0000112222110000",
    "0011223333221100",
    "0122331111332210",
    "1233112222113321",
    "1231221111221321",
    "1231221111221321",
    "1233112222113321",
    "1233112222113321",
    "0122331111332210",
    "0011223333221100",
    "0000112222110000",
    "000120000021000",
    "0012000000002100",
    "0120000000000210",
    "1200000000000021",
  ]
  const spriteColorMap = {
    '0': null,
    '1': palette[10], // White
    '2': palette[11], // Yellow
    '3': palette[12], // Cyan
  }

  const drawSprite = (sx, sy) => {
    for (let r = 0; r < 16; r++) {
      const row = spriteMap[r]
      for (let c = 0; c < 16; c++) {
        const ch = row[c]
        const col = spriteColorMap[ch]
        if (!col) continue
        for (let py = 0; py < 2; py++) {
          for (let px = 0; px < 2; px++) {
            const outX = sx + c * 2 + px
            const outY = sy + r * 2 + py
            if (outX >= 0 && outX < width && outY >= 0 && outY < height) {
              const off = (outY * width + outX) * 4
              rgba[off] = col[0]
              rgba[off + 1] = col[1]
              rgba[off + 2] = col[2]
              rgba[off + 3] = col[3]
            }
          }
        }
      }
    }
  }

  // Draw bouncing sprites across the preview image
  const spriteCoords = [
    [50, 40], [130, 80], [210, 50], [320, 70], [420, 45], [480, 100],
    [80, 160], [170, 190], [350, 180], [440, 210], [260, 120], [500, 160]
  ]
  for (const [sx, sy] of spriteCoords) {
    drawSprite(sx, sy)
  }

  // CRC32 table & calculation
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

  // Encode PNG
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

  const pngPath = path.join(rootDir, "veratest.png")
  fs.writeFileSync(pngPath, pngBuf)
  console.log(`  - veratest.png Size=${pngBuf.length} bytes (${width}x${height} preview image)`)
}

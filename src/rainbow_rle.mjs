// Generate precomputed, RLE-compressed 320x240 Rainbow Arc image
export const generateRainbowRleData = () => {
  const width = 320, height = 240
  const rawPixels = new Uint8Array(width * height)

  for (let y = 0; y < height; y++) {
    const dy = 230 - y
    for (let x = 0; x < width; x++) {
      const dx = Math.abs(160 - x)
      const r = Math.sqrt(dx * dx + dy * dy)
      let col = 1 // Deep Sky Blue (#2060A0)
      if (y >= 220) {
        col = 9 // Meadow Dark Green / Base
      } else if (r >= 85 && r < 155) {
        // Standard 7 Rainbow bands (Red -> Orange -> Yellow -> Green -> Blue -> Indigo -> Violet)
        const band = Math.floor((154 - r) / 10)
        col = band + 2
      }
      rawPixels[y * width + x] = col
    }
  }

  // RLE compress: [count, color, count, color, ...]
  const rle = []
  let i = 0
  while (i < rawPixels.length) {
    let color = rawPixels[i]
    let count = 1
    while (i + count < rawPixels.length && rawPixels[i + count] === color && count < 255) {
      count++
    }
    rle.push(count, color)
    i += count
  }
  rle.push(0x00, 0x00) // End marker
  return new Uint8Array(rle)
}

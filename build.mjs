import fs from "fs"
import path from "path"
import zlib from "zlib"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = __dirname

const hex = (val) => val.toString(16).toUpperCase()

// Complete 6502 assembler with guaranteed byte-length consistency
const assemble6502 = (lines, startAddress = 0x2000) => {
  let labels = {}

  const getEncodedBytes = (instr, operand, currentPc, currentLabels) => {
    const resolveVal = (op) => {
      let s = op.replace("#", "").replace("<", "").replace(">", "")
      let highByte = op.includes(">")
      let lowByte = op.includes("<")
      let add = 0
      if (s.includes("+")) {
        const p = s.split("+")
        s = p[0]
        add = parseInt(p[1].replace("$", "0x"))
      }
      let val = 0
      if (s in currentLabels) {
        val = currentLabels[s] + add
      } else if (s.startsWith("$")) {
        val = parseInt(s.substring(1), 16) + add
      } else {
        val = parseInt(s, 10) + add
      }
      if (highByte) return (val >> 8) & 0xFF
      if (lowByte) return val & 0xFF
      return val
    }

    if (instr === "HEX") {
      const hList = operand.split(/\s+/).filter(Boolean)
      return hList.map(h => parseInt(h, 16))
    }
    if (instr === "RTS") return [0x60]
    if (instr === "TXA") return [0x8A]
    if (instr === "TYA") return [0x98]
    if (instr === "TAX") return [0xAA]
    if (instr === "TAY") return [0xA8]
    if (instr === "INX") return [0xE8]
    if (instr === "INY") return [0xC8]
    if (instr === "DEX") return [0xCA]
    if (instr === "DEY") return [0x88]
    if (instr === "CLC") return [0x18]
    if (instr === "SEC") return [0x38]
    if (instr === "ASL") return [0x0A]
    if (instr === "LSR") return [0x4A]

    if (instr === "LDA") {
      if (operand.startsWith("#")) return [0xA9, resolveVal(operand)]
      if (operand.startsWith("(") && operand.endsWith("),Y")) {
        const val = resolveVal(operand.replace("(", "").replace("),Y", ""))
        return [0xB1, val & 0xFF]
      }
      if (operand.startsWith("$") && operand.length <= 3) {
        return [0xA5, resolveVal(operand)]
      }
      if (operand.endsWith(",X")) {
        const val = resolveVal(operand.replace(",X", ""))
        return [0xBD, val & 0xFF, (val >> 8) & 0xFF]
      }
      if (operand.endsWith(",Y")) {
        const val = resolveVal(operand.replace(",Y", ""))
        return [0xB9, val & 0xFF, (val >> 8) & 0xFF]
      }
      const val = resolveVal(operand)
      return [0xAD, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "STA") {
      if (operand.startsWith("(") && operand.endsWith("),Y")) {
        const val = resolveVal(operand.replace("(", "").replace("),Y", ""))
        return [0x91, val & 0xFF]
      }
      if (operand.startsWith("$") && operand.length <= 3) {
        return [0x85, resolveVal(operand)]
      }
      if (operand.endsWith(",X")) {
        const val = resolveVal(operand.replace(",X", ""))
        return [0x9D, val & 0xFF, (val >> 8) & 0xFF]
      }
      if (operand.endsWith(",Y")) {
        const val = resolveVal(operand.replace(",Y", ""))
        return [0x99, val & 0xFF, (val >> 8) & 0xFF]
      }
      const val = resolveVal(operand)
      return [0x8D, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "STX") {
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0x86, val & 0xFF]
      return [0x8E, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "STY") {
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0x84, val & 0xFF]
      return [0x8C, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "LDX") {
      if (operand.startsWith("#")) return [0xA2, resolveVal(operand)]
      if (operand.startsWith("$") && operand.length <= 3) return [0xA6, resolveVal(operand)]
      const val = resolveVal(operand)
      return [0xAE, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "LDY") {
      if (operand.startsWith("#")) return [0xA0, resolveVal(operand)]
      if (operand.startsWith("$") && operand.length <= 3) return [0xA4, resolveVal(operand)]
      const val = resolveVal(operand)
      return [0xAC, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "ADC") {
      if (operand.startsWith("#")) return [0x69, resolveVal(operand)]
      if (operand.endsWith(",X")) {
        const val = resolveVal(operand.replace(",X", ""))
        return [0x7D, val & 0xFF, (val >> 8) & 0xFF]
      }
      const val = resolveVal(operand)
      return [0x6D, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "SBC") {
      if (operand.startsWith("#")) return [0xE9, resolveVal(operand)]
      const val = resolveVal(operand)
      return [0xED, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "ORA") {
      if (operand.startsWith("#")) return [0x09, resolveVal(operand)]
      if (operand.startsWith("$") && operand.length <= 3) return [0x05, resolveVal(operand)]
      const val = resolveVal(operand)
      return [0x0D, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "AND") {
      if (operand.startsWith("#")) return [0x29, resolveVal(operand)]
      if (operand.startsWith("$") && operand.length <= 3) return [0x25, resolveVal(operand)]
      const val = resolveVal(operand)
      return [0x2D, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "EOR") {
      if (operand.startsWith("#")) return [0x49, resolveVal(operand)]
      if (operand.startsWith("$") && operand.length <= 3) return [0x45, resolveVal(operand)]
      const val = resolveVal(operand)
      return [0x4D, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "CMP") {
      if (operand.startsWith("#")) return [0xC9, resolveVal(operand)]
      const val = resolveVal(operand)
      return [0xCD, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "CPX") return [0xE0, resolveVal(operand)]
    if (instr === "CPY") return [0xC0, resolveVal(operand)]

    if (instr === "JMP") {
      const val = resolveVal(operand)
      return [0x4C, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (["BNE", "BEQ", "BPL", "BMI", "BCC", "BCS"].includes(instr)) {
      const opcodes = { BNE: 0xD0, BEQ: 0xF0, BPL: 0x10, BMI: 0x30, BCC: 0x90, BCS: 0xB0 }
      const target = resolveVal(operand)
      const offset = target - (currentPc + 2)
      return [opcodes[instr], (offset & 0xFF)]
    }

    if (instr === "INC") {
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0xE6, val & 0xFF]
      return [0xEE, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "DEC") {
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0xC6, val & 0xFF]
      return [0xCE, val & 0xFF, (val >> 8) & 0xFF]
    }

    throw new Error(`Unknown instruction: ${instr}`)
  }

  // Pass 1: find labels by calling getEncodedBytes with empty/mock labels
  let pc = startAddress
  for (let rawLine of lines) {
    let line = rawLine.split("//")[0].split(";")[0].trim()
    if (!line) continue
    if (line.startsWith("ORG") || line.startsWith("* =")) continue

    const parts = line.split(/\s+/)
    if (parts[1] === "EQU" || parts[1] === "=") {
      const valStr = parts[2].replace("$", "0x")
      labels[parts[0].replace(":", "")] = parseInt(valStr, 16) || parseInt(valStr, 10)
      continue
    }

    if (parts[0].endsWith(":")) {
      labels[parts[0].slice(0, -1)] = pc
      continue
    }

    const instr = parts[0].toUpperCase()
    const operand = instr === "HEX" ? parts.slice(1).join(" ") : parts.slice(1).join("")
    const b = getEncodedBytes(instr, operand, pc, {})
    pc += b.length
  }

  // Pass 2: generate real bytes using exact same function and resolved labels
  pc = startAddress
  let bytes = []
  for (let rawLine of lines) {
    let line = rawLine.split("//")[0].split(";")[0].trim()
    if (!line) continue
    if (line.startsWith("ORG") || line.startsWith("* =") || line.includes("EQU") || line.includes(" = ")) continue
    if (line.endsWith(":")) continue

    const parts = line.split(/\s+/)
    const instr = parts[0].toUpperCase()
    const operand = instr === "HEX" ? parts.slice(1).join(" ") : parts.slice(1).join("")
    const b = getEncodedBytes(instr, operand, pc, labels)
    bytes.push(...b)
    pc += b.length
  }

  return new Uint8Array(bytes)
}

// 6502 Sprite Demo Assembly (16 smooth 16x16 glowing crystal sprites bouncing on 640x480 screen)
const getSpriteDemoAsm = (slot = 2, startAddress = 0x2000) => {
  const base = 0xC000 + slot * 0x100
  return [
    `VERA_ADDR_L EQU $${hex(base + 0x00)}`,
    `VERA_ADDR_M EQU $${hex(base + 0x01)}`,
    `VERA_ADDR_H EQU $${hex(base + 0x02)}`,
    `VERA_DATA0  EQU $${hex(base + 0x03)}`,
    `VERA_DATA1  EQU $${hex(base + 0x04)}`,
    `VERA_CTRL   EQU $${hex(base + 0x05)}`,
    `VERA_IEN    EQU $${hex(base + 0x06)}`,
    `VERA_ISR    EQU $${hex(base + 0x07)}`,
    `VERA_DC_VID EQU $${hex(base + 0x09)}`,
    `VERA_DC_HSC EQU $${hex(base + 0x0A)}`,
    `VERA_DC_VSC EQU $${hex(base + 0x0B)}`,
    `START:`,
    ` LDA #$00`,
    ` STA VERA_CTRL`,
    ` LDA #$41`,            // Enable VGA (1) + Sprites (0x40)
    ` STA VERA_DC_VID`,
    ` LDA #$40`,            // 2x scale (Consistent, crisp, large sprites!)
    ` STA VERA_DC_HSC`,
    ` STA VERA_DC_VSC`,
    `// Setup Palette at $1FA00: Entry 0 Black, Entry 1 White, Entry 2 Yellow, Entry 3 Cyan`,
    ` LDA #$00`,
    ` STA VERA_ADDR_L`,
    ` LDA #$FA`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,            // Stride +1
    ` STA VERA_ADDR_H`,
    ` LDA #$00`,            // Entry 0 (Black $0000)
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` LDA #$FF`,            // Entry 1 (White $0FFF)
    ` STA VERA_DATA0`,
    ` LDA #$0F`,
    ` STA VERA_DATA0`,
    ` LDA #$F0`,            // Entry 2 (Yellow $0FF0)
    ` STA VERA_DATA0`,
    ` LDA #$0F`,
    ` STA VERA_DATA0`,
    ` LDA #$0F`,            // Entry 3 (Cyan $00FF)
    ` STA VERA_DATA0`,
    ` LDA #$00`,
    ` STA VERA_DATA0`,
    `// Init 16 Sprite Attributes at $1FC00`,
    ` LDA #$00`,
    ` STA VERA_ADDR_L`,
    ` LDA #$FC`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,            // Stride +1
    ` STA VERA_ADDR_H`,
    ` LDX #$00`,
    `INIT_SPR:`,
    ` LDA #$00`,            // Shape Address Low ($10000 >> 5 = $0800)
    ` STA VERA_DATA0`,
    ` LDA #$08`,            // Shape Address High (4bpp mode)
    ` STA VERA_DATA0`,
    ` LDA SPR_X_LO,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_X_HI,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_Y_LO,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_Y_HI,X`,
    ` STA VERA_DATA0`,
    ` LDA #$0C`,            // Z-depth = 3 (Front)
    ` STA VERA_DATA0`,
    ` LDA #$50`,            // Height=16 (1), Width=16 (1), Palette Offset=0
    ` STA VERA_DATA0`,
    ` INX`,
    ` CPX #$10`,            // 16 Sprites
    ` BNE INIT_SPR`,
    `// Upload 16x16 4bpp Sprite Pixels to $10000 (128 bytes)`,
    ` LDA #$00`,
    ` STA VERA_ADDR_L`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,
    ` STA VERA_ADDR_H`,
    ` LDX #$00`,
    `LOAD_SHAPE:`,
    ` LDA SPR_PIXELS,X`,
    ` STA VERA_DATA0`,
    ` INX`,
    ` CPX #$80`,            // 128 bytes
    ` BNE LOAD_SHAPE`,
    `ANIM_LOOP:`,
    ` LDX #$00`,
    `UPD_SPRITES:`,
    `// 1. Update X in RAM`,
    ` LDA SPR_X_LO,X`,
    ` CLC`,
    ` ADC SPEED_X,X`,
    ` STA SPR_X_LO,X`,
    ` LDA SPR_X_HI,X`,
    ` ADC #$00`,
    ` STA SPR_X_HI,X`,
    ` CMP #$01`,            // 320 = $0140
    ` BCC X_OK`,
    ` BNE RST_X`,
    ` LDA SPR_X_LO,X`,
    ` CMP #$30`,
    ` BCC X_OK`,
    `RST_X:`,
    ` LDA #$00`,
    ` STA SPR_X_LO,X`,
    ` STA SPR_X_HI,X`,
    `X_OK:`,
    `// 2. Update Y in RAM`,
    ` LDA SPR_Y_LO,X`,
    ` CLC`,
    ` ADC SPEED_Y,X`,
    ` STA SPR_Y_LO,X`,
    ` CMP #224`,            // 240 - 16 = 224 ($E0)
    ` BCC Y_OK`,
    `RST_Y:`,
    ` LDA #$00`,
    ` STA SPR_Y_LO,X`,
    `Y_OK:`,
    `// 3. Atomically write X and Y to VERA Sprite Attributes`,
    ` TXA`,
    ` ASL`,
    ` ASL`,
    ` ASL`,
    ` CLC`,
    ` ADC #$02`,            // Offset 2 = X_LO
    ` STA VERA_ADDR_L`,
    ` LDA #$FC`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,            // Stride +1
    ` STA VERA_ADDR_H`,
    ` LDA SPR_X_LO,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_X_HI,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_Y_LO,X`,
    ` STA VERA_DATA0`,
    ` LDA #$00`,
    ` STA VERA_DATA0`,
    ` INX`,
    ` CPX #$10`,
    ` BNE UPD_SPRITES`,
    `// Check Keyboard Strobe at $C000`,
    ` LDA $C000`,
    ` BPL NO_KEY`,
    ` STA $C010`,
    ` RTS`,
    `NO_KEY:`,
    ` LDY #$20`,
    `DLY1:`,
    ` LDX #$FF`,
    `DLY2:`,
    ` DEX`,
    ` BNE DLY2`,
    ` DEY`,
    ` BNE DLY1`,
    ` JMP ANIM_LOOP`,
    `// 128 bytes for 16x16 4bpp Crystal Alien Sprite`,
    `SPR_PIXELS:`,
    ` HEX 00 00 00 11 11 00 00 00`,
    ` HEX 00 00 11 22 22 11 00 00`,
    ` HEX 00 11 22 33 33 22 11 00`,
    ` HEX 01 22 33 11 11 33 22 10`,
    ` HEX 12 33 11 22 22 11 33 21`,
    ` HEX 12 31 22 11 11 22 13 21`,
    ` HEX 12 31 22 11 11 22 13 21`,
    ` HEX 12 33 11 22 22 11 33 21`,
    ` HEX 12 33 11 22 22 11 33 21`,
    ` HEX 01 22 33 11 11 33 22 10`,
    ` HEX 00 11 22 33 33 22 11 00`,
    ` HEX 00 00 11 22 22 11 00 00`,
    ` HEX 00 01 20 00 00 02 10 00`,
    ` HEX 00 12 00 00 00 00 21 00`,
    ` HEX 01 20 00 00 00 00 02 10`,
    ` HEX 12 00 00 00 00 00 00 21`,
    `// Dispersed starting coordinates across 320x240 screen`,
    `SPR_X_LO:`,
    ` HEX 20 60 A0 E0 20 60 A0 E0 10 50 90 D0 30 70 B0 F0`,
    `SPR_X_HI:`,
    ` HEX 00 00 00 00 01 01 01 01 00 00 00 00 01 01 01 01`,
    `SPR_Y_LO:`,
    ` HEX 10 40 70 A0 D0 20 50 80 B0 E0 30 60 90 C0 15 45`,
    `SPR_Y_HI:`,
    ` HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00`,
    `SPEED_X:`,
    ` HEX 02 03 01 02 03 01 02 04 03 01 02 03 02 01 03 02`,
    `SPEED_Y:`,
    ` HEX 01 02 03 01 02 04 02 01 03 02 01 02 03 01 02 03`,
  ]
}

// Generate 6502 Assembly for Sprite Demo WITH Rich 4-Voice Stereo VERA PSG Chiptune Music
const getSpriteSoundDemoAsm = (slot = 2, startAddress = 0x2000) => {
  const base = 0xC000 + slot * 0x100

  const asm = [
    `VERA_ADDR_L EQU $${hex(base + 0x00)}`,
    `VERA_ADDR_M EQU $${hex(base + 0x01)}`,
    `VERA_ADDR_H EQU $${hex(base + 0x02)}`,
    `VERA_DATA0  EQU $${hex(base + 0x03)}`,
    `VERA_DATA1  EQU $${hex(base + 0x04)}`,
    `VERA_CTRL   EQU $${hex(base + 0x05)}`,
    `VERA_IEN    EQU $${hex(base + 0x06)}`,
    `VERA_ISR    EQU $${hex(base + 0x07)}`,
    `VERA_DC_VID EQU $${hex(base + 0x09)}`,
    `VERA_DC_HSC EQU $${hex(base + 0x0A)}`,
    `VERA_DC_VSC EQU $${hex(base + 0x0B)}`,
    `START:`,
    ` LDA #$00`,
    ` STA VERA_CTRL`,
    ` LDA #$41`,            // Enable VGA (1) + Sprites (0x40)
    ` STA VERA_DC_VID`,
    ` LDA #$40`,            // 2x scale
    ` STA VERA_DC_HSC`,
    ` STA VERA_DC_VSC`,
    `// Setup Palette at $1FA00`,
    ` LDA #$00`,
    ` STA VERA_ADDR_L`,
    ` LDA #$FA`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,            // Stride +1
    ` STA VERA_ADDR_H`,
    ` LDA #$00`,            // Entry 0 (Black)
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` LDA #$FF`,            // Entry 1 (White)
    ` STA VERA_DATA0`,
    ` LDA #$0F`,
    ` STA VERA_DATA0`,
    ` LDA #$F0`,            // Entry 2 (Yellow)
    ` STA VERA_DATA0`,
    ` LDA #$0F`,
    ` STA VERA_DATA0`,
    ` LDA #$0F`,            // Entry 3 (Cyan)
    ` STA VERA_DATA0`,
    ` LDA #$00`,
    ` STA VERA_DATA0`,
    `// Init 16 Sprite Attributes at $1FC00`,
    ` LDA #$00`,
    ` STA VERA_ADDR_L`,
    ` LDA #$FC`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,            // Stride +1
    ` STA VERA_ADDR_H`,
    ` LDX #$00`,
    `INIT_SPR:`,
    ` LDA #$00`,            // Shape Address Low
    ` STA VERA_DATA0`,
    ` LDA #$08`,            // Shape Address High
    ` STA VERA_DATA0`,
    ` LDA SPR_X_LO,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_X_HI,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_Y_LO,X`,
    ` STA VERA_DATA0`,
    ` LDA #$00`,
    ` STA VERA_DATA0`,
    ` LDA #$0C`,            // Z-depth 3 (front)
    ` STA VERA_DATA0`,
    ` LDA #$50`,            // 16x16 size
    ` STA VERA_DATA0`,
    ` INX`,
    ` CPX #$10`,
    ` BNE INIT_SPR`,
    `// Upload Sprite Pixel Data to VRAM $10000`,
    ` LDA #$00`,
    ` STA VERA_ADDR_L`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,
    ` STA VERA_ADDR_H`,
    ` LDX #$00`,
    `LOAD_PX:`,
    ` LDA SPR_PIXELS,X`,
    ` STA VERA_DATA0`,
    ` INX`,
    ` CPX #$80`,            // 128 bytes
    ` BNE LOAD_PX`,
    `// Initialize Music Engine state in Zero Page`,
    ` LDA #$00`,
    ` STA $EB`,             // Current Step (0..31)
    ` LDA #$01`,
    ` STA $EC`,             // Tick Timer
    ` LDA #$3F`,
    ` STA $ED`,             // Master Lead Volume Envelope
    `ANIM_LOOP:`,
    `// 1. Advance Music Clock & Envelope`,
    ` DEC $EC`,
    ` BNE TICK_ENV`,
    ` LDA #$05`,            // Note duration (tempo)
    ` STA $EC`,
    ` LDA #$3F`,
    ` STA $ED`,             // Reset volume envelope
    ` LDY $EB`,
    `// Set VERA VRAM address to PSG Channel 0 at $1F9C0`,
    ` LDA #$C0`,
    ` STA VERA_ADDR_L`,
    ` LDA #$F9`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,            // Stride +1
    ` STA VERA_ADDR_H`,
    `// Voice 1 (Left Stereo Lead Melody - Pulse 25%)`,
    ` LDA LEAD_LO,Y`,
    ` STA VERA_DATA0`,
    ` LDA LEAD_HI,Y`,
    ` STA VERA_DATA0`,
    ` LDA #$7F`,            // Left pan, max vol
    ` STA VERA_DATA0`,
    ` LDA #$10`,            // Pulse wave 25% duty
    ` STA VERA_DATA0`,
    `// Voice 2 (Right Stereo Counter Melody - Sawtooth / Pulse)`,
    ` LDA HARM_LO,Y`,
    ` STA VERA_DATA0`,
    ` LDA HARM_HI,Y`,
    ` STA VERA_DATA0`,
    ` LDA #$BB`,            // Right pan, rich vol
    ` STA VERA_DATA0`,
    ` LDA #$40`,            // Sawtooth wave
    ` STA VERA_DATA0`,
    `// Voice 3 (Center Deep Punchy Bass - Triangle)`,
    ` LDA BASS_LO,Y`,
    ` STA VERA_DATA0`,
    ` LDA BASS_HI,Y`,
    ` STA VERA_DATA0`,
    ` LDA #$FE`,            // Full stereo, punchy vol
    ` STA VERA_DATA0`,
    ` LDA #$80`,            // Triangle wave
    ` STA VERA_DATA0`,
    `// Voice 4 (Center Percussion Kick/Snare/Hihat - Noise/Pulse)`,
    ` LDA DRUM_FRQ,Y`,
    ` STA VERA_DATA0`,
    ` LDA #$02`,
    ` STA VERA_DATA0`,
    ` LDA DRUM_VOL,Y`,
    ` STA VERA_DATA0`,
    ` LDA DRUM_WAV,Y`,      // Noise or low thump
    ` STA VERA_DATA0`,
    ` INY`,
    ` CPY #$20`,            // 32-step rich melody loop
    ` BNE STEP_OK`,
    ` LDY #$00`,
    `STEP_OK:`,
    ` STY $EB`,
    ` JMP SPRITE_UPDATE`,
    `TICK_ENV:`,
    `// Decay Lead volume envelope for natural attack/release`,
    ` LDA $ED`,
    ` SEC`,
    ` SBC #$06`,
    ` BCS VOL_OK`,
    ` LDA #$00`,
    `VOL_OK:`,
    ` STA $ED`,
    ` ORA #$40`,            // Keep Left pan bit
    ` STA VERA_DATA1`,      // Quick write to volume via port
    `SPRITE_UPDATE:`,
    `// 2. Update 16 Sprites in RAM`,
    ` LDX #$00`,
    `UPD_SPRITES:`,
    ` LDA SPR_X_LO,X`,
    ` CLC`,
    ` ADC SPEED_X,X`,
    ` STA SPR_X_LO,X`,
    ` LDA SPR_X_HI,X`,
    ` ADC #$00`,
    ` STA SPR_X_HI,X`,
    ` CMP #$01`,            // 320 = $0140
    ` BCC X_OK`,
    ` BNE RST_X`,
    ` LDA SPR_X_LO,X`,
    ` CMP #$30`,
    ` BCC X_OK`,
    `RST_X:`,
    ` LDA #$00`,
    ` STA SPR_X_LO,X`,
    ` STA SPR_X_HI,X`,
    `X_OK:`,
    ` LDA SPR_Y_LO,X`,
    ` CLC`,
    ` ADC SPEED_Y,X`,
    ` STA SPR_Y_LO,X`,
    ` CMP #224`,
    ` BCC Y_OK`,
    `RST_Y:`,
    ` LDA #$00`,
    ` STA SPR_Y_LO,X`,
    `Y_OK:`,
    ` TXA`,
    ` ASL`,
    ` ASL`,
    ` ASL`,
    ` CLC`,
    ` ADC #$02`,            // Offset 2 = X_LO
    ` STA VERA_ADDR_L`,
    ` LDA #$FC`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,            // Stride +1
    ` STA VERA_ADDR_H`,
    ` LDA SPR_X_LO,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_X_HI,X`,
    ` STA VERA_DATA0`,
    ` LDA SPR_Y_LO,X`,
    ` STA VERA_DATA0`,
    ` LDA #$00`,
    ` STA VERA_DATA0`,
    ` INX`,
    ` CPX #$10`,
    ` BNE UPD_SPRITES`,
    `// Check Keyboard Strobe at $C000`,
    ` LDA $C000`,
    ` BPL NO_KEY`,
    ` STA $C010`,
    `// Silence all 4 PSG Voices before returning`,
    ` LDA #$C0`,
    ` STA VERA_ADDR_L`,
    ` LDA #$F9`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,
    ` STA VERA_ADDR_H`,
    ` LDA #$00`,
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,       // V1 vol = 0
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,       // V2 vol = 0
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,       // V3 vol = 0
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,
    ` STA VERA_DATA0`,       // V4 vol = 0
    ` STA VERA_DATA0`,
    ` RTS`,
    `NO_KEY:`,
    ` LDY #$14`,
    `DLY1:`,
    ` LDX #$FF`,
    `DLY2:`,
    ` DEX`,
    ` BNE DLY2`,
    ` DEY`,
    ` BNE DLY1`,
    ` JMP ANIM_LOOP`,
    `// 128 bytes for 16x16 4bpp Crystal Alien Sprite`,
    `SPR_PIXELS:`,
    ` HEX 00 00 00 11 11 00 00 00`,
    ` HEX 00 00 11 22 22 11 00 00`,
    ` HEX 00 11 22 33 33 22 11 00`,
    ` HEX 01 22 33 11 11 33 22 10`,
    ` HEX 12 33 11 22 22 11 33 21`,
    ` HEX 12 31 22 11 11 22 13 21`,
    ` HEX 12 31 22 11 11 22 13 21`,
    ` HEX 12 33 11 22 22 11 33 21`,
    ` HEX 12 33 11 22 22 11 33 21`,
    ` HEX 01 22 33 11 11 33 22 10`,
    ` HEX 00 11 22 33 33 22 11 00`,
    ` HEX 00 00 11 22 22 11 00 00`,
    ` HEX 00 01 20 00 00 02 10 00`,
    ` HEX 00 12 00 00 00 00 21 00`,
    ` HEX 01 20 00 00 00 00 02 10`,
    ` HEX 12 00 00 00 00 00 00 21`,
    `SPR_X_LO:`,
    ` HEX 20 60 A0 E0 20 60 A0 E0 10 50 90 D0 30 70 B0 F0`,
    `SPR_X_HI:`,
    ` HEX 00 00 00 00 01 01 01 01 00 00 00 00 01 01 01 01`,
    `SPR_Y_LO:`,
    ` HEX 10 40 70 A0 D0 20 50 80 B0 E0 30 60 90 C0 15 45`,
    `SPR_Y_HI:`,
    ` HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00`,
    `SPEED_X:`,
    ` HEX 02 03 01 02 03 01 02 04 03 01 02 03 02 01 03 02`,
    `SPEED_Y:`,
    ` HEX 01 02 03 01 02 04 02 01 03 02 01 02 03 01 02 03`,
    `// 32-Step Arcade Chiptune Tables (Lead + Harmony + Slap Bass + Drum Section)`,
    `LEAD_LO:`,
    ` HEX BE 75 1C 7D 7D 1C 75 14 BE 75 1C 9D 9D 1C 75 14`,
    ` HEX BE BE 14 75 1C 1C 9D 7D 7D 1C 9D 1C 75 14 BE 00`,
    `LEAD_HI:`,
    ` HEX 02 03 04 05 05 04 03 03 02 03 04 04 04 04 03 03`,
    ` HEX 02 02 03 03 04 04 04 05 05 04 04 04 03 03 02 00`,
    `HARM_LO:`,
    ` HEX 5F 1C 9D 1C 1C 9D 1C 75 5F 1C 9D 7D 7D 9D 1C 75`,
    ` HEX 5F 5F 75 1C 9D 9D 7D 1C 1C 9D 7D 9D 1C 75 5F 00`,
    `HARM_HI:`,
    ` HEX 01 04 04 04 04 04 04 03 01 04 04 05 05 04 04 03`,
    ` HEX 01 01 03 04 04 04 05 04 04 04 05 04 04 03 01 00`,
    `BASS_LO:`,
    ` HEX 5F BE 5F BE 0E 1C 0E 1C 4F 9D 4F 9D 8D 14 8D 14`,
    ` HEX 5F BE 5F BE 0E 1C 0E 1C 8D 14 0E 1C 5F BE 5F 00`,
    `BASS_HI:`,
    ` HEX 01 02 01 02 02 04 02 04 02 04 02 04 01 03 01 03`,
    ` HEX 01 02 01 02 02 04 02 04 01 03 02 04 01 02 01 00`,
    `DRUM_FRQ:`,
    ` HEX 40 80 40 A0 40 80 40 A0 40 80 40 A0 40 A0 40 A0`,
    ` HEX 40 80 40 A0 40 80 40 A0 40 A0 40 A0 40 40 40 00`,
    `DRUM_VOL:`,
    ` HEX FF 60 FF E0 FF 60 FF E0 FF 60 FF E0 FF E0 FF E0`,
    ` HEX FF 60 FF E0 FF 60 FF E0 FF E0 FF E0 FF FF FF 00`,
    `DRUM_WAV:`,
    ` HEX 00 C0 00 C0 00 C0 00 C0 00 C0 00 C0 00 C0 00 C0`,
    ` HEX 00 C0 00 C0 00 C0 00 C0 00 C0 00 C0 00 00 00 00`,
  ]
  return asm
}

// Generate precomputed, RLE-compressed 320x240 Rainbow Arc image
const generateRainbowRleData = () => {
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
        // Standard 7 Rainbow bands (from outside to inside: Red -> Orange -> Yellow -> Green -> Blue -> Indigo -> Violet)
        // r = 145..155 -> Red (2)
        // r = 135..145 -> Orange (3)
        // r = 125..135 -> Yellow (4)
        // r = 115..125 -> Green (5)
        // r = 105..115 -> Blue (6)
        // r = 95..105  -> Indigo (7)
        // r = 85..95   -> Violet (8)
        const band = Math.floor((154 - r) / 10) // 0 to 6
        col = band + 2 // Colors 2 (Red) to 8 (Violet)
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
  rle.push(0x00, 0x00) // End marker (count 0)
  return new Uint8Array(rle)
}

// Build Mode 7 Real Rainbow Arc Binary with instant 6502 RLE decompressor
const buildMode7Binary = (slot = 2) => {
  const base = 0xC000 + slot * 0x100
  const rleData = generateRainbowRleData()

  const asm = [
    `VERA_ADDR_L EQU $${hex(base + 0x00)}`,
    `VERA_ADDR_M EQU $${hex(base + 0x01)}`,
    `VERA_ADDR_H EQU $${hex(base + 0x02)}`,
    `VERA_DATA0  EQU $${hex(base + 0x03)}`,
    `VERA_DATA1  EQU $${hex(base + 0x04)}`,
    `VERA_CTRL   EQU $${hex(base + 0x05)}`,
    `VERA_DC_VID EQU $${hex(base + 0x09)}`,
    `VERA_DC_HSC EQU $${hex(base + 0x0A)}`,
    `VERA_DC_VSC EQU $${hex(base + 0x0B)}`,
    `VERA_L0_CFG EQU $${hex(base + 0x0D)}`,
    `VERA_L0_MAP EQU $${hex(base + 0x0E)}`,
    `VERA_L0_TIL EQU $${hex(base + 0x0F)}`,
    `VERA_L0_HSC_L EQU $${hex(base + 0x10)}`,
    `VERA_L0_HSC_H EQU $${hex(base + 0x11)}`,
    `VERA_L0_VSC_L EQU $${hex(base + 0x12)}`,
    `VERA_L0_VSC_H EQU $${hex(base + 0x13)}`,
    `RLE_PTR_L    EQU $EB`,
    `RLE_PTR_H    EQU $EC`,
    `COUNT        EQU $ED`,
    `START:`,
    ` LDA #$00`,
    ` STA VERA_CTRL`,
    ` LDA #$11`,            // VGA output + Layer 0 Enable
    ` STA VERA_DC_VID`,
    ` LDA #$40`,            // 2x scale (320x240 stretched to 640x480)
    ` STA VERA_DC_HSC`,
    ` STA VERA_DC_VSC`,
    ` LDA #$07`,            // 8bpp Bitmap Mode
    ` STA VERA_L0_CFG`,
    ` LDA #$00`,
    ` STA VERA_L0_MAP`,
    ` STA VERA_L0_TIL`,
    ` STA VERA_L0_HSC_L`,
    ` STA VERA_L0_HSC_H`,
    ` STA VERA_L0_VSC_L`,
    ` STA VERA_L0_VSC_H`,
    `// Setup Authentic Rainbow Palette at $1FA00`,
    ` LDA #$00`,
    ` STA VERA_ADDR_L`,
    ` LDA #$FA`,
    ` STA VERA_ADDR_M`,
    ` LDA #$11`,            // Stride +1
    ` STA VERA_ADDR_H`,
    ` LDX #$00`,
    `LOAD_PAL:`,
    ` LDA PALETTE_DATA,X`,
    ` STA VERA_DATA0`,
    ` INX`,
    ` CPX #$20`,
    ` BNE LOAD_PAL`,
    `// Point VERA to VRAM $00000`,
    ` LDA #$00`,
    ` STA VERA_ADDR_L`,
    ` STA VERA_ADDR_M`,
    ` LDA #$10`,            // Stride +1
    ` STA VERA_ADDR_H`,
    `// Setup RLE Pointer`,
    ` LDA #<RLE_IMAGE_DATA`,
    ` STA RLE_PTR_L`,
    ` LDA #>RLE_IMAGE_DATA`,
    ` STA RLE_PTR_H`,
    `// Instant RLE Decompressor`,
    `DECOMPRESS_LOOP:`,
    ` LDY #$00`,
    ` LDA (RLE_PTR_L),Y`,   // Read Count
    ` BEQ DONE_DRAWING`,    // Count 0 = End
    ` STA COUNT`,
    ` INY`,
    ` LDA (RLE_PTR_L),Y`,   // Read Color
    ` LDX COUNT`,
    `EMIT_PIXELS:`,
    ` STA VERA_DATA0`,
    ` DEX`,
    ` BNE EMIT_PIXELS`,
    `// Advance Pointer by 2`,
    ` LDA RLE_PTR_L`,
    ` CLC`,
    ` ADC #$02`,
    ` STA RLE_PTR_L`,
    ` LDA RLE_PTR_H`,
    ` ADC #$00`,
    ` STA RLE_PTR_H`,
    ` JMP DECOMPRESS_LOOP`,
    `DONE_DRAWING:`,
    ` RTS`,                 // Finished drawing instantly! Return straight to BASIC menu
    `// Palette: 0:Black, 1:SkyBlue, 2:Red, 3:Orange, 4:Yellow, 5:Green, 6:Blue, 7:Indigo, 8:Violet, 9:Grass`,
    `// Little-Endian 12-bit RGB: Byte 0: [G4 B4], Byte 1: [0 R4]`,
    `PALETTE_DATA:`,
    ` HEX 00 00 6A 02 00 0F 80 0F E0 0F E0 00 8F 00 0C 02`,
    ` HEX 08 08 40 01 00 00 00 00 00 00 00 00 00 00 00 00`,
    `RLE_IMAGE_DATA:`
  ]

  const codeBytes = assemble6502(asm, 0x2000)
  return new Uint8Array([...codeBytes, ...rleData])
}

// Build Applesoft BASIC STARTUP Menu (Auto-detects VERA card on Slot 2 or 4)
const buildStartupBasic = () => {
  let mem = []
  let currAddr = 0x0801

  const addLine = (lineNo, tokensAndText) => {
    const lineLen = tokensAndText.length + 1
    const nextAddr = currAddr + 4 + lineLen
    mem.push(nextAddr & 0xFF, (nextAddr >> 8) & 0xFF)
    mem.push(lineNo & 0xFF, (lineNo >> 8) & 0xFF)
    mem.push(...tokensAndText, 0x00)
    currAddr = nextAddr
  }

  const S = (str) => Array.from(str).map(c => c.charCodeAt(0))

  // Tokens: TEXT=0x89, HOME=0x97, PRINT=0xBA, POKE=0xB9, PEEK=0xE2, IF=0xAD, = = 0xD0, THEN=0xC4, AND=0xCD, GOTO=0xAB, GOSUB=0xB0, RETURN=0xB1, INPUT=0x84, CHR$=0xE7, END=0x80
  addLine(10, [0x89].flat()) // 10 TEXT
  addLine(15, [0x97].flat()) // 15 HOME
  addLine(20, [0xBA, S(' "VERA GRAPHICS TEST DEMO FOR APPLE2TS"')].flat())
  addLine(22, [0xBA, S(' "BY ANOMIXER https://github.com/anomixer"')].flat())
  addLine(25, [0xBA, S(' "---------------------------------------"')].flat())

  // Robust VERA Probe using direct literal addresses (no + operators or subroutines needed)
  // Slot 2: ADDR_L=49664, ADDR_M=49665, ADDR_H=49666, DATA0=49667, CTRL=49669
  // Slot 4: ADDR_L=50176, ADDR_M=50177, ADDR_H=50178, DATA0=50179, CTRL=50181
  addLine(30, [S('S'), 0xD0, S('0')].flat()) // 30 S = 0

  // Test Slot 2
  addLine(31, [0xB9, S(' 49669,1')].flat())
  addLine(32, [0xAD, 0xE2, S('(49669)'), 0xD0, S('1'), 0xC4, 0xAB, S(' 34')].flat())
  addLine(33, [0xAB, S(' 45')].flat())
  addLine(34, [0xB9, S(' 49669,0')].flat())
  addLine(35, [0xAD, 0xE2, S('(49669)'), 0xD0, S('0'), 0xC4, 0xAB, S(' 37')].flat())
  addLine(36, [0xAB, S(' 45')].flat())
  addLine(37, [0xB9, S(' 49664,0')].flat())
  addLine(38, [0xB9, S(' 49665,0')].flat())
  addLine(39, [0xB9, S(' 49666,0')].flat())
  addLine(40, [0xB9, S(' 49667,222')].flat())
  addLine(41, [0xAD, 0xE2, S('(49667)'), 0xD0, S('222'), 0xC4, 0xAB, S(' 43')].flat())
  addLine(42, [0xAB, S(' 45')].flat())
  addLine(43, [0xB9, S(' 49667,111')].flat())
  addLine(44, [0xAD, 0xE2, S('(49667)'), 0xD0, S('111'), 0xC4, S('S'), 0xD0, S('2')].flat())

  // Test Slot 4 (if Slot 2 not detected)
  addLine(45, [0xAD, S('S'), 0xD0, S('2'), 0xC4, 0xAB, S(' 60')].flat())
  addLine(46, [0xB9, S(' 50181,1')].flat())
  addLine(47, [0xAD, 0xE2, S('(50181)'), 0xD0, S('1'), 0xC4, 0xAB, S(' 49')].flat())
  addLine(48, [0xAB, S(' 60')].flat())
  addLine(49, [0xB9, S(' 50181,0')].flat())
  addLine(50, [0xAD, 0xE2, S('(50181)'), 0xD0, S('0'), 0xC4, 0xAB, S(' 52')].flat())
  addLine(51, [0xAB, S(' 60')].flat())
  addLine(52, [0xB9, S(' 50176,0')].flat())
  addLine(53, [0xB9, S(' 50177,0')].flat())
  addLine(54, [0xB9, S(' 50178,0')].flat())
  addLine(55, [0xB9, S(' 50179,222')].flat())
  addLine(56, [0xAD, 0xE2, S('(50179)'), 0xD0, S('222'), 0xC4, 0xAB, S(' 58')].flat())
  addLine(57, [0xAB, S(' 60')].flat())
  addLine(58, [0xB9, S(' 50179,111')].flat())
  addLine(59, [0xAD, 0xE2, S('(50179)'), 0xD0, S('111'), 0xC4, S('S'), 0xD0, S('4')].flat())

  // Status display
  addLine(60, [0xAD, S('S'), 0xD0, S('0'), 0xC4, 0xBA, S(' "STATUS: NO VERA CARD DETECTED!"')].flat())
  addLine(62, [0xAD, S('S'), 0xD0, S('2'), 0xC4, 0xBA, S(' "STATUS: VERA CARD ON SLOT 2"')].flat())
  addLine(64, [0xAD, S('S'), 0xD0, S('4'), 0xC4, 0xBA, S(' "STATUS: VERA CARD ON SLOT 4"')].flat())
  addLine(66, [0xAD, S('S'), 0xD0, S('0'), 0xC4, 0xAB, S(' 69')].flat())
  addLine(68, [0xBA, S(' "OPEN \'VERA MONITOR\' TAB ON RIGHT!"')].flat())
  addLine(69, [0xBA].flat())

  // Menu items (0 to 4)
  addLine(70, [0xBA, S(' "0. ABOUT & README"')].flat())
  addLine(72, [0xBA, S(' "1. SPRITE DEMO (SILENT)"')].flat())
  addLine(74, [0xBA, S(' "2. SPRITE DEMO (WITH SOUND)"')].flat())
  addLine(76, [0xBA, S(' "3. REAL RAINBOW ARC"')].flat())
  addLine(78, [0xBA, S(' "4. EXIT TO BASIC"')].flat())
  addLine(79, [0xBA].flat())

  // Input and dispatch
  addLine(80, [0x84, S(' "SELECT (0-4): ";A$')].flat())
  addLine(81, [0xAD, S(' A$'), 0xD0, S('"0"'), 0xC4, 0xAB, S(' 300')].flat())
  addLine(82, [0xAD, S('S'), 0xD0, S('0'), 0xCD, S('A$'), 0xD0, S('"1"'), 0xC4, 0xBA, S(' "NO VERA CARD DETECTED!"')].flat())
  addLine(83, [0xAD, S('S'), 0xD0, S('0'), 0xCD, S('A$'), 0xD0, S('"2"'), 0xC4, 0xBA, S(' "NO VERA CARD DETECTED!"')].flat())
  addLine(84, [0xAD, S('S'), 0xD0, S('0'), 0xCD, S('A$'), 0xD0, S('"3"'), 0xC4, 0xBA, S(' "NO VERA CARD DETECTED!"')].flat())
  addLine(85, [0xAD, S('S'), 0xD0, S('0'), 0xCD, S('A$'), 0xD0, S('"1"'), 0xC4, 0xAB, S(' 79')].flat())
  addLine(86, [0xAD, S('S'), 0xD0, S('0'), 0xCD, S('A$'), 0xD0, S('"2"'), 0xC4, 0xAB, S(' 79')].flat())
  addLine(87, [0xAD, S('S'), 0xD0, S('0'), 0xCD, S('A$'), 0xD0, S('"3"'), 0xC4, 0xAB, S(' 79')].flat())
  addLine(88, [0xAD, S(' A$'), 0xD0, S('"1"'), 0xC4, 0xBA, S(' "THIS MAY TAKE 3 - 15 SECONDS."')].flat())
  addLine(89, [0xAD, S(' A$'), 0xD0, S('"1"'), 0xC4, 0xBA, S(' "PRESS ANY KEY TO STOP."')].flat())
  addLine(90, [0xAD, S(' A$'), 0xD0, S('"2"'), 0xC4, 0xBA, S(' "THIS MAY TAKE 3 - 15 SECONDS."')].flat())
  addLine(91, [0xAD, S(' A$'), 0xD0, S('"2"'), 0xC4, 0xBA, S(' "PRESS ANY KEY TO STOP."')].flat())
  addLine(92, [0xAD, S(' A$'), 0xD0, S('"3"'), 0xC4, 0xBA, S(' "THIS MAY TAKE 3 - 15 SECONDS."')].flat())
  addLine(120, [0xAD, S(' A$'), 0xD0, S('"1"'), 0xCD, S('S'), 0xD0, S('2'), 0xC4, 0xBA, 0xE7, S('(4);"BRUN SPRITE.BIN"')].flat())
  addLine(125, [0xAD, S(' A$'), 0xD0, S('"1"'), 0xCD, S('S'), 0xD0, S('4'), 0xC4, 0xBA, 0xE7, S('(4);"BRUN SPRITE4.BIN"')].flat())
  addLine(130, [0xAD, S(' A$'), 0xD0, S('"2"'), 0xCD, S('S'), 0xD0, S('2'), 0xC4, 0xBA, 0xE7, S('(4);"BRUN SPRSND.BIN"')].flat())
  addLine(135, [0xAD, S(' A$'), 0xD0, S('"2"'), 0xCD, S('S'), 0xD0, S('4'), 0xC4, 0xBA, 0xE7, S('(4);"BRUN SPRSND4.BIN"')].flat())
  addLine(140, [0xAD, S(' A$'), 0xD0, S('"3"'), 0xCD, S('S'), 0xD0, S('2'), 0xC4, 0xBA, 0xE7, S('(4);"BRUN MODE7.BIN"')].flat())
  addLine(145, [0xAD, S(' A$'), 0xD0, S('"3"'), 0xCD, S('S'), 0xD0, S('4'), 0xC4, 0xBA, 0xE7, S('(4);"BRUN MODE74.BIN"')].flat())
  addLine(160, [0xAD, S(' A$'), 0xD0, S('"4"'), 0xC4, 0x80].flat())
  addLine(170, [0xAB, S(' 79')].flat())

  // README Screen at Line 300
  addLine(300, [0x89].flat()) // 300 TEXT
  addLine(305, [0x97].flat()) // 305 HOME
  addLine(310, [0xBA, S(' "ABOUT VERA FOR APPLE2TS"')].flat())
  addLine(315, [0xBA, S(' "======================="')].flat())
  addLine(318, [0xBA].flat())
  addLine(320, [0xBA, S(' "VERA (VERSATILE EMBEDDED RETRO ADAPTER)"')].flat())
  addLine(325, [0xBA, S(' "IS THE FPGA VIDEO CARD SYSTEM FROM THE"')].flat())
  addLine(330, [0xBA, S(' "COMMANDER X16 PROJECT (THE 8-BIT GUY)."')].flat())
  addLine(335, [0xBA].flat())
  addLine(340, [0xBA, S(' "APPLE2TS NOW BRINGS FULL VERA EMULATION"')].flat())
  addLine(345, [0xBA, S(' "TO APPLE II MACHINES (SLOT 2 & SLOT 4)!"')].flat())
  addLine(350, [0xBA].flat())
  addLine(355, [0xBA, S(' "FEATURES IN THIS DEMO DISK:"')].flat())
  addLine(358, [0xBA].flat())
  addLine(360, [0xBA, S(' " - AUTO HARDWARE PROBING (SLOT 2 / 4)"')].flat())
  addLine(365, [0xBA, S(' " - 16 BOUNCING HARDWARE SPRITES (6502)"')].flat())
  addLine(368, [0xBA, S(' " - 3-VOICE STEREO PSG CHIPTUNE MUSIC"')].flat())
  addLine(370, [0xBA, S(' " - 256-COLOR 8BPP BITMAP RAINBOW ARC"')].flat())
  addLine(375, [0xBA, S(' " - FAST 6502 RLE DECOMPRESSION ENGINE"')].flat())
  addLine(380, [0xBA].flat())
  addLine(385, [0xBA, S(' "PRESS ANY KEY TO RETURN TO MENU..."')].flat())
  addLine(390, [0xB9, S(' 49168,0')].flat()) // POKE 49168,0 (clear strobe)
  addLine(392, [0xB5, S(' 49152,128')].flat()) // WAIT 49152,128 (wait key)
  addLine(394, [0xB9, S(' 49168,0')].flat()) // POKE 49168,0
  addLine(396, [0xAB, S(' 10')].flat()) // GOTO 10

  mem.push(0x00, 0x00)
  return new Uint8Array(mem)
}

// Build ProDOS Disk Image
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

  // Assemble and write real binaries
  const sprite2 = assemble6502(getSpriteDemoAsm(2, 0x2000), 0x2000)
  const sprite4 = assemble6502(getSpriteDemoAsm(4, 0x2000), 0x2000)
  const spritesnd2 = assemble6502(getSpriteSoundDemoAsm(2, 0x2000), 0x2000)
  const spritesnd4 = assemble6502(getSpriteSoundDemoAsm(4, 0x2000), 0x2000)
  const mode72 = buildMode7Binary(2)
  const mode74 = buildMode7Binary(4)
  const startup = buildStartupBasic()

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
  console.log(`  - STARTUP      Size=${startup.length} bytes`)

  // Auto-sync to Apple2TS if repo is present
  const apple2tsPublicDisks = path.resolve(rootDir, "../apple2ts/public/disks")
  if (fs.existsSync(apple2tsPublicDisks)) {
    fs.writeFileSync(path.join(apple2tsPublicDisks, "veratest.po"), disk)
    console.log(`  -> Synced to ${path.join(apple2tsPublicDisks, "veratest.po")}`)
  }

  // Generate veratest.png preview screenshot
  generatePreviewPng()
}

// Generate high quality 560x384 PNG screenshot for Disk Collection preview
const generatePreviewPng = () => {
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

  // Auto-sync to Apple2TS if repo is present
  const apple2tsPublicDisks = path.resolve(rootDir, "../apple2ts/public/disks")
  if (fs.existsSync(apple2tsPublicDisks)) {
    fs.writeFileSync(path.join(apple2tsPublicDisks, "veratest.png"), pngBuf)
    console.log(`  -> Synced to ${path.join(apple2tsPublicDisks, "veratest.png")}`)
  }
}

buildProDosDisk()

import fs from "fs"
import path from "path"

const hex = (val) => val.toString(16).toUpperCase()

// Complete 6502 assembler with guaranteed byte-length consistency and standard ASM syntax support
export const assemble6502 = (lines, startAddress = 0x2000, extraLabels = {}) => {
  let labels = { ...extraLabels }

  const getEncodedBytes = (instr, operand, currentPc, currentLabels) => {
    const resolveVal = (op) => {
      let s = op.replace("#", "").replace("<", "").replace(">", "")
      let highByte = op.includes(">")
      let lowByte = op.includes("<")
      let add = 0
      if (s.includes("+")) {
        const p = s.split("+")
        s = p[0].trim()
        add = parseInt(p[1].trim().replace("$", "0x"))
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

    if (instr === "!WORD" || instr === ".WORD" || instr === "DW" || instr === "DA") {
      const val = resolveVal(operand)
      return [val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "HEX") {
      const hList = operand.split(/[\s,]+/).filter(Boolean)
      return hList.map(h => {
        if (h.startsWith("$")) return parseInt(h.substring(1), 16)
        if (h.startsWith("0x") || h.startsWith("0X")) return parseInt(h, 16)
        return parseInt(h, 16)
      })
    }

    if (instr === "!BYTE" || instr === ".BYTE") {
      const hList = operand.split(/[\s,]+/).filter(Boolean)
      return hList.map(h => {
        if (h.startsWith("<") || h.startsWith(">") || h.startsWith("#") || (h in currentLabels)) {
          return resolveVal(h) & 0xFF
        }
        if (h.startsWith("$")) return parseInt(h.substring(1), 16)
        if (h.startsWith("0x") || h.startsWith("0X")) return parseInt(h, 16)
        return parseInt(h, 10)
      })
    }

    // Inherent / Implied 1-byte opcodes
    if (instr === "RTS") return [0x60]
    if (instr === "RTI") return [0x40]
    if (instr === "NOP") return [0xEA]
    if (instr === "PHA") return [0x48]
    if (instr === "PLA") return [0x68]
    if (instr === "PHP") return [0x08]
    if (instr === "PLP") return [0x28]
    if (instr === "TSX") return [0xBA]
    if (instr === "TXS") return [0x9A]
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
    if (instr === "CLI") return [0x58]
    if (instr === "SEI") return [0x78]
    if (instr === "CLD") return [0xD8]
    if (instr === "SED") return [0xF8]
    if (instr === "CLV") return [0xB8]

    if (instr === "ASL") {
      if (!operand || operand === "A") return [0x0A]
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0x06, val & 0xFF]
      return [0x0E, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "LSR") {
      if (!operand || operand === "A") return [0x4A]
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0x46, val & 0xFF]
      return [0x4E, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "ROL") {
      if (!operand || operand === "A") return [0x2A]
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0x26, val & 0xFF]
      return [0x2E, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "ROR") {
      if (!operand || operand === "A") return [0x6A]
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0x66, val & 0xFF]
      return [0x6E, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "JSR") {
      const val = resolveVal(operand)
      return [0x20, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "JMP") {
      const val = resolveVal(operand)
      return [0x4C, val & 0xFF, (val >> 8) & 0xFF]
    }

    if (instr === "BIT") {
      const val = resolveVal(operand)
      if (operand.startsWith("$") && operand.length <= 3) return [0x24, val & 0xFF]
      return [0x2C, val & 0xFF, (val >> 8) & 0xFF]
    }

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

    if (["BNE", "BEQ", "BPL", "BMI", "BCC", "BCS", "BVC", "BVS"].includes(instr)) {
      const opcodes = { BNE: 0xD0, BEQ: 0xF0, BPL: 0x10, BMI: 0x30, BCC: 0x90, BCS: 0xB0, BVC: 0x50, BVS: 0x70 }
      const target = resolveVal(operand)
      const offset = target - (currentPc + 2)
      if (currentLabels && (operand in currentLabels)) {
        if (offset < -128 || offset > 127) {
          throw new Error(`Branch target out of range for ${instr} ${operand}: offset ${offset} at PC $${currentPc.toString(16)}`)
        }
      }
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

    throw new Error(`Unknown instruction: ${instr} with operand '${operand}'`)
  }

  // Pass 1: find labels and constants
  let pc = startAddress
  for (let rawLine of lines) {
    let line = rawLine.split("//")[0].split(";")[0].trim()
    if (!line) continue
    if (line.startsWith("ORG") || line.startsWith("* =") || line.startsWith("*=")) continue

    // Handle equate definitions (LABEL EQU $xxxx, LABEL = $xxxx, LABEL = VERA_BASE + $xx)
    if (line.includes(" EQU ") || line.includes(" = ") || /^\w+\s*=/.test(line)) {
      const parts = line.split(/\s*(=|EQU)\s*/)
      const labelName = parts[0].trim().replace(":", "")
      let expr = parts[2].trim()
      let add = 0
      if (expr.includes("+")) {
        const p = expr.split("+")
        expr = p[0].trim()
        add = parseInt(p[1].trim().replace("$", "0x"))
      }
      let val = 0
      if (expr in labels) {
        val = labels[expr] + add
      } else if (expr.startsWith("$")) {
        val = parseInt(expr.substring(1), 16) + add
      } else {
        val = parseInt(expr, 10) + add
      }
      labels[labelName] = val
      continue
    }

    if (line.endsWith(":")) {
      labels[line.slice(0, -1).trim()] = pc
      continue
    }

    const parts = line.split(/\s+/)
    const instr = parts[0].toUpperCase()
    const isDataDir = (instr === "HEX" || instr === "!BYTE" || instr === ".BYTE" || instr === "!WORD" || instr === ".WORD" || instr === "DW" || instr === "DA")
    const operand = isDataDir ? parts.slice(1).join(" ") : parts.slice(1).join("")
    const b = getEncodedBytes(instr, operand, pc, labels)
    pc += b.length
  }

  // Pass 2: generate real bytes using resolved labels
  pc = startAddress
  let bytes = []
  for (let rawLine of lines) {
    let line = rawLine.split("//")[0].split(";")[0].trim()
    if (!line) continue
    if (line.startsWith("ORG") || line.startsWith("* =") || line.startsWith("*=")) continue
    if (line.includes(" EQU ") || line.includes(" = ") || /^\w+\s*=/.test(line)) continue
    if (line.endsWith(":")) continue

    const parts = line.split(/\s+/)
    const instr = parts[0].toUpperCase()
    const isDataDir = (instr === "HEX" || instr === "!BYTE" || instr === ".BYTE" || instr === "!WORD" || instr === ".WORD" || instr === "DW" || instr === "DA")
    const operand = isDataDir ? parts.slice(1).join(" ") : parts.slice(1).join("")
    const b = getEncodedBytes(instr, operand, pc, labels)
    bytes.push(...b)
    pc += b.length
  }

  return new Uint8Array(bytes)
}

// Load and assemble an assembly source file with a given VERA slot base
export const assembleAsmFile = (srcDir, filename, slot = 2, startAddress = 0x2000, extraLines = []) => {
  const filePath = path.isAbsolute(filename) ? filename : path.join(srcDir, filename)
  const fileDir = path.dirname(filePath)
  const content = fs.readFileSync(filePath, "utf-8")
  const fileLines = content.split(/\r?\n/)

  let veraIncPath = path.join(fileDir, "vera.inc")
  if (!fs.existsSync(veraIncPath)) {
    veraIncPath = path.join(fileDir, "..", "vera.inc")
  }
  if (!fs.existsSync(veraIncPath)) {
    veraIncPath = path.join(srcDir, "vera.inc")
  }

  const veraIncLines = fs.existsSync(veraIncPath)
    ? fs.readFileSync(veraIncPath, "utf-8").split(/\r?\n/)
    : []

  const baseAddress = 0xC000 + slot * 0x100
  const combinedLines = [
    `VERA_BASE = $${hex(baseAddress)}`,
    ...veraIncLines,
    ...fileLines,
    ...extraLines
  ]

  return assemble6502(combinedLines, startAddress)
}

#!/usr/bin/env node
// Music stream verifier: regenerates the packaged .vzm streams from their source
// .ZSM files and proves two things.
//
//   1. The build is reproducible: the bytes produced now are exactly the bytes
//      checked into src/slideshow/data/*.vzm (same balance curve, same order).
//   2. The conversion is register-equivalent to the original ZSM: for every
//      60 Hz tick the PSG and YM2151 register image implied by the raw ZSM equals
//      the image implied by the converted stream, and the `$08` key-on/key-off
//      write sequence is identical in order and value.
//
// Point 2 is what guarantees the FM daughterboard hears the arrangement the
// tracker wrote. Two bugs that slipped past earlier inspection are covered here:
// a YM2151 batch decoded one pair short, and a rewritten `$08` key register that
// turned every key-off into a key-on so each channel decayed once and never
// retriggered (heard as "the music stops after a moment").
//
// Usage: node src/verify_music_streams.mjs
import fs from "node:fs"
import path from "node:path"
import { convertZsmToVeraStream, MUSIC_BALANCE } from "./zsm2vera.mjs"
import { MUSIC_TRACKS, SLIDESHOW_DATA_DIR } from "./music_streams.mjs"

const PSG = 0
const FM = 1

// Per 60 Hz tick, every write the song issues, in stream order.
const zsmTicks = (buffer) => {
  const ticks = []
  let current = []
  let ptr = 16
  while (ptr < buffer.length) {
    const command = buffer[ptr++]
    if (command < 0x40) {
      current.push([PSG, command, buffer[ptr++]])
      continue
    }
    if (command === 0x40) {
      const ext = buffer[ptr++]
      ptr += ext & 0x3f
      continue
    }
    if (command < 0x80) {
      const count = command & 0x3f
      for (let i = 0; i < count; i++) current.push([FM, buffer[ptr++], buffer[ptr++]])
      continue
    }
    if (command === 0x80) {
      ticks.push(current)
      break
    }
    // Delay: the writes above happen on this tick, then (command & $7F) - 1 silent ticks.
    ticks.push(current)
    current = []
    for (let i = 1; i < (command & 0x7f); i++) ticks.push([])
  }
  return ticks
}

const vzmTicks = (buffer) => {
  const ticks = []
  let current = []
  let ptr = 0
  while (ptr < buffer.length) {
    const command = buffer[ptr++]
    if (command === 0xff) {
      ticks.push(current)
      break
    }
    if (command <= 0x7f) {
      // Delay byte N: this tick plus N silent ticks.
      ticks.push(current)
      current = []
      for (let i = 0; i < command; i++) ticks.push([])
      continue
    }
    if (command <= 0xbf) {
      current.push([PSG, command & 0x3f, buffer[ptr++]])
      continue
    }
    if (command <= 0xdf) {
      const count = (command & 0x1f) + 1
      for (let i = 0; i < count; i++) current.push([FM, buffer[ptr++], buffer[ptr++]])
      continue
    }
    // $E0..$FE: alignment padding between 512-byte blocks.
  }
  return ticks
}

const sameImage = (left, right) => {
  for (let i = 0; i < left.length; i++) if (left[i] !== right[i]) return false
  return true
}

const verifyTrack = (track) => {
  const sourcePath = path.join(SLIDESHOW_DATA_DIR, track.source)
  const outputPath = path.join(SLIDESHOW_DATA_DIR, track.output)
  const zsm = fs.readFileSync(sourcePath)
  const packaged = fs.readFileSync(outputPath)
  const { data, stats } = convertZsmToVeraStream(zsm, {
    balance: MUSIC_BALANCE[track.name],
    sourceName: track.source,
  })
  if (Buffer.compare(data, packaged) !== 0) {
    throw new Error(
      `${track.output}: regenerated stream differs from the packaged file ` +
        `(${data.length} vs ${packaged.length} bytes) - rerun the build`,
    )
  }

  const reference = zsmTicks(zsm)
  const actual = vzmTicks(packaged)
  if (reference.length !== actual.length) {
    throw new Error(`${track.name}: ${reference.length} ticks in the ZSM but ${actual.length} in the VZM`)
  }

  const psgRef = new Uint8Array(64)
  const psgAct = new Uint8Array(64)
  const fmRef = new Uint8Array(256)
  const fmAct = new Uint8Array(256)
  let mismatched = 0
  let firstMismatch = -1
  let keyWrites = 0
  // CANYON is deliberately rebalanced at build time, so the reference PSG image
  // is passed through the same curve before it is compared.
  const balance = MUSIC_BALANCE[track.name] || null
  for (let tick = 0; tick < reference.length; tick++) {
    const keyRef = []
    const keyAct = []
    for (const [kind, reg, value] of reference[tick]) {
      if (kind === PSG) psgRef[reg] = balance ? balance(reg, value) : value
      else {
        fmRef[reg] = value
        if (reg === 0x08) keyRef.push(value)
      }
    }
    for (const [kind, reg, value] of actual[tick]) {
      if (kind === PSG) psgAct[reg] = value
      else {
        fmAct[reg] = value
        if (reg === 0x08) keyAct.push(value)
      }
    }
    keyWrites += keyRef.length
    const same =
      sameImage(psgRef, psgAct) &&
      sameImage(fmRef, fmAct) &&
      keyRef.length === keyAct.length &&
      keyRef.every((value, index) => value === keyAct[index])
    if (!same) {
      mismatched++
      if (firstMismatch < 0) firstMismatch = tick
    }
  }

  return { ...track, bytes: packaged.length, ticks: reference.length, keyWrites, mismatched, firstMismatch, stats }
}

let failed = false
for (const track of MUSIC_TRACKS) {
  const result = verifyTrack(track)
  if (result.mismatched !== 0) failed = true
  const status = result.mismatched === 0 ? "OK  " : "FAIL"
  console.log(
    `${status} ${result.name.padEnd(9)} ${result.ticks} ticks, ${result.bytes / 512} blocks ` +
      `(${result.bytes} B), ${result.stats.psgWrites} PSG / ${result.stats.fmWrites} FM writes, ` +
      `${result.keyWrites} key writes, ${result.mismatched} mismatched ticks` +
      (result.firstMismatch >= 0 ? ` (first at tick ${result.firstMismatch})` : ""),
  )
}

if (failed) {
  console.error("Music stream verification FAILED")
  process.exit(1)
}
console.log("All streams match their source ZSM and the packaged build")
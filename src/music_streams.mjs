// =============================================================================
// Shared build step: X16 ZSM -> VERA "VZM" streams
// =============================================================================
//
// The slideshow and the Sonic demo both play the same three X16 soundtracks.
// Each ZSM file is converted once into a compact PSG + YM2151 event stream and
// stored next to the slideshow assets; both builders call this module so the
// packaged streams can never drift apart.
// =============================================================================

import fs from "fs"
import path from "path"
import { fileURLToPath } from "url"
import { convertZsmToVeraStream, MUSIC_BALANCE } from "./zsm2vera.mjs"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
export const SLIDESHOW_DATA_DIR = path.resolve(__dirname, "slideshow", "data")

export const MUSIC_TRACKS = [
  { name: "SB-INTRO", source: "SB-INTRO.ZSM", output: "sb-intro.vzm" },
  { name: "CANYON", source: "CANYON.ZSM", output: "canyon.vzm" },
  { name: "GREENHILL", source: "GREENHILL.ZSM", output: "greenhill.vzm" },
]

/**
 * Convert every soundtrack into SLIDESHOW_DATA_DIR and return them keyed by
 * track name.  `music.tracks[i].data` is the block-padded VZM byte stream.
 */
export const buildMusicStreams = () => {
  const tracks = MUSIC_TRACKS.map(track => {
    const sourcePath = path.join(SLIDESHOW_DATA_DIR, track.source)
    const outputPath = path.join(SLIDESHOW_DATA_DIR, track.output)
    if (!fs.existsSync(sourcePath)) {
      throw new Error(`X16 soundtrack not found: ${sourcePath}`)
    }
    const { data, stats } = convertZsmToVeraStream(fs.readFileSync(sourcePath), {
      balance: MUSIC_BALANCE[track.name],
      sourceName: track.source,
    })
    fs.writeFileSync(outputPath, data)
    const { psgKept, fmKept, ticks } = stats
    console.log(
      `  🎵 ${track.source} -> ${track.output} ` +
      `(${data.length} bytes, ${data.length / 512} blocks; PSG ${psgKept}, FM ${fmKept} writes, ${ticks} ticks)`
    )
    return { ...track, path: outputPath, data, stats }
  })
  return tracks
}

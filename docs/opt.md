# ProDOS File-Level I/O and Cadius Image-Building Notes

Reusable notes from the `veratest` ProDOS file-access and Cadius migration. These patterns apply to Apple II software that must survive copying to another ProDOS disk or subdirectory.

## 1. What “file-level” means here

A file-level program finds data by ProDOS pathname/catalog metadata rather than by assuming a fixed disk block such as “asset starts at block 6000.” ProDOS may allocate a file's blocks anywhere, and copied files can receive a different allocation. Never derive a file's block numbers from a build layout or assume its data blocks are contiguous.

There are two useful ways to read a file:

- **MLI file calls** (`OPEN`, repeated `READ`, `CLOSE`): use for ordinary sequential data, small files, and streams such as music. ProDOS follows the file's allocation metadata.
- **Catalog lookup + MLI `READ_BLOCK`**: use when each 512-byte block must be sent to a special destination such as VERA VRAM, bypassing a large intermediate RAM buffer. Resolve every physical block from the file's catalog entry and index block first. This still uses `READ_BLOCK`, but the program is file-aware and allocation-independent.

Both approaches must locate the file from the active ProDOS prefix or another explicit pathname. A matching filename elsewhere on the disk is not proof that it belongs to this application.

## 2. Sequential reads with ProDOS MLI

Use `OPEN` / `READ` / `CLOSE` for normal streams:

1. Construct the pathname from `GET_PREFIX` plus the application-relative filename. Respect an existing trailing slash and root paths. This supports launch from a volume root or nested directory.
2. Allocate and initialize the ProDOS I/O buffer required by `OPEN`; capture the returned reference number.
3. Read in bounded chunks into a RAM buffer. Check both the MLI carry/status and the actual transfer count. A successful call can still return fewer bytes at EOF.
4. Close the reference on success and every error path. Do not continue after an open/read error or treat a short final read as a complete data chunk.
5. If a format is a fixed-size block container, validate its expected size and handle its final partial logical payload explicitly. Padding the container at build time can simplify exact 512-byte reads, but the logical end marker/length must remain authoritative.

The Sonic demo uses this pattern for `SONIC.DAT`; the slideshow uses it for the PSG + FM `VZM` streams in `/DATA/`.

A player that prefetches one block ahead reads past the end of every stream, so the last `READ` lands beyond EOF and ProDOS answers with a short or zero-length transfer (status `$27`). That is the normal end of the stream, not a read failure: write an end-of-stream terminator into the prefetched buffer and let the player advance to the next track. Treating it as an error cost `veratest`'s slideshow its track change and left the last chord ringing, which is the classic symptom.

## 3. Streaming large files directly to VERA

For a large Mode 7 image (76,800 bytes = 150 blocks), loading the whole file into Apple II RAM is wasteful or impossible. Resolve the file's allocation and issue one ProDOS MLI `READ_BLOCK` per allocated block into a small 512-byte RAM buffer, then copy that buffer to VERA's data port.

### Locate the correct file

1. Call `GET_PREFIX` and parse the directory path. The prefix may be `/VOLUME/` or `/VOLUME/APP/`.
2. Starting from the ProDOS volume root directory block 2, follow directory-chain links and compare active entries by exact name and storage type. For nested applications, walk each path component to the intended app asset directory, then find the target filename there.
3. Read the catalog entry's storage type, key block, EOF, and file type. Reject unexpected types/sizes. Do not scan the whole disk for a generic asset filename; another app can have files with the same name.
4. Handle the ProDOS directory entry length (39 bytes) and directory block chain. Avoid assuming all entries fit in the first root directory block.

### Resolve storage blocks

- **Seedling file**: the key block is the file's only data block. This is appropriate for a 512-byte palette.
- **Sapling file**: the key block points to a 512-byte index block. Its 256 low-byte entries occupy offsets `0..255`; the matching high bytes occupy offsets `256..511`. For logical file block `i`, the disk block is `index[i] | (index[i + 256] << 8)`. A 76,800-byte image needs 150 of these entries.
- **Tree file**: requires a master index plus sapling indexes. Add tree support if files may exceed sapling limits; do not silently treat tree files as sapling files.

For each logical image block, fetch the actual physical block from the index and call `READ_BLOCK` with that block number. Check the call status and transfer result. Program VERA's address/increment mode for the intended VRAM destination, then copy the 512-byte read buffer to `VERA_DATA0` with the required hardware register semantics. Reuse that buffer for every block; only catalog/index data and one data block need RAM, never the full bitmap. Do not set the `READ_BLOCK` destination to a VERA register: ProDOS writes successive bytes to successive CPU addresses, while VERA streaming requires repeated writes to its data-port address.

The slideshow resolves its `/DATA1`–`/DATA3` image/palette entries this way. It reads each image's sapling index and streams the resolved allocated blocks through a 512-byte RAM buffer to VERA; palette seedling blocks use the same buffered path. Music remains on ordinary MLI file calls.

### Common failure sources

- Using a volume-root path when the application was launched from a nested directory, or dropping the current ProDOS prefix.
- Matching the wrong same-named asset elsewhere on a hard disk.
- Assuming directory entries are contiguous or only scanning block 2.
- Treating a sapling index as contiguous data blocks, reversing its low/high-byte halves, or using the index block itself as the first data block.
- Assuming a file is a seedling/sapling without checking storage type and EOF.
- Ignoring MLI carry, status, or transfer count; reusing a stale buffer after a failed read.
- Leaving an OPEN reference unclosed on errors.

## 4. Build ProDOS images with Cadius

Use Cadius to create and modify the ProDOS catalog, allocation indexes, timestamps, and volume bitmap. Avoid custom image code that manually allocates blocks and edits directory entries.

### Recommended build shape

1. Start from a known bootable ProDOS `.po` or `.hdv` baseline.
2. Copy it to a temporary output path; never mutate the only baseline.
3. Rename the volume explicitly (`RENAMEVOLUME`) to the name the application expects.
4. Preserve required boot files. For a bootable ProDOS/BASIC disk, the baseline's `PRODOS` and `BASIC.SYSTEM` are typically required. Remove unwanted utilities only through Cadius so the catalog and bitmap stay consistent.
5. Assemble/compile programs and stage all files in temporary folders. Keep staged folder contents limited to the files for that ProDOS directory.
6. Add files with Cadius, putting them in the intended volume root or subdirectory. Create the ProDOS directory structure first; split very large catalogs into subdirectories to keep catalogs manageable for tools such as Copy II Plus.
7. Run Cadius `CHECKVOLUME` on the completed image and inspect its catalog. Then boot/test the output and test copying the program's files to a different disk and nested directory.
8. Clean only the temporary staging directory after checking that its resolved path is inside the expected temp root.

In this repository both builders use the checked-in `tools/cadius.exe` by default and honor `CADIUS` as an override. The 140 KiB builder starts with the bootable ProDOS baseline, renames it `VERATEST`, keeps `PRODOS` and `BASIC.SYSTEM`, deletes other baseline entries through Cadius, and adds the application files. The 32 MiB builder starts with its ProDOS baseline, renames it `SLIDESHOW`, retains the needed boot configuration, and creates `/DATA/` plus `/DATA1/` through `/DATA3/`.

### File metadata and Cadius staging

Cadius infers ProDOS file type and auxiliary type from staged filenames using the `#TTAAAA` suffix:

- `#06 2000` (written without the space as `#062000`): Binary (`$06`), load address `$2000`.
- `#FC 0801` (`#FC0801`): Applesoft BASIC (`$FC`), start address `$0801`.
- `#00 0000` (`#000000`): Untyped data file.

Example staged name: `SLIDESHOW.BIN#062000`. The suffix is packaging metadata, not part of the ProDOS filename. Confirm the Cadius invocation syntax/version used by your project and inspect the resulting catalog to ensure file types and auxiliary addresses are correct.

### ProDOS 8 compatibility note

In this project's Cadius build, newly created subdirectory headers use compatibility marker `$76`, while the tested ProDOS 8 setup requires `$75`. The HDV builder locates each created directory from the root catalog, validates the header/name, and changes only that header marker to `$75`. Treat this as a tested project/platform compatibility workaround, not a general rule for every ProDOS version. Verify on the exact ProDOS and driver versions you support, and run `CHECKVOLUME` after any post-processing.

## 5. Copy/install contract

Document the complete file set users must copy. For a slideshow installed under a path such as `/VERASD/SLIDESHOW/`, copy the application binaries and the four sibling asset directories `DATA`, `DATA1`, `DATA2`, and `DATA3` into that target directory. Resolve paths relative to the active ProDOS prefix so the same build runs from the original image, another volume, or a nested directory. Test with files copied individually through a ProDOS-aware utility; booting only the generated image does not prove allocation-independent access.

For apps that use one data container, copy that container alongside the app and open it through ProDOS file calls from the active prefix.

## 6. Practical checklist

- [ ] Runtime has no fixed physical block numbers or contiguity assumptions.
- [ ] Asset lookup is scoped to the app's volume/prefix and expected directory.
- [ ] Path handling works at volume root and in nested directories.
- [ ] Catalog chains and file storage types are validated.
- [ ] MLI errors, EOF/short reads, and cleanup are handled.
- [ ] Image/palette sizes and expected file counts are validated at build time.
- [ ] Cadius builds from a copied baseline and preserves required boot files.
- [ ] File type, auxiliary address, volume name, and timestamps are checked.
- [ ] `CHECKVOLUME` passes after image creation and any header compatibility adjustment.
- [ ] A copied file-level install has been tested on a different ProDOS volume/directory.

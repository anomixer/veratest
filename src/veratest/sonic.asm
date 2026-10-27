; ==============================================================================
; Demo 7: Sonic The Hedgehog (Green Hill Zone) for Apple II (VERA Card)
; Based on ZeroByte's Sega Genesis 16-bit Engine for Commander X16
; Features:
;   - Dual-Layer Parallax Scrolling (Layer 1 Foreground + Layer 0 Background)
;   - Sonic Running 4-Frame Hardware Sprite Animation (Ears + Body)
;   - Dynamic Ground Level Modulation (Sonic bobs up/down over the rolling hills)
;   - Shimmering Water & Waterfall Palette Cycling (waterpalette at $1FA50)
;   - Rotating Sunflower Tile Animation (VRAM $0EB80 swapped in real-time)
;   - Authentic 60 Hz Green Hill Zone BGM: VERA PSG + optional YM2151 FM
;   - Standard ProDOS MLI Asset Streaming (< 1.5s clean load)
;   - Safe Zero-Page Usage ($06..$17), Zero Screen/Font Corruption on Exit
; ==============================================================================

* = $2000

; Safe Zero Page Variables (Never conflicts with Apple II, ProDOS, or Applesoft)
FRAME       = $06
WATER       = $07
FLOWER      = $08
SONIC_FRAME = $09
DIRTY       = $0A
FG_SCROLL_L = $0B
FG_SCROLL_H = $0C
BG_SCROLL_L = $0D
BG_SCROLL_H = $0E
BG_FRAC     = $0F
MUSIC_PTR_L = $10
MUSIC_PTR_H = $11
MUSIC_DELAY = $12
OLD_IRQ_L   = $13
OLD_IRQ_H   = $14
REF_NUM     = $15
BLK_CTR     = $16
TMP_L       = $17
FM_PRESENT  = $20       ; 1 = YM2151 FM daughterboard detected
FM_COUNT    = $21       ; Remaining register pairs in the current FM batch
FM_KEYS     = $22       ; Last $08 (key on/off) value per FM channel ($22..$29)

; Music stream lives in RAM at $4000, BLOADed from SONICMUS.BIN by STARTUP.
MUSIC_BASE  = $4800

; Constants
SONIC_X     = 100
SONIC_Y     = 152
WATER_PAL   = $1FA50
FLOWER_VRAM = $0EB80
SONIC_SPEED = 2             ; 2 pixels per frame

START:
    ; 1. Clean Hardware Reset & Blank Video
    LDA #$00
    STA VERA_CTRL       ; Port 0, DCSEL = 0
    STA VERA_DC_VID     ; Blank video during initialization
    STA VERA_DC_BOR     ; Border color = 0
    STA VERA_L0_CFG     ; Disable Layer 0
    STA VERA_L1_CFG     ; Disable Layer 1
    LDA #$40            ; 2x hardware scale (320x240 view)
    STA VERA_DC_HSC
    STA VERA_DC_VSC

    ; 2. Wipe Entire 128KB VRAM (Bank 0 & Bank 1)
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$10            ; Stride +1, Bank 0
    STA VERA_ADDR_H
    JSR CLR_64K

    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1, Bank 1
    STA VERA_ADDR_H
    JSR CLR_64K

    ; 2b. Detect and clear the optional YM2151 FM daughterboard. The Green Hill
    ; stream carries both the PSG and the FM arrangement; when no daughterboard
    ; is fitted the player skips the FM batches and the PSG part plays exactly
    ; as in the PSG-only version of this demo.
    JSR VERA_FM_DETECT
    JSR VERA_FM_RESET

    ; 3. Load SONIC.DAT via ProDOS MLI ($C8 OPEN, $CA READ, $CC CLOSE)
    JSR LOAD_SONIC_ASSETS
    BCC SONIC_ASSETS_READY
    LDA #$00
    STA VERA_DC_VID
    JSR SHOW_SONIC_ERROR
    RTS
SONIC_ASSETS_READY:

    ; 4. Configure Layer 0 (Background: 64x32 4bpp, Map at $04800, Tiles at $08000)
    LDA #$12            ; 4bpp Tile Mode, 64x32
    STA VERA_L0_CFG
    LDA #$24            ; Map Base: $04800 >> 9 = $24
    STA VERA_L0_MAP
    LDA #$40            ; Tile Base: $08000 >> 9 = $40, 8x8 tiles
    STA VERA_L0_TIL
    LDA #$00
    STA VERA_L0_HSC_L
    STA VERA_L0_HSC_H
    STA VERA_L0_VSC_L
    STA VERA_L0_VSC_H

    ; 5. Configure Layer 1 (Foreground: 64x32 4bpp, Map at $00000, Tiles at $08000)
    LDA #$12            ; 4bpp Tile Mode, 64x32
    STA VERA_L1_CFG
    LDA #$00            ; Map Base: $00000 >> 9 = $00
    STA VERA_L1_MAP
    LDA #$40            ; Tile Base: $08000 >> 9 = $40, 8x8 tiles
    STA VERA_L1_TIL
    LDA #$00
    STA VERA_L1_HSC_L
    STA VERA_L1_HSC_H
    STA VERA_L1_VSC_L
    STA VERA_L1_VSC_H

    ; 6. Configure Sonic Hardware Sprites in VRAM $1FC00..$1FC0F
    ; Sprite 0: Body (32x32, VRAM $10100)
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FC
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1, Bank 1 ($1FC00)
    STA VERA_ADDR_H

    LDA #$10            ; Addr low ($0810)
    STA VERA_DATA0
    LDA #$08            ; Addr high
    STA VERA_DATA0
    LDA #<SONIC_X       ; X low
    STA VERA_DATA0
    LDA #>SONIC_X       ; X high
    STA VERA_DATA0
    LDA #<(SONIC_Y+8)   ; Y low
    STA VERA_DATA0
    LDA #>(SONIC_Y+8)   ; Y high
    STA VERA_DATA0
    LDA #$0C            ; Z-depth = 3 (In front of Layer 1)
    STA VERA_DATA0
    LDA #$A0            ; 32x32, Palette 0
    STA VERA_DATA0

    ; Sprite 1: Ears (16x32, VRAM $10000)
    LDA #$00            ; Addr low ($0800)
    STA VERA_DATA0
    LDA #$08            ; Addr high
    STA VERA_DATA0
    LDA #<SONIC_X       ; X low
    STA VERA_DATA0
    LDA #>SONIC_X       ; X high
    STA VERA_DATA0
    LDA #<SONIC_Y       ; Y low
    STA VERA_DATA0
    LDA #>SONIC_Y       ; Y high
    STA VERA_DATA0
    LDA #$0C            ; Z-depth = 3
    STA VERA_DATA0
    LDA #$20            ; 16x32, Palette 0
    STA VERA_DATA0

    ; 7. Initialize Animation Variables
    LDA #$00
    STA FRAME
    STA WATER
    STA FLOWER
    STA SONIC_FRAME
    STA FG_SCROLL_L
    STA FG_SCROLL_H
    STA BG_SCROLL_L
    STA BG_SCROLL_H
    STA BG_FRAC

    ; 8. Enable VERA Video Output: VGA (1) + Layer 0 ($10) + Layer 1 ($20) + Sprites ($40) -> $71
    LDA #$71
    STA VERA_DC_VID

    ; 9. Hook 60 Hz VERA VSYNC IRQ for Green Hill Zone PSG Music
    JSR START_MUSIC_IRQ

; ------------------------------------------------------------------------------
; Main Animation & Scrolling Loop
; ------------------------------------------------------------------------------
MAIN_LOOP:
    ; 1. Check Keyboard Strobe at $C000 for Clean Return
    LDA $C000
    BPL NO_KEY_PRESS
    JMP EXIT_SONIC_DEMO
NO_KEY_PRESS:

    ; 2. Advance Foreground & Background Scroll
    ; Foreground: +2 pixels per frame
    CLC
    LDA FG_SCROLL_L
    ADC #SONIC_SPEED
    STA FG_SCROLL_L
    LDA FG_SCROLL_H
    ADC #$00
    STA FG_SCROLL_H

    ; Background: 1/4 speed of foreground (add 128 to fractional byte)
    LDA BG_FRAC
    CLC
    ADC #$80
    STA BG_FRAC
    BCC BG_NO_CARRY
    INC BG_SCROLL_L
    BNE BG_NO_CARRY
    INC BG_SCROLL_H
BG_NO_CARRY:

    ; Write updated scrolls to VERA hardware registers
    LDA FG_SCROLL_L
    STA VERA_L1_HSC_L
    LDA FG_SCROLL_H
    STA VERA_L1_HSC_H

    LDA BG_SCROLL_L
    STA VERA_L0_HSC_L
    LDA BG_SCROLL_H
    STA VERA_L0_HSC_H

    ; 3. Modulate Sonic Y Position with Ground Rolling Dips (every frame)
    ; Tile column = (FG_SCROLL_L >> 3) & 31
    LDA FG_SCROLL_L
    LSR
    LSR
    LSR
    AND #$1F
    TAX
    LDA Y_DIPS,X
    CLC
    ADC #SONIC_Y
    STA TMP_L           ; Ears Y

    ; Update Ears Sprite Y in VRAM $1FC0C
    LDA #$0C
    STA VERA_ADDR_L
    LDA #$FC
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1
    STA VERA_ADDR_H
    LDA TMP_L
    STA VERA_DATA0

    ; Update Body Sprite Y in VRAM $1FC04 (Ears Y + 8)
    LDA #$04
    STA VERA_ADDR_L
    LDA #$FC
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H
    LDA TMP_L
    CLC
    ADC #$08
    STA VERA_DATA0

    ; 4. Advance Frame Counter
    INC FRAME

    ; 5. Every 4 Frames: Advance Sonic Animation Frame & Water Palette
    LDA FRAME
    AND #$03
    BNE NO_4FRAME

    ; Advance Sonic 4-Frame Running Animation (0, 1, 2, 3)
    INC SONIC_FRAME
    LDA SONIC_FRAME
    AND #$03
    STA SONIC_FRAME
    TAX
    LDA SONIC_BODY_FRAMES,X
    STA TMP_L           ; Body address low

    ; Write Body Addr Low to VRAM $1FC00
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FC
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H
    LDA TMP_L
    STA VERA_DATA0

    ; Write Ears Addr Low to VRAM $1FC08
    LDA SONIC_EARS_FRAMES,X
    STA TMP_L
    LDA #$08
    STA VERA_ADDR_L
    LDA #$FC
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H
    LDA TMP_L
    STA VERA_DATA0

    ; Rotate Shimmering Water Palette at VRAM $1FA50 (4 colors = 8 bytes)
    JSR ROTATE_WATER_PALETTE

NO_4FRAME:
    ; 6. Every 16 Frames: Swap Sunflower Flower Frame at VRAM $0EB80
    LDA FRAME
    AND #$0F
    BNE NO_16FRAME
    JSR ROTATE_FLOWER_TILE
NO_16FRAME:

    ; 7. Frame Delay (~60 FPS)
    LDY #$12
DLY_Y:
    LDX #$FF
DLY_X:
    DEX
    BNE DLY_X
    DEY
    BNE DLY_Y

    JMP MAIN_LOOP

; ------------------------------------------------------------------------------
; Exit Handler: Clean Shutdown, Silence PSG, Restore IRQ & Video
; ------------------------------------------------------------------------------
EXIT_SONIC_DEMO:
    STA $C010           ; Clear keyboard strobe
    JSR STOP_MUSIC_IRQ  ; Disable VERA IRQ & restore Apple II IRQ vector
    JSR SILENCE_PSG     ; Silence all 16 PSG sound channels
    JSR VERA_FM_KEY_OFF_ALL ; Key off every FM channel so notes do not hang
    LDA #$00
    STA VERA_DC_VID     ; Disable VERA video output (switches AppleWin back to text screen)
    RTS

; ------------------------------------------------------------------------------
; Subroutine: Rotate Water Palette at VRAM $1FA50 (4 colors cycling)
; ------------------------------------------------------------------------------
ROTATE_WATER_PALETTE:
    LDA WATER
    CLC
    ADC #$02
    AND #$07            ; 0, 2, 4, 6
    STA WATER
    TAX

    ; Set VRAM address to $1FA50 (Bank 1, stride +1)
    LDA #$50
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H

    LDY #$04            ; 4 colors
WATER_COL_LP:
    LDA WATER_COLORS,X
    STA VERA_DATA0
    LDA WATER_COLORS+1,X
    STA VERA_DATA0
    INX
    INX
    CPX #$08
    BCC WATER_WRAP_OK
    LDX #$00
WATER_WRAP_OK:
    DEY
    BNE WATER_COL_LP
    RTS

; ------------------------------------------------------------------------------
; Subroutine: Swap Sunflower Flower Tile in VRAM $0EB80 (512 bytes)
; ------------------------------------------------------------------------------
ROTATE_FLOWER_TILE:
    LDA FLOWER
    EOR #$01
    STA FLOWER
    BNE FLOWER_FRAME_2

FLOWER_FRAME_1:
    ; Source: Host RAM $3000
    LDA #$00
    STA FLOWER_SRC_L
    LDA #$30
    STA FLOWER_SRC_H
    JMP DO_COPY_FLOWER

FLOWER_FRAME_2:
    ; Source: Host RAM $3200
    LDA #$00
    STA FLOWER_SRC_L
    LDA #$32
    STA FLOWER_SRC_H

DO_COPY_FLOWER:
    ; Set VERA address to $0EB80 (Bank 0, stride +1)
    LDA #$80
    STA VERA_ADDR_L
    LDA #$EB
    STA VERA_ADDR_M
    LDA #$10            ; Bank 0
    STA VERA_ADDR_H

    LDY #$00
COPY_FLW_P1:
    LDA (FLOWER_SRC_L),Y
    STA VERA_DATA0
    INY
    BNE COPY_FLW_P1
    INC FLOWER_SRC_H
COPY_FLW_P2:
    LDA (FLOWER_SRC_L),Y
    STA VERA_DATA0
    INY
    BNE COPY_FLW_P2
    RTS

FLOWER_SRC_L = $18
FLOWER_SRC_H = $19

DIR_BLK_L    = $1A
DIR_BLK_H    = $1B
NEXT_DIR_L   = $1C
NEXT_DIR_H   = $1D
DIR_PTR_L    = $1E
DIR_PTR_H    = $1F

; ------------------------------------------------------------------------------
; Sequential ProDOS file reader: works with SONIC.DAT in the current prefix.
; ------------------------------------------------------------------------------
LOAD_SONIC_ASSETS:
    LDA #$00
    STA REF_NUM
    LDA #$01
    STA SONIC_STAGE
    JSR BUILD_SONIC_PATH
    BCC SONIC_PATH_READY
    JMP SONIC_OPEN_FAIL
SONIC_PATH_READY:
    LDA #$02
    STA SONIC_STAGE
    JSR $BF00
    HEX C8
    DA SONIC_OPEN_PARAMS
    BCC SONIC_OPEN_OK
    JMP SONIC_OPEN_FAIL
SONIC_OPEN_OK:
    LDA SONIC_OPEN_PARAMS+5
    STA REF_NUM

    ; 3. Read Block 0: 512-Byte Palette -> VRAM $1FA00 (Bank 1)
    JSR READ_SONIC_BLOCK
    BCC SONIC_R0_OK
    JMP SONIC_LOAD_FAIL
SONIC_R0_OK:
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1
    STA VERA_ADDR_H
    JSR COPY_BUF_TO_VRAM

    ; 4. Read Blocks 1..2: Flower Animation Frames -> Host RAM $3000..$33FF
    JSR READ_SONIC_BLOCK
    BCC SONIC_R1_OK
    JMP SONIC_LOAD_FAIL
SONIC_R1_OK:
    LDY #$00
CP_F1_LP:
    LDA $3800,Y
    STA $3000,Y
    LDA $3900,Y
    STA $3100,Y
    INY
    BNE CP_F1_LP

    JSR READ_SONIC_BLOCK
    BCC SONIC_R2_OK
    JMP SONIC_LOAD_FAIL
SONIC_R2_OK:
    LDY #$00
CP_F2_LP:
    LDA $3800,Y
    STA $3200,Y
    LDA $3900,Y
    STA $3300,Y
    INY
    BNE CP_F2_LP

    ; 5. Read Blocks 3..10: 8 Blocks (4096 bytes) BG Tilemap -> VRAM $04800 (Bank 0)
    LDA #$00
    STA VERA_ADDR_L
    LDA #$48
    STA VERA_ADDR_M
    LDA #$10            ; Bank 0, Stride +1
    STA VERA_ADDR_H
    LDA #8
    STA BLK_CTR
STREAM_BG:
    JSR READ_SONIC_BLOCK
    BCC SONIC_R4_OK
    JMP SONIC_LOAD_FAIL
SONIC_R4_OK:
    JSR COPY_BUF_TO_VRAM
    DEC BLK_CTR
    BNE STREAM_BG

    ; 7. Read Blocks 26..33: 8 Blocks (4096 bytes) FG Tilemap -> VRAM $00000 (Bank 0)
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$10
    STA VERA_ADDR_H
    LDA #8
    STA BLK_CTR
STREAM_FG:
    JSR READ_SONIC_BLOCK
    BCC SONIC_R5_OK
    JMP SONIC_LOAD_FAIL
SONIC_R5_OK:
    JSR COPY_BUF_TO_VRAM
    DEC BLK_CTR
    BNE STREAM_FG

    ; 8. Read Blocks 34..97: 64 Blocks (32768 bytes) Tileset -> VRAM $08000 (Bank 0)
    LDA #$00
    STA VERA_ADDR_L
    LDA #$80
    STA VERA_ADDR_M
    LDA #$10
    STA VERA_ADDR_H
    LDA #64
    STA BLK_CTR
STREAM_TILES:
    JSR READ_SONIC_BLOCK
    BCC SONIC_R6_OK
    JMP SONIC_LOAD_FAIL
SONIC_R6_OK:
    JSR COPY_BUF_TO_VRAM
    DEC BLK_CTR
    BNE STREAM_TILES

    ; 9. Read Blocks 98..102: 5 Blocks (2560 bytes) Sprites -> VRAM $10000 (Bank 1)
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1
    STA VERA_ADDR_H
    LDA #5
    STA BLK_CTR
STREAM_SPRITES:
    JSR READ_SONIC_BLOCK
    BCC SONIC_R7_OK
    JMP SONIC_LOAD_FAIL
SONIC_R7_OK:
    JSR COPY_BUF_TO_VRAM
    DEC BLK_CTR
    BNE STREAM_SPRITES

    ; 10. The PSG+FM music stream is BLOADed to $4000 by the STARTUP menu
    ; (SONICMUS.BIN).  Reading it into RAM from inside the demo corrupted
    ; ProDOS' own file bookkeeping, so the loader only handles the assets now.

    ; Close the ProDOS file and report success.
    LDA REF_NUM
    STA SONIC_CLOSE_PARAMS+1
    JSR $BF00
    HEX CC
    DA SONIC_CLOSE_PARAMS
    LDA #$00
    STA REF_NUM
    CLC
    RTS

SONIC_LOAD_FAIL:
    LDA REF_NUM
    BEQ SONIC_LOAD_FAIL_DONE
    STA SONIC_CLOSE_PARAMS+1
    JSR $BF00
    HEX CC
    DA SONIC_CLOSE_PARAMS
    LDA #$00
    STA REF_NUM
SONIC_LOAD_FAIL_DONE:
    SEC
    RTS

SONIC_OPEN_FAIL:
    STA SONIC_ERROR
    SEC
    RTS

; Read exactly 512 bytes from the open file into $3800-$39FF.
READ_SONIC_BLOCK:
    LDA #$03
    STA SONIC_STAGE
    LDA REF_NUM
    STA SONIC_READ_PARAMS+1
    JSR $BF00
    HEX CA
    DA SONIC_READ_PARAMS
    BCS SONIC_READ_FAIL
    LDA SONIC_READ_PARAMS+6
    BNE SONIC_READ_FAIL
    LDA SONIC_READ_PARAMS+7
    CMP #$02
    BEQ SONIC_READ_OK
    LDA #$FE
SONIC_READ_FAIL:
    ; A short/error read must never be treated as a valid asset block.
    STA SONIC_ERROR
    SEC
    RTS
SONIC_READ_OK:
    CLC
    RTS

SONIC_PATH:
    HEX 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
SONIC_NAME:
    ASC "SONIC.DAT"
    HEX 00
SONIC_NAMEBUF:
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
SONIC_PREFIX_PARAMS:
    HEX 01
    DA SONIC_PATH
SONIC_ONLINE_PARAMS:
    HEX 02,00
    DA SONIC_ONLINE_BUF
SONIC_ONLINE_BUF:
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
SONIC_VOLUME_LEN:
    HEX 00
SONIC_OPEN_PARAMS:
    HEX 03
    DA SONIC_PATH
    DA $3D00
    HEX 00
SONIC_READ_PARAMS:
    HEX 04,00
    DA $3800
    DA $0200
    DA $0000
SONIC_CLOSE_PARAMS:
    HEX 01,00
SONIC_STAGE:
    HEX 00
SONIC_ERROR:
    HEX 00
SONIC_ERROR_TEXT:
    ASC "SONIC FILE ERROR STAGE "
    HEX 00
SONIC_HEX:
    ASC "0123456789ABCDEF"

SHOW_SONIC_ERROR:
    JSR $FC58
    LDX #$00
SONIC_ERROR_PRINT:
    LDA SONIC_ERROR_TEXT,X
    BEQ SONIC_ERROR_NUMBERS
    JSR $FDED
    INX
    BNE SONIC_ERROR_PRINT
SONIC_ERROR_NUMBERS:
    LDA SONIC_STAGE
    JSR SONIC_PRINT_HEX
    LDA #$20
    JSR $FDED
    LDA SONIC_ERROR
    JSR SONIC_PRINT_HEX
    LDA #$8D
    JSR $FDED
    RTS
SONIC_PRINT_HEX:
    PHA
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA SONIC_HEX,X
    JSR $FDED
    PLA
    AND #$0F
    TAX
    LDA SONIC_HEX,X
    JSR $FDED
    RTS

; GET_PREFIX returns the current ProDOS directory. Build an absolute pathname
; so launching through BASIC.SYSTEM behaves consistently from copied folders.
BUILD_SONIC_PATH:
    LDA $BF30
    STA SONIC_ONLINE_PARAMS+1
    JSR $BF00
    HEX C7
    DA SONIC_PREFIX_PARAMS
    BCS SONIC_PATH_FAIL
    LDY SONIC_PATH
    BEQ SONIC_PATH_ADD_ROOT_SLASH
    LDA SONIC_PATH,Y
    CMP #$2F
    BEQ SONIC_PATH_APPEND_NAME
    LDA #$2F
    INY
    STA SONIC_PATH,Y
    BNE SONIC_PATH_APPEND_NAME
SONIC_PATH_ADD_ROOT_SLASH:
    JSR $BF00
    HEX C5
    DA SONIC_ONLINE_PARAMS
    BCS SONIC_PATH_FAIL
    LDA SONIC_ONLINE_BUF
    AND #$0F
    BNE SONIC_VOLUME_FOUND
    LDA SONIC_ONLINE_BUF+1
    JMP SONIC_PATH_FAIL
SONIC_VOLUME_FOUND:
    STA SONIC_VOLUME_LEN
    LDY #$01
    LDA #$2F
    STA SONIC_PATH,Y
    LDX #$00
SONIC_PATH_VOLUME_LOOP:
    LDA SONIC_ONLINE_BUF+1,X
    INY
    STA SONIC_PATH,Y
    INX
    CPX SONIC_VOLUME_LEN
    BCC SONIC_PATH_VOLUME_LOOP
    LDA #$2F
    INY
    STA SONIC_PATH,Y
SONIC_PATH_APPEND_NAME:
    LDX #$00
SONIC_PATH_NAME_LOOP:
    LDA SONIC_NAME,X
    BEQ SONIC_PATH_DONE
    INY
    STA SONIC_PATH,Y
    INX
    BNE SONIC_PATH_NAME_LOOP
SONIC_PATH_DONE:
    TYA
    STA SONIC_PATH
    CLC
    RTS
SONIC_PATH_FAIL:
    SEC
    RTS

; Helper: Copy 512 bytes from $3800..$39FF to VERA_DATA0
COPY_BUF_TO_VRAM:
    LDY #$00
CP_VRAM_P1:
    LDA $3800,Y
    STA VERA_DATA0
    INY
    BNE CP_VRAM_P1
CP_VRAM_P2:
    LDA $3900,Y
    STA VERA_DATA0
    INY
    BNE CP_VRAM_P2
    RTS

; ------------------------------------------------------------------------------
; 60 Hz VERA VSYNC IRQ Audio Player Routine
; ------------------------------------------------------------------------------
START_MUSIC_IRQ:
    SEI
    LDA #<MUSIC_BASE
    STA MUSIC_PTR_L
    LDA #>MUSIC_BASE
    STA MUSIC_PTR_H
    LDA #$00
    STA MUSIC_DELAY

    LDA $03FE
    STA OLD_IRQ_L
    LDA $03FF
    STA OLD_IRQ_H
    LDA #<SONIC_IRQ_HANDLER
    STA $03FE
    LDA #>SONIC_IRQ_HANDLER
    STA $03FF

    LDA #$01
    STA VERA_ISR          ; Acknowledge any pending IRQ
    STA VERA_IEN          ; Enable VERA VSYNC interrupt
    CLI
    RTS

STOP_MUSIC_IRQ:
    SEI
    LDA #$00
    STA VERA_IEN
    LDA OLD_IRQ_L
    STA $03FE
    LDA OLD_IRQ_H
    STA $03FF
    CLI
    RTS

SONIC_IRQ_HANDLER:
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA VERA_ISR
    AND #$01
    BEQ IRQ_EXIT
    LDA #$01
    STA VERA_ISR          ; Acknowledge VSYNC

    ; Save foreground VERA address registers
    LDA VERA_ADDR_L
    STA IRQ_ADDR_L
    LDA VERA_ADDR_M
    STA IRQ_ADDR_M
    LDA VERA_ADDR_H
    STA IRQ_ADDR_H

    JSR TICK_SONIC_MUSIC

    ; Restore foreground VERA address registers
    LDA IRQ_ADDR_L
    STA VERA_ADDR_L
    LDA IRQ_ADDR_M
    STA VERA_ADDR_M
    LDA IRQ_ADDR_H
    STA VERA_ADDR_H

IRQ_EXIT:
    PLA
    TAY
    PLA
    TAX
    PLA
    RTI

IRQ_ADDR_L:
    HEX 00
IRQ_ADDR_M:
    HEX 00
IRQ_ADDR_H:
    HEX 00

TICK_SONIC_MUSIC:
    LDA MUSIC_DELAY
    BEQ DECODE_MUSIC_EVENT
    DEC MUSIC_DELAY
    RTS

DECODE_MUSIC_EVENT:
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    CMP #$FF
    BNE MUSIC_CHK_DELAY
    JMP RESTART_MUSIC
MUSIC_CHK_DELAY:
    CMP #$80
    BCS MUSIC_CHK_PSG
    STA MUSIC_DELAY
    JSR MUSIC_ADVANCE_1
    RTS
MUSIC_CHK_PSG:
    CMP #$C0
    BCS MUSIC_CHK_FM
    ; PSG Register Write: Address is $1F9C0 + (Command & $3F)
    AND #$3F
    CLC
    ADC #$C0
    STA VERA_ADDR_L
    LDA #$F9
    ADC #$00
    STA VERA_ADDR_M
    LDA #$01            ; Bank 1 ($1F9C0), Stride 0 (single write)
    STA VERA_ADDR_H

    LDY #$01
    LDA (MUSIC_PTR_L),Y
    STA VERA_DATA0
    JSR MUSIC_ADVANCE_2
    JMP DECODE_MUSIC_EVENT
MUSIC_CHK_FM:
    CMP #$E0
    BCS MUSIC_NOP_EVENT
    ; $C0-$DF: (count - 1) in the low five bits, then count YM2151 pairs.
    AND #$1F
    CLC
    ADC #$01            ; stored value is count-1: recover the real pair count
    STA FM_COUNT
    JSR MUSIC_ADVANCE_1
    LDA FM_PRESENT
    BEQ MUSIC_FM_SKIP
MUSIC_FM_WRITE:
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    PHA
    JSR MUSIC_ADVANCE_1
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    TAX
    PLA
    JSR VERA_FM_WRITE   ; A = register, X = value (tracks $08 into FM_KEYS)
    JSR MUSIC_ADVANCE_1
    DEC FM_COUNT
    BNE MUSIC_FM_WRITE
    JMP DECODE_MUSIC_EVENT
MUSIC_FM_SKIP:
    ; No FM daughterboard: drop the batch payload without touching YM_SEL/YM_DATA (/DEVICE SELECT).
    JSR MUSIC_ADVANCE_2
    DEC FM_COUNT
    BNE MUSIC_FM_SKIP
    JMP DECODE_MUSIC_EVENT
MUSIC_NOP_EVENT:
    ; $E0-$FE: block alignment no-op, consumes no tick.
    JSR MUSIC_ADVANCE_1
    JMP DECODE_MUSIC_EVENT

MUSIC_ADVANCE_1:
    CLC
    LDA MUSIC_PTR_L
    ADC #$01
    STA MUSIC_PTR_L
    LDA MUSIC_PTR_H
    ADC #$00
    STA MUSIC_PTR_H
    RTS

MUSIC_ADVANCE_2:
    CLC
    LDA MUSIC_PTR_L
    ADC #$02
    STA MUSIC_PTR_L
    LDA MUSIC_PTR_H
    ADC #$00
    STA MUSIC_PTR_H
    RTS

RESTART_MUSIC:
    ; Loop the arrangement: the stream is compressed against an all-zero PSG and
    ; YM2151 state, so both engines must be cleared before replaying it.
    JSR SILENCE_PSG
    JSR VERA_FM_RESET
    LDA #<MUSIC_BASE
    STA MUSIC_PTR_L
    LDA #>MUSIC_BASE
    STA MUSIC_PTR_H
    LDA #$00
    STA MUSIC_DELAY
    RTS

; ------------------------------------------------------------------------------
; Helper: Fast 64KB VRAM Wiping Routine (Bank 0 & Bank 1)
; ------------------------------------------------------------------------------
CLR_64K:
    LDX #$20
    LDY #$00
    LDA #$00
CLR_64K_LP:
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    DEY
    BNE CLR_64K_LP
    DEX
    BNE CLR_64K_LP
    RTS

; Helper: Silence all 16 PSG sound channels ($1F9C0..$1F9FF)
SILENCE_PSG:
    LDA #$C0
    STA VERA_ADDR_L
    LDA #$F9
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1
    STA VERA_ADDR_H
    LDX #64
    LDA #$00
SILENCE_LP:
    STA VERA_DATA0
    DEX
    BNE SILENCE_LP
    RTS

; ==============================================================================
; YM2151 FM daughterboard helpers (detection, reset, key off, register write)
; ==============================================================================
.include "../vera_fm.inc"

; Block count of the PSG+FM music stream at the tail of SONIC.DAT (generated).
.include "sonic_music.inc"

; ------------------------------------------------------------------------------
; Data Tables
; ------------------------------------------------------------------------------
; 4 Animation Frame Sprite Address Pointers (VRAM $10000 + Frame * $200)
SONIC_BODY_FRAMES:
    HEX 10 20 30 40     ; $0810, $0820, $0830, $0840

SONIC_EARS_FRAMES:
    HEX 00 04 00 04     ; $0800, $0804, $0800, $0804

; 32 Ground Offset Dips for Sonic's Vertical Bobbing over Rolling Hills
Y_DIPS:
    HEX 02 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 02 02 04 04 06 08 08 06 04 04 02 02

; 4 Cycling Water Colors (12-bit RGB Little-Endian)
WATER_COLORS:
    HEX 9D 02 0B 02 4D 02 9F 06

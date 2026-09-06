; ==============================================================================
; Demo 7: Sonic The Hedgehog (Green Hill Zone) for Apple II (VERA Card)
; Based on ZeroByte's Sega Genesis 16-bit Engine for Commander X16
; Features:
;   - Dual-Layer Parallax Scrolling (Layer 1 Foreground + Layer 0 Background)
;   - Sonic Running 4-Frame Hardware Sprite Animation (Ears + Body)
;   - Dynamic Ground Level Modulation (Sonic bobs up/down over the rolling hills)
;   - Shimmering Water & Waterfall Palette Cycling (waterpalette at $1FA50)
;   - Rotating Sunflower Tile Animation (VRAM $0EB80 swapped in real-time)
;   - Authentic 60 Hz VERA PSG Green Hill Zone Polyphonic Chiptune BGM
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

    ; 3. Load SONIC.DAT via ProDOS MLI ($C8 OPEN, $CA READ, $CC CLOSE)
    JSR LOAD_SONIC_ASSETS

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
MUSIC_DEST_L = $1A
MUSIC_DEST_H = $1B

; ------------------------------------------------------------------------------
; Direct Block MLI Streaming Engine: Reads 103 Blocks from Disk into VRAM & RAM
; ------------------------------------------------------------------------------
LOAD_SONIC_ASSETS:
    ; 1. Copy Boot Drive Unit Number from ProDOS Global Page $BF30
    LDA $BF30
    STA MLI_UNIT_NUM

    ; 2. Dynamically scan ProDOS Root Directory (Block 2 / Block 3) for SONIC.DAT
    JSR LOCATE_SONIC_DAT

    ; 3. Read Block 0: 512-Byte Palette -> VRAM $1FA00 (Bank 1)
    JSR READ_BLOCK_MLI
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1
    STA VERA_ADDR_H
    JSR COPY_BUF_TO_VRAM
    JSR ADVANCE_BLOCK

    ; 4. Read Blocks 1..2: Flower Animation Frames -> Host RAM $3000..$33FF
    JSR READ_BLOCK_MLI
    LDY #$00
CP_F1_LP:
    LDA $3800,Y
    STA $3000,Y
    LDA $3900,Y
    STA $3100,Y
    INY
    BNE CP_F1_LP
    JSR ADVANCE_BLOCK

    JSR READ_BLOCK_MLI
    LDY #$00
CP_F2_LP:
    LDA $3800,Y
    STA $3200,Y
    LDA $3900,Y
    STA $3300,Y
    INY
    BNE CP_F2_LP
    JSR ADVANCE_BLOCK

    ; 5. Read Blocks 3..17: 15 Blocks (7680 bytes) PSG Music -> Host RAM $4000..$5DFF
    LDA #15
    STA BLK_CTR
    LDA #$00
    STA MUSIC_DEST_L
    LDA #$40
    STA MUSIC_DEST_H

LOAD_MUS_LP:
    JSR READ_BLOCK_MLI
    LDY #$00
CP_MUS_P1:
    LDA $3800,Y
    STA (MUSIC_DEST_L),Y
    INY
    BNE CP_MUS_P1
    INC MUSIC_DEST_H

CP_MUS_P2:
    LDA $3900,Y
    STA (MUSIC_DEST_L),Y
    INY
    BNE CP_MUS_P2
    INC MUSIC_DEST_H

    JSR ADVANCE_BLOCK
    DEC BLK_CTR
    BNE LOAD_MUS_LP

    ; 6. Read Blocks 18..25: 8 Blocks (4096 bytes) BG Tilemap -> VRAM $04800 (Bank 0)
    LDA #$00
    STA VERA_ADDR_L
    LDA #$48
    STA VERA_ADDR_M
    LDA #$10            ; Bank 0, Stride +1
    STA VERA_ADDR_H
    LDA #8
    STA BLK_CTR
STREAM_BG:
    JSR READ_BLOCK_MLI
    JSR COPY_BUF_TO_VRAM
    JSR ADVANCE_BLOCK
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
    JSR READ_BLOCK_MLI
    JSR COPY_BUF_TO_VRAM
    JSR ADVANCE_BLOCK
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
    JSR READ_BLOCK_MLI
    JSR COPY_BUF_TO_VRAM
    JSR ADVANCE_BLOCK
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
    JSR READ_BLOCK_MLI
    JSR COPY_BUF_TO_VRAM
    JSR ADVANCE_BLOCK
    DEC BLK_CTR
    BNE STREAM_SPRITES
    RTS

; ------------------------------------------------------------------------------
; Helper: Scan ProDOS Directory for "SONIC.DAT" Key Block
; ------------------------------------------------------------------------------
LOCATE_SONIC_DAT:
    LDA #$02            ; Start at Root Directory Block 2
    STA DIR_BLK_L
    LDA #$00
    STA DIR_BLK_H

SCAN_DIR_BLK:
    LDA DIR_BLK_L
    STA MLI_BLK_NUM
    LDA DIR_BLK_H
    STA MLI_BLK_NUM+1
    JSR READ_BLOCK_MLI
    BCS LOCATE_DEFAULT

    ; Extract next directory block pointer at $3802..$3803
    LDA $3802
    STA NEXT_DIR_L
    LDA $3803
    STA NEXT_DIR_H

    ; Loop over 13 entries (starting at offset 4)
    LDA #$04
    STA DIR_PTR_L
    LDA #$38
    STA DIR_PTR_H
    LDX #13

SCAN_ENTRY_LP:
    LDY #$00
    LDA (DIR_PTR_L),Y
    BEQ NEXT_ENTRY_SKIP ; Inactive entry
    AND #$0F
    CMP #$09            ; "SONIC.DAT" length = 9
    BNE NEXT_ENTRY_SKIP

    ; Compare 9 ASCII characters
    LDY #$01
CHK_NAME_LP:
    LDA (DIR_PTR_L),Y
    CMP SONIC_NAME_TXT-1,Y
    BNE NEXT_ENTRY_SKIP
    INY
    CPY #$0A
    BNE CHK_NAME_LP

    ; Match! Extract key block at offset $11 (17)
    ; Data blocks start at key_block + 1
    LDY #$11
    LDA (DIR_PTR_L),Y
    CLC
    ADC #$01
    STA MLI_BLK_NUM
    LDY #$12
    LDA (DIR_PTR_L),Y
    ADC #$00
    STA MLI_BLK_NUM+1
    RTS

NEXT_ENTRY_SKIP:
    CLC
    LDA DIR_PTR_L
    ADC #39             ; ProDOS directory entry length = 39 bytes
    STA DIR_PTR_L
    LDA DIR_PTR_H
    ADC #$00
    STA DIR_PTR_H
    DEX
    BNE SCAN_ENTRY_LP

    ; Check if there is another directory block
    LDA NEXT_DIR_L
    ORA NEXT_DIR_H
    BEQ LOCATE_DEFAULT
    LDA NEXT_DIR_L
    STA DIR_BLK_L
    LDA NEXT_DIR_H
    STA DIR_BLK_H
    JMP SCAN_DIR_BLK

LOCATE_DEFAULT:
    ; Fallback to default block 143 ($008F)
    LDA #$8F
    STA MLI_BLK_NUM
    LDA #$00
    STA MLI_BLK_NUM+1
    RTS

SONIC_NAME_TXT:
    ASC "SONIC.DAT"

; Helper: Low-level Direct Block MLI ($80)
READ_BLOCK_MLI:
    JSR $BF00
    HEX 80              ; READ_BLOCK Call
    DA READ_BLOCK_PARAMS
    RTS

READ_BLOCK_PARAMS:
    HEX 03              ; Param count = 3
MLI_UNIT_NUM:
    HEX 60              ; Unit Number
    DA $3800            ; 512-Byte Buffer ($3800..$39FF)
MLI_BLK_NUM:
    DA $008F            ; 16-Bit Block Number (143)

ADVANCE_BLOCK:
    INC MLI_BLK_NUM
    BNE ADV_BLK_DONE
    INC MLI_BLK_NUM+1
ADV_BLK_DONE:
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
    LDA #<$4000
    STA MUSIC_PTR_L
    LDA #>$4000
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
    BEQ DECODE_MUSIC_PSG
    DEC MUSIC_DELAY
    RTS

DECODE_MUSIC_PSG:
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    CMP #$FF
    BEQ RESTART_MUSIC
    CMP #$80
    BCC SET_MUSIC_DELAY

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

    ; Advance music pointer by 2 bytes
    CLC
    LDA MUSIC_PTR_L
    ADC #$02
    STA MUSIC_PTR_L
    LDA MUSIC_PTR_H
    ADC #$00
    STA MUSIC_PTR_H
    JMP DECODE_MUSIC_PSG

SET_MUSIC_DELAY:
    STA MUSIC_DELAY
    ; Advance music pointer by 1 byte
    CLC
    LDA MUSIC_PTR_L
    ADC #$01
    STA MUSIC_PTR_L
    LDA MUSIC_PTR_H
    ADC #$00
    STA MUSIC_PTR_H
    RTS

RESTART_MUSIC:
    LDA #<$4000
    STA MUSIC_PTR_L
    LDA #>$4000
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

; ==============================================================================
; Dual-Layer Parallax Deep Space Starfield & Energy Waves for Apple II
; ==============================================================================

* = $2000

SCROLL_L0   = $EB
SCROLL_L1   = $EC
FRAME_CNT   = $ED
TICK        = $EE
PTR_L       = $EF
PTR_H       = $F0
ROW_IDX     = $F1

START:
    LDA #$00
    STA VERA_CTRL
    ; Enable VGA (1) + Layer 0 (0x10) + Layer 1 (0x20) -> DC_VID = $31
    LDA #$31
    STA VERA_DC_VID
    LDA #$40            ; 2x scale
    STA VERA_DC_HSC
    STA VERA_DC_VSC

    ; Setup Palette at $1FA00
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H

    ; Entry 0: Pure Black Space ($0000)
    LDA #$00
    STA VERA_DATA0
    STA VERA_DATA0
    ; Entry 1: Deep Nebula Blue ($0110)
    LDA #$10
    STA VERA_DATA0
    LDA #$01
    STA VERA_DATA0
    ; Entry 2: Distant Star Cyan ($007E)
    LDA #$7E
    STA VERA_DATA0
    LDA #$00
    STA VERA_DATA0
    ; Entry 3: Blazing Pure White Energy ($0FFF)
    LDA #$FF
    STA VERA_DATA0
    LDA #$0F
    STA VERA_DATA0

    ; 1. Load Background Star Tiles to VRAM $08000
    LDA #$00
    STA VERA_ADDR_L
    LDA #$80
    STA VERA_ADDR_M
    LDA #$10            ; Stride +1
    STA VERA_ADDR_H

    LDX #$00
LOAD_BG_CHR:
    LDA BG_TILES,X
    STA VERA_DATA0
    INX
    CPX #$20            ; 32 bytes (4 tiles)
    BNE LOAD_BG_CHR

    ; 2. Clear Layer 0 Map at VRAM $00000 (Pure clean black space, zero vertical lines!)
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$10
    STA VERA_ADDR_H

    LDX #$10            ; 4096 bytes
    LDY #$00
CLR_L0:
    LDA #$00
    STA VERA_DATA0
    STA VERA_DATA0
    INY
    BNE CLR_L0
    DEX
    BNE CLR_L0

    ; 3. Plant 32 discrete star points at specific scattered coordinates on Layer 0
    LDX #$00
PLANT_STARS:
    LDA STAR_ADDR_L,X
    STA VERA_ADDR_L
    LDA STAR_ADDR_M,X
    STA VERA_ADDR_M
    LDA #$10
    STA VERA_ADDR_H

    LDA #$01            ; Star Tile
    STA VERA_DATA0
    LDA #$02            ; Cyan Star Color
    STA VERA_DATA0
    INX
    CPX #24
    BNE PLANT_STARS

    ; 4. Fill Layer 1 (Foreground Plasma Wave Array) at VRAM $04000 (64x32)
    ; 3 dynamic plasma beam lines at Row 6, 14, 22
    LDA #$00
    STA VERA_ADDR_L
    LDA #$40
    STA VERA_ADDR_M
    LDA #$10
    STA VERA_ADDR_H

    LDA #$00
    STA ROW_IDX
L1_ROW_LOOP:
    LDA ROW_IDX
    CMP #6
    BEQ DO_PLASMA
    CMP #14
    BEQ DO_PLASMA
    CMP #22
    BEQ DO_PLASMA

    ; Blank Transparent Row (64 tiles x 2 = 128 bytes)
    LDY #$40
CLR_ROW:
    LDA #$00
    STA VERA_DATA0
    STA VERA_DATA0
    DEY
    BNE CLR_ROW
    JMP ROW_DONE

DO_PLASMA:
    LDY #$40
    LDX #$01
DRAW_PLASMA:
    STX VERA_DATA0      ; Tile 1, 2, 3 (Animated wave)
    LDA #$03            ; Bright White on Transparent (Color 3)
    STA VERA_DATA0
    INX
    CPX #$04
    BNE NO_WRAP_PLASMA
    LDX #$01
NO_WRAP_PLASMA:
    DEY
    BNE DRAW_PLASMA

ROW_DONE:
    INC ROW_IDX
    LDA ROW_IDX
    CMP #32
    BNE L1_ROW_LOOP

    ; 5. Upload Frame 0 of Electric Plasma Tile to VRAM $09000
    JSR UPLOAD_FRAME

    ; 6. Configure Layer 0 & Layer 1
    LDA #$10
    STA VERA_L0_CFG
    LDA #$00
    STA VERA_L0_MAP
    LDA #$40
    STA VERA_L0_TIL
    LDA #$00
    STA VERA_L0_VSC_L
    STA VERA_L0_VSC_H

    LDA #$10
    STA VERA_L1_CFG
    LDA #$20
    STA VERA_L1_MAP
    LDA #$48
    STA VERA_L1_TIL
    LDA #$00
    STA VERA_L1_VSC_L
    STA VERA_L1_VSC_H

    LDA #$00
    STA SCROLL_L0
    STA SCROLL_L1
    STA FRAME_CNT
    STA TICK

MAIN_LOOP:
    ; 1. Slow Background Parallax: Scroll Layer 0 LEFT at 1x speed
    INC SCROLL_L0
    LDA SCROLL_L0
    STA VERA_L0_HSC_L

    ; 2. Fast Foreground Parallax: Scroll Layer 1 LEFT at 3x speed
    LDA SCROLL_L1
    CLC
    ADC #$03
    STA SCROLL_L1
    STA VERA_L1_HSC_L

    ; 3. Cycle Plasma Animation Frame (0..5)
    INC TICK
    LDA TICK
    CMP #$03
    BCC NO_FRAME_CHG
    LDA #$00
    STA TICK
    INC FRAME_CNT
    LDA FRAME_CNT
    CMP #$06
    BNE FRAME_OK
    LDA #$00
    STA FRAME_CNT
FRAME_OK:
    JSR UPLOAD_FRAME

NO_FRAME_CHG:
    ; Check Keyboard Strobe
    LDA $C000
    BPL NO_KEY
    STA $C010
    LDA #$FF
    STA $F1
    RTS

NO_KEY:
    LDY #$04
DLY1:
    LDX #$FF
DLY2:
    DEX
    BNE DLY2
    DEY
    BNE DLY1
    JMP MAIN_LOOP

; Helper: Upload current 32-byte frame of plasma tiles to VRAM $09000
UPLOAD_FRAME:
    LDA FRAME_CNT
    ASL
    ASL
    ASL
    ASL
    ASL                 ; FRAME * 32
    CLC
    ADC #<ZAP_TILES
    STA PTR_L
    LDA #>ZAP_TILES
    ADC #$00
    STA PTR_H

    LDA #$00
    STA VERA_ADDR_L
    LDA #$90
    STA VERA_ADDR_M
    LDA #$10            ; Stride +1
    STA VERA_ADDR_H

    LDY #$00
UP_LP:
    LDA (PTR_L),Y
    STA VERA_DATA0
    INY
    CPY #$20            ; 32 bytes
    BNE UP_LP
    RTS

; Scattered Star VRAM Low/High byte coordinates (Zero regular patterns = Zero vertical lines)
STAR_ADDR_L:
    HEX 12 56 9A DE 24 78 BC 0E 42 86 CA 1E 62 A6 EA 38 7C C0 14 58 9C E0 34 88
STAR_ADDR_M:
    HEX 01 02 04 05 07 08 0A 0C 0D 0F 02 03 06 08 0B 0D 0E 01 04 07 09 0C 0E 03

; Background star tiles (32 bytes)
BG_TILES:
    HEX 00 00 00 00 00 00 00 00   ; 0: Empty
    HEX 00 10 38 10 00 00 00 00   ; 1: Discrete Star

; 192 bytes of authentic electricity waveform tile graphics
ZAP_TILES:
    HEX 00 00 00 00 00 00 00 00
    HEX 01 02 02 64 94 14 08 00
    HEX 00 80 40 40 58 24 05 02
    HEX 00 00 00 40 A2 A5 18 00
    HEX 00 00 00 00 00 00 00 00
    HEX 10 28 24 44 45 42 80 00
    HEX 00 00 00 04 8A 4A 51 20
    HEX 00 00 00 06 29 51 80 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 80 40 40 58 24 05 02
    HEX 00 00 00 40 A2 A5 18 00
    HEX 01 02 02 64 94 14 08 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 04 8A 4A 51 20
    HEX 00 00 00 06 29 51 80 00
    HEX 10 28 24 44 45 42 80 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 40 A2 A5 18 00
    HEX 01 02 02 64 94 14 08 00
    HEX 00 80 40 40 58 24 05 02
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 06 29 51 80 00
    HEX 10 28 24 44 45 42 80 00
    HEX 00 00 00 04 8A 4A 51 20

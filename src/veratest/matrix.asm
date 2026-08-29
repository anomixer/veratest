; ==============================================================================
; The Matrix Digital Code Rain Demo for Apple II (VERA Card)
; Ultra-Random Multi-Track Multi-Speed Matrix Stream Engine
; ==============================================================================

* = $2000

COL         = $EB
ROW         = $EC
OFFS_0      = $ED
OFFS_1      = $EE
OFFS_2      = $EF
TICK        = $F0
PTR_L       = $F1
PTR_H       = $F2

START:
    LDA #$00
    STA VERA_CTRL
    LDA #$11            ; Enable VGA (1) + Layer 0 (0x10)
    STA VERA_DC_VID
    LDA #$40            ; 2x scale (40 columns text)
    STA VERA_DC_HSC
    STA VERA_DC_VSC

    ; 1. Upload Matrix Glyph Tile Patterns to VRAM $08000 (128 bytes)
    LDA #$00
    STA VERA_ADDR_L
    LDA #$80
    STA VERA_ADDR_M
    LDA #$10            ; Stride +1
    STA VERA_ADDR_H

    LDX #$00
LOAD_GLYPHS:
    LDA MATRIX_GLYPHS,X
    STA VERA_DATA0
    INX
    CPX #$80            ; 16 glyphs x 8 bytes = 128 bytes
    BNE LOAD_GLYPHS

    ; 2. Configure Layer 0: 256-Color Text Mode (T256C = 1)
    LDA #$18            ; 256-Color Text Mode
    STA VERA_L0_CFG
    LDA #$00            ; Map Base: $00000 >> 9 = 0
    STA VERA_L0_MAP
    LDA #$40            ; Tile Base: $08000 >> 9 = $40 (8x8 tiles)
    STA VERA_L0_TIL
    LDA #$00
    STA VERA_L0_HSC_L
    STA VERA_L0_HSC_H
    STA VERA_L0_VSC_L
    STA VERA_L0_VSC_H

    ; 3. Fill Screen Buffer VRAM $00000 (64x32 x 2 = 4096 bytes)
    ; Each column is assigned a random Palette Track (Track 0: 1..32, Track 1: 33..64, Track 2: 65..96)
    ; with highly randomized offsets and blanks for organic, irregular waterfalls!
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$10            ; Stride +1
    STA VERA_ADDR_H

    LDA #$00
    STA ROW
ROW_LOOP:
    LDA #$00
    STA COL
COL_LOOP:
    ; Byte 0: Random Matrix Glyph (1..15)
    JSR GET_RAND
    AND #$0F
    BNE GLYPH_OK
    LDA #$01
GLYPH_OK:
    STA VERA_DATA0

    ; Byte 1: Palette Index derived from Column Track + Random Offset
    LDX COL
    CPX #40
    BCS BLANK_CELL

    ; Check if this column is an empty space gap
    LDA COL_TRACKS,X
    BEQ BLANK_CELL      ; Track 0 = occasional empty column

    ; Track 1 (Base 1), Track 2 (Base 33), Track 3 (Base 65)
    CMP #$01
    BEQ ASSIGN_T1
    CMP #$02
    BEQ ASSIGN_T2

ASSIGN_T3:
    ; Track 3: Fast narrow streams (Base 65)
    LDA ROW
    CLC
    ADC COL_OFFSETS,X
    AND #$1F
    CLC
    ADC #65
    STA VERA_DATA0
    JMP NEXT_CELL

ASSIGN_T2:
    ; Track 2: Double-head streams (Base 33)
    LDA ROW
    CLC
    ADC COL_OFFSETS,X
    AND #$1F
    CLC
    ADC #33
    STA VERA_DATA0
    JMP NEXT_CELL

ASSIGN_T1:
    ; Track 1: Long flowing streams (Base 1)
    LDA ROW
    CLC
    ADC COL_OFFSETS,X
    AND #$1F
    CLC
    ADC #1
    STA VERA_DATA0
    JMP NEXT_CELL

BLANK_CELL:
    LDA #$00
    STA VERA_DATA0

NEXT_CELL:
    INC COL
    LDA COL
    CMP #64
    BNE COL_LOOP

    INC ROW
    LDA ROW
    CMP #32
    BNE ROW_LOOP

    LDA #$00
    STA OFFS_0
    STA OFFS_1
    STA OFFS_2
    STA TICK

; ==============================================================================
; Main Animation Loop: Multi-Track Asynchronous Palette Cycling
; Track 0 rotates at speed 1, Track 1 at speed 2, Track 2 at speed 3
; Plus live random glyph mutation glitches!
; ==============================================================================
MAIN_LOOP:
    ; 1. Upload Palette Track 1 (VRAM $1FA02..$1FA41) - Long Flowing Streams
    LDA #$02
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H

    LDX #$00
T1_LOOP:
    TXA
    CLC
    ADC OFFS_0
    AND #$1F
    ASL
    TAY
    LDA PAL_TRACK1,Y
    STA VERA_DATA0
    INY
    LDA PAL_TRACK1,Y
    STA VERA_DATA0
    INX
    CPX #32
    BNE T1_LOOP

    ; 2. Upload Palette Track 2 (VRAM $1FA42..$1FA81) - Double-Head Streams
    LDA #$42
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H

    LDX #$00
T2_LOOP:
    TXA
    CLC
    ADC OFFS_1
    AND #$1F
    ASL
    TAY
    LDA PAL_TRACK2,Y
    STA VERA_DATA0
    INY
    LDA PAL_TRACK2,Y
    STA VERA_DATA0
    INX
    CPX #32
    BNE T2_LOOP

    ; 3. Upload Palette Track 3 (VRAM $1FA82..$1FAC1) - Fast Narrow Streams
    LDA #$82
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H

    LDX #$00
T3_LOOP:
    TXA
    CLC
    ADC OFFS_2
    AND #$1F
    ASL
    TAY
    LDA PAL_TRACK3,Y
    STA VERA_DATA0
    INY
    LDA PAL_TRACK3,Y
    STA VERA_DATA0
    INX
    CPX #32
    BNE T3_LOOP

    ; 4. Update Asynchronous Speeds
    ; Track 0 shifts every frame (Speed 1)
    DEC OFFS_0
    LDA OFFS_0
    AND #$1F
    STA OFFS_0

    ; Track 1 shifts every 2nd frame (Speed 0.5)
    INC TICK
    LDA TICK
    AND #$01
    BNE NO_T1_SHIFT
    DEC OFFS_1
    LDA OFFS_1
    AND #$1F
    STA OFFS_1
NO_T1_SHIFT:

    ; Track 2 shifts by 2 units (Speed 2 - Fast rain!)
    LDA OFFS_2
    SEC
    SBC #$02
    AND #$1F
    STA OFFS_2

    ; 5. Live Random Glyph Mutation (Glitch 2 random characters on screen each frame!)
    JSR MUTATE_GLYPH
    JSR MUTATE_GLYPH

    ; Check Keyboard Strobe
    LDA $C000
    BPL NO_KEY
    STA $C010
    ; Restore Applesoft BASIC text SPEED register ($F1) to full speed (255)
    LDA #$FF
    STA $F1
    RTS

NO_KEY:
    ; Super Smooth Cinematic Delay (Slowed by another 20%)
    LDY #$46
DLY1:
    LDX #$FF
DLY2:
    DEX
    BNE DLY2
    DEY
    BNE DLY1
    JMP MAIN_LOOP

; Random Glyph Mutator: rewrites 1 character at random (X, Y)
MUTATE_GLYPH:
    JSR GET_RAND
    AND #$1F            ; Y = 0..31
    STA ROW
    JSR GET_RAND
    AND #$3F            ; X = 0..39
    CMP #40
    BCS NO_MUTATE
    STA COL

    ; Calculate VRAM address
    LDA ROW
    LSR
    STA VERA_ADDR_M
    LDA #$00
    ROR
    STA PTR_L
    LDA COL
    ASL
    CLC
    ADC PTR_L
    STA VERA_ADDR_L
    LDA #$10            ; Stride +1
    STA VERA_ADDR_H

    JSR GET_RAND
    AND #$0F
    BNE MUT_OK
    LDA #$01
MUT_OK:
    STA VERA_DATA0
NO_MUTATE:
    RTS

; LFSR 8-bit Pseudo Random Number Generator
GET_RAND:
    LDA RAND_SEED
    ASL
    BCC NO_EOR
    EOR #$1D
NO_EOR:
    STA RAND_SEED
    RTS

RAND_SEED:
    HEX 5A

; 40 Highly-Randomized Column Stream Track Types (0: Blank gap, 1: Long, 2: Double-head, 3: Fast)
COL_TRACKS:
    HEX 01 02 03 01 00 03 02 01 03 02 01 03 00 01 02 03
    HEX 02 01 03 00 02 01 03 02 01 03 02 00 01 03 02 01
    HEX 03 01 02 00 03 02 01 03

; 40 Randomized Initial Column Phase Offsets (0..31)
COL_OFFSETS:
    HEX 03 17 08 1D 05 12 1F 0A 14 01 1B 0E 06 18 02 15
    HEX 1C 09 13 04 1E 0B 16 00 1A 0D 07 19 03 10 11 0C
    HEX 18 05 1F 02 14 0E 1B 07

; Track 1: Long 16-character dense waterfall with bright white head
PAL_TRACK1:
    HEX 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 00 00
    HEX 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 00 00
    HEX 20 00, 30 00, 40 00, 50 00, 60 00, 70 00, 80 00, 90 00
    HEX A0 00, B0 00, C0 00, D0 00, E0 00, F0 00, FF 0A, FF 0F

; Track 2: Double-Head Medium Streams (2 glowing white heads per column)
PAL_TRACK2:
    HEX 00 00, 00 00, 00 00, 00 00, 30 00, 60 00, 90 00, C0 00
    HEX F0 00, FF 08, FF 0F, 00 00, 00 00, 00 00, 00 00, 00 00
    HEX 00 00, 00 00, 00 00, 00 00, 30 00, 60 00, 90 00, C0 00
    HEX F0 00, FF 08, FF 0F, 00 00, 00 00, 00 00, 00 00, 00 00

; Track 3: Fast Narrow Laser Streams (Short, intense, highly spaced)
PAL_TRACK3:
    HEX 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 00 00
    HEX 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 00 00
    HEX 00 00, 00 00, 00 00, 00 00, 00 00, 00 00, 40 00, 80 00
    HEX A0 00, C0 00, E0 00, F0 00, F0 00, FF 08, FF 0C, FF 0F

; 16 Matrix / Katakana Glyphs (16 tiles x 8 bytes = 128 bytes)
MATRIX_GLYPHS:
    HEX 00 00 00 00 00 00 00 00   ; 0: Blank Space
    HEX 7C 10 10 7C 10 10 10 00   ; 1: + / Kanji 十
    HEX 44 44 7C 44 44 44 44 00   ; 2: H / Katakana
    HEX 3C 42 04 18 20 42 3C 00   ; 3: Z / Katakana
    HEX 00 7E 42 42 7E 40 40 00   ; 4: P
    HEX 18 24 42 7E 42 42 42 00   ; 5: A
    HEX 7E 02 04 18 20 40 7E 00   ; 6: 2
    HEX 3C 66 60 3C 06 66 3C 00   ; 7: S
    HEX 7C 40 40 78 40 40 7C 00   ; 8: E
    HEX 7E 52 52 72 52 52 7E 00   ; 9: 日
    HEX 42 42 42 7E 42 42 42 00   ; 10: 中
    HEX 10 38 54 10 10 10 10 00   ; 11: 木
    HEX 38 44 44 44 44 44 38 00   ; 12: 口
    HEX 7E 18 18 18 18 18 18 00   ; 13: T
    HEX 66 66 66 7E 66 66 66 00   ; 14: 目
    HEX 18 18 7E 18 18 7E 18 00   ; 15: 井

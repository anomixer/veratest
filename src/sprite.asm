; ==============================================================================
; 16-Sprite Hardware Bouncing Animation Demo for Apple II (VERA Card)
; ==============================================================================

* = $2000

START:
    LDA #$00
    STA VERA_CTRL
    LDA #$41            ; Enable VGA (1) + Sprites (0x40)
    STA VERA_DC_VID
    LDA #$40            ; 2x scale (Consistent, crisp, large sprites!)
    STA VERA_DC_HSC
    STA VERA_DC_VSC

    ; Setup Palette at $1FA00: Entry 0 Black, Entry 1 White, Entry 2 Yellow, Entry 3 Cyan
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H
    LDA #$00            ; Entry 0 (Black $0000)
    STA VERA_DATA0
    STA VERA_DATA0
    LDA #$FF            ; Entry 1 (White $0FFF)
    STA VERA_DATA0
    LDA #$0F
    STA VERA_DATA0
    LDA #$F0            ; Entry 2 (Yellow $0FF0)
    STA VERA_DATA0
    LDA #$0F
    STA VERA_DATA0
    LDA #$0F            ; Entry 3 (Cyan $00FF)
    STA VERA_DATA0
    LDA #$00
    STA VERA_DATA0

    ; Init 16 Sprite Attributes at $1FC00
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FC
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H
    LDX #$00
INIT_SPR:
    LDA #$00            ; Shape Address Low ($10000 >> 5 = $0800)
    STA VERA_DATA0
    LDA #$08            ; Shape Address High (4bpp mode)
    STA VERA_DATA0
    LDA SPR_X_LO,X
    STA VERA_DATA0
    LDA SPR_X_HI,X
    STA VERA_DATA0
    LDA SPR_Y_LO,X
    STA VERA_DATA0
    LDA SPR_Y_HI,X
    STA VERA_DATA0
    LDA #$0C            ; Z-depth = 3 (Front)
    STA VERA_DATA0
    LDA #$50            ; Height=16 (1), Width=16 (1), Palette Offset=0
    STA VERA_DATA0
    INX
    CPX #$10            ; 16 Sprites
    BNE INIT_SPR

    ; Upload 16x16 4bpp Sprite Pixels to $10000 (128 bytes)
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H
    LDX #$00
LOAD_SHAPE:
    LDA SPR_PIXELS,X
    STA VERA_DATA0
    INX
    CPX #$80            ; 128 bytes
    BNE LOAD_SHAPE

ANIM_LOOP:
    LDX #$00
UPD_SPRITES:
    ; 1. Update X in RAM
    LDA SPR_X_LO,X
    CLC
    ADC SPEED_X,X
    STA SPR_X_LO,X
    LDA SPR_X_HI,X
    ADC #$00
    STA SPR_X_HI,X
    CMP #$01            ; 320 = $0140
    BCC X_OK
    BNE RST_X
    LDA SPR_X_LO,X
    CMP #$30
    BCC X_OK
RST_X:
    LDA #$00
    STA SPR_X_LO,X
    STA SPR_X_HI,X
X_OK:
    ; 2. Update Y in RAM
    LDA SPR_Y_LO,X
    CLC
    ADC SPEED_Y,X
    STA SPR_Y_LO,X
    CMP #224            ; 240 - 16 = 224 ($E0)
    BCC Y_OK
RST_Y:
    LDA #$00
    STA SPR_Y_LO,X
Y_OK:
    ; 3. Atomically write X and Y to VERA Sprite Attributes
    TXA
    ASL
    ASL
    ASL
    CLC
    ADC #$02            ; Offset 2 = X_LO
    STA VERA_ADDR_L
    LDA #$FC
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H
    LDA SPR_X_LO,X
    STA VERA_DATA0
    LDA SPR_X_HI,X
    STA VERA_DATA0
    LDA SPR_Y_LO,X
    STA VERA_DATA0
    LDA #$00
    STA VERA_DATA0
    INX
    CPX #$10
    BNE UPD_SPRITES

    ; Check Keyboard Strobe at $C000
    LDA $C000
    BPL NO_KEY
    STA $C010
    RTS

NO_KEY:
    LDY #$20
DLY1:
    LDX #$FF
DLY2:
    DEX
    BNE DLY2
    DEY
    BNE DLY1
    JMP ANIM_LOOP

; 128 bytes for 16x16 4bpp Crystal Alien Sprite
SPR_PIXELS:
    HEX 00 00 00 11 11 00 00 00
    HEX 00 00 11 22 22 11 00 00
    HEX 00 11 22 33 33 22 11 00
    HEX 01 22 33 11 11 33 22 10
    HEX 12 33 11 22 22 11 33 21
    HEX 12 31 22 11 11 22 13 21
    HEX 12 31 22 11 11 22 13 21
    HEX 12 33 11 22 22 11 33 21
    HEX 12 33 11 22 22 11 33 21
    HEX 01 22 33 11 11 33 22 10
    HEX 00 11 22 33 33 22 11 00
    HEX 00 00 11 22 22 11 00 00
    HEX 00 01 20 00 00 02 10 00
    HEX 00 12 00 00 00 00 21 00
    HEX 01 20 00 00 00 00 02 10
    HEX 12 00 00 00 00 00 00 21

; Dispersed starting coordinates across 320x240 screen
SPR_X_LO:
    HEX 20 60 A0 E0 20 60 A0 E0 10 50 90 D0 30 70 B0 F0
SPR_X_HI:
    HEX 00 00 00 00 01 01 01 01 00 00 00 00 01 01 01 01
SPR_Y_LO:
    HEX 10 40 70 A0 D0 20 50 80 B0 E0 30 60 90 C0 15 45
SPR_Y_HI:
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
SPEED_X:
    HEX 02 03 01 02 03 01 02 04 03 01 02 03 02 01 03 02
SPEED_Y:
    HEX 01 02 03 01 02 04 02 01 03 02 01 02 03 01 02 03

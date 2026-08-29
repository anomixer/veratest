; ==============================================================================
; Mode 7 256-Color Fullscreen Bitmap + Instant 6502 RLE Decompressor for Apple II
; ==============================================================================

* = $2000

RLE_PTR_L    = $EB
RLE_PTR_H    = $EC
COUNT        = $ED

START:
    LDA #$00
    STA VERA_CTRL
    LDA #$11            ; VGA output + Layer 0 Enable
    STA VERA_DC_VID
    LDA #$40            ; 2x scale (320x240 stretched to 640x480)
    STA VERA_DC_HSC
    STA VERA_DC_VSC
    LDA #$07            ; 8bpp Bitmap Mode
    STA VERA_L0_CFG
    LDA #$00
    STA VERA_L0_MAP
    STA VERA_L0_TIL
    STA VERA_L0_HSC_L
    STA VERA_L0_HSC_H
    STA VERA_L0_VSC_L
    STA VERA_L0_VSC_H

    ; Setup Authentic Rainbow Palette at $1FA00
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H
    LDX #$00
LOAD_PAL:
    LDA PALETTE_DATA,X
    STA VERA_DATA0
    INX
    CPX #$20
    BNE LOAD_PAL

    ; Point VERA to VRAM $00000
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$10            ; Stride +1
    STA VERA_ADDR_H

    ; Setup RLE Pointer
    LDA #<RLE_IMAGE_DATA
    STA RLE_PTR_L
    LDA #>RLE_IMAGE_DATA
    STA RLE_PTR_H

    ; Instant RLE Decompressor
DECOMPRESS_LOOP:
    LDY #$00
    LDA (RLE_PTR_L),Y   ; Read Count
    BEQ DONE_DRAWING    ; Count 0 = End
    STA COUNT
    INY
    LDA (RLE_PTR_L),Y   ; Read Color
    LDX COUNT
EMIT_PIXELS:
    STA VERA_DATA0
    DEX
    BNE EMIT_PIXELS

    ; Advance Pointer by 2
    LDA RLE_PTR_L
    CLC
    ADC #$02
    STA RLE_PTR_L
    LDA RLE_PTR_H
    ADC #$00
    STA RLE_PTR_H
    JMP DECOMPRESS_LOOP

DONE_DRAWING:
    RTS                 ; Finished drawing instantly! Return straight to BASIC menu

; Palette: 0:Black, 1:SkyBlue, 2:Red, 3:Orange, 4:Yellow, 5:Green, 6:Blue, 7:Indigo, 8:Violet, 9:Grass
; Little-Endian 12-bit RGB: Byte 0: [G4 B4], Byte 1: [0 R4]
PALETTE_DATA:
    HEX 00 00 6A 02 00 0F 80 0F E0 0F E0 00 8F 00 0C 02
    HEX 08 08 40 01 00 00 00 00 00 00 00 00 00 00 00 00

RLE_IMAGE_DATA:

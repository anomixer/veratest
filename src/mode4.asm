; ==============================================================================
; Mode 4 256-Color RPG Tilemap Engine Demo for Apple II (VERA Card)
; ==============================================================================

* = $2000

PTR_L   = $EB
PTR_H   = $EC
SCROLL_L= $ED
SCROLL_H= $EE
DIR     = $EF

START:
    LDA #$00
    STA VERA_CTRL
    LDA #$11            ; Enable VGA (1) + Layer 0 (0x10)
    STA VERA_DC_VID
    LDA #$40            ; 2.0x scale (320x240 crisp view)
    STA VERA_DC_HSC
    STA VERA_DC_VSC

    ; 1. Load 256-Color Palette to VRAM $1FA00 (512 bytes)
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H

    LDA #<PALETTE_DATA
    STA PTR_L
    LDA #>PALETTE_DATA
    STA PTR_H
    LDX #$02            ; 2 * 256 = 512 bytes
    LDY #$00
LOAD_PAL:
    LDA (PTR_L),Y
    STA VERA_DATA0
    INY
    BNE LOAD_PAL
    INC PTR_H
    DEX
    BNE LOAD_PAL

    ; 2. Clear entire Tilemap VRAM $00000..$00FFF (4096 bytes) with grass tile
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$10            ; Bank 0, Stride +1
    STA VERA_ADDR_H

    LDX #$10            ; 16 * 256 = 4096 bytes
    LDY #$00
CLR_MAP:
    LDA #$00            ; Base grass tile
    STA VERA_DATA0
    LDA #$00            ; Attributes
    STA VERA_DATA0
    INY
    BNE CLR_MAP
    DEX
    BNE CLR_MAP

    ; 3. Load Tilemap (2048 bytes) into VRAM $00300 (Offset by 6 rows to center the castle!)
    LDA #$00
    STA VERA_ADDR_L
    LDA #$03            ; Row 6 offset = $0300
    STA VERA_ADDR_M
    LDA #$10
    STA VERA_ADDR_H

    LDA #<TILEMAP_DATA
    STA PTR_L
    LDA #>TILEMAP_DATA
    STA PTR_H
    LDX #$08            ; 8 * 256 = 2048 bytes
    LDY #$00
LOAD_MAP:
    LDA (PTR_L),Y
    STA VERA_DATA0
    INY
    BNE LOAD_MAP
    INC PTR_H
    DEX
    BNE LOAD_MAP

    ; 4. Load Tile Graphics (3584 bytes = 56 tiles) to VRAM $10000 (8bpp, 8x8 tiles)
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1
    STA VERA_ADDR_H

    LDA #<TILES_DATA
    STA PTR_L
    LDA #>TILES_DATA
    STA PTR_H
    LDX #$0E            ; 14 * 256 = 3584 bytes
    LDY #$00
LOAD_TILES:
    LDA (PTR_L),Y
    STA VERA_DATA0
    INY
    BNE LOAD_TILES
    INC PTR_H
    DEX
    BNE LOAD_TILES

    ; 5. Configure Layer 0:
    LDA #$13            ; 8bpp color depth
    STA VERA_L0_CFG
    LDA #$00            ; Map Base: $00000
    STA VERA_L0_MAP
    LDA #$80            ; Tile Base: $10000 >> 9 = $80 (8x8 tiles)
    STA VERA_L0_TIL

    LDA #$00
    STA SCROLL_L
    STA SCROLL_H
    STA DIR
    STA VERA_L0_HSC_L
    STA VERA_L0_HSC_H
    STA VERA_L0_VSC_L
    STA VERA_L0_VSC_H

SCROLL_LOOP:
    ; Smooth pan back and forth (0..350 pixels)
    LDA DIR
    BNE SCROLL_LEFT

    ; Scrolling Right
    INC SCROLL_L
    BNE CHK_MAX
    INC SCROLL_H
CHK_MAX:
    LDA SCROLL_H
    CMP #$01
    BCC UPD_HW
    LDA SCROLL_L
    CMP #$60            ; 352 pixels
    BCC UPD_HW
    LDA #$01
    STA DIR
    JMP UPD_HW

SCROLL_LEFT:
    LDA SCROLL_L
    BNE DEC_L
    DEC SCROLL_H
DEC_L:
    DEC SCROLL_L
    LDA SCROLL_H
    BNE UPD_HW
    LDA SCROLL_L
    BNE UPD_HW
    LDA #$00
    STA DIR

UPD_HW:
    LDA SCROLL_L
    STA VERA_L0_HSC_L
    LDA SCROLL_H
    STA VERA_L0_HSC_H

    ; Check Keyboard Strobe at $C000
    LDA $C000
    BPL NO_KEY
    STA $C010
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
    JMP SCROLL_LOOP

PALETTE_DATA:
TILEMAP_DATA = PALETTE_DATA + 512
TILES_DATA   = TILEMAP_DATA + 2048

; ==============================================================================
; VERA (Versatile Embedded Retro Adapter) Hardware Definitions for Apple II
; ==============================================================================

; Slot base addresses in Apple II Slot I/O / ROM space
; Slot 2: $C200 / Slot 4: $C400 (Default: VERA_BASE defined by assembler)

VERA_ADDR_L   = VERA_BASE + $00  ; VRAM Address [7:0]
VERA_ADDR_M   = VERA_BASE + $01  ; VRAM Address [15:8]
VERA_ADDR_H   = VERA_BASE + $02  ; VRAM Address [19:16] & Stride/Decr
VERA_DATA0    = VERA_BASE + $03  ; Data Port 0 (Auto-increment)
VERA_DATA1    = VERA_BASE + $04  ; Data Port 1
VERA_CTRL     = VERA_BASE + $05  ; Control (Bit 0=Port Select, Bit 7=Reset)
VERA_IEN      = VERA_BASE + $06  ; Interrupt Enable
VERA_ISR      = VERA_BASE + $07  ; Interrupt Status
VERA_IRQ_L    = VERA_BASE + $08  ; Scanline IRQ Target [7:0]
VERA_DC_VID   = VERA_BASE + $09  ; Display Composer Video Control
VERA_DC_HSC   = VERA_BASE + $0A  ; Display Composer H-Scale (128=1.0x, 64=2.0x)
VERA_DC_VSC   = VERA_BASE + $0B  ; Display Composer V-Scale (128=1.0x, 64=2.0x)
VERA_DC_BOR   = VERA_BASE + $0C  ; Border Color Index
VERA_L0_CFG   = VERA_BASE + $0D  ; Layer 0 Config & Color Mode
VERA_L0_MAP   = VERA_BASE + $0E  ; Layer 0 Tilemap Base Address
VERA_L0_TIL   = VERA_BASE + $0F  ; Layer 0 Tile/Bitmap Base Address
VERA_L0_HSC_L = VERA_BASE + $10  ; Layer 0 H-Scroll Low
VERA_L0_HSC_H = VERA_BASE + $11  ; Layer 0 H-Scroll High
VERA_L0_VSC_L = VERA_BASE + $12  ; Layer 0 V-Scroll Low
VERA_L0_VSC_H = VERA_BASE + $13  ; Layer 0 V-Scroll High

; Apple II Hardware Softswitches
KBD_DATA      = $C000            ; Read Keyboard Data (Bit 7 = Key pressed)
KBD_STROBE    = $C010            ; Clear Keyboard Strobe

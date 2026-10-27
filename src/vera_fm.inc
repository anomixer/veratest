; ==============================================================================
; YM2151 (Yamaha OPM) FM Chip Support
; ==============================================================================
;
; The optional YM2151 uses /DEVICE SELECT, separate from VERA Cx registers.
; YM_SEL/YM_DATA are $C0A0/$C0A1 in Slot 2, $C0C0/$C0C1 in Slot 4.
; Detection checks a bounded BUSY transition; absent FM is floating-bus I/O.
;
; The including source must define these zero page locations beforehand:
;   FM_PRESENT : 0 = no FM chip, 1 = YM2151 detected & initialised
;   FM_KEYS    : 8 bytes, last $08 (key on/off) value written per YM channel
;
; All routines are safe to call when no FM chip is present: they simply
; return without touching the YM2151 ports.
; ==============================================================================

YM_KEY_REG = $08                  ; YM2151 key on/off register (ch bits 0..2, opmask bits 3..6)

; ------------------------------------------------------------------------------
; Shared with the inline machine-code probe in both BASIC launchers.
include "vera_fm_detect.inc"

; ------------------------------------------------------------------------------
; Silence the FM chip and reset every tone register to zero.
; This matches the converter's assumption that all YM2151 registers ($20..$FF)
; start at zero, which is what makes the duplicate-write compression valid.
; ------------------------------------------------------------------------------
VERA_FM_RESET:
    LDA FM_PRESENT
    BEQ VERA_FM_RESET_DONE
    JSR VERA_FM_KEY_OFF_ALL
    LDX #$20
VERA_FM_RESET_LOOP:
    STX YM_SEL
    LDA #$00
    STA YM_DATA
    INX
    BNE VERA_FM_RESET_LOOP
    LDX #$00
VERA_FM_CLEAR_KEYS:
    LDA #$00
    STA FM_KEYS,X
    INX
    CPX #$08
    BCC VERA_FM_CLEAR_KEYS
VERA_FM_RESET_DONE:
    RTS

; ------------------------------------------------------------------------------
; Key off all eight FM channels (used when muting and when leaving a demo).
; ------------------------------------------------------------------------------
VERA_FM_KEY_OFF_ALL:
    LDA FM_PRESENT
    BEQ VERA_FM_KEY_OFF_DONE
    LDX #$00
VERA_FM_KEY_OFF_LOOP:
    LDA #YM_KEY_REG
    STA YM_SEL
    STX YM_DATA                   ; opmask 0 = key off, channel = X
    INX
    CPX #$08
    BCC VERA_FM_KEY_OFF_LOOP
VERA_FM_KEY_OFF_DONE:
    RTS

; ------------------------------------------------------------------------------
; Re-apply the tracked $08 values after a mute, so sustained FM notes resume
; instead of being permanently silenced by VERA_FM_KEY_OFF_ALL.
; ------------------------------------------------------------------------------
VERA_FM_RESTORE_KEYS:
    LDA FM_PRESENT
    BEQ VERA_FM_RESTORE_DONE
    LDX #$00
VERA_FM_RESTORE_LOOP:
    LDA #YM_KEY_REG
    STA YM_SEL
    LDA FM_KEYS,X
    STA YM_DATA
    INX
    CPX #$08
    BCC VERA_FM_RESTORE_LOOP
VERA_FM_RESTORE_DONE:
    RTS

; ------------------------------------------------------------------------------
; Write one YM2151 register pair: A = register, X = value.
; Also updates FM_KEYS when the key register is written.
; ------------------------------------------------------------------------------
VERA_FM_WRITE:
    STA YM_SEL
    CMP #YM_KEY_REG
    BNE VERA_FM_WRITE_DATA
    TXA
    PHA
    AND #$07
    TAY
    PLA
    STA FM_KEYS,Y
VERA_FM_WRITE_DATA:
    TXA
    STA YM_DATA
    RTS

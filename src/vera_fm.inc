; ==============================================================================
; YM2151 (Yamaha OPM) FM Chip Support
; ==============================================================================
;
; The VERA card decodes an optional YM2151 FM chip at
; $Cs20 (YM_REG, write only) and $Cs21 (YM_DATA write / status read).  When the
; FM chip is absent (or the card's FM option is disabled) those two
; addresses simply alias VERA_ADDR_L / VERA_ADDR_M, which is exactly what the
; detection routine below exploits.
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
; Detect the FM chip.
; Writes a known pattern into VERA_ADDR_L/M and reads it back through the two
; YM2151 offsets: an FM card returns 0 / status (never the written pattern),
; while a card without FM returns the aliased VERA address bytes.
; VERA_ADDR_L/M are restored, so the foreground VRAM pointer is untouched.
; ------------------------------------------------------------------------------
VERA_FM_DETECT:
    LDA VERA_ADDR_L
    PHA
    LDA VERA_ADDR_M
    PHA
    LDA #$5A
    STA VERA_ADDR_L
    LDA #$A5
    STA VERA_ADDR_M
    LDA YM_REG                    ; $Cs20: 0 with FM, $5A address alias without
    CMP #$5A
    BNE VERA_FM_FOUND
    LDA YM_DATA                   ; $Cs21: status with FM, $A5 alias without
    CMP #$A5
    BNE VERA_FM_FOUND
    LDA #$00
    STA FM_PRESENT
    JMP VERA_FM_RESTORE_ADDR
VERA_FM_FOUND:
    LDA #$01
    STA FM_PRESENT
VERA_FM_RESTORE_ADDR:
    PLA
    STA VERA_ADDR_M
    PLA
    STA VERA_ADDR_L
    RTS

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
    STX YM_REG
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
    STA YM_REG
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
    STA YM_REG
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
    STA YM_REG
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

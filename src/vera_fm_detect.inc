; YM2151 /DEVICE SELECT probe (AI-assisted implementation, 2026-10-27).
; Check BUSY after clearing timer flags, then require BUSY to clear within a
; bounded wait. Reserved status bits must stay zero. No VERA pointer changes.
; FM_PRESENT is supplied by the caller. Clobbers A/X/Y, preserves stack.
VERA_FM_DETECT:
    LDA #$00
    STA FM_PRESENT
    LDX #$00
    LDY #$00
VERA_FM_WAIT_IDLE:
    LDA YM_DATA
    AND #$7C
    BNE VERA_FM_DETECT_DONE
    LDA YM_DATA
    BPL VERA_FM_TEST_BUSY
    DEX
    BNE VERA_FM_WAIT_IDLE
    DEY
    BNE VERA_FM_WAIT_IDLE
    RTS
VERA_FM_TEST_BUSY:
    LDA #$14
    STA YM_SEL
    LDA #$30
    STA YM_DATA
    LDA YM_DATA
    CMP #$80
    BNE VERA_FM_DETECT_DONE
    LDX #$00
    LDY #$00
VERA_FM_WAIT_READY:
    LDA YM_DATA
    BEQ VERA_FM_FOUND
    CMP #$80
    BNE VERA_FM_DETECT_DONE
    DEX
    BNE VERA_FM_WAIT_READY
    DEY
    BNE VERA_FM_WAIT_READY
    RTS
VERA_FM_FOUND:
    LDA #$01
    STA FM_PRESENT
VERA_FM_DETECT_DONE:
    RTS

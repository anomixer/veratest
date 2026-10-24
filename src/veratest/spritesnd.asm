; ==============================================================================
; 16-Sprite Demo WITH Rich 4-Voice Stereo VERA PSG Chiptune Music for Apple II
; Plus an optional YM2151 FM daughterboard layer (lead + bass) when fitted.
; ==============================================================================

* = $2000

FM_PRESENT = $EE        ; 1 = YM2151 FM daughterboard detected
FM_CH      = $EF        ; YM2151 channel currently being programmed
FM_KEYS    = $4800      ; Last $08 (key on/off) value per FM channel

START:
    LDA #$00
    STA VERA_CTRL       ; Port 0, DCSEL = 0
    STA VERA_DC_VID     ; Blank video during initialization
    STA VERA_DC_BOR     ; Border color = 0
    STA VERA_L0_CFG     ; Disable Layer 0
    STA VERA_L1_CFG     ; Disable Layer 1
    LDA #$40            ; 2x scale
    STA VERA_DC_HSC
    STA VERA_DC_VSC

    ; --------------------------------------------------------------------------
    ; 1. Completely Wipe VERA Video RAM (128 KB: Bank 0 and Bank 1)
    ;    - Clears all 128 sprite attributes ($1FC00..$1FFFF) -> Z-depth = 0
    ;    - Clears all 256 palette entries ($1FA00..$1FBFF)
    ;    - Clears all 16 PSG sound registers ($1F9C0..$1F9FF)
    ;    - Clears all residual tilemaps, bitmaps, and sprite pixel patterns
    ; --------------------------------------------------------------------------
    ; Wipe Bank 0 ($00000..$0FFFF, 64 KB)
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$10            ; Stride +1, Bank 0
    STA VERA_ADDR_H
    JSR CLR_64K

    ; Wipe Bank 1 ($10000..$1FFFF, 64 KB)
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1, Bank 1
    STA VERA_ADDR_H
    JSR CLR_64K

    ; Setup Palette at $1FA00
    LDA #$00
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H
    LDA #$00            ; Entry 0 (Black)
    STA VERA_DATA0
    STA VERA_DATA0
    LDA #$FF            ; Entry 1 (White)
    STA VERA_DATA0
    LDA #$0F
    STA VERA_DATA0
    LDA #$F0            ; Entry 2 (Yellow)
    STA VERA_DATA0
    LDA #$0F
    STA VERA_DATA0
    LDA #$0F            ; Entry 3 (Cyan)
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
    LDA #$00            ; Shape Address Low
    STA VERA_DATA0
    LDA #$08            ; Shape Address High
    STA VERA_DATA0
    LDA SPR_X_LO,X
    STA VERA_DATA0
    LDA SPR_X_HI,X
    STA VERA_DATA0
    LDA SPR_Y_LO,X
    STA VERA_DATA0
    LDA #$00
    STA VERA_DATA0
    LDA #$0C            ; Z-depth 3 (front)
    STA VERA_DATA0
    LDA #$50            ; 16x16 size
    STA VERA_DATA0
    INX
    CPX #$10
    BNE INIT_SPR

    ; Upload Sprite Pixel Data to VRAM $10000
    LDA #$00
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H
    LDX #$00
LOAD_PX:
    LDA SPR_PIXELS,X
    STA VERA_DATA0
    INX
    CPX #$80            ; 128 bytes
    BNE LOAD_PX

    ; Initialize Music Engine state in Zero Page
    LDA #$00
    STA $EB             ; Current Step (0..31)
    LDA #$01
    STA $EC             ; Tick Timer
    LDA #$3F
    STA $ED             ; Master Lead Volume Envelope

    ; Detect the optional YM2151 FM daughterboard. When it is fitted, the demo
    ; adds the FM drum voices on top of the PSG arrangement; without it only the
    ; PSG voices play.
    JSR VERA_FM_DETECT
    JSR VERA_FM_RESET
    LDA #$00
    STA FM_KICK_IDX     ; no kick pitch dive running
    LDA FM_PRESENT
    BEQ FM_NO_PATCH
    JSR FM_LOAD_PATCH
FM_NO_PATCH:

    ; Enable VGA output (1) + Sprites (0x40) -> $41
    LDA #$41
    STA VERA_DC_VID

ANIM_LOOP:
    ; 1. Advance Music Clock & Envelope
    DEC $EC
    BEQ NOTE_TICK
    JMP TICK_ENV
NOTE_TICK:
    LDA #$05            ; Note duration (tempo)
    STA $EC
    LDA #$3F
    STA $ED             ; Reset volume envelope
    LDY $EB

    ; Set VERA VRAM address to PSG Channel 0 at $1F9C0
    LDA #$C0
    STA VERA_ADDR_L
    LDA #$F9
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1
    STA VERA_ADDR_H

    ; Voice 1 (Left Stereo Lead Melody - Pulse 25%)
    LDA LEAD_LO,Y
    STA VERA_DATA0
    LDA LEAD_HI,Y
    STA VERA_DATA0
    LDA #$7F            ; Left pan, max vol
    STA VERA_DATA0
    LDA #$10            ; Pulse wave 25% duty
    STA VERA_DATA0

    ; Voice 2 (Right Stereo Counter Melody - Sawtooth / Pulse)
    LDA HARM_LO,Y
    STA VERA_DATA0
    LDA HARM_HI,Y
    STA VERA_DATA0
    LDA #$BB            ; Right pan, rich vol
    STA VERA_DATA0
    LDA #$40            ; Sawtooth wave
    STA VERA_DATA0

    ; Voice 3 (Center Deep Punchy Bass - Triangle)
    LDA BASS_LO,Y
    STA VERA_DATA0
    LDA BASS_HI,Y
    STA VERA_DATA0
    LDA #$FE            ; Full stereo, punchy vol
    STA VERA_DATA0
    LDA #$80            ; Triangle wave
    STA VERA_DATA0

    ; Voice 4 (Center Percussion Kick/Snare/Hihat - Noise/Pulse)
    LDA DRUM_FRQ,Y
    STA VERA_DATA0
    LDA #$02
    STA VERA_DATA0
    LDA DRUM_VOL,Y
    STA VERA_DATA0
    LDA DRUM_WAV,Y      ; Noise or low thump
    STA VERA_DATA0

    ; FM layer: retrigger the FM lead/bass voices for this same step
    JSR FM_STEP

    INY
    CPY #$20            ; 32-step rich melody loop
    BNE STEP_OK
    LDY #$00
STEP_OK:
    STY $EB
    JMP SPRITE_UPDATE

TICK_ENV:
    ; FM kick: continue the SB-INTRO pitch dive once per video frame.
    JSR FM_DRUM_TICK

    ; Decay Lead volume envelope for natural attack/release
    LDA $ED
    SEC
    SBC #$06
    BCS VOL_OK
    LDA #$00
VOL_OK:
    STA $ED
    ORA #$40            ; Keep Left pan bit
    TAX                 ; Hold the new volume in X
    ; Write it to PSG voice 0 volume ($1F9C2) through data port 0. The old code
    ; used VERA_DATA1 without selecting port 1, so the decay silently landed at
    ; VRAM $00000 and the lead never faded.
    LDA #$C2
    STA VERA_ADDR_L
    LDA #$F9
    STA VERA_ADDR_M
    LDA #$01            ; Bank 1, Stride +1
    STA VERA_ADDR_H
    TXA
    STA VERA_DATA0

SPRITE_UPDATE:
    ; 2. Update 16 Sprites in RAM
    LDX #$00
UPD_SPRITES:
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
    LDA SPR_Y_LO,X
    CLC
    ADC SPEED_Y,X
    STA SPR_Y_LO,X
    CMP #224
    BCC Y_OK
RST_Y:
    LDA #$00
    STA SPR_Y_LO,X
Y_OK:
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

    ; Silence all 4 PSG Voices before returning
    LDA #$C0
    STA VERA_ADDR_L
    LDA #$F9
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H
    LDA #$00
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0       ; V1 vol = 0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0       ; V2 vol = 0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0       ; V3 vol = 0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0       ; V4 vol = 0
    STA VERA_DATA0

    ; Key off every FM channel so no lead/bass note hangs after we leave
    JSR VERA_FM_KEY_OFF_ALL

    LDA #$00
    STA VERA_DC_VID     ; Disable VERA display (switches AppleWin back to Apple II text mode)
    RTS
NO_KEY:
    LDY #$14
DLY1:
    LDX #$FF
DLY2:
    DEX
    BNE DLY2
    DEY
    BNE DLY1
    JMP ANIM_LOOP

; ==============================================================================
; YM2151 FM Daughterboard Layer (optional hardware)
; Only percussion runs on the FM chip (channels 2 and 3). Channels 0 and 1 are
; deliberately left silent: the PSG already plays the lead and the bass, and an
; FM copy of them read as a detuned double instead of a harmony.
; ==============================================================================
.include "../vera_fm.inc"

; ------------------------------------------------------------------------------
; Program the two SFX/drum patches used by the beat.
; ------------------------------------------------------------------------------
FM_LOAD_PATCH:
    LDA #$02
    JSR FM_APPLY_KICK
    LDA #$03
    JSR FM_APPLY_SNARE
    RTS

; Percussion patches copied from SB-INTRO's own FM drum channels. Channel 2 is
; the slideshow's kick voice, channel 3 its snare/hat voice; the register values
; are exactly the ones the soundtrack's tracker writes (see FM_KICK_VALS and
; FM_SNARE_VALS below), so demo 2 sounds like the slideshow instead of like a
; synthetic beep.
FM_APPLY_KICK:
    STA FM_CH
    LDX #$00
FM_KICK_PATCH_LOOP:
    LDA FM_PATCH_REGS,X
    CLC
    ADC FM_CH
    STA YM_REG
    LDA FM_KICK_VALS,X
    STA YM_DATA
    INX
    CPX #FM_PATCH_LEN
    BNE FM_KICK_PATCH_LOOP
    RTS

FM_APPLY_SNARE:
    STA FM_CH
    LDX #$00
FM_SNARE_PATCH_LOOP:
    LDA FM_PATCH_REGS,X
    CLC
    ADC FM_CH
    STA YM_REG
    LDA FM_SNARE_VALS,X
    STA YM_DATA
    INX
    CPX #FM_PATCH_LEN
    BNE FM_SNARE_PATCH_LOOP
    RTS

; ------------------------------------------------------------------------------
; Trigger the FM drum voices for the current step (Y = step index).
; Channels 0 and 1 stay silent on purpose — the PSG lead and bass are the only
; melody voices; doubling them on the FM chip sounded like a detuned second
; player, not like the soundtrack.
; ------------------------------------------------------------------------------
FM_STEP:
    TYA
    PHA
    LDA FM_PRESENT
    BEQ FM_STEP_EXIT
    ; --- Percussion -> FM channels 2 (kick) and 3 (snare), using the slideshow
    ; soundtrack's own drum voices. The PSG drum tables already say which steps
    ; are a kick ($00 pulse wave) and which are noise (snare/hat), so the FM
    ; drums follow the same grid; the key codes, key fractions and the kick's
    ; six-frame downward pitch dive are the values SB-INTRO.ZSM writes to its
    ; channel 2, so the beat sounds like the slideshow rather than a beep.
    LDY $EB
    LDA DRUM_WAV,Y
    CMP #$C0
    BEQ FM_SNARE_HIT
    LDA DRUM_VOL,Y
    BEQ FM_STEP_EXIT      ; silent step (last step of the loop)
    LDA #YM_KEY_REG
    LDX #$02              ; release channel 2 first (mask 0), like SB-INTRO
    JSR VERA_FM_WRITE
    LDX #$32              ; kick attack pitch (155 Hz key code)
    LDA #$2A              ; KC, channel 2
    JSR VERA_FM_WRITE
    LDX #$68              ; matching key fraction
    LDA #$32              ; KF, channel 2
    JSR VERA_FM_WRITE
    LDA #YM_KEY_REG
    LDX #$7A              ; key on all four operators of channel 2
    JSR VERA_FM_WRITE
    LDA #$01
    STA FM_KICK_IDX       ; the sweep continues on the next video frames
    JMP FM_STEP_EXIT
FM_SNARE_HIT:
    LDA #YM_KEY_REG
    LDX #$03              ; release channel 3 first
    JSR VERA_FM_WRITE
    LDX #$6E              ; fixed snare/hat pitch used by SB-INTRO
    LDA #$2B              ; KC, channel 3
    JSR VERA_FM_WRITE
    LDX #$00
    LDA #$33              ; KF, channel 3
    JSR VERA_FM_WRITE
    LDA #YM_KEY_REG
    LDX #$7B              ; key on channel 3
    JSR VERA_FM_WRITE

FM_STEP_EXIT:
    PLA
    TAY
    RTS

; ------------------------------------------------------------------------------
; Advance the kick's pitch dive one video frame. SB-INTRO walks channel 2's key
; code 32 -> 2A -> 22 -> 1A -> 12 -> 0A -> 02 and its key fraction 68 -> C8 over
; six ticks after the key-on, which is what turns a static tone into a thump.
; FM_KICK_IDX holds the next table entry (1..6); 0 means no sweep is running.
; ------------------------------------------------------------------------------
FM_DRUM_TICK:
    LDA FM_PRESENT
    BEQ FM_DRUM_TICK_DONE
    LDX FM_KICK_IDX
    BEQ FM_DRUM_TICK_DONE
    LDA DRUM_KC,X
    TAX
    LDA #$2A              ; KC, channel 2
    JSR VERA_FM_WRITE
    LDX FM_KICK_IDX
    LDA DRUM_KF,X
    TAX
    LDA #$32              ; KF, channel 2
    JSR VERA_FM_WRITE
    LDX FM_KICK_IDX
    INX
    CPX #$07
    BNE FM_KICK_IDX_STORE
    LDX #$00              ; dive finished
FM_KICK_IDX_STORE:
    STX FM_KICK_IDX
FM_DRUM_TICK_DONE:
    RTS

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

; 32-Step Arcade Chiptune Tables (Lead + Harmony + Slap Bass + Drum Section)
LEAD_LO:
    HEX BE 75 1C 7D 7D 1C 75 14 BE 75 1C 9D 9D 1C 75 14
    HEX BE BE 14 75 1C 1C 9D 7D 7D 1C 9D 1C 75 14 BE 00
LEAD_HI:
    HEX 02 03 04 05 05 04 03 03 02 03 04 04 04 04 03 03
    HEX 02 02 03 03 04 04 04 05 05 04 04 04 03 03 02 00
HARM_LO:
    HEX 5F 1C 9D 1C 1C 9D 1C 75 5F 1C 9D 7D 7D 9D 1C 75
    HEX 5F 5F 75 1C 9D 9D 7D 1C 1C 9D 7D 9D 1C 75 5F 00
HARM_HI:
    HEX 01 04 04 04 04 04 04 03 01 04 04 05 05 04 04 03
    HEX 01 01 03 04 04 04 05 04 04 04 05 04 04 03 01 00
BASS_LO:
    HEX 5F BE 5F BE 0E 1C 0E 1C 4F 9D 4F 9D 8D 14 8D 14
    HEX 5F BE 5F BE 0E 1C 0E 1C 8D 14 0E 1C 5F BE 5F 00
BASS_HI:
    HEX 01 02 01 02 02 04 02 04 02 04 02 04 01 03 01 03
    HEX 01 02 01 02 02 04 02 04 01 03 02 04 01 02 01 00
DRUM_FRQ:
    HEX 40 80 40 A0 40 80 40 A0 40 80 40 A0 40 A0 40 A0
    HEX 40 80 40 A0 40 80 40 A0 40 A0 40 A0 40 40 40 00
DRUM_VOL:
    HEX FF 60 FF E0 FF 60 FF E0 FF 60 FF E0 FF E0 FF E0
    HEX FF 60 FF E0 FF 60 FF E0 FF E0 FF E0 FF FF FF 00
DRUM_WAV:
    HEX 00 C0 00 C0 00 C0 00 C0 00 C0 00 C0 00 C0 00 C0
    HEX 00 C0 00 C0 00 C0 00 C0 00 C0 00 C0 00 00 00 00

; YM2151 register list shared by both drum patches (registers relative to the
; channel; the player adds the channel number):
;   $20 : pan / feedback / algorithm
;   $40 : DT/MULT  (operators 0..3)
;   $60 : TL       (0 = loudest, 0.75 dB per step)
;   $80 : KSR/AR
;   $A0 : AMS/DR
;   $C0 : DT2/SR
;   $E0 : SL/RR
FM_PATCH_LEN = 25
FM_PATCH_REGS:
    HEX 20
    HEX 40 48 50 58
    HEX 60 68 70 78
    HEX 80 88 90 98
    HEX A0 A8 B0 B8
    HEX C0 C8 D0 D8
    HEX E0 E8 F0 F8

; FM kick (channel 2), same register list as above. Every value below is the one
; SB-INTRO.ZSM writes to its own kick channel, so the drum is the slideshow's:
;   $20 = $F8  pan both, feedback 7, algorithm 0 (4-operator series)
;   $40 = $0F  op0 detune 0 / MULT 15, $48 = MULT 2, $50 = MULT 3, $58 = MULT 1
;   $60 = TL $00/$00/$00/$04, $80 = AR 31 ($98 = 23 on the carrier)
;         (SB-INTRO uses $18 on the carrier, i.e. -18 dB; that is mixed for a
;         soundtrack with quiet PSG, here it vanished under the PSG drums, so the
;         carrier is raised to $04 = -3 dB. Everything else is the soundtrack's.)
;   $A0 = DR 0/24/0/13, $C0 = SR 0/11/0/0
;   $E0 = $F0/$BF/$FF/$FF — SL 15 / RR 0, i.e. the pitch dive (see FM_DRUM_TICK)
;         shapes the thump, exactly as in the soundtrack.
FM_KICK_VALS:
    HEX F8
    HEX 0F 02 03 01
    HEX 00 00 00 04
    HEX 1F 1F 1F 17
    HEX 00 18 00 0D
    HEX 00 0B 00 00
    HEX F0 BF FF FF

; FM snare/hat (channel 3), again the register values SB-INTRO.ZSM writes:
;   $20 = $FC  pan both, feedback 7, algorithm 4
;   $40 = $25  detune 2 / MULT 5, $48 = MULT 5, $50/$58 = detune -1 / MULT 4
;   $60 = TL $00/$18/$16/$0A (SB-INTRO's $2E/$2B/$1F raised the same way as the
;         kick carrier, otherwise the snare was below the PSG noise), $80 = AR 31
;   $A0 = DR 0/0/13/13, $C0 = SR 4/31/12/12
;   $E0 = SL 15/RR 3, SL 15/RR 1, SL 3/RR 9, SL 3/RR 9
FM_SNARE_VALS:
    HEX FC
    HEX 25 05 74 74
    HEX 00 18 16 0A
    HEX 1F 1F 1F 1F
    HEX 00 00 0D 0D
    HEX 40 1F CC CC
    HEX F3 F1 39 39

; SB-INTRO's kick pitch dive: key code 32 -> 02 and key fraction 68 -> C8, one
; step per video frame. Entry 0 is the attack pitch written at key-on.
DRUM_KC:
    HEX 32 2A 22 1A 12 0A 02
DRUM_KF:
    HEX 68 78 88 98 A8 B8 C8

; Next entry of the dive (1..6), 0 = idle. Data byte, not zero page.
FM_KICK_IDX:
    HEX 00

; Fast 64KB VRAM Wiping Routine (Unrolled 8x writes)
; 32 outer loops * 256 inner loops * 8 bytes = 65,536 bytes
CLR_64K:
    LDX #$20
    LDY #$00
    LDA #$00
CLR_LOOP:
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    STA VERA_DATA0
    DEY
    BNE CLR_LOOP
    DEX
    BNE CLR_LOOP
    RTS

; ==============================================================================
; 16-Sprite Demo WITH Rich 4-Voice Stereo VERA PSG Chiptune Music for Apple II
; ==============================================================================

* = $2000

START:
    LDA #$00
    STA VERA_CTRL
    LDA #$41            ; Enable VGA (1) + Sprites (0x40)
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

ANIM_LOOP:
    ; 1. Advance Music Clock & Envelope
    DEC $EC
    BNE TICK_ENV
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

    INY
    CPY #$20            ; 32-step rich melody loop
    BNE STEP_OK
    LDY #$00
STEP_OK:
    STY $EB
    JMP SPRITE_UPDATE

TICK_ENV:
    ; Decay Lead volume envelope for natural attack/release
    LDA $ED
    SEC
    SBC #$06
    BCS VOL_OK
    LDA #$00
VOL_OK:
    STA $ED
    ORA #$40            ; Keep Left pan bit
    STA VERA_DATA1      ; Quick write to volume via port

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

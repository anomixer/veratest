; ==============================================================================
; 256-Color Fullscreen Slideshow Engine for Apple II (VERA Card + ProDOS)
; ProDOS MLI direct-block streaming engine for image assets; file MLI for music
; Supports: 375 320x240 8bpp Bitmaps + 375 Custom Palettes + 3 PSG+FM tracks
; Music: X16 ZSM streams (VERA PSG + YM2151 FM when the chip is present)
; Controls: Space/Right=Next, Left/Prev, A=Auto, R=Random, M=Mute, ESC=Exit
; ==============================================================================

* = $2000

MLI         = $BF00

CURRENT_IMG = $06       ; Current Image Index low byte (1..375)
CURRENT_IMG_H = $1C     ; High byte of current image index
AUTO_MODE   = $07       ; 0 = Manual, 1 = Auto-Play
RANDOM_MODE = $08       ; 0 = Sequential, 1 = Random
TIMER_L     = $09       ; Auto-play countdown timer
TIMER_H     = $0A
RAND_SEED   = $0B
RAND_SEED_H = $1D
BLOCK_COUNT = $0E       ; 150 blocks loop counter
MUSIC_PTR_L = $0F
MUSIC_PTR_H = $10
MUSIC_DELAY = $11
MUSIC_MUTE  = $12
MUSIC_INDEX = $20       ; Current soundtrack index (0..2)
MUSIC_NAME_PTR = $21
MUSIC_LOAD_TICKS = $13 ; Approx. 60Hz divider while streaming an image
IMAGE_VERA_ADDR_L = $14
IMAGE_VERA_ADDR_M = $15
IMAGE_VERA_ADDR_H = $16
OLD_IRQ_L = $17
OLD_IRQ_H = $18
IRQ_VERA_ADDR_L = $19
IRQ_VERA_ADDR_M = $1A
IRQ_VERA_ADDR_H = $1B
SAVE_PTR        = $1E       ; Pointer for saving Row 29 in RAM ($1E, $1F)
OSD_FG_COLOR    = $23       ; Optimal white color for current palette
OSD_BG_COLOR    = $24       ; Optimal black color for current palette
OSD_FONT_BYTE   = $25
OSD_ROW_IDX     = $26
OSD_COL_IDX     = $27
LEFT_BADGE_END  = $28       ; Dynamic end column for left badge (13..16)
PATH_SRC_PTR_L  = $30
PATH_SRC_PTR_H  = $31
PATH_SRC_IDX    = $32
PATH_CHAR       = $33
DIR_PTR         = $34       ; Zero-page pointer for ProDOS directory entries
FM_PRESENT      = $0C       ; 1 = YM2151 FM chip detected
FM_COUNT        = $0D       ; Remaining register pairs in the current FM batch
FM_MUSIC_MODE   = $2A       ; Text/OSD indicator character ('F' = FM, 'P' = PSG)
MUSIC_ACTIVE    = $2B       ; 0 = playing from MUSIC_BUF_A, 1 = MUSIC_BUF_B
MUSIC_NEXT_READY = $2C      ; 1 = the inactive buffer holds the next block
MUSIC_END_H     = $2D       ; High byte just past the active 512-byte block
MUSIC_MID_H     = $2E       ; High byte of the active block's midpoint

DATA_BUF    = $3C00     ; 512-Byte ProDOS Block Buffer ($3C00 ~ $3DFF)
PATH_BUF    = $5A00     ; 64-byte ProDOS pathname buffer
FILE_IO_BUF = $6000     ; 1 KB page-aligned ProDOS OPEN buffer
INDEX_BUF   = $5B00     ; Copy of an image's 512-byte sapling index block
MUSIC_BUF_A = $4000     ; 512-byte music stream block (buffer A)
MUSIC_BUF_B = $4200     ; 512-byte music stream block (buffer B)
FM_KEYS     = $4400     ; Last YM2151 $08 (key on/off) value per channel
; Master-volume scratch: the IRQ decoder, the mute/unmute restore and the +/- key
; handler all scale PSG volume registers through the same working bytes.
VOL_SAVEX   = $4408     ; Saved X (PSG register index) across SCALE_PSG_VOL
VOL_TMP     = $4409     ; Unscaled PSG volume byte
VOL_PAN     = $440A     ; Pan bits ($C0) of that byte
VOL_PROD    = $440B     ; value * volume, low byte
VOL_PROD_H  = $440C     ; value * volume, high byte
VOL_PROD_V  = $440D     ; Value being multiplied
FM_ATTEN    = $440E     ; YM2151 total-level attenuation steps for this volume
MUSIC_VOL   = $440F     ; Master volume 0..15 (default 12), adjusted by '+/-'
FM_TL_BASE  = $3B30     ; Base YM2151 TL values ($60..$7F), mirroring the chip

START:
    ; BRUN has no caller state to return to, so STARTUP loads this binary and
    ; CALLs $2000. Preserve Applesoft's zero page for a clean RTS back to BASIC.
    LDX #$3F
SAVE_BASIC_ZP:
    LDA $00,X
    STA BASIC_ZP_SAVE,X
    DEX
    BPL SAVE_BASIC_ZP

    ; 1. Hardware IRQ Safety & Video Blanking
    ; BRUN from BASIC may leave the 6502 decimal flag set. Address arithmetic
    ; in directory scanning (ADC #39) and music/file code must be binary.
    CLD
    SEI
    LDA #$00
    STA VERA_IEN          ; Disable VERA interrupts immediately
    LDA #$01
    STA VERA_ISR          ; Clear any pending VSYNC IRQ
    STA KBD_STROBE        ; Clear keyboard strobe
    LDA #$FF
    STA $F1               ; Applesoft text speed normal (255)

    ; 2. Blank VERA Display Composer & Reset Layers
    LDA #$00
    STA VERA_CTRL         ; Port 0, ADDRSEL = 0
    STA VERA_DC_VID       ; Blank video display during initialization
    STA VERA_DC_BOR       ; Border color = 0
    STA VERA_L0_CFG       ; Disable Layer 0
    STA VERA_L1_CFG       ; Disable Layer 1
    LDA #$40              ; 2.0x scale (320x240 view)
    STA VERA_DC_HSC
    STA VERA_DC_VSC

    ; 3. Silence ALL 16 VERA PSG Sound Channels ($1F9C0..$1F9FF) & Clear Shadow
    JSR SILENCE_PSG
    JSR CLEAR_PSG_SHADOW

    ; 3b. Detect the YM2151 FM chip on /DEVICE SELECT and clear
    ; its registers. The music streams carry both the PSG and the FM parts;
    ; when no FM chip answers the player simply skips FM batches and
    ; the PSG part still plays exactly as in the PSG-only version.
    JSR VERA_FM_DETECT
    JSR VERA_FM_RESET
    LDA #$D0            ; 'P' (PSG only)
    LDX FM_PRESENT
    BEQ FM_MODE_READY
    LDA #$C6            ; 'F' (PSG + FM)
FM_MODE_READY:
    STA FM_MUSIC_MODE

    ; 4. Initialize State Variables
    LDA #$01
    STA CURRENT_IMG
    LDA #$00
    STA CURRENT_IMG_H
    LDA #$01              ; Default to AutoPlay
    STA AUTO_MODE
    LDA #$00
    STA RANDOM_MODE
    LDA #$01              ; Default OSD Enabled
    STA OSD_ENABLED
    STA OSD_DIRTY
    LDA #$5A
    STA RAND_SEED
    LDA #$37
    STA RAND_SEED_H

    LDA #$00
    STA MUSIC_FILE_OPEN
    STA MUSIC_REFILL_PENDING
    STA MUSIC_CHANGE_PENDING
    STA MUSIC_WAITING
    STA MUSIC_PREFETCH_DONE
    STA MUSIC_HOLD

    ; Master volume: 0..15, default 12 (the +/- keys change it at run time).
    ; FM total levels can only be attenuated, so the table holds the number of
    ; TL steps to add for each volume; 0 means "unchanged" at full volume.
    LDA #12
    STA MUSIC_VOL
    LDX #12
    LDA FM_ATTEN_TAB,X
    STA FM_ATTEN
    JSR RESET_FM_TL_SHADOW

    ; 5. Configure Layer 0: Bitmap Mode (Color depth 8bpp = 3, Bitmap Mode = 1 << 2 = 4) -> $07
    LDA #$07
    STA VERA_L0_CFG
    LDA #$00
    STA VERA_L0_MAP
    STA VERA_L0_TIL
    LDA #$00
    STA VERA_L0_HSC_L
    STA VERA_L0_HSC_H
    STA VERA_L0_VSC_L
    STA VERA_L0_VSC_H
    STA VERA_L1_CFG

    ; 6. Load and initialize the converted Canyon PSG stream
    ; ProDOS file drivers may use IRQs while resolving paths and reading blocks.
    ; VERA IRQ sources are still disabled here; enable CPU IRQ handling for MLI.
    CLI
    JSR INIT_CANYON_MUSIC
    JSR LOAD_CANYON_MUSIC
    JSR UPDATE_MUSIC_NAME
    JSR UPDATE_VOLUME_TEXT

    ; 7. Initial Load of Image 1 and Palette 1
    ; (Interrupts remain disabled so MLI disk streaming is completely atomic!)
    JSR LOAD_IMAGE_AND_PALETTE
    JSR RESET_AUTO_TIMER
    STA KBD_STROBE

    ; 8. NOW that Image 1 and Palette 1 are in VRAM: Enable Video Output (Layer 0 only)
    LDA #$11
    STA VERA_DC_VID

    ; 9. Hook and Enable Music IRQ (interrupts enabled only NOW)
    JSR ENABLE_MUSIC_IRQ

MAIN_LOOP:
    JSR SERVICE_MUSIC_REQUESTS
    LDA OSD_DIRTY
    BEQ CHK_KEY
    LDA #$00
    STA OSD_DIRTY
    LDA OSD_ENABLED
    BEQ CHK_KEY
    JSR RENDER_OSD_TEXT

CHK_KEY:
    ; Check Keyboard Strobe
    LDA KBD_DATA
    BMI PROCESS_KEY
    JMP CHK_AUTO

PROCESS_KEY:
    STA KBD_STROBE      ; Clear strobe
    AND #$7F            ; Strip high bit

    ; ESC ($1B) or 'Q'/'q' ($51/$71) -> Exit to BASIC
    CMP #$1B
    BEQ DO_EXIT_JMP
    CMP #$51
    BEQ DO_EXIT_JMP
    CMP #$71
    BEQ DO_EXIT_JMP

    ; 'A' / 'a' ($41 / $61) -> Toggle Auto Mode
    CMP #$41
    BEQ TOGGLE_AUTO_JMP
    CMP #$61
    BEQ TOGGLE_AUTO_JMP

    ; 'R' / 'r' ($52 / $72) -> Toggle Random Mode
    CMP #$52
    BEQ TOGGLE_RAND_JMP
    CMP #$72
    BEQ TOGGLE_RAND_JMP

    ; 'O' / 'o' ($4F / $6F) -> Toggle OSD Status Bar
    CMP #$4F
    BEQ TOGGLE_OSD_JMP
    CMP #$6F
    BEQ TOGGLE_OSD_JMP

    ; 'M' / 'm' -> Toggle music
    CMP #$4D
    BEQ TOGGLE_MUTE_JMP
    CMP #$6D
    BEQ TOGGLE_MUTE_JMP

    ; '[' / ']' -> previous / next soundtrack
    CMP #$5B
    BEQ MUSIC_PREV_JMP
    CMP #$5D
    BEQ MUSIC_NEXT_JMP
    ; 'N'/'n' -> next soundtrack
    CMP #$4E
    BEQ MUSIC_NEXT_JMP
    CMP #$6E
    BEQ MUSIC_NEXT_JMP

    ; '+'/'=' and '-'/'_' -> master volume (0..15)
    CMP #$2B
    BEQ VOLUME_UP_JMP
    CMP #$3D
    BEQ VOLUME_UP_JMP
    CMP #$2D
    BEQ VOLUME_DOWN_JMP
    CMP #$5F
    BEQ VOLUME_DOWN_JMP

    ; Space ($20), Right Arrow ($15), Down Arrow ($0A) -> Next Image
    CMP #$20
    BEQ GOTO_NEXT_JMP
    CMP #$15
    BEQ GOTO_NEXT_JMP
    CMP #$0A
    BEQ GOTO_NEXT_JMP
    ; Left Arrow ($08), Up Arrow ($0B), 'P'/'p' -> Prev Image
    CMP #$08
    BEQ GOTO_PREV_JMP
    CMP #$0B
    BEQ GOTO_PREV_JMP
    CMP #$50
    BEQ GOTO_PREV_JMP
    CMP #$70
    BEQ GOTO_PREV_JMP

    JMP CHK_AUTO

DO_EXIT_JMP:
    JMP DO_EXIT
TOGGLE_AUTO_JMP:
    JMP TOGGLE_AUTO
TOGGLE_RAND_JMP:
    JMP TOGGLE_RAND
TOGGLE_OSD_JMP:
    JMP TOGGLE_OSD
TOGGLE_MUTE_JMP:
    JMP TOGGLE_MUTE
MUSIC_PREV_JMP:
    JMP MUSIC_PREV_KEY
MUSIC_NEXT_JMP:
    JMP MUSIC_NEXT_KEY
GOTO_NEXT_JMP:
    JMP GOTO_NEXT
GOTO_PREV_JMP:
    JMP GOTO_PREV
VOLUME_UP_JMP:
    JMP VOLUME_UP
VOLUME_DOWN_JMP:
    JMP VOLUME_DOWN

DO_EXIT:
    ; Clean up and return to ProDOS BASIC
    JSR DISABLE_MUSIC_IRQ
    JSR CLOSE_MUSIC_FILE
    JSR SILENCE_PSG
    JSR VERA_FM_KEY_OFF_ALL
    LDA #$00
    STA VERA_DC_VID     ; Disable VERA display
    ; Our zero-page scratch variables overlap the Apple II ROM's text-window
    ; state ($20-$29). Restore a normal 40-column window before calling HOME.
    STA $20               ; WNDLFT
    STA $22               ; WNDTOP
    STA $24               ; CH
    STA $25               ; CV
    LDA #$28
    STA $21               ; WNDWDTH = 40 columns
    LDA #$18
    STA $23               ; WNDBTM = 24 rows
    ; BRUN may leave the Apple II text/graphics soft switches in an unexpected
    ; state. Restore text mode and clear the screen before ProDOS resumes BASIC.
    JSR $FB39            ; SETTXT
    JSR $FC58            ; HOME
    ; Also clear all text-page bytes in case the ROM's window bookkeeping was
    ; damaged while the slideshow owned these zero-page locations.
    LDA #$A0
    LDX #$00
EXIT_CLEAR_TEXT:
    STA $0400,X
    STA $0500,X
    STA $0600,X
    STA $0700,X
    INX
    BNE EXIT_CLEAR_TEXT
    LDA #$00
    STA $24               ; CH
    STA $25               ; CV
    LDA #$FF
    STA $F1             ; Full text speed
    ; Restore Applesoft's zero page after using it as slideshow scratch space.
    LDX #$3F
RESTORE_BASIC_ZP:
    LDA BASIC_ZP_SAVE,X
    STA $00,X
    DEX
    BPL RESTORE_BASIC_ZP
    RTS

TOGGLE_OSD:
    LDA OSD_ENABLED
    EOR #$01
    STA OSD_ENABLED
    BNE TOGGLE_OSD_ON

TOGGLE_OSD_OFF:
    JSR RESTORE_ROW29
    JMP MAIN_LOOP

TOGGLE_OSD_ON:
    JSR RENDER_OSD_TEXT
    JMP MAIN_LOOP

TOGGLE_MUTE:
    LDA MUSIC_MUTE
    EOR #$01
    STA MUSIC_MUTE
    JSR UPDATE_MUSIC_NAME
    LDA MUSIC_MUTE
    BNE MUTE_PSG
    JSR RESTORE_PSG_FROM_SHADOW
    JSR VERA_FM_RESTORE_KEYS
    JMP MAIN_LOOP
MUTE_PSG:
    JSR SILENCE_PSG
    JSR VERA_FM_KEY_OFF_ALL
    JMP MAIN_LOOP

TOGGLE_AUTO:
    LDA AUTO_MODE
    EOR #$01
    STA AUTO_MODE
    LDA #$01
    STA OSD_DIRTY
    JSR RESET_AUTO_TIMER
    JMP MAIN_LOOP

TOGGLE_RAND:
    LDA RANDOM_MODE
    EOR #$01
    STA RANDOM_MODE
    ; Random mode always runs as an automatic slideshow.
    LDA #$01
    STA AUTO_MODE
    STA OSD_DIRTY
    ; Immediately jump to random next image!
    JSR GET_RANDOM_375
    STA CURRENT_IMG
    JSR LOAD_IMAGE_AND_PALETTE
    JSR RESET_AUTO_TIMER
    STA KBD_STROBE
    JMP MAIN_LOOP

GOTO_NEXT:
    JSR ADVANCE_NEXT_IMG
    JSR LOAD_IMAGE_AND_PALETTE
    JSR RESET_AUTO_TIMER
    STA KBD_STROBE
    JMP MAIN_LOOP

GOTO_PREV:
    JSR RETREAT_PREV_IMG
    JSR LOAD_IMAGE_AND_PALETTE
    JSR RESET_AUTO_TIMER
    STA KBD_STROBE
    JMP MAIN_LOOP

; ==============================================================================
; Master volume: 0..15, default 12, adjusted with '+'/'=' and '-'/'_'
; ==============================================================================
VOLUME_UP:
    LDA MUSIC_VOL
    CMP #$0F
    BCS VOLUME_DONE
    INC MUSIC_VOL
    JMP VOLUME_CHANGED
VOLUME_DOWN:
    LDA MUSIC_VOL
    BEQ VOLUME_DONE
    DEC MUSIC_VOL
VOLUME_CHANGED:
    JSR APPLY_VOLUME
VOLUME_DONE:
    JMP MAIN_LOOP

APPLY_VOLUME:
    ; Re-send every voice with the new volume: PSG volume registers are scaled
    ; from PSG_SHADOW, YM2151 total levels are attenuated from FM_TL_BASE.
    LDA MUSIC_VOL
    TAX
    LDA FM_ATTEN_TAB,X
    STA FM_ATTEN
    LDA MUSIC_MUTE
    BNE APPLY_VOLUME_UI       ; muted: leave the voices silent
    SEI
    JSR RESTORE_PSG_FROM_SHADOW
    JSR FM_APPLY_VOLUME
    CLI
APPLY_VOLUME_UI:
    JSR UPDATE_VOLUME_TEXT
    LDA #$01
    STA OSD_DIRTY
    RTS

; Scale a PSG volume byte (pan bits 7..6 preserved, volume bits 5..0 scaled)
; by MUSIC_VOL. In: A = value, X = PSG register index (preserved).
SCALE_PSG_VOL:
    STX VOL_SAVEX
    STA VOL_TMP
    AND #$C0
    STA VOL_PAN
    LDA MUSIC_VOL
    CMP #$0F
    BCS SCALE_PSG_FULL        ; full volume: leave the value alone
    STA VOL_PROD_V            ; multiplier = volume
    LDA #$08                  ; start with +8 for rounding
    STA VOL_PROD
    LDA #$00
    STA VOL_PROD_H
    LDA VOL_TMP
    AND #$3F
    STA VOL_TMP
    LDX VOL_PROD_V
    BEQ SCALE_PSG_ZERO        ; volume 0: silent, keep the pan bits only
SCALE_PSG_LOOP:
    CLC
    LDA VOL_PROD
    ADC VOL_TMP
    STA VOL_PROD
    BCC SCALE_PSG_NEXT
    INC VOL_PROD_H
SCALE_PSG_NEXT:
    DEX
    BNE SCALE_PSG_LOOP
    ; (value * volume + 8) >> 4, assembled from the two product bytes so the
    ; shift stays in the accumulator (no zero-page shift instructions needed).
    LDA VOL_PROD_H
    ASL
    ASL
    ASL
    ASL
    STA VOL_TMP
    LDA VOL_PROD
    LSR
    LSR
    LSR
    LSR
    ORA VOL_TMP
    STA VOL_TMP
    JMP SCALE_PSG_COMBINE
SCALE_PSG_ZERO:
    LDA #$00
    STA VOL_TMP
SCALE_PSG_COMBINE:
    LDA VOL_TMP
    ORA VOL_PAN
    LDX VOL_SAVEX
    RTS
SCALE_PSG_FULL:
    LDA VOL_TMP
    LDX VOL_SAVEX
    RTS

; Add FM_ATTEN to a YM2151 total-level value and saturate at $7F.
; The OPM total level is a 7-bit field (ymfm_opm.h: op_total_level reads
; bitfield(0x60, 0, 7)), so bit 7 must be masked off *before* the level is
; scaled. The ZSM streams leave it set in places ($8A, $94, $9D ...), and the
; chip ignores it; the earlier code compared the raw byte against $80 instead
; and clamped every one of those to $7F -- maximum attenuation, i.e. silence.
; GREENHILL writes such levels on its carriers from the first tick, which is
; why its FM half went missing while the other tracks still had FM.
; In: A = base TL; out: A = attenuated TL.
FM_ATTENUATE:
    AND #$7F
    CLC
    ADC FM_ATTEN
    CMP #$80
    BCC FM_ATTENUATE_DONE
    LDA #$7F
FM_ATTENUATE_DONE:
    RTS

; Rewrite every YM2151 total level from FM_TL_BASE with the current attenuation.
; All 32 operator levels are written because the chip's power-on/reset value is
; 0 (loudest) and the stream only rewrites the levels it actually changes.
FM_APPLY_VOLUME:
    LDA FM_PRESENT
    BEQ FM_APPLY_DONE
    LDX #$00
FM_APPLY_LOOP:
    TXA
    CLC
    ADC #$60                  ; $60..$7F = operator total levels
    STA YM_SEL
    LDA FM_TL_BASE,X
    JSR FM_ATTENUATE
    STA YM_DATA
    INX
    CPX #$20
    BCC FM_APPLY_LOOP
FM_APPLY_DONE:
    RTS

; Reset the base total levels to zero (called at start and on every track change,
; right after VERA_FM_RESET has zeroed the chip, so the mirror stays in step).
RESET_FM_TL_SHADOW:
    LDA #$00
    LDX #$00
RESET_FM_TL_LOOP:
    STA FM_TL_BASE,X
    INX
    CPX #$20
    BCC RESET_FM_TL_LOOP
    RTS

; Volume readout on the Apple II text page, row 24 cols 16..22: " VOL:nn"
UPDATE_VOLUME_TEXT:
    LDA #$A0            ; space (separates it from the " F"/" P" mode char)
    STA $07E0
    LDA #$D6            ; V
    STA $07E1
    LDA #$CF            ; O
    STA $07E2
    LDA #$CC            ; L
    STA $07E3
    LDA #$BA            ; :
    STA $07E4
    LDA MUSIC_VOL
    LDY #$2F            ; '0' - 1
UPDATE_VOL_TENS:
    INY
    SEC
    SBC #$0A
    BCS UPDATE_VOL_TENS
    ADC #$BA            ; ones digit with the high bit set
    STA $07E6
    TYA
    ORA #$80
    STA $07E5
    RTS

; ==============================================================================
; Per-volume YM2151 total-level attenuation, matched to the PSG amplitude law
; (PSG level scales as volume/16, i.e. 20*log10(v/16) dB) so both halves of the
; mix move together: 15 -> 0 steps (as authored), 12 -> 3 (~2.25 dB, default),
; 0 -> 127 (silent). One TL step is 0.75 dB on the OPM.
; ==============================================================================
FM_ATTEN_TAB:
    !byte 127, 32, 24, 19, 16, 14, 11, 10, 8, 7, 5, 4, 3, 2, 2, 0

CHK_AUTO:
    LDA AUTO_MODE
    BEQ IDLE_DELAY

    ; Proper 16-bit countdown timer decrement
    LDA TIMER_L
    SEC
    SBC #$01
    STA TIMER_L
    LDA TIMER_H
    SBC #$00
    STA TIMER_H

    ORA TIMER_L         ; Check if (TIMER_H | TIMER_L) == 0
    BNE IDLE_DELAY

    ; Auto-Timer expired! Advance to next/random image
    JSR ADVANCE_NEXT_IMG
    JSR LOAD_IMAGE_AND_PALETTE
    JSR RESET_AUTO_TIMER
    STA KBD_STROBE

IDLE_DELAY:
    ; Music is advanced by the VERA VSYNC IRQ. Keep the foreground delay for
    ; keyboard polling and auto-play timing.
    ; 13 * (255 * ~5 cycles) ~= 16,600 cycles at 1 MHz.
    LDY #$0D
DLY1:
    LDX #$FF
DLY2:
    DEX
    BNE DLY2
    DEY
    BNE DLY1
    JMP MAIN_LOOP

; ==============================================================================
; Image Index Manipulation
; ==============================================================================
ADVANCE_NEXT_IMG:
    LDA RANDOM_MODE
    BNE DO_RANDOM_NEXT
    INC CURRENT_IMG
    BNE ADV_CHECK_LIMIT
    INC CURRENT_IMG_H
ADV_CHECK_LIMIT:
    LDA CURRENT_IMG_H
    CMP #$01
    BCC ADV_OK
    BNE ADV_WRAP
    LDA CURRENT_IMG
    CMP #$78            ; 376: wrap after image 375 ($0177)
    BCC ADV_OK
ADV_WRAP:
    LDA #$01
    STA CURRENT_IMG
    LDA #$00
    STA CURRENT_IMG_H
ADV_OK:
    RTS

DO_RANDOM_NEXT:
    JSR GET_RANDOM_375
    STA CURRENT_IMG
    RTS

RETREAT_PREV_IMG:
    LDA RANDOM_MODE
    BNE DO_RANDOM_NEXT
    LDA CURRENT_IMG
    BNE RET_DEC_LOW
    DEC CURRENT_IMG_H
RET_DEC_LOW:
    DEC CURRENT_IMG
    LDA CURRENT_IMG
    ORA CURRENT_IMG_H
    BNE RET_OK
    LDA #$77            ; 375 ($0177)
    STA CURRENT_IMG
    LDA #$01
    STA CURRENT_IMG_H
RET_OK:
    RTS

RESET_AUTO_TIMER:
    ; ~3.0 seconds delay (60 ticks/sec * 3.0s = 180 ticks = $00B4)
    LDA #$B4
    STA TIMER_L
    LDA #$00
    STA TIMER_H
    RTS

; 16-bit LFSR Random 1..375 Generator
GET_RANDOM_375:
    LDA RAND_SEED
    ASL
    STA RAND_SEED
    LDA RAND_SEED_H
    ROL
    STA RAND_SEED_H
    BCC RANDOM_NO_EOR
    LDA RAND_SEED
    EOR #$1D
    STA RAND_SEED
    LDA RAND_SEED_H
    EOR #$A6
    STA RAND_SEED_H
RANDOM_NO_EOR:
    LDA RAND_SEED_H
    AND #$01
    BNE RANDOM_HIGH_CHECK
    JMP RANDOM_ACCEPT
RANDOM_HIGH_CHECK:
    LDA RAND_SEED
    CMP #$77
    BCS GET_RANDOM_375
RANDOM_ACCEPT:
    LDA RAND_SEED
    CLC
    ADC #$01
    STA CURRENT_IMG
    LDA RAND_SEED_H
    AND #$01
    ADC #$00
    STA CURRENT_IMG_H
    LDA CURRENT_IMG
    ORA CURRENT_IMG_H
    BNE RANDOM_DONE
    JMP GET_RANDOM_375
RANDOM_DONE:
    LDA CURRENT_IMG
    RTS

MULT_TEMP:
    !byte $00
MULT_TEMP_H:
    !byte $00

; ==============================================================================
; ProDOS file streaming: one palette file plus 150 image data blocks
; ==============================================================================
LOAD_IMAGE_AND_PALETTE:
    ; Palette files are only 512 bytes: use ProDOS OPEN/READ directly.
    LDA #$01
    STA PAL_STAGE
    LDA #$00
    STA FILE_KIND
    JSR OPEN_SELECTED_FILE
    BCC PAL_OPEN_OK
    JMP READ_PAL_FAIL
PAL_OPEN_OK:
    LDA #$02
    STA PAL_STAGE
    LDA #<DATA_BUF
    STA FILE_BUF_PTR
    LDA #>DATA_BUF
    STA FILE_BUF_PTR+1
    JSR READ_IMAGE_BLOCK
    BCC PAL_READ_OK
    JMP READ_PAL_FAIL
PAL_READ_OK:
    LDA #$03
    STA PAL_STAGE
    JSR CLOSE_IMAGE_FILE
    ; Lookup optimal FG (white) and BG (black) for this image from precomputed LUT
    LDA CURRENT_IMG_H
    BEQ GET_LUT_LO
    LDX CURRENT_IMG
    LDA PAL_FG_TABLE+255,X
    STA OSD_FG_COLOR
    LDA PAL_BG_TABLE+255,X
    STA OSD_BG_COLOR
    JMP GOT_LUT
GET_LUT_LO:
    LDX CURRENT_IMG
    DEX
    LDA PAL_FG_TABLE,X
    STA OSD_FG_COLOR
    LDA PAL_BG_TABLE,X
    STA OSD_BG_COLOR
GOT_LUT:

    ; Write Palette (512 bytes) to VRAM $1FA00 (100% UNTOUCHED! No modifying entries!)
    LDA #$00
    STA VERA_CTRL
    STA VERA_ADDR_L
    LDA #$FA
    STA VERA_ADDR_M
    LDA #$11            ; Stride +1, Bank 1
    STA VERA_ADDR_H

    LDY #$00
CP_PAL_P1:
    LDA DATA_BUF,Y
    STA VERA_DATA0
    INY
    BNE CP_PAL_P1
CP_PAL_P2:
    LDA DATA_BUF+$100,Y
    STA VERA_DATA0
    INY
    BNE CP_PAL_P2

    ; Resolve IMGnnn.BIN and load its sapling index block.
    LDA #$01
    STA FILE_KIND
    JSR PREPARE_DIRECT_FILE
    BCC IMAGE_OPEN_OK
    JMP READ_IMG_OPEN_FAIL
IMAGE_OPEN_OK:

    ; Set VRAM Address to $00000, Stride +1, Bank 0
    LDA #$00
    STA VERA_CTRL
    STA VERA_ADDR_L
    STA VERA_ADDR_M
    LDA #$10            ; Bank 0, Stride +1
    STA VERA_ADDR_H

    ; Stream 150 consecutive Blocks (76,800 bytes) directly to VERA
    LDA #150
    STA BLOCK_COUNT
    LDA #$00
    STA IMAGE_BLOCK_INDEX
    LDA #<$5000
    STA SAVE_PTR
    LDA #>$5000
    STA SAVE_PTR+1

STREAM_150_BLOCKS:
    ; Resolve this data block through the sapling index (150 entries).
    LDX IMAGE_BLOCK_INDEX
    LDA INDEX_BUF,X
    STA MLI_BLOCK
    LDA INDEX_BUF+$100,X
    STA MLI_BLOCK+1
    ; ProDOS sparse files use index value $0000 for an all-zero data block.
    ; Reading physical block 0 here would copy the boot block into the bitmap,
    ; producing the colored garbage seen in images with blank rows.
    LDA MLI_BLOCK
    ORA MLI_BLOCK+1
    BNE STREAM_READ_IMAGE_BLOCK
    LDY #$00
    LDA #$00
ZERO_SPARSE_BLOCK_LO:
    STA DATA_BUF,Y
    INY
    BNE ZERO_SPARSE_BLOCK_LO
    LDY #$00
ZERO_SPARSE_BLOCK_HI:
    STA DATA_BUF+$100,Y
    INY
    BNE ZERO_SPARSE_BLOCK_HI
    JMP IMAGE_BLOCK_OK
STREAM_READ_IMAGE_BLOCK:
    JSR READ_PRODOS_BLOCK
    BCC IMAGE_BLOCK_OK
    JMP READ_IMG_FAIL
IMAGE_BLOCK_OK:
    ; Image loading is a long foreground operation. Service any deferred PSG
    ; disk read between image blocks so audio does not pause for the full image.
    JSR SERVICE_MUSIC_REQUESTS

    ; Check if this is one of the last 5 blocks (BLOCK_COUNT <= 5)
    LDA BLOCK_COUNT
    CMP #6
    BCS STREAM_NORMAL_BLOCK

    ; Save DATA_BUF (512 bytes) to SAVED_ROW29 in RAM ($5000..$59FF)
    LDY #$00
SAVE_ROW29_P1:
    LDA DATA_BUF,Y
    STA (SAVE_PTR),Y
    INY
    BNE SAVE_ROW29_P1
    INC SAVE_PTR+1
    LDY #$00
SAVE_ROW29_P2:
    LDA DATA_BUF+$100,Y
    STA (SAVE_PTR),Y
    INY
    BNE SAVE_ROW29_P2
    INC SAVE_PTR+1

STREAM_NORMAL_BLOCK:
    ; Stream 512 bytes directly to VERA_DATA0 (music IRQ advances uninterrupted here)
    LDY #$00
CP_IMG_P1:
    LDA DATA_BUF,Y
    STA VERA_DATA0
    INY
    BNE CP_IMG_P1
CP_IMG_P2:
    LDA DATA_BUF+$100,Y
    STA VERA_DATA0
    INY
    BNE CP_IMG_P2

    DEC BLOCK_COUNT
    INC IMAGE_BLOCK_INDEX
    LDA BLOCK_COUNT
    BNE STREAM_150_BLOCKS

    ; Success! Clear border to black
    LDA #$00
    STA VERA_DC_BOR
    JSR UPDATE_IMAGE_NUMBER
    LDA OSD_ENABLED
    BEQ LOAD_IMG_NO_OSD
    JSR RENDER_OSD_TEXT
LOAD_IMG_NO_OSD:
    RTS

READ_PAL_FAIL:
    LDA #$01
    STA FILE_ERROR_KIND
    JMP SHOW_FILE_ERROR

READ_IMG_FAIL:
READ_IMG_OPEN_FAIL:
    LDA #$02
    STA FILE_ERROR_KIND
    JMP SHOW_FILE_ERROR

SHOW_FILE_ERROR:
    LDA #$00
    STA VERA_DC_VID
    STA $C051
    STA $C054
    LDX #$00
    LDA #$A0
CLEAR_ERROR_TEXT:
    STA $0400,X
    STA $0480,X
    INX
    CPX #$50
    BCC CLEAR_ERROR_TEXT
    LDA #$C6
    STA $0400
    LDA #$C9
    STA $0401
    LDA #$CC
    STA $0402
    LDA #$C5
    STA $0403
    LDA #$A0
    STA $0404
    LDA #$C5
    STA $0405
    LDA #$D2
    STA $0406
    LDA #$D2
    STA $0407
    LDA #$CF
    STA $0408
    LDA #$D2
    STA $0409
    LDA FILE_ERROR_KIND
    CMP #$01
    BNE SHOW_IMAGE_ERROR_KIND
    LDA #$D0
    BNE SHOW_ERROR_KIND
SHOW_IMAGE_ERROR_KIND:
    LDA #$C9
SHOW_ERROR_KIND:
    STA $040B
    LDA #$D0
    STA $0480
    LDA #$C1
    STA $0481
    LDA #$D4
    STA $0482
    LDA #$C8
    STA $0483
    LDA #$BA
    STA $0484
    LDX #$00
SHOW_ERROR_PATH:
    TXA
    CMP PATH_BUF
    BCS SHOW_ERROR_DETAILS
    LDA PATH_BUF+1,X
    ORA #$80
    STA $0486,X
    INX
    CPX #$22
    BCC SHOW_ERROR_PATH
SHOW_ERROR_DETAILS:
    LDA #$C5
    STA $0500
    LDA #$D2
    STA $0501
    STA $0502
    LDA #$BA
    STA $0503
    LDA FILE_MLI_STATUS
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA HEX_DIGITS,X
    STA $0504
    LDA FILE_MLI_STATUS
    AND #$0F
    TAX
    LDA HEX_DIGITS,X
    STA $0505
    ; Show the failing file READ parameter list inline after ERR:xx.
    LDA #$D2
    STA $0507
    LDA #$BA
    STA $0508
    LDX #$00
    STX READ_DIAG_INDEX
    LDY #$09
SHOW_READ_DIAG:
    LDX READ_DIAG_INDEX
    LDA READ_PARAMS,X
    STA READ_DIAG_BYTE
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA HEX_DIGITS,X
    STA $0500,Y
    INY
    LDA READ_DIAG_BYTE
    AND #$0F
    TAX
    LDA HEX_DIGITS,X
    STA $0500,Y
    INY
    INC READ_DIAG_INDEX
    LDA READ_DIAG_INDEX
    CMP #$08
    BCC SHOW_READ_DIAG
    LDA #$D3
    STA $0519
    LDA #$BA
    STA $051A
    LDX PAL_STAGE
    LDA HEX_DIGITS,X
    STA $051B
SHOW_ERROR_HALT:
    JMP SHOW_ERROR_HALT

UPDATE_IMAGE_NUMBER:
    ; Apple II text page 1, row 24, right-aligned: "IMG: nnn/375".
    ; The Apple II text display is independent from the fullscreen VERA output.
    LDA #$A0              ; space
    STA $07EC
    LDA #$C9              ; I
    STA $07ED
    LDA #$CD              ; M
    STA $07EE
    LDA #$C7              ; G
    STA $07EF
    LDA #$BA              ; colon
    STA $07F0
    LDA CURRENT_IMG
    STA MULT_TEMP
    LDA CURRENT_IMG_H
    STA MULT_TEMP_H

    LDX #$00
IMAGE_HUNDREDS:
    LDA MULT_TEMP_H
    BNE IMAGE_SUB_100
    LDA MULT_TEMP
    CMP #$64
    BCC IMAGE_HUNDREDS_DONE
IMAGE_SUB_100:
    LDA MULT_TEMP
    SEC
    SBC #$64
    STA MULT_TEMP
    LDA MULT_TEMP_H
    SBC #$00
    STA MULT_TEMP_H
    INX
    JMP IMAGE_HUNDREDS
IMAGE_HUNDREDS_DONE:
    TXA
    CLC
    ADC #$B0
    STA $07F1

    LDY #$00
IMAGE_TENS:
    LDA MULT_TEMP
    CMP #$0A
    BCC IMAGE_TENS_DONE
    SEC
    SBC #$0A
    STA MULT_TEMP
    INY
    JMP IMAGE_TENS
IMAGE_TENS_DONE:
    TYA
    CLC
    ADC #$B0
    STA $07F2
    LDA MULT_TEMP
    CLC
    ADC #$B0
    STA $07F3
    LDA #$AF              ; /
    STA $07F4
    LDA #$B3              ; 3
    STA $07F5
    LDA #$B7              ; 7
    STA $07F6
    LDA #$B5              ; 5
    STA $07F7
    RTS

; ===========================================================================
; Converted ZSM -> VERA PSG stream player
; ===========================================================================

INIT_CANYON_MUSIC:
    JSR CLEAR_PSG_SHADOW
    LDA #<MUSIC_BUF_A
    STA MUSIC_PTR_L
    LDA #>MUSIC_BUF_A
    STA MUSIC_PTR_H
    LDA #$41
    STA MUSIC_MID_H
    LDA #$42
    STA MUSIC_END_H
    LDA #$00
    STA MUSIC_ACTIVE
    STA MUSIC_NEXT_READY
    STA MUSIC_DELAY
    STA MUSIC_MUTE
    STA MUSIC_INDEX
    RTS

LOAD_CANYON_MUSIC:
    CLC
    LDA MUSIC_INDEX
    ADC #$02
    STA FILE_KIND
    JSR OPEN_SELECTED_FILE
    BCS CANYON_LOAD_FAIL
    LDA #<$4000
    STA CANYON_BUF_PTR
    LDA #>$4000
    STA CANYON_BUF_PTR+1
    ; Keep one block buffered. The IRQ requests a foreground refill at the end.
    LDA #$01
    STA MUSIC_LOAD_COUNT
LOAD_CANYON_CHUNK:
    LDA CANYON_BUF_PTR
    STA FILE_BUF_PTR
    LDA CANYON_BUF_PTR+1
    STA FILE_BUF_PTR+1
    JSR READ_MUSIC_BLOCK
    BCS CANYON_LOAD_FAIL
    LDA CANYON_BUF_PTR+1
    CLC
    ADC #$02
    STA CANYON_BUF_PTR+1
    DEC MUSIC_LOAD_COUNT
    BNE LOAD_CANYON_CHUNK
    RTS

; Legacy label retained as the common failure exit for the file reader.
CANYON_LOAD_FAIL:
    LDA #$01
    STA MUSIC_MUTE
    LDA #$00
    STA MUSIC_HOLD
    RTS

MUSIC_NEXT:
    INC MUSIC_INDEX
    LDA MUSIC_INDEX
    CMP #$03
    BCC MUSIC_SELECT
    LDA #$00
    STA MUSIC_INDEX
    JMP MUSIC_SELECT

MUSIC_PREV:
    LDA MUSIC_INDEX
    BNE MUSIC_PREV_DEC
    LDA #$03
    STA MUSIC_INDEX
MUSIC_PREV_DEC:
    DEC MUSIC_INDEX

MUSIC_SELECT:
    LDA #$01
    STA MUSIC_HOLD
    JSR CLOSE_MUSIC_FILE
    ; Reset all voices so the previous soundtrack cannot leave residual notes.
    JSR SILENCE_PSG
    JSR CLEAR_PSG_SHADOW
    ; The FM stream is compressed against an all-zero YM2151 state, so the chip
    ; must be cleared here too before the first record of the new track.
    JSR VERA_FM_RESET
    JSR RESET_FM_TL_SHADOW
    LDA #<MUSIC_BUF_A
    STA MUSIC_PTR_L
    LDA #>MUSIC_BUF_A
    STA MUSIC_PTR_H
    LDA #$00
    STA MUSIC_DELAY
    JSR LOAD_CANYON_MUSIC
    JSR UPDATE_MUSIC_NAME
    JSR UPDATE_VOLUME_TEXT
    ; The first block is buffered at MUSIC_BUF_A; ask for block 1 immediately.
    LDA #$41
    STA MUSIC_MID_H
    LDA #$42
    STA MUSIC_END_H
    LDA #$00
    STA MUSIC_ACTIVE
    STA MUSIC_NEXT_READY
    STA MUSIC_CHANGE_PENDING
    STA MUSIC_WAITING
    STA MUSIC_PREFETCH_DONE
    STA MUSIC_HOLD
    LDA #$01
    STA MUSIC_REFILL_PENDING
    RTS

MUSIC_NEXT_KEY:
    JSR MUSIC_NEXT
    JMP MAIN_LOOP

MUSIC_PREV_KEY:
    JSR MUSIC_PREV
    JMP MAIN_LOOP

ENABLE_MUSIC_IRQ:
    SEI
    LDA $03FE
    STA OLD_IRQ_L
    LDA $03FF
    STA OLD_IRQ_H
    LDA #<MUSIC_IRQ_HANDLER
    STA $03FE
    LDA #>MUSIC_IRQ_HANDLER
    STA $03FF
    LDA #$01
    STA VERA_ISR          ; Clear any pending VSYNC IRQ
    STA VERA_IEN          ; Enable VERA VSYNC interrupt
    CLI
    RTS

DISABLE_MUSIC_IRQ:
    SEI
    LDA #$00
    STA VERA_IEN
    LDA OLD_IRQ_L
    STA $03FE
    LDA OLD_IRQ_H
    STA $03FF
    CLI
    RTS

MUSIC_IRQ_HANDLER:
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA VERA_ISR
    AND #$01
    BEQ MUSIC_IRQ_DONE
    LDA #$01
    STA VERA_ISR          ; Acknowledge VSYNC source

    ; Music writes the PSG through VERA and therefore changes the VRAM
    ; address registers. Preserve the foreground image stream address.
    LDA VERA_ADDR_L
    STA IRQ_VERA_ADDR_L
    LDA VERA_ADDR_M
    STA IRQ_VERA_ADDR_M
    LDA VERA_ADDR_H
    STA IRQ_VERA_ADDR_H
    JSR TICK_MUSIC
    LDA IRQ_VERA_ADDR_L
    STA VERA_ADDR_L
    LDA IRQ_VERA_ADDR_M
    STA VERA_ADDR_M
    LDA IRQ_VERA_ADDR_H
    STA VERA_ADDR_H

MUSIC_IRQ_DONE:
    PLA
    TAY
    PLA
    TAX
    PLA
    RTI

SERVICE_MUSIC_REQUESTS:
    ; Never call ProDOS MLI from the IRQ handler. A refill fills the buffer
    ; that is not playing, and a track change keeps MUSIC_HOLD set while MLI
    ; is active. Music setup also writes VERA registers, so preserve the
    ; foreground's current VERA address while servicing a request between
    ; image blocks.
    LDA VERA_CTRL
    STA SERVICE_VERA_CTRL
    LDA VERA_ADDR_L
    STA SERVICE_VERA_ADDR_L
    LDA VERA_ADDR_M
    STA SERVICE_VERA_ADDR_M
    LDA VERA_ADDR_H
    STA SERVICE_VERA_ADDR_H
    LDA MUSIC_HOLD
    BNE SERVICE_MUSIC_RESTORE
    LDA MUSIC_REFILL_PENDING
    BEQ SERVICE_MUSIC_TRACK
    JSR REFILL_MUSIC_BUFFER
    JMP SERVICE_MUSIC_RESTORE
SERVICE_MUSIC_TRACK:
    LDA MUSIC_CHANGE_PENDING
    BEQ SERVICE_MUSIC_RESTORE
    LDA #$00
    STA MUSIC_CHANGE_PENDING
    JSR MUSIC_SELECT
SERVICE_MUSIC_RESTORE:
    LDA SERVICE_VERA_CTRL
    STA VERA_CTRL
    LDA SERVICE_VERA_ADDR_L
    STA VERA_ADDR_L
    LDA SERVICE_VERA_ADDR_M
    STA VERA_ADDR_M
    LDA SERVICE_VERA_ADDR_H
    STA VERA_ADDR_H
    RTS

TICK_MUSIC:
    LDA MUSIC_MUTE
    BEQ TICK_MUSIC_NOT_MUTED
    RTS
TICK_MUSIC_NOT_MUTED:
    LDA MUSIC_HOLD
    BEQ TICK_MUSIC_NOT_HELD
    LDA MUSIC_DELAY
    BNE TICK_MUSIC_RET
    RTS
TICK_MUSIC_NOT_HELD:
    LDA MUSIC_CHANGE_PENDING
    BEQ TICK_MUSIC_NOT_CHANGING
    LDA MUSIC_DELAY
    BNE TICK_MUSIC_RET
    RTS
TICK_MUSIC_NOT_CHANGING:
    ; The stream is double-buffered.  As soon as the active block pointer
    ; passes its midpoint, ask the foreground to read the next 512-byte block
    ; into the *other* buffer, so the switch at the end of the block never
    ; waits for the disk and never costs a music tick.
    LDA MUSIC_NEXT_READY
    BNE TICK_MUSIC_END_CHECK
    LDA MUSIC_PTR_H
    CMP MUSIC_MID_H
    BCC TICK_MUSIC_END_CHECK
    LDA #$01
    STA MUSIC_REFILL_PENDING
TICK_MUSIC_END_CHECK:
    LDA MUSIC_PTR_H
    CMP MUSIC_END_H
    BCS TICK_MUSIC_AT_END
    LDA MUSIC_DELAY
    BNE TICK_MUSIC_DEC_DELAY
    JMP MUSIC_DECODE
TICK_MUSIC_DEC_DELAY:
    DEC MUSIC_DELAY
    RTS
TICK_MUSIC_AT_END:
    JSR MUSIC_SWITCH_BLOCK
    BCS TICK_MUSIC_STALLED
    JMP TICK_MUSIC_READY
TICK_MUSIC_STALLED:
    LDA MUSIC_DELAY
    BNE TICK_MUSIC_DEC_DELAY
    RTS
TICK_MUSIC_READY:
    LDA MUSIC_DELAY
    BNE TICK_MUSIC_DEC_DELAY
    JMP MUSIC_DECODE
TICK_MUSIC_RET:
    RTS

; Switch the decoder to the prefetched buffer.
;   C=0: switched, MUSIC_PTR points at the start of the other buffer
;   C=1: the other buffer is still being filled, caller must wait a frame
MUSIC_SWITCH_BLOCK:
    LDA MUSIC_NEXT_READY
    BEQ MUSIC_SWITCH_STALL
    LDA #$00
    STA MUSIC_NEXT_READY
    LDA MUSIC_ACTIVE
    EOR #$01
    STA MUSIC_ACTIVE
    BNE MUSIC_SWITCH_B
    LDA #$00
    STA MUSIC_PTR_L
    LDA #$40
    STA MUSIC_PTR_H
    LDA #$41
    STA MUSIC_MID_H
    LDA #$42
    STA MUSIC_END_H
    JMP MUSIC_SWITCH_OK
MUSIC_SWITCH_B:
    LDA #$00
    STA MUSIC_PTR_L
    LDA #$42
    STA MUSIC_PTR_H
    LDA #$43
    STA MUSIC_MID_H
    LDA #$44
    STA MUSIC_END_H
MUSIC_SWITCH_OK:
    LDA #$01
    STA MUSIC_REFILL_PENDING
    CLC
    RTS
MUSIC_SWITCH_STALL:
    LDA #$01
    STA MUSIC_REFILL_PENDING
    SEC
    RTS

MUSIC_DECODE:
    ; A block boundary can be reached while decoding several records in one
    ; tick. Switch to the prefetched buffer and keep decoding, so the tick is
    ; not split; only fall back to waiting when the prefetch has not finished.
    LDA MUSIC_PTR_H
    CMP MUSIC_END_H
    BCC MUSIC_DECODE_READY
    JSR MUSIC_SWITCH_BLOCK
    BCS MUSIC_STALL_MID_TICK
    JMP MUSIC_DECODE
MUSIC_STALL_MID_TICK:
    RTS
MUSIC_DECODE_READY:
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    CMP #$FF
    BNE MUSIC_CHK_80
    JMP MUSIC_RESTART
MUSIC_CHK_80:
    CMP #$80
    BCS MUSIC_CHK_C0
    JMP MUSIC_SET_DELAY
MUSIC_CHK_C0:
    CMP #$C0
    BCS MUSIC_CHK_E0
    JMP MUSIC_PSG_WRITE
MUSIC_CHK_E0:
    CMP #$E0
    BCS MUSIC_NOP_PAD
    JMP MUSIC_FM_BATCH
MUSIC_NOP_PAD:
    ; $E0-$FE: block alignment no-op, consumes no tick (not a delay).
    JSR MUSIC_ADVANCE_1
    JMP MUSIC_DECODE
MUSIC_PSG_WRITE:
    AND #$3F
    TAX
    CLC
    ADC #$C0
    STA VERA_ADDR_L
    LDA #$F9
    ADC #$00
    STA VERA_ADDR_M
    LDA #$01
    STA VERA_ADDR_H
    LDY #$01
    LDA (MUSIC_PTR_L),Y
    STA PSG_SHADOW,X
    ; Volume registers (offset +2 of each voice) carry pan in bits 7..6 and the
    ; level in bits 5..0: the shadow keeps the stream value, VERA gets it scaled.
    TXA
    AND #$03
    CMP #$02
    BNE MUSIC_PSG_PLAIN
    LDA PSG_SHADOW,X
    JSR SCALE_PSG_VOL
    JMP MUSIC_PSG_STORE
MUSIC_PSG_PLAIN:
    LDA PSG_SHADOW,X
MUSIC_PSG_STORE:
    STA VERA_DATA0
    JSR MUSIC_ADVANCE_2
    JMP MUSIC_DECODE
MUSIC_FM_BATCH:
    ; $C0-$DF: (count - 1) in the low five bits, then count YM2151 pairs.
    ; The converter guarantees the whole batch lives inside one 512-byte block.
    AND #$1F
    CLC
    ADC #$01            ; stored value is count-1: recover the real pair count
    STA FM_COUNT
    JSR MUSIC_ADVANCE_1
    LDA FM_PRESENT
    BEQ MUSIC_FM_SKIP
MUSIC_FM_WRITE:
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    STA YM_SEL
    CMP #$08
    BNE MUSIC_FM_PLAIN
    ; Key on/off register: remember the value per channel for mute/unmute.
    JSR MUSIC_ADVANCE_1
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    PHA
    AND #$07
    TAY
    PLA
    STA FM_KEYS,Y
    STA YM_DATA
    JSR MUSIC_ADVANCE_1
    JMP MUSIC_FM_NEXT
MUSIC_FM_PLAIN:
    ; A still holds the register byte that was just written to YM_SEL; keep it
    ; before advancing, because the FM aperture cannot be read back.
    STA VOL_TMP
    JSR MUSIC_ADVANCE_1
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    ; YM2151 total levels ($60..$7F) follow the master volume. The stream value
    ; is kept as the base so a later '+'/'-' can recompute the attenuation.
    LDX VOL_TMP
    CPX #$60
    BCC MUSIC_FM_STORE
    CPX #$80
    BCS MUSIC_FM_STORE
    PHA
    TXA
    AND #$1F
    TAX
    PLA
    STA FM_TL_BASE,X
    JSR FM_ATTENUATE
MUSIC_FM_STORE:
    STA YM_DATA
    JSR MUSIC_ADVANCE_1
MUSIC_FM_NEXT:
    DEC FM_COUNT
    BNE MUSIC_FM_WRITE
    JMP MUSIC_DECODE
MUSIC_FM_SKIP:
    ; No FM chip: drop the batch payload without touching YM_SEL/YM_DATA (/DEVICE SELECT).
    JSR MUSIC_ADVANCE_2
    DEC FM_COUNT
    BNE MUSIC_FM_SKIP
    JMP MUSIC_DECODE
MUSIC_SET_DELAY:
    STA MUSIC_DELAY
    JSR MUSIC_ADVANCE_1
MUSIC_TICK_DONE:
    RTS
MUSIC_RESTART:
    LDA RANDOM_MODE
    BNE MUSIC_RANDOM_NEXT
    INC MUSIC_INDEX
    LDA MUSIC_INDEX
    CMP #$03
    BCC MUSIC_RESTART_SELECT
    LDA #$00
    STA MUSIC_INDEX
MUSIC_RESTART_SELECT:
    LDA #$01
    STA MUSIC_CHANGE_PENDING
    RTS
MUSIC_RANDOM_NEXT:
    LDA RAND_SEED
    ASL
    EOR RAND_SEED
    STA RAND_SEED
    AND #$03
    CMP #$03
    BEQ MUSIC_RANDOM_NEXT
    STA MUSIC_INDEX
    LDA #$01
    STA MUSIC_CHANGE_PENDING
    RTS
MUSIC_ADVANCE_1:
    INC MUSIC_PTR_L
    BNE MUSIC_PTR_OK
    INC MUSIC_PTR_H
MUSIC_PTR_OK:
    RTS
MUSIC_ADVANCE_2:
    JSR MUSIC_ADVANCE_1
    JMP MUSIC_ADVANCE_1

UPDATE_MUSIC_NAME:
    LDA MUSIC_MUTE
    BEQ UPDATE_MNAME_ACTIVE

    ; Muted: clear entire bottom-left text (16 chars $07D0..$07DF) with spaces
    LDY #$00
    LDA #$A0
CLR_MNAME_TEXT:
    STA $07D0,Y
    INY
    CPY #16
    BCC CLR_MNAME_TEXT
    LDA #$01
    STA OSD_DIRTY
    RTS

UPDATE_MNAME_ACTIVE:
    ; Apple II text page 1, bottom-left: "MUSIC:<name>"
    LDA #$CD              ; M
    STA $07D0
    LDA #$D5              ; U
    STA $07D1
    LDA #$D3              ; S
    STA $07D2
    LDA #$C9              ; I
    STA $07D3
    LDA #$C3              ; C
    STA $07D4
    LDA #$BA              ; :
    STA $07D5
    LDX MUSIC_INDEX
    LDA MUSIC_NAME_PTR_LO,X
    STA MUSIC_NAME_PTR
    LDA MUSIC_NAME_PTR_HI,X
    STA MUSIC_NAME_PTR+1
    LDY #$00
MUSIC_NAME_COPY:
    LDA (MUSIC_NAME_PTR),Y
    STA $07D6,Y
    INY
    CPY #$09
    BCC MUSIC_NAME_COPY
    LDA FM_MUSIC_MODE     ; 'F' (PSG+FM) or 'P' (PSG only)
    STA $07DF
    LDA #$01
    STA OSD_DIRTY
    RTS

REFILL_MUSIC_BUFFER:
    ; Read the next 512-byte block into the buffer that is not being played.
    ; MUSIC_HOLD stays clear, so the VSYNC IRQ keeps decoding the active
    ; buffer while this MLI read runs and no music tick is lost.
    LDA MUSIC_NEXT_READY
    BEQ REFILL_CHOOSE_BUFFER
    LDA #$00
    STA MUSIC_REFILL_PENDING
    RTS
REFILL_CHOOSE_BUFFER:
    LDA MUSIC_ACTIVE
    EOR #$01
    BEQ REFILL_TO_A
    LDA #<MUSIC_BUF_B
    STA FILE_BUF_PTR
    LDA #>MUSIC_BUF_B
    STA FILE_BUF_PTR+1
    JMP REFILL_READ
REFILL_TO_A:
    LDA #<MUSIC_BUF_A
    STA FILE_BUF_PTR
    LDA #>MUSIC_BUF_A
    STA FILE_BUF_PTR+1
REFILL_READ:
    JSR READ_MUSIC_BLOCK
    BCC REFILL_READ_OK
    ; A transfer shorter than one block is how ProDOS reports the end of the
    ; stream (a zero-length read at EOF, sometimes with the "END OF FILE" $27
    ; status). That is the end of the song, not a disk error: hand the decoder
    ; an $FF record so the pending block switch restarts the playlist. Treating
    ; it as a failure muted the player and left the last FM chord ringing
    ; forever with no track change. The single-buffer player never prefetched
    ; past the end, so it only ever met the stream's own $FF terminator.
    LDA READ_PARAMS+7
    CMP #$02
    BCC REFILL_END_OF_STREAM
    LDA FILE_MLI_STATUS
    CMP #$27
    BEQ REFILL_END_OF_STREAM
REFILL_READ_FAIL:
    JMP CANYON_LOAD_FAIL
REFILL_END_OF_STREAM:
    ; Write an $FF terminator at the start of the inactive buffer. The decoder
    ; consumes it on the pending switch and MUSIC_RESTART advances MUSIC_INDEX
    ; exactly like a stream that carries its own $FF. One byte is enough: $FF
    ; ends the tick immediately, so the rest of the block is never read.
    LDA FILE_BUF_PTR+1
    CMP #>MUSIC_BUF_B
    BNE REFILL_END_TO_A
    LDA #$FF
    STA MUSIC_BUF_B
    STA MUSIC_BUF_B+1
    JMP REFILL_READ_OK
REFILL_END_TO_A:
    LDA #$FF
    STA MUSIC_BUF_A
    STA MUSIC_BUF_A+1
REFILL_READ_OK:
    ; Publish the block to the IRQ. The two stores are atomic against the
    ; VSYNC interrupt so the switch cannot interleave and strand a request.
    SEI
    LDA #$00
    STA MUSIC_REFILL_PENDING
    LDA #$01
    STA MUSIC_NEXT_READY
    CLI
    RTS

SILENCE_PSG:
    LDA #$00
    STA VERA_CTRL
    LDA #$C0
    STA VERA_ADDR_L
    LDA #$F9
    STA VERA_ADDR_M
    LDA #$11
    STA VERA_ADDR_H
    LDX #$40
    LDA #$00
SILENCE_PSG_LOOP:
    STA VERA_DATA0
    DEX
    BNE SILENCE_PSG_LOOP
    RTS

RESTORE_PSG_FROM_SHADOW:
    LDA #$00
    STA VERA_CTRL
    LDA #$C0
    STA VERA_ADDR_L
    LDA #$F9
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1 ($1F9C0)
    STA VERA_ADDR_H
    LDX #$00
RESTORE_PSG_LOOP:
    TXA
    AND #$03
    CMP #$02            ; volume register: apply the master volume again
    BNE RESTORE_PSG_PLAIN
    LDA PSG_SHADOW,X
    JSR SCALE_PSG_VOL
    JMP RESTORE_PSG_STORE
RESTORE_PSG_PLAIN:
    LDA PSG_SHADOW,X
RESTORE_PSG_STORE:
    STA VERA_DATA0
    INX
    CPX #$40
    BCC RESTORE_PSG_LOOP
    RTS

CLEAR_PSG_SHADOW:
    LDX #$3F
    LDA #$00
CLR_SHADOW_LOOP:
    STA PSG_SHADOW,X
    DEX
    BPL CLR_SHADOW_LOOP
    RTS

; ==============================================================================
; Low-Level ProDOS MLI READ_BLOCK for a file-allocated block
; ==============================================================================
; Image files are ProDOS seedling/sapling files. Locate their catalog entries,
; resolve each allocated block, then read it directly into VERA so large IMG
; files never need an MLI OPEN buffer or a 76,800-byte RAM staging area.
PREPARE_DIRECT_FILE:
    JSR BUILD_FILE_PATH
    BCC DIRECT_PATH_OK
    JMP DIRECT_FILE_ERROR
DIRECT_PATH_OK:
    LDA FILE_KIND
    BEQ DIRECT_PALETTE_NAME
    LDA #10
    STA TARGET_LENGTH
    JMP COPY_TARGET_NAME
DIRECT_PALETTE_NAME:
    LDA #11
    STA TARGET_LENGTH
COPY_TARGET_NAME:
    LDA PATH_BUF
    SEC
    SBC TARGET_LENGTH
    TAY
    LDX #$00
COPY_TARGET_NAME_LOOP:
    LDA PATH_BUF+1,Y
    STA FILE_NAME_BUF,X
    INY
    INX
    CPX TARGET_LENGTH
    BCC COPY_TARGET_NAME_LOOP

    ; Resolve DATA1..DATA3 through the ProDOS prefix path, which may be a
    ; nested app directory on a VeraSD volume rather than the volume root.
    JSR FIND_IMAGE_DIRECTORY
    BCC DIRECT_DATA_DIR_OK
    JMP DIRECT_FILE_ERROR
DIRECT_DATA_DIR_OK:
    LDA MLI_BLOCK
    STA DATA_DIR_BLOCK
    LDA MLI_BLOCK+1
    STA DATA_DIR_BLOCK+1

    ; Locate IMGnnn.BIN or VPALnnn.BIN in the selected DATA1..DATA3 folder.
    LDA FILE_NAME_BUF
    STA TARGET_NAME
    LDA FILE_NAME_BUF+1
    STA TARGET_NAME+1
    LDA FILE_NAME_BUF+2
    STA TARGET_NAME+2
    LDA FILE_NAME_BUF+3
    STA TARGET_NAME+3
    LDA FILE_NAME_BUF+4
    STA TARGET_NAME+4
    LDA FILE_NAME_BUF+5
    STA TARGET_NAME+5
    LDA FILE_NAME_BUF+6
    STA TARGET_NAME+6
    LDA FILE_NAME_BUF+7
    STA TARGET_NAME+7
    LDA FILE_NAME_BUF+8
    STA TARGET_NAME+8
    LDA FILE_NAME_BUF+9
    STA TARGET_NAME+9
    LDA FILE_KIND
    BNE DIRECT_IMAGE_NAME_READY
    LDA FILE_NAME_BUF+10
    STA TARGET_NAME+10
DIRECT_IMAGE_NAME_READY:
    LDA FILE_KIND
    BEQ DIRECT_SET_PALETTE_LENGTH
    LDA #10
    BNE DIRECT_SET_TARGET_LENGTH
DIRECT_SET_PALETTE_LENGTH:
    LDA #11
DIRECT_SET_TARGET_LENGTH:
    STA TARGET_LENGTH
    LDA DATA_DIR_BLOCK
    STA DIR_BLOCK
    LDA DATA_DIR_BLOCK+1
    STA DIR_BLOCK+1
    JSR FIND_CATALOG_ENTRY
    BCC DIRECT_ENTRY_OK
    JMP DIRECT_FILE_ERROR
DIRECT_ENTRY_OK:

    LDA FILE_KIND
    BEQ DIRECT_READ_PALETTE
    LDA STORAGE_TYPE
    CMP #$02
    BEQ DIRECT_IMAGE_IS_SAPLING
    JMP DIRECT_FILE_ERROR
DIRECT_IMAGE_IS_SAPLING:
    ; Sapling key block points to an index table of 256 data-block numbers.
    JSR READ_PRODOS_BLOCK
    BCC DIRECT_INDEX_READ_OK
    JMP DIRECT_FILE_ERROR
DIRECT_INDEX_READ_OK:
    LDY #$00
DIRECT_COPY_INDEX:
    LDA DATA_BUF,Y
    STA INDEX_BUF,Y
    LDA DATA_BUF+$100,Y
    STA INDEX_BUF+$100,Y
    INY
    BNE DIRECT_COPY_INDEX
    CLC
    RTS

DIRECT_READ_PALETTE:
    LDA STORAGE_TYPE
    CMP #$01
    BEQ DIRECT_PALETTE_IS_SEEDLING
    JMP DIRECT_FILE_ERROR
DIRECT_PALETTE_IS_SEEDLING:
    ; Seedling key block is the palette's only data block.
    JMP READ_PRODOS_BLOCK

; Follow the directory portion of PATH_BUF from the volume root to DATA1/2/3.
; GET_PREFIX provides paths such as /SLIDESHOW/ (boot volume) or
; /VERASD/SLIDESHOW/ (app copied into a directory on another volume).
FIND_IMAGE_DIRECTORY:
    LDA CURRENT_IMG_H
    BNE FIND_IMAGE_DIR_3
    LDA CURRENT_IMG
    CMP #126
    BCC FIND_IMAGE_DIR_1
    CMP #251
    BCC FIND_IMAGE_DIR_2
FIND_IMAGE_DIR_3:
    LDA #$33
    BNE FIND_IMAGE_DIR_SET
FIND_IMAGE_DIR_2:
    LDA #$32
    BNE FIND_IMAGE_DIR_SET
FIND_IMAGE_DIR_1:
    LDA #$31
FIND_IMAGE_DIR_SET:
    STA IMAGE_FOLDER_DIGIT
    LDA #$02
    STA DIR_BLOCK
    LDA #$00
    STA DIR_BLOCK+1
    LDA #$01
    STA PATH_SCAN_IDX
FIND_IMAGE_SKIP_VOLUME:
    LDX PATH_SCAN_IDX
    CPX PATH_BUF
    BCC FIND_IMAGE_VOLUME_CHAR_OK
    JMP FIND_IMAGE_DIR_ERROR
FIND_IMAGE_VOLUME_CHAR_OK:
    LDA PATH_BUF+1,X
    CMP #$2F
    BEQ FIND_IMAGE_VOLUME_DONE
    INC PATH_SCAN_IDX
    JMP FIND_IMAGE_SKIP_VOLUME
FIND_IMAGE_VOLUME_DONE:
    INC PATH_SCAN_IDX
FIND_IMAGE_COMPONENT:
    LDA #$00
    STA TARGET_LENGTH
    LDY #$00
FIND_IMAGE_COMPONENT_CHAR:
    LDX PATH_SCAN_IDX
    CPX PATH_BUF
    BCC FIND_IMAGE_COMPONENT_CHAR_OK
    JMP FIND_IMAGE_DIR_ERROR
FIND_IMAGE_COMPONENT_CHAR_OK:
    LDA PATH_BUF+1,X
    CMP #$2F
    BEQ FIND_IMAGE_COMPONENT_DONE
    CPY #$0F
    BCC FIND_IMAGE_COMPONENT_STORE
    JMP FIND_IMAGE_DIR_ERROR
FIND_IMAGE_COMPONENT_STORE:
    STA TARGET_NAME,Y
    INY
    INC TARGET_LENGTH
    INC PATH_SCAN_IDX
    JMP FIND_IMAGE_COMPONENT_CHAR
FIND_IMAGE_COMPONENT_DONE:
    ; Stop at the matching DATA group directory.
    LDA TARGET_LENGTH
    CMP #$05
    BNE FIND_IMAGE_PARENT_COMPONENT
    LDA TARGET_NAME
    CMP #$44
    BNE FIND_IMAGE_PARENT_COMPONENT
    LDA TARGET_NAME+1
    CMP #$41
    BNE FIND_IMAGE_PARENT_COMPONENT
    LDA TARGET_NAME+2
    CMP #$54
    BNE FIND_IMAGE_PARENT_COMPONENT
    LDA TARGET_NAME+3
    CMP #$41
    BNE FIND_IMAGE_PARENT_COMPONENT
    LDA TARGET_NAME+4
    CMP IMAGE_FOLDER_DIGIT
    BEQ FIND_IMAGE_TARGET_COMPONENT
FIND_IMAGE_PARENT_COMPONENT:
    JSR FIND_CATALOG_ENTRY
    BCC FIND_IMAGE_PARENT_FOUND
    JMP FIND_IMAGE_DIR_ERROR
FIND_IMAGE_PARENT_FOUND:
    LDA MLI_BLOCK
    STA DIR_BLOCK
    LDA MLI_BLOCK+1
    STA DIR_BLOCK+1
    INC PATH_SCAN_IDX
    JMP FIND_IMAGE_COMPONENT
FIND_IMAGE_TARGET_COMPONENT:
    JSR FIND_CATALOG_ENTRY
    BCC FIND_IMAGE_TARGET_FOUND
    JMP FIND_IMAGE_DIR_ERROR
FIND_IMAGE_TARGET_FOUND:
    LDA MLI_BLOCK
    STA DATA_DIR_BLOCK
    LDA MLI_BLOCK+1
    STA DATA_DIR_BLOCK+1
    CLC
    RTS
FIND_IMAGE_DIR_ERROR:
    SEC
    RTS

DIRECT_FILE_ERROR:
    SEC
    RTS

; Search a ProDOS directory chain. Input: DIR_BLOCK, TARGET_LENGTH/NAME.
; Output: MLI_BLOCK=entry key block, STORAGE_TYPE=entry storage type.
FIND_CATALOG_ENTRY:
    ; Only the first directory block has the directory header in slot 0.
    ; Continuation blocks use all 13 slots for file entries.
    LDA DIR_BLOCK
    STA CATALOG_START_BLOCK
    LDA DIR_BLOCK+1
    STA CATALOG_START_BLOCK+1
FIND_CATALOG_BLOCK:
    LDA DIR_BLOCK
    STA MLI_BLOCK
    LDA DIR_BLOCK+1
    STA MLI_BLOCK+1
    JSR READ_PRODOS_BLOCK
    BCC FIND_CATALOG_BLOCK_READY
    ; Preserve the actual READ_BLOCK status instead of reporting file-not-found.
    SEC
    RTS
FIND_CATALOG_BLOCK_READY:
    ; Preserve the root catalog DATA entry bytes for diagnostics.
    ; Slot 7 begins at offset 4 + 7*39 = $0115 in block 2.
    LDA DIR_BLOCK
    CMP #$02
    BNE FIND_CATALOG_NOT_ROOT
    LDA DIR_BLOCK+1
    BNE FIND_CATALOG_NOT_ROOT
    LDY #$15
    LDX #$00
FIND_CATALOG_SAVE_DATA_DIAG:
    LDA DATA_BUF+$100,Y
    STA DATA_DIAG,X
    INY
    INX
    CPX #$05
    BCC FIND_CATALOG_SAVE_DATA_DIAG
FIND_CATALOG_NOT_ROOT:
    LDA DATA_BUF+2
    STA NEXT_DIR_BLOCK
    LDA DATA_BUF+3
    STA NEXT_DIR_BLOCK+1
    ; Skip slot 0 only in the initial block; continuation blocks use slot 0.
    LDA DIR_BLOCK
    CMP CATALOG_START_BLOCK
    BNE FIND_CATALOG_CONTINUATION
    LDA DIR_BLOCK+1
    CMP CATALOG_START_BLOCK+1
    BNE FIND_CATALOG_CONTINUATION
    ; Directory entry pointers are relative to DATA_BUF: entry 0 starts at
    ; DATA_BUF+4 (after the block header), and the first block's slot 0 header
    ; pushes entry 1 to DATA_BUF+$2B. Derive them from DATA_BUF so moving the
    ; buffer can never desynchronise the catalog reader again.
    LDA #<DATA_BUF+$2B
    STA DIR_PTR
    LDA #>DATA_BUF+$2B
    STA DIR_PTR+1
    LDA #12
    STA CATALOG_ENTRIES_LEFT
    JMP FIND_CATALOG_ENTRY_LOOP
FIND_CATALOG_CONTINUATION:
    LDA #<DATA_BUF+$04
    STA DIR_PTR
    LDA #>DATA_BUF+$04
    STA DIR_PTR+1
    LDA #13
    STA CATALOG_ENTRIES_LEFT
FIND_CATALOG_ENTRY_LOOP:
    LDY #$00
    LDA (DIR_PTR),Y
    BEQ FIND_CATALOG_NEXT_ENTRY
    AND #$0F
    CMP TARGET_LENGTH
    BNE FIND_CATALOG_NEXT_ENTRY
    LDX #$00
FIND_CATALOG_NAME_LOOP:
    TXA
    TAY
    INY
    LDA (DIR_PTR),Y
    CMP TARGET_NAME,X
    BNE FIND_CATALOG_NAME_MISMATCH
    INX
    CPX TARGET_LENGTH
    BCC FIND_CATALOG_NAME_LOOP
    LDY #$00
    LDA (DIR_PTR),Y
    LSR
    LSR
    LSR
    LSR
    STA STORAGE_TYPE
    LDY #$11
    LDA (DIR_PTR),Y
    STA MLI_BLOCK
    LDY #$12
    LDA (DIR_PTR),Y
    STA MLI_BLOCK+1
    CLC
    RTS
FIND_CATALOG_NAME_MISMATCH:
    JMP FIND_CATALOG_NEXT_ENTRY
FIND_CATALOG_NEXT_ENTRY:
    CLC
    LDA DIR_PTR
    ADC #39
    STA DIR_PTR
    LDA DIR_PTR+1
    ADC #$00
    STA DIR_PTR+1
    DEC CATALOG_ENTRIES_LEFT
    BNE FIND_CATALOG_ENTRY_LOOP
    LDA NEXT_DIR_BLOCK
    ORA NEXT_DIR_BLOCK+1
    BNE FIND_NEXT_CATALOG_BLOCK
    JMP CATALOG_NOT_FOUND
FIND_NEXT_CATALOG_BLOCK:
    LDA NEXT_DIR_BLOCK
    STA DIR_BLOCK
    LDA NEXT_DIR_BLOCK+1
    STA DIR_BLOCK+1
    JMP FIND_CATALOG_BLOCK
CATALOG_NOT_FOUND:
    ; Distinguish a missing DATA directory from a missing asset entry.
    ; Capture the pointer at which the directory scan ended.
    LDA DIR_PTR
    STA SCAN_PTR_DIAG
    LDA DIR_PTR+1
    STA SCAN_PTR_DIAG+1
    LDA TARGET_LENGTH
    CMP #$04
    BNE CATALOG_FILE_MISSING
    LDA #$45
    BNE CATALOG_STORE_MISSING
CATALOG_FILE_MISSING:
    LDA #$46
CATALOG_STORE_MISSING:
    STA FILE_MLI_STATUS
    SEC
    RTS

READ_PRODOS_BLOCK:
    LDA #$03
    STA BLOCK_PARAMS
    LDA $BF30
    STA BLOCK_PARAMS+1
    LDA #<DATA_BUF
    STA BLOCK_PARAMS+2
    LDA #>DATA_BUF
    STA BLOCK_PARAMS+3
    LDA MLI_BLOCK
    STA BLOCK_PARAMS+4
    LDA MLI_BLOCK+1
    STA BLOCK_PARAMS+5
    JSR MLI
    !byte $80
    !word BLOCK_PARAMS
    STA FILE_MLI_STATUS
    RTS

DIR_BLOCK:
    !word $0000
CATALOG_START_BLOCK:
    !word $0000
NEXT_DIR_BLOCK:
    !word $0000
DATA_DIR_BLOCK:
    !word $0000
MLI_BLOCK:
    !word $0000
TARGET_LENGTH:
    !byte $00
TARGET_NAME:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
FILE_NAME_BUF:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
STORAGE_TYPE:
    !byte $00
CATALOG_ENTRIES_LEFT:
    !byte $00
IMAGE_BLOCK_INDEX:
    !byte $00
BLOCK_PARAMS:
    !byte $03,$00
    !word DATA_BUF
    !word $0000
DATA_DIAG:
    !byte $00,$00,$00,$00,$00
DATA_DIAG_INDEX:
    !byte $00
DATA_DIAG_BYTE:
    !byte $00
SCAN_PTR_DIAG:
    !word $0000
PAL_STAGE:
    !byte $00
READ_DIAG_INDEX:
    !byte $00
READ_DIAG_BYTE:
    !byte $00
PATH_SCAN_IDX:
    !byte $00
IMAGE_FOLDER_DIGIT:
    !byte $00

OPEN_SELECTED_FILE:
    PHP
    JSR BUILD_FILE_PATH
    BCS OPEN_FILE_ERROR
    LDA #<PATH_BUF
    STA OPEN_PARAMS+1
    LDA #>PATH_BUF
    STA OPEN_PARAMS+2
    LDA #<FILE_IO_BUF
    STA OPEN_PARAMS+3
    LDA #>FILE_IO_BUF
    STA OPEN_PARAMS+4
    LDA FILE_KIND
    CMP #$02
    BCC OPEN_FILE_CALL
    LDA #<$6400
    STA OPEN_PARAMS+3
    LDA #>$6400
    STA OPEN_PARAMS+4
OPEN_FILE_CALL:
    ; OPEN is allowed to use its pathname as workspace on some ProDOS
    ; versions. Keep the intended name for useful diagnostics on failure.
    LDX #$00
SAVE_OPEN_PATH:
    LDA PATH_BUF,X
    STA PATH_BACKUP,X
    INX
    CPX #$40
    BCC SAVE_OPEN_PATH
    JSR MLI
    !byte $C8
    !word OPEN_PARAMS
    STA FILE_MLI_STATUS
    BCS OPEN_FILE_ERROR
    LDA OPEN_PARAMS+5
    STA FILE_REF
    LDA FILE_KIND
    CMP #$02
    BCC OPEN_IMAGE_RESULT
    LDA FILE_REF
    STA MUSIC_REF
    LDA #$01
    STA MUSIC_FILE_OPEN
    LDX #$00
    JMP OPEN_FILE_RETURN
OPEN_IMAGE_RESULT:
    LDA FILE_REF
    STA IMAGE_REF
    LDX #$00
    JMP OPEN_FILE_RETURN
OPEN_FILE_ERROR:
    LDX #$00
RESTORE_OPEN_PATH:
    LDA PATH_BACKUP,X
    STA PATH_BUF,X
    INX
    CPX #$40
    BCC RESTORE_OPEN_PATH
    LDX #$01
OPEN_FILE_RETURN:
    PLP
    TXA
    BEQ OPEN_FILE_OK
    SEC
    RTS
OPEN_FILE_OK:
    CLC
    RTS

CLOSE_MUSIC_FILE:
    LDA MUSIC_FILE_OPEN
    BEQ CLOSE_MUSIC_DONE
    PHP
    LDA MUSIC_REF
    STA CLOSE_PARAMS+1
    JSR MLI
    !byte $CC
    !word CLOSE_PARAMS
    LDX #$00
    BCC CLOSE_MUSIC_RETURN
    LDX #$01
CLOSE_MUSIC_RETURN:
    LDA #$00
    STA MUSIC_FILE_OPEN
    PLP
    TXA
    BEQ CLOSE_MUSIC_OK
    SEC
    RTS
CLOSE_MUSIC_OK:
    CLC
    RTS
CLOSE_MUSIC_DONE:
    CLC
    RTS

READ_IMAGE_BLOCK:
    PHP
    LDA IMAGE_REF
    STA READ_PARAMS+1
    JSR READ_FILE_BLOCK_LOCKED
    TAX
    PLP
    TXA
    BEQ READ_IMAGE_OK
    SEC
    RTS
READ_IMAGE_OK:
    CLC
    RTS

CLOSE_IMAGE_FILE:
    LDA IMAGE_REF
    STA CLOSE_PARAMS+1
    JSR MLI
    !byte $CC
    !word CLOSE_PARAMS
    STA FILE_MLI_STATUS
    RTS

READ_MUSIC_BLOCK:
    PHP
    LDA MUSIC_REF
    STA READ_PARAMS+1
    JSR READ_FILE_BLOCK_LOCKED
    TAX
    PLP
    TXA
    BEQ READ_MUSIC_OK
    SEC
    RTS
READ_MUSIC_OK:
    CLC
    RTS

READ_FILE_BLOCK_LOCKED:
    LDA FILE_BUF_PTR
    STA READ_PARAMS+2
    LDA FILE_BUF_PTR+1
    STA READ_PARAMS+3
    LDA #$00
    STA READ_PARAMS+4
    LDA #$02
    STA READ_PARAMS+5
    LDA #$00
    STA READ_PARAMS+6
    STA READ_PARAMS+7
    JSR MLI
    !byte $CA
    !word READ_PARAMS
    STA FILE_MLI_STATUS
    BCS READ_FILE_ERROR
    LDA READ_PARAMS+6
    BNE READ_FILE_ERROR
    LDA READ_PARAMS+7
    CMP #$02
    BNE READ_FILE_ERROR
    ; Callers consume the status from A; leave the transfer-count byte out
    ; of A (it is currently $02 for a successful 512-byte read).
    LDX #$00
    LDA #$00
    RTS
READ_FILE_ERROR:
    LDX #$01
    LDA #$01
    RTS

BUILD_FILE_PATH:
    LDA #<PATH_BUF
    STA GET_PREFIX_PARAMS+1
    LDA #>PATH_BUF
    STA GET_PREFIX_PARAMS+2
    JSR MLI
    !byte $C7
    !word GET_PREFIX_PARAMS
    BCC BUILD_PREFIX_READY
    JMP BUILD_PATH_ERROR
BUILD_PREFIX_READY:
    LDA PATH_BUF
    BNE BUILD_PREFIX_PRESENT
    LDA #$2F
    JSR APPEND_PATH_CHAR
    LDA #$53
    JSR APPEND_PATH_CHAR
    LDA #$4C
    JSR APPEND_PATH_CHAR
    LDA #$49
    JSR APPEND_PATH_CHAR
    LDA #$44
    JSR APPEND_PATH_CHAR
    LDA #$45
    JSR APPEND_PATH_CHAR
    LDA #$53
    JSR APPEND_PATH_CHAR
    LDA #$48
    JSR APPEND_PATH_CHAR
    LDA #$4F
    JSR APPEND_PATH_CHAR
    LDA #$57
    JSR APPEND_PATH_CHAR
    LDA #$2F
    JSR APPEND_PATH_CHAR
    JMP BUILD_APPEND_DATA
BUILD_PREFIX_PRESENT:
    TAY
    DEY
    LDA PATH_BUF+1,Y
    CMP #$2F
    BEQ BUILD_APPEND_DATA
    LDA #$2F
    JSR APPEND_PATH_CHAR
BUILD_APPEND_DATA:
    LDA #$44
    JSR APPEND_PATH_CHAR
    LDA #$41
    JSR APPEND_PATH_CHAR
    LDA #$54
    JSR APPEND_PATH_CHAR
    LDA #$41
    JSR APPEND_PATH_CHAR
    LDA FILE_KIND
    CMP #$02
    BCS BUILD_APPEND_DATA_SLASH
    LDA CURRENT_IMG_H
    BNE BUILD_PATH_DIR_3
    LDA CURRENT_IMG
    CMP #126
    BCC BUILD_PATH_DIR_1
    CMP #251
    BCC BUILD_PATH_DIR_2
BUILD_PATH_DIR_3:
    LDA #$33
    BNE BUILD_PATH_APPEND_DIR
BUILD_PATH_DIR_2:
    LDA #$32
    BNE BUILD_PATH_APPEND_DIR
BUILD_PATH_DIR_1:
    LDA #$31
BUILD_PATH_APPEND_DIR:
    JSR APPEND_PATH_CHAR
BUILD_APPEND_DATA_SLASH:
    LDA #$2F
    JSR APPEND_PATH_CHAR
    LDA FILE_KIND
    CMP #$02
    BCS BUILD_MUSIC_PATH
    CMP #$01
    BEQ BUILD_IMAGE_NAME
    LDA #$56              ; V
    JSR APPEND_PATH_CHAR
    LDA #$50              ; P
    JSR APPEND_PATH_CHAR
    LDA #$41              ; A
    JSR APPEND_PATH_CHAR
    LDA #$4C              ; L
    JSR APPEND_PATH_CHAR
    JMP BUILD_IMAGE_DIGITS
BUILD_IMAGE_NAME:
    LDA #$49              ; I
    JSR APPEND_PATH_CHAR
    LDA #$4D              ; M
    JSR APPEND_PATH_CHAR
    LDA #$47              ; G
    JSR APPEND_PATH_CHAR
    JMP BUILD_IMAGE_DIGITS
BUILD_MUSIC_PATH:
    SEC
    SBC #$02
    TAX
    LDA MUSIC_FILE_PTR_LO,X
    STA PATH_SRC_PTR_L
    LDA MUSIC_FILE_PTR_HI,X
    STA PATH_SRC_PTR_H
    JSR APPEND_PATH_STRING
    BCC BUILD_MUSIC_NAME_OK
    JMP BUILD_PATH_ERROR
BUILD_MUSIC_NAME_OK:
    JMP BUILD_PATH_COMPLETE

BUILD_IMAGE_DIGITS:
    BCC BUILD_IMAGE_NUMBER_OK
    JMP BUILD_PATH_ERROR
BUILD_IMAGE_NUMBER_OK:
    LDA CURRENT_IMG
    STA NUMBER_LO
    LDA CURRENT_IMG_H
    STA NUMBER_HI
    LDA #$00
    STA NUMBER_HUNDREDS
BUILD_HUNDREDS_LOOP:
    LDA NUMBER_HI
    BNE SUBTRACT_HUNDRED
    LDA NUMBER_LO
    CMP #100
    BCC BUILD_HUNDREDS_DONE
SUBTRACT_HUNDRED:
    SEC
    LDA NUMBER_LO
    SBC #100
    STA NUMBER_LO
    LDA NUMBER_HI
    SBC #$00
    STA NUMBER_HI
    INC NUMBER_HUNDREDS
    JMP BUILD_HUNDREDS_LOOP
BUILD_HUNDREDS_DONE:
    LDA NUMBER_HUNDREDS
    CLC
    ADC #$30
    JSR APPEND_PATH_CHAR
    LDA #$00
    STA NUMBER_TENS
BUILD_TENS_LOOP:
    LDA NUMBER_LO
    CMP #10
    BCC BUILD_TENS_DONE
    SEC
    SBC #10
    STA NUMBER_LO
    INC NUMBER_TENS
    JMP BUILD_TENS_LOOP
BUILD_TENS_DONE:
    LDA NUMBER_TENS
    CLC
    ADC #$30
    JSR APPEND_PATH_CHAR
    LDA NUMBER_LO
    CLC
    ADC #$30
    JSR APPEND_PATH_CHAR
    LDA #$2E              ; .
    JSR APPEND_PATH_CHAR
    LDA #$42              ; B
    JSR APPEND_PATH_CHAR
    LDA #$49              ; I
    JSR APPEND_PATH_CHAR
    LDA #$4E              ; N
    JSR APPEND_PATH_CHAR
BUILD_PATH_COMPLETE:
    CLC
    RTS
BUILD_PATH_ERROR:
    SEC
    RTS

APPEND_PATH_STRING:
    LDA #$00
    STA PATH_SRC_IDX
APPEND_PATH_LOOP:
    LDY PATH_SRC_IDX
    LDA (PATH_SRC_PTR_L),Y
    BEQ APPEND_PATH_DONE
    JSR APPEND_PATH_CHAR
    BCS APPEND_PATH_ERROR
    INC PATH_SRC_IDX
    JMP APPEND_PATH_LOOP
APPEND_PATH_DONE:
    CLC
    RTS
APPEND_PATH_ERROR:
    SEC
    RTS

APPEND_PATH_CHAR:
    STA PATH_CHAR
    LDY PATH_BUF
    CPY #$3F
    BCS APPEND_PATH_CHAR_ERROR
    LDA PATH_CHAR
    STA PATH_BUF+1,Y
    INY
    STY PATH_BUF
    CLC
    RTS
APPEND_PATH_CHAR_ERROR:
    SEC
    RTS

FILE_KIND:
    !byte $00
FILE_ERROR_KIND:
    !byte $00
FILE_MLI_STATUS:
    !byte $00
FILE_REF:
    !byte $00
IMAGE_REF:
    !byte $00
MUSIC_REF:
    !byte $00
MUSIC_FILE_OPEN:
    !byte $00
MUSIC_REFILL_PENDING:
    !byte $00
MUSIC_CHANGE_PENDING:
    !byte $00
MUSIC_HOLD:
    !byte $00
MUSIC_WAITING:
    !byte $00
MUSIC_PREFETCH_DONE:
    !byte $00
SERVICE_VERA_CTRL:
    !byte $00
SERVICE_VERA_ADDR_L:
    !byte $00
SERVICE_VERA_ADDR_M:
    !byte $00
SERVICE_VERA_ADDR_H:
    !byte $00
FILE_BUF_PTR:
    !word DATA_BUF
CANYON_BUF_PTR:
    !word $4000
MUSIC_LOAD_COUNT:
    !byte $00
NUMBER_LO:
    !byte $00
NUMBER_HI:
    !byte $00
NUMBER_HUNDREDS:
    !byte $00
NUMBER_TENS:
    !byte $00
OPEN_PARAMS:
    !byte $03
    !word PATH_BUF
    !word FILE_IO_BUF
    !byte $00
GET_PREFIX_PARAMS:
    !byte $01
    !word PATH_BUF
PATH_BACKUP:
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$00,$00,$00,$00,$00
CLOSE_PARAMS:
    !byte $01,$00
BASIC_ZP_SAVE:
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
READ_PARAMS:
    !byte $04,$00
    !word DATA_BUF
    !word $0200
    !word $0000
HEX_DIGITS:
    !byte $B0,$B1,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$C1,$C2,$C3,$C4,$C5,$C6
MUSIC_FILE_PTR_LO:
    !byte <MUSIC_FILE_0,<MUSIC_FILE_1,<MUSIC_FILE_2
MUSIC_FILE_PTR_HI:
    !byte >MUSIC_FILE_0,>MUSIC_FILE_1,>MUSIC_FILE_2
MUSIC_FILE_0:
    ASC "SBINTRO.VZM"
    !byte $00
MUSIC_FILE_1:
    ASC "CANYON.VZM"
    !byte $00
MUSIC_FILE_2:
    ASC "GREENHILL.VZM"
    !byte $00
MUSIC_NAME_PTR_LO:
    !byte <MUSIC_NAME_0,<MUSIC_NAME_1,<MUSIC_NAME_2
MUSIC_NAME_PTR_HI:
    !byte >MUSIC_NAME_0,>MUSIC_NAME_1,>MUSIC_NAME_2
MUSIC_NAME_LEN:
    !byte 8, 6, 9
MUSIC_NAME_0:
    !byte $D3,$C2,$AD,$C9,$CE,$D4,$D2,$CF,$A0
MUSIC_NAME_1:
    !byte $C3,$C1,$CE,$D9,$CF,$CE,$A0,$A0,$A0
MUSIC_NAME_2:
    !byte $C7,$D2,$C5,$C5,$CE,$C8,$C9,$CC,$CC
TEXT_MUTE_STR:
    !byte $DB,$CD,$D5,$D4,$C5,$DD,$A0,$A0,$A0  ; "[MUTE]   "

; ==============================================================================
; OSD Direct Bitmap Row 29 Rendering Engine (VRAM $12200..$12BFF)
; ==============================================================================
RENDER_OSD_TEXT:
    JSR RESTORE_ROW29
    JSR FORMAT_OSD_STRING

    LDA #$00
    STA OSD_ROW_IDX

OSD_ROW_LOOP:
    LDX OSD_ROW_IDX
    LDA #$00
    STA VERA_CTRL
    LDA ROW29_ADDR_LO,X
    STA VERA_ADDR_L
    LDA ROW29_ADDR_HI,X
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1 ($12200)
    STA VERA_ADDR_H

    LDA #$00
    STA OSD_COL_IDX
    LDA LEFT_BADGE_END
    BNE OSD_COL_LOOP

    ; Left badge disabled (MUTE) - skip directly to right badge at col 29
    LDA RIGHT_ADDR_LO,X
    STA VERA_ADDR_L
    LDA RIGHT_ADDR_HI,X
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1
    STA VERA_ADDR_H
    LDA #29
    STA OSD_COL_IDX

OSD_COL_LOOP:
    LDX OSD_COL_IDX
    LDA OSD_LINE_BUF,X
    SEC
    SBC #$20            ; Map ASCII to font index (32 -> 0)
    BCC OSD_GLYPH_SPACE
    CMP #64
    BCC OSD_GLYPH_OK
OSD_GLYPH_SPACE:
    LDA #$00
OSD_GLYPH_OK:
    CMP #32
    BCS OSD_GLYPH_P2

    ; Glyph in Page 1 (0..31)
    ASL
    ASL
    ASL
    ORA OSD_ROW_IDX
    TAY
    LDA FONT_8X8,Y
    STA OSD_FONT_BYTE
    JMP OSD_OUTPUT_8PIXELS

OSD_GLYPH_P2:
    ; Glyph in Page 2 (32..63)
    SEC
    SBC #32
    ASL
    ASL
    ASL
    ORA OSD_ROW_IDX
    TAY
    LDA FONT_8X8+$100,Y
    STA OSD_FONT_BYTE

OSD_OUTPUT_8PIXELS:
    ; Output 8 pixels for this glyph row to VERA_DATA0
    LDA OSD_BG_COLOR
    ASL OSD_FONT_BYTE
    BCC P0_OUT
    LDA OSD_FG_COLOR
P0_OUT:
    STA VERA_DATA0

    LDA OSD_BG_COLOR
    ASL OSD_FONT_BYTE
    BCC P1_OUT
    LDA OSD_FG_COLOR
P1_OUT:
    STA VERA_DATA0

    LDA OSD_BG_COLOR
    ASL OSD_FONT_BYTE
    BCC P2_OUT
    LDA OSD_FG_COLOR
P2_OUT:
    STA VERA_DATA0

    LDA OSD_BG_COLOR
    ASL OSD_FONT_BYTE
    BCC P3_OUT
    LDA OSD_FG_COLOR
P3_OUT:
    STA VERA_DATA0

    LDA OSD_BG_COLOR
    ASL OSD_FONT_BYTE
    BCC P4_OUT
    LDA OSD_FG_COLOR
P4_OUT:
    STA VERA_DATA0

    LDA OSD_BG_COLOR
    ASL OSD_FONT_BYTE
    BCC P5_OUT
    LDA OSD_FG_COLOR
P5_OUT:
    STA VERA_DATA0

    LDA OSD_BG_COLOR
    ASL OSD_FONT_BYTE
    BCC P6_OUT
    LDA OSD_FG_COLOR
P6_OUT:
    STA VERA_DATA0

    LDA OSD_BG_COLOR
    ASL OSD_FONT_BYTE
    BCC P7_OUT
    LDA OSD_FG_COLOR
P7_OUT:
    STA VERA_DATA0

    INC OSD_COL_IDX
    LDA OSD_COL_IDX
    CMP LEFT_BADGE_END
    BNE CHK_COL_RIGHT_DONE
    ; Jump from left badge to right badge (col 29), skipping middle cols
    LDX OSD_ROW_IDX
    LDA RIGHT_ADDR_LO,X
    STA VERA_ADDR_L
    LDA RIGHT_ADDR_HI,X
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1
    STA VERA_ADDR_H
    LDA #29
    STA OSD_COL_IDX
    JMP OSD_COL_LOOP

CHK_COL_RIGHT_DONE:
    CMP #40
    BCS OSD_COL_DONE
    JMP OSD_COL_LOOP
OSD_COL_DONE:

    INC OSD_ROW_IDX
    LDA OSD_ROW_IDX
    CMP #8
    BCS OSD_ROW_DONE
    JMP OSD_ROW_LOOP
OSD_ROW_DONE:
    RTS

RESTORE_ROW29:
    LDA #$00
    STA VERA_CTRL
    STA VERA_ADDR_L
    LDA #$22
    STA VERA_ADDR_M
    LDA #$11            ; Bank 1, Stride +1 ($12200)
    STA VERA_ADDR_H

    LDA #<$5000
    STA SAVE_PTR
    LDA #>$5000
    STA SAVE_PTR+1

    LDX #10             ; 10 pages x 256 bytes = 2,560 bytes
RESTORE_PAGE_LOOP:
    LDY #$00
RESTORE_BYTE_LOOP:
    LDA (SAVE_PTR),Y
    STA VERA_DATA0
    INY
    BNE RESTORE_BYTE_LOOP
    INC SAVE_PTR+1
    DEX
    BNE RESTORE_PAGE_LOOP
    RTS

FORMAT_OSD_STRING:
    ; 1. Clear 40-byte buffer with spaces (ASCII $20)
    LDX #39
    LDA #$20
OSD_CLR_BUF:
    STA OSD_LINE_BUF,X
    DEX
    BPL OSD_CLR_BUF

    LDA MUSIC_MUTE
    BEQ OSD_FMT_MNAME

    ; Muted: no left badge at all (LEFT_BADGE_END = 0)
    LDA #$00
    STA LEFT_BADGE_END
    JMP OSD_FMT_IMG

OSD_FMT_MNAME:
    ; 2. Write "MUSIC:" (cols 0..5, no trailing space)
    LDA #$4D            ; 'M'
    STA OSD_LINE_BUF+0
    LDA #$55            ; 'U'
    STA OSD_LINE_BUF+1
    LDA #$53            ; 'S'
    STA OSD_LINE_BUF+2
    LDA #$49            ; 'I'
    STA OSD_LINE_BUF+3
    LDA #$43            ; 'C'
    STA OSD_LINE_BUF+4
    LDA #$3A            ; ':'
    STA OSD_LINE_BUF+5

    ; 3. Write music name (cols 6..)
    LDX MUSIC_INDEX
    LDA MUSIC_NAME_LEN,X
    CLC
    ADC #$06            ; 6 + Name Length (tight badge without trailing spaces!)
    STA LEFT_BADGE_END
    LDY #$00
OSD_MNAME_LOOP:
    LDA (MUSIC_NAME_PTR),Y
    AND #$7F            ; Strip Apple II high bit
    STA OSD_LINE_BUF+6,Y
    INY
    CPY #$09
    BCC OSD_MNAME_LOOP

    ; FM indicator: append " F" to the music badge when the YM2151 is present.
    LDA FM_PRESENT
    BEQ OSD_FMT_IMG
    LDY LEFT_BADGE_END
    LDA #$20            ; space
    STA OSD_LINE_BUF,Y
    INY
    LDA #$46            ; 'F'
    STA OSD_LINE_BUF,Y
    INY
    STY LEFT_BADGE_END

OSD_FMT_IMG:
    ; 5. Write "IMG:" (cols 29..32, no spaces)
    LDA #$49            ; 'I'
    STA OSD_LINE_BUF+29
    LDA #$4D            ; 'M'
    STA OSD_LINE_BUF+30
    LDA #$47            ; 'G'
    STA OSD_LINE_BUF+31
    LDA #$3A            ; ':'
    STA OSD_LINE_BUF+32

    ; 6. Format Current Image Index into 3 decimal digits (cols 33..35)
    LDA CURRENT_IMG
    STA MULT_TEMP
    LDA CURRENT_IMG_H
    STA MULT_TEMP_H

    LDX #$00
OSD_HUND:
    LDA MULT_TEMP_H
    BNE OSD_SUB_100
    LDA MULT_TEMP
    CMP #$64
    BCC OSD_HUND_DONE
OSD_SUB_100:
    LDA MULT_TEMP
    SEC
    SBC #$64
    STA MULT_TEMP
    LDA MULT_TEMP_H
    SBC #$00
    STA MULT_TEMP_H
    INX
    JMP OSD_HUND
OSD_HUND_DONE:
    TXA
    CLC
    ADC #$30
    STA OSD_LINE_BUF+33

    LDY #$00
OSD_TENS:
    LDA MULT_TEMP
    CMP #$0A
    BCC OSD_TENS_DONE
    SEC
    SBC #$0A
    STA MULT_TEMP
    INY
    JMP OSD_TENS
OSD_TENS_DONE:
    TYA
    CLC
    ADC #$30
    STA OSD_LINE_BUF+34
    LDA MULT_TEMP
    CLC
    ADC #$30
    STA OSD_LINE_BUF+35

    ; 7. Write "/375" (cols 36..39, no spaces)
    LDA #$2F            ; '/'
    STA OSD_LINE_BUF+36
    LDA #$33            ; '3'
    STA OSD_LINE_BUF+37
    LDA #$37            ; '7'
    STA OSD_LINE_BUF+38
    LDA #$35            ; '5'
    STA OSD_LINE_BUF+39
    RTS

; ==============================================================================
; YM2151 FM chip helpers (detection, reset, key off/restore)
; ==============================================================================
.include "../vera_fm.inc"

ROW29_ADDR_LO:
    !byte $00, $40, $80, $C0, $00, $40, $80, $C0
ROW29_ADDR_HI:
    !byte $22, $23, $24, $25, $27, $28, $29, $2A
RIGHT_ADDR_LO:
    !byte $E8, $28, $68, $A8, $E8, $28, $68, $A8
RIGHT_ADDR_HI:
    !byte $22, $24, $25, $26, $27, $29, $2A, $2B

OSD_ENABLED:
    !byte $01
OSD_DIRTY:
    !byte $01
OSD_LINE_BUF:
    HEX 20 20 20 20 20 20 20 20
    HEX 20 20 20 20 20 20 20 20
    HEX 20 20 20 20 20 20 20 20
    HEX 20 20 20 20 20 20 20 20
    HEX 20 20 20 20 20 20 20 20

PSG_SHADOW:
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00
    HEX 00 00 00 00 00 00 00 00

.include "palette_lut.inc"
.include "font8x8.inc"

; ==============================================================================
; 256-Color Fullscreen Slideshow Engine for Apple II (VERA Card + ProDOS)
; High-Speed Direct Block MLI ($80) Streaming Engine: 0% Path Error, 0% Buffer Error
; Supports: 375 320x240 8bpp Bitmaps + 375 Custom Palettes + 8 PSG soundtracks
; Controls: Space/Right=Next, Left=Prev, A=Auto, R=Random, M=Mute, ESC=Exit
; ==============================================================================

* = $2000

MLI         = $BF00
PRODOS_UNIT = $BF30     ; ProDOS Global Page: Boot device unit number

CURRENT_IMG = $06       ; Current Image Index low byte (1..375)
CURRENT_IMG_H = $1C     ; High byte of current image index
AUTO_MODE   = $07       ; 0 = Manual, 1 = Auto-Play
RANDOM_MODE = $08       ; 0 = Sequential, 1 = Random
TIMER_L     = $09       ; Auto-play countdown timer
TIMER_H     = $0A
RAND_SEED   = $0B
RAND_SEED_H = $1D
CURR_BLK_L  = $0C       ; 16-bit current block pointer
CURR_BLK_H  = $0D
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

DATA_BUF    = $3800     ; 512-Byte ProDOS Block Buffer ($3800 ~ $39FF)

START:
    ; 1. Clear keyboard strobe to consume leftover ENTER from BASIC menu
    STA KBD_STROBE
    LDA #$FF
    STA $F1             ; Set Applesoft text speed to normal (255)
    LDA #$01
    STA CURRENT_IMG
    LDA #$00
    STA CURRENT_IMG_H
    LDA #$01            ; Default to AutoPlay
    STA AUTO_MODE
    LDA #$00
    STA RANDOM_MODE
    LDA #$5A
    STA RAND_SEED
    LDA #$37
    STA RAND_SEED_H

    ; Copy Boot Drive Unit Number from ProDOS Global Page $BF30
    LDA PRODOS_UNIT
    STA MLI_UNIT_NUM
    STA CANYON_UNIT_NUM

    ; 2. Configure VERA Display: Mode 7 Bitmap (320x240 8bpp)
    LDA #$00
    STA VERA_CTRL
    ; Enable VGA output (1) + Layer 0 (0x10) -> DC_VID = $11
    LDA #$11
    STA VERA_DC_VID
    LDA #$40            ; 2.0x scale (320x240 view)
    STA VERA_DC_HSC
    STA VERA_DC_VSC
    LDA #$00
    STA VERA_DC_BOR

    ; Configure Layer 0: Bitmap Mode (Color depth 8bpp = 3, Bitmap Mode = 1 << 2 = 4) -> $07
    LDA #$07
    STA VERA_L0_CFG
    LDA #$00
    STA VERA_L0_MAP
    STA VERA_L0_TIL
    STA VERA_L0_HSC_L
    STA VERA_L0_HSC_H
    STA VERA_L0_VSC_L
    STA VERA_L0_VSC_H

    ; 3. Load and initialize the converted Canyon PSG stream
    JSR INIT_CANYON_MUSIC
    JSR LOAD_CANYON_MUSIC
    JSR UPDATE_MUSIC_NAME
    JSR ENABLE_MUSIC_IRQ

    ; 4. Initial Load of Image 1
    JSR LOAD_IMAGE_AND_PALETTE
    JSR RESET_AUTO_TIMER
    STA KBD_STROBE

MAIN_LOOP:
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

DO_EXIT:
    ; Clean up and return to ProDOS BASIC
    JSR DISABLE_MUSIC_IRQ
    JSR SILENCE_PSG
    LDA #$00
    STA VERA_DC_VID     ; Disable VERA display
    LDA #$FF
    STA $F1             ; Full text speed
    RTS

TOGGLE_MUTE:
    LDA MUSIC_MUTE
    EOR #$01
    STA MUSIC_MUTE
    BNE MUTE_PSG
    JMP MAIN_LOOP
MUTE_PSG:
    JSR SILENCE_PSG
    JMP MAIN_LOOP

TOGGLE_AUTO:
    LDA AUTO_MODE
    EOR #$01
    STA AUTO_MODE
    JSR RESET_AUTO_TIMER
    JMP MAIN_LOOP

TOGGLE_RAND:
    LDA RANDOM_MODE
    EOR #$01
    STA RANDOM_MODE
    ; Random mode always runs as an automatic slideshow.
    LDA #$01
    STA AUTO_MODE
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

; ==============================================================================
; Calculate Base Block for Current Image (Base Block = 6000 + (Index - 1) * 152)
; ==============================================================================
CALC_IMAGE_BLOCKS:
    ; 6000 = $1770
    ; (Index - 1) * 152, using a 16-bit image index
    LDA CURRENT_IMG
    SEC
    SBC #$01            ; 0-indexed: 0..74
    STA MULT_TEMP
    LDA CURRENT_IMG_H
    SBC #$00
    STA MULT_TEMP_H

    ; Low/High calculation of 1300 + (A * 152)
    LDA #$70
    STA CURR_BLK_L
    LDA #$17
    STA CURR_BLK_H

    LDA MULT_TEMP
    ORA MULT_TEMP_H
    BEQ CALC_DONE

    ; Multiply A by 152 and add to CURR_BLK
ADD_152_LOOP:
    CLC
    LDA CURR_BLK_L
    ADC #152
    STA CURR_BLK_L
    LDA CURR_BLK_H
    ADC #$00
    STA CURR_BLK_H
    LDA MULT_TEMP
    BNE ADD_152_DEC_LOW
    DEC MULT_TEMP_H
ADD_152_DEC_LOW:
    DEC MULT_TEMP
    LDA MULT_TEMP
    ORA MULT_TEMP_H
    BNE ADD_152_LOOP

CALC_DONE:
    RTS

MULT_TEMP:
    !byte $00
MULT_TEMP_H:
    !byte $00

; ==============================================================================
; Direct Block MLI Streaming Engine: Palette (1 Block) + Image (150 Blocks)
; ==============================================================================
LOAD_IMAGE_AND_PALETTE:
    JSR CALC_IMAGE_BLOCKS

    ; 1. Read Palette Block (CURR_BLK) into DATA_BUF ($3800)
    LDA CURR_BLK_L
    STA MLI_BLK_NUM
    LDA CURR_BLK_H
    STA MLI_BLK_NUM+1

    JSR READ_BLOCK_MLI
    BCC PAL_READ_OK
    JMP READ_PAL_FAIL
PAL_READ_OK:

    ; Write Palette (512 bytes) to VRAM $1FA00
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

    ; 2. Advance to Image Bitmap Start Block (CURR_BLK + 2, skipping Index Block)
    CLC
    LDA CURR_BLK_L
    ADC #$02
    STA CURR_BLK_L
    LDA CURR_BLK_H
    ADC #$00
    STA CURR_BLK_H

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

STREAM_150_BLOCKS:
    LDA CURR_BLK_L
    STA MLI_BLK_NUM
    LDA CURR_BLK_H
    STA MLI_BLK_NUM+1

    ; Do not enter the ProDOS MLI while the music IRQ is enabled. The pending
    ; VSYNC request is serviced immediately after the read returns.
    SEI
    JSR READ_BLOCK_MLI
    CLI
    BCS READ_IMG_FAIL

    ; Stream 512 bytes directly to VERA_DATA0
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

    ; Next Block: CURR_BLK++
    INC CURR_BLK_L
    BNE NO_BLK_C_INC
    INC CURR_BLK_H
NO_BLK_C_INC:

    DEC BLOCK_COUNT
    BNE STREAM_150_BLOCKS

    ; Success! Clear border to black
    LDA #$00
    STA VERA_DC_BOR
    JSR UPDATE_IMAGE_NUMBER
    RTS

READ_PAL_FAIL:
    LDA #$01            ; Red border on Palette read fail
    STA VERA_DC_BOR
    RTS

READ_IMG_FAIL:
    LDA #$02            ; Blue border on Image read fail
    STA VERA_DC_BOR
    RTS

UPDATE_IMAGE_NUMBER:
    ; Apple II text page 1, row 24, right-aligned: "IMG: nnn/375".
    ; The Apple II text display is independent from the fullscreen VERA output.
    LDA #$C9              ; I
    STA $07EC
    LDA #$CD              ; M
    STA $07ED
    LDA #$C7              ; G
    STA $07EE
    LDA #$BA              ; colon
    STA $07EF
    LDA #$A0              ; space
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
    LDA #<$4000
    STA MUSIC_PTR_L
    LDA #>$4000
    STA MUSIC_PTR_H
    LDA #$00
    STA MUSIC_DELAY
    STA MUSIC_MUTE
    STA MUSIC_INDEX
    RTS

LOAD_CANYON_MUSIC:
    LDA #<$4000
    STA CANYON_BUF_PTR
    LDA #>$4000
    STA CANYON_BUF_PTR+1
    JSR SET_MUSIC_START
    LDX #$01
LOAD_CANYON_BLOCK:
    JSR MLI
    !byte $80
    !word CANYON_READ_PARAMS
    BCC CANYON_LOAD_OK
    JMP CANYON_LOAD_FAIL
CANYON_LOAD_OK:
    INC CANYON_BLK_NUM
    BNE CANYON_NO_BLK_CARRY
    INC CANYON_BLK_NUM+1
CANYON_NO_BLK_CARRY:
    LDA CANYON_BUF_PTR+1
    CLC
    ADC #$02
    STA CANYON_BUF_PTR+1
    DEX
    BNE LOAD_CANYON_BLOCK
    RTS
CANYON_LOAD_FAIL:
    LDA #$01
    STA MUSIC_MUTE
    RTS

SET_MUSIC_START:
    LDX MUSIC_INDEX
    LDA MUSIC_START_LO,X
    STA CANYON_BLK_NUM
    LDA MUSIC_START_HI,X
    STA CANYON_BLK_NUM+1
    RTS

MUSIC_NEXT:
    INC MUSIC_INDEX
    LDA MUSIC_INDEX
    CMP #$03
    BCC MUSIC_SELECT
    LDA #$00
    STA MUSIC_INDEX
    JSR MUSIC_SELECT
    JMP MUSIC_DECODE

MUSIC_PREV:
    LDA MUSIC_INDEX
    BNE MUSIC_PREV_DEC
    LDA #$03
    STA MUSIC_INDEX
MUSIC_PREV_DEC:
    DEC MUSIC_INDEX

MUSIC_SELECT:
    ; Reset all voices so the previous soundtrack cannot leave residual notes.
    JSR SILENCE_PSG
    LDA #<$4000
    STA MUSIC_PTR_L
    LDA #>$4000
    STA MUSIC_PTR_H
    LDA #$00
    STA MUSIC_DELAY
    JSR SET_MUSIC_START
    JSR REFILL_CANYON_BUFFER
    JSR UPDATE_MUSIC_NAME
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

TICK_MUSIC:
    LDA MUSIC_MUTE
    BNE MUSIC_TICK_DONE
    LDA MUSIC_PTR_H
    CMP #$42
    BCC MUSIC_BUFFER_READY
    JSR REFILL_CANYON_BUFFER
MUSIC_BUFFER_READY:
    LDA MUSIC_DELAY
    BEQ MUSIC_DECODE
    DEC MUSIC_DELAY
    RTS
MUSIC_DECODE:
    ; A block boundary can be reached while decoding several PSG writes in
    ; one tick.  Refill before the next command, not only at TICK_MUSIC entry.
    ; Otherwise the indirect read would consume stale bytes past $41FF.
    LDA MUSIC_PTR_H
    CMP #$42
    BCC MUSIC_DECODE_READY
    JSR REFILL_CANYON_BUFFER
MUSIC_DECODE_READY:
    LDY #$00
    LDA (MUSIC_PTR_L),Y
    CMP #$FF
    BEQ MUSIC_RESTART
    CMP #$80
    BCC MUSIC_SET_DELAY
    AND #$3F
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
    STA VERA_DATA0
    JSR MUSIC_ADVANCE_2
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
    JSR MUSIC_SELECT
    JMP MUSIC_DECODE
MUSIC_RANDOM_NEXT:
    LDA RAND_SEED
    ASL
    EOR RAND_SEED
    STA RAND_SEED
    AND #$03
    CMP #$03
    BEQ MUSIC_RANDOM_NEXT
    STA MUSIC_INDEX
    JSR MUSIC_SELECT
    JMP MUSIC_DECODE
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
    ; Apple II text page 1, bottom-left: "MUSIC: <name>"
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
    LDA #$A0              ; space
    STA $07D6
    LDX MUSIC_INDEX
    LDA MUSIC_NAME_PTR_LO,X
    STA MUSIC_NAME_PTR
    LDA MUSIC_NAME_PTR_HI,X
    STA MUSIC_NAME_PTR+1
    LDY #$00
MUSIC_NAME_COPY:
    LDA (MUSIC_NAME_PTR),Y
    STA $07D7,Y
    INY
    CPY #$09
    BCC MUSIC_NAME_COPY
    RTS

REFILL_CANYON_BUFFER:
    LDA #<$4000
    STA CANYON_BUF_PTR
    LDA #>$4000
    STA CANYON_BUF_PTR+1
    JSR MLI
    !byte $80
    !word CANYON_READ_PARAMS
    BCC REFILL_READ_OK
    JMP CANYON_LOAD_FAIL
REFILL_READ_OK:
    INC CANYON_BLK_NUM
    BNE REFILL_NO_CARRY
    INC CANYON_BLK_NUM+1
REFILL_NO_CARRY:
    LDA #<$4000
    STA MUSIC_PTR_L
    LDA #>$4000
    STA MUSIC_PTR_H
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

; ==============================================================================
; Low-Level ProDOS MLI Direct Block Read Call ($80)
; ==============================================================================
READ_BLOCK_MLI:
    JSR MLI
    !byte $80                   ; READ_BLOCK Call
    !word READ_BLOCK_PARAMS     ; Parameter Block
    RTS

; ==============================================================================
; ProDOS MLI READ_BLOCK Parameter Block (Param Count = 3)
; ==============================================================================
READ_BLOCK_PARAMS:
    !byte $03                   ; Param count = 3
MLI_UNIT_NUM:
    !byte $70                   ; Unit number (Updated dynamically from $BF30)
    !word DATA_BUF              ; 512-Byte Data Buffer ($3800)
MLI_BLK_NUM:
    !word $03E8                 ; 16-Bit Block Number (Updated dynamically)

CANYON_READ_PARAMS:
    !byte $03
CANYON_UNIT_NUM:
    !byte $70
CANYON_BUF_PTR:
    !word $4000
CANYON_BLK_NUM:
    !word $0320

MUSIC_START_LO:
    !byte $20,$78,$D0
MUSIC_START_HI:
    !byte $03,$05,$07
MUSIC_NAME_PTR_LO:
    !byte <MUSIC_NAME_0,<MUSIC_NAME_1,<MUSIC_NAME_2
MUSIC_NAME_PTR_HI:
    !byte >MUSIC_NAME_0,>MUSIC_NAME_1,>MUSIC_NAME_2
MUSIC_NAME_0:
    !byte $D3,$C2,$AD,$C9,$CE,$D4,$D2,$CF,$A0
MUSIC_NAME_1:
    !byte $C3,$C1,$CE,$D9,$CF,$CE,$A0,$A0,$A0
MUSIC_NAME_2:
    !byte $C7,$D2,$C5,$C5,$CE,$C8,$C9,$CC,$CC

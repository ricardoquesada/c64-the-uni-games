;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; game scene
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; from exodecrunch.s
.import decrunch                                ; exomizer decrunch

; from utils.s
.import _crunched_byte_hi, _crunched_byte_lo    ; exomizer address
.import ut_clear_color, ut_setup_tod, ut_vic_video_type
.import main_menu
.import music_speed, palb_freq_table_lo, palb_freq_table_hi
.import music_patch_table_1, music_patch_table_2

.enum GAME_STATE
        ON_YOUR_MARKS                   ; initial scroll
        GET_SET_GO                      ; get set, go
        RIDING                          ; race started
        GAME_OVER                       ; race finished
.endenum

; finished is in a different state for some reason
; but I can't remember why... related to scrolling and finished
.enum PLAYER_STATE
        GET_SET_GO = 1                  ; race not started
        RIDING     = 2                  ; riding: touching ground
        AIR_DOWN   = 3                  ; riding: not touching ground, falling
        AIR_UP     = 4                  ; riding: impulse, going up
.endenum

.enum FINISH_STATE                      ; used by p?_finished,
        NOT_FINISHED = 0
        WINNER = 1
        LOSER = 2
.endenum

.enum GAME_EVENT                        ; Events of the game
        ROAD_RACE = 0
        CYCLO_CROSS = 1
        CROSS_COUNTRY = 2
.endenum

RECORD_FIRE = 0                         ; computer player: record fire, or play fire? 
                                        ; 0 for "PLAY" (normal mode)
                                        ; 1 to "RECORD" jumps


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode
.macpack mymacros                       ; my own macros

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void consume_cycles()
; consumes cycles to make the IRQ kind of stable.
; works in NTSC, PAL-B and PAL-N (Drean)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macro CONSUME_CYCLES
                                        ; consume PAL-B: 40 cycles
                                        ;         NTSC: 20 cycles
                                        ;         PAL-N: 48 cycles

        lda ut_vic_video_type           ; $01 --> PAL        4 cycles
                                        ; $2F --> PAL-N
                                        ; $28 --> NTSC
                                        ; $2e --> NTSC-OLD
        cmp #$28                        ; 2 cycles
        beq @ntsc1                      ; 2 cycles
        cmp #$2e                        ; 2 cycles
        beq @ntsc2                      ; 2 cycles
        cmp #$01                        ; 2 cycles
        beq @palb                       ; 2 cycles

        .repeat 4                       ; pal-n path
                nop                     ; 8 cycles
        .endrepeat
@palb:
        .repeat 6                       ; pal-b branch
                nop                     ; 12 cycles
        .endrepeat
@ntsc1:
        .repeat 2
                nop                     ; 4 cycles
        .endrepeat
@ntsc2:

        .repeat 3
                nop
        .endrepeat
.endmacro

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants

DEBUG = 0                               ; bitwise: 1=raster-sync code. 2=asserts
                                        ; 4=colllision detection

LEVEL1_WIDTH = 1024                     ; width of map. must be multiple of 256
LEVEL1_HEIGHT = 6
LEVEL1_MAP = $4100                      ; map address. must be 256-aligned
LEVEL1_COLORS = $4000                   ; color address

EMPTY_ROWS = 2                          ; there are two empty rows at the top of
                                        ; the map that is not used.
                                        ; so the map is 8 rows height, but
                                        ; only 6 rows are scrolled

BANK_BASE = $0000
SCREEN_BASE = BANK_BASE + $0400                     ; screen address
SPRITES_BASE = BANK_BASE + $2400                    ; Sprite 0 at $2400
SPRITES_POINTER = <((SPRITES_BASE .MOD $4000) / 64) ; Sprite 0 at 144
SPRITE_PTR = SCREEN_BASE + 1016                     ; right after the screen, at $7f8

SCROLL_ROW_P1= 4
RASTER_TOP_P1 = 50 + 8 * (SCROLL_ROW_P2 + LEVEL1_HEIGHT)        ; first raster line (where P2 scroll ends)
RASTER_BOTTOM_P1 = 50 + 8 * (SCROLL_ROW_P1-EMPTY_ROWS)          ; moving part of the screen

SCROLL_ROW_P2 = 17
RASTER_TOP_P2 = 50 + 8 * (SCROLL_ROW_P1 + LEVEL1_HEIGHT)        ; first raster line (where P1 scroll ends)
RASTER_BOTTOM_P2 = 50 + 8 * (SCROLL_ROW_P2-EMPTY_ROWS)          ; moving part of the screen

RASTER_TRIGGER_ANIMS = 0                ; raster to trigger the animations

ON_YOUR_MARKS_ROW = 12                  ; row to display on your marks

LEVEL_BKG_COLOR = 15
HUD_BKG_COLOR = 0

ACTOR_ANIMATION_SPEED = 8               ; animation speed. the bigger the number, the slower it goes
SCROLL_SPEED = $0130                    ; $0100 = normal speed. $0200 = 2x speed
                                        ; $0080 = half speed
ACCEL_SPEED = $20                       ; how fast the speed will increase
MAX_SPEED = $05                         ; max speed MSB: eg: $05 means $0500

MUSIC_INIT = $1000
MUSIC_PLAY = $1003

.segment "HI_CODE"

.export game_start
.proc game_start
        sei

        jsr init_sound                  ; turn off volume right now

        lda #$00
        sta VIC_SPR_ENA                 ; disable sprites... temporary

                                        ; multicolor mode + extended color causes
        lda #%01011011                  ; the bug that blanks the screen
        sta $d011                       ; extended background color mode: on
        lda #%00011000
        sta $d016                       ; turn on multicolor

        jsr level_setup                 ; setup data for selected level
        jsr computer_setup              ; in case a "one player" was selected

        jsr game_init_data              ; uncrunch data

        lda #01
        jsr ut_clear_color              ; clears the screen color ram
        jsr game_init_screen

        jsr init_game

        jsr ut_setup_tod                ; must be called AFTER detect_pal_...

        lda #$7f
        sta $dc0d                       ; turn off cia 1 interrupts
        sta $dd0d                       ; turn off cia 2 interrupts

        lda #01                         ; Enable raster irq
        sta $d01a

        ldx #<irq_top_p1                ; raster irq vector
        ldy #>irq_top_p1
        stx $fffe
        sty $ffff

        lda #RASTER_TOP_P1
        sta $d012

        lda $dc0d                       ; clear interrupts and ACK irq
        lda $dd0d
        asl $d019

        lda #0
        sta $d012
                                        ; turn VIC on again
        lda #%00011011                  ; charset mode, default scroll-Y position, 25-rows
        sta $d011                       ; extended color mode: off
        lda #%00001000                  ; no scroll, hires (mono color), 40-cols
        sta $d016                       ; turn off multicolor

        cli

_mainloop:
        lda sync_raster_anims
        bne animations
        lda sync_raster_bottom_p1
        bne scroll_p2
        lda sync_raster_bottom_p2
        beq _mainloop

.if (::DEBUG & 1)
        dec $d020
.endif
        dec sync_raster_bottom_p2
        jsr update_scroll_p1                   ; when P1 irq is triggered, scroll P2
.if (::DEBUG & 1)
        inc $d020
.endif
        jmp _mainloop

scroll_p2:
.if (::DEBUG & 1)
        dec $d020
.endif
        dec sync_raster_bottom_p1
        jsr update_scroll_p2                   ; when P2 irq is triggered, scroll P1
.if (::DEBUG & 1)
        inc $d020
.endif
        jmp _mainloop

animations:
        dec sync_raster_anims

.if (::DEBUG & 1)
        dec $d020
.endif

        jsr update_players              ; sprite animations, physics
animate_level_addr = * + 1
        jsr animate_level_roadrace      ; level specific animation: self modyfing

        lda game_state
        cmp #GAME_STATE::ON_YOUR_MARKS
        beq on_your_marks
        cmp #GAME_STATE::GET_SET_GO
        beq get_set_go

        pha                             ; common events for RIDING and GAME_OVER
music_play_addr = *+1
        jsr MUSIC_PLAY                  ; self modifying since changes from song to song
        jsr process_events
        jsr print_speed
        pla

        cmp #GAME_STATE::RIDING
        beq riding
        cmp #GAME_STATE::GAME_OVER
        beq game_over

        jmp main_menu                   ; end event


on_your_marks:
        jsr update_on_your_marks
        jmp cont

get_set_go:
        jsr update_get_set_go
        jmp cont

riding:
        jsr remove_go_lbl
        jsr print_elpased_time          ; updates playing time
        jmp cont

game_over:
        jsr show_press_space            ; display "press space"

        lda #%01111111                  ; space ?
        sta CIA1_PRA                    ; row 7
        lda CIA1_PRB
        and #%00010000                  ; col 4
        bne cont                        ; space pressed ?
        jmp main_menu                   ; yes, return to main

cont:

.if (::DEBUG & 1)
        inc $d020
.endif
        jmp _mainloop
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void game_init_music(void)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc game_init_music
        lda #0
        jsr MUSIC_INIT                  ; init song #0

;        lda music_speed                 ; init with PAL frequency
;        sta $dc04                       ; it plays at 50.125hz
;        lda music_speed+1
;        sta $dc05
;
;        lda #$81                        ; enable timer to play music
;        sta $dc0d                       ; CIA1
;
;        lda #$11
;        sta $dc0e                       ; start timer interrupt A
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void game_init_data()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
game_init_data:
        ; ASSERT (interrupts disabled)

        dec $01                         ; $34: RAM 100%

game_music_address = *+1
        ldx #<game_music1_exo           ; self-modifying. game music
        ldy #>game_music1_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch map

level_map_address = *+1
        ldx #<level_roadrace_map_exo    ; self-modifyng
        ldy #>level_roadrace_map_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch map


level_color_address = *+1
        ldx #<level_roadrace_colors_exo ; self-modifying
        ldy #>level_roadrace_colors_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch

level_charset_address = *+1
        ldx #<level_roadrace_charset_exo        ; self-modifying
        ldy #>level_roadrace_charset_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch

        inc $01                         ; $35: RAM + IO ($D000-$DF00)

        rts

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; IRQ handlers
; 
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq_top_p1
; triggered at bottom of the screen, where the scroll of player two ends
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_top_p1
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt

        .repeat 14
                nop
        .endrepeat

        lda #%00001000                  ; no scroll,single-color,40-cols
        sta $d016

        lda #HUD_BKG_COLOR              ; border and background color
        sta $d021

        lda #%01011011
        sta $d011                       ; extended background color mode: on

        lda #<irq_anims                 ; set a new irq vector
        sta $fffe
        lda #>irq_anims
        sta $ffff

        lda #RASTER_TRIGGER_ANIMS       ; should be triggered when raster = RASTER_TRIGGER_ANIMS
        sta $d012

end_irq:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq_anims
; triggered 0... will trigger when to do the animations
; we can't use irq_top_p1 to trigger them, because the raster will still be consumed
; by the previous raster stuff
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_anims
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
        inc sync_raster_anims

        lda #<irq_bottom_p1             ; set a new irq vector
        sta $fffe
        lda #>irq_bottom_p1
        sta $ffff

        lda #RASTER_BOTTOM_P1           ; should be triggered when raster = RASTER_BOTTOM
        sta $d012

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq_bottom_p1
; triggered at top of the screen, where the scroll of player one starts
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_bottom_p1
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
;        bcs raster
;
;        lda $dc0d                       ; clears CIA interrupts, in particular timer A
;        inc sync_timer_irq
;        jmp end_irq
;
;raster:
        CONSUME_CYCLES

        lda smooth_scroll_x_p1+1        ; scroll x
        ora #%00010000                  ; multicolor on
        sta $d016

        lda background_color
        sta $d021                       ; background color

        lda #%00011011
        sta $d011                       ; extended color mode: off

        lda #<irq_top_p2                ; set new IRQ-raster vector
        sta $fffe
        lda #>irq_top_p2
        sta $ffff

        lda #RASTER_TOP_P2
        sta $d012

        inc sync_raster_bottom_p1

end_irq:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq_top_p2
; triggered at middle of the screen, where the scroll of player one ends
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_top_p2
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
;        bcs raster
;
;        lda $dc0d                       ; clears CIA interrupts, in particular timer A
;        inc sync_timer_irq
;        jmp end_irq
;
;raster:
;        STABILIZE_RASTER
        .repeat 14
                nop
        .endrepeat

        lda #%00001000                  ; no scroll,single-color,40-cols
        sta $d016

        lda #HUD_BKG_COLOR              ; border and background color
        sta $d021                       ; to place the score and time

        lda #%01011011
        sta $d011                       ; extended background color mode: on

        lda #<irq_bottom_p2             ; set a new irq vector
        sta $fffe
        lda #>irq_bottom_p2
        sta $ffff

        lda #RASTER_BOTTOM_P2           ; should be triggered when raster = RASTER_BOTTOM
        sta $d012

end_irq:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq_bottom_p2
; triggered at middle of the screen, where the scroll of player two starts
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_bottom_p2
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
;        bcs raster
;
;        lda $dc0d                       ; clears CIA interrupts, in particular timer A
;        inc sync_timer_irq
;        jmp end_irq
;
;raster:
        CONSUME_CYCLES

        lda smooth_scroll_x_p2+1        ; scroll x
        ora #%00010000                  ; multicolor on
        sta $d016

        lda background_color
        sta $d021                       ; background color

        lda #%00011011
        sta $d011                       ; extended color mode: off

        lda #<irq_top_p1                ; set new IRQ-raster vector
        sta $fffe
        lda #>irq_top_p1
        sta $ffff

        lda #RASTER_TOP_P1
        sta $d012

        inc sync_raster_bottom_p2

end_irq:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void game_init_screen()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc game_init_screen

        lda #%00011100                  ; screen:  $0400 %0001xxxx
        sta $d018                       ; charset: $3000 %xxxx110x

        ldx #$00                        ; screen starts at SCREEN_BASE
_loop:
        lda #$20
        sta SCREEN_BASE,x
        sta SCREEN_BASE+$0100,x
        sta SCREEN_BASE+$0200,x
        sta SCREEN_BASE+$02e8,x
        inx
        bne _loop

        ldx #40-1                       ; 2 lines only
:       lda screen,x
        sta SCREEN_BASE+40*(SCROLL_ROW_P1-EMPTY_ROWS-1),x
        sta SCREEN_BASE+40*(SCROLL_ROW_P2-EMPTY_ROWS-1),x
        dex
        bpl :-

        ldx #0
_loop2:
        .repeat 6, YY
                lda LEVEL1_MAP + LEVEL1_WIDTH* YY,x
                sta SCREEN_BASE + 40 * SCROLL_ROW_P1 + 40 * YY, x
                sta SCREEN_BASE + 40 * SCROLL_ROW_P2 + 40 * YY, x
                tay
                lda LEVEL1_COLORS,y
                sta $d800 + 40 * SCROLL_ROW_P1 + 40 * YY, x
                sta $d800 + 40 * SCROLL_ROW_P2 + 40 * YY, x
        .endrepeat
        inx
        cpx #40
        bne _loop2

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_game()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_game
        jsr init_sprites                ; setup sprites

        lda #GAME_STATE::ON_YOUR_MARKS  ; game state machine = "get set"
        sta game_state

        lda #PLAYER_STATE::GET_SET_GO   ; player state machine = "get set"
        sta p1_state
        sta p2_state
        lda #FINISH_STATE::NOT_FINISHED
        sta p1_finished
        sta p2_finished

        lda #0
        sta frame_idx_p1
        sta frame_idx_p2
        sta animation_idx_p1
        sta animation_idx_p2
        sta resistance_idx_p1
        sta resistance_idx_p2
        sta jump_idx_p1
        sta jump_idx_p2
        sta smooth_scroll_x_p1
        sta smooth_scroll_x_p1+1
        sta smooth_scroll_x_p2
        sta smooth_scroll_x_p2+1
        sta expected_joy1_idx
        sta expected_joy2_idx
        sta sync_raster_anims
        sta sync_raster_bottom_p1
        sta sync_raster_bottom_p2

        ldx #<SCROLL_SPEED              ; initial speed
        ldy #>SCROLL_SPEED
        stx scroll_speed_p1             ; LSB
        stx scroll_speed_p2
        sty scroll_speed_p1+1           ; MSB
        sty scroll_speed_p2+1

        lda #$80
        sta remove_go_counter

        ldx #<(LEVEL1_MAP+40)
        ldy #>(LEVEL1_MAP+40)
        stx scroll_idx_p1
        stx scroll_idx_p2
        sty scroll_idx_p1+1
        sty scroll_idx_p2+1

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_sound()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_sound
        ldx #$1c
        lda #0                          ; reset sound
:       sta $d400,x
        dex
        bpl :-

        lda #15
        sta SID_Amp                     ; volume

        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_sprites()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_sprites

        ldx #0
loop:
        txa                             ; y = x * 2
        asl
        tay

        lda sprite_frames,x
        sta SPRITE_PTR,x

        lda sprites_x,x
        sta VIC_SPR0_X,y

        lda sprites_y,x
        sta VIC_SPR0_Y,y

        inx
        cpx #8
        bne loop


        lda #%11111111                  ; sprite enabled
        sta VIC_SPR_ENA
        lda #%00000000
        sta VIC_SPR_HI_X                ; sprite hi x
        sta VIC_SPR_MCOLOR              ; multicolor enabled
        sta VIC_SPR_EXP_X               ; sprite expanded X
        sta VIC_SPR_EXP_Y               ; sprite expanded Y


        rts

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_on_your_marks()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_on_your_marks
        ldx resistance_idx_p1
        sec
        lda scroll_speed_p1             ; subtract
        sbc resistance_tbl,x
        sta scroll_speed_p1             ; LSB
        sta scroll_speed_p2             ; LSB

        bcs @end                        ; shortcut for MSB
        dec scroll_speed_p1+1           ; MSB
        dec scroll_speed_p2+1           ; MSB

        bpl @end                        ; if < 0, then 0

        jmp init_get_set_go             ; transition to get_set_go state
@end:
        inx
        cpx #(RESISTANCE_TBL_SIZE .MOD 256)
        bne :+
        ldx #RESISTANCE_TBL_SIZE-1
:       stx resistance_idx_p1
        stx resistance_idx_p2
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_get_set_go()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_get_set_go
        lda #0                          ; reset variables
        sta scroll_speed_p1
        sta scroll_speed_p1+1
        sta scroll_speed_p2
        sta scroll_speed_p2+1
        sta resistance_idx_p1
        sta resistance_idx_p2

        ldx #39                         ; display "on your marks"
:       lda on_your_marks_lbl,x
        sta SCREEN_BASE + 40 * ON_YOUR_MARKS_ROW,x
        dex
        bpl :-

        lda #GAME_STATE::GET_SET_GO
        sta game_state

        ldx #12*4                       ; Do. 4th octave
        jsr play_sound
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_get_set_go()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_get_set_go
        dec counter
        lda counter
        beq @riding_state

        cmp #$80                        ; cycles to wait
        bne @end

        ldx #12*4                       ; Do. 4th octave
        jsr play_sound

        ldx #39                         ; display "get set"
:       lda on_your_marks_lbl + 40*1,x
        sta SCREEN_BASE + 40 * ON_YOUR_MARKS_ROW,x
        dex
        bpl :-
        rts

@riding_state:
        ldx #39                         ; display "go!"
:       lda on_your_marks_lbl + 40*2,x
        sta SCREEN_BASE + 40 * ON_YOUR_MARKS_ROW,x
        dex
        bpl :-

        lda #0
        sta $dc0b                       ; Set TOD-Clock to 0 (hours)
        sta $dc0a                       ;- (minutes)
        sta $dc09                       ;- (seconds)
        sta $dc08                       ;- (deciseconds)

        lda #GAME_STATE::RIDING
        sta game_state

        ldx #12*5                       ; Do: 5th octave
        jsr play_sound

        jsr game_init_music             ; enable timer, play music

@end:
        rts

counter: .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; remove_go_lbl
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc remove_go_lbl
        lda remove_go_counter
        beq @end
        dec remove_go_counter
        bne @end

        ldx #39                         ; clean the "go" message
        lda #$20                        ; ' ' (space)
:       sta SCREEN_BASE + 40 * ON_YOUR_MARKS_ROW,x
        dex
        bpl :-

@end:
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void show_press_space()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc show_press_space
        dec counter
        beq @display
        rts

@display:
        lda #$40
        sta counter

        lda on_off
        eor #%00000001
        sta on_off

        beq show_label

        ldx #39                         ; clean the "go" message
        lda #$20
l0:     sta SCREEN_BASE + 40 * ON_YOUR_MARKS_ROW,x
        dex
        bpl l0
        rts

show_label:
        ldx #39                         ; clean the "go" message
l1:     lda press_space_lbl,x
        sta SCREEN_BASE + 40 * ON_YOUR_MARKS_ROW,x
        dex
        bpl l1
        rts

on_off: .byte 0
counter: .byte $40
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; process_events
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc process_events
        jsr process_p1
        jmp process_p2
.endproc

.proc process_p1
        lda p1_finished                 ; if finished, go directly to
        bne decrease_speed_p1           ; decrease speed

        lda p1_state                    ; if "falling" or "jumping", decrease speed
        cmp #PLAYER_STATE::AIR_DOWN     ; since it can't accelerate
        beq decrease_speed_p1
        cmp #PLAYER_STATE::AIR_UP
        beq decrease_speed_p1

joy1_address = *+1
        jsr read_joy1                   ; self modified
        tay
        and #%00010000                  ; button
        bne test_movement_p1

        lda #PLAYER_STATE::AIR_UP       ; start jump sequence
        sta p1_state
        lda #0                          ; use sine to jump
        sta jump_idx_p1                 ; set pointer to beginning of sine
        rts

test_movement_p1:
        tya
        eor #%00001111                  ; invert joy bits, since they are inverted
        ldx expected_joy1_idx
        and expected_joy,x              ; AND instead of CMP to support diagonals
        bne increase_velocity_p1
        jmp decrease_speed_p1

increase_velocity_p1:
        inx
        txa
        and #%00000001
        sta expected_joy1_idx           ; cycles between 0,1

        lda #0
        sta resistance_idx_p1

        clc
        lda scroll_speed_p1             ; increase
        adc #ACCEL_SPEED
        sta scroll_speed_p1             ; LSB
        bcc :+
        inc scroll_speed_p1+1           ; MSB
:
        lda scroll_speed_p1+1
        cmp #MAX_SPEED                  ; max speed MSB
        bne @end

        lda #$00                        ; if $0500 or more, then make it $500
        sta scroll_speed_p1
@end:
        rts

decrease_speed_p1:
        ldx resistance_idx_p1
        sec
        lda scroll_speed_p1            ; subtract
        sbc resistance_tbl,x
        sta scroll_speed_p1            ; LSB

        bcs end_p1                     ; shortcut for MSB
        dec scroll_speed_p1+1          ; MSB

        bpl end_p1                     ; if < 0, then 0
        lda #0
        sta scroll_speed_p1
        sta scroll_speed_p1+1

end_p1:
        inx
        cpx #(RESISTANCE_TBL_SIZE .MOD 256)
        bne :+
        ldx #RESISTANCE_TBL_SIZE-1
:       stx resistance_idx_p1
        rts
.endproc


.proc process_p2
        lda p2_finished                 ; if finished, go directly to
        bne decrease_speed_p2           ; decrease speed

        lda p2_state                    ; if "falling" or "jumping", decrease speed
        cmp #PLAYER_STATE::AIR_DOWN     ; since it can't accelerate
        beq decrease_speed_p2
        cmp #PLAYER_STATE::AIR_UP
        beq decrease_speed_p2

joy2_address = *+1
        jsr read_joy2                   ; self modified
        tay
        and #%00010000                  ; button
        bne test_movement_p2

        lda #PLAYER_STATE::AIR_UP       ; start jump sequence
        sta p2_state
        lda #0                          ; use sine to jump
        sta jump_idx_p2                 ; set pointer to beginning of sine
        rts

test_movement_p2:
        tya
        eor #%00001111                  ; invert joy bits, since they are inverted
        ldx expected_joy2_idx
        and expected_joy,x              ; AND instead of CMP to support diagonals
        bne increase_velocity_p2
        jmp decrease_speed_p2

increase_velocity_p2:
        inx
        txa
        and #%00000001
        sta expected_joy2_idx           ; cycles between 0,1

        lda #0
        sta resistance_idx_p2

        clc
        lda scroll_speed_p2             ; increase
        adc #ACCEL_SPEED
        sta scroll_speed_p2             ; LSB
        bcc :+
        inc scroll_speed_p2+1           ; MSB

:                                       ; check if it reached max speed
        lda scroll_speed_p2+1
        cmp #MAX_SPEED                  ; max speed MSB
        bne @end

        lda #$00                        ; if $0500 or more, then make it $500
        sta scroll_speed_p2
@end:
        rts

decrease_speed_p2:
        ldx resistance_idx_p2
        sec
        lda scroll_speed_p2            ; subtract
        sbc resistance_tbl,x
        sta scroll_speed_p2            ; LSB

        bcs end_p2                     ; shortcut for MSB
        dec scroll_speed_p2+1          ; MSB

        bpl end_p2                     ; if < 0, then 0
        lda #0
        sta scroll_speed_p2
        sta scroll_speed_p2+1

end_p2:
        inx
        cpx #(RESISTANCE_TBL_SIZE .MOD 256)
        bne :+
        ldx #RESISTANCE_TBL_SIZE-1
:       stx resistance_idx_p2
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void read_joy1()
; returns A values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_joy1
        lda $dc01                       ; self modified
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void read_joy1_left_right()
; returns A values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_joy1_left_right
        lda $dc01
        ora #%11110011                  ; only enable left & right
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void read_joy1_jump()
; returns A values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_joy1_jump
        jsr @simulate_left_right

        lda $dc01
        ora #%11101111                  ; only enable jump
        and last_value
        rts

@simulate_left_right:
        dec delay
        beq :+
        rts
:
        lda #$04
        sta delay

        lda left
        eor #%00000001
        sta left

        beq doleft
        lda #%11110111
        sta last_value
        rts
doleft:
        lda #%11111011
        sta last_value
        rts
delay:
        .byte $04
last_value:
        .byte %11111111
left:
        .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void read_joy2()
; returns A values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_joy2
        lda $dc00
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void read_joy2_left_right()
; returns A values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_joy2_left_right
        lda $dc00
        ora #%11110011                 ; only enable left & right
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void read_joy2_jump()
; returns A values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_joy2_jump
        jsr @simulate_left_right

        lda $dc00
        ora #%11101111                 ; only enable jump
        and last_value
        rts

@simulate_left_right:
        dec delay
        beq :+
        rts
:
        lda #$04
        sta delay

        lda left
        eor #%00000001
        sta left

        beq doleft
        lda #%11110111
        sta last_value
        rts
doleft:
        lda #%11111011
        sta last_value
        rts
delay:
        .byte $04
last_value:
        .byte %11111111
left:
        .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void read_joy_computer
; returns A values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_joy_computer
        jsr test_fire
        dec delay
        beq l0
        lda last_value
        rts

test_fire:
.if (::RECORD_FIRE)
        jmp record_fire
.else
        jmp play_fire
.endif

l0:
        lda scroll_idx_p1+1                     ; adjust speed according to
        cmp scroll_idx_p2+1                     ; position of player #2
        bcc dofast                              ; p1 < p2, set FAST speed
        bne doslow                              ; p1 > p2, slow down

compare_lsb:                                    ; p1 == p2
        lda scroll_idx_p1
        cmp scroll_idx_p2
        bcc dofast                              ; p1 < p2, set FAST speed
        bne doslow                              ; p1 > p2, slow down

        lda #$04                                ; p1 == p2, fast
        bne cont

doslow:
.if (::RECORD_FIRE)                             ; while recording
        lda #$04                                ; slow is fast
.else
        lda #$05
.endif
        bne cont
dofast:
        lda #$04                                ; slow down a bit if computer is
cont:
        sta delay                               ; ahead of player

        lda left                                ; joy position to send
        eor #%00000001                          ; left or right?
        sta left

        beq doleft

        lda #%11110111                          ; right
        sta last_value
        rts
doleft:
        lda #%11111011                          ; left
        sta last_value
        rts

.if (::RECORD_FIRE)
record_fire:                                    ; record "button pressed"
        lda $dc01                               ; button pressed?
        and #%00010000
        bne fire_off                            ; no, continue with left/right
        jsr store_fire                          ; pressed? process button pressed
        lda last_value                          ; set the button-pressed flag
        and #%11101111
        sta last_value
        rts
fire_off:
        lda last_value
        ora #%00010000
        sta last_value
        rts
store_fire:                                     ; record "button pressed"
        ldx computer_fires_idx                  ; in which X position
        lda scroll_idx_p1                       ; occurred
        sta computer_fires_lo,x
        lda scroll_idx_p1+1
        sta computer_fires_hi,x
        inc computer_fires_idx
        rts
.else
play_fire:
        ldx computer_fires_idx
        lda scroll_idx_p1+1                     ; MSB
        cmp computer_fires_hi,x
        bcc do_no_fire                          ; p1 < fires_hi
        bne do_fire                             ; p1 > fires_hi

        lda scroll_idx_p1
        cmp computer_fires_lo,x
        bcc do_no_fire                          ; p1 < fires_lo? yes.
                                                ; else: p1 >= fires_lo.. do fire
do_fire:
        inc computer_fires_idx                  ; next index of fires
        lda last_value                          ; simulate "button pressed"
        and #%11101111
        sta last_value
        rts

do_no_fire:
        lda last_value                          ; simulate "button not pressed"
        ora #%00010000
        sta last_value
        rts
.endif

delay:
        .byte $04
last_value:
        .byte %11111111
left:
        .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_scroll_p1()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_scroll_p1
        sec                                     ; 16-bit substract
        lda smooth_scroll_x_p1                  ; LSB
        sbc scroll_speed_p1
        sta smooth_scroll_x_p1
        lda smooth_scroll_x_p1+1                ; MSB
        sbc scroll_speed_p1+1
        and #%00000111                          ; scroll-x
        sta smooth_scroll_x_p1+1
        bcc :+                                  ; only scroll if result is negative
        rts
:
        .repeat 6,YY                            ; 6 == LEVEL1_HEIGHT but doesn't compile
                .repeat 39,XX                   ; 40 chars 
                        lda SCREEN_BASE+40*(SCROLL_ROW_P1+YY)+XX+1      ; scroll screen
                        sta SCREEN_BASE+40*(SCROLL_ROW_P1+YY)+XX+0
                        lda $d800+40*(SCROLL_ROW_P1+YY)+XX+1            ; scroll color RAM
                        sta $d800+40*(SCROLL_ROW_P1+YY)+XX+0
                .endrepeat
        .endrepeat


        ldx scroll_idx_p1
        ldy scroll_idx_p1+1
        stx $f8
        sty $f9
        ldy #0
        .repeat 6,YY                            ; 6 == LEVEL1_HEIGHT but doesn't compile
                lda ($f8),y                     ; new char
                sta SCREEN_BASE+40*(SCROLL_ROW_P1+YY)+39
                tax                             ; color for new char
                lda LEVEL1_COLORS,x
                sta $d800+40*(SCROLL_ROW_P1+YY)+39

                clc
                lda $f9                         ; fetch char 1024 chars ahead
                adc #>LEVEL1_WIDTH              ; LEVEL1_WIDTH must be multiple of 256
                sta $f9
        .endrepeat

        inc scroll_idx_p1
        bne @end
        inc scroll_idx_p1+1

        lda scroll_idx_p1+1                     ; game over?
        cmp #>(LEVEL1_MAP + LEVEL1_WIDTH)       ; if so, the p1 state to finished
        bne @end

        ldx #FINISH_STATE::WINNER               ; winner?
        lda p2_finished                         ; only if p2 hasn't finished yet
        beq :+
        lda #GAME_STATE::GAME_OVER              ; if loser, it also means game over
        sta game_state                          ; since both players have finished
        ldx #FINISH_STATE::LOSER                ; loser then
:       stx p1_finished
@end:
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_scroll_p2()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_scroll_p2
        sec                                     ; 16-bit substract
        lda smooth_scroll_x_p2                  ; LSB
        sbc scroll_speed_p2
        sta smooth_scroll_x_p2
        lda smooth_scroll_x_p2+1                ; MSB
        sbc scroll_speed_p2+1
        and #%00000111                          ; scroll-x
        sta smooth_scroll_x_p2+1
        bcc :+
        rts
:
        .repeat 6,YY                             ; 6 == LEVEL1_HEIGHT but doesn't compile
                .repeat 39,XX
                        lda SCREEN_BASE+40*(SCROLL_ROW_P2+YY)+XX+1        ; scroll screen
                        sta SCREEN_BASE+40*(SCROLL_ROW_P2+YY)+XX+0
                        lda $d800+40*(SCROLL_ROW_P2+YY)+XX+1             ; scroll color RAM
                        sta $d800+40*(SCROLL_ROW_P2+YY)+XX+0
                .endrepeat
        .endrepeat

        ldx scroll_idx_p2
        ldy scroll_idx_p2+1
        stx $f8
        sty $f9

        ldy #0
        .repeat 6,YY                            ; 6 == LEVEL1_HEIGHT but doesn't compile
                lda ($f8),y                     ; new char
                sta SCREEN_BASE+40*(SCROLL_ROW_P2+YY)+39
                tax
                lda LEVEL1_COLORS,x             ; color for new char
                sta $d800+40*(SCROLL_ROW_P2+YY)+39

                clc
                lda $f9                         ; fetch char 1024 chars ahead
                adc #>LEVEL1_WIDTH              ; must be multiple of 256
                sta $f9
        .endrepeat

        inc scroll_idx_p2
        bne @end
        inc scroll_idx_p2+1

        lda scroll_idx_p2+1                     ; game over?
        cmp #>(LEVEL1_MAP + LEVEL1_WIDTH)       ; if so, the p2 state to finished
        bne @end

        ldx #FINISH_STATE::WINNER               ; winner?
        lda p1_finished                         ; only if p1 hasn't finished yet
        beq :+
        lda #GAME_STATE::GAME_OVER              ; if loser, it also means game over
        sta game_state                          ; since both players have finished
        ldx #FINISH_STATE::LOSER                ; loser then
:       stx p2_finished
@end:

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; print_elpased_time
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc print_elpased_time
        lda $dc08                       ; 1/10th seconds.
        and #%00001111
        ora #$30

        ldy p1_finished
        bne :+
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-EMPTY_ROWS-1) + 39
:       ldy p2_finished
        bne :+
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-EMPTY_ROWS-1) + 39


:       lda $dc09                       ; seconds. digit
        tax
        and #%00001111
        ora #$30

        ldy p1_finished
        bne :+
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-EMPTY_ROWS-1) + 37
:       ldy p2_finished
        bne :+
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-EMPTY_ROWS-1) + 37

:
        txa                             ; seconds. Ten digit
        lsr
        lsr
        lsr
        lsr
        ora #$30

        ldy p1_finished
        bne :+
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-EMPTY_ROWS-1) + 36
:       ldy p2_finished
        bne :+
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-EMPTY_ROWS-1) + 36
:
        lda $dc0a                       ; minutes. digit
        and #%00001111
        ora #$30
        ldy p1_finished
        bne :+
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-EMPTY_ROWS-1) + 34
:       ldy p2_finished
        bne :+
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-EMPTY_ROWS-1) + 34
:
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; print_speed
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc print_speed

        ; player one
        lda scroll_speed_p1                     ; firt digit
        sta tmp
        lda scroll_speed_p1+1
        sta tmp+1

        asl tmp                                 ; divide 0x500 by 128
        rol tmp+1                               ; which is the same as using the
                                                ; the first 4 MSB bits
        ldx #10                                 ; print speed bar. 10 chars
l1:     lda #42+128                             ; char to fill the speed bar
        cpx tmp+1
        bmi print_p1

        lda #32+128                             ; empty char
print_p1:
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-EMPTY_ROWS-1) + 7,x
        dex
        bpl l1

        lda tmp                                 ; use 3-MSB bits
        lsr                                     ; from tmp for the
        lsr                                     ; variable char
        lsr
        lsr
        lsr

        clc
        adc #35+128                             ; base char is 35

        ldx tmp+1
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-EMPTY_ROWS-1) + 7,x


        ; player two
        lda scroll_speed_p2                     ; firt digit
        sta tmp
        lda scroll_speed_p2+1
        sta tmp+1

        asl tmp                                 ; divide 0x500 by 128
        rol tmp+1                               ; which is the same as using the
                                                ; the first 4 MSB bits
        ldx #10                                 ; print speed bar. 10 chars
l2:     lda #42+128                             ; char to fill the speed bar
        cpx tmp+1
        bmi print_p2

        lda #32+128                             ; empty char
print_p2:
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-EMPTY_ROWS-1) + 7,x
        dex
        bpl l2

        lda tmp                                 ; use 3-MSB bits
        lsr                                     ; from tmp for the
        lsr                                     ; variable char
        lsr
        lsr
        lsr

        clc
        adc #35+128                             ; base char

        ldx tmp+1
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-EMPTY_ROWS-1) + 7,x

        rts

tmp:
.byte 0, 0

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_players()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_players
        jsr update_frame_p1
        jsr update_frame_p2

        lda $d01f                               ; collision: sprite - background
        pha                                     ; save value since it is cleared
        jsr update_position_y_p1                ; after reading it
        pla                                     ; restore value
        jmp update_position_y_p2
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_frame_p1()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_frame_p1
        dec animation_delay_p1
        beq :+
        rts
:
        lda #ACTOR_ANIMATION_SPEED
        sta animation_delay_p1


        lda p1_finished
        beq anim_riding                         ; riding animation

        ldx #(RESISTANCE_TBL_SIZE/3)-1          ; if not riding, then it finishes
        stx resistance_idx_p1                   ; so slow down quickly

        cmp #FINISH_STATE::WINNER
        beq anim_winner                         ; winner animation

                                                ; default: loser animation
        lda scroll_speed_p1+1                   ; but only anim when speed is low
        bne anim_riding

        lda #SPRITES_POINTER+10                 ; hair sprite
        sta SPRITE_PTR+3
        lda #SPRITES_POINTER+9                  ; body sprite
        sta SPRITE_PTR+2

        ldx VIC_SPR1_Y                          ; hair and head
        dex                                     ; one pixel above wheel
        stx VIC_SPR2_Y
        stx VIC_SPR3_Y
        rts

anim_winner:
        lda scroll_speed_p1+1                   ; only anim when speed is low
        bne anim_riding

        ldx frame_idx_p1
        lda frame_hair_winner_tbl,x
        sta SPRITE_PTR+3                        ; hair
        lda frame_body_winner_tbl,x
        sta SPRITE_PTR+2                        ; body
        inx
        cpx #FRAME_HAIR_WINNER_TBL_SIZE
        bne @end
        ldx #0
@end:   stx frame_idx_p1

        ldx VIC_SPR1_Y                          ; hair and head
        dex                                     ; one pixel above wheel
        stx VIC_SPR2_Y
        stx VIC_SPR3_Y
        rts

anim_riding:
        ldx frame_idx_p1
        lda frame_hair_riding_tbl,x
        sta SPRITE_PTR + 3                      ; head is 4th sprite
        inx
        cpx #FRAME_HAIR_RIDING_TBL_SIZE
        bne :+
        ldx #0
:       stx frame_idx_p1

        ldx animation_idx_p1
        lda VIC_SPR2_Y
        clc
        adc animation_tbl,x
        sta VIC_SPR2_Y
        sta VIC_SPR3_Y

        inx
        cpx #ANIMATION_TBL_SIZE
        bne :+
        ldx #0
:       stx animation_idx_p1
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_frame_p2()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_frame_p2
        dec animation_delay_p2
        beq :+
        rts
:
        lda #ACTOR_ANIMATION_SPEED
        sta animation_delay_p2

        lda p2_finished
        beq anim_riding                         ; riding animation

        ldx #(RESISTANCE_TBL_SIZE/3)-1          ; if not riding, then it finishes
        stx resistance_idx_p2                   ; so slow down quickly

        cmp #FINISH_STATE::WINNER
        beq anim_winner                         ; winner animation

                                                ; default: loser animation
        lda scroll_speed_p2+1                   ; but only anim when speed is low
        bne anim_riding

        lda #SPRITES_POINTER+10                 ; hair sprite
        sta SPRITE_PTR+7
        lda #SPRITES_POINTER+9                  ; body sprite
        sta SPRITE_PTR+6

        ldx VIC_SPR5_Y                          ; hair and head
        dex                                     ; one pixel above wheel
        stx VIC_SPR6_Y
        stx VIC_SPR7_Y

        rts
anim_winner:
        lda scroll_speed_p2+1                   ; only anim when speed is low
        bne anim_riding

        ldx frame_idx_p2
        lda frame_hair_winner_tbl,x
        sta SPRITE_PTR+7
        lda frame_body_winner_tbl,x
        sta SPRITE_PTR+6
        inx
        cpx #FRAME_HAIR_WINNER_TBL_SIZE
        bne @end
        ldx #0
@end:   stx frame_idx_p2

        ldx VIC_SPR5_Y                          ; hair and head
        dex                                     ; one pixel above wheel
        stx VIC_SPR6_Y
        stx VIC_SPR7_Y
        rts

anim_riding:
        ldx frame_idx_p2
        lda frame_hair_riding_tbl,x
        sta SPRITE_PTR + 7                      ; head is 8th sprite
        inx
        cpx #FRAME_HAIR_RIDING_TBL_SIZE
        bne :+
        ldx #0
:       stx frame_idx_p2

        ldx animation_idx_p2
        lda VIC_SPR6_Y
        clc
        adc animation_tbl,x
        sta VIC_SPR6_Y
        sta VIC_SPR7_Y

        inx
        cpx #ANIMATION_TBL_SIZE
        bne :+
        ldx #0
:       stx animation_idx_p2
        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_position_y_p1(int collision_bits)
;       input A = copy of $d01f
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_position_y_p1
        tax                                     ; 1st: check body collision
        and #%00000100                          ; head or body?
        bne p1_collision_body

        lda p1_state                            ; 2nd: was it going up?
        cmp #PLAYER_STATE::AIR_UP               ; if so, keep going up
        beq p1_go_up

        txa                                     ; 3rd: check tire/rim collision
        and #%00000011                          ; if so, do the collision handler
        beq :+
        jmp p1_collision_tire

:
        lda #PLAYER_STATE::AIR_DOWN             ; 4th: else, go down
        cmp p1_state                            ; Was it already going down?
        beq l0
        sta p1_state                            ; no? set it
        lda #JUMP_TBL_SIZE-1                    ; and the index to the correct position
        sta jump_idx_p1

l0:     ldx jump_idx_p1
        lda jump_tbl,x
        beq l2                                  ; don't go down if value is 0
        tay

l1:     inc VIC_SPR0_Y                          ; tire
        inc VIC_SPR1_Y                          ; rim
        inc VIC_SPR2_Y                          ; head
        inc VIC_SPR3_Y                          ; hair
        dey
        bne l1

l2:     lda jump_idx_p1                         ; if it is already 0, stop dec
        beq @end
        dec jump_idx_p1
@end:   rts

p1_go_up:
        ldx jump_idx_p1                         ; fetch sine index
        lda jump_tbl,x
        beq l4                                  ; don't go up if value is 0
        tay

l3:     lda VIC_SPR0_Y                          ; don't go above a certain height
        cmp #60                                 ; sky is the limit
        bmi l4

        dec VIC_SPR0_Y                          ; tire
        dec VIC_SPR1_Y                          ; rim
        dec VIC_SPR2_Y                          ; head
        dec VIC_SPR3_Y                          ; hair
        dey
        bne l3

l4:     inc jump_idx_p1                         ; reached max height?
        lda jump_idx_p1
        cmp #JUMP_TBL_SIZE
        bne @end

        dec jump_idx_p1                         ; set idx to JUMP_TBL_SIZE-1
        lda #PLAYER_STATE::AIR_DOWN             ; and start going down
        sta p1_state
@end:   rts

p1_collision_body:
        lda #JUMP_TBL_SIZE-1
        sta jump_idx_p1                         ; reset jmp table just in case
        lda #PLAYER_STATE::RIDING               ; touching ground
        sta p1_state

        ldx #3
l5:     dec VIC_SPR0_Y                          ; go up three times
        dec VIC_SPR1_Y
        dec VIC_SPR2_Y
        dec VIC_SPR3_Y
        dex
        bne l5

        lsr scroll_speed_p1+1                   ; reduce speed by 2
        ror scroll_speed_p1
        rts

p1_collision_tire:
        ldy #JUMP_TBL_SIZE-1
        sty jump_idx_p1                         ; reset jmp table just in case
        ldy #PLAYER_STATE::RIDING               ; touching ground
        sty p1_state

        cmp #%00000011                          ; ASSERT(A == collision bis)
        bne @end                                ; only the tire is touching ground?
                                                ; if only tire, then end, else
        dec VIC_SPR0_Y                          ; go up
        dec VIC_SPR1_Y
        dec VIC_SPR2_Y
        dec VIC_SPR3_Y
@end:
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_position_y_p2(int collision_bits)
;       input A = copy of $d01f
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_position_y_p2
        tax                                     ; 1st: check body collision
        and #%01000000                          ; head or body?
        bne p2_collision_body

        lda p2_state                            ; 2nd: was it going up?
        cmp #PLAYER_STATE::AIR_UP               ; if so, keep going up
        beq p2_go_up

        txa                                     ; 3rd: check tire/rim collision
        and #%00110000                          ; if so, do the collision handler
        beq :+
        jmp p2_collision_tire

:
        lda #PLAYER_STATE::AIR_DOWN             ; 4th: else, go down
        cmp p2_state                            ; Was it already going down?
        beq l0
        sta p2_state                            ; no? set it
        lda #JUMP_TBL_SIZE-1                    ; and the index to the correct position
        sta jump_idx_p2

l0:     ldx jump_idx_p2
        lda jump_tbl,x
        beq l2                                  ; don't go down if value is 0
        tay

l1:     inc VIC_SPR4_Y                          ; tire
        inc VIC_SPR5_Y                          ; rim
        inc VIC_SPR6_Y                          ; head
        inc VIC_SPR7_Y                          ; hair
        dey
        bne l1

l2:     lda jump_idx_p2                         ; if it is already 0, stop dec
        beq @end
        dec jump_idx_p2
@end:   rts

p2_go_up:
        ldx jump_idx_p2                         ; fetch sine index
        lda jump_tbl,x
        beq l4                                 ; don't go up if value is 0
        tay

l3:     lda VIC_SPR4_Y                          ; don't go above a certain height
        cmp #164                                ; sky is the limit
        bmi l4

        dec VIC_SPR4_Y                          ; tire
        dec VIC_SPR5_Y                          ; rim
        dec VIC_SPR6_Y                          ; head
        dec VIC_SPR7_Y                          ; hair
        dey
        bne l3

l4:     inc jump_idx_p2                         ; reached max height?
        lda jump_idx_p2
        cmp #JUMP_TBL_SIZE
        bne @end

        dec jump_idx_p2                         ; set idx to JUMP_TBL_SIZE-1
        lda #PLAYER_STATE::AIR_DOWN             ; and start going down
        sta p2_state
@end:   rts

p2_collision_body:
        lda #JUMP_TBL_SIZE-1
        sta jump_idx_p2                         ; reset jmp table just in case
        lda #PLAYER_STATE::RIDING               ; touching ground
        sta p2_state

        ldx #3
l5:     dec VIC_SPR4_Y                          ; go up three times
        dec VIC_SPR5_Y
        dec VIC_SPR6_Y
        dec VIC_SPR7_Y
        dex
        bne l5

        lsr scroll_speed_p2+1                   ; reduce speed by 2
        ror scroll_speed_p2
        rts

p2_collision_tire:
        ldy #JUMP_TBL_SIZE-1
        sty jump_idx_p2                         ; reset jmp table just in case
        ldy #PLAYER_STATE::RIDING               ; touching ground
        sty p2_state

        cmp #%00110000                          ; ASSERT(A == collision bis)
        bne @end                                ; only the tire is touching ground?
                                                ; if only tire, then end, else
        dec VIC_SPR4_Y                          ; go up
        dec VIC_SPR5_Y
        dec VIC_SPR6_Y
        dec VIC_SPR7_Y
@end:
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void play_sound(int tone_idx)
; entries:
;   X = tone to play (from 0 to 95).
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc play_sound
        lda #0                          ; gate: release previous sound
        sta $d404                       ; control register
        sta $d404+7
        sta $d404+14

        lda #%00001001
        sta $d405                       ; attack / decay
        sta $d405+7                     ; attack / decay
        sta $d405+14                    ; attack / decay
        lda #0
        sta $d406                       ; sustain / release
        sta $d406+7                     ; sustain / release
        sta $d406+14                    ; sustain / release
        lda palb_freq_table_lo,x
        sta $d400                       ; freq lo
        sta $d400+7                     ; freq lo
        sta $d400+14                    ; freq lo
        lda palb_freq_table_hi,x
        sta $d401                       ; freq hi
        sta $d401+7                     ; freq hi
        sta $d401+14                    ; freq hi
        lda #%00010001                  ; gate: start Attack/Decay/Sus. Sawtooth
        sta $d404                       ; control register
        sta $d404+7                     ; control register
        sta $d404+14                    ; control register
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void animate_level_roadrace
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc animate_level_roadrace
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void animate_level_cyclocross
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc animate_level_cyclocross
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void animate_level_crosscountry
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc animate_level_crosscountry
        lda level_state                 ; delay or anim?
        bne anim                        ; 0==delay, 1==anim

        dec delay                       ; delay, so wait
        beq :+
        rts
:       dec delay+1
        beq init_anim                   ; delay reched zero?
        rts

init_anim:
        lda #1                          ; reset variables
        sta level_state                 ; and set state to "anim" (1)
        lda #$00
        sta delay
        lda #$03
        sta delay+1
anim:
        ldx colors_idx
        lda colors,x
        sta background_color
        inx
        stx colors_idx
        cpx #TOTAL_COLORS
        bne end

        ldx #0
        stx colors_idx
        stx level_state
end:
        rts

delay:
        .word $0300

level_state:
        .byte 0
colors_idx:     .byte 0
colors:
        .byte 1,15,15,15,12,12,12,11,11,11
        .byte 0,0,0,0,0,0,0,11
        .byte 0,0,0,0,0,0,0,11
        .byte 0,0,0,0,0,0,0,11
        .byte 11,11,11,12,12,12,15,15,15,1
TOTAL_COLORS = * - colors
        rts
.endproc
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void level_setup()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc level_setup
        lda game_selected_event
        cmp #GAME_EVENT::ROAD_RACE
        beq start_roadrace
        cmp #GAME_EVENT::CYCLO_CROSS
        beq start_cyclocross

        jmp level_setup_crosscountry             ; else cross country
start_roadrace:
        jmp level_setup_roadrace
start_cyclocross:
        jmp level_setup_cyclocross
.endproc
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void level_setup_roadrace()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc level_setup_roadrace
        ldx #<level_roadrace_map_exo            ; map
        ldy #>level_roadrace_map_exo
        stx level_map_address
        sty level_map_address+2

        ldx #<level_roadrace_colors_exo         ; colors
        ldy #>level_roadrace_colors_exo
        stx level_color_address
        sty level_color_address+2

        ldx #<level_roadrace_charset_exo        ; charset
        ldy #>level_roadrace_charset_exo
        stx level_charset_address
        sty level_charset_address+2

        ldx #<game_music1_exo                   ; music
        ldy #>game_music1_exo
        stx game_music_address
        sty game_music_address+2

        ldx #<read_joy1_left_right              ; joy #1 left right only
        ldy #>read_joy1_left_right
        stx process_p1::joy1_address
        sty process_p1::joy1_address+1

        ldx #<read_joy2_left_right              ; joy #2 left right only
        ldy #>read_joy2_left_right
        stx process_p2::joy2_address
        sty process_p2::joy2_address+1

        lda #03                                 ; $1003
        sta game_start::music_play_addr

        lda #0
        sta $d020
        lda #15
        sta background_color
        lda #2
        sta $d022                               ; used for extended background
        lda #12
        sta $d023                               ; used for extended background

        ldx #<animate_level_roadrace
        ldy #>animate_level_roadrace
        stx game_start::animate_level_addr
        sty game_start::animate_level_addr+1

        ldx #7
l0:     lda spr_colors,x
        sta VIC_SPR0_COLOR,x                    ; sprite color
        dex
        bpl l0

        jsr music_patch_table_1                 ; convert to PAL if needed

        ldx #0
        lda #$ff                                ; jump table is $ffff. no jump
l1:     sta computer_fires_lo,x                 ; in this level for the computer
        sta computer_fires_hi,x
        inx
        cpx #FIRE_TBL_SIZE
        bne l1

        rts
spr_colors:
                .byte 1, 1, 0, 7                ; player 1
                .byte 1, 1, 0, 7                ; player 2
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void level_setup_cyclocross()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc level_setup_cyclocross
        ldx #<level_cyclocross_map_exo          ; map
        ldy #>level_cyclocross_map_exo
        stx level_map_address
        sty level_map_address+2

        ldx #<level_cyclocross_colors_exo       ; color for map
        ldy #>level_cyclocross_colors_exo
        stx level_color_address
        sty level_color_address+2

        ldx #<level_cyclocross_charset_exo      ; charset
        ldy #>level_cyclocross_charset_exo
        stx level_charset_address
        sty level_charset_address+2

        ldx #<game_music2_exo                   ; music
        ldy #>game_music2_exo
        stx game_music_address
        sty game_music_address+2

        ldx #<read_joy1_jump                    ; joy #1 only jump
        ldy #>read_joy1_jump
        stx process_p1::joy1_address
        sty process_p1::joy1_address+1

        ldx #<read_joy2_jump                    ; joy #2 only jump
        ldy #>read_joy2_jump
        stx process_p2::joy2_address
        sty process_p2::joy2_address+1

        lda #03                                 ; $1003
        sta game_start::music_play_addr

        lda #0
        sta $d020
        lda #15
        sta background_color
        lda #2
        sta $d022                               ; used in level
        lda #12
        sta $d023                               ; used in level and extended background color

        ldx #<animate_level_cyclocross
        ldy #>animate_level_cyclocross
        stx game_start::animate_level_addr
        sty game_start::animate_level_addr+1

        ldx #7
l0:     lda spr_colors,x
        sta VIC_SPR0_COLOR,x                    ; sprite color
        dex
        bpl l0

        jsr music_patch_table_1                 ; convert to PAL if needed


.if !(::RECORD_FIRE)                            ; only copy if not recording fires
                                                ; otherwise the table might have additional
                                                ; jumps

        ldx #0                                  ; computer jump table
l1:
        lda computer_fires_cyclocross_lo,x
        sta computer_fires_lo,x
        lda computer_fires_cyclocross_hi,x
        sta computer_fires_hi,x
        inx
        cpx #FIRE_TBL_SIZE
        bne l1
.endif

        rts
spr_colors:
                .byte 1, 1, 0, 7                ; player 1
                .byte 1, 1, 0, 7                ; player 2
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void level_setup_crosscountry()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc level_setup_crosscountry
        ldx #<level_crosscountry_map_exo        ; map
        ldy #>level_crosscountry_map_exo
        stx level_map_address
        sty level_map_address+2

        ldx #<level_crosscountry_colors_exo     ; color
        ldy #>level_crosscountry_colors_exo
        stx level_color_address
        sty level_color_address+2

        ldx #<level_crosscountry_charset_exo    ; charset
        ldy #>level_crosscountry_charset_exo
        stx level_charset_address
        sty level_charset_address+2

        ldx #<game_music3_exo                   ; music
        ldy #>game_music3_exo
        stx game_music_address
        sty game_music_address+2

        ldx #<read_joy1                         ; joy #1
        ldy #>read_joy1
        stx process_p1::joy1_address
        sty process_p1::joy1_address+1

        ldx #<read_joy2                         ; joy #2
        ldy #>read_joy2
        stx process_p2::joy2_address
        sty process_p2::joy2_address+1

        lda #06                                 ; $1006
        sta game_start::music_play_addr

        lda #0
        sta $d020
        lda #1
        sta background_color
        lda #11
        sta $d022                               ; used in level
        lda #12
        sta $d023                               ; used in level and extended background color

        ldx #<animate_level_crosscountry
        ldy #>animate_level_crosscountry
        stx game_start::animate_level_addr
        sty game_start::animate_level_addr+1

        ldx #7
l0:     lda spr_colors,x
        sta VIC_SPR0_COLOR,x                    ; sprite color
        dex
        bpl l0

        jsr music_patch_table_2                 ; convert to NTSC if needed



.if !(::RECORD_FIRE)                            ; only copy if not recording fires
                                                ; otherwise the table might have additional
                                                ; jumps
        ldx #0                                  ; computer jump table
l1:
        lda computer_fires_crosscountry_lo,x
        sta computer_fires_lo,x
        lda computer_fires_crosscountry_hi,x
        sta computer_fires_hi,x
        inx
        cpx #FIRE_TBL_SIZE
        bne l1
.endif

        rts
spr_colors:
                .byte 15, 15, 0, 12             ; player 1
                .byte 15, 15, 0, 12             ; player 2
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void computer_setup()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc computer_setup
        lda game_number_of_players
        bne l0                                  ; no computer

        ldx #<read_joy_computer                 ; computer?
        ldy #>read_joy_computer                 ; joystick is controlled by
        stx process_p1::joy1_address            ; computer then
        sty process_p1::joy1_address+1

l0:
        lda #0
        sta computer_fires_idx                  ; next fire to read? 0
        rts
.endproc





sync_raster_anims:      .byte $00
sync_raster_bottom_p1:  .byte $00
sync_raster_bottom_p2:  .byte $00
game_state:             .byte GAME_STATE::GET_SET_GO
p1_state:               .byte PLAYER_STATE::GET_SET_GO
p2_state:               .byte PLAYER_STATE::GET_SET_GO
p1_finished:            .byte FINISH_STATE::NOT_FINISHED  ; don't mix p_finished and p_state together. 0=Not finished, 1=Finished Winner, 2=Finished Loser
p2_finished:            .byte FINISH_STATE::NOT_FINISHED  ; since scrolling should still happen while player is finished

smooth_scroll_x_p1:     .word $0000     ; MSB is used for $d016
smooth_scroll_x_p2:     .word $0000     ; MSB is used for $d016
scroll_idx_p1:          .word 0         ; initialized in init_game
scroll_idx_p2:          .word 0
scroll_speed_p1:        .word SCROLL_SPEED      ; $0100 = normal speed. $0200 = 2x speed. $0080 = half speed
scroll_speed_p2:        .word SCROLL_SPEED      ; $0100 = normal speed. $0200 = 2x speed. $0080 = half speed
expected_joy1_idx:      .byte 0
expected_joy2_idx:      .byte 0
expected_joy:
;        .byte %00000001                 ; up
        .byte %00001001                 ; right or up
;        .byte %00000010                 ; down
        .byte %00000110                 ; left or down
resistance_idx_p2:      .byte 0         ; index in resistance table
resistance_idx_p1:      .byte 0         ; index in resistance table
resistance_tbl:                         ; how fast the unicycle will desacelerate
; autogenerated table: easing_table_generator.py -s256 -m128 -aTrue bezier:0,0.05,0.95,1
.byte   0,  0,  0,  0,  0,  1,  1,  1
.byte   1,  1,  1,  2,  2,  2,  2,  2
.byte   3,  3,  3,  3,  4,  4,  4,  4
.byte   5,  5,  5,  6,  6,  6,  7,  7
.byte   7,  8,  8,  9,  9,  9, 10, 10
.byte  11, 11, 11, 12, 12, 13, 13, 14
.byte  14, 15, 15, 16, 16, 17, 17, 18
.byte  18, 19, 19, 20, 20, 21, 21, 22
.byte  22, 23, 23, 24, 25, 25, 26, 26
.byte  27, 28, 28, 29, 29, 30, 31, 31
.byte  32, 32, 33, 34, 34, 35, 36, 36
.byte  37, 38, 38, 39, 40, 40, 41, 42
.byte  42, 43, 44, 44, 45, 46, 46, 47
.byte  48, 48, 49, 50, 51, 51, 52, 53
.byte  53, 54, 55, 55, 56, 57, 58, 58
.byte  59, 60, 60, 61, 62, 63, 63, 64
.byte  65, 65, 66, 67, 68, 68, 69, 70
.byte  70, 71, 72, 73, 73, 74, 75, 75
.byte  76, 77, 77, 78, 79, 80, 80, 81
.byte  82, 82, 83, 84, 84, 85, 86, 86
.byte  87, 88, 88, 89, 90, 90, 91, 92
.byte  92, 93, 94, 94, 95, 96, 96, 97
.byte  97, 98, 99, 99,100,100,101,102
.byte 102,103,103,104,105,105,106,106
.byte 107,107,108,108,109,109,110,110
.byte 111,111,112,112,113,113,114,114
.byte 115,115,116,116,117,117,117,118
.byte 118,119,119,119,120,120,121,121
.byte 121,122,122,122,123,123,123,124
.byte 124,124,124,125,125,125,125,126
.byte 126,126,126,126,127,127,127,127
.byte 127,127,128,128,128,128,128,128
RESISTANCE_TBL_SIZE = * - resistance_tbl

jump_idx_p1:            .byte 0         ; sine pointer for jump/down sequence
jump_idx_p2:            .byte 0         ; sine pointer for jump/down sequence
jump_tbl:
; autogenerated table: easing_table_generator.py -s32 -m20 -aFalse sin
.byte   2,  2,  2,  2,  1,  2,  2,  1
.byte   1,  2,  1,  0,  1,  1,  0,  0
JUMP_TBL_SIZE = * - jump_tbl

; riding
frame_idx_p1:      .byte 0                              ; index for frame p1
frame_idx_p2:      .byte 0                              ; index for frame p2
frame_hair_riding_tbl:
        .byte SPRITES_POINTER + 3                       ; hair #1 riding
        .byte SPRITES_POINTER + 4                       ; hair #2 riding
FRAME_HAIR_RIDING_TBL_SIZE = * - frame_hair_riding_tbl
frame_hair_winner_tbl:
        .byte SPRITES_POINTER + 7                       ; hair #1 winner
        .byte SPRITES_POINTER + 8                       ; hair #2 winner
FRAME_HAIR_WINNER_TBL_SIZE = * - frame_hair_winner_tbl
frame_body_winner_tbl:
        .byte SPRITES_POINTER + 5                       ; body winner #1
        .byte SPRITES_POINTER + 6                       ; body winner #2
animation_delay_p1:     .byte ACTOR_ANIMATION_SPEED
animation_delay_p2:     .byte ACTOR_ANIMATION_SPEED
animation_idx_p1:       .byte 0         ; index in the animation table
animation_idx_p2:       .byte 0         ; index in the animation table
animation_tbl:
        .byte 255,1,1,255               ; go up, down, down, up
ANIMATION_TBL_SIZE = * - animation_tbl

on_your_marks_lbl:
                ;0123456789|123456789|123456789|123456789|
        scrcode "             on your marks              "
        scrcode "                get set                 "
        scrcode "                  go!                   "

press_space_lbl:
                ;0123456789|123456789|123456789|123456789|
        scrcode "              press space               "

screen:
                ;0123456789|123456789|123456789|123456789|
        scrcode "speed: "
        .byte 32+128,32+128,32+128,32+128,32+128,32+128,32+128,32+128,32+128,32+128,32+128
        scrcode                   "         time: 00:00:0"

background_color:
        .byte 1                                         ; $d021 color for game

sprites_x:      .byte 80, 80, 80, 80            ; player 1
                .byte 80, 80, 80, 80            ; player 2
sprites_y:      .byte (SCROLL_ROW_P1+5)*7+26    ; player 1
                .byte (SCROLL_ROW_P1+5)*7+26
                .byte (SCROLL_ROW_P1+5)*7+26
                .byte (SCROLL_ROW_P1+5)*7+26
                .byte (SCROLL_ROW_P2+5)*7+26    ; player 2
                .byte (SCROLL_ROW_P2+5)*7+26
                .byte (SCROLL_ROW_P2+5)*7+26
                .byte (SCROLL_ROW_P2+5)*7+26
sprite_frames:
                .byte SPRITES_POINTER + 0       ; player 1
                .byte SPRITES_POINTER + 1
                .byte SPRITES_POINTER + 2
                .byte SPRITES_POINTER + 3
                .byte SPRITES_POINTER + 0       ; player 2
                .byte SPRITES_POINTER + 1
                .byte SPRITES_POINTER + 2
                .byte SPRITES_POINTER + 3


remove_go_counter:  .byte $80                           ; delay to remove "go" label

.export game_number_of_players
game_number_of_players: .byte 0                         ; number of human players: one (0) or two (1)
.export game_selected_event
game_selected_event:    .byte 0                         ; which event was selected

computer_fires_idx:     .byte 0
computer_fires_lo:      .res 64,255
computer_fires_hi:      .res 64,255
FIRE_TBL_SIZE = * - computer_fires_hi                   ; size

computer_fires_cyclocross_lo:
        .incbin "fires_cyclocross_lo.bin"               ; XXX: should be in compressed segment
computer_fires_cyclocross_hi:
        .incbin "fires_cyclocross_hi.bin"

computer_fires_crosscountry_lo:                         ; XXX: should be in compressed segment
        .incbin "fires_crosscountry_lo.bin"
computer_fires_crosscountry_hi:
        .incbin "fires_crosscountry_hi.bin"


.segment "COMPRESSED_DATA"

        ; road race data
        .incbin "level-roadrace-charset.prg.exo"        ; 2k at $3000
level_roadrace_charset_exo:

        .incbin "level-roadrace-map.prg.exo"            ; 6k at $4100
level_roadrace_map_exo:

        .incbin "level-roadrace-colors.prg.exo"         ; 256b at $4000
level_roadrace_colors_exo:

        .incbin "music_roadrace.sid.exo"                ; export at $1000
game_music2_exo:


        ; cyclo cross data
        .incbin "level-cyclocross-charset.prg.exo"      ; 2k at $3000
level_cyclocross_charset_exo:

        .incbin "level-cyclocross-map.prg.exo"          ; 6k at $4100
level_cyclocross_map_exo:

        .incbin "level-cyclocross-colors.prg.exo"       ; 256b at $4000
level_cyclocross_colors_exo:

        .incbin "music_cyclocross.sid.exo"              ; export at $1000
game_music1_exo:


        ; cross country data
        .incbin "level-crosscountry-charset.prg.exo"    ; 2k at $3000
level_crosscountry_charset_exo:

        .incbin "level-crosscountry-map.prg.exo"        ; 6k at $4100
level_crosscountry_map_exo:

        .incbin "level-crosscountry-colors.prg.exo"     ; 256b at $4000
level_crosscountry_colors_exo:

        .incbin "music_crosscountry.sid.exo"            ; export at $1000
game_music3_exo:

.byte 0                                                 ; ignore

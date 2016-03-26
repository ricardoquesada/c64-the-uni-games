;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; game scene
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __MAIN_SPRITES_LOAD__

; from utils.s
.import ut_clear_color, ut_setup_tod

.enum GAME_STATE
    ON_YOUR_MARKS                       ; initial scroll
    GET_SET_GO                          ; get set, go
    RIDING                              ; race started
    GAME_OVER                           ; race finished
.endenum

.enum PLAYER_STATE
    GET_SET_GO                          ; race not started
    RIDING                              ; riding: touching ground
    ON_AIR                              ; riding: not touching ground
    FALL                                ; fall down
    FINISHED                            ; finished race
.endenum


LEVEL1_WIDTH = 1024                     ; width of map


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode
.macpack mymacros                       ; my own macros

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants

DEBUG = 7                               ; bitwise: 1=raster-sync code. 2=asserts
                                        ; 4=colllision detection

SCREEN_BASE = $8400                     ; screen starts at $8400


SCROLL_ROW_P1= 3
RASTER_TOP_P1 = 50 + 8 * 21 - 2         ; first raster line
RASTER_BOTTOM_P1 = 50 + 8 * SCROLL_ROW_P1 - 2; moving part of the screen

SCROLL_ROW_P2 = 15
RASTER_TOP_P2 = 50 + 8 * 9 - 2          ; first raster line
RASTER_BOTTOM_P2 = 50 + 8 * SCROLL_ROW_P2 - 2; moving part of the screen

ACTOR_ANIMATION_SPEED = 8               ; animation speed. the bigger the number, the slower it goes
SCROLL_SPEED_P1 = $0130                 ; $0100 = normal speed. $0200 = 2x speed
                                        ; $0080 = half speed
SCROLL_SPEED_P2 = $0130                 ; $0100 = normal speed. $0200 = 2x speed
                                        ; $0080 = half speed
ACCEL_SPEED = $20                       ; how fast the speed will increase

.segment "GAME_CODE"

        sei

        lda #01
        jsr ut_clear_color              ; clears the screen color ram
        jsr init_screen
        jsr init_sound

        jsr init_game

        jsr ut_setup_tod                ; must be called AFTER detect_pal_...

        lda #$00
        sta sync

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

        cli

_mainloop:
:       lda sync
        beq :-

.if (DEBUG & 1)
        dec $d020
.endif

        dec sync

                                        ; events that happens on all game states
        jsr update_scroll               ; screen horizontal scroll
        jsr update_players              ; sprite animations, physics

        lda game_state
        cmp #GAME_STATE::ON_YOUR_MARKS
        beq @on_your_marks
        cmp #GAME_STATE::GET_SET_GO
        beq @get_set_go
        cmp #GAME_STATE::RIDING
        beq @riding
        cmp #GAME_STATE::GAME_OVER
        beq @game_over

@on_your_marks:
        jsr update_on_your_marks
        jmp @cont

@get_set_go:
        jsr update_get_set_go
        jmp @cont

@riding:
        jsr remove_go_lbl
        jsr process_events
        jsr update_time                 ; updates playing time
        jmp @cont

@game_over:

@cont:

.if (DEBUG & 1)
        inc $d020
.endif
        jmp _mainloop

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ handlers
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_top_p1
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        STABILIZE_RASTER

        .repeat 26
                nop
        .endrepeat

        lda #00                         ; black border and background
        sta $d020                       ; to place the score and time
        sta $d021

        lda #%00001000                  ; no scroll,single-color,40-cols
        sta $d016

        lda #<irq_bottom_p1             ; set a new irq vector
        sta $fffe
        lda #>irq_bottom_p1
        sta $ffff

        lda #RASTER_BOTTOM_P1           ; should be triggered when raster = RASTER_BOTTOM
        sta $d012

        asl $d019                       ; ACK raster interrupt

        inc sync

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

.proc irq_bottom_p1
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        STABILIZE_RASTER

        .repeat 26
                nop
        .endrepeat

        lda #14
        sta $d020                       ; border color
        sta $d021                       ; background color

        lda smooth_scroll_x_p1+1        ; scroll x
        sta $d016

        lda #<irq_top_p2                ; set new IRQ-raster vector
        sta $fffe
        lda #>irq_top_p2
        sta $ffff

        lda #RASTER_TOP_P2
        sta $d012

        asl $d019                       ; ACK raster interrupt

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

.proc irq_top_p2
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        STABILIZE_RASTER

        .repeat 26
                nop
        .endrepeat

        lda #00                         ; black border and background
        sta $d020                       ; to place the score and time
        sta $d021

        lda #%00001000                  ; no scroll,single-color,40-cols
        sta $d016

        lda #<irq_bottom_p2             ; set a new irq vector
        sta $fffe
        lda #>irq_bottom_p2
        sta $ffff

        lda #RASTER_BOTTOM_P2           ; should be triggered when raster = RASTER_BOTTOM
        sta $d012

        asl $d019                       ; ACK raster interrupt

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

.proc irq_bottom_p2
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        STABILIZE_RASTER

        .repeat 26
                nop
        .endrepeat

        lda #14
        sta $d020                       ; border color
        sta $d021                       ; background color

        lda smooth_scroll_x_p2+1        ; scroll x
        sta $d016

        lda #<irq_top_p1                ; set new IRQ-raster vector
        sta $fffe
        lda #>irq_top_p1
        sta $ffff

        lda #RASTER_TOP_P1
        sta $d012

        asl $d019                       ; ACK raster interrupt

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_screen()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen

        lda #%00010100                  ; screen:  $0400 %0001xxxx
        sta $d018                       ; charset: $1000 %xxxx010x

        lda #14
        sta $d020
        sta $d021

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
        sta SCREEN_BASE+40*2,x
        sta SCREEN_BASE+40*14,x
        dex
        bpl :-

        ldx #0
_loop2:
        .repeat 6, YY
            lda level1 + LEVEL1_WIDTH* YY,x
            sta SCREEN_BASE + 40 * SCROLL_ROW_P1 + 40 * YY, x
            sta SCREEN_BASE + 40 * SCROLL_ROW_P2 + 40 * YY, x
            tay
            lda level1_colors,y
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

        ldx #<(level1+40)
        ldy #>(level1+40)
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
        sta $d418                       ; volume

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

        lda frames,x
        sta $87f8,x

        lda colors,x
        sta VIC_SPR0_COLOR,x            ; sprite color

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
sprites_x:  .byte 80, 80, 80, 80        ; player 1
            .byte 80, 80, 80, 80        ; player 2
sprites_y:  .byte (SCROLL_ROW_P1+5)*8+36    ; player 1
            .byte (SCROLL_ROW_P1+5)*8+36
            .byte (SCROLL_ROW_P1+5)*8+36
            .byte (SCROLL_ROW_P1+5)*8+36
            .byte (SCROLL_ROW_P2+5)*8+36    ; player 2
            .byte (SCROLL_ROW_P2+5)*8+36
            .byte (SCROLL_ROW_P2+5)*8+36
            .byte (SCROLL_ROW_P2+5)*8+36
frames:     .byte 0, 1, 2, 3            ; player 1
            .byte 0, 1, 2, 3            ; player 2
colors:     .byte 1, 1, 2, 7            ; player 1
            .byte 1, 1, 2, 7            ; player 2

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
        cpx #TOTAL_RESISTANCE
        bne :+
        ldx #TOTAL_RESISTANCE-1
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
        sta SCREEN_BASE + 40 * 12,x
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
        sta SCREEN_BASE + 40 * 12,x
        dex
        bpl :-
        rts

@riding_state:
        ldx #39                         ; display "go!"
:       lda on_your_marks_lbl + 40*2,x
        sta SCREEN_BASE + 40 * 12,x
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

@end:
        rts

counter: .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; remove_go_lbl
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc remove_go_lbl
        lda counter
        beq @end
        dec counter
        bne @end

        ldx #39                         ; clean the "go" message
        lda #$20                        ; ' ' (space)
:       sta SCREEN_BASE + 40 * 12,x
        dex
        bpl :-

@end:
        rts
counter: .byte $80
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; process_events
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc process_events
        jsr process_p1
        jmp process_p2

process_p1:
        lda p1_state                    ; if "on air", decrease speed
        cmp PLAYER_STATE::ON_AIR        ; since it can't accelerate
        beq decrease_speed_p1


        lda $dc01                       ; ready from joy1
        and #%00001100                  ; and get only right and left bits
        cmp expected_joy_p1
        beq increase_velocity_p1
        jmp decrease_speed_p1

increase_velocity_p1:
        eor #%00001100                  ; cycles between left and right -> %01 -> %10
        sta expected_joy_p1

        lda #0
        sta resistance_idx_p1

        clc
        lda scroll_speed_p1             ; increase
        adc #ACCEL_SPEED
        sta scroll_speed_p1             ; LSB
        bcc :+
        inc scroll_speed_p1+1           ; MSB
:       rts

decrease_speed_p1:
        ldx resistance_idx_p1
        sec
        lda scroll_speed_p1            ; subtract
        sbc resistance_tbl,x
        sta scroll_speed_p1            ; LSB

        bcs @end_p1                    ; shortcut for MSB
        dec scroll_speed_p1+1          ; MSB

        bpl @end_p1                    ; if < 0, then 0
        lda #0
        sta scroll_speed_p1
        sta scroll_speed_p1+1

@end_p1:
        inx
        cpx #TOTAL_RESISTANCE
        bne :+
        ldx #TOTAL_RESISTANCE-1
:       stx resistance_idx_p1
        rts


process_p2:
        lda p2_state                    ; if "on air", decrease speed
        cmp PLAYER_STATE::ON_AIR        ; since it can't accelerate
        beq decrease_speed_p2

        lda $dc00                       ; ready from joy2
        and #%00001100                  ; and get only right and left bits
        cmp expected_joy_p2
        beq increase_velocity_p2
        jmp decrease_speed_p2

increase_velocity_p2:
        eor #%00001100                  ; cycles between left and right -> %01 -> %10
        sta expected_joy_p2

        lda #0
        sta resistance_idx_p2

        clc
        lda scroll_speed_p2             ; increase
        adc #ACCEL_SPEED
        sta scroll_speed_p2             ; LSB
        bcc :+
        inc scroll_speed_p2+1           ; MSB
:       rts

decrease_speed_p2:
        ldx resistance_idx_p2
        sec
        lda scroll_speed_p2            ; subtract
        sbc resistance_tbl,x
        sta scroll_speed_p2            ; LSB

        bcs @end_p2                    ; shortcut for MSB
        dec scroll_speed_p2+1          ; MSB

        bpl @end_p2                    ; if < 0, then 0
        lda #0
        sta scroll_speed_p2
        sta scroll_speed_p2+1

@end_p2:
        inx
        cpx #TOTAL_RESISTANCE
        bne :+
        ldx #TOTAL_RESISTANCE-1
:       stx resistance_idx_p2
        rts

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_scroll()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_scroll
        jsr update_scroll_p1
        jmp update_scroll_p2

update_scroll_p1:
        sec                                 ; 16-bit substract
        lda smooth_scroll_x_p1              ; LSB
        sbc scroll_speed_p1
        sta smooth_scroll_x_p1
        lda smooth_scroll_x_p1+1            ; MSB
        sbc scroll_speed_p1+1
        and #%00000111                      ; scroll-x
        sta smooth_scroll_x_p1+1
        bcc :+                              ; only scroll, result is negative
        rts
:
        ldx #0                              ; move the chars to the left and right
@loop:
        .repeat 6,i
                lda SCREEN_BASE+40*(SCROLL_ROW_P1+i)+1,x        ; scroll screen
                sta SCREEN_BASE+40*(SCROLL_ROW_P1+i)+0,x
                lda $d800+40*(SCROLL_ROW_P1+i)+1,x              ; scroll color RAM
                sta $d800+40*(SCROLL_ROW_P1+i)+0,x
        .endrepeat

        inx
        cpx #39
        bne @loop

        ldx scroll_idx_p1
        ldy scroll_idx_p1+1
        stx $f8
        sty $f9
        ldy #0
        .repeat 6,YY
                lda ($f8),y                             ; new char
                sta SCREEN_BASE+40*(SCROLL_ROW_P1+YY)+39
                tax                                     ; color for new char
                lda level1_colors,x
                sta $d800+40*(SCROLL_ROW_P1+YY)+39

                clc
                lda $f9                 ; fetch char 1024 chars ahead
                adc #4
                sta $f9

        .endrepeat

        inc scroll_idx_p1
        bne @end
        inc scroll_idx_p1+1
@end:
        rts

update_scroll_p2:
        sec                                 ; 16-bit substract
        lda smooth_scroll_x_p2              ; LSB
        sbc scroll_speed_p2
        sta smooth_scroll_x_p2
        lda smooth_scroll_x_p2+1            ; MSB
        sbc scroll_speed_p2+1
        and #%00000111                      ; scroll-x
        sta smooth_scroll_x_p2+1
        bcc :+
        rts
:
        ldx #0                          ; move the chars to the left and right
@loop:
        .repeat 6,i
                lda SCREEN_BASE+40*(SCROLL_ROW_P2+i)+1,x        ; scroll screen
                sta SCREEN_BASE+40*(SCROLL_ROW_P2+i)+0,x
                lda $d800+40*(SCROLL_ROW_P2+i)+1,x              ; scroll color RAM
                sta $d800+40*(SCROLL_ROW_P2+i)+0,x
        .endrepeat

        inx
        cpx #39
        bne @loop

        ldx scroll_idx_p2
        ldy scroll_idx_p2+1
        stx $f8
        sty $f9

        ldy #0
        .repeat 6,YY
                lda ($f8),y                                     ; new char
                sta SCREEN_BASE+40*(SCROLL_ROW_P2+YY)+39
                tax
                lda level1_colors,x                             ; color for new char
                sta $d800+40*(SCROLL_ROW_P2+YY)+39

                clc                     ; fetch char from 1024
                lda $f9                 ; fetch char 1024 chars ahead
                adc #4
                sta $f9
        .endrepeat

        inc scroll_idx_p2
        bne @end
        inc scroll_idx_p2+1
@end:

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; update_time
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_time
        lda $dc08                       ; 1/10th seconds.
        tax
        and #%00001111
        ora #$30
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-1) + 39
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-1) + 39

        lda $dc09                       ; seconds. digit
        tax
        and #%00001111
        ora #$30
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-1) + 37
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-1) + 37

        txa                             ; seconds. Ten digit
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-1) + 36
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-1) + 36

        lda $dc0a                       ; minutes. digit
        and #%00001111
        ora #$30
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P1-1) + 34
        sta SCREEN_BASE + 40 * (SCROLL_ROW_P2-1) + 34

        rts
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



update_position_y_p1:
        and #%00000011                          ; tire or rim on ground?
        bne @collision                          ; yes

        ldx #PLAYER_STATE::ON_AIR               ; on air (can accelerate when
        stx p1_state                            ; on air)

                                                ; go down (gravity)
        inc VIC_SPR0_Y                          ; tire
        inc VIC_SPR1_Y                          ; rim
        inc VIC_SPR2_Y                          ; head
        inc VIC_SPR3_Y                          ; hair
        rts
@collision:
        ldx #PLAYER_STATE::RIDING               ; touching ground
        stx p1_state

        cmp #%00000011                          ; only the tire is touching ground?
        bne @end                                ; if only tire, then end
                                                ; otherwise go up
        dec VIC_SPR0_Y                          ; go up
        dec VIC_SPR1_Y
        dec VIC_SPR2_Y
        dec VIC_SPR3_Y
@end:
        rts


update_position_y_p2:
        and #%00110000                          ; tire or rim on ground?
        bne @collision                          ; yes

        ldx #PLAYER_STATE::ON_AIR               ; on air (can accelerate when
        stx p2_state                            ; on air)

                                                ; go down (gravity)
        inc VIC_SPR4_Y                          ; tire
        inc VIC_SPR5_Y                          ; rim
        inc VIC_SPR6_Y                          ; head
        inc VIC_SPR7_Y                          ; hair
        rts
@collision:
        ldx #PLAYER_STATE::RIDING               ; touching ground
        stx p2_state

        cmp #%00110000                          ; only the tire is touching ground?
        bne @end                                ; if only tire, then end
                                                ; otherwise go up
        dec VIC_SPR4_Y                          ; go up
        dec VIC_SPR5_Y
        dec VIC_SPR6_Y
        dec VIC_SPR7_Y
@end:
        rts

update_frame_p1:
        dec animation_delay_p1
        beq :+
        rts
:
        lda #ACTOR_ANIMATION_SPEED
        sta animation_delay_p1

        ldx animation_idx_p1
        lda VIC_SPR2_Y
        clc
        adc animation_tbl,x
        sta VIC_SPR2_Y
        sta VIC_SPR3_Y

        inx
        cpx #TOTAL_ANIMATION
        bne :+
        ldx #0
:       stx animation_idx_p1
        rts

update_frame_p2:
        dec animation_delay_p2
        beq :+
        rts
:
        lda #ACTOR_ANIMATION_SPEED
        sta animation_delay_p2

        ldx animation_idx_p2
        lda VIC_SPR6_Y
        clc
        adc animation_tbl,x
        sta VIC_SPR6_Y
        sta VIC_SPR7_Y

        inx
        cpx #TOTAL_ANIMATION
        bne :+
        ldx #0
:       stx animation_idx_p2
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

        lda #%00001001
        sta $d405                       ; attack / decay
        lda #0
        sta $d406                       ; sustain / release
        lda freq_table_lo,x
        sta $d400                       ; freq lo
        lda freq_table_hi,x
        sta $d401                       ; freq hi
        lda #%00010001                  ; gate: start Attack/Decay/Sus. Sawtooth
        sta $d404                       ; control register
        rts
.endproc


sync:                   .byte $00
game_state:             .byte GAME_STATE::GET_SET_GO
p1_state:               .byte PLAYER_STATE::GET_SET_GO
p2_state:               .byte PLAYER_STATE::GET_SET_GO

smooth_scroll_x_p1:     .word $0000     ; MSB is used for $d016
smooth_scroll_x_p2:     .word $0000     ; MSB is used for $d016
scroll_idx_p1:          .word 0         ; initialized in init_game
scroll_idx_p2:          .word 0
scroll_speed_p1:        .word SCROLL_SPEED_P1  ; $0100 = normal speed. $0200 = 2x speed. $0080 = half speed
scroll_speed_p2:        .word SCROLL_SPEED_P2  ; $0100 = normal speed. $0200 = 2x speed. $0080 = half speed
expected_joy_p1:        .byte %00001000 ; joy value. default left
expected_joy_p2:        .byte %00001000 ; joy value. default left
resistance_idx_p2:      .byte 0         ; index in resistance table
resistance_idx_p1:      .byte 0         ; index in resistance table
resistance_tbl:                         ; how fast the unicycle will desacelerate
; autogenerated table: easing_table_generator.py -s64 -m32 -aTrue bezier:0,0.6,0.4,1
.byte   1,  2,  3,  3,  4,  5,  5,  6
.byte   7,  7,  8,  8,  9,  9, 10, 10
.byte  11, 11, 12, 12, 12, 13, 13, 14
.byte  14, 14, 14, 15, 15, 15, 16, 16
.byte  16, 17, 17, 17, 18, 18, 18, 19
.byte  19, 19, 20, 20, 20, 21, 21, 22
.byte  22, 23, 23, 24, 24, 25, 25, 26
.byte  27, 27, 28, 29, 29, 30, 31, 32
TOTAL_RESISTANCE = * - resistance_tbl
animation_delay_p1:     .byte ACTOR_ANIMATION_SPEED
animation_delay_p2:     .byte ACTOR_ANIMATION_SPEED
animation_idx_p1:       .byte 0         ; index in the animation table
animation_idx_p2:       .byte 0         ; index in the animation table
animation_tbl:
        .byte 255,1,1,255               ; go up, down, down, up
TOTAL_ANIMATION = * - animation_tbl

on_your_marks_lbl:
                ;0123456789|123456789|123456789|123456789|
    scrcode     "             on your marks              "
    scrcode     "                get set                 "
    scrcode     "                  go!                   "

screen:
                ;0123456789|123456789|123456789|123456789|
        scrcode "                                 00:00:0"

level1:
    ; 1024x6 map
    .incbin "level1-map.bin"

level1_colors:
    .incbin "level1-colors.bin"

; autogenerated table: freq_table_generator.py -b440 -o8 -s12 985248
freq_table_lo:
.byte $16,$27,$39,$4b,$5f,$74,$8a,$a1,$ba,$d4,$f0,$0e  ; 0
.byte $2d,$4e,$71,$96,$be,$e7,$14,$42,$74,$a9,$e0,$1b  ; 1
.byte $5a,$9c,$e2,$2d,$7b,$cf,$27,$85,$e8,$51,$c1,$37  ; 2
.byte $b4,$38,$c4,$59,$f7,$9d,$4e,$0a,$d0,$a2,$81,$6d  ; 3
.byte $67,$70,$89,$b2,$ed,$3b,$9c,$13,$a0,$45,$02,$da  ; 4
.byte $ce,$e0,$11,$64,$da,$76,$39,$26,$40,$89,$04,$b4  ; 5
.byte $9c,$c0,$23,$c8,$b4,$eb,$72,$4c,$80,$12,$08,$68  ; 6
.byte $39,$80,$45,$90,$68,$d6,$e3,$99,$00,$24,$10,$ff  ; 7
freq_table_hi:
.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02  ; 0
.byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04  ; 1
.byte $04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08  ; 2
.byte $08,$09,$09,$0a,$0a,$0b,$0c,$0d,$0d,$0e,$0f,$10  ; 3
.byte $11,$12,$13,$14,$15,$17,$18,$1a,$1b,$1d,$1f,$20  ; 4
.byte $22,$24,$27,$29,$2b,$2e,$31,$34,$37,$3a,$3e,$41  ; 5
.byte $45,$49,$4e,$52,$57,$5c,$62,$68,$6e,$75,$7c,$83  ; 6
.byte $8b,$93,$9c,$a5,$af,$b9,$c4,$d0,$dd,$ea,$f8,$ff  ; 7


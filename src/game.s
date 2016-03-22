;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; game scene
;
; Zero Page global registers:
;   $f9/$fa -> modified temporary in collision detection.
;               can be altered by other tmp functions
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __MAIN_SPRITES_LOAD__

; from utils.s
.import ut_clear_screen, ut_clear_color, ut_get_key, ut_read_joy2, ut_setup_tod

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
SCROLL_SPEED_P1 = $0100                 ; $0100 = normal speed. $0200 = 2x speed
                                        ; $0080 = half speed
SCROLL_SPEED_P2 = $0100                 ; $0100 = normal speed. $0200 = 2x speed
                                        ; $0080 = half speed
ACCEL_SPEED = $20                       ; how fast the speed will increase

.segment "GAME_CODE"

        sei

        lda #01
        jsr ut_clear_color              ; clears the screen color ram
        jsr init_screen
        jsr init_game

        jsr ut_setup_tod                ; must be called AFTER detect_pal_...
        lda #0
        sta $dc0b                       ; Set TOD-Clock to 0 (hours)
        sta $dc0a                       ;- (minutes)
        sta $dc09                       ;- (seconds)
        sta $dc08                       ;- (deciseconds)

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

        jsr process_events
        jsr update_time                 ; updates playing time
        jsr update_scroll               ; screen horizontal scroll
        jsr update_players              ; sprite animations, physics


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

        lda #%00010100                  ; screen: $0400, charset $1800
        sta $d018

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

        ldx #40*2-1                     ; 2 lines only
:       lda screen,x
        ora #$80                        ; using second half of the romset
        sta SCREEN_BASE,x
        dex
        bpl :-

        ldx #0
_loop2:
        .repeat 6, YY
            lda level1 + 256 * YY,x
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

        ldx #00
        stx <score
        stx >score
        stx <time
        stx >time

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
; process_events
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc process_events
        jsr process_p1
        jmp process_p2

process_p1:
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
        ldx #0                          ; move the chars to the left and right
@loop:
        .repeat 6,i
                lda SCREEN_BASE+40*(SCROLL_ROW_P1+i)+1,x
                sta SCREEN_BASE+40*(SCROLL_ROW_P1+i)+0,x
                lda $d800+40*(SCROLL_ROW_P1+i)+1,x
                sta $d800+40*(SCROLL_ROW_P1+i)+0,x
        .endrepeat

        inx
        cpx #39
        bne @loop

        ldx scroll_idx_p1
        inc scroll_idx_p1
        .repeat 6,i
                lda level1 + 256 * i,x
                sta SCREEN_BASE+40*(SCROLL_ROW_P1+i)+39
                tay
                lda level1_colors,y
                sta $d800+40*(SCROLL_ROW_P1+i)+39
        .endrepeat

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
                lda SCREEN_BASE+40*(SCROLL_ROW_P2+i)+1,x
                sta SCREEN_BASE+40*(SCROLL_ROW_P2+i)+0,x
                lda $d800+40*(SCROLL_ROW_P2+i)+1,x
                sta $d800+40*(SCROLL_ROW_P2+i)+0,x
        .endrepeat

        inx
        cpx #39
        bne @loop

        ldx scroll_idx_p2
        inc scroll_idx_p2
        .repeat 6,i
                lda level1 + 256 * i,x
                sta SCREEN_BASE+40*(SCROLL_ROW_P2+i)+39
                tay
                lda level1_colors,y
                sta $d800+40*(SCROLL_ROW_P2+i)+39
        .endrepeat

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; update_time
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_time

        lda $dc09                       ; seconds. digit
        tax
        and #%00001111
        ora #($80 + $30)
        sta SCREEN_BASE + 40 * 01 + 38

        txa                             ; seconds. Ten digit
        lsr
        lsr
        lsr
        lsr
        ora #($80 + $30)
        sta SCREEN_BASE + 40 * 01 + 37

        lda $dc0a                       ; minutes. digit
        and #%00001111
        ora #$b0
        sta SCREEN_BASE + 40 * 01 + 35

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_players()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_players
        jsr update_frame
        jmp update_position_y

update_position_y:
        lda $d01f
        and #%00110000                          ; tire or rim on ground?
        bne collision                           ; yes 

                                                ; go down (gravity)
        inc VIC_SPR4_Y                          ; tire
        inc VIC_SPR5_Y                          ; rim
        inc VIC_SPR6_Y                          ; head
        inc VIC_SPR7_Y                          ; hair
        rts
collision:  
        cmp #%00110000                          ; only the tire is touching ground?
        bne end                                 ; if only tire, then end
                                                ; otherwise go up
        dec VIC_SPR4_Y                          ; go up, and return
        dec VIC_SPR5_Y                          ; go up, and return
        dec VIC_SPR6_Y                          ; go up, and return
        dec VIC_SPR7_Y                          ; go up, and return
end:
        rts

update_frame:
        dec animation_delay
        beq :+
        rts
:
        lda #ACTOR_ANIMATION_SPEED
        sta animation_delay

        ldx animation_idx
        lda VIC_SPR6_Y
        clc
        adc animation_tbl,x
        sta VIC_SPR6_Y
        sta VIC_SPR7_Y

        inx
        cpx #TOTAL_ANIMATION
        bne :+
        ldx #0
:       stx animation_idx
        rts
.endproc


sync:                   .byte $00

animation_delay:        .byte ACTOR_ANIMATION_SPEED
score:                  .word $0000
time:                   .word $0000
smooth_scroll_x_p1:     .word $0000     ; MSB is used for $d016
smooth_scroll_x_p2:     .word $0000     ; MSB is used for $d016
scroll_speed_p1:        .word SCROLL_SPEED_P1  ; $0100 = normal speed. $0200 = 2x speed. $0080 = half speed
scroll_speed_p2:        .word SCROLL_SPEED_P2  ; $0100 = normal speed. $0200 = 2x speed. $0080 = half speed
scroll_idx_p1:          .byte 0
scroll_idx_p2:          .byte 0
expected_joy_p1:        .byte %00001000 ; joy value. default left
expected_joy_p2:        .byte %00001000 ; joy value. default left
resistance_idx_p2:      .byte 0         ; index in resistance table
resistance_idx_p1:      .byte 0         ; index in resistance table
resistance_tbl:                         ; how fast the unicycle will desacelerate
; autogenerated table: easing_table_generator.py -s64 -m32 -aTrue bezier:0,0.1,0.9,1
.byte   0,  0,  1,  1,  1,  1,  2,  2
.byte   3,  3,  3,  4,  4,  5,  5,  6
.byte   6,  7,  8,  8,  9,  9, 10, 11
.byte  11, 12, 13, 13, 14, 15, 15, 16
.byte  17, 17, 18, 19, 19, 20, 21, 21
.byte  22, 23, 23, 24, 24, 25, 26, 26
.byte  27, 27, 28, 28, 29, 29, 29, 30
.byte  30, 31, 31, 31, 31, 32, 32, 32
TOTAL_RESISTANCE = * - resistance_tbl
animation_idx:          .byte 0         ; index in the animation table
animation_tbl:
        .byte 255,1,1,255               ; go up, down, down, up
TOTAL_ANIMATION = * - animation_tbl

screen:
                ;0123456789|123456789|123456789|123456789|
        scrcode " score                             time "
        scrcode " 00000                             0:00 "

level1:
    ; 256x6 map
    .incbin "level1-map.bin"

level1_colors:
    .incbin "level1-colors.bin"


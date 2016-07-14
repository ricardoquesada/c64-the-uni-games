;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; High Scores screen
;
; Uses $fe/$ff. $fe/$ff CANNOT be used by other functions
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; from utils.s
.import ut_clear_color, ut_get_key, ut_clear_screen

; from main.s
.import sync_timer_irq
.import menu_read_events
.import mainscreen_colors

UNI1_ROW = 10                           ; unicyclist #1 x,y
UNI1_COL = 0
UNI2_ROW = 37                           ; unicylists #2 x,y
UNI2_COL = 10


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
.include "myconstants.inc"


.segment "HI_CODE"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; scores_init
;------------------------------------------------------------------------------;
.export scores_init
.proc scores_init
        sei
        lda #0
        sta score_counter

        lda #%00000000                  ; enable only PAL/NTSC scprite
        sta VIC_SPR_ENA

        lda #$01
        jsr ut_clear_color

        jsr init_screen
        cli


scores_mainloop:
        lda sync_timer_irq
        bne play_music

        jsr menu_read_events
        cmp #%00010000                  ; space or button
        bne scores_mainloop
        rts                             ; return to caller (main menu)
play_music:
        dec sync_timer_irq
        jsr $1003
        jsr paint_score
        jsr animate_unicyclists
        jmp scores_mainloop
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen

        ldx #0
l0:
        lda hiscores_map,x
        sta SCREEN0_BASE,x
        tay
        lda mainscreen_colors,y
        sta $d800,x

        lda hiscores_map + $0100,x
        sta SCREEN0_BASE + $0100,x
        tay
        lda mainscreen_colors,y
        sta $d900,x

        lda hiscores_map + $0200,x
        sta SCREEN0_BASE + $0200,x
        tay
        lda mainscreen_colors,y
        sta $da00,x

        lda hiscores_map + $02e8,x
        sta SCREEN0_BASE + $02e8,x
        tay
        lda mainscreen_colors,y
        sta $dae8,x

        inx
        bne l0


        ldx #39
:       lda categories,x                ; displays the  category: "10k road racing"
        sta SCREEN0_BASE + 280,x
        dex
        bpl :-

        lda #2                          ; set color for unicyclist
        .repeat 5,YY
                ldx #2
:               sta $d800+(YY+UNI1_ROW)*40+UNI1_COL,x
                sta $d800+(YY+UNI2_ROW)*40+UNI2_COL,x
                dex
                bpl :-
        .endrepeat

        lda #3                          ; set color for unicycle
        .repeat 5,YY
                ldx #2
:               sta $d800+(YY+UNI1_ROW+6)*40+UNI1_COL,x
                sta $d800+(YY+UNI2_ROW+6)*40+UNI2_COL,x
                dex
                bpl :-
        .endrepeat


        ldx #<(SCREEN0_BASE + 40 * 10 + 6)  ; init "save" pointer
        ldy #>(SCREEN0_BASE + 40 * 10 + 6)  ; start writing at 10th line
        stx $fe
        sty $ff
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; paint_score
; entries:
;       X = score to draw
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc paint_score

        dec delay
        beq paint
        rts

paint:
        lda #$04
        sta delay

        ldx score_counter
        cpx #8                          ; paint only 8 scores
        beq @end

        jsr @print_highscore_entry

        clc                             ; pointer to the next line in the screen
        lda $fe
        adc #(40 * 2)                   ; skip one line
        sta $fe
        bcc :+
        inc $ff
:
        inc score_counter

@end:
        rts

@print_highscore_entry:
        txa                             ; x has the high score entry index

        ldy #$00                        ; y = screen idx

        pha
        clc
        adc #$01                        ; positions start with 1, not 0

        cmp #10                         ; print position
        bne @print_second_digit

        lda #$31                        ; hack: if number is 10, print '1'. $31 = '1'
        sta ($fe),y                     ; otherwise, skip to second number
        ora #$40
        iny
        lda #00                         ; second digit is '0'
        jmp :+

@print_second_digit:
        iny
:
        clc
        adc #$30                        ; A = high_score entry.
        sta ($fe),y
        iny

        lda #$2e                        ; print '.'
        sta ($fe),y
        iny


        lda #10                         ; print name. 10 chars
        sta @tmp_counter

        txa                             ; multiply x by 16, since each entry has 16 bytes
        asl
        asl
        asl
        asl
        tax                             ; x = high score pointer

:       lda entries,x                   ; points to entry[i].name
        sta ($fe),y                     ; pointer to screen
        iny
        inx
        dec @tmp_counter
        bne :-


        lda #6                          ; print score. 6 digits
        sta @tmp_counter

        tya                             ; advance some chars
        clc
        adc #8
        tay

:       lda entries,x                   ; points to entry[i].score
        clc
        adc #$30
        sta ($fe),y                     ; pointer to screen
        iny
        inx
        dec @tmp_counter
        bne :-

        pla
        tax
        rts

@tmp_counter:
        .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void animate_unicyclists(void)
; uses $fb-$ff
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc animate_unicyclists

        dec delay
        beq :+
        rts
:
        lda #50
        sta delay


        rts
delay:
        .byte 50

.endproc


                ;0123456789|123456789|123456789|123456789|
categories:
        scrcode "             10k road racing            "
        scrcode "              muni downhill             "
        scrcode "             stairs climbing            "

entries:
        ; high score entry:
        ;     name: 10 bytes in PETSCII
        ;     score: 6 bytes
        ;        0123456789
        scrcode "tom       "
        .byte  9,0,0,0,0,0
        scrcode "chris     "
        .byte  8,0,0,0,0,0
        scrcode "dragon    "
        .byte  7,0,0,0,0,0
        scrcode "corbin    "
        .byte  6,0,0,0,0,0
        scrcode "jimbo     "
        .byte  5,0,0,0,0,0
        scrcode "ashley    "
        .byte  4,0,0,0,0,0
        scrcode "josh      "
        .byte  3,0,0,0,0,0
        scrcode "michele   "
        .byte  2,0,0,0,0,0

score_counter: .byte 0                  ; score that has been drawn
delay:         .byte $10                ; delay used to print the scores

hiscores_map:
        .incbin "hiscores-map.bin"

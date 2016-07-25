;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; High Scores screen
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
        lda #0
        sta score_counter

        lda #%00000000                  ; enable only PAL/NTSC scprite
        sta VIC_SPR_ENA

        lda #$01
        jsr ut_clear_color

        lda #$20
        jsr ut_clear_screen

        jsr scores_init_screen


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
        jmp scores_mainloop
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; scores_init_screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc scores_init_screen

        ldx #0
l0:
        lda hiscores_map,x
        sta SCREEN0_BASE,x
        tay
        lda mainscreen_colors,y
        sta $d800,x

        inx
        cpx #240
        bne l0


        ldx #39
:       lda categories,x                ; displays the  category: "10k road racing"
        sta SCREEN0_BASE + 280,x
        dex
        bpl :-

        ldx #<(SCREEN0_BASE + 40 * 10 + 6)  ; init "save" pointer
        ldy #>(SCREEN0_BASE + 40 * 10 + 6)  ; start writing at 10th line
        stx zp_hs_ptr_lo
        sty zp_hs_ptr_hi
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
        lda zp_hs_ptr_lo
        adc #(40 * 2)                   ; skip one line
        sta zp_hs_ptr_lo
        bcc :+
        inc zp_hs_ptr_hi
:
        inc score_counter

@end:
        rts

@print_highscore_entry:
        txa                             ; x has the high score entry index

        ldy #$00                        ; y = screen idx

        clc
        adc #$01                        ; positions start with 1, not 0

        cmp #10                         ; print position
        bne @print_second_digit

        lda #$31                        ; hack: if number is 10, print '1'. $31 = '1'
        sta (zp_hs_ptr_lo),y            ; otherwise, skip to second number
        iny
        lda #00                         ; second digit is '0'
        jmp :+

@print_second_digit:
        iny
:
        ora #$30
        sta (zp_hs_ptr_lo),y
        iny

        lda #$2e                        ; print '.'
        sta (zp_hs_ptr_lo),y
        iny


        lda #10                         ; print name. 10 chars
        sta zp_tmp00

        txa                             ; multiply x by 16, since each entry has 16 bytes
        asl
        asl
        asl
        asl
        tax                             ; x = high score pointer

:       lda entries_roadrace,x          ; points to entry[i].name
        sta (zp_hs_ptr_lo),y            ; pointer to screen
        iny
        inx
        dec zp_tmp00
        bne :-


        lda #6                          ; print score. 6 digits
        sta zp_tmp00

        tya                             ; advance some chars
        clc
        adc #8
        tay

                                        ; minutes
        lda entries_roadrace,x          ; points to entry[i].score
        ora #$30
        sta (zp_hs_ptr_lo),y            ; write to screen

        iny                             ; ptr to screen++
        lda #58                         ; ':'
        sta (zp_hs_ptr_lo),y            ; write to screen

                                        ; seconds (first digit)
        iny                             ; ptr to screen++
        inx                             ; ptr to score++
        lda entries_roadrace,x          ; points to entry[i].score
        ora #$30
        sta (zp_hs_ptr_lo),y            ; write to screen

                                        ; seconds (second digit)
        iny                             ; ptr to screen++
        inx                             ; ptr to score++
        lda entries_roadrace,x          ; points to entry[i].score
        ora #$30
        sta (zp_hs_ptr_lo),y            ; write to screen

        iny                             ; ptr to screen++
        lda #58                         ; ':'
        sta (zp_hs_ptr_lo),y            ; write to screen

                                        ; decimal
        iny                             ; ptr to screen++
        inx                             ; ptr to score++
        lda entries_roadrace,x          ; points to entry[i].score
        ora #$30
        sta (zp_hs_ptr_lo),y            ; write to screen

        rts
.endproc


score_counter: .byte 0                  ; score that has been drawn
delay:         .byte $10                ; delay used to print the scores

                ;0123456789|123456789|123456789|123456789|
categories:
        scrcode "                road race               "
        scrcode "               cyclo cross              "
        scrcode "              cross country             "

hiscores_map:
        .incbin "hiscores-map.bin"      ; 40 * 6

; fixed at $e80 to load/save them from disk
.segment "SCORES"
entries_roadrace:
        ; high score entry: must have exactly 16 bytes each entry
        ;     name: 10 bytes in PETSCII
        ;     score: 4 bytes
        ;     pad: 2 bytes
        ;        0123456789
        scrcode "tom       "
        .byte 0,4,0,2
        .byte 0,0               ; ignore
        scrcode "chris     "
        .byte 0,4,0,8
        .byte 0,0               ; ignore
        scrcode "dragon    "
        .byte 0,4,1,0
        .byte 0,0               ; ignore
        scrcode "corbin    "
        .byte 0,4,1,5
        .byte 0,0               ; ignore
        scrcode "jimbo     "
        .byte 0,4,2,2
        .byte 0,0               ; ignore
        scrcode "ashley    "
        .byte 0,4,5,9
        .byte 0,0               ; ignore
        scrcode "josh      "
        .byte 0,4,6,3
        .byte 0,0               ; ignore
        scrcode "michele   "
        .byte 0,4,8,8
        .byte 0,0               ; ignore

entries_crosscountry:
        ; high score entry: must have exactly 16 bytes each entry
        ;     name: 10 bytes in PETSCII
        ;     score: 4 bytes
        ;     pad: 2 bytes
        ;        0123456789
        scrcode "tom       "
        .byte 0,4,0,2
        .byte 0,0               ; ignore
        scrcode "chris     "
        .byte 0,4,0,8
        .byte 0,0               ; ignore
        scrcode "dragon    "
        .byte 0,4,1,0
        .byte 0,0               ; ignore
        scrcode "corbin    "
        .byte 0,4,1,5
        .byte 0,0               ; ignore
        scrcode "jimbo     "
        .byte 0,4,2,2
        .byte 0,0               ; ignore
        scrcode "ashley    "
        .byte 0,4,5,9
        .byte 0,0               ; ignore
        scrcode "josh      "
        .byte 0,4,6,3
        .byte 0,0               ; ignore
        scrcode "michele   "
        .byte 0,4,8,8
        .byte 0,0               ; ignore

entries_cyclocross:
        ; high score entry: must have exactly 16 bytes each entry
        ;     name: 10 bytes in PETSCII
        ;     score: 4 bytes
        ;     pad: 2 bytes
        ;        0123456789
        scrcode "tom       "
        .byte 0,4,0,2
        .byte 0,0               ; ignore
        scrcode "chris     "
        .byte 0,4,0,8
        .byte 0,0               ; ignore
        scrcode "dragon    "
        .byte 0,4,1,0
        .byte 0,0               ; ignore
        scrcode "corbin    "
        .byte 0,4,1,5
        .byte 0,0               ; ignore
        scrcode "jimbo     "
        .byte 0,4,2,2
        .byte 0,0               ; ignore
        scrcode "ashley    "
        .byte 0,4,5,9
        .byte 0,0               ; ignore
        scrcode "josh      "
        .byte 0,4,6,3
        .byte 0,0               ; ignore
        scrcode "michele   "
        .byte 0,4,8,8
        .byte 0,0               ; ignore


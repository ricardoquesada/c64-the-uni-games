;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; High Scores screen
;
; Uses $f9/$fa temporary. $f9/$fa can be used by other temporary functions
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__
.import __MAIN_SPRITES_LOAD__, __GAME_CODE_LOAD__

; from utils.s
.import ut_clear_color, ut_get_key

; from main.s
.import irq_open_borders

SCREEN_BASE = $8400                     ; screen address

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants


.segment "HIGH_SCORES_CODE"

        sei

        lda #00                         ; disable raster irq
        sta $d01a
        lda $dc0d                       ; clear interrupts and ACK irq
        lda $dd0d
        asl $d019

        cli

        lda #$01
        jsr ut_clear_color
        jsr init_screen

@main_loop:
        jsr ut_get_key
        bcc @main_loop

        cmp #$47                        ; space ?
        bne @main_loop
        jmp __MAIN_CODE_LOAD__

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_screen
;------------------------------------------------------------------------------;
; paints the screen with the "main menu" screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen

        ldx #0                          ; clear the screen: 1000 bytes. 40*25
        lda #$20
:       sta SCREEN_BASE+$0000,x               ; can't call clear_screen
        sta SCREEN_BASE+$0100,x               ; since we are in VIC bank 2
        sta SCREEN_BASE+$0200,x
        sta SCREEN_BASE+$02e8,x
        inx
        bne :-

        ldx #0
:       lda high_scores_screen,x        ; display the "high scores" text at the top
        sta SCREEN_BASE,x
        inx
        cpx #40                         ; draw 1 line
        bne :-

        ldx #<(SCREEN_BASE + 40 * 3)          ; init "save" pointer
        ldy #>(SCREEN_BASE + 40 * 3)          ; start writing at 3rd line
        stx $f9
        sty $fa


        ldx #00                         ; x has the high score entry

@loop:
        jsr @delay


        jsr @print_highscore_entry

        clc                             ; pointer to the next line in the screen
        lda $f9
        adc #40 * 2 + 0                 ; skip one line
        sta $f9
        bcc :+
        inc $fa
:
        inx
        cpx #10                         ; repeat 10 times. there are only 10 high scores
        bne @loop

        rts

@delay:
        txa
        pha
        tya
        pha

        ldx #$10                        ; small delay
:       ldy #$00
:       dey
        bne :-
        dex
        bne :--

        pla
        tay
        pla
        tax
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
        sta ($f9),y                     ; otherwise, skip to second number
        ora #$40
        iny
        lda #00                         ; second digit is '0'
        jmp :+

@print_second_digit:
        iny
:
        clc
        adc #$30                        ; A = high_score entry.
        sta ($f9),y
        iny

        lda #$2e                        ; print '.'
        sta ($f9),y
        iny


        lda #10                         ; print name
        sta @tmp_counter

        txa                             ; multiply x by 16, since each entry has 16 bytes
        asl
        asl
        asl
        asl
        tax                             ; x = high score pointer

:       lda entries,x                   ; points to entry[i].name
        sta ($f9),y                     ; pointer to screen
        iny
        inx
        dec @tmp_counter
        bne :-


        lda #6                          ; print score
        sta @tmp_counter

        tya                             ; advance some chars
        clc
        adc #21
        tay

:       lda entries,x                   ; points to entry[i].score
        clc
        adc #$30
        sta ($f9),y                     ; pointer to screen
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


high_scores_screen:
                ;0123456789|123456789|123456789|123456789|
        scrcode "               high scores              "


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
        scrcode "josh      "
        .byte  6,0,0,0,0,0
        scrcode "ashley    "
        .byte  5,0,0,0,0,0
        scrcode "kevin     "
        .byte  4,0,0,0,0,0
        scrcode "michele   "
        .byte  3,0,0,0,0,0
        scrcode "corbin    "
        .byte  2,0,0,0,0,0
        scrcode "beau      "
        .byte  1,0,0,0,0,0
        scrcode "ricardo123"
        .byte  0,0,0,0,0,0

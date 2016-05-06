;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; High Scores screen
;
; Uses $f0/$f1. $f0/$f1 CANNOT be used by other functions
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; from utils.s
.import ut_clear_color, ut_get_key

; from main.s
.import sync_timer_irq
.import menu_read_events

BANK_BASE = $0000
SCREEN0_BASE = BANK_BASE + $0400                    ; screen address
SCREEN1_BASE = $0c00
SPRITES_BASE = BANK_BASE + $2400                    ; Sprite 0 at $2400
SPRITES_POINTER = <((SPRITES_BASE .MOD $4000) / 64) ; Sprite 0 at 144
SPRITE_PTR = SCREEN0_BASE + 1016                    ; right after the screen, at $7f8

UNI1_ROW = 13                           ; unicyclist #1 x,y
UNI1_COL = 0
UNI2_ROW = 3                            ; unicylists #2 x,y
UNI2_COL = 37


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants


.segment "HIGH_SCORES_CODE"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; scores_init
;------------------------------------------------------------------------------;
.export scores_init
.proc scores_init
        lda #0
        sta $d01a                       ; no raster IRQ, only timer IRQ
        sta score_counter

        lda #$01
        jsr ut_clear_color

        lda #%00110100                  ; video addres at $0c00
        sta $d018

        jsr init_screen


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

        ldx #0                          ; clear the screen: 1000 bytes. 40*25
        lda #$20
:       sta SCREEN1_BASE+$0000,x         ; can't call clear_screen
        sta SCREEN1_BASE+$0100,x         ; since we are in VIC bank 2
        sta SCREEN1_BASE+$0200,x
        sta SCREEN1_BASE+$02e8,x
        inx
        bne :-

        ldx #39
:       lda categories,x                ; displays the  category: "10k road racing"
        sta SCREEN1_BASE,x
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

        .repeat 9,YY                    ; paint two unicyclist
            ldx #2
:           lda unicyclists_map+6*YY,x ; bottom left unicyclsit
            sta SCREEN1_BASE+40*(YY+UNI1_ROW)+UNI1_COL,x
            lda unicyclists_map+6*YY+3,x   ; top right unicyclist
            sta SCREEN1_BASE+40*(YY+UNI2_ROW)+UNI2_COL,x
            dex
            bpl :-
        .endrepeat


        ldx #<(SCREEN1_BASE + 40 * 3)    ; init "save" pointer
        ldy #>(SCREEN1_BASE + 40 * 3)    ; start writing at 3rd line
        stx $f0
        sty $f1
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
        cpx #10
        beq @end

        jsr @print_highscore_entry

        clc                             ; pointer to the next line in the screen
        lda $f0
        adc #40 * 2 + 1                 ; skip one line
        sta $f0
        bcc :+
        inc $f1
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
        sta ($f0),y                     ; otherwise, skip to second number
        ora #$40
        iny
        lda #00                         ; second digit is '0'
        jmp :+

@print_second_digit:
        iny
:
        clc
        adc #$30                        ; A = high_score entry.
        sta ($f0),y
        iny

        lda #$2e                        ; print '.'
        sta ($f0),y
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
        sta ($f0),y                     ; pointer to screen
        iny
        inx
        dec @tmp_counter
        bne :-


        lda #6                          ; print score
        sta @tmp_counter

        tya                             ; advance some chars
        clc
        adc #11
        tay

:       lda entries,x                   ; points to entry[i].score
        clc
        adc #$30
        sta ($f0),y                     ; pointer to screen
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

        ldy #0
        ldx #4
l0:
        lda addresses_lo,x          ; swaps values
        sta $fc
        lda addresses_hi,x
        sta $fd
        lda addresses_lo+5,x
        sta $fe
        lda addresses_hi+5,x
        sta $ff
                                    ; swaps left and right values
                                    ; using $fb as tmp variable
        lda ($fc),y                 ; A = left
        sta $fb                     ; tmp = A
        lda ($fe),y                 ; A = right
        sta ($fc),y                 ; left = A
        lda $fb                     ; A = tmp
        sta ($fe),y                 ; right = tmp

        dex
        bpl l0

        rts
delay:
        .byte 50
bytes_to_swap:
ADDRESS0 = SCREEN1_BASE+(UNI1_ROW+1)*40+UNI1_COL+0   ; left eye
ADDRESS1 = SCREEN1_BASE+(UNI1_ROW+1)*40+UNI1_COL+2   ; right eye
ADDRESS2 = SCREEN1_BASE+(UNI1_ROW+3)*40+UNI1_COL+0   ; left arm
ADDRESS3 = SCREEN1_BASE+(UNI1_ROW+3)*40+UNI1_COL+2   ; right arm
ADDRESS4 = SCREEN1_BASE+(UNI1_ROW+7)*40+UNI1_COL+1   ; hub

ADDRESS5 = SCREEN1_BASE+(UNI2_ROW+1)*40+UNI2_COL+0   ; left eye
ADDRESS6 = SCREEN1_BASE+(UNI2_ROW+1)*40+UNI2_COL+2   ; right eye
ADDRESS7 = SCREEN1_BASE+(UNI2_ROW+3)*40+UNI2_COL+0   ; left arm
ADDRESS8 = SCREEN1_BASE+(UNI2_ROW+3)*40+UNI2_COL+2   ; right arm
ADDRESS9 = SCREEN1_BASE+(UNI2_ROW+7)*40+UNI2_COL+1   ; hub

addresses_lo:
.repeat 10,YY
        .byte <.IDENT(.CONCAT("ADDRESS", .STRING(YY)))
.endrepeat
addresses_hi:
.repeat 10,YY
        .byte >.IDENT(.CONCAT("ADDRESS", .STRING(YY)))
.endrepeat

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
        scrcode "nathan    "
        .byte  1,0,0,0,0,0
        scrcode "stefan    "
        .byte  0,0,0,0,0,0

score_counter: .byte 0                  ; score that has been drawn
delay:         .byte $10                ; delay used to print the scores

unicyclists_map:
        .incbin "unicyclists-map.bin"

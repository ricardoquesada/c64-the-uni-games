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
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __SIDMUSIC_LOAD__
.import __MAIN_SPRITES_LOAD__, __GAME_CODE_LOAD__

; from utils.s
.import clear_screen, clear_color, get_key, read_joy2

; from main.s
.import irq_open_borders

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm				; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"			; c64 constants


.segment "HIGH_SCORES_CODE"

	sei

	lda #01				; enable raster irq
	sta $d01a

	ldx #<irq_open_borders		; raster IRQ to open top/bottom borders
	ldy #>irq_open_borders
	stx $fffe
	sty $ffff
	lda #$f9
	sta $d012

	lda $dc0d			; clear interrupts and ACK irq
	lda $dd0d
	asl $d019

	cli

	lda #$01
	jsr clear_color
	jsr init_screen

@main_loop:
	jsr get_key
	bcc @main_loop

	cmp #$47			; space ?
	bne @main_loop
	jmp __MAIN_CODE_LOAD__

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_screen
;------------------------------------------------------------------------------;
; paints the screen with the "main menu" screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen

	ldx #0				; clear the screen
	lda #$20
:	sta $8400+$0000,x
	sta $8400+$0100,x
	sta $8400+$0200,x
	sta $8400+$02e8,x
	inx
	bne :-

	ldx #0
:	lda high_scores_screen,x
	sta $8400,x
	inx
	cpx #40				; draw 1 line
	bne :-

	ldx #<($8400 + 40 * 3)		; init "save" pointer
	ldy #>($8400 + 40 * 3)		; start writing at 3rd line
	stx $f9
	sty $fa


	ldx #00				; x has the high score entry

@loop:
	jsr @delay


	jsr @print_highscore_entry

	clc				; pointer to the next line in the screen
	lda $f9
	adc #40 * 2 + 0			; skip one line
	sta $f9
	bcc :+
	inc $fa
:
	inx
	cpx #10				; repeat 10 times. there are only 10 high scores
	bne @loop

	rts

@delay:
	txa
	pha
	tya
	pha

	ldx #$10
:	ldy #$00
:	dey
	bne :-
	dex
	bne :--

	pla
	tay
	pla
	tax
	rts

@print_highscore_entry:
	txa				; x has the high score entry index

	ldy #$00			; y = screen idx

	pha
	clc
	adc #$01			; positions start with 1, not 0

	cmp #10				; print position
	bne @print_second_digit

	lda #$31			; hack: if number is 10, print '1'. $31 = '1'
	sta ($f9),y			; otherwise, skip to second number
	ora #$40
	iny
	sta ($f9),y			; wide char: print 2nd part of digit
	iny
	lda #00				; second digit is '0'
	jmp :+

@print_second_digit:
	iny
	iny
:
	clc
	adc #$30			; A = high_score entry.
	sta ($f9),y
	iny
	ora #$40			; wide chars
	sta ($f9),y
	iny

	lda #33				; print '.'
	sta ($f9),y
	iny


	lda #10				; print name 
	sta @tmp_counter

	txa				; multiply x by 16, since each entry has 16 bytes
	asl
	asl
	asl
	asl
	tax				; x = high score pointer

:	lda entries,x			; points to entry[i].name
	sta ($f9),y			; pointer to screen
	iny
	ora #$40			; wide chars
	sta ($f9),y
	iny
	inx
	dec @tmp_counter
	bne :-


	lda #6				; print score
	sta @tmp_counter

	iny
	iny
	iny

:	lda entries,x			; points to entry[i].score
	clc
	adc #$30
	sta ($f9),y			; pointer to screen
	iny
	ora #$40			; wide chars
	sta ($f9),y
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
	scrcode "         hHiIgGhH  sScCoOrReEsS         "


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

;--------------------------------------------------------------------------
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; High Scores screen
;
;--------------------------------------------------------------------------

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __SIDMUSIC_LOAD__, __MAIN_SPRITES_LOAD__, __GAME_CODE_LOAD__

; from utils.s
.import clear_screen, clear_color, get_key, read_joy2

;--------------------------------------------------------------------------
; Macros
;--------------------------------------------------------------------------
.macpack cbm			; adds support for scrcode

;--------------------------------------------------------------------------
; Constants
;--------------------------------------------------------------------------
.include "c64.inc"		; c64 constants


.segment "HIGH_SCORES_CODE"

	sei

	; enable raster irq
	lda #01
	sta $d01a

	; no IRQ
	ldx #<no_irq
	ldy #>no_irq
	stx $fffe
	sty $ffff

	; clear interrupts and ACK irq
	lda $dc0d
	lda $dd0d
	asl $d019

	cli

	lda #$01
	jsr clear_color
	jsr init_screen

@main_loop:
	jsr get_key
	bcc @main_loop

	cmp #$47		; space
	bne @main_loop
	jmp __MAIN_CODE_LOAD__


no_irq:
	pha			; saves A, X, Y
	txa
	pha
	tya
	pha

	asl $d019

	pla			; restores A, X, Y
	tay
	pla
	tax
	pla
	rti			; restores previous PC, status

;--------------------------------------------------------------------------
; init_screen
;--------------------------------------------------------------------------
; paints the screen with the "main menu" screen
;--------------------------------------------------------------------------
.proc init_screen
	ldx #<high_scores_screen
	ldy #>high_scores_screen
	stx @loadaddr
	sty @loadaddr+1

	ldx #<$8400
	ldy #>$8400
	stx @saveaddr
	sty @saveaddr+1


	ldy #25			; repeat 25 times

@loop:
	jsr @delay
	ldx #$00

@shortloop:
@loadaddr = *+1
	lda high_scores_screen+$0000,x
@saveaddr = *+1
	sta $8400,x
	inx
	cpx #40
	bne @shortloop
	clc
	lda @loadaddr
	adc #40
	sta @loadaddr
	bcc :+
	inc @loadaddr+1
:
	clc
	lda @saveaddr
	adc #40
	sta @saveaddr
	bcc :+
	inc @saveaddr+1
:
	dey
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
.endproc


high_scores_screen:
		;0123456789|123456789|123456789|123456789|
	scrcode "         hHiIgGhH  sScCoOrReEsS         "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode " 11 -  tToOmM                           "
	scrcode "                                        "
	scrcode " 22 -  cChHrRiIsS                       "
	scrcode "                                        "
	scrcode " 44 -  dDrRaAgGoOnN                     "
	scrcode "                                        "
	scrcode " 33 -  jJoOsShH                         "
	scrcode "                                        "
	scrcode " 44 -  aAsShHlLeEyY                     "
	scrcode "                                        "
	scrcode " 55 -  kKeEvViInN                       "
	scrcode "                                        "
	scrcode " 77 -  mMiIcChHeElLeE                   "
	scrcode "                                        "
	scrcode " 88 -  cCoOrRbBiInN                     "
	scrcode "                                        "
	scrcode " 99 -  bBeEaAuU                         "
	scrcode "                                        "
	scrcode " 00 -  rRiIcCaArRdDoO                   "
	scrcode "                                        "
	scrcode "                                        "


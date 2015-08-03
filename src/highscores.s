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
	ldx #$00
@loop:
	lda high_scores_screen+$0000,x
	sta $8400,x
	lda high_scores_screen+$0100,x
	sta $8400+$0100,x
	lda high_scores_screen+$0200,x
	sta $8400+$0200,x
	lda high_scores_screen+$02e8,x
	sta $8400+$02e8,x
	inx
	bne @loop
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


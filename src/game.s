;--------------------------------------------------------------------------
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; game scene
;
;--------------------------------------------------------------------------

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __SIDMUSIC_LOAD__, __MAIN_SPRITES_LOAD__

; from main.s
.import selected_rider

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

.segment "GAME_CODE"

	sei

	lda #00
	jsr clear_color
	jsr init_screen
	jsr init_sprites


	cli

	jmp *


.proc init_screen

	; screen is at $8400
	ldx #$00
@loop:
	lda #$20
	sta $8400,x
	sta $8400+$0100,x
	sta $8400+$0200,x
	sta $8400+$02e8,x
	inx
	bne @loop
	rts
.endproc

.proc init_sprites
	; in case rider 1 is selected (instead of 0)
	; sprite pointer and sprite color need to be changed
	lda selected_rider
	cmp #$01
	bne :+

	lda #$02		; sprite pointer 2
	sta $87f8

	lda __MAIN_SPRITES_LOAD__ + 64 * 2 + 63 ; sprite color
	and #$0f
	sta VIC_SPR0_COLOR

:
	lda #%00000001
	sta VIC_SPR_ENA
	lda #40
	sta VIC_SPR0_X
	lda #80
	sta VIC_SPR0_Y
	rts
.endproc


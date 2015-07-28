;--------------------------------------------------------------------------
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-uni-race
;
; game file
;--------------------------------------------------------------------------

; exported by the linker
.import ___GAME_CODE_LOAD__, __MAIN_CODE_LOAD__, __SIDMUSIC_LOAD__

; from utils.s
.import clear_screen, clear_color, get_key

;--------------------------------------------------------------------------
; Macros
;--------------------------------------------------------------------------
.macpack cbm			; adds support for scrcode
.macpack mymacros		; my own macros


.segment "GAME_CODE"
	lda #$01
	jsr clear_color

	jsr init_screen

	; no scroll,single-color,40-cols
	; default: %00001000
	lda #%00001000
	sta $d016

	; Vic bank 2: $8000-$BFFF
	lda $dd00
	and #$fc
	ora #1
	sta $dd00
	lda #$20

	; charset at $8800 (equal to $0800 for bank 0)
	; default is:
	;    %00010101
	lda #%00010010
	sta $d018

	;default is:
	;    %00011011
	; disable bitmap mode
	; 25 rows
	; disable extended color
	; vertical scroll: default position
	lda #%00011011
	sta $d011

	lda #$00
	sta $d020
	sta $d021

	jmp *

;--------------------------------------------------------------------------
; init_screen
;--------------------------------------------------------------------------
.proc init_screen
	ldx #$00
@loop:
	lda screen,x
	sta $8400,x		; $8400: vic bank 2
	lda screen+$0100,x
	sta $8400+$0100,x
	lda screen+$0200,x
	sta $8400+$0200,x
	lda screen+$02e8,x
	sta $8400+$02e8,x
	inx
	bne @loop
	rts
.endproc

screen:
		;0123456789|123456789|123456789|123456789|
	scrcode "                                        "
	scrcode "         cChHoOoOsSeE rRiIdDeErR        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode " aA - kKrRiIsS cChHoOlLmM               "
	scrcode " bB - mMaAxX cChHuUlLzZeE               "
	scrcode " cC - cChHrRiIsS lLaAbBoOnNtTeE         "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "

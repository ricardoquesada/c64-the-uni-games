;--------------------------------------------------------------------------
; game
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
	lda #$20
	jsr clear_screen

	jmp *


@screen:
		;0123456789|123456789|123456789|123456789|
	scrcode "                                        "

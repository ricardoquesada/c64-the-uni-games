;--------------------------------------------------------------------------
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; game scene
;
;--------------------------------------------------------------------------

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __SIDMUSIC_LOAD__, __MAIN_SPRITES_LOAD__

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
	cli

	jmp *

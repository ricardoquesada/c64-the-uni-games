;--------------------------------------------------------------------------
; main screen
;--------------------------------------------------------------------------

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__

; from utils.s
.import clear_screen, clear_color

;--------------------------------------------------------------------------
; Macros
;--------------------------------------------------------------------------
.macpack cbm			; adds support for scrcode

.segment "CODE"
	jmp __MAIN_CODE_LOAD__
;	jmp __ABOUT_CODE_LOAD__

.segment "MAIN_CODE"


	lda #$20
	jsr clear_screen
	lda #$01
	jsr clear_color

	lda #$00
	sta $d020
	sta $d021

        ; Vic bank 2: $8000-$BFFF
	lda $dd00
        and #$fc
	ora #1
        sta $dd00

        ; charset at $8800 (equal to $0800 for bank 0)
	; default is:
	;    %00010101
	lda #%00010010
	sta $d018
	rts


screen:

.segment "MAIN_SCREEN"
		;0123456789|123456789|123456789|123456789|
	scrcode "                                        "
	scrcode "                                        "
	scrcode " * * * * * * * * * * * * * * * * * * * *"
	scrcode "                                        "
	scrcode " *                                     *"
	scrcode "                                        "
	scrcode " *      tThHeE  mMuUnNiI  rRaAcCeE     *"
	scrcode "                                        "
	scrcode " *                                     *"
	scrcode "                                        "
	scrcode " * * * * * * * * * * * * * * * * * * * *"
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
        scrcode "          fF1",177," - sStTaArRtT             "
	scrcode "                                        "
        scrcode "          fF7",183," - aAbBoOuUtT             "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
        ; splitting the macro 3 since it has too many parameters
        scrcode "      ",64,96,"2",178,"0"
        scrcode          176,"1",177,"5",181
        scrcode                 " - rRqQ pPrRoOgGsS      "

.segment "MAIN_CHARSET"
        .incbin "res/shared_font.bin"

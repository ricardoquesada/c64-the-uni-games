;--------------------------------------------------------------------------
; main screen
;--------------------------------------------------------------------------

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __GAME_CODE_LOAD__, __SIDMUSIC_LOAD__

; from utils.s
.import clear_screen, clear_color, get_key

;--------------------------------------------------------------------------
; Macros
;--------------------------------------------------------------------------
.macpack cbm			; adds support for scrcode

.segment "CODE"
	jmp __MAIN_CODE_LOAD__
;	jmp __ABOUT_CODE_LOAD__


.segment "MAIN_CODE"

	sei

	jsr clear_screen
	lda #$01
	jsr clear_color

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

	; color wash 40 times before showing the screen
	; so that the colors are in the correct position
	; FIXME: 40 times faster is to just colorify the screen
	; with the correct colors instead of iterating 40
	; times over color_wash
	lda #40
	sta $ff
:	jsr @color_wash
	dec $ff
	bne :-

	lda #$00
	sta $d020
	sta $d021


	; turn off BASIC + Kernal. More RAM
	lda #$35
	sta $01

	; turn off cia interrups
	lda #$7f
	sta $dc0d
	sta $dd0d

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

	; init music
	jsr __SIDMUSIC_LOAD__

	cli


@main_loop:
	jsr @color_wash

	; delay loop to make the color
	; washer slower
	ldy #$0a
:	ldx #$00
:	dex
	bne :-
	dey	
	bne :--


	jsr get_key
	bcc @main_loop

	sta $0400
	cmp #$40                ; F1
	beq @jump_start
	cmp #$30                ; F7
	beq @jump_about
	jmp @main_loop


@jump_start:
	jmp __GAME_CODE_LOAD__
@jump_about:
	jmp __ABOUT_CODE_LOAD__


@color_wash:
	; scroll the colors
	ldx #0
@loop:
	; 9 lines to scroll, starting from line 1
	.repeat 9,i
		lda $d800+40*(i+1)+1,x
		sta $d800+40*(i+1),x
	.endrepeat
	inx
	cpx #40			; 40 columns
	bne @loop

	; set the new colors at row 39
	ldy color_idx

	.repeat 9,i
		lda colors,y
		sta $d800+40*(i+1)+39
		iny
		iny
		tya
		and #$3f	; 64 colors
		tay
	.endrepeat

	; set the new index color for the next iteration
	ldy color_idx
	iny
	tya
	and #$3f		; 64 colors
	sta color_idx
	rts

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

color_idx: .byte $00
	.byte $00
colors:
	; Color washer palette based on Dustlayer intro
	; https://github.com/actraiser/dust-tutorial-c64-first-intro/blob/master/code/data_colorwash.asm
	.byte $09,$09,$09,$09,$02,$02,$02,$02
	.byte $08,$08,$08,$08,$0a,$0a,$0a,$0a
	.byte $0f,$0f,$0f,$0f,$07,$07,$07,$07
	.byte $01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01
	.byte $07,$07,$07,$07,$0f,$0f,$0f,$0f
	.byte $0a,$0a,$0a,$0a,$08,$08,$08,$08
	.byte $02,$02,$02,$02,$09,$09,$09,$09
	.byte $00

screen:

.segment "MAIN_SCREEN"
		;0123456789|123456789|123456789|123456789|
	scrcode "                                        "
	.repeat 20
	.byte $2a,$6a
	.endrepeat
	scrcode "*",170,"                                    *",170
	scrcode "*",170,"                                    *",170
	scrcode "*",170,"                                    *",170
	scrcode "*",170,"     tThHeE  mMuUnNiI  rRaAcCeE     *",170
	scrcode "*",170,"                                    *",170
	scrcode "*",170,"                                    *",170
	scrcode "*",170,"                                    *",170
	.repeat 20
	.byte $2a,$6a
	.endrepeat
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "      fF1",177," -      sStTaArRtT            "
	scrcode "                                        "
	scrcode "      fF3",179," - hHiIgGhH sScCoOrReEsS      "
	scrcode "                                        "
	scrcode "      fF7",183," -      aAbBoOuUtT            "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	; splitting the macro in 3 since it has too many parameters
	scrcode "     ",64,96,"2",178,"0"
	scrcode          176,"1",177,"5",181
	scrcode                 "  rReEtTrRoO  mMoOeE     "
;	scrcode                 " rRqQ pPrRoOgGsS       "


.segment "MAIN_CHARSET"
;	.incbin "res/shared_font.bin"
	.incbin "res/boulderdash-font.bin"

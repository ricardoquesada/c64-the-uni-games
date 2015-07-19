;--------------------------------------------------------------------------
; main screen
;--------------------------------------------------------------------------

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __SIDMUSIC_LOAD__

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

	; init music
	jsr __SIDMUSIC_LOAD__

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

	;default is:
	;    %00011011
	; disable bitmap mode
	; 25 rows
	; disable extended color
	; vertical scroll: default position
	lda #%00011011
	sta $d011

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

	cli

@main_loop:
	jsr @color_wash

	; delay loop
	ldy #$f0
:	ldx #$00
:	inx
	bne :-
	iny
	bne :--


	jsr get_key
	bcc @main_loop

	cmp #$40                ; F1
	beq @jump_start
	cmp #$30                ; F7
	beq @jump_about
	jmp @main_loop


@jump_start:
	jmp $caca
@jump_about:
	jmp __ABOUT_CODE_LOAD__


@color_wash:
	ldx #0
@loop:
	lda $d800+40*2+1,x
	sta $d800+40*2,x
	lda $d800+40*3+1,x
	sta $d800+40*3,x
	lda $d800+40*4+1,x
	sta $d800+40*4,x
	lda $d800+40*5+1,x
	sta $d800+40*5,x
	lda $d800+40*6+1,x
	sta $d800+40*6,x
	lda $d800+40*7+1,x
	sta $d800+40*7,x
	lda $d800+40*8+1,x
	sta $d800+40*8,x
	lda $d800+40*9+1,x
	sta $d800+40*9,x
	lda $d800+40*10+1,x
	sta $d800+40*10,x
	lda $d800+40*11+1,x
	sta $d800+40*11,x
	inx
	cpx #40
	bne @loop

	; new color
	ldy color_idx
	lda colors,y
	sta $d800+40*3+39
	lda colors+1,y
	sta $d800+40*4+39
	lda colors+2,y
	sta $d800+40*5+39
	lda colors+3,y
	sta $d800+40*6+39
	lda colors+4,y
	sta $d800+40*7+39
	lda colors+5,y
	sta $d800+40*8+39
	lda colors+6,y
	sta $d800+40*9+39
	lda colors+7,y
	sta $d800+40*10+39
	lda colors+8,y
	sta $d800+40*11+39

	; next color
	inc color_idx
	lda color_idx
	cmp #40
	bne :+
	lda #$00
	sta color_idx
:
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
colors:
	; Color washer palette taken from: Dustlayer intro
	; https://github.com/actraiser/dust-tutorial-c64-first-intro/blob/master/code/data_colorwash.asm
	.byte $09,$09,$02,$02,$08
	.byte $08,$0a,$0a,$0f,$0f
	.byte $07,$07,$01,$01,$01
	.byte $01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01
	.byte $01,$01,$01,$07,$07
	.byte $0f,$0f,$0a,$0a,$08
	.byte $08,$02,$02,$09,$09

	.repeat 10
		.byte $00
	.endrepeat

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
	; splitting the macro in 3 since it has too many parameters
	scrcode "      ",64,96,"2",178,"0"
	scrcode          176,"1",177,"5",181
	scrcode                 " - rRqQ pPrRoOgGsS      "


.segment "MAIN_CHARSET"
	.incbin "res/shared_font.bin"

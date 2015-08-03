;--------------------------------------------------------------------------
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; main screen
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
SPRITE_ANIMATION_SPEED = 8


.segment "CODE"
	jmp __MAIN_CODE_LOAD__
;	jmp __ABOUT_CODE_LOAD__


.segment "MAIN_CODE"

	sei

	lda #$01
	jsr clear_color
	jsr init_main_menu_screen

	; no scroll,single-color,40-cols
	; default: %00001000
	lda #%00001000
	sta $d016

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

	jsr init_color_wash

	; background & border color
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

	; turn off volume
	lda #$00
	sta SID_Amp

	; default menu mode: main menu
	lda #$00
	sta menu_mode
	sta selected_rider
	lda #SPRITE_ANIMATION_SPEED
	sta animation_delay

	cli


@main_loop:
	jsr color_wash

	; delay loop to make the color
	; washer slower
	ldy #$0a
:	ldx #$00
:	
	dex
	bne :-
	dey	
	bne :--

	lda menu_mode
	beq @main_menu_mode
	
	; "choose rider" mode
	jsr animate_rider
	jsr read_joy2
	eor #$ff
	and #%00011100 ;	; only care about left,right,fire
	beq @main_loop

	cmp #%00010000		; fire ?
	bne :+
	jmp __GAME_CODE_LOAD__

:
	; joystick moved to the left or right.
	; choose a new rider
	jsr choose_new_rider
	jmp @main_loop

@main_menu_mode:
	jsr get_key
	bcc @main_loop

	cmp #$40                ; F1
	beq @set_choose_rider_mode
	cmp #$30                ; F7
	beq @jump_about
	jmp @main_loop


@set_choose_rider_mode:
	jsr init_choose_rider_screen
	jsr init_choose_rider_sprites
	lda #$01
	sta menu_mode
	jmp @main_loop

@jump_about:
	jmp __ABOUT_CODE_LOAD__


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
; init_main_menu_screen
;--------------------------------------------------------------------------
.proc init_main_menu_screen
	ldx #$00
@loop:
	lda main_menu_screen,x
	sta $8400,x
	lda main_menu_screen+$0100,x
	sta $8400+$0100,x
	lda main_menu_screen+$0200,x
	sta $8400+$0200,x
	lda main_menu_screen+$02e8,x
	sta $8400+$02e8,x
	inx
	bne @loop
	rts
.endproc

;--------------------------------------------------------------------------
; init_choose_rider_screen(void)
;--------------------------------------------------------------------------
; displays the "choose rider" message
;--------------------------------------------------------------------------
.proc init_choose_rider_screen
	ldx #39
@loop:
	; overwrite starting from line 10. Lines 0-9 are still used: 10*40 = 400 = $0190
	; total lines to write: 10
	.repeat 10,i
		lda choose_rider_screen + (40*i),x
		sta $8590 + (40*i),x		; start screen: $8400 (vic bank 2). offset = $0190
	.endrepeat

	; small delay to create a "sweeping" effect
	txa
	pha
	ldx #$05		; start of delay
:	ldy #$00
:	iny
	bne :-
	dex
	bne :--			; end of delay
	pla
	tax

	dex
	bpl @loop
	rts
.endproc

;--------------------------------------------------------------------------
; init_choose_rider_sprites(void)
;--------------------------------------------------------------------------
; displays the sprite riders
;--------------------------------------------------------------------------
.proc init_choose_rider_sprites

	lda #%00000111		; enable 3 sprites
	sta VIC_SPR_ENA

	; sprites 0,1: multicolor
	; sprites 2: hi res
	lda #%00000011
	sta VIC_SPR_MCOLOR

	; sprite 2 expanded in X and Y
	lda #%00000100
	sta VIC_SPR_EXP_X	; expand X
	sta VIC_SPR_EXP_Y	; expand Y

	; multicolor values
	lda #$0a
	sta VIC_SPR_MCOLOR0
	lda #$0b
	sta VIC_SPR_MCOLOR1

	; 9th bit
	lda #%00000010
	sta $d010
	
	; sprite #0
	lda #$48		; position x
	sta VIC_SPR0_X
	lda #$a4		; position y
	sta VIC_SPR0_Y
	lda __MAIN_SPRITES_LOAD__ + 64 * 0 + 63; sprite color
	and #$0f
	sta VIC_SPR0_COLOR
	; sprites are located at $8000... First sprite pointer is 0
	lda #$00		; sprite pointer 0
	sta $87f8

	; sprite #1
	lda #$0b		; position x
	sta VIC_SPR1_X
	lda #$a4		; position y
	sta VIC_SPR1_Y
	lda __MAIN_SPRITES_LOAD__ + 64 * 8 + 63 ; sprite color
	and #$0f
	sta VIC_SPR1_COLOR
	lda #$08		; sprite pointer 8
	sta $87f9

	; sprite #2
	lda #$43		; position x
	sta VIC_SPR2_X
	lda #$a0		; position y
	sta VIC_SPR2_Y
	lda __MAIN_SPRITES_LOAD__ + 64 * 7 + 63 ; sprite color
	and #$0f
	sta VIC_SPR2_COLOR
	lda #$07		; sprite pointer 7
	sta $87fa


	rts
.endproc



;--------------------------------------------------------------------------
; init_color_wash(void)
;--------------------------------------------------------------------------
; sets the screen color already 40 "washed" colors, so that the scrolls
; starts at the right position.
; This code is similar to call `jsr color_wash` for 40 times faster
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
; init_color_wash(void)
;--------------------------------------------------------------------------
; sets the screen color already 40 "washed" colors, so that the scrolls
; starts at the right position.
; This code is similar to call `jsr color_wash` for 40 times faster
;--------------------------------------------------------------------------
.proc init_color_wash
	; set color screen
	ldx #00
	ldy #00
@loop:
	; 9 lines to scroll, starting from line 1
	.repeat 9,i
		lda colors+(i*2),y
		sta $d800+40*(i+1),x
	.endrepeat
	iny
	inx
	cpx #40
	bne @loop

	stx color_idx

	rts
.endproc

;--------------------------------------------------------------------------
; color_wash(void)
;--------------------------------------------------------------------------
; Scrolls the screen colors creating a kind of "rainbow" effect
;--------------------------------------------------------------------------
.proc color_wash
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

	; sprite #2 color
	; change color at this moment, in order to avoid
	; doing "ldy color_idx" again
	lda colors,y
	sta VIC_SPR2_COLOR

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
.endproc

;--------------------------------------------------------------------------
; void animate_rider(void)
;--------------------------------------------------------------------------
; animates the selected rider
;--------------------------------------------------------------------------
.proc animate_rider
	dec animation_delay
	beq @animate
	rts

@animate:
	lda #SPRITE_ANIMATION_SPEED
	sta animation_delay

	ldx selected_rider
	lda $87f8,x
	eor #%00000001		; new spriter pointer
	sta $87f8,x
	rts
.endproc

;--------------------------------------------------------------------------
; void choose_new_rider(joystick)
;--------------------------------------------------------------------------
; chooses a new rider
;--------------------------------------------------------------------------
.proc choose_new_rider
	cmp #%00001000
	beq @right

@left:
	ldx #$00
	beq :+

@right:
	ldx #$01
:
	lda @position_x,x
	sta VIC_SPR2_X		; set position X
	lda @position_9,x
	sta $d010		; set 9th for position X
	stx selected_rider
	rts

	; positions for the "select" sprite
	; based on which rider is selected
@position_x: .byte $43, $06
@position_9: .byte %00000010, %00000110
.endproc
	


	; modes: $00: main menu, $01: choose rider menu
menu_mode: .byte $00
	; $00: cris holm, $01: krish labonte
.export selected_rider
selected_rider: .byte $00
animation_delay: .byte SPRITE_ANIMATION_SPEED

color_idx: .byte $00
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

main_menu_screen:
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

choose_rider_screen:
		;0123456789|123456789|123456789|123456789|
	scrcode "                                        "
	scrcode "                                        "
	scrcode "        cChHoOoOsSeE  rRiIdDeErR        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "                                        "
	scrcode "   cChHrRiIsS               kKrRiIsS    "
	scrcode "    hHoOlLmM             lLaAbBoOnNtTeE "


.segment "MAIN_CHARSET"
;	.incbin "res/shared_font.bin"
	.incbin "res/boulderdash-font.bin"

.segment "MAIN_SPRITES"
	.incbin "res/sprites.prg",2


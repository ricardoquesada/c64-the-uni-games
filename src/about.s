;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; About file
;
; Zero Page global registers:
;   $f9/$fa -> charset:  ** MUST NOT be modifed by any other functions **
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;


; exported by the linker
.import __SIDMUSIC_LOAD__, __ABOUT_CODE_LOAD__, __ABOUT_GFX_LOAD__
.import __MAIN_CODE_LOAD__, __MAIN_CHARSET_LOAD__

; from utils.s
.import clear_screen, clear_color, get_key, sync_irq_timer

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

DEBUG = 0				; bitwise: 1=raster-sync code. 2=50hz code (music)

RASTER_START = 50			; raster scan starts at line 50

SCROLL_AT_LINE = 18			; starting row for the scroller
ROWS_PER_LETTER = 7			; how many rows does one big-char takes

SCREEN_TOP = $0400 + SCROLL_AT_LINE * 40


MUSIC_INIT = __SIDMUSIC_LOAD__
MUSIC_PLAY = __SIDMUSIC_LOAD__ + 3

SCROLL_SPEED = 6			; SPEED must be between 0 and 7. 0=Stop, 7=Max speed

SCROLL_BKG_COLOR = 0			; Black

COLORWASH_DELAY = 1			; SPEED of colorwasher: 1=Max speed

ANIM_SPEED = 1

KOALA_BITMAP_DATA = __ABOUT_GFX_LOAD__
KOALA_CHARMEM_DATA = KOALA_BITMAP_DATA + $1f40
KOALA_COLORMEM_DATA = KOALA_BITMAP_DATA + $2328
KOALA_BACKGROUND_DATA = KOALA_BITMAP_DATA + $2710

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm				; adds support for scrcode
.macpack mymacros			; my own macros

.segment "ABOUT_CODE"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; _main
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
	jsr init

@mainloop:
	lda sync50hz
	beq :+
	jsr @do_sync50hz
:
	lda sync
	beq :+
	jsr @do_sync
:
	jsr get_key			; key pressed ?
	bcc @mainloop
	cmp #$47			; space
	bne @mainloop

	jmp __MAIN_CODE_LOAD__

@do_sync:
	lda #$00
	sta sync
.if (DEBUG & 1)
	dec $d020
.endif
	jsr scroll
	jsr anim_char
	jsr anim_colorwash
.if (DEBUG & 1)
	inc $d020
.endif
	rts

@do_sync50hz:
:
.if (DEBUG & 2)
	inc $d020
.endif
	jsr MUSIC_PLAY
.if (DEBUG & 2)
	dec $d020
.endif
	dec sync50hz			; I don't think it is possible have more than one
	bne :-				; timer IRQ, but just in case

	rts


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ handler
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
irq:
	pha				; saves A, X, Y
	txa
	pha
	tya
	pha

	sei				; disables interrupts
	asl $d019			; clears raster interrupt
	bcs @raster

	lda $dc0d			; clears timer A interrupt
	cli				; enables interrupts

	inc sync50hz

	pla				; restores A, X, Y
	tay
	pla
	tax
	pla
	rti				; restores previous PC, status

@raster:
	STABILIZE_RASTER

	.repeat 23
		nop
	.endrepeat

	lda #%00011011			; set char mode
	sta $d011

	ldx #SCROLL_BKG_COLOR		; set border and background colors
	stx $d020
	stx $d021

	lda smooth_scroll_x		; set the horizontal scroll
	sta $d016

	ldx #$00			; raster bars
	ldy #(ROWS_PER_LETTER *8)	; paint the raster bars
:       lda $d012
:       cmp $d012
	beq :-				; wait until next raster line
	lda raster_colors+12,x
	sta $d021
	inx
	dey
	bne :--

	lda #$00
	sta $d020			; set border color
	lda KOALA_BACKGROUND_DATA
	sta $d021			; set background color

	lda #%00011000			; no scroll, multi-color
	sta $d016

	lda #%00111011			; set hires bitmap mode. needed for the logo
	sta $d011

	inc sync


	lda #<irq			; we have to re-schedule irq from irq basically because
	sta $fffe			; we are using a double IRQ
	lda #>irq
	sta $ffff

	lda #RASTER_START+SCROLL_AT_LINE*8-2
	sta $d012

	asl $d019

	pla				; restores A, X, Y
	tay
	pla
	tax
	pla
	rti				; restores previous PC, status

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; scroll(void)
;------------------------------------------------------------------------------;
; main scroll function
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc scroll

	sec				; speed control
	lda smooth_scroll_x
	sbc #SCROLL_SPEED
	and #07
	sta smooth_scroll_x
	bcc :+
	rts
:

	jsr scroll_screen

	lda chars_scrolled
	cmp #%10000000
	bne :+

	jsr setup_charset		; A and current_char will contain the char to print
					; $f9/$fa points to the charset definition of the char
:
	ldx #<(SCREEN_TOP+7*40+39)	; basic setup
	ldy #>(SCREEN_TOP+7*40+39)
	stx @screen_address
	sty @screen_address+1

	ldy #.min(ROWS_PER_LETTER,7)	; should not be bigger than 7 (8 rows)

@loop:
	lda ($f9),y
	and chars_scrolled
	beq @empty_char

;	 lda current_char
	lda #$fe			; A = char to display. $fe = full char
	bne :+

@empty_char:
	lda #$ff			; A = char to display. $ff = empty char

:
@screen_address = *+1
	sta $caca			; self-modifying value
					; this value will be overwritten with the address of the screen

	sec				; next line for top scroller
	lda @screen_address
	sbc #40
	sta @screen_address
	bcs :+
	dec @screen_address+1
:

	dey				; next charset definition
	bpl @loop

	lsr chars_scrolled
	bcc @endscroll

	lda #128
	sta chars_scrolled

	clc
	lda scroller_text_ptr_low
	adc #1
	sta scroller_text_ptr_low
	bcc @endscroll
	inc scroller_text_ptr_hi

@endscroll:
	rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; scroll_screen(void)
;------------------------------------------------------------------------------;
; args: -
; modifies: A, X, Status
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
scroll_screen:
	ldx #0				; move the chars to the left and right

	ldy #38				; doing a cpy #$ff

@loop:
	.repeat ROWS_PER_LETTER,i
		lda SCREEN_TOP+40*i+1,x
		sta SCREEN_TOP+40*i+0,x
	.endrepeat

	inx
	dey
	bpl @loop
	rts

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; setup_charset(void)
;------------------------------------------------------------------------------;
; Args: -
; Modifies A, X, Status
; returns A: the character to print
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc setup_charset

	clc				; put next char in column 40
	lda #<scroller_text		; supports a scroller with more than 255 chars
	adc scroller_text_ptr_low
	sta @address
	lda #>scroller_text
	adc scroller_text_ptr_hi
	sta @address+1

@address = *+1
	lda scroller_text		; self-modifying value
	cmp #$ff
	bne :+

	lda #%10000000			; reached $ff. Then start from the beginning
	sta chars_scrolled
	lda #0
	sta scroller_text_ptr_low
	sta scroller_text_ptr_hi
	lda scroller_text
:
	sta current_char

	tax

	asl				; address = CHARSET + 8 * index
	asl				; multiply by 8 (LSB)
	asl
	clc
	adc #<(__MAIN_CHARSET_LOAD__ + 128*8)	; charset starting at pos 128
	sta $f9

	txa
	lsr				; multiply by 8 (MSB)
	lsr				; 256 / 8 = 32
	lsr				; 32 = %00100000
	lsr
	lsr

	clc
	adc #>(__MAIN_CHARSET_LOAD__ + 128*8)	; charset starting at pos 128
	sta $fa

	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; anim_char(void)
;------------------------------------------------------------------------------;
; Args: -
; Modifies A, X, Status
; returns A: the character to print
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
ANIM_TOTAL_FRAMES = 4
.proc anim_char

	sec
	lda anim_speed
	sbc #ANIM_SPEED
	and #07
	sta anim_speed
	bcc @animation

	rts

@animation:
	lda anim_char_idx
	asl				; multiply by 8 (next char)
	asl
	asl
	tay

	ldx #7				; 8 rows
@loop:
	lda char_frames,y
	sta $3800 + $fe * 8,x

	iny
	dex
	bpl @loop

	dec anim_char_idx
	bpl :+

	; reset anim_char_idx
	lda #ANIM_TOTAL_FRAMES-1
	sta anim_char_idx
:
	rts

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; anim_colorwash(void)
;------------------------------------------------------------------------------;
; Args: -
; A Color washer routine
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc anim_colorwash

	dec colorwash_delay
	beq :+
	rts

:
	lda #COLORWASH_DELAY
	sta colorwash_delay

	lda raster_colors_top		; washer top
	sta save_color_top

	ldx #0
:	lda raster_colors_top+1,x
	sta raster_colors_top,x
	inx
	cpx #TOTAL_RASTER_LINES
	bne :-

save_color_top = *+1
	lda #00				; self modifying code
	sta raster_colors_top+TOTAL_RASTER_LINES-1

	lda raster_colors_bottom+TOTAL_RASTER_LINES-1 ; washer bottom
	sta save_color_bottom

	dex				; x == TOTAL_RASTER_LINES... 
					; and I need it to be TOTAL_RASTER_LINES-1

:	lda raster_colors_bottom,x
	sta raster_colors_bottom+1,x
	dex
	bpl :-

save_color_bottom = *+1
	lda #00				; self modifying code
	sta raster_colors_bottom
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init(void)
;------------------------------------------------------------------------------;
; Args: -
; Clear screen, interrupts, charset and others
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init
	lda #$20			; must be BEFORE any screen-related function
	jsr clear_screen
	lda #$00
	jsr clear_color

	jsr init_koala_colors		; must be BEFORE init_charset / init_scroll_colors

	jsr init_charset		; must be AFTER koala colors

	jsr init_scroll_colors		; must be AFTER koala colors

	jsr init_scroll_vars		; default values for scroll variables

	lda #$00			; no sprites please
	sta $d015

	lda #0				; init music
	jsr MUSIC_INIT

	lda #0				; colors
	sta $d020
	sta $d021

	lda #%00011111			; charset at $3800
	sta $d018

	sei				; no interrups
	jsr sync_irq_timer

	lda #$7f			; turn off cia interrups
	sta $dc0d
	sta $dd0d

	lda #01				; enable raster irq
	sta $d01a

	lda #%00011011			; disable bitmap mode, 25 rows, disable extended color
	sta $d011			; and vertical scroll in default position

	lda $dd00			; Vic bank 0: $0000-$3FFF
	and #$fc
	ora #3
	sta $dd00

	lda #$01
	sta $dc0e			; start timer interrupt A
	lda #$81
	sta $dc0d			; enable timer A interrupts

	lda #<irq			; IRQ handler
	sta $fffe			; both for raster interrupts
	lda #>irq			; and timer interrupts
	sta $ffff

	lda #RASTER_START+SCROLL_AT_LINE*8-2 ; raster interrupt
	sta $d012

	lda $dc0d			; clear interrupts and ACK irq
	lda $dd0d
	asl $d019

	cli				; enable interrups again

	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_koala_colors(void)
;--------------------------------------------------------------------------
; Args: -
; puts the koala colors in the correct address
; Assumes that bimap data was loaded in the correct position
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_koala_colors

	; Koala format
	; bitmap:           $0000 - $1f3f = $1f40 ( 8000) bytes
	; color %01 - %10:  $1f40 - $2327 = $03e8 ( 1000) bytes
	; color %11:        $2328 - $270f = $03e8 ( 1000) bytes
	; color %00:        $2710         =     1 (    1) byte
	; total:                    $2710 (10001) bytes

	ldx #$00
@loop:
	lda KOALA_CHARMEM_DATA,x	; $0400: colors %01, %10
	sta $0400,x
	lda KOALA_CHARMEM_DATA+$0100,x
	sta $0400+$0100,x
	lda KOALA_CHARMEM_DATA+$0200,x
	sta $0400+$0200,x
	lda KOALA_CHARMEM_DATA+$02e8,x
	sta $0400+$02e8,x

	lda KOALA_COLORMEM_DATA,x	; $d800: color %11
	sta $d800,x
	lda KOALA_COLORMEM_DATA+$0100,x
	sta $d800+$100,x
	lda KOALA_COLORMEM_DATA+$0200,x
	sta $d800+$200,x
	lda KOALA_COLORMEM_DATA+$02e8,x
	sta $d800+$02e8,x

	inx
	bne @loop
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_scroll_colors(void)
;------------------------------------------------------------------------------;
; Args: -
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_scroll_colors
	ldx #0				; foreground RAM color for scroll lines
					; 9 lines: 40 * 9 = 360. 256 + 104
@loop:
	lda #SCROLL_BKG_COLOR		; clear color
	sta $d800 + SCROLL_AT_LINE * 40,x
	sta $d800 + SCROLL_AT_LINE * 40 + (ROWS_PER_LETTER*40-256),x

	lda #$ff			; $ff = clear char
	sta $0400 + SCROLL_AT_LINE * 40,x
	sta $0400 + SCROLL_AT_LINE * 40 + (ROWS_PER_LETTER*40-256),x

	inx
	bne @loop
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_scroll_vars(void)
;------------------------------------------------------------------------------;
; Args: -
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_scroll_vars
	lda #$07
	sta smooth_scroll_x
	lda #$80
	sta chars_scrolled
	lda #$00
	sta current_char
	lda #$07
	sta anim_speed
	lda #ANIM_TOTAL_FRAMES-1
	sta anim_char_idx
	lda #$00
	sta scroller_text_ptr_low
	sta scroller_text_ptr_hi
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_charset(void)
;------------------------------------------------------------------------------;
; Args: -
; copies 3 custom chars to the correct address
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_charset
	ldx #$07
@loop:
	lda empty_char,x
	sta $3800 + $ff*8,x
	eor #$ff
	sta $3800 + $fe*8,x
	dex
	bpl @loop
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; IMPORTANT: raster_colors must be at the beginning of the page in order to avoid extra cycles.
.segment "ABOUT_DATA"
raster_colors:
raster_colors_top:
	; Color washer palette taken from: Dustlayer intro
	; https://github.com/actraiser/dust-tutorial-c64-first-intro/blob/master/code/data_colorwash.asm
	.byte $09,$09,$02,$02,$08,$08,$0a,$0a
	.byte $0f,$0f,$07,$07,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01
	.byte $07,$07,$0f,$0f,$0a,$0a,$08,$08
	.byte $02,$02,$09,$09

raster_colors_bottom:
	.byte $09,$09,$02,$02
	.byte $08,$08,$0a,$0a,$0f,$0f,$07,$07
	.byte $01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$07,$07,$0f,$0f
	.byte $0a,$0a,$08,$08,$02,$02,$09,$09
	.byte 0				; FIXME: ignore, for overflow

TOTAL_RASTER_LINES = raster_colors_bottom-raster_colors_top

sync:			.byte 0
sync50hz:		.byte 0
smooth_scroll_x:	.byte 7
chars_scrolled:		.byte 128
current_char:		.byte 0
anim_speed:		.byte 7
anim_char_idx:		.byte ANIM_TOTAL_FRAMES-1
scroller_text_ptr_low:	.byte 0
scroller_text_ptr_hi:	.byte 0
colorwash_delay:	.byte COLORWASH_DELAY

scroller_text:
        scrcode "   retro moe presents "
	.byte 65
	scrcode "the muni race"
	.byte 66
	scrcode " the best mountain unicycle racing game for the "
	.byte 64
	scrcode "64. "
	scrcode "people said about this game: 'awesome graphics', 'impressive physics', "
	scrcode "'best sound ever', 'i want to ride a real unicycle now', "
	scrcode "'bikes? what a waste of resources!', "
	scrcode "and much more! "
	scrcode "credits: code and some gfx by riq, the rest was taken from somewhere... "
	scrcode "tools: ca65, vim, gimp, project one, vice, wine, vchar64, spritepad... "
	scrcode "download the source code: https://github.com/ricardoquesada/c64-the-muni-race "
	scrcode "  come and join us for a muni ride: http://berkeleyunicycling.org "
	scrcode "  high quality unicycles: http://www.krisholm.com "
	scrcode "      contact retro moe at: http://retro.moe "
	scrcode "      press 'space' to return to the main menu...   "
	.byte $ff

char_frames:
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00011000
	.byte %00011000
	.byte %00000000
	.byte %00000000
	.byte %00000000

	.byte %00000000
	.byte %00000000
	.byte %00011000
	.byte %00111100
	.byte %00111100
	.byte %00011000
	.byte %00000000
	.byte %00000000

	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00011000
	.byte %00011000
	.byte %00000000
	.byte %00000000
	.byte %00000000

	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000

empty_char:
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111


.segment "SIDMUSIC"
;         .incbin "res/music.sid",$7e
	 .incbin "res/1_45_Tune.sid",$7e

.segment "ABOUT_GFX"
;	 .incbin "res/muni-320x200x16.prg"
	 .incbin "res/the-muni-race.kla",2


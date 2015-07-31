;--------------------------------------------------------------------------
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; About file
;
; Zero Page global registers:
;   $f9/$fa -> charset:  ** MUST NOT be modifed by any other functions **
;
;--------------------------------------------------------------------------


; exported by the linker
.import __ABOUT_CHARSET_LOAD__, __SIDMUSIC_LOAD__, __ABOUT_CODE_LOAD__, __ABOUT_GFX_LOAD__, __MAIN_CODE_LOAD__

; from utils.s
.import clear_screen, clear_color, get_key

;--------------------------------------------------------------------------
; Constants
;--------------------------------------------------------------------------

DEBUG = 0			; Use 1 to enable music-raster debug

RASTER_START = 50

SCROLL_AT_LINE = 18
ROWS_PER_CHAR = 7

SCREEN_TOP = $0400 + SCROLL_AT_LINE * 40


MUSIC_INIT = __SIDMUSIC_LOAD__
MUSIC_PLAY = __SIDMUSIC_LOAD__ + 3

; SPEED must be between 0 and 7. 0=Stop, 7=Max speed
SCROLL_SPEED = 6

; Black
SCROLL_BKG_COLOR = 0

; SPEED of colorwasher: 1=Max speed
COLORWASH_SPEED = 1

ANIM_SPEED = 1

KOALA_BITMAP_DATA = __ABOUT_GFX_LOAD__
KOALA_CHARMEM_DATA = KOALA_BITMAP_DATA + $1f40
KOALA_COLORMEM_DATA = KOALA_BITMAP_DATA + $2328
KOALA_BACKGROUND_DATA = KOALA_BITMAP_DATA + $2710

;--------------------------------------------------------------------------
; Macros
;--------------------------------------------------------------------------
.macpack cbm			; adds support for scrcode
.macpack mymacros		; my own macros

.segment "ABOUT_CODE"

;--------------------------------------------------------------------------
; _main
;--------------------------------------------------------------------------
	jsr init


@mainloop:
	lda #0
	sta sync
:	cmp sync
	beq :-

	jsr scroll
	jsr anim_char
	jsr anim_colorwash

	; key pressed ?
	jsr get_key
	bcc @mainloop
	cmp #$47		; space
	bne @mainloop

	jmp __MAIN_CODE_LOAD__


irq1:
	pha			; saves A, X, Y
	txa
	pha
	tya
	pha

	STABILIZE_RASTER

	.repeat 23
		nop
	.endrepeat

	; char mode
	lda #%00011011		; +2
	sta $d011		; +4

	ldx #SCROLL_BKG_COLOR	; +6
	stx $d020		; +10
	stx $d021		; +14

	lda smooth_scroll_x	; +16
	sta $d016		; +20

	; raster bars
	ldx #$00		; +22

	; 7 chars of 8 raster lines
	; the "+8" in "raster_colors+8" is needed
	; in order to center the washer effect.
	; the washer colors has 64 colors, but here we are using only 56 lines (7 rows of 8 lines each)
	.repeat ROWS_PER_CHAR
		; 7 "Good" lines: I must consume 63 cycles
		.repeat 7
			lda raster_colors+8,x	; +4
			sta $d021		; +4
			inx			; +2
			.repeat 25
				nop		; +2 * 25
			.endrepeat
			bit $00			; +3 = 63 cycles
		.endrepeat
		; 1 "Bad lines": I must consume ~20 cycles
		lda raster_colors+8,x		; +4
		sta $d021			; +4
		inx				; +2
		.repeat 5
			nop			; +2 * 5 = 20 cycles
		.endrepeat
	.endrepeat

	.repeat 23
		nop
	.endrepeat

	; color
	lda #$00
	sta $d020
	lda KOALA_BACKGROUND_DATA
	sta $d021

	; no scroll, multi-color
	lda #%00011000
	sta $d016

	; hires bitmap mode
	lda #%00111011
	sta $d011

	inc sync

.if (DEBUG=1)
	inc $d020
.endif
	jsr MUSIC_PLAY
.if (DEBUG=1)
	dec $d020
.endif

	; we have to re-schedule irq1 from irq1 basically because
	; we are using a double IRQ
	lda #<irq1
	sta $fffe
	lda #>irq1
	sta $ffff

	lda #RASTER_START+SCROLL_AT_LINE*8-2
	sta $d012

	asl $d019

	pla			; restores A, X, Y
	tay
	pla
	tax
	pla
	rti			; restores previous PC, status


;--------------------------------------------------------------------------
; scroll(void)
; main scroll function
;--------------------------------------------------------------------------
.proc scroll
	; speed control

	sec
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

	; A and current_char will contain the char to print
	; $f9/$fa points to the charset definition of the char
	jsr setup_charset

:
	; basic setup
	ldx #<(SCREEN_TOP+7*40+39)
	ldy #>(SCREEN_TOP+7*40+39)
	stx @screen_address
	sty @screen_address+1

	; should not be bigger than 7 (8 rows)
	ldy #.min(ROWS_PER_CHAR,7)


@loop:
	lda ($f9),y
	and chars_scrolled
	beq @empty_char

;	 lda current_char
	; char to display
	lda #$fe		; full char
	bne :+

@empty_char:
	lda #$ff		; empty char

:
	; self-changing value
	; this value will be overwritten with the address of the screen
@screen_address = *+1
	sta $caca

	; next line for top scroller
	sec
	lda @screen_address
	sbc #40
	sta @screen_address
	bcs :+
	dec @screen_address+1
:

	dey			; next charset definition
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


;--------------------------------------------------------------------------
; scroll_screen(void)
;--------------------------------------------------------------------------
; args: -
; modifies: A, X, Status
;--------------------------------------------------------------------------
scroll_screen:
	; move the chars to the left and right
	ldx #0

	; doing a cpy #$ff
	ldy #38

@loop:
	.repeat ROWS_PER_CHAR,i
		lda SCREEN_TOP+40*i+1,x
		sta SCREEN_TOP+40*i+0,x
	.endrepeat

	inx
	dey
	bpl @loop
	rts

;--------------------------------------------------------------------------
; setup_charset(void)
;--------------------------------------------------------------------------
; Args: -
; Modifies A, X, Status
; returns A: the character to print
;--------------------------------------------------------------------------
.proc setup_charset
	; put next char in column 40

	; supports a scroller with more than 255 chars
	clc
	lda #<scroller_text
	adc scroller_text_ptr_low
	sta @address
	lda #>scroller_text
	adc scroller_text_ptr_hi
	sta @address+1

	; self-changing value
@address = *+1
	lda scroller_text
	cmp #$ff
	bne :+

        ; reached $ff. Then start from the beginning
	lda #%10000000
	sta chars_scrolled
	lda #0
	sta scroller_text_ptr_low
	sta scroller_text_ptr_hi
	lda scroller_text
:
	sta current_char

	tax

	; address = CHARSET + 8 * index
	; multiply by 8 (LSB)
	asl
	asl
	asl
	clc
	adc #<__ABOUT_CHARSET_LOAD__
	sta $f9

	; multiply by 8 (MSB)
	; 256 / 8 = 32
	; 32 = %00100000
	txa
	lsr
	lsr
	lsr
	lsr
	lsr

	clc
	adc #>__ABOUT_CHARSET_LOAD__
	sta $fa

	rts
.endproc

;--------------------------------------------------------------------------
; anim_char(void)
;--------------------------------------------------------------------------
; Args: -
; Modifies A, X, Status
; returns A: the character to print
;--------------------------------------------------------------------------
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
	asl			; multiply by 8 (next char)
	asl
	asl
	tay

	ldx #7			; 8 rows
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

;--------------------------------------------------------------------------
; anim_colorwash(void)
;--------------------------------------------------------------------------
; Args: -
; A Color washer routine
;--------------------------------------------------------------------------
.proc anim_colorwash

	dec colorwash_delay
	beq :+
	rts

:
	lda #COLORWASH_SPEED
	sta colorwash_delay

	; washer top
	lda raster_colors_top
	sta save_color_top

	ldx #0
:	lda raster_colors_top+1,x
	sta raster_colors_top,x
	inx
	cpx #TOTAL_RASTER_LINES
	bne :-

save_color_top = *+1
	lda #00			; This value will be overwritten
	sta raster_colors_top+TOTAL_RASTER_LINES-1

	; washer bottom
	lda raster_colors_bottom+TOTAL_RASTER_LINES-1
	sta save_color_bottom

	cpx #TOTAL_RASTER_LINES-1
:	lda raster_colors_bottom,x
	sta raster_colors_bottom+1,x
	dex
	bpl :-

save_color_bottom = *+1
	lda #00			; This value will be overwritten
	sta raster_colors_bottom
	rts
.endproc

;--------------------------------------------------------------------------
; init(void)
;--------------------------------------------------------------------------
; Args: -
; Clear screen, interrupts, charset and others
;--------------------------------------------------------------------------
.proc init
	; must be BEFORE any screen-related function
	lda #$20
	jsr clear_screen
	lda #$00
	jsr clear_color

	; must be BEFORE init_charset / init_scroll_colors
	jsr init_koala_colors

	; must be AFTER koala colors
	jsr init_charset

	; must be AFTER koala colors
	jsr init_scroll_colors

	;default values for scroll variables
	jsr init_scroll_vars

	; no sprites please
	lda #$00
	sta $d015

	; init music
	lda #0
	jsr MUSIC_INIT

	; colors
	lda #0
	sta $d020
	sta $d021

	; default is:
	;    %00010101
        ; charset at $3800
	lda #%00011111
	sta $d018

	; no interrups
	sei

	; turn off cia interrups
	lda #$7f
	sta $dc0d
	sta $dd0d

	; enable raster irq
	lda #01
	sta $d01a

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

        ; Vic bank 0: $0000-$3FFF
	lda $dd00
        and #$fc
	ora #3
        sta $dd00

	;
	; irq handler
	;
	lda #<irq1
	sta $fffe
	lda #>irq1
	sta $ffff

	; raster interrupt
	lda #RASTER_START+SCROLL_AT_LINE*8-2
	sta $d012

	; clear interrupts and ACK irq
	lda $dc0d
	lda $dd0d
	asl $d019


	; enable interrups again
	cli

	rts
.endproc

;--------------------------------------------------------------------------
; init_koala_colors(void)
;--------------------------------------------------------------------------
; Args: -
; puts the koala colors in the correct address
; Assumes that bimap data was loaded in the correct position
;--------------------------------------------------------------------------
.proc init_koala_colors

	; Koala format
	; bitmap:           $0000 - $1f3f = $1f40 ( 8000) bytes
	; color %01 - %10:  $1f40 - $2327 = $03e8 ( 1000) bytes
	; color %11:        $2328 - $270f = $03e8 ( 1000) bytes
	; color %00:        $2710         =     1 (    1) byte
	; total:                    $2710 (10001) bytes

	ldx #$00
@loop:
	; $0400: colors %01, %10
	lda KOALA_CHARMEM_DATA,x
	sta $0400,x
	lda KOALA_CHARMEM_DATA+$0100,x
	sta $0400+$0100,x
	lda KOALA_CHARMEM_DATA+$0200,x
	sta $0400+$0200,x
	lda KOALA_CHARMEM_DATA+$02e8,x
	sta $0400+$02e8,x

	; $d800: color %11
	lda KOALA_COLORMEM_DATA,x
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

;--------------------------------------------------------------------------
; init_scroll_colors(void)
;--------------------------------------------------------------------------
; Args: -
;--------------------------------------------------------------------------
.proc init_scroll_colors
	; foreground RAM color for scroll lines
	ldx #0
	; 9 lines: 40 * 9 = 360. 256 + 104
@loop:
	; clear color
	lda #SCROLL_BKG_COLOR
	sta $d800 + SCROLL_AT_LINE * 40,x
	sta $d800 + SCROLL_AT_LINE * 40 + (ROWS_PER_CHAR*40-256),x

	; clear char
	lda #$ff
	sta $0400 + SCROLL_AT_LINE * 40,x
	sta $0400 + SCROLL_AT_LINE * 40 + (ROWS_PER_CHAR*40-256),x

	inx
	bne @loop
	rts
.endproc

;--------------------------------------------------------------------------
; init_scroll_vars(void)
;--------------------------------------------------------------------------
; Args: -
;--------------------------------------------------------------------------
.proc init_scroll_vars
	lda #$01
	sta sync
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

;--------------------------------------------------------------------------
; init_charset(void)
;--------------------------------------------------------------------------
; Args: -
; copies 3 custom chars to the correct address
;--------------------------------------------------------------------------
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

;--------------------------------------------------------------------------
; variables
;--------------------------------------------------------------------------

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
	; FIXME: ignore, for overflow
	.byte 0

TOTAL_RASTER_LINES = raster_colors_bottom-raster_colors_top

sync:			.byte 1
smooth_scroll_x:	.byte 7
chars_scrolled:		.byte 128
current_char:		.byte 0
anim_speed:		.byte 7
anim_char_idx:		.byte ANIM_TOTAL_FRAMES-1
scroller_text_ptr_low:	.byte 0
scroller_text_ptr_hi:	.byte 0
colorwash_delay:        .byte COLORWASH_SPEED

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
	scrcode "tools used: ca65, vim, gimp, project one, wine, vchar64, spritepad, vice... "
        scrcode "download the source code from https://github.com/ricardoquesada/c64-the-muni-race "
        scrcode "  come and join us in a muni ride: http://berkeleyunicycling.org/ "
        scrcode "      contact me: http://retro.moe "
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

.segment "ABOUT_CHARSET"
	.incbin "res/1-writer.64c",2

.segment "SIDMUSIC"
;         .incbin "res/music.sid",$7e
         .incbin "res/1_45_Tune.sid",$7e

.segment "ABOUT_GFX"
;	 .incbin "res/muni-320x200x16.prg"
	 .incbin "res/the-muni-race.kla",2


;
; The Race
; Intro file
;
; Zero Page global registers:
;     ** MUST NOT be modifed by any other functions **
;   $f9/$fa -> charset
;
;
; Zero Page: modified by the program, but can be modified by other functions
;   $fb/$fc -> screen pointer (upper)
;   $fd/$fe -> screen pointer (bottom)


; exported by the linker
.import __CHARSET_LOAD__, __SIDMUSIC_LOAD__

; Use 1 to enable music-raster debug
DEBUG = 1

RASTER_START = 50

SCROLL_1_AT_LINE = 0
SCROLL_2_AT_LINE = 17

SCREEN_TOP = $0400 + SCROLL_1_AT_LINE * 40
SCREEN_BOTTOM = $0400 + SCROLL_2_AT_LINE * 40


MUSIC_INIT = __SIDMUSIC_LOAD__
MUSIC_PLAY = __SIDMUSIC_LOAD__ + 3

SPEED = 2			; must be between 1 and 8


.macpack cbm			; adds support for scrcode

.segment "CODE"

;--------------------------------------------------------------------------
; _main
;--------------------------------------------------------------------------
	jsr $ff81		; init screen

	; default is #$15  #00010101
	lda #%00011110
	sta $d018		; logo font at $3800

	sei

	; turn off cia interrups
	lda #$7f
	sta $dc0d
	sta $dd0d

	lda $d01a		; enable raster irq
	ora #$01
	sta $d01a

	lda $d011		; clear high bit of raster line
	and #$7f
	sta $d011

	; irq handler
	lda #<irq1
	sta $0314
	lda #>irq1
	sta $0315

	; raster interrupt
	lda #RASTER_START+SCROLL_1_AT_LINE*8
	sta $d012

	; clear interrupts and ACK irq
	lda $dc0d
	lda $dd0d
	asl $d019

	lda #0
	jsr MUSIC_INIT

	cli


mainloop:
	lda #0
	sta sync
:	cmp sync
	beq :-

	jsr scroll
	jmp mainloop

irq1:
	asl $d019

	lda #<irq2
	sta $0314
	lda #>irq2
	sta $0315

	lda #RASTER_START+(SCROLL_1_AT_LINE+8)*8
	sta $d012

	lda #3
	sta $d020

	; scroll left, upper part
	lda scroll_left
	sta $d016

	jmp $ea81

irq2:
	asl $d019

	lda #<irq3
	sta $0314
	lda #>irq3
	sta $0315

	; FIXME If I don't add the -1 it won't scroll correctly.
	; FIXME Raster is not stable.
	lda #RASTER_START+(SCROLL_2_AT_LINE)*8-1
	sta $d012

	lda #1
	sta $d020

	; no scroll
	lda #%00001000
	sta $d016

	jmp $ea81


irq3:
	asl $d019

	lda #<irq4
	sta $0314
	lda #>irq4
	sta $0315

	lda #RASTER_START+(SCROLL_2_AT_LINE+8)*8
	sta $d012

	lda #0
	sta $d020

	; scroll right, bottom part
	lda scroll_left
	eor #$07		; negate "scroll left" to simulate "scroll right"
	and #$07
	sta $d016

	jmp $ea81


irq4:
	asl $d019

	lda #<irq1
	sta $0314
	lda #>irq1
	sta $0315

	; FIXME If I don't add the -1 it won't scroll correctly.
	; FIXME Raster is not stable.
	lda #RASTER_START+SCROLL_1_AT_LINE*8-1
	sta $d012

	lda #1
	sta $d020

	; no scroll
	lda #%00001000
	sta $d016

	inc sync

.if (DEBUG=1)
	inc $d020
.endif
	jsr MUSIC_PLAY
.if (DEBUG=1)
	dec $d020
.endif

	jmp $ea31


;--------------------------------------------------------------------------
; scroll(void)
; main scroll function
;--------------------------------------------------------------------------
scroll:
	; speed control

	ldx scroll_left		; save current value in X
.repeat SPEED
	dec scroll_left
.endrepeat

	lda scroll_left
	and #07
	sta scroll_left

	cpx scroll_left		; new value is higher than the old one ? if so, then scroll
	bcc :+

	rts

:
	jsr scroll_screen
	jsr anim_char

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
	stx $fb
	sty $fc
	ldx #<(SCREEN_BOTTOM)
	ldy #>(SCREEN_BOTTOM)
	stx $fd
	sty $fe

	ldy #7			; 8 rows


@loop:
	ldx #0

	lda ($f9),y
	and chars_scrolled
	beq @empty_char

;	 lda current_char
	; different chars for top and bottom
	lda #$fd
	sta ($fb,x)
	lda #$fe
	sta ($fd,x)

	bne :+

@empty_char:
	lda #$ff		; empty char
	sta ($fb,x)
	sta ($fd,x)

:
	; next line for top scroller
	sec
	lda $fb
	sbc #40
	sta $fb
	bcs :+
	dec $fc

:
	; next line for bottom scroller
	clc
	lda $fd
	adc #40
	sta $fd
	bcc :+
	inc $fe

:
	dey			; next charset definition
	bpl @loop

	lsr chars_scrolled
	bcc @endscroll

	lda #128
	sta chars_scrolled

	inc label_index

@endscroll:
	rts


;--------------------------------------------------------------------------
; scroll_screen(void)
;--------------------------------------------------------------------------
; args: -
; modifies: A, X, Status
;--------------------------------------------------------------------------
.proc scroll_screen
	; move the chars to the left and right
	ldx #0

	; doing a cpy #$ff
	ldy #38

@loop:
.repeat 8,i
	lda SCREEN_TOP+40*i+1,x
	sta SCREEN_TOP+40*i+0,x
.endrepeat

.repeat 8,i
	lda SCREEN_BOTTOM+40*i+0,y
	sta SCREEN_BOTTOM+40*i+1,y
.endrepeat

	inx
	dey
	bpl @loop
	rts
.endproc

;--------------------------------------------------------------------------
; setup_charset(void)
;--------------------------------------------------------------------------
; Args: -
; Modifies A, X, Status
; returns A: the character to print
;--------------------------------------------------------------------------
.proc setup_charset
	; put next char in column 40
	ldx label_index
	lda label,x
	cmp #$ff
	bne :+

	; reached $ff ? Then start from the beginning
	lda #%10000000
	sta chars_scrolled
	lda #0
	sta label_index
	lda label
:
	sta current_char

	tax

	; address = CHARSET + 8 * index
	; multiply by 8 (LSB)
	asl
	asl
	asl
	clc
	adc #<__CHARSET_LOAD__
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
	adc #>__CHARSET_LOAD__
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
.proc anim_char

.if 1
	; self modifying code
	lda anim_char_idx
	asl			; multiply by 8 (next char)
	asl
	asl
	tay
	clc
	adc #<anim_char_0
	sta @anim_address+1
	lda #>anim_char_0
	sta @anim_address+2

	ldx #7
@loop:

@anim_address:
	lda anim_char_0,x
	sta __CHARSET_LOAD__ + 254 * 8,x

	dex
	cpx #$ff
	bne @loop

	inc anim_char_idx
	lda anim_char_idx
	cmp #6
	bne :+

	; reset anim_char_idx
	lda #0
	sta anim_char_idx
:
	rts

.else
	ldx #7
@loop:
	; ror
	clc
	lda #%00000001
	and __CHARSET_LOAD__ + $fd * 8,x
	beq :+
	sec
:
	ror __CHARSET_LOAD__ + $fd * 8,x

	; rol
	clc
	lda #%10000000
	and __CHARSET_LOAD__ + $fe * 8,x
	beq :+
	sec
:
	rol __CHARSET_LOAD__ + $fe * 8,x
	dex
	bpl @loop
	rts
.endif
.endproc

; variables
sync:	.byte 1
scroll_left:	.byte 7
label_index:	.byte 0
chars_scrolled:	.byte 128
current_char:	.byte 0
anim_char_idx:	.byte 0

label:
	scrcode "welcome to the race. one or two players. networking races. hello world."
	.byte $ff

anim_char_0:
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111

	.byte %00000000
	.byte %01111110
	.byte %01111110
	.byte %01111110
	.byte %01111110
	.byte %01111110
	.byte %01111110
	.byte %00000000

	.byte %00000000
	.byte %00000000
	.byte %00111100
	.byte %00111100
	.byte %00111100
	.byte %00111100
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

	.byte %11111111
	.byte %10000001
	.byte %10000001
	.byte %10000001
	.byte %10000001
	.byte %10000001
	.byte %10000001
	.byte %11111111

	.byte %11111111
	.byte %11111111
	.byte %11000011
	.byte %11000011
	.byte %11000011
	.byte %11000011
	.byte %11111111
	.byte %11111111
	
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11100111
	.byte %11100111
	.byte %11111111
	.byte %11111111
	.byte %11111111


.segment "CHARSET"
	; last 3 chars reserved
	.incbin "fonts/scrap_writer_iii_16.64c",2,(2048-8*3)

.segment "CHARSET254"
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %11111111
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000

	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %11111111
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000

	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111

.segment "SIDMUSIC"
	 .incbin "music.sid",$7e


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

; from utils.s
.import clear_screen, color_screen

;--------------------------------------------------------------------------
; Constants
;--------------------------------------------------------------------------

DEBUG = 0			; Use 1 to enable music-raster debug

RASTER_START = 50

SCROLL_1_AT_LINE = 0
SCROLL_2_AT_LINE = 17

SCREEN_TOP = $0400 + SCROLL_1_AT_LINE * 40
SCREEN_BOTTOM = $0400 + SCROLL_2_AT_LINE * 40


MUSIC_INIT = __SIDMUSIC_LOAD__
MUSIC_PLAY = __SIDMUSIC_LOAD__ + 3

; SPEED must be between 0 and 7. 0=Stop, 7=Max speed
SCROLL_SPEED = 4
ANIM_SPEED = 2


;--------------------------------------------------------------------------
; Macros
;--------------------------------------------------------------------------
.macpack cbm			; adds support for scrcode

; Double-IRQ Stable raster routine
; taken from: http://codebase64.org/doku.php?id=base:stable_raster_routine
.macro STABILIZE_RASTER
	lda #<@irq_stable	; set IRQ Vector
	ldx #>@irq_stable	; to point to the next part of the
	sta $fffe		; Stable IRQ
	stx $ffff		; ON NEXT LINE!
	inc $d012
	asl $d019		; Ack RASTER IRQ
	tsx			; We want the IRQ
	cli			; To return to our

.repeat 8
	nop
.endrepeat

@irq_stable:
	txs			; Restore STACK Pointer
	ldx #$08		; Wait exactly 1
	dex			; lines worth of
	bne *-1			; cycles for compare
	bit $ea			; Minus compare

	lda $d012		; RASTER change yet?
	cmp $d012
	beq *+2			; If no waste 1 more cycle
.endmacro

.segment "CODE"

;--------------------------------------------------------------------------
; _main
;--------------------------------------------------------------------------
	jsr init


mainloop:
	lda #0
	sta sync
:	cmp sync
	beq :-

	jsr scroll
	jsr anim_char
	jmp mainloop

irq1:
	pha			; saves A, X, Y
	txa
	pha
	tya
	pha

	STABILIZE_RASTER

	ldx #15			; Grey 2
	ldy #12			; Grey 2
	stx $d020
	sty $d021

	lda smooth_scroll_x
	sta $d016

	lda #<irq2
	sta $fffe
	lda #>irq2
	sta $ffff

	lda #RASTER_START+(SCROLL_1_AT_LINE+8)*8-1
	sta $d012

	asl $d019

	pla			; restores A, X, Y
	tay
	pla
	tax
	pla
	rti			; restores previous PC, status

irq2:
	pha			; saves A, X, Y
	txa
	pha
	tya
	pha

	STABILIZE_RASTER

	; color
	lda #0
	sta $d020
	sta $d021

	; no scroll
	lda #%00001000
	sta $d016


	lda #<irq3
	sta $fffe
	lda #>irq3
	sta $ffff

	lda #RASTER_START+(SCROLL_2_AT_LINE)*8-2
	sta $d012

	asl $d019

	pla			; restores A, X, Y
	tay
	pla
	tax
	pla
	rti			; restores previous PC, status


irq3:
	pha			; saves A, X, Y
	txa
	pha
	tya
	pha

	STABILIZE_RASTER

	ldx #15			; Grey 2
	ldy #12			; Grey 2
	stx $d020
	sty $d021

	; scroll right, bottom part
	lda smooth_scroll_x
	eor #$07		; negate "scroll left" to simulate "scroll right"
	and #$07
	sta $d016

	lda #<irq4
	sta $fffe
	lda #>irq4
	sta $ffff

	lda #RASTER_START+(SCROLL_2_AT_LINE+8)*8-1
	sta $d012

	asl $d019

	pla			; restores A, X, Y
	tay
	pla
	tax
	pla
	rti			; restores previous PC, status


irq4:
	pha			; saves A, X, Y
	txa
	pha
	tya
	pha

	STABILIZE_RASTER
	
	lda #0
	sta $d020
	sta $d021

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

	lda #<irq1
	sta $fffe
	lda #>irq1
	sta $ffff

	lda #RASTER_START+SCROLL_1_AT_LINE*8-2
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
.endproc


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

        ; reached $ff. Then start from the beginning
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
ANIM_TOTAL_FRAMES = 14
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
	lda anim_char_0,y
	sta __CHARSET_LOAD__ + $fd * 8,x
	eor #$ff
	sta __CHARSET_LOAD__ + $fe * 8,x

	iny
	dex
	bpl @loop

	dec anim_char_idx
	bpl :+

	; reset anim_char_idx
	lda #ANIM_TOTAL_FRAMES-1; 10 frames
	sta anim_char_idx
:
	rts
.endproc

;--------------------------------------------------------------------------
; init(void)
;--------------------------------------------------------------------------
; Args: -
; Clear screen, interrupts, charset and others
;--------------------------------------------------------------------------
.proc init
	lda #$ff
	jsr clear_screen
	lda #0
	jsr color_screen

	; foreground RAM color for scroll lines
	ldx #0
	lda #15
	; 8 lines: 40 * 8 = 320. 256 + 64
@loop:
	sta $d800 + SCROLL_1_AT_LINE * 40,x
	sta $d800 + SCROLL_1_AT_LINE * 40 + 64,x
	sta $d800 + SCROLL_2_AT_LINE * 40,x
	sta $d800 + SCROLL_2_AT_LINE * 40 + 64,x
	inx
	bne @loop


	; colors
	lda #0
	sta $d020
	sta $d021

	; default is:
	;    %00010101
	lda #%00011110
	sta $d018		; charset at $3800

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
	lda #%00011011
	sta $d011

	; turn off BASIC and KERNAL
	; but $d000-$e000 visible to SID/VIC
	lda #$35
	sta $01

	;
	; irq handler
	;
	lda #<irq1
	sta $fffe
	lda #>irq1
	sta $ffff

	; raster interrupt
	lda #RASTER_START+SCROLL_1_AT_LINE*8-1
	sta $d012

	; clear interrupts and ACK irq
	lda $dc0d
	lda $dd0d
	asl $d019


	;
	; init music
	;
	lda #0
	jsr MUSIC_INIT

	cli

	rts
.endproc

; variables
sync:			.byte 1
smooth_scroll_x:	.byte 7
label_index:		.byte 0
chars_scrolled:		.byte 128
current_char:		.byte 0
anim_speed:		.byte 7
anim_char_idx:		.byte ANIM_TOTAL_FRAMES-1

label:
	scrcode "    - - - - welcome to 'the race': a racing game. who would have guessed it, right?"
	scrcode "but there is no game for the moment... ha ha ha... just this lame intro screen."
	scrcode "come back soon"
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

	.byte %01111110
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %01111110

	.byte %00111100
	.byte %01111110
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %01111110
	.byte %00111100

	.byte %00011000
	.byte %00111100
	.byte %01111110
	.byte %11111111
	.byte %11111111
	.byte %01111110
	.byte %00111100
	.byte %00011000

	.byte %00000000
	.byte %00011000
	.byte %00111100
	.byte %01111110
	.byte %01111110
	.byte %00111100
	.byte %00011000
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
	.byte %00011000
	.byte %00111100
	.byte %01111110
	.byte %01111110
	.byte %00111100
	.byte %00011000
	.byte %00000000

	.byte %00011000
	.byte %00111100
	.byte %01111110
	.byte %11111111
	.byte %11111111
	.byte %01111110
	.byte %00111100
	.byte %00011000

	.byte %00111100
	.byte %01111110
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %01111110
	.byte %00111100

	.byte %01111110
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %01111110

.segment "CHARSET"
	; last 3 chars reserved
        .incbin "res/scrap_writer_iii_16.64c",2,(2048-8*3)

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
         .incbin "res/music.sid",$7e


;--------------------------------------------------------------------------
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; Collection of utils functions
;
;--------------------------------------------------------------------------

.segment "CODE"

;--------------------------------------------------------------------------
; clear_screen(int char_used_to_clean)
;--------------------------------------------------------------------------
; Args: A char used to clean the screen.
; Clears the screen
;--------------------------------------------------------------------------
.export clear_screen
.proc clear_screen
	ldx #0
:
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $06e8,x
	inx
	bne :-

	rts
.endproc


;--------------------------------------------------------------------------
; clear_color(int foreground_color)
;--------------------------------------------------------------------------
; Args: A color to be used. Only lower 3 bits are used.
; Changes foreground RAM color
;--------------------------------------------------------------------------
.export clear_color
.proc clear_color
	ldx #0
:
	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $dae8,x
	inx
	bne :-

	rts
.endproc

;--------------------------------------------------------------------------
; char get_key(void)
;--------------------------------------------------------------------------
; reads a key from the keyboard
; Carry set if keyboard detected. Othewise Carry clear
; Returns key in A
; Code by Groepaz. Copied from:
; http://codebase64.org/doku.php?id=base:reading_the_keyboard&s[]=keyboard
;--------------------------------------------------------------------------
.export get_key
.proc get_key
	lda #$0
	sta $dc03	; port b ddr (input)
	lda #$ff
	sta $dc02	; port a ddr (output)
			
	lda #$00
	sta $dc00	; port a
	lda $dc01       ; port b
	cmp #$ff
	beq @nokey
	; got column
	tay
			
	lda #$7f
	sta @nokey2+1
	ldx #8
@nokey2:
	lda #0
	sta $dc00	; port a
	
	sec
	ror @nokey2+1
	dex
	bmi @nokey
			
	lda $dc01       ; port b
	cmp #$ff
	beq @nokey2
			
	; got row in X
	txa
	ora @columntab,y
			
	sec
	rts
			
@nokey:
	clc
	rts

@columntab:
	.repeat 256,count
		.if count = ($ff-$80)
			.byte $70
		.elseif count = ($ff-$40)
			.byte $60
		.elseif count = ($ff-$20)
			.byte $50
		.elseif count = ($ff-$10)
			.byte $40
		.elseif count = ($ff-$08)
			.byte $30
		.elseif count = ($ff-$04)
			.byte $20
		.elseif count = ($ff-$02)
			.byte $10
		.elseif count = ($ff-$01)
			.byte $00
		.else
			.byte $ff
		.endif
	.endrepeat

.endproc


;--------------------------------------------------------------------------
; char read_joy2(void)
;--------------------------------------------------------------------------
; reads the joystick in port2
;--------------------------------------------------------------------------
.export read_joy2
.proc read_joy2
	lda $dc00
	rts
.endproc

;--------------------------------------------------------------------------
; char detect_pal_ntsc(void)
;--------------------------------------------------------------------------
; code taken from here: http://codebase64.org/doku.php?id=base:detect_pal_ntsc
; returns A: $03 = PAL:  312 rasterlines
;	     $02 = NTSC: 263 rasterlines
;	     $01 = NTSC: 262 rasterlines
;
;	312 rasterlines -> 63 cycles per line [PAL: 6569 VIC]
;	263 rasterlines -> 65 cycles per line [NTSC: 6567R8 VIC]
;	262 rasterlines -> 64 cycles per line [NTSC: 6567R56A VIC]
;--------------------------------------------------------------------------
.export detect_pal_ntsc
.proc detect_pal_ntsc
	sei
:
	lda $d012
:
	cmp $d012
	beq :-
	bmi :--
	and #$03
	cli
	rts
.endproc


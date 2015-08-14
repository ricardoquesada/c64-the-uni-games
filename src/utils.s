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
; char detect_pal_paln_ntsc(void)
;--------------------------------------------------------------------------
; It counts how many rasterlines were drawn in 312*63-1 (19655) cycles. 
;
; In PAL,      (312 by 63)  19655/63 = 312  -> 312 % 312   (00, $00)
; In PAL-N,    (312 by 65)  19655/65 = 302  -> 302 % 312   (46, $2e)
; In NTSC,     (263 by 65)  19655/65 = 302  -> 302 % 263   (39, $27)
; In NTSC Old, (262 by 64)  19655/64 = 307  -> 307 % 262   (45, $2d) 
;
; Return values:
;   $01 --> PAL
;   $2F --> PAL-N
;   $28 --> NTSC
;   $2e --> NTSC-OLD
;
;--------------------------------------------------------------------------
.export vic_video_type
vic_video_type: .byte $00

.export detect_pal_paln_ntsc
.proc detect_pal_paln_ntsc
	sei

	; wait for start of raster (more stable results)
:	lda $d012
:	cmp $d012
	beq :-
	bmi :--

	lda #$00
	sta $dc0e

	lda #$00
	sta $d01a		; no raster IRQ
	lda #$7f
	sta $dc0d		; no timer IRQ
	sta $dd0d

	lda #$00
	sta sync

	ldx #<(312*63-1)	; set the timer for PAL
	ldy #>(312*63-1)
	stx $dc04
	sty $dc05

	lda #%00001001		; one-shot only
	sta $dc0e

	ldx #<timer_irq
	ldy #>timer_irq
	stx $fffe
	sty $ffff

	lda $dc0d		; clear possible interrupts
	lda $dd0d


	lda #$81
	sta $dc0d		; enable time A interrupts
	cli

:	lda sync
	beq :-

	lda vic_video_type
	rts

timer_irq:
	pha			; only saves A

	sei
	; timer A interrupt
	lda $dc0d		; clear the interrupt

	lda $d012
	sta vic_video_type

	inc sync
	cli

	pla			; restoring A
	rti

sync:		.byte $00

.endproc

;--------------------------------------------------------------------------
; void sync_irq_timer()
;--------------------------------------------------------------------------
; code taken from zoo mania game source code: http://csdb.dk/release/?id=121860
; and values from here: http://codebase64.org/doku.php?id=base:playing_music_on_pal_and_ntsc
;--------------------------------------------------------------------------
PAL_TIMER := (312*63)-1			; raster lines (312) * cycles_per_line(63) = 19656 
PAL_N_TIMER := $4fc2-1 			; 19656 / (985248/1023445) - 1
NTSC_TIMER := $4fb2			; 19656 / (985248/1022727) - 1

.export sync_irq_timer
.proc sync_irq_timer

	lda #$00
	sta $dc0e

	ldy #$08
@wait:
	cpy $d012
	bne @wait
	lda $d011
	bmi @wait

	lda vic_video_type
	cmp #$01
	beq @pal
	cmp #$2f
	beq @paln

	; 50hz on NTSC			; it is an NTSC
	lda #<NTSC_TIMER
	ldy #>NTSC_TIMER
	jmp @end

@paln:					; it is a PAL-N (drean commodore 64)
	lda #<PAL_N_TIMER
	ldy #>PAL_N_TIMER
	jmp @end

@pal:
	; 50hz on PAL
	lda #<PAL_TIMER
	ldy #>PAL_TIMER

@end:
	sta $dc04
	sty $dc05

	lda #$11
	sta $dc0e
	rts
.endproc


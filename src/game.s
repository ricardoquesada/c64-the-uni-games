;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; game scene
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __SIDMUSIC_LOAD__, __MAIN_SPRITES_LOAD__

; from main.s
.import selected_rider

; from utils.s
.import clear_screen, clear_color, get_key, read_joy2

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm				; adds support for scrcode
.macpack mymacros			; my own macros

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"			; c64 constants

RASTER_TOP = 12				; first raster line
RASTER_BOTTOM = 50 + 8*3		; moving part of the screen

ACTOR_ANIMATION_SPEED = 8		; animation speed. the bigger the number, the slower it goes

.segment "GAME_CODE"

	sei

	lda #01
	jsr clear_color			; clears the screen color ram
	jsr init_screen
	jsr init_game

	lda #$00
	sta sync

	lda #01				; Enable raster irq
	sta $d01a

	ldx #<irq_top			; raster irq vector
	ldy #>irq_top
	stx $fffe
	sty $ffff

	lda #RASTER_TOP
	sta $d012

	lda $dc0d			; clear interrupts and ACK irq
	lda $dd0d
	asl $d019

	cli

@mainloop:
	lda sync
	beq @mainloop

	dec sync

	jsr read_joy2
	eor #$ff
	beq :+
	jsr process_events

:
	jsr actor_update
	jmp @mainloop

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ handler: RASTER_TOP
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_top
	pha				; saves A, X, Y
	txa
	pha
	tya
	pha

	STABILIZE_RASTER

	lda #00				; black border and background
	sta $d020			; to place the score and time
	lda #00
	sta $d021

	lda #<irq_bottom		; set a new irq vector
	sta $fffe
	lda #>irq_bottom
	sta $ffff

	lda #RASTER_BOTTOM		; should be triggered when raster = RASTER_BOTTOM
	sta $d012

	asl $d019			; ACK raster interrupt

	pla				; restores A, X, Y
	tay
	pla
	tax
	pla
	rti				; restores previous PC, status
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ handler: RASTER_BOTTOM
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_bottom
	pha				; saves A, X, Y
	txa
	pha
	tya
	pha

	STABILIZE_RASTER

	lda #$00			; black
	sta $d020			; border color
	lda #14
	sta $d021			; background color

	lda #<irq_top			; set new IRQ-raster vector
	sta $fffe
	lda #>irq_top
	sta $ffff

	lda #RASTER_TOP
	sta $d012

	inc sync

	asl $d019			; ACK raster interrupt

	pla				; restores A, X, Y
	tay
	pla
	tax
	pla
	rti				; restores previous PC, status
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_screen()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen

	lda #14
	sta $d020
	sta $d021

	ldx #$00			; screen is at $8400
@loop:
	lda #$20
	sta $8400,x
	sta $8400+$0100,x
	sta $8400+$0200,x
	sta $8400+$02e8,x
	inx
	bne @loop

	ldx #40*2-1
:	lda screen,x
	ora #$80			; using second half of the romset
	sta $8400,x
	dex
	bpl :-

	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_game()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_game
	jsr init_sprites		; setup sprites

	jsr init_actor_update_y_nothing	; no Y movement by default

	lda #0
	sta button_elapsed_time		; reset button state
	sta button_click
	sta button_prev_state

	lda #1
	sta actor_can_start_jump	; enable jumping

	ldx #00
	stx <score
	stx >score
	stx <time
	stx >time

	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_screen()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_sprites
	lda selected_rider		; in case rider 1 is selected (instead of 0)
	cmp #$01			; sprite pointer and sprite color need to be changed
	bne :+

	lda #$08			; sprite pointer 8
	sta $87f8

	lda __MAIN_SPRITES_LOAD__ + 64 * 8 + 63
	and #$0f
	sta VIC_SPR0_COLOR		; sprite #0 color

:
	lda #%00000001			; sprite #0 enabled. the rest, disabled
	sta VIC_SPR_ENA
	lda #40
	sta VIC_SPR0_X			; sprite #0 set position
	lda #204			; should be 204
	sta VIC_SPR0_Y

	lda #%00000001			; sprite #0, expand X and Y
	sta VIC_SPR_EXP_X
	sta VIC_SPR_EXP_Y

	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update
	jsr actor_animate		; do the sprite frame animation
	jsr actor_update_y		; update actor_vel_y

	clc				; calculate new pos x and y
	lda VIC_SPR0_X			; X = X + vel_x
	adc actor_vel_x
	sta VIC_SPR0_X

	sec
	lda VIC_SPR0_Y			; Y = Y - vel_y
	sbc actor_vel_y
	sta VIC_SPR0_Y
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void process_events(byte joy2_values)
;------------------------------------------------------------------------------;
; A = joy2 values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc process_events
	pha				; save A

	lda button_click		; button clicked already?
	beq :+				; nope

	inc button_elapsed_time		; 12 (or 0.2 seconds) cycles elapsed since last click ?
	lda button_elapsed_time
	cmp #12
	bmi :+				; nope

	lda #0				; yes. reset elapsed time
	sta button_elapsed_time
	lda button_click		; and do the jump
	bne @do_the_jump		; A is either 1 or 2. This is a forced jump

:
	pla				; restore A
	pha				; and push it again. needed for @next_event

	and #%00010000			; has button state changed ?
	cmp button_prev_state		; compare with previous state
	sta button_prev_state		; store the new state
	beq @next_event			; state changed? no, skip

	lda button_prev_state		; state changed. button pressed or released?
	beq @next_event			; button released, skip

	inc button_click		; button_click++
	lda button_click
	cmp #2				; double click ?
	bne @next_event			; no double-click, skip

@do_the_jump:
	jsr actor_jump			; A has number of jumps: single or double

	lda #0				; reset button values after a jump
	sta button_click
	sta button_prev_state
	sta button_elapsed_time

@next_event:
	pla				; restore A
	and #%00001100			; joy moved left or right ?
	bne @joy_moved
	jmp actor_did_not_move		; no movement


@joy_moved:				; was the joy moved to right or left?
	and #%00000100			; left ?
	beq :+
	jmp actor_move_left
:	jmp actor_move_right

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_did_not_move()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_did_not_move
	lda #0
	sta actor_vel_x			; actor vel x = 0
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_move_left()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_move_left
	lda #$ff			; actor vel x = -1
	sta actor_vel_x
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_move_right()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_move_right
	lda #1				; actor vel x = 1
	sta actor_vel_x
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_jump(byte number_of_clicks)
;------------------------------------------------------------------------------;
; A == cycles the button was pressed
; A < 20: low jump
; A >= 20: high jump
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_jump
	ldx actor_can_start_jump	; allowed to start the jump ?
	bne :+				; yes
	rts				; no, return

:
	cmp #1				; A == 1 ?
	beq @low_jump			; low jump

	cmp #2				; A == 2 ?
	beq @hi_jump			; high jump

	jmp *				; else, error

@hi_jump:
	ldx #<actor_update_y_up_hi	; high jump vector
	ldy #>actor_update_y_up_hi
	jmp :+

@low_jump:
	ldx #<actor_update_y_up_low	; low jump vector
	ldy #>actor_update_y_up_low

:
	jmp init_actor_update_y_up
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_animate()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_animate
	dec animation_delay
	beq @animate
	rts

@animate:
	lda #ACTOR_ANIMATION_SPEED
	sta animation_delay

	lda $87f8
	eor #%00000001			; new spriter pointer
	sta $87f8
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update_y()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update_y
	jmp $caca			; self-modifying code. Jump table
					; for movement Y
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_actor_update_y_nothing()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_actor_update_y_nothing
	ldx #0				; reset the jump table idx
	stx jump_table_idx
	stx actor_vel_y

	ldx #<actor_update_y_nothing	; setup the "do nothing" vector
	ldy #>actor_update_y_nothing
	stx actor_update_y+1
	sty actor_update_y+2

	inc actor_can_start_jump	; enable jumping again
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update_y_nothing()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update_y_nothing
	rts				; do nothing
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_actor_update_y_up(x: <jump vector, y: >jump vector)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_actor_update_y_up
	stx actor_update_y+1
	sty actor_update_y+2
	ldx #0				; sets up 'actor_update_y_up'
	stx jump_table_idx
	stx actor_can_start_jump	; no jump while still jumping
	rts
.endproc
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update_y_up_hi()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update_y_up_hi
	ldx jump_table_idx		; X = jump_table_idx
	cpx #JUMP_UP_HIGH_TABLE_SIZE	; end of table ?
	beq :+

	lda jump_up_high_table,x	; A = jump_table[x]
	sta actor_vel_y			; update actor vel Y
	inc jump_table_idx		; jump_table_idx++
	rts				; no, return

:	jmp init_actor_update_y_down	; yes, so setup the 'go down'
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update_y_up_low()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update_y_up_low
	ldx jump_table_idx		; X = jump_table_idx
	cpx #JUMP_UP_LOW_TABLE_SIZE	; end of table ?
	beq :+

	lda jump_up_low_table,x		; A = jump_table[x]
	sta actor_vel_y			; update actor vel Y
	inc jump_table_idx		; jump_table_idx++
	rts				; no, return

:	jmp init_actor_update_y_down	; yes, so setup the 'go down'
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_actor_update_y_down()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_actor_update_y_down
	ldx #0				; sets up up 'actor_update_y_down'
	stx jump_table_idx
	ldx #<actor_update_y_down
	ldy #>actor_update_y_down
	stx actor_update_y+1
	sty actor_update_y+2
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update_y_down()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update_y_down
	ldx jump_table_idx		; X = jump_table_idx
	cpx #JUMP_DOWN_LOW_TABLE_SIZE	; end of table ?
	beq :+		

	lda jump_down_low_table,x	; A = jump_table[x]
	sta actor_vel_y			; update actor vel Y
	inc jump_table_idx		; jump_table_idx++
	rts				; no, return

:	jmp init_actor_update_y_nothing ; yes, so setup the 'do nothing'
.endproc

sync:			.byte $00

animation_delay:	.byte ACTOR_ANIMATION_SPEED
actor_can_start_jump:	.byte $01	; whether or not actor can start a jump
button_elapsed_time:    .byte $00       ; how many cycles the button was pressed.
button_click:		.byte $00       ; holds the number of button clicks: zero, single or double
button_prev_state:	.byte $00	; last cycle button state to detect a button release / press
actor_vel_x:		.byte 0		; horizonal velocity in pixels per frame
actor_vel_y:		.byte 0		; vertical velocity in pixels per frame
score:			.word $0000
time:			.word $0000
smooth_scroll_x:	.byte $07

jump_table_idx:		.byte $00

JUMP_UP_HIGH_TABLE_SIZE = 32
jump_up_high_table:
; autogenerated table: easing_table_generator.py -s32 -m50 -aFalse -r easeInBounce:2
.byte   3,  2,  3,  1,  2,  1,  0,  1
.byte 255,  0,255,254,255,253,254,253
.byte   6,  6,  5,  5,  4,  4,  4,  4
.byte   2,  3,  2,  2,  1,  1,  1,  0

JUMP_DOWN_HIGH_TABLE_SIZE = 24
jump_down_high_table:
; autogenerated table: easing_table_generator.py -s24 -m32 -aFalse -r easeOutQuad
; reversed
.byte   0,255,  0,255,255,255,255,255
.byte 255,255,254,255,254,255,254,254
.byte 255,254,254,254,255,254,254,254

JUMP_UP_LOW_TABLE_SIZE = 20
jump_up_low_table:
; autogenerated table: easing_table_generator.py -s20 -m32 -aFalse -r easeOutQuad
.byte   2,  2,  3,  2,  2,  2,  2,  2
.byte   2,  2,  2,  1,  2,  1,  1,  1
.byte   1,  1,  1,  0

JUMP_DOWN_LOW_TABLE_SIZE = 20
jump_down_low_table:
; autogenerated table: easing_table_generator.py -s20 -m32 -aFalse -r easeOutQuad
; reversed
.byte   0,255,255,255,255,255,255,254
.byte 255,254,254,254,254,254,254,254
.byte 254,253,254,254

screen:
		;0123456789|123456789|123456789|123456789|
	scrcode " score                             time "
	scrcode " 00000                              90  "

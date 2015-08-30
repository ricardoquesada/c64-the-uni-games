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

ACTOR_MODE_JUMP = 0			; Actor modes: riding, jumping, etc.
ACTOR_MODE_RIDE = 1

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
	jsr init_sprites

	lda #ACTOR_MODE_RIDE
	sta actor_mode

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
	lda #204
	sta VIC_SPR0_Y

	lda #%00000001			; sprite #0, expand X and Y
	sta VIC_SPR_EXP_X
	sta VIC_SPR_EXP_Y

	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update
	jsr actor_animate		; do the sprite frame animation

	clc				; calculate new pos x and y
	lda VIC_SPR0_X			; based on sprite velocity
	adc actor_vel_x
	sta VIC_SPR0_X
	clc
	lda VIC_SPR0_Y
	adc actor_vel_y
	sta VIC_SPR0_Y
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void process_events(int)
;------------------------------------------------------------------------------;
; A = joy2 values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc process_events
	pha				; save A
	and #%00010000			; button pressed ?
	beq :+

	jsr actor_jump

:	pla				; restore A 
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
; void actor_did_not_move
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_did_not_move
	lda #0
	sta actor_vel_x			; actor vel x = 0
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_move_left
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_move_left
	lda #$ff			; actor vel x = -1
	sta actor_vel_x	
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_move_right
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_move_right
	lda #1				; actor vel x = 1
	sta actor_vel_x
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_jump
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_jump
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_animate
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

sync:			.byte $00

animation_delay:	.byte ACTOR_ANIMATION_SPEED
actor_mode:		.byte ACTOR_MODE_RIDE
actor_vel_x:		.byte 0		; horizonal velocity in pixels per frame
actor_vel_y:		.byte 0		; vertical velocity in pixels per frame
score:			.word $0000
time:			.word $0000
smooth_scroll_x:	.byte $07

screen:
		;0123456789|123456789|123456789|123456789|
	scrcode " score                             time "
	scrcode " 00000                              90  "

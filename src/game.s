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

DEBUG = 3				; bitwise: 1=raster-sync code. 2=asserts

RASTER_TOP = 12				; first raster line
RASTER_BOTTOM = 50 + 8*3		; moving part of the screen

ACTOR_ANIMATION_SPEED = 8		; animation speed. the bigger the number, the slower it goes
GROUND_Y = 200				; max Y position for actor
JUMP_TIME_LIMIT = 11			; max cycles that jump can be pressed
ACTOR_JUMP_IMPULSE = 3			; higher the number, higher the initial jump

.segment "GAME_CODE"

	sei


	lda #01
	jsr clear_color			; clears the screen color ram
	jsr init_screen
	jsr init_game

	lda #$00
	sta sync

	lda #$7f			; turn off cia interrups
	sta $dc0d
	sta $dd0d

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
:	lda sync
	beq :-

.if (DEBUG & 1)
	dec $d020
.endif

	dec sync

	jsr read_joy2
	eor #$ff			; invert joy2 value
	jsr process_events		; call process events, even if no event is generated

	jsr actor_update		; update main actor

	jsr render_sprites		; render sprites

.if (DEBUG & 1)
	inc $d020
.endif
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

	asl $d019			; ACK raster interrupt

	inc sync

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

	ldx #40*2-1			; 2 lines only
:	lda screen,x
	ora #$80			; using second half of the romset
	sta $8400,x
	dex
	bpl :-

	ldx #40*6-1			; 6 lines only
:	lda terrain,x
	ora #$80			; using second half of the romset
	sta $8400+19*40,x		; start from the line 19
	dex
	cpx #$ff
	bne :-

	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_game()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_game
	jsr init_sprites		; setup sprites

	jsr init_actor_update_y_down	; by default go down

	ldx #0
	stx button_elapsed_time		; reset button state
	stx button_released		; enable "high jumping"

	inx
	stx actor_can_start_jump	; enable jumping

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
	lda #%00000001			; sprite #0, expand X and Y
	sta VIC_SPR_EXP_X
	sta VIC_SPR_EXP_Y

	lda #40
	sta sprites_x+0			; sprite #0 set position
	lda #GROUND_Y-30
	sta sprites_y+0

	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update
	jsr actor_animate		; do the sprite frame animation
	jsr actor_update_y		; update actor_vel_y

	clc
	lda sprites_x+0			; X = X + vel_x
	adc actor_vel_x
	sta sprites_x+0

	php				; save carry
	lda actor_vel_x			; velocity was negative ?
	bmi @negative_vel		; yes, so test carry according to that

	plp				; restore carry
	bcc @update_y			; velocity was positive. if carry clear no changes
	bcs @toggle_8_bit		; if carry set, toggle 8 bit

@negative_vel:
	plp				; restore carry
	bcs @update_y			; if carry set on negative vel, no changes

@toggle_8_bit:	
	lda sprites_msb+0		; toggle sprite.x 8 bit
	eor #%00000001
	sta sprites_msb+0

@update_y:
	sec
	lda sprites_y+0			; Y = Y - vel_y
	sbc actor_vel_y
	sta sprites_y+0 
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void render_sprites()
;------------------------------------------------------------------------------;
; code taken from here: http://codebase64.org/doku.php?id=base:moving_sprites
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc render_sprites
	ldx #$07
	ldy #$0e
		
@loop:	lda sprites_y,x
	sta VIC_SPR0_Y,y		; write y
	lda sprites_x,x
	sta VIC_SPR0_X,y		; write x
	lda sprites_msb,x
	cmp #$01			; no msb=carry clear  / msb=carry set
	rol VIC_SPR_HI_X		; carry -> $d010, repeat 8 times and all bits are set
		
	dey
	dey
	dex
	bpl @loop
	rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void process_events(byte joy2_values)
;------------------------------------------------------------------------------;
; A = joy2 values
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

.proc process_events
	pha				; save A

	and #%00010000			; button clicked ?
	beq @no_button			; nope

	lda button_released		; was the button released when already in the air ?
	bne @next_event			; yes?... so no more jumping


	lda button_elapsed_time		; button_elapsed_time < JUMP_TIME_LIMIT ?
	cmp #JUMP_TIME_LIMIT		; needed to jump higher
	bpl @next_event			; nope

	inc button_elapsed_time		; reached max time that actor can jump ?
	lda #ACTOR_JUMP_IMPULSE		; while button is pressed 
	sta actor_vel_y			; velocity.y = ACTOR_JUMP_IMPULSE
					; the longer the button is pressed, the higher it jumps
	jsr actor_jump
	jmp @next_event	

@no_button:
	lda actor_can_start_jump	; if actor is on the air
	bne @next_event			; and button is not pressed
	lda #1				; then button cannot be pressed again
	sta button_released

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
; void actor_jump(void)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_jump
	ldx actor_can_start_jump	; allowed to start the jump ?
	beq :+				; no

	ldx #<actor_update_y_up		; yes, can jump
	ldy #>actor_update_y_up		; setup update vector
	stx actor_update_y+1
	sty actor_update_y+2
	ldx #0
	stx actor_can_start_jump	; no more jumping while in air

:	rts
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
; void actor_update_y_up()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update_y_up
	dec @counter
	beq :+
	rts

:	lda #$05
	sta @counter
	dec actor_vel_y
	beq :+
	rts

:	jmp init_actor_update_y_down	; yes, so setup the 'go down'

@counter:
	.byte $05

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_actor_update_y_down()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_actor_update_y_down
	ldx #0				; sets up up 'actor_update_y_down'
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
	jsr check_collision_floor	; touching floor ?
	bcs @stop_falling		; if so, stop falling

	dec @counter			; counter == 0?
	bne :+				; no ?
 
	lda #$05			; counter = 5
	sta @counter			; actor_vel_y++
	dec actor_vel_y			; increase velocity as the actor keeps falling 
:	rts

@stop_falling:
	ldx #0
	stx button_elapsed_time
	stx actor_vel_y			; no vertical movement
	stx button_released		; button_released = 0
	inx
	stx actor_can_start_jump	; actor_can_start_jump = 1

	lda sprites_y
	and #%11111000
	sta sprites_y

	rts

@counter:
	.byte $05
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void check_collision_floor()
;------------------------------------------------------------------------------;
; returns Carry Set on collision
;         Carry clear on no collision
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc check_collision_floor

	ldx #<$8400			; restore screen base value
	ldy #>$8400
	stx @screen_base
	sty @screen_base+1

	lda sprites_msb+0		; C = 1 only if 8th bit is on
	sec
	bne :+				; bit on ? then Carry Set
	clc				; if not, Clear Carry

:	lda sprites_x+0			; convert pixels coords to chars coords
	ror				; x = actor.x / 8 taking into account 8th bit
	lsr
	lsr

	clc
	adc @screen_base		; screen_base = screen_base + x
	sta @screen_base
	bcc :+
	inc @screen_base+1


:	lda sprites_y+0			; convert pixels coords to chars coords
	lsr				; y = actor.y / 8
	lsr
	lsr
	tay

;	dey
	dey				; since sprite coordinates start before screen, we need to compesate

	tya 
	jsr mult40			; ret = A * 40.  ret is a 16-bit stored in LSB=X, MSB=Y

	txa				; LSB: screen_base = ret + screenbase
	clc
	adc @screen_base
	sta @screen_base
	bcc :+
	inc @screen_base+1

:
	tya				; MSB: screen_base = ret + screenbase
	clc
	adc @screen_base+1
	sta @screen_base+1

.if (::DEBUG & 2)
	bcc :+
	jmp *				; should not happen
:
.endif


@screen_base = *+1
	lda $8400			; self-modifying value
	tax
	cmp #$20			; space?
	clc				; by default no collision
	beq @end

	sec

	cmp #$a0
	clc
	beq @end
	sec

@end:
	rts

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void mult40(byte number_to_be_multiplied)
;------------------------------------------------------------------------------;
; A = number to be multiplied by 40 (A is value between 0 and 24)
; X = result LSB 
; Y = result MSB
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc mult40
	cmp #25				; if A >= 24, then A = 24
	bmi :+
	lda #24
:
	tax				; r = y * 32 + y * 8, but looking up the result
	lda @mult_40_lo,x		; in table is faster
	ldy @mult_40_hi,x
	tax
	rts

; autogenerated table: mult_table_generator.py -f0 -t24 -2 40
; LSB values
@mult_40_lo:
.byte <$0000,<$0028,<$0050,<$0078,<$00a0,<$00c8,<$00f0,<$0118
.byte <$0140,<$0168,<$0190,<$01b8,<$01e0,<$0208,<$0230,<$0258
.byte <$0280,<$02a8,<$02d0,<$02f8,<$0320,<$0348,<$0370,<$0398
; MSB values
@mult_40_hi:
.byte >$0000,>$0028,>$0050,>$0078,>$00a0,>$00c8,>$00f0,>$0118
.byte >$0140,>$0168,>$0190,>$01b8,>$01e0,>$0208,>$0230,>$0258
.byte >$0280,>$02a8,>$02d0,>$02f8,>$0320,>$0348,>$0370,>$0398

.endproc


sync:			.byte $00

animation_delay:	.byte ACTOR_ANIMATION_SPEED
actor_can_start_jump:	.byte $01	; boolean. whether or not actor can start a jump
button_elapsed_time:    .byte $00       ; how many cycles the button was pressed.
actor_vel_x:		.byte 0		; horizonal velocity in pixels per frame
actor_vel_y:		.byte 0		; vertical velocity in pixels per frame
button_released:	.byte 0		; boolean. whether or not the button was released while in the air
score:			.word $0000
time:			.word $0000
smooth_scroll_x:	.byte $07

screen:
		;0123456789|123456789|123456789|123456789|
	scrcode " score                             time "
	scrcode " 00000                              90  "

terrain:
		;0123456789|123456789|123456789|123456789|
	scrcode "                          aaaaaaaa      "
	scrcode "                      aaaaaaaaaaaaaa    "
	scrcode "                  aaaaaaaaaaaaaaaaaaaa  "
	scrcode "                aaaaaaaaaaaaaaaaaaaaaaaa"
	scrcode "aaaa   aa   aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	scrcode "aaaa   aa   aaaaaaaaaaaaaaaaaaaaaaaaaaaa"


; global sprite values
sprites_y:	.byte $00, $00, $00, $00, $00, $00, $00, $00
sprites_x:	.byte $00, $00, $00, $00, $00, $00, $00, $00
sprites_msb:	.byte $00, $00, $00, $00, $00, $00, $00, $00


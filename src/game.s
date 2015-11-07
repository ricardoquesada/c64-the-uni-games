;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; game scene
;
; Zero Page global registers:
;   $f9/$fa -> modified temporary in collision detection.
;               can be altered by other tmp functions
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __SIDMUSIC_LOAD__, __MAIN_SPRITES_LOAD__

; from main.s
.import selected_rider

; from utils.s
.import ut_clear_screen, ut_clear_color, ut_get_key, ut_read_joy2, ut_setup_tod

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode
.macpack mymacros                       ; my own macros

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants

DEBUG = 7                               ; bitwise: 1=raster-sync code. 2=asserts. 4=colllision detection

RASTER_TOP = 50 + 8 * 25                ; first raster line
RASTER_BOTTOM = 50 + 8 * 3              ; moving part of the screen

ACTOR_ANIMATION_SPEED = 8               ; animation speed. the bigger the number, the slower it goes
GROUND_Y = 200                          ; max Y position for actor
JUMP_TIME_LIMIT = 11                    ; max cycles that jump can be pressed
ACTOR_JUMP_IMPULSE = 3                  ; higher the number, higher the initial jump
SCROLL_SPEED = 1                        ; scroll speed. higher numbers, faster

.segment "GAME_CODE"

        sei

        lda #01
        jsr ut_clear_color              ; clears the screen color ram
        jsr init_screen
        jsr init_game

        jsr ut_setup_tod                ; must be called AFTER detect_pal_...
        lda #0
        sta $dc0b                       ; Set TOD-Clock to 0 (hours)
        sta $dc0a                       ;- (minutes)
        sta $dc09                       ;- (seconds)
        sta $dc08                       ;- (deciseconds)

        lda #$00
        sta sync

        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda #01                         ; Enable raster irq
        sta $d01a

        ldx #<irq_top                   ; raster irq vector
        ldy #>irq_top
        stx $fffe
        sty $ffff

        lda #RASTER_TOP
        sta $d012

        lda $dc0d                       ; clear interrupts and ACK irq
        lda $dd0d
        asl $d019

        cli

@mainloop:
:       lda sync
        beq :-

.if (DEBUG & 1)
        dec $d020
.endif

        dec sync

        jsr update_time                 ; updates playing time
        jsr update_scroll               ; screen horizontal scroll

        jsr ut_read_joy2
        eor #$ff                        ; invert joy2 value
        jsr process_events              ; call process events, even if no event is generated

        jsr update_actor                ; update main actor
        jsr render_sprites              ; render sprites

.if (DEBUG & 1)
        inc $d020
.endif
        jmp @mainloop

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ handler: RASTER_TOP
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_top
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        STABILIZE_RASTER

        lda #%00001000                  ; no scroll,single-color,40-cols
        sta $d016

        lda #00                         ; black border and background
        sta $d020                       ; to place the score and time
        lda #00
        sta $d021

        lda #<irq_bottom                ; set a new irq vector
        sta $fffe
        lda #>irq_bottom
        sta $ffff

        lda #RASTER_BOTTOM              ; should be triggered when raster = RASTER_BOTTOM
        sta $d012

        asl $d019                       ; ACK raster interrupt

        inc sync

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ handler: RASTER_BOTTOM
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_bottom
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        STABILIZE_RASTER

        lda smooth_scroll_x             ; scroll x
        sta $d016

        lda #$00                        ; black
        sta $d020                       ; border color
        lda #14
        sta $d021                       ; background color

        lda #<irq_top                   ; set new IRQ-raster vector
        sta $fffe
        lda #>irq_top
        sta $ffff

        lda #RASTER_TOP
        sta $d012

        asl $d019                       ; ACK raster interrupt

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_screen()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen

        lda #14
        sta $d020
        sta $d021

        ldx #$00                        ; screen is at $8400
@loop:
        lda #$20
        sta $8400,x
        sta $8400+$0100,x
        sta $8400+$0200,x
        sta $8400+$02e8,x
        inx
        bne @loop

        ldx #40*2-1                     ; 2 lines only
:       lda screen,x
        ora #$80                        ; using second half of the romset
        sta $8400,x
        dex
        bpl :-

        ldx #40*6-1                     ; 6 lines only
:       lda terrain,x
        ora #$80                        ; using second half of the romset
        sta $8400+19*40,x               ; start from the line 19
        dex
        cpx #$ff
        bne :-

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_game()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_game
        jsr init_sprites                ; setup sprites

        ldx #0
        stx button_elapsed_time         ; reset button state
        stx button_released             ; enable "high jumping"

        inx
        stx actor_can_start_jump        ; enable jumping

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
        lda selected_rider              ; in case rider 1 is selected (instead of 0)
        cmp #$01                        ; sprite pointer and sprite color need to be changed
        bne :+

        lda #$08                        ; sprite pointer 8
        sta $87f8

        lda __MAIN_SPRITES_LOAD__ + 64 * 8 + 63
        and #$0f
        sta VIC_SPR0_COLOR              ; sprite #0 color

:
        lda #%00000001                  ; sprite #0 enabled. the rest, disabled
        sta VIC_SPR_ENA
        lda #%00000001                  ; sprite #0, expand X and Y
        sta VIC_SPR_EXP_X
        sta VIC_SPR_EXP_Y

        lda #40
        sta sprites_x+0                 ; sprite #0 set position
        lda #GROUND_Y-30
        sta sprites_y+0

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_actor()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_actor
        jsr actor_animate               ; do the sprite frame animation
        jsr actor_update_y              ; update actor_vel_y
        jsr actor_update_pos            ; updates actor position based on vel_x and vel_y

        jsr check_collision_detection   ; check collision

        pha                             ; saves A, the collision bits
        and #%00000010                  ; bottom ?
        beq :+                          ; no, next test
        jsr _bottom_collision

:       pla                             ; restores, saves A
        pha
        and #%00001000                  ; right ?
        beq :+                          ; no, next test
        jsr _right_collision

:       pla                             ; restores, saves A
        pha
        and #%00000100                  ; left ?
        beq :+                          ; no, next test
        jsr _left_collision

:       pla                             ; restores A
        and #%00000001                  ; top ?
        beq :+                          ; no, next test
        jmp _top_collision

:       rts


_top_collision:
        rts                             ; FIXME: not implemented

_bottom_collision:
        lda sprites_y+0
;        clc
;        adc actor_vel_y
        and #%11111000
        sta sprites_y+0                 ; go up

        ldx #0                          ; if bottom collision, stop falling
        stx button_elapsed_time
        stx actor_vel_y                 ; no vertical movement
        stx button_released             ; button_released = 0
        inx
        stx actor_can_start_jump        ; actor_can_start_jump = 1

        rts

_right_collision:
        clc
        lda scroll_speed                ; scroll speed
        adc actor_vel_x                 ;
        sta _total_vel_r                ; total speed = scroll speed + actor_x speed

        sec
        lda sprites_x+0
_total_vel_r = * + 1
        sbc #$00                        ; self modifying code. scroll velocity + actor vel x
        sta sprites_x+0
        bcs :+
        lda #0
        sta sprites_msb+0
:       rts

_left_collision:
        clc
        lda actor_vel_x
        eor #$ff                        ; actor_vel_x = -actor_vel-x
        adc scroll_speed
        sta _total_vel_l

        clc
        lda sprites_x+0
_total_vel_l = * + 1
        adc #$00                        ; self modifying code. scroll velocity + actor_vel_x
        sta sprites_x+0
        bcc :+
        lda #1
        sta sprites_msb+0
:       rts

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_scroll()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_scroll
SCROLL_SPEED = 1

        sec
        lda smooth_scroll_x
        sbc scroll_speed
        and #%00000111
        sta smooth_scroll_x
        bcc :+
        rts
:
        lda #07
        sta smooth_scroll_x

        .repeat 8,i
                lda $8400+40*(17+i)
                sta $8400+40*(17+i)+39
        .endrepeat

        ldx #0                          ; move the chars to the left and right
@loop:
        .repeat 8,i
                lda $8400+40*(17+i)+1,x
                sta $8400+40*(17+i)+0,x
        .endrepeat

        inx
        cpx #39
        bne @loop

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; update_time
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_time

        lda $dc09                       ; seconds. digit
        tax
        and #%00001111
        ora #($80 + $30)
        sta $8400 + 40 * 01 + 38

        txa                             ; seconds. Ten digit
        lsr
        lsr
        lsr
        lsr
        ora #($80 + $30)
        sta $8400 + 40 * 01 + 37

        lda $dc0a                       ; minutes. digit
        and #%00001111
        ora #$b0
        sta $8400 + 40 * 01 + 35

        rts

@temp: .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void render_sprites()
;------------------------------------------------------------------------------;
; code taken from here: http://codebase64.org/doku.php?id=base:moving_sprites
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc render_sprites
        ldx #$07
        ldy #$0e

@loop:  lda sprites_y,x
        sta VIC_SPR0_Y,y                ; write y
        lda sprites_x,x
        sta VIC_SPR0_X,y                ; write x
        lda sprites_msb,x
        cmp #$01                        ; no msb=carry clear  / msb=carry set
        rol VIC_SPR_HI_X                ; carry -> $d010, repeat 8 times and all bits are set

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
        pha                             ; save A

        and #%00010000                  ; button clicked ?
        beq @no_button                  ; nope

        lda button_released             ; was the button released when already in the air ?
        bne @next_event                 ; yes?... so no more jumping


        lda button_elapsed_time         ; button_elapsed_time < JUMP_TIME_LIMIT ?
        cmp #JUMP_TIME_LIMIT            ; needed to jump higher
        bpl @next_event                 ; nope

        inc button_elapsed_time         ; reached max time that actor can jump ?
        lda #ACTOR_JUMP_IMPULSE         ; while button is pressed 
        sta actor_vel_y                 ; velocity.y = ACTOR_JUMP_IMPULSE
                                        ; the longer the button is pressed, the higher it jumps
        jsr actor_jump
        jmp @next_event 

@no_button:
        lda actor_can_start_jump        ; if actor is on the air
        bne @next_event                 ; and button is not pressed
        lda #1                          ; then button cannot be pressed again
        sta button_released

@next_event:
        pla                             ; restore A
        and #%00001100                  ; joy moved left or right ?
        bne @joy_moved
        jmp actor_did_not_move          ; no movement


@joy_moved:                             ; was the joy moved to right or left?
        and #%00000100                  ; left ?
        beq :+
        jmp actor_move_left
:       jmp actor_move_right
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_did_not_move()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_did_not_move
        lda #0
        sta actor_vel_x                 ; actor vel x = 0
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_move_left()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_move_left
        lda #$ff                        ; actor vel x = -1
        sta actor_vel_x
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_move_right()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_move_right
        lda #1                          ; actor vel x = 1
        sta actor_vel_x
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_jump(void)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_jump
        ldx actor_can_start_jump        ; allowed to start the jump ?
        beq :+                          ; no

        ldx #0
        stx actor_can_start_jump        ; no more jumping while in air

:       rts
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
        eor #%00000001                  ; new spriter pointer
        sta $87f8
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update_pos()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update_pos
        clc
        lda sprites_x+0                 ; X = X + vel_x
        adc actor_vel_x
        sta sprites_x+0

        php                             ; save carry
        lda actor_vel_x                 ; velocity was negative ?
        bmi @negative_vel               ; yes, so test carry according to that

        plp                             ; restore carry
        bcc @update_y                   ; velocity was positive. if carry clear no changes
        bcs @toggle_8_bit               ; if carry set, toggle 8 bit

@negative_vel:
        plp                             ; restore carry
        bcs @update_y                   ; if carry set on negative vel, no changes

@toggle_8_bit:  
        lda sprites_msb+0               ; toggle sprite.x 8 bit
        eor #%00000001
        sta sprites_msb+0

@update_y:
        sec
        lda sprites_y+0                 ; Y = Y - vel_y
        sbc actor_vel_y
        sta sprites_y+0 
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void actor_update_y()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc actor_update_y
        dec @counter
        bne :+

        lda #$05
        sta @counter

        dec actor_vel_y

:       rts

@counter:
        .byte $05

.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void check_collision_detection()
;------------------------------------------------------------------------------;
; returns A:
;       Bit 0=ON if Top collision
;       Bit 1=ON if Down collision
;       Bit 2=ON if Left collision
;       Bit 3=ON if Right collision
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc check_collision_detection

        lda #0
        sta @ret_value                  ; reset return value

        ldx #<$8400                     ; restore screen base value
        ldy #>$8400
        stx $f9                         ; zero page register ($f9) -> $8400
        sty $fa

:       lda sprites_y+0                 ; FIRST: y = actor.y / 8
        lsr                             ; convert pixels coords to chars coords
        lsr
        lsr
        tay

;       dey
        dey                             ; since sprite coordinates start before screen, we need to compesate

        tya
        jsr mult40                      ; ret = A * 40.  ret is a 16-bit stored in LSB=X, MSB=Y

        clc
        txa                             ; LSB: screen_base = ret + screenbase
        adc $f9
        sta $f9
        tya                             ; MSB: screen_base = ret + screenbase
        adc $fa
        sta $fa

.if (::DEBUG & 2)
        bcc :+
        jmp *                           ; should not happen
:
.endif

        lda sprites_x+0                 ; SECOND: x = actor.x / 8
        sec
        sbc smooth_scroll_x             ; take into account x scroll position
        ldx sprites_msb+0
        cpx #01                         ; C=On if MSB is On. Needed for 'ror'
        ror                             ; x = actor.x / 8 taking into account 8th bit
        lsr
        lsr
        tay                             ; put value in Y and use it ($f9),y


        ldx #0
@check_bottom_collision:
        lda ($f9),y                     ; $f9/$fa points to screen position.

        cmp #$20                        ; space?
        beq :+                          ; no collision then

        cmp #$a0                        ; another kind of space?
        beq :+                          ; no collision then

        lda @ret_value                  ; if not space, then
        ora #%00000010                  ; turn on bottom collision bit
        sta @ret_value

:
        iny                             ; Y++, used in ($f9),y
        inx
        cpx #2                          ; do the test in 2 bytes        
        bne @check_bottom_collision



@start_right_collision:
        dey
        sec                             ; setup for right collision
        lda $f9                         ; ($f9),y -= 40
        sbc #40
        sta $f9
        lda $fa
        sbc #00
        sta $fa


        lda ($f9),y                     ; $f9/$fa points to screen position.

        cmp #$20                        ; space?
        beq @start_left_collision       ; no collision then

        cmp #$a0                        ; another kind of space?
        beq @start_left_collision       ; no collision then

        lda @ret_value                  ; if not space, then
        ora #%00001000                  ; turn on right collision bit
        sta @ret_value


@start_left_collision:
        dey
        dey
        lda ($f9),y                     ; $f9/$fa points to screen position.

        cmp #$20                        ; space?
        beq @end                        ; no collision then

        cmp #$a0                        ; another kind of space?
        beq @end                        ; no collision then

        lda @ret_value                  ; if not space, then
        ora #%00000100                  ; turn on left collision bit
        sta @ret_value

;       lda ($f9),y
;       tax
;       inx
;       txa
;       sta ($f9),y

@end:

.if (::DEBUG & 4)
        ldx #3                          ; print 4 bits of the coll detection                 
        lda @ret_value                  
:       ror
        pha
        ldy #($80 + $30)                ; '0'
        bcc :+
        iny                             ; '1'
:       tya
        sta $8400 + 20,x
        pla 
        dex
        bpl :--
.endif

        lda @ret_value                  ; load return value
        rts

@ret_value:     .byte $00

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void mult40(byte number_to_be_multiplied)
;------------------------------------------------------------------------------;
; A = number to be multiplied by 40 (A is value between 0 and 24)
; X = result LSB 
; Y = result MSB
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc mult40
        cmp #25                         ; if A >= 24, then A = 24
        bmi :+
        lda #24
:
        tax                             ; r = y * 32 + y * 8, but looking up the result
        lda @mult_40_lo,x               ; in table is faster
        ldy @mult_40_hi,x
        tax
        rts

; autogenerated table: mult_table_generator.py -f0 -t24 -2 40
; LSB values
@mult_40_lo:
.byte <$0000,<$0028,<$0050,<$0078,<$00a0,<$00c8,<$00f0,<$0118
.byte <$0140,<$0168,<$0190,<$01b8,<$01e0,<$0208,<$0230,<$0258
.byte <$0280,<$02a8,<$02d0,<$02f8,<$0320,<$0348,<$0370,<$0398
.byte <$03c0
; MSB values
@mult_40_hi:
.byte >$0000,>$0028,>$0050,>$0078,>$00a0,>$00c8,>$00f0,>$0118
.byte >$0140,>$0168,>$0190,>$01b8,>$01e0,>$0208,>$0230,>$0258
.byte >$0280,>$02a8,>$02d0,>$02f8,>$0320,>$0348,>$0370,>$0398
.byte >$03c0

.endproc


sync:                   .byte $00

animation_delay:        .byte ACTOR_ANIMATION_SPEED
actor_can_start_jump:   .byte $01       ; boolean. whether or not actor can start a jump
button_elapsed_time:    .byte $00       ; how many cycles the button was pressed.
actor_vel_x:            .byte 0         ; horizonal velocity in pixels per frame
actor_vel_y:            .byte 0         ; vertical velocity in pixels per frame
button_released:        .byte 0         ; boolean. whether or not the button was released while in the air
score:                  .word $0000
time:                   .word $0000
smooth_scroll_x:        .byte $05
scroll_speed:           .byte SCROLL_SPEED

screen:
                ;0123456789|123456789|123456789|123456789|
        scrcode " score                             time "
        scrcode " 00000                             0:00 "

terrain:
                ;0123456789|123456789|123456789|123456789|
        scrcode "                          aaaaaaaaaa    "
        scrcode "                      aaaaaaaaaaaaaa    "
        scrcode "                  aaaaaaaaaaaaaaaaaaaa  "
        scrcode "                aaaaaaaaaaaaaaaaaaaaaaaa"
        scrcode "       a    aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        scrcode "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


; global sprite values
sprites_y:      .byte $00, $00, $00, $00, $00, $00, $00, $00
sprites_x:      .byte $00, $00, $00, $00, $00, $00, $00, $00
sprites_msb:    .byte $00, $00, $00, $00, $00, $00, $00, $00


; last well known position without collision
no_col_pos_x:   .byte $00
no_col_pos_y:   .byte $00
no_col_pos_msb: .byte $00



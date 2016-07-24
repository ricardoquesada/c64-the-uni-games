;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; Instructions file
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

.import ut_clear_color, ut_get_key, ut_clear_screen
.import menu_read_events
; from main.s
.import sync_timer_irq
.import menu_read_events
.import mainscreen_colors

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
.include "myconstants.inc"


.segment "HI_CODE"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void instructions_init()
;------------------------------------------------------------------------------;
.export instructions_init
.proc instructions_init

        lda #%00011000                  ; sprites 3 and 4
        sta VIC_SPR_ENA                 ; since they are the onces used in main
        lda #%00010000                  ; set sprite #7 x-pos 9-bit ON
        sta VIC_SPR_HI_X                ; since x pos > 255

        ldx #0                          ; setup maks sprites
        ldy #0                          ; for the Ns in INSTRUCTIONS
l0:     lda sprite_x,x
        sta VIC_SPR3_X,y                ; setup sprite X
        lda sprite_y,x
        sta VIC_SPR3_Y,y                ; setup sprite Y
        lda sprite_color,x
        sta VIC_SPR3_COLOR,x            ; setup sprite color
        lda sprite_frame,x
        sta SPRITES_PTR0 + 3,x              ; setup sprite pointer
        inx
        iny
        iny
        cpx #2
        bne l0


        ldx #0
l1:
        lda instructions_map + $0000,x
        sta SCREEN0_BASE + $0000,x
        tay
        lda mainscreen_colors,y
        sta $d800 + $0000,x

        lda instructions_map + $0100,x
        sta SCREEN0_BASE + $0100,x
        tay
        lda mainscreen_colors,y
        sta $d800 + $0100,x

        lda instructions_map + $0200,x
        sta SCREEN0_BASE + $0200,x
        tay
        lda mainscreen_colors,y
        sta $d800 + $0200,x

        lda instructions_map + $02e8,x
        sta SCREEN0_BASE + $02e8,x
        tay
        lda mainscreen_colors,y
        sta $d800 + $02e8,x

        inx
        bne l1


loop:
        lda sync_timer_irq
        bne play_music

        jsr menu_read_events
        cmp #%00010000                  ; space or button
        bne loop
        rts                             ; return to caller (main menu)
play_music:
        dec sync_timer_irq
        jsr $1003
        jmp loop

        ; maks sprites
sprite_x:
        .byte 48,288-256
sprite_y:
        .byte 74,74
sprite_color:
        .byte 11,11
sprite_frame:
        .byte SPRITES_POINTER + 46      ; mask for N
        .byte SPRITES_POINTER + 46      ; mask for N

.endproc

instructions_map:
        .incbin "instructions-map.bin"
        .byte 0                                 ; ignore

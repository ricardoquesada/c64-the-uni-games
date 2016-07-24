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
.endproc

instructions_map:
        .incbin "instructions-map.bin"
        .byte 0                                 ; ignore

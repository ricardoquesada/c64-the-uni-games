;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; Select event screen
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

.import decrunch                                ; exomizer decrunch
.import _crunched_byte_hi, _crunched_byte_lo    ; from utils
.import sync_timer_irq
.import ut_clear_color, ut_get_key
.import game_start_cyclocross, game_start_roadrace
.import menu_handle_events, menu_invert_row

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
; select_event_init
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export selectevent_init
.proc selectevent_init
        sei

        ldx #<selectevent_map
        ldy #>selectevent_map
        stx _crunched_byte_lo
        sty _crunched_byte_hi

        dec $01                                 ; $34: RAM 100%

        jsr decrunch                            ; uncrunch map

        inc $01                                 ; $35: RAM + IO ($D000-$DF00)
        cli

        lda #2                                  ; setup the global variables
        sta MENU_MAX_ITEMS                      ; needed for the menu code
        lda #0
        sta MENU_CURRENT_ITEM
        lda #30
        sta MENU_ITEM_LEN
        lda #(40*2)
        sta MENU_BYTES_BETWEEN_ITEMS
        ldx #<(SCREEN0_BASE + 40 * 19 + 5)
        ldy #>(SCREEN0_BASE + 40 * 19 + 5)
        stx MENU_CURRENT_ROW_ADDR
        sty MENU_CURRENT_ROW_ADDR+1
        ldx #<selectevent_exec
        ldy #>selectevent_exec
        stx MENU_EXEC_ADDR
        sty MENU_EXEC_ADDR+1
        jmp menu_invert_row
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; selectevent_exec
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc selectevent_exec
        lda MENU_CURRENT_ITEM
        bne :+
        jmp game_start_roadrace
:       jmp game_start_cyclocross
.endproc


.segment "COMPRESSED_DATA"
; select_event-map.prg.exo: should be exported to $0680
.incbin "select_event-map.prg.exo"
selectevent_map:
        .byte 0                         ; ignore

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
.import game_start, game_selected_event, game_number_of_players
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
;
; select event
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; select_event_init
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export selectevent_init
.proc selectevent_init

        ldx #0
l0:
        lda selectevent_map,x                   ; copy 8 * 40 chars in total
        sta SCREEN0_BASE + 40 * 16,x

        lda selectevent_map + 64,x              ; 320 - 256 = 64
        sta SCREEN0_BASE + 40 * 16 + 64,x 

        inx
        bne l0

;        lda #1                                  ; white color last $d800 row
;        ldx #39
;l1:     sta $d800 + 24 * 40,x
;        dex
;        bpl l1


        lda #3                                  ; setup the global variables
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
        sta game_selected_event
        jmp number_of_players_init
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; number of players
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; number_of_players_init
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc number_of_players_init

        ldx #0
l0:
        lda number_of_players_map,x             ; copy 8 * 40 chars in total
        sta SCREEN0_BASE + 40 * 16,x

        lda number_of_players_map+ 64,x         ; 320 - 256 = 64
        sta SCREEN0_BASE + 40 * 16 + 64,x

        inx
        bne l0


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
        ldx #<number_of_players_exec
        ldy #>number_of_players_exec
        stx MENU_EXEC_ADDR
        sty MENU_EXEC_ADDR+1
        jmp menu_invert_row
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; number_of_players_exec
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc number_of_players_exec
        ldx #$ff                                ; reset stack
        txs                                     ; since after 128 cycles
                                                ; it will overflow the stack
                                                ; probably a "pla, pla" will fix it
        lda MENU_CURRENT_ITEM
        sta game_number_of_players
        jmp game_start
.endproc


selectevent_map:
        .incbin "select_event-map.bin"
number_of_players_map:
        .incbin "number_of_players-map.bin"

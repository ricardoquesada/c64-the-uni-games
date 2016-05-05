;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; menu handling code
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
.include "myconstants.inc"

.segment "MENU_CODE"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void menu_handle_events()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export menu_handle_events
.proc menu_handle_events
        lda $dc00
        cmp last_joy_value              ; execute if joy != last vale
        bne do_joy 
        dec delay                       ; if same value, wait "delay"
        beq update_delay                ; until executing the joy
        rts


do_joy:
        sta last_joy_value

update_delay:
        ldx #$10
        stx delay

        eor #%11111111
        and #%00011111
        cmp #%00000001                  ; up ?
        beq go_prev
        cmp #%00000100                  ; left ?
        beq go_prev
        cmp #%00000010                  ; down ?
        beq go_next
        cmp #%00001000                  ; right ?
        beq go_next
        and #%00010000                  ; fire pressed ?
        bne go_fire
        rts
go_prev:
        jmp menu_prev_row
go_next:
        jmp menu_next_row
go_fire:
        jmp menu_execute

last_joy_value:
        .byte 0
delay:
        .byte 8
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void menu_invert_row()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export menu_invert_row
.proc menu_invert_row
        ldy MENU_ITEM_LEN
        dey

l0:     lda (MENU_CURRENT_ROW_ADDR),y
        eor #%10000000
        sta (MENU_CURRENT_ROW_ADDR),y
        dey
        bpl l0
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void menu_execute
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export menu_execute
.proc menu_execute
        jmp (MENU_EXEC_ADDR)
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void menu_next_row()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export menu_next_row
.proc menu_next_row
        jsr menu_invert_row

        ldx MENU_CURRENT_ITEM
        inx
        cpx MENU_MAX_ITEMS
        beq itemlast

        clc
        lda MENU_CURRENT_ROW_ADDR                       ; MENU_CURRENT_ROW_ADDR += ITEM_LEN
        adc MENU_BYTES_BETWEEN_ITEMS
        sta MENU_CURRENT_ROW_ADDR
        bcc end
        inc MENU_CURRENT_ROW_ADDR+1
        jmp end

itemlast:
        dex

end:
        stx MENU_CURRENT_ITEM
        jmp menu_invert_row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void menu_prev_row()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export menu_prev_row
.proc menu_prev_row
        jsr menu_invert_row

        ldx MENU_CURRENT_ITEM
        dex
        bmi itemfirst

        sec
        lda MENU_CURRENT_ROW_ADDR                       ; MENU_CURRENT_ROW_ADDR -= ITEM_LEN
        sbc MENU_BYTES_BETWEEN_ITEMS
        sta MENU_CURRENT_ROW_ADDR
        bcs end
        dec MENU_CURRENT_ROW_ADDR+1
        jmp end

itemfirst:
        inx
        ; assert(x=0)

end:
        stx MENU_CURRENT_ITEM
        jmp menu_invert_row
.endproc


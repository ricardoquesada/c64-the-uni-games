;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; menu handling code
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

.import ut_get_key

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
        jsr read_events                 ; value in A, but Z is not guaranteed
        cmp last_value
        bne process_event
        rts

process_event:
        sta last_value
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

last_value:
        .byte 0
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

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; byte read_events()
; returns:
;       %00010000 fire or space
;       %00001000 right
;       %00000100 left
;       %00000010 down
;       %00000001 up
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_events

        lda #%00011111
        sta $dc00

        lda $dc00                       ; read joy#2
        eor #%11111111                  ; "normalize" events
        and #%00011111
        beq l1                          ; if no joystick, read keyboard
        rts

l1:     jmp read_keyboard               ; otherwise, read keyboard

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; byte read_keyboard()
; returns:
;       %00010000 fire or space
;       %00001000 right
;       %00000100 left
;       %00000010 down
;       %00000001 up
;
; Reference: http://sta.c64.org/cbm64kbdlay.html
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc read_keyboard

        lda #$ff
        sta CIA1_PRB                    ; needed ?

        lda #%01111111                  ; space ?
        sta CIA1_PRA                    ; row 7
        lda CIA1_PRB
        and #%00010000                  ; col 4
        eor #%00010000
        bne end                         ; if pressed, end


        lda #%11111101                  ; left shift pressed ?
        sta CIA1_PRA                    ; row 1
        lda CIA1_PRB
        and #%10000000                  ; col 7
        beq skip

        lda #%10111111                  ; right shift pressed ?
        sta CIA1_PRA                    ; row 6
        lda CIA1_PRB
        and #%00010000                  ; col 4
        beq skip
        lda #%11111111                  ; no shift then
skip:
        eor #%11111111
        sta shift_pressed


        lda #%11111110                  ; cursor left/right ?
        sta CIA1_PRA                    ; row 0
        lda CIA1_PRB
        and #%00000100                  ; col 2
        eor #%00000100
        beq up_down

        lda #%00000100                  ; Left bit On
        ldx shift_pressed
        beq end
        asl                             ; convert "left" into "right"
        ; assert (!z)
        bne end

up_down:
        lda #%11111110                  ; cursor up/down ?
        sta CIA1_PRA                    ; row 0
        lda CIA1_PRB
        and #%10000000                  ; col 7
        eor #%10000000
        beq end

        lda #%00000010                  ; Down bit on
        ldx shift_pressed               ; If shift On, convert it to Up
        beq end                         ; not pressed, end
        lsr                             ; convert "down" into "up"

end:
        rts

shift_pressed:          .byte 0         ; boolean
.endproc


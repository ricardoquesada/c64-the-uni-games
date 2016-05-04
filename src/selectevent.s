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

.segment "SELECT_EVENT_CODE"

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

        dec $01                         ; $34: RAM 100%

        jsr decrunch                    ; uncrunch map

        inc $01                         ; $35: RAM + IO ($D000-$DF00)
        cli
        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; selectevent_loop
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export selectevent_loop
.proc selectevent_loop

        jsr ut_get_key
        bcc end

        cmp #$47                        ; space ?
        bne end
        inc $400
end:
        rts                             ; return to caller (main menu)
.endproc


.segment "COMPRESSED_DATA"
; select_event-map.prg.exo: should be exported to $0680
.incbin "select_event-map.prg.exo"
selectevent_map:
        .byte 0                         ; ignore

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
        lda #0
        sta $d01a                       ; no raster IRQ, only timer IRQ

        lda #$01
        jsr ut_clear_color

        ldx #<selectevent_map
        ldy #>selectevent_map
        stx _crunched_byte_lo
        sty _crunched_byte_hi

        dec $01                         ; $34: RAM 100%

        jsr decrunch                    ; uncrunch map

        inc $01                         ; $35: RAM + IO ($D000-$DF00)
        cli

selectevent_mainloop:
        lda sync_timer_irq
        bne play_music

        jsr ut_get_key
        bcc selectevent_mainloop

        cmp #$47                        ; space ?
        bne selectevent_mainloop
        rts                             ; return to caller (main menu)
play_music:
        dec sync_timer_irq
        jsr $1003
        jmp selectevent_mainloop
.endproc



.segment "COMPRESSED_DATA"
; select_event-map.prg.exo: should be exported to $0400
.incbin "select_event-map.prg.exo"
selectevent_map:
        .byte 0                         ; ignore

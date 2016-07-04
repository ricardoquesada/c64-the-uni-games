;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; About file
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

.import decrunch                                ; exomizer decrunch
.import _crunched_byte_hi, _crunched_byte_lo    ; from utils
.import sync_timer_irq
.import ut_clear_color, ut_get_key, ut_clear_screen
.import menu_read_events

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
; about_init
;------------------------------------------------------------------------------;
.export about_init
.proc about_init
        lda #%10000000                          ; enable only PAL/NTSC scprite
        sta VIC_SPR_ENA

        sei

        ldx #<about_map
        ldy #>about_map
        stx _crunched_byte_lo
        sty _crunched_byte_hi

        dec $01                                 ; $34: RAM 100%

        jsr decrunch                            ; uncrunch map

        inc $01                                 ; $35: RAM + IO ($D000-$DF00)


        ldx #0                                  ; put correct colors on screen
l0:
        lda $400,x
        tay
        lda COLORMAP_BASE,y
        sta $d800,x

        lda $500,x
        tay
        lda COLORMAP_BASE,y
        sta $d900,x

        lda $600,x
        tay
        lda COLORMAP_BASE,y
        sta $da00,x

        lda $6e8,x
        tay
        lda COLORMAP_BASE,y
        sta $dae8,x

        inx
        bne l0
        cli

about_mainloop:
        lda sync_timer_irq
        bne play_music

        jsr menu_read_events
        cmp #%00010000                          ; space or button
        bne about_mainloop
        rts                                     ; return to caller (main menu)
play_music:
        dec sync_timer_irq
        jsr $1003
        jmp about_mainloop
.endproc


.segment "COMPRESSED_DATA"
        .incbin "about-map.prg.exo"
about_map:

        .byte 0                                 ; ignore

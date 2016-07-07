;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; intro
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;


.import main

; from exodecrunch.s
.import decrunch                                ; exomizer decrunch

; from utils.s
.import _crunched_byte_hi, _crunched_byte_lo    ; exomizer address
.import menu_handle_events
.import ut_clear_color, ut_start_clean

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
.include "myconstants.inc"


.segment "CODE"
        jmp intro_main

.segment "HI_CODE"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void intro_main()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc intro_main
        jsr ut_start_clean              ; no basic, no kernal, no interrupts

        sei

        lda #$ff
        sta CIA1_DDRA                   ; port a ddr (output)
        lda #$0
        sta CIA1_DDRB                   ; port b ddr (input)


        lda #$00                        ; turn off volume
        sta SID_Amp
        sta VIC_SPR_ENA                 ; no sprites

        lda #0
        sta $d020
        sta $d021                       ; background color

                                        ; turn off video
        lda #%01011011                  ; the bug that blanks the screen
        sta $d011                       ; extended color mode: on
        lda #%00011000
        sta $d016                       ; turn on multicolor

        lda $dd00                       ; Vic bank 0: $0000-$3FFF
        and #$fc
        ora #3
        sta $dd00

        lda #%00011100                  ; charset at $3000, screen at $0400
        sta $d018


        dec $01                         ; $34: RAM 100%

        ldx #<intro_charset_exo         ; decrunch charset
        ldy #>intro_charset_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncompress it

        ldx #<intro_map_exo             ; decrunch map
        ldy #>intro_map_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncompress it

        inc $01                         ; $35: RAM + IO ($D000-$DFFF)

        lda #0                          ; background is white
        jsr ut_clear_color

                                        ; turn VIC on again
        lda #%00011011                  ; charset mode, default scroll-Y position, 25-rows
        sta $d011                       ; extended color mode: off
        lda #%00001000                  ; no scroll, hires (mono color), 40-cols
        sta $d016                       ; turn off multicolor


        jsr fade_in_logo

        cli
        lda #5
        sta delay

l0:     ldx #0
l1:     ldy #0

l2:
        lda #%01111111                  ; space ?
        sta CIA1_PRA                    ; row 7
        lda CIA1_PRB
        and #%00010000                  ; col 4
        beq end

        dey
        bne l2

        dex
        bne l1

        dec delay
        bne l0

end:
        jsr fade_out_logo


        jmp main


delay:
        .byte 0
.endproc

.proc fade_delay_2
        ldy #20
l1:     ldx #0
l0:     dex
        bne l0
        dey
        bne l1
        rts
.endproc

.proc fade_in_logo
        ldy #TOTAL_COLORS-1
l0:     lda colors,y
        sta $d020
        sta $d021

        tya
        pha

        jsr fade_delay_2

        pla
        tay

        dey
        bpl l0
        rts
colors:
        .byte 1, 15, 12, 11, 0
TOTAL_COLORS = * - colors
.endproc

.proc fade_out_logo
        ldy #TOTAL_COLORS-1
l0:     lda colors,y
        sta $d020
        sta $d021

        tya
        pha

        jsr fade_delay_2

        pla
        tay

        dey
        bpl l0
        rts
colors:
        .byte 0, 11, 12, 15, 1
TOTAL_COLORS = * - colors
.endproc


.segment "COMPRESSED_DATA"
        ; export it at 0x3000
        .incbin "src/intro-charset.prg.exo"
intro_charset_exo:

        ; export it at 0x0400
        .incbin "src/intro-map.prg.exo"
intro_map_exo:

        .byte 0             ; ignore

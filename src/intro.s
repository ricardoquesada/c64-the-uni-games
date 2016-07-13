;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; intro
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;


.import main_menu

; from exodecrunch.s
.import decrunch                                ; exomizer decrunch

; from utils.s
.import _crunched_byte_hi, _crunched_byte_lo    ; exomizer address
.import menu_handle_events
.import ut_clear_color, ut_start_clean, ut_detect_pal_paln_ntsc, ut_vic_video_type

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
.include "myconstants.inc"


.enum INTRO_STATE
        FADE_IN
        WAIT_KEY
        FADE_OUT
        END
.endenum

.segment "CODE"
        jmp intro_main

.segment "HI_CODE"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void intro_main()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc intro_main
                                        ; one time init code here
        jsr ut_start_clean              ; no basic, no kernal, no interrupts
        jsr ut_detect_pal_paln_ntsc     ; pal, pal-n or ntsc?

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

        ldx #<mainsprites_exo           ; decrunch main sprites
        ldy #>mainsprites_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch

        inc $01                         ; $35: RAM + IO ($D000-$DFFF)

        lda #0                          ; background is white
        jsr ut_clear_color

        jsr init_sprite

                                        ; turn VIC on again
        lda #%00011011                  ; charset mode, default scroll-Y position, 25-rows
        sta $d011                       ; extended color mode: off
        lda #%00001000                  ; no scroll, hires (mono color), 40-cols
        sta $d016                       ; turn off multicolor

        lda #01                         ; enable raster irq
        sta $d01a                       ; needed to open borders

        ldx #<irq_top                   ; next IRQ-raster vector
        ldy #>irq_top                   ; needed to open the top/bottom borders
        stx $fffe
        sty $ffff
        lda #50
        sta $d012

        cli

loop:
        lda sync_raster_irq
        bne loop

        dec sync_raster_irq

        lda intro_state
        cmp #INTRO_STATE::FADE_IN
        beq fadein
        cmp #INTRO_STATE::WAIT_KEY
        beq waitkey
        cmp #INTRO_STATE::FADE_OUT
        beq fadeout

        jmp main_menu                   ; INTRO_STATE::END? to to main menu


fadein:
        jsr fade_in_logo
        jmp loop


waitkey:
        lda #%01111111                  ; space ?
        sta CIA1_PRA                    ; row 7
        lda CIA1_PRB
        and #%00010000                  ; col 4
        beq start_fadeout
        jmp loop

start_fadeout:
        lda #INTRO_STATE::FADE_OUT
        sta intro_state
        jmp loop

fadeout:
        jsr fade_out_logo
        jmp loop
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_sprite()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_sprite
        lda #%10000000                  ; enable sprites
        sta VIC_SPR_ENA
        lda #%10000000                  ; set sprite #7 x-pos 9-bit ON
        sta $d010                       ; since x pos > 255
        lda #%00000000
        sta VIC_SPR_MCOLOR              ; enable multicolor

        lda #$40                        ; setup PAL/NTSC/ sprite
        sta VIC_SPR7_X                  ; x= $140 = 320
        lda #$f0
        sta VIC_SPR7_Y

        lda #0                          ; color
        sta VIC_SPR7_COLOR

        ldx #(SPRITES_POINTER + $0f)    ; sprite pointer to PAL (15)
        lda ut_vic_video_type           ; ntsc, pal or paln?
        cmp #$01                        ; Pal ?
        beq @end                        ; yes.
        cmp #$2f                        ; Pal-N?
        beq @paln                       ; yes
        cmp #$2e                        ; NTSC Old?
        beq @ntscold                    ; yes

        ldx #(SPRITES_POINTER + $0e)    ; otherwise it is NTSC
        bne @end

@ntscold:
        ldx #(SPRITES_POINTER + $0c)    ; NTSC old
        bne @end
@paln:
        ldx #(SPRITES_POINTER + $0d)    ; PAL-N (Drean)
@end:
        stx SPRITES_PTR0 + 7            ; set sprite pointer for screen0
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ: irq_top()
;------------------------------------------------------------------------------;
; used to open the top/bottom borders
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_top
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt

        lda #$f8
        sta $d012
        ldx #<irq_bottom
        ldy #>irq_bottom
        stx $fffe
        sty $ffff
        inc sync_raster_irq

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

.proc irq_bottom
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt

        lda $d011                       ; open vertical borders trick
        and #%11110111                  ; first switch to 24 cols-mode...
        sta $d011

:       lda $d012
        cmp #$ff
        bne :-

        lda $d011                       ; ...a few raster lines switch to 25 cols-mode again
        ora #%00001000
        sta $d011


        lda #50
        sta $d012
        ldx #<irq_top
        ldy #>irq_top
        stx $fffe
        sty $ffff

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
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
        ldy color_idx
l0:     lda colors,y
        sta $d020
        sta $d021

        cpy #TOTAL_COLORS-1
        bne end

        lda #INTRO_STATE::WAIT_KEY
        sta intro_state
        rts
end:
        inc color_idx
        rts
colors:
        .byte 0, 11, 12, 15, 1
TOTAL_COLORS = * - colors
color_idx:
        .byte 0
.endproc

.proc fade_out_logo
        ldy color_idx
l0:     lda colors,y
        sta $d020
        sta $d021

        cpy #TOTAL_COLORS-1
        bne end

        lda #INTRO_STATE::END
        sta intro_state
        rts
end:
        inc color_idx
        rts

colors:
        .byte 1, 15, 12, 11, 0
TOTAL_COLORS = * - colors
color_idx:
        .byte 0
.endproc

sync_raster_irq:
        .byte 0

intro_state:
        .byte INTRO_STATE::FADE_IN


.segment "COMPRESSED_DATA"
        ; export it at 0x3000
        .incbin "src/intro-charset.prg.exo"
intro_charset_exo:

        ; export it at 0x0400
        .incbin "src/intro-map.prg.exo"
intro_map_exo:

        ; export it at 0x2400
        .incbin "src/sprites.prg.exo"
mainsprites_exo:

        .byte 0             ; ignore

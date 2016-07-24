;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; About file
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

.import ut_clear_color, ut_get_key, ut_clear_screen
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
; void about_anim_scroll()
; do the vertical scroll
;------------------------------------------------------------------------------;
.proc about_anim_scroll
        dec scroll_delay
        beq do_the_scroll
        rts

do_the_scroll:
        lda #3
        sta scroll_delay

        ldx scroll_y
        dex
        txa
        and #%00000111
        sta scroll_y

        cmp #2
        beq scroll

        rts

scroll:
        ldx #39

l0:
        .repeat 17, YY
                lda SCREEN0_BASE + 40 * (8 + YY),x
                sta SCREEN0_BASE + 40 * (7 + YY),x
        .endrepeat

source_addr = *+1
        lda credits_map,x
        sta SCREEN0_BASE + 40 * 24,x

        dex
        bpl l0

        inc scroll_row                          ; last row for scroll ?
        lda scroll_row

        cmp #88+17                              ; end? loop the scroll
        beq loop_scroll

        cmp #88                                 ; 88 or more ? fill next 16 lines with spaces
        bpl fake_spaces

        clc                                     ; else, increment source addr
        lda source_addr                         ; and return
        adc #40
        sta source_addr
        bcc :+
        inc source_addr+1
:       rts

fake_spaces:
        ldx #<(credits_map+40*2)                ; 3rd row if full of spaces 
        ldy #>(credits_map+40*2)                ; use it to generate 16 empty rows
        stx source_addr
        sty source_addr+1
        rts

loop_scroll:
        lda #0
        sta scroll_row
        ldx #<credits_map
        ldy #>credits_map
        stx source_addr
        sty source_addr+1
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; about_init
;------------------------------------------------------------------------------;
.export about_init
.proc about_init
        sei

        lda #%11111111                          ; init sprites
        sta VIC_SPR_ENA
        sta VIC_SPR_EXP_X
        lda #0
        sta VIC_SPR_MCOLOR
        lda #%11100000
        sta VIC_SPR_HI_X

        lda #0                                  ; sprite colors.
        sta VIC_SPR0_COLOR                      ; these sprites are used
        sta VIC_SPR1_COLOR                      ; to create a "barrier"
        sta VIC_SPR2_COLOR                      ; so that the top
        sta VIC_SPR3_COLOR                      ; scrolling row doesn't look
        sta VIC_SPR4_COLOR                      ; bad
        sta VIC_SPR5_COLOR
        sta VIC_SPR6_COLOR
        sta VIC_SPR7_COLOR

        ldx #0
        ldy #0

l0:     lda #(50+8*7)
        sta VIC_SPR0_Y,y
        lda sprites_x,x
        sta VIC_SPR0_X,y
        lda #(SPRITES_POINTER + 47)             ; block
        sta SPRITES_PTR0,x                      ; sprite pointer

        iny
        iny
        inx
        cpx #8
        bne l0

        lda #1                                  ; init screen
        jsr ut_clear_color
        lda #$20
        jsr ut_clear_screen

        ldx #0
l1:
        lda about_map,x
        sta SCREEN0_BASE,x
        tay
        lda mainscreen_colors,y
        sta $d800,x

        inx
        cpx #240
        bne l1

        lda #1
        sta $d01a                               ; enable raster IRQ

        lda #0
        sta $d012
        sta about_sync_timer                    ; sync flags
        sta about_sync_raster
        sta scroll_y
        sta scroll_row

        lda #1
        sta scroll_delay

        ldx #<irq_vscroll_top
        ldy #>irq_vscroll_top
        stx $fffe
        sty $ffff

        ldx #<credits_map
        ldy #>credits_map
        stx about_anim_scroll::source_addr
        sty about_anim_scroll::source_addr+1

        cli

about_mainloop:
        lda about_sync_timer
        bne play_music                          ; timer IRQ?

        lda about_sync_raster
        beq about_mainloop                      ; raster IRQ?

        dec about_sync_raster

        jsr about_anim_scroll                   ; animate scroll

        jsr menu_read_events
        cmp #%00010000                          ; space or button
        bne about_mainloop

        lda #0                                  ; cleanup
        sta $d01a                               ; disable IRQ

        rts                                     ; return to caller (main menu)

play_music:
        dec about_sync_timer
        jsr $1003
        jmp about_mainloop
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void irq_vscroll_top()
; sets the scrolling part of the screen
;------------------------------------------------------------------------------;
.proc irq_vscroll_top
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
        bcs raster

        lda $dc0d                       ; clears CIA interrupts, in particular timer A
        inc about_sync_timer
        jmp end_irq

raster:
        lda scroll_y
        ora #%00001000                  ; disable blank
        sta $d011                       ; smooth scroll y

        lda #(50 + 25*8)
        sta $d012

        ldx #<irq_vscroll_bottom
        ldy #>irq_vscroll_bottom
        stx $fffe
        sty $ffff

        lda #(50+8*24)
        .repeat 8, YY
                sta VIC_SPR0_Y + YY * 2
        .endrepeat

end_irq:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void irq_vscroll_bottom()
; sets the non-scrolling part of the screen
;------------------------------------------------------------------------------;
.proc irq_vscroll_bottom
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
        bcs raster

        lda $dc0d                       ; clears CIA interrupts, in particular timer A
        inc about_sync_timer
        jmp end_irq

raster:
        lda #%00011011                  ; 25 rows, y-scroll original position
        sta $d011

        lda #(50 + 7*8)
        sta $d012

        ldx #<irq_vscroll_top
        ldy #>irq_vscroll_top
        stx $fffe
        sty $ffff

        lda #(50+8*7)
        .repeat 8, YY
                sta VIC_SPR0_Y + YY * 2
        .endrepeat

        inc about_sync_raster

end_irq:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc


about_sync_raster:      .byte 0
about_sync_timer:       .byte 0
scroll_y:               .byte 0                 ; scroll y to be used in $d011
scroll_row:             .byte 0                 ; how many rows were scrolled ?
scroll_delay:           .byte 0                 ; delay
sprites_x:
        .repeat 8, XX
                .byte (24 + 24 * XX * 2) .MOD 256          ; x position for expanded sprites
        .endrepeat

credits_map = * + 240                           ; 40 x 6
about_map:
        .incbin "about-map.bin"                 ; 40 x 6 "ABOUT"
                                                ; 40 x 88 CREDITS

        .byte 0                                 ; ignore

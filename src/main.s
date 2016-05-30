;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; main screen
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __SIDMUSIC_LOAD__

.import roadrace_init, selectevent_init, scores_init
.import selectevent_loop

; from exodecrunch.s
.import decrunch                                ; exomizer decrunch

; from utils.s
.import _crunched_byte_hi, _crunched_byte_lo    ; exomizer address
.import ut_get_key, ut_read_joy2, ut_detect_pal_paln_ntsc
.import ut_vic_video_type, ut_start_clean
.import ut_clear_screen, ut_clear_color
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


.enum SCENE_STATE
        MAIN_MENU
        SELECTEVENT_MENU
        SCORES_MENU
        ABOUT_MENU
.endenum

.segment "CODE"
        jmp main

.segment "HI_CODE"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main
        lda #$ff
        sta CIA1_DDRA                   ; port a ddr (output)
        lda #$0
        sta CIA1_DDRB                   ; port b ddr (input)

        jsr display_intro_banner
        jsr ut_start_clean              ; no basic, no kernal, no interrupts
        jsr ut_detect_pal_paln_ntsc     ; pal, pal-n or ntsc?


        ; disable NMI
;       sei
;       ldx #<disable_nmi
;       ldy #>disable_nmi
;       sta $fffa
;       sta $fffb
;       cli

        jmp main_init

disable_nmi:
        rti
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void display_intro_banner()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc display_intro_banner
        lda #$20
        jsr ut_clear_screen
        lda #1
        jsr ut_clear_color
        lda #0
        sta $d020
        sta $d021

        ldx #0
l0:
        lda label1,x
        sta $0400,x
        jsr delay
        inx
        cpx #LABEL1_LEN
        bne l0

        ldx #0
l1:
        lda label2,x
        sta $0400 + 51,x
        jsr delay
        inx
        cpx #LABEL2_LEN
        bne l1

        rts

delay:
        lda #%01111111                  ; space ?
        sta CIA1_PRA                    ; row 7
        lda CIA1_PRB
        and #%00010000                  ; col 4
        bne do_delay
        lda #$08
        sta delay_value

do_delay:
        txa
        pha
delay_value = *+1
        ldx #$30
l2:
        ldy #0
l3:     iny
        bne l3
        dex
        bne l2

        pla
        tax
        rts

label1:
                ;1234567890123456789012345678901234567890
        scrcode "winners don't use joysticks..."
LABEL1_LEN = * - label1

label2:
        scrcode           "    ...they use unijoysticles"
        scrcode "                   "
LABEL2_LEN = * - label2
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_init()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init
        sei

        lda #SCENE_STATE::MAIN_MENU      ; menu to display
        sta scene_state                 ; is "main menu"

        lda $dd00                       ; Vic bank 0: $0000-$3FFF
        and #$fc
        ora #3
        sta $dd00

        lda #%00010100                  ; charset at $1000 (same as sid, but uses built-in one)
        sta $d018


        lda #$00                        ; background & border color
        sta $d020
        sta $d021

        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda #01                         ; enable raster irq
        sta $d01a

        ldx #<irq_a                     ; next IRQ-raster vector
        ldy #>irq_a                     ; needed to open the top/bottom borders
        stx $fffe
        sty $ffff
        lda #50
        sta $d012

        lda $dc0d                       ; clear interrupts and ACK irq
        lda $dd0d
        asl $d019

        lda #$00                        ; turn off volume
        sta SID_Amp

        lda #$00                        ; avoid garbage when opening borders
        sta $bfff                       ; should be $3fff, but I'm in the 2 bank

                                        ; multicolor mode + extended color causes
        lda #%01011011                  ; the bug that blanks the screen
        sta $d011                       ; extended color mode: on
        lda #%00011000
        sta $d016                       ; turn on multicolor


        jsr init_data
        jsr init_screen
        jsr init_music
        jsr mainmenu_init

                                        ; turn VIC on again
        lda #%00011011                  ; charset mode, default scroll-Y position, 25-rows
        sta $d011                       ; extended color mode: off

        lda #%00001000                  ; no scroll, hires (mono color), 40-cols
        sta $d016                       ; turn off multicolor

        cli


main_loop:
        lda sync_raster_irq
        bne do_raster

        lda sync_timer_irq
        beq main_loop

        dec sync_timer_irq
        jsr MUSIC_PLAY
        jmp main_loop

do_raster:
        dec sync_raster_irq

        jsr animate_palette

        jsr menu_handle_events          ; will disable/enable interrupts

        jmp main_loop
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void mainmenu_init()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc mainmenu_init
        lda #3                                  ; setup the global variables
        sta MENU_MAX_ITEMS                      ; needed for the menu code
        lda #0
        sta MENU_CURRENT_ITEM
        lda #30
        sta MENU_ITEM_LEN
        lda #(40*2)
        sta MENU_BYTES_BETWEEN_ITEMS
        ldx #<(SCREEN0_BASE + 40 * 16 + 5)
        ldy #>(SCREEN0_BASE + 40 * 16 + 5)
        stx MENU_CURRENT_ROW_ADDR
        sty MENU_CURRENT_ROW_ADDR+1
        ldx #<mainmenu_exec
        ldy #>mainmenu_exec
        stx MENU_EXEC_ADDR
        sty MENU_EXEC_ADDR+1

        jmp menu_invert_row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void mainmenu_exec()
;------------------------------------------------------------------------------;
.proc mainmenu_exec
        lda MENU_CURRENT_ITEM
        beq start_game                  ; item 0? start game
        cmp #$01
        beq jump_high_scores            ; item 1? high scores
        cmp #$02
        bne end                         ; item 2? about
        jmp end                         ; FIXME: add here jump to about

end:
        rts

start_game:
        jsr selectevent_init
        lda #SCENE_STATE::SELECTEVENT_MENU
        sta scene_state
        rts

jump_high_scores:
        lda #SCENE_STATE::SCORES_MENU
        sta scene_state

        jsr scores_init                 ; takes over of the mainloop
                                        ; no need to update the jmp table

        lda #SCENE_STATE::MAIN_MENU     ; restore stuff modifying by scores
        sta scene_state

        lda #%00010100                  ; restore video address: at $0400
        sta $d018
        jsr init_screen

        lda #01                         ; enable raster irq again
        sta $d01a

        rts

.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ: irq_open_borders()
;------------------------------------------------------------------------------;
; used to open the top/bottom borders
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
irq_a:
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
        bcs @raster

        lda $dc0d                       ; clears CIA interrupts, in particular timer A
        inc sync_timer_irq
        jmp @end_irq

@raster:
        lda #$f8
        sta $d012
        ldx #<irq_open_borders
        ldy #>irq_open_borders
        stx $fffe
        sty $ffff

        ldx #0
        stx $d021

        ldx palette_idx_top
        .repeat 6 * 8
                lda $d012
:               cmp $d012
                beq :-
                lda luminances,x
                sta $d021
                inx
                txa
                and #%00111111          ; only 64 values are loaded
                tax
        .endrepeat

        ldx palette_idx_bottom
        .repeat 6 * 8
                lda $d012
:               cmp $d012
                beq :-
                lda luminances,x
                sta $d021
                dex
                txa
                and #%00111111          ; only 64 values are loaded
                tax
        .endrepeat

        lda #0
        sta $d021

        inc sync_raster_irq

@end_irq:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status

.export irq_open_borders
irq_open_borders:
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
        bcs @raster

        lda $dc0d                       ; clears CIA interrupts, in particular timer A
        inc sync_timer_irq
        jmp @end_irq

@raster:
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
        ldx #<irq_a
        ldy #>irq_a
        stx $fffe
        sty $ffff

@end_irq:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_data()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_data
        ; ASSERT (interrupts disabled)

        dec $01                         ; $34: RAM 100%

        ldx #<mainsid_exo               ; decrunch music
        ldy #>mainsid_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch map


        ldx #<mainscreen_exo            ; decrunch main screen
        ldy #>mainscreen_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch


        ldx #<mainsprites_exo           ; decrunch main sprites
        ldy #>mainsprites_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch

        inc $01                         ; $35: RAM + IO ($D000-$DF00)

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_screen()
;------------------------------------------------------------------------------;
; paints the screen with the "main menu" screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen
        ldx #$00
@loop:
        lda #0
        sta $d800,x                     ; set reverse color
        sta $d800+$0100,x               ; set reverse color
        sta $d800+$0100+48,x            ; set reverse color

        lda #1
        sta $d800+$0200+48,x            ; set normal color
        sta $d800+$02e8,x               ; set normal color

        inx
        bne @loop

        lda #$0b                         ; set color for copyright
        ldx #39
:       sta $d800+24*40,x
        dex
        bpl :-


        lda #%10000000                  ; enable sprite #7
        sta VIC_SPR_ENA
        lda #%10000000                  ; set sprite #7 x-pos 9-bit ON
        sta $d010                       ; since x pos > 255

        lda #$40
        sta VIC_SPR7_X                  ; x= $140 = 320
        lda #$f0
        sta VIC_SPR7_Y

        lda SPRITES_BASE + 64 * 15 + 63 ; sprite color
        and #$0f
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
        lda ntsc_speed
        sta music_speed
        lda ntsc_speed+1
        sta music_speed+1
        bne @end

@ntscold:
        lda ntsc_speed
        sta music_speed
        lda ntsc_speed+1
        sta music_speed+1
        ldx #(SPRITES_POINTER + $0c)    ; NTSC old
        bne @end
@paln:
        ldx #(SPRITES_POINTER + $0d)    ; PAL-N (Drean)
@end:
        stx SPRITES_PTR0 + 7            ; set sprite pointer for screen0
        stx SPRITES_PTR1 + 7            ; set sprite pointer for screen1

        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_music(void)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_music
        lda #0
        jsr MUSIC_INIT                  ; init song #0

        lda music_speed                 ; init with PAL frequency
        sta $dc04                       ; it plays at 50.125hz
        lda music_speed+1
        sta $dc05

        lda #$81                        ; enable timer to play music
        sta $dc0d                       ; CIA1

        lda #$11
        sta $dc0e                       ; start timer interrupt A
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void animate_palette(void)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc animate_palette

        dec palette_idx_top             ; animate top palette
        lda palette_idx_top
        and #%00111111
        sta palette_idx_top

        dec palette_idx_bottom          ; animate bottom palette
        lda palette_idx_bottom
        and #%00111111
        sta palette_idx_bottom
        rts
.endproc

music_speed: .word $4cc7                ; default: playing at PAL spedd in PAL computer
ntsc_speed: .word $4550                 ; playing at PAL speed in NTSC computer

palette_idx_top:        .byte 0         ; color index for top palette
palette_idx_bottom:     .byte 48        ; color index for bottom palette (palette_size / 2)

luminances:
.byte $01,$01,$0d,$0d,$07,$07,$03,$03,$0f,$0f,$05,$05,$0a,$0a,$0e,$0e
.byte $0c,$0c,$08,$08,$04,$04,$02,$02,$0b,$0b,$09,$09,$06,$06,$00,$00
.byte $01,$01,$0d,$0d,$07,$07,$03,$03,$0f,$0f,$05,$05,$0a,$0a,$0e,$0e
.byte $0c,$0c,$08,$08,$04,$04,$02,$02,$0b,$0b,$09,$09,$06,$06,$00,$00
PALETTE_SIZE = * - luminances

.export sync_raster_irq
sync_raster_irq:    .byte 0            ; enabled when raster is triggred (once per frame)
.export sync_timer_irq
sync_timer_irq:     .byte 0            ; enabled when timer is triggred (used by music)

scene_state:        .byte SCENE_STATE::MAIN_MENU ; scene state. which scene to render


.segment "COMPRESSED_DATA"
        .incbin "src/Chariots_of_Fire.sid.exo"
mainsid_exo:
        .incbin "src/mainscreen-map.prg.exo"
mainscreen_exo:
        .incbin "src/sprites.prg.exo"
mainsprites_exo:

        .byte 0             ; ignore

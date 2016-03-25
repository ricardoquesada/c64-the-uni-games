;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; main screen
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __MAIN_CODE_LOAD__, __SIDMUSIC_LOAD__
.import __MAIN_SPRITES_LOAD__, __GAME_CODE_LOAD__, __HIGH_SCORES_CODE_LOAD__

; from utils.s
.import ut_get_key, ut_read_joy2, ut_detect_pal_paln_ntsc
.import ut_vic_video_type, ut_start_clean

; from highscores.s
.import scores_mainloop, scores_init

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
SPRITE_ANIMATION_SPEED = 8
SCREEN_BASE = $8400                     ; screen address
MUSIC_INIT = $1000
MUSIC_PLAY = $1003

.enum SCENE_STATE
    MAIN_MENU
    SCORES_MENU
    ABOUT_MENU
.endenum

.segment "CODE"
        jsr ut_start_clean              ; no basic, no kernal, no interrupts
        jsr ut_detect_pal_paln_ntsc     ; pal, pal-n or ntsc?


        ; disable NMI
;       sei
;       ldx #<disable_nmi
;       ldy #>disable_nmi
;       sta $fffa
;       sta $fffb
;       cli

        jmp __MAIN_CODE_LOAD__

disable_nmi:
        rti

.segment "MAIN_CODE"
        sei

        lda SCENE_STATE::MAIN_MENU      ; menu to display
        sta scene_state                 ; is "main menu"

        lda #%00001000                  ; no scroll,single-color,40-cols
        sta $d016

        lda $dd00                       ; Vic bank 2: $8000-$BFFF
        and #$fc
        ora #1
        sta $dd00

        lda #%00010100                  ; charset at $9000 (equal to $1000 for bank 0)
        sta $d018

        lda #%00011011                  ; disable bitmap mode, 25 rows, disable extended color
        sta $d011                       ; and vertical scroll in default position

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

        jsr init_music

        jsr init_screen

        cli


@main_loop:
        lda sync_raster_irq
        bne @do_raster
        lda sync_timer_irq
        beq @main_loop
        dec sync_timer_irq
        jsr MUSIC_PLAY
        jmp @main_loop

@do_raster:
        dec sync_raster_irq

        jsr animate_palette
        jsr ut_get_key
        bcc @main_loop

        cmp #$40                        ; F1
        beq @start_game
        cmp #$50                        ; F3
        beq @jump_high_scores
        cmp #$30                        ; F7
        bne @main_loop
        jmp @main_loop                  ; FIXME: added here jump to about

@start_game:
        jmp __GAME_CODE_LOAD__

@jump_high_scores:
        lda SCENE_STATE::SCORES_MENU
        sta scene_state
        jsr scores_init

        jsr scores_mainloop

        lda SCENE_STATE::MAIN_MENU
        sta scene_state

        jsr init_screen

        lda #01                         ; enable raster irq again
        sta $d01a

        jmp @main_loop

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
; void init_screen()
;------------------------------------------------------------------------------;
; paints the screen with the "main menu" screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen
        ldx #$00
@loop:
        lda main_menu_screen,x          ; copy the first 14 rows
        clc                             ; using the reversed characters
        adc #$80                        ; 14 * 40 = 560 = 256 + 256 + 48
        sta SCREEN_BASE,x
        lda #0
        sta $d800,x                     ; set reverse color

        lda main_menu_screen+$0100,x
        clc
        adc #$80
        sta SCREEN_BASE+$0100,x
        lda #0
        sta $d800+$0100,x               ; set reverse color

        lda main_menu_screen+$0100+48,x
        clc
        adc #$80
        sta SCREEN_BASE+$0100+48,x
        lda #0
        sta $d800+$0100+48,x            ; set reverse color


        lda main_menu_screen+$0200+48,x ; copy the remaining chars
        sta SCREEN_BASE+$0200+48,x      ; in normal mode
        lda #1
        sta $d800+$0200+48,x            ; set normal color
        lda main_menu_screen+$02e8,x
        sta SCREEN_BASE+$02e8,x
        lda #1
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

        lda __MAIN_SPRITES_LOAD__ + 64 * 15 + 63; sprite color
        and #$0f
        sta VIC_SPR7_COLOR

        ldx #$0f                        ; sprite pointer to PAL (15)
        lda ut_vic_video_type           ; ntsc, pal or paln?
        cmp #$01                        ; Pal ?
        beq @end                        ; yes.
        cmp #$2f                        ; Pal-N?
        beq @paln                       ; yes
        cmp #$2e                        ; NTSC Old?
        beq @ntscold                    ; yes
        ldx #$0e                        ; otherwise it is NTSC
        bne @end

@ntscold:
        ldx #$0c
        bne @end
@paln:
        ldx #$0d
@end:
        stx $87ff                       ; set sprite pointer

        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_music(void)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_music
        lda #0
        jsr MUSIC_INIT                  ; init song #0

        lda #<$4cc7                     ; init with PAL frequency
        sta $dc04                       ; it plays at 50.125hz
        lda #>$4cc7
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

main_menu_screen:
        .incbin "mainscreen-map.bin"

.segment "MAIN_SPRITES"
        .incbin "src/sprites.bin"

.segment "SIDMUSIC"
        .incbin "src/Chariots_of_Fire.sid",$7e


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The MUni Race: https://github.com/ricardoquesada/c64-the-muni-race
;
; main screen
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __MAIN_CODE_LOAD__, __ABOUT_CODE_LOAD__, __SIDMUSIC_LOAD__
.import __MAIN_SPRITES_LOAD__, __GAME_CODE_LOAD__, __HIGH_SCORES_CODE_LOAD__

; from utils.s
.import clear_screen, clear_color, get_key, read_joy2, detect_pal_paln_ntsc
.import vic_video_type, start_clean

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
SPRITE_ANIMATION_SPEED = 8


.segment "CODE"
        jsr start_clean                 ; no basic, no kernal, no interrupts
        jsr detect_pal_paln_ntsc        ; pal, pal-n or ntsc?


        ; disable NMI
;       sei
;       ldx #<disable_nmi
;       ldy #>disable_nmi
;       sta $fffa
;       sta $fffb
;       cli

        jmp __MAIN_CODE_LOAD__
;       jmp __ABOUT_CODE_LOAD__

disable_nmi:
        rti

.segment "MAIN_CODE"
        sei

        lda #$01
        jsr clear_color
        jsr init_screen

        lda #%00001000                  ; no scroll,single-color,40-cols
        sta $d016

        lda $dd00                       ; Vic bank 2: $8000-$BFFF
        and #$fc
        ora #1
        sta $dd00

        lda #%00010010                  ; charset at $8800 (equal to $0800 for bank 0)
        sta $d018

        lda #%00011011                  ; disable bitmap mode, 25 rows, disable extended color
        sta $d011                       ; and vertical scroll in default position

        jsr init_color_wash

        lda #$00                        ; background & border color
        sta $d020
        sta $d021


        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda #01                         ; enable raster irq
        sta $d01a

        ldx #<irq_open_borders          ; next IRQ-raster vector
        ldy #>irq_open_borders          ; needed to open the top/bottom borders
        stx $fffe
        sty $ffff
        lda #$f9
        sta $d012

        lda $dc0d                       ; clear interrupts and ACK irq
        lda $dd0d
        asl $d019

        lda #$00                        ; turn off volume
        sta SID_Amp

        lda #$00                        ; default menu mode: main menu
        sta menu_mode
        sta selected_rider
        lda #SPRITE_ANIMATION_SPEED
        sta animation_delay

        lda #$00                        ; avoid garbage when opening borders
        sta $bfff                       ; should be $3fff, but I'm in the 2 bank

        cli


@main_loop:
        jsr color_wash

        ldy #$0a                        ; delay loop to make the color
:       ldx #$00                        ; washer slower
:       dex
        bne :-
        dey
        bne :--

        lda menu_mode
        beq @main_menu_mode

        jsr animate_rider               ; "choose rider" mode
        jsr read_joy2
        eor #$ff
        and #%00011100 ;                ; only care about left,right,fire
        beq @main_loop

        cmp #%00010000                  ; fire ?
        bne :+
        jmp __GAME_CODE_LOAD__

:
        jsr choose_new_rider            ; joystick moved to the left or right.  choose a new rider
        jmp @main_loop

@main_menu_mode:
        jsr get_key
        bcc @main_loop

        cmp #$40                        ; F1
        beq @set_choose_rider_mode
        cmp #$50                        ; F3
        beq @jump_high_scores
        cmp #$30                        ; F7
        beq @jump_about
        jmp @main_loop


@set_choose_rider_mode:
        jsr init_choose_rider_screen
        jsr init_choose_rider_sprites
        lda #$01
        sta menu_mode
        jmp @main_loop

@jump_high_scores:
        jmp __HIGH_SCORES_CODE_LOAD__
@jump_about:
        jmp __ABOUT_CODE_LOAD__


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; IRQ: irq_open_borders()
;------------------------------------------------------------------------------;
; used to open the top/bottom borders
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export irq_open_borders
irq_open_borders:
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        lda $d011                       ; open vertical borders trick
        and #$f7                        ; first switch to 24 cols-mode...
        sta $d011

:       lda $d012
        cmp #$ff
        bne :-

        lda $d011                       ; ...a few raster lines switch to 25 cols-mode again
        ora #$08
        sta $d011

        asl $d019

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
        lda main_menu_screen,x
        sta $8400,x
        lda main_menu_screen+$0100,x
        sta $8400+$0100,x
        lda main_menu_screen+$0200,x
        sta $8400+$0200,x
        lda main_menu_screen+$02e8,x
        sta $8400+$02e8,x
        inx
        bne @loop


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
        lda vic_video_type              ; ntsc, pal or paln?
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
; init_choose_rider_screen(void)
;------------------------------------------------------------------------------;
; displays the "choose rider" message
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_choose_rider_screen
        ldx #20
        ldy #19
@loop:
        ; overwrite starting from line 10. Lines 0-9 are still used: 10*40 = 400 = $0190
        ; total lines to write: 10
        .repeat 10,i
                lda choose_rider_screen + (40*i),x
                sta $8590 + (40*i),x            ; start screen: $8400 (vic bank 2). offset = $0190

                lda choose_rider_screen + (40*i),y
                sta $8590 + (40*i),y            ; start screen: $8400 (vic bank 2). offset = $0190
        .endrepeat

        jsr @delay

        iny
        dex
        bpl @loop
        rts

@delay:
        txa                             ; small delay to create a "sweeping" effect
        pha
        tya
        pha
        ldx #$12                        ; start of delay
:       ldy #$00
:       dey
        bne :-
        dex
        bne :--                         ; end of delay
        pla
        tay
        pla
        tax
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_choose_rider_sprites(void)
;------------------------------------------------------------------------------;
; displays the sprite riders
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_choose_rider_sprites

        lda VIC_SPR_ENA
        ora #%00000111                  ; enable sprites 1,2,3
        sta VIC_SPR_ENA

        lda #%00000011                  ; sprites 0,1: multicolor
        sta VIC_SPR_MCOLOR              ; sprites 2: hi res

        lda #%00000100                  ; sprite 2 expanded in X and Y
        sta VIC_SPR_EXP_X               ; expand X
        sta VIC_SPR_EXP_Y               ; expand Y

        lda #$0a                        ; multicolor values
        sta VIC_SPR_MCOLOR0
        lda #$0b
        sta VIC_SPR_MCOLOR1

        lda $d010                       ; sprite #2. set "x" 9th bit on
        ora #%00000010
        sta $d010

        lda #$48                        ; sprite #0: position x
        sta VIC_SPR0_X
        lda #$a4                        ; sprite #0: position y
        sta VIC_SPR0_Y
        lda __MAIN_SPRITES_LOAD__ + 64 * 0 + 63; sprite #0 color
        and #$0f
        sta VIC_SPR0_COLOR

        lda #$00                        ; sprites are located at $8000... First sprite pointer is 0
        sta $87f8                       ; sprite #0 pointer = 0

        lda #$0b                        ; sprite #1 position x
        sta VIC_SPR1_X
        lda #$a4                        ; sprite #1 position y
        sta VIC_SPR1_Y
        lda __MAIN_SPRITES_LOAD__ + 64 * 8 + 63 ; sprite #1 color
        and #$0f
        sta VIC_SPR1_COLOR
        lda #$08                        ; sprite #1 pointer = 8
        sta $87f9

        lda #$43                        ; sprite #2 position x
        sta VIC_SPR2_X
        lda #$a0                        ; sprite #2 position y
        sta VIC_SPR2_Y
        lda __MAIN_SPRITES_LOAD__ + 64 * 7 + 63 ; sprite #2 color
        and #$0f
        sta VIC_SPR2_COLOR
        lda #$07                        ; sprite #2 pointer = 7
        sta $87fa


        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_color_wash(void)
;------------------------------------------------------------------------------;
; sets the screen color already 40 "washed" colors, so that the scrolls
; starts at the right position.
; This code is similar to call `jsr color_wash` for 40 times faster
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
COLORWASH_START_LINE = 0
.proc init_color_wash
        ldx #00                         ; set color screen
        ldy #00
@loop:
        .repeat 9,i                     ; 9 lines to scroll, starting from line 0
                lda colors+(i*2),y
                sta $d800+40*(i+COLORWASH_START_LINE),x
        .endrepeat
        iny
        inx
        cpx #40
        bne @loop

        stx color_idx

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; color_wash(void)
;------------------------------------------------------------------------------;
; Scrolls the screen colors creating a kind of "rainbow" effect
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc color_wash
        ; scroll the colors
        ldx #0
@loop:
        .repeat 9,i                     ; 9 lines to scroll, starting from line COLORWASH_START_LINE
                lda $d800+40*(i+COLORWASH_START_LINE)+1,x
                sta $d800+40*(i+COLORWASH_START_LINE),x
        .endrepeat
        inx
        cpx #40                         ; 40 columns
        bne @loop

        ldy color_idx                   ; set the new colors at row 39

        lda colors,y                    ; sprite #2 color
        sta VIC_SPR2_COLOR              ; change color at this moment, in order to avoid
                                        ; doing "ldy color_idx" again

        .repeat 9,i
                lda colors,y
                sta $d800+40*(i+COLORWASH_START_LINE)+39
                iny
                iny
                tya
                and #$3f                ; 64 colors
                tay
        .endrepeat

        ldy color_idx                   ; set the new index color for the next iteration
        iny
        tya
        and #$3f                        ; 64 colors
        sta color_idx

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void animate_rider(void)
;------------------------------------------------------------------------------;
; animates the selected rider
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc animate_rider
        dec animation_delay
        beq @animate
        rts

@animate:
        lda #SPRITE_ANIMATION_SPEED
        sta animation_delay

        ldx selected_rider
        lda $87f8,x                     ; sprite #0 pointer
        eor #%00000001                  ; new spriter pointer
        sta $87f8,x
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void choose_new_rider(joystick)
;------------------------------------------------------------------------------;
; chooses a new rider
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc choose_new_rider
        cmp #%00001000
        beq @right

@left:
        ldx #$00
        beq :+

@right:
        ldx #$01
:
        lda @position_x,x
        sta VIC_SPR2_X                  ; set position X
        lda @position_9,x
        ora #%10000000                  ; sprite 7 must be On (it is the PAL/NTSC sprite)
        sta $d010                       ; set 9th for position X
        stx selected_rider
        rts

@position_x: .byte $43, $06             ; positions for the "select" sprite
@position_9: .byte %00000010, %00000110 ; based on which rider is selected
.endproc



menu_mode: .byte $00                    ; modes: $00: main menu, $01: choose rider menu
.export selected_rider
selected_rider: .byte $00               ; $00: cris holm, $01: krish labonte
animation_delay: .byte SPRITE_ANIMATION_SPEED

color_idx: .byte $00
colors:
        ; Color washer palette based on Dustlayer intro
        ; https://github.com/actraiser/dust-tutorial-c64-first-intro/blob/master/code/data_colorwash.asm
        .byte $09,$09,$09,$09,$02,$02,$02,$02
        .byte $08,$08,$08,$08,$0a,$0a,$0a,$0a
        .byte $0f,$0f,$0f,$0f,$07,$07,$07,$07
        .byte $01,$01,$01,$01,$01,$01,$01,$01
        .byte $01,$01,$01,$01,$01,$01,$01,$01
        .byte $07,$07,$07,$07,$0f,$0f,$0f,$0f
        .byte $0a,$0a,$0a,$0a,$08,$08,$08,$08
        .byte $02,$02,$02,$02,$09,$09,$09,$09
        .byte $00

main_menu_screen:
                ;0123456789|123456789|123456789|123456789|
        .repeat 20
        .byte $2a,$6a
        .endrepeat
        scrcode "*",170,"                                    *",170
        scrcode "*",170,"                                    *",170
        scrcode "*",170,"                                    *",170
        scrcode "*",170,"     tThHeE  mMuUnNiI  rRaAcCeE     *",170
        scrcode "*",170,"                                    *",170
        scrcode "*",170,"                                    *",170
        scrcode "*",170,"                                    *",170
        .repeat 20
        .byte $2a,$6a
        .endrepeat
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "      fF1",177," -      sStTaArRtT            "
        scrcode "                                        "
        scrcode "      fF3",179," - hHiIgGhH sScCoOrReEsS      "
        scrcode "                                        "
        scrcode "      fF7",183," -      aAbBoOuUtT            "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        ; splitting the macro in 3 since it has too many parameters
        scrcode "     ",64,96,"2",178,"0"
        scrcode          176,"1",177,"5",181
        scrcode                 "  rReEtTrRoO  mMoOeE     "

choose_rider_screen:
                ;0123456789|123456789|123456789|123456789|
        scrcode "                                        "
        scrcode "                                        "
        scrcode "        cChHoOoOsSeE  rRiIdDeErR        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "                                        "
        scrcode "   cChHrRiIsS               kKrRiIsS    "
        scrcode "    hHoOlLmM             lLaAbBoOnNtTeE "

.segment "MAIN_CHARSET"
        .incbin "res/font-boulderdash-1writer.bin"

.segment "MAIN_SPRITES"
        .incbin "res/sprites.prg",2


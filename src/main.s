;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; main screen
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; exported by the linker
.import __SIDMUSIC_LOAD__

.import roadrace_init, selectevent_init, scores_init, about_init
.import selectevent_loop
.import music_speed, PALB_MUSIC_SPEED, NTSC_MUSIC_SPEED, PALN_MUSIC_SPEED

; from exodecrunch.s
.import decrunch                                ; exomizer decrunch

; from utils.s
.import _crunched_byte_hi, _crunched_byte_lo    ; exomizer address
.import ut_get_key, ut_read_joy2
.import ut_vic_video_type, ut_start_clean
.import ut_clear_screen, ut_clear_color
.import menu_handle_events, menu_invert_row
.import music_patch_table_1

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

DEBUG = 0                               ; bitwise: 1=raster-sync code

.segment "HI_CODE"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export main_menu
.proc main_menu
        sei

        lda #0
        sta $d01a                       ; no raster interrups

        lda #0
        sta VIC_SPR_ENA                 ; no sprites while initing the screen

        lda #SCENE_STATE::MAIN_MENU     ; menu to display
        sta scene_state                 ; is "main menu"

        lda $dd00                       ; Vic bank 0: $0000-$3FFF
        and #$fc
        ora #3
        sta $dd00

        lda #%00011100                  ; charset at $3000, screen at $0400
        sta $d018


        lda #$00                        ; background & border color
        sta $d020
        sta $d021

        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda $dc0d                       ; clear interrupts and ACK irq
        lda $dd0d
        asl $d019

        lda #$00                        ; turn off volume
        sta SID_Amp
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


        ldx #<irq_timer                 ; irq for timer
        ldy #>irq_timer
        stx $fffe
        sty $ffff

        cli

main_loop:
        lda sync_timer_irq
        beq main_loop


.if (::DEBUG & 1)
        inc $d020
.endif
        dec sync_timer_irq

        jsr MUSIC_PLAY
        jsr animate_sprites
        jsr menu_handle_events          ; will disable/enable interrupts

.if (::DEBUG & 1)
        inc $d020
.endif

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
        ldx #<(SCREEN0_BASE + 40 * 17 + 5)
        ldy #>(SCREEN0_BASE + 40 * 17 + 5)
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
        beq jump_about                  ; item 2? about
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
        jmp set_mainmenu


jump_about:
        lda #SCENE_STATE::ABOUT_MENU
        sta scene_state

        jsr about_init                  ; takes over of the mainloop
                                        ; no need to update the jmp table
set_mainmenu:
        lda #SCENE_STATE::MAIN_MENU     ; restore stuff modifying by scores
        sta scene_state

        sei

        ldx #<irq_timer                 ; restore irq for timer
        ldy #>irq_timer
        stx $fffe
        sty $ffff

        jsr init_screen
        jsr mainmenu_init
        cli

        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq_timer
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_timer
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        lda $dc0d                       ; clears CIA interrupts, in particular timer A
        inc sync_timer_irq

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

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


        ldx #<mainscreen_charset_exo    ; decrunch main screen colors
        ldy #>mainscreen_charset_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch                    ; uncrunch


        inc $01                         ; $35: RAM + IO ($D000-$DFFF)

        jmp music_patch_table_1         ; convert to PAL if needed
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void init_screen()
;------------------------------------------------------------------------------;
; paints the screen with the "main menu" screen
; MUST BE CALLED after init_data()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen
        ldx #0

l0:
        lda mainscreen_map,x
        sta SCREEN0_BASE,x
        tay
        lda mainscreen_colors,y
        sta $d800,x

        lda mainscreen_map + $0100,x
        sta SCREEN0_BASE + $0100,x
        tay
        lda mainscreen_colors,y
        sta $d900,x

        lda mainscreen_map + $0200,x
        sta SCREEN0_BASE + $0200,x
        tay
        lda mainscreen_colors,y
        sta $da00,x

        lda mainscreen_map + $02e8,x
        sta SCREEN0_BASE + $02e8,x
        tay
        lda mainscreen_colors,y
        sta $dae8,x

        inx
        bne l0


        lda #$0b                         ; set color for copyright
        ldx #39
:       sta $d800+24*40,x
        dex
        bpl :-


        lda #0
        sta VIC_SPR_EXP_X
        sta VIC_SPR_EXP_Y
        lda #%00011111                  ; enable sprites
        sta VIC_SPR_ENA
        lda #%00010000                  ; set sprite #7 x-pos 9-bit ON
        sta VIC_SPR_HI_X                ; since x pos > 255
        lda #%00000111
        sta VIC_SPR_MCOLOR              ; enable multicolor
        lda #10                         ; sprites multicolor values
        sta VIC_SPR_MCOLOR0
        lda #9
        sta VIC_SPR_MCOLOR1

        ldx #0                          ; setup BC's Tire sprite
        ldy #0                          ; and mask for the N and M in UNI GAMES
l1:     lda sprite_x,x
        sta VIC_SPR0_X,y                ; setup sprite X
        lda sprite_y,x
        sta VIC_SPR0_Y,y                ; setup sprite Y
        lda sprite_color,x
        sta VIC_SPR0_COLOR,x            ; setup sprite color
        lda sprite_frame,x
        sta SPRITES_PTR0,x              ; setup sprite pointer
        inx
        iny
        iny
        cpx #5
        bne l1

        lda ut_vic_video_type           ; ntsc, pal or paln?
        cmp #$01                        ; Pal ?
        beq @end                        ; yes.
        cmp #$2f                        ; Pal-N?
        beq @paln                       ; yes
        cmp #$2e                        ; NTSC Old?
        beq @ntscold                    ; yes

        lda #<NTSC_MUSIC_SPEED
        sta music_speed
        lda #>NTSC_MUSIC_SPEED
        sta music_speed+1
        bne @end

@ntscold:
        lda #<NTSC_MUSIC_SPEED
        sta music_speed
        lda #>NTSC_MUSIC_SPEED
        sta music_speed+1
        bne @end
@paln:
        lda #<PALN_MUSIC_SPEED
        sta music_speed
        lda #>PALN_MUSIC_SPEED
        sta music_speed+1
@end:
        rts

        ; variables for BC's Tire sprites
sprite_x:
        .byte 183,176,176,176,296-256
sprite_y:
        .byte 48,61,81,114,58
sprite_color:
        .byte 11,11,11,11,11
sprite_frame:
        .byte SPRITES_POINTER + 40      ; BC's head
        .byte SPRITES_POINTER + 41      ; BC's body
        .byte SPRITES_POINTER + 42      ; BC's wheel
        .byte SPRITES_POINTER + 45      ; mask for M
        .byte SPRITES_POINTER + 46      ; mask for N

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
; void animate_sprites(void)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc animate_sprites

        dec delay
        bne end

        ldx frame_idx                   ; switches between 0 and 1
        lda sprite0_frames,x
        sta SPRITES_PTR0                ; new frame for sprite 0
        lda sprite2_frames,x
        sta SPRITES_PTR0 + 2            ; new frame for sprite 2

        txa
        eor #%00000001
        sta frame_idx

        lda #8
        sta delay

end:    rts
delay:          .byte 8
frame_idx:      .byte 0
sprite0_frames:
        .byte SPRITES_POINTER + 40
        .byte SPRITES_POINTER + 43
sprite2_frames:
        .byte SPRITES_POINTER + 42
        .byte SPRITES_POINTER + 44
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export sync_timer_irq
sync_timer_irq:     .byte 0            ; enabled when timer is triggred (used by music)

scene_state:        .byte SCENE_STATE::MAIN_MENU ; scene state. which scene to render

mainscreen_map:
    .incbin "src/mainscreen-map.bin"

.export mainscreen_colors
mainscreen_colors:
    .incbin "src/mainscreen-colors.bin"


.segment "COMPRESSED_DATA"
        ; export it at 0x1000
        .incbin "src/maintitle_music.sid.exo"
mainsid_exo:

        ; export it at 0x3000
        .incbin "src/mainscreen-charset.prg.exo"
mainscreen_charset_exo:

        .byte 0             ; ignore

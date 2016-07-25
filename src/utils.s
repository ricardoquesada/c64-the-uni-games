;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; Collection of utils functions
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

.segment "HI_CODE"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; ut_clear_screen(int char_used_to_clean)
;------------------------------------------------------------------------------;
; Args: A char used to clean the screen.
; Clears the screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export ut_clear_screen
.proc ut_clear_screen
        ldx #0
:       sta $0400,x                     ; clears the screen memory
        sta $0500,x                     ; but assumes that VIC is using bank 0
        sta $0600,x                     ; otherwise it won't work
        sta $06e8,x
        inx                             ; 1000 bytes = 40*25
        bne :-

        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; ut_clear_color(int foreground_color)
;------------------------------------------------------------------------------;
; Args: A color to be used. Only lower 3 bits are used.
; Changes foreground RAM color
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export ut_clear_color
.proc ut_clear_color
        ldx #0
:       sta $d800,x                     ; clears the screen color memory
        sta $d900,x                     ; works for any VIC bank
        sta $da00,x
        sta $dae8,x
        inx                             ; 1000 bytes = 40*25
        bne :-

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; char ut_get_key(void)
;------------------------------------------------------------------------------;
; reads a key from the keyboard
; Carry set if keyboard detected. Othewise Carry clear
; Returns key in A
; Code by Groepaz. Copied from:
; http://codebase64.org/doku.php?id=base:reading_the_keyboard&s[]=keyboard
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export ut_get_key
.proc ut_get_key
        lda #$0
        sta $dc03                       ; port b ddr (input)
        lda #$ff
        sta $dc02                       ; port a ddr (output)

        lda #$00
        sta $dc00                       ; port a
        lda $dc01                       ; port b
        cmp #$ff
        beq @nokey
        tay                             ; got column

        lda #$7f
        sta @nokey2+1
        ldx #8
@nokey2:
        lda #0
        sta $dc00                       ; port a

        sec
        ror @nokey2+1
        dex
        bmi @nokey

        lda $dc01                       ; port b
        cmp #$ff
        beq @nokey2

        txa                             ; got row in X
        ora @columntab,y

        sec
        rts

@nokey:
        clc
        rts

@columntab:
        .repeat 256,count
                .if count = ($ff-$80)
                        .byte $70
                .elseif count = ($ff-$40)
                        .byte $60
                .elseif count = ($ff-$20)
                        .byte $50
                .elseif count = ($ff-$10)
                        .byte $40
                .elseif count = ($ff-$08)
                        .byte $30
                .elseif count = ($ff-$04)
                        .byte $20
                .elseif count = ($ff-$02)
                        .byte $10
                .elseif count = ($ff-$01)
                        .byte $00
                .else
                        .byte $ff
                .endif
        .endrepeat

.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; char ut_detect_pal_paln_ntsc(void)
;------------------------------------------------------------------------------;
; It counts how many rasterlines were drawn in 312*63 (19656) cycles.
; 312*63-1 is passed to the timer since it requires one less.
;
; In PAL,      (312 by 63)  19656/63 = 312  -> 312 % 312   (00, $00)
; In PAL-N,    (312 by 65)  19656/65 = 302  -> 302 % 312   (46, $2e)
; In NTSC,     (263 by 65)  19656/65 = 302  -> 302 % 263   (39, $27)
; In NTSC Old, (262 by 64)  19656/64 = 307  -> 307 % 262   (45, $2d)
;
; Return values:
;   $01 --> PAL
;   $2F --> PAL-N
;   $28 --> NTSC
;   $2e --> NTSC-OLD
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export ut_vic_video_type
ut_vic_video_type: .byte $01

.export ut_detect_pal_paln_ntsc
.proc ut_detect_pal_paln_ntsc
        sei                             ; disable interrupts

        lda #0
        sta $d011                       ; turn off display to disable badlines

:       lda $d012                       ; wait for start of raster (more stable results)
:       cmp $d012
        beq :-
        bmi :--

        lda #$00
        sta $dc0e                       ; stop timer A, in case it is running

        lda #$00
        sta $d01a                       ; disables raster IRQ
        lda #$7f
        sta $dc0d                       ; disables timer A and B IRQ
        sta $dd0d

        lda #$00
        sta sync

        ldx #<(312*63-1)                ; set the timer for PAL
        ldy #>(312*63-1)
        stx $dc04
        sty $dc05

        lda #%00001001                  ; one-shot only
        sta $dc0e

        ldx #<timer_irq
        ldy #>timer_irq
        stx $fffe
        sty $ffff

        lda $dc0d                       ; ACK possible timer A and B interrupts
        lda $dd0d


        lda #$81
        sta $dc0d                       ; enable timer A interrupts
        cli

:       lda sync
        beq :-

        lda #$1b                        ; enable the display again
        sta $d011
        lda ut_vic_video_type           ; load ret value
        rts

timer_irq:
        pha                             ; only saves A

        lda $dc0d                       ; clear timer A interrupt

        lda $d012
        sta ut_vic_video_type

        inc sync
        cli

        pla                             ; restores A
        rti

sync:  .byte $00

.endproc

.export ut_start_clean
.proc ut_start_clean
        sei                             ; disable interrupts
        lda #$35                        ; no basic, no kernal
        sta $01

        lda #$00
        sta $d01a                       ; no raster IRQ
        lda #$7f
        sta $dc0d                       ; no timer A and B IRQ
        sta $dd0d

        asl $d019                       ; ACK raster interrupt
        lda $dc0d                       ; ACK timer A interrupt
        lda $dd0d                       ; ACK timer B interrupt
        cli
        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void ut_sync_irq_timer()
;------------------------------------------------------------------------------;
; code taken from zoo mania game source code: http://csdb.dk/release/?id=121860
; and values from here:
;       http://codebase64.org/doku.php?id=base:playing_music_on_pal_and_ntsc
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export ut_sync_irq_timer
.proc ut_sync_irq_timer

PAL_TIMER := (312*63)-1                 ; raster lines (312) * cycles_per_line(63) = 19656
PAL_N_TIMER := $4fc2-1                  ; 19656 / (985248/1023445) - 1
NTSC_TIMER := $4fb2                     ; 19656 / (985248/1022727) - 1


        lda #$00
        sta $dc0e                       ; stop timer A

        ldy #$08
@wait:
        cpy $d012                       ; wait for a complete
        bne @wait                       ; raster scan
        lda $d011                       ; but, why is this needed ???
        bmi @wait

        lda ut_vic_video_type
        cmp #$01
        beq @pal
        cmp #$2f
        beq @paln

        lda #<NTSC_TIMER                ; 50hz on NTSC
        ldy #>NTSC_TIMER                ; it is an NTSC
        jmp @end

@paln:                                  ; it is a PAL-N (drean commodore 64)
        lda #<PAL_N_TIMER
        ldy #>PAL_N_TIMER
        jmp @end

@pal:
        lda #<PAL_TIMER                 ; 50hz on PAL
        ldy #>PAL_TIMER

@end:
        sta $dc04                       ; set timer A (low)
        sty $dc05                       ; set timer A (hi)

        lda #$11
        sta $dc0e                       ; start timer A
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void ut_setup_tod()
;------------------------------------------------------------------------------;
; code taken from:
; http://codebase64.org/doku.php?id=base:initialize_tod_clock_on_all_platforms;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export ut_setup_tod
.proc ut_setup_tod
        sei
        lda #<@INT_NMI          ; Setup NMI vector
        sta $fffa               ; to catch unwanted NMIs
        lda #>@INT_NMI          ;
        sta $fffb               ;
        lda #$35                ; Bank out KERNAL
        sta $01                 ; so new NMI vector is active

        lda #0
        sta $d011               ; Turn off display to disable badlines
        sta $dc0e               ; Set TOD Clock Frequency to 60Hz
        sta $dc0f               ; Enable Set-TOD-Clock
        sta $dc0b               ; Set TOD-Clock to 0 (hours)
        sta $dc0a               ; - (minutes)
        sta $dc09               ; - (seconds)
        sta $dc08               ; - (deciseconds)

        lda $dc08               ;
:       cmp $dc08               ; Sync raster to TOD Clock Frequency
        beq :-                  ;

        ldx #0                  ; Prep X and Y for 16 bit
        ldy #0                  ;  counter operation
        lda $dc08               ; Read deciseconds
:       inx                     ; 2   -+
        bne :+                  ; 2/3  | Do 16 bit count up on
        iny                     ; 2    | X(lo) and Y(hi) regs in a 
        jmp :++                 ; 3    | fixed cycle manner
:       nop                     ; 2    |
        nop                     ; 2   -+
:       cmp $dc08               ; 4 - Did 1 decisecond pass?
        beq :---                ; 3 - If not, loop-di-doop
                                ; Each loop = 16 cycles
                                ; If less than 118230 cycles passed, TOD is 
                                ; clocked at 60Hz. If 118230 or more cycles
                                ; passed, TOD is clocked at 50Hz.
                                ; It might be a good idea to account for a bit
                                ; of slack and since every loop is 16 cycles,
                                ; 28*256 loops = 114688 cycles, which seems to be
                                ; acceptable. That means we need to check for
                                ; a Y value of 28.

        cpy #28                 ; Did 114688 cycles or less go by?
        bcc :+                  ; - Then we already have correct 60Hz $dc0e value
        lda #$80                ; Otherwise, we need to set it to 50Hz
        sta $dc0e
:
        lda #$1b                ; Enable the display again
        sta $d011

        rts

@INT_NMI:
        rti
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; get_crunched_byte
; The decruncher jsr:s to the get_crunched_byte address when it wants to
; read a crunched byte. This subroutine has to preserve x and y register
; and must not modify the state of the carry flag.
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.export get_crunched_byte
.export _crunched_byte_lo
.export _crunched_byte_hi
get_crunched_byte:
        lda _crunched_byte_lo
        bne @_byte_skip_hi
        dec _crunched_byte_hi
@_byte_skip_hi:
;        dec $01
;        sta $d020
;        inc $01

        dec _crunched_byte_lo
_crunched_byte_lo = * + 1
_crunched_byte_hi = * + 2
        lda $caca                       ; self-modify. needs to be set correctly before
        rts			                    ; decrunch_file is called.
; $caca needs to point to the address just after the address
; of the last byte of crunched data.


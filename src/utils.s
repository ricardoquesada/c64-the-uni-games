;
; Collection of utils functions
;

.segment "CODE"

;--------------------------------------------------------------------------
; clear_screen(int char_used_to_clean)
;--------------------------------------------------------------------------
; Args: A char used to clean the screen.
; Clears the screen
;--------------------------------------------------------------------------
.export clear_screen
.proc clear_screen
	ldx #0
:
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $06e8,x
	inx
	bne :-

	rts
.endproc


;--------------------------------------------------------------------------
; clear_color(int foreground_color)
;--------------------------------------------------------------------------
; Args: A color to be used. Only lower 3 bits are used.
; Changes foreground RAM color
;--------------------------------------------------------------------------
.export clear_color
.proc clear_color
	ldx #0
:
	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $dae8,x
	inx
	bne :-

	rts
.endproc


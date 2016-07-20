;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; game scene
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; zp
MENU_MAX_ITEMS = $41                                    ; total number of items
MENU_CURRENT_ITEM = $42                                 ; item idx  0<idx<max_items
MENU_BYTES_BETWEEN_ITEMS = $43                          ; 40 for one after another
MENU_ITEM_LEN = $44                                     ; 40 for complete line
MENU_CURRENT_ROW_ADDR = $45 ; and $46                   ; screen ptr to current item
MENU_EXEC_ADDR = $47  ; and $48                         ; When button is pressed, what to do


; variables
zp_tmp = $50                                            ; 16 bytes ($50 - $5f) for tmp vars
zp_mc_color = $60

; game constants
BANK_BASE = $0000
SCREEN0_BASE = BANK_BASE + $0400                        ; screen address
SPRITES_BASE = BANK_BASE + $2400                        ; Sprite 0 at $2400
                                                        ; reserved space for 48 sprites
                                                        ; from $2400 to $3000
SPRITES_POINTER = <((SPRITES_BASE .MOD $4000) / 64)     ; Sprite 0 at 144
SPRITES_PTR0 = SCREEN0_BASE + 1016                      ; right after the screen, at $7f8
CHARSET_BASE = BANK_BASE + $3000                        ; place for charset
MUSIC_INIT = $1000
MUSIC_PLAY = $1003

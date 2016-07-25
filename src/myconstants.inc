;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; game scene
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; Global Enums and constants
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.enum SCORES_CAT
        ROAD_RACE
        CYCLO_CROSS
        CROSS_COUNTRY
.endenum

.enum SCORES_MODE
        CYCLE
        NEW_HS
.endenum

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

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; ZP variables
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
MENU_MAX_ITEMS = $41                                    ; total number of items
MENU_CURRENT_ITEM = $42                                 ; item idx  0<idx<max_items
MENU_BYTES_BETWEEN_ITEMS = $43                          ; 40 for one after another
MENU_ITEM_LEN = $44                                     ; 40 for complete line
MENU_CURRENT_ROW_ADDR = $45 ; and $46                   ; screen ptr to current item
MENU_EXEC_ADDR = $47  ; and $48                         ; When button is pressed, what to do


; variables
zp_tmp = $50                                            ; 16 bytes ($50 - $5f) for tmp vars
zp_tmp00 = $50
zp_tmp01 = $51
zp_tmp02 = $52
zp_tmp03 = $53
zp_tmp04 = $54
zp_tmp05 = $55
zp_tmp06 = $56
zp_tmp07 = $57
zp_tmp08 = $58
zp_tmp09 = $59
zp_tmp0a = $5a
zp_tmp0b = $5b
zp_tmp0c = $5c
zp_tmp0d = $5d
zp_tmp0e = $5e
zp_tmp0f = $5f

zp_mc_color = $60                                       ; .byte

zp_jump_idx_p1 = $61                                    ; .byte  sine pointer for jump/down sequence
zp_jump_idx_p2 = $62                                    ; .byte  sine pointer for jump/down sequence
zp_game_state = $63                                     ; .byte  default: GAME_STATE::GET_SET_GO
zp_p1_state = $64                                       ; .byte  default: PLAYER_STATE::GET_SET_GO
zp_p2_state = $65                                       ; .byte  default: PLAYER_STATE::GET_SET_GO
zp_p1_finished = $66                                    ; .byte  default FINISH_STATE::NOT_FINISHED
zp_p2_finished = $67                                    ; .byte  default: FINISH_STATE::NOT_FINISHED
                                                        ; don't mix p_finished and p_state together. 0=Not finished, 1=Finished Winner, 2=Finished Loser
                                                        ; since scrolling should still happen while player is finished
                                                        ;
zp_smooth_scroll_x_p1 = $68                             ; .word  MSB is used for $d016
zp_smooth_scroll_x_p2 = $6a                             ; .word  MSB is used for $d016
zp_scroll_idx_p1 = $6c                                  ; .word  initialized in init_game
zp_scroll_idx_p2 = $6e                                  ; .word
zp_scroll_speed_p1 = $70                                ; .word  $0100 = normal speed. $0200 = 2x speed. $0080 = half speed
zp_scroll_speed_p2 = $72                                ; .word  $0100 = normal speed. $0200 = 2x speed. $0080 = half speed

zp_sync_raster_anims = $74                              ; .byte
zp_sync_raster_bottom_p1 = $75                          ; .byte
zp_sync_raster_bottom_p2 = $76                          ; .byte

zp_expected_joy1_idx = $77                              ; .byte 0
zp_expected_joy2_idx = $78                              ; .byte 0

zp_resistance_idx_p2 = $79                              ; .byte 0  index in resistance table
zp_resistance_idx_p1 = $7a                              ; .byte 0  index in resistance table

zp_frame_idx_p1 = $7b                                   ; .byte 0  index for frame p1
zp_frame_idx_p2 = $7c                                   ; .byte 0  index for frame p2

zp_animation_delay_p1 = $7d                             ; .byte ACTOR_ANIMATION_SPEED
zp_animation_delay_p2 = $7e                             ; .byte ACTOR_ANIMATION_SPEED
zp_animation_idx_p1 = $7f                               ; .byte 0  index in the animation table
zp_animation_idx_p2 = $80                               ; .byte 0  index in the animation table

zp_background_color = $81                               ; .byte 1  $d021 color for game

zp_remove_go_counter = $82                              ; .byte $80  delay to remove "go" label

zp_computer_fires_idx = $83                             ; .byte 0  index for computer_fires_lo/hi

zp_computer_speed = $84                                 ; .byte AUTO_SPEED but each level can define one. 
zp_computer_delay = $85                                 ; .byte 1
zp_joy1_delay = $85                                     ; .byte 1 same as zp_computer_delay since they can't be used at the same time
zp_joy2_delay = $86                                     ; .byte 1

zp_abort = $87                                          ; .byte 0 if 0, "abort" was pressed

zp_hs_ptr_lo = $90                                      ; .byte  used for sta (),x
zp_hs_ptr_hi = $91                                      ; .byte
zp_hs_category = $92                                    ; .byte SCORES_CAT::ROAD_RACE
                                                        ;       SCORES_CAT::CYCLO_CROSS
                                                        ;       SCORES_CAT::CROSS_COUNTRY
zp_hs_mode = $93                                        ; .byte SCORES_MODE::CYCLE, SCORES_MODE::NEW_HS

zp_hs_latest_score = $94                                ; 4 .bytes  minutes, seconds, seconds, deci-seconds


scores_entries = $200                                   ; from $200 to $280


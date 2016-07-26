;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; The Uni Games: https://github.com/ricardoquesada/c64-the-uni-games
;
; data
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; here goes the "empty" space that can be used during the game to put stuff
; and can be used by "intro" and other stuff to put volatile (one-time only) data

.segment "SIDMUSIC"
        .res 5120,0

.segment "SPRITES"
        ; 3k in total
        ; ASSERT(* = $2400)
        .incbin "src/sprites.bin"               ; 48 * 64

.segment "UNCOMPRESSED_DATA"
        ; 13k in total
        ; ASSERT(* = $3000)
        ; WARNING: This data will get overwritten by main.s
        ; should only be used by volatile data used by intro
        .incbin "src/intro-charset.bin"         ; 2k

        ; ASSERT(* = $3800)
        .res 1024*11,0                          ; 11k



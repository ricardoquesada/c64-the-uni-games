import os


with open("mainscreen.vchar64proj", "rb") as orig:
    with open("mainscreen2.vchar64proj", "wb") as new:

# read until data
#        char id[5];                 // must be VChar
#        char version;               // must be 2
#        char colors[4];             // BGR, MC1, MC2, RAM.
#        char vic_res;               // 0 = Hi Resolution, 1 = Multicolour.
#
#        quint16 num_chars;          // 16-bits, Number of chars - 1 (low, high).
#
#        quint8 tile_width;          // between 1-8
#        quint8 tile_height;         // between 1-8
#        quint8 char_interleaved;    // between 1-128
#
#        // until here, it shares same structure as version 1
#
#        char color_mode;            // 0 = Global, 1 = Per Tile
#
#        quint16 map_width;          // 16-bit Map width (low, high).
#        quint16 map_height;         // 16-bit Map height (low, high).
#
#        char reserved[11];           // Must be 32 bytes in total

        buf = orig.read(32 + 8 * 256 + 256)
        new.write(buf)

        invert = orig.read(40*14)
        invert2 = bytearray(i for i in invert)
        for i in range(len(invert2)):
            invert2[i] = invert2[i] | 0x80 if invert2[i] < 0x80 else invert2[i] & 0x7f

        new.write(invert2)

        buf = orig.read(40*11)
        new.write(buf)


.SILENT:

.PHONY: all clean res run

D64_IMAGE = "bin/unigames.d64"
C1541 = c1541
X64 = x64

all: res bin
bin: unigames d64 run

SRC=src/intro.s src/main.s src/about.s src/utils.s src/game.s src/highscores.s \
	src/exodecrunch.s src/selectevent.s src/menu.s src/about.s src/music_table.s \
	src/instructions.s src/data.s

res:
	echo "Compressing resources..."
	-exomizer mem -q res/mainscreen-charset.prg -o src/mainscreen-charset.prg.exo
	-exomizer mem -q res/level-roadrace-map.prg -o src/level-roadrace-map.prg.exo
	-exomizer mem -q res/level-roadrace-colors.prg -o src/level-roadrace-colors.prg.exo
	-exomizer mem -q res/level-roadrace-charset.prg -o src/level-roadrace-charset.prg.exo
	-exomizer mem -q res/level-cyclocross-map.prg -o src/level-cyclocross-map.prg.exo
	-exomizer mem -q res/level-cyclocross-colors.prg -o src/level-cyclocross-colors.prg.exo
	-exomizer mem -q res/level-cyclocross-charset.prg -o src/level-cyclocross-charset.prg.exo
	-exomizer mem -q res/level-crosscountry-map.prg -o src/level-crosscountry-map.prg.exo
	-exomizer mem -q res/level-crosscountry-colors.prg -o src/level-crosscountry-colors.prg.exo
	-exomizer mem -q res/level-crosscountry-charset.prg -o src/level-crosscountry-charset.prg.exo
	-exomizer mem -q res/intro-map.prg -o src/intro-map.prg.exo
	-cp res/intro-charset.bin src
	-cp res/sprites.bin src
	-cp res/select_event-map.bin src
	-cp res/number_of_players-map.bin src
	-cp res/mainscreen-map.bin src
	-cp res/mainscreen-colors.bin src
	-cp res/about-map.bin src
	-cp res/hiscores-map.bin src
	-cp res/instructions-map.bin src
	-cp res/Popcorn_2.exo src/maintitle_music.sid.exo
	-cp res/Action_G.exo src/music_cyclocross.sid.exo
	-cp res/12_Bar_Blues.exo src/music_roadrace.sid.exo
	-cp res/Seek_and_Destroy.exo src/music_crosscountry.sid.exo

unigames: ${SRC}
	echo "Compiling..."
	cl65 -d -g -Ln bin/$@.sym -o bin/$@.prg -u __EXEHDR__ -t c64 -C $@.cfg $^
	echo "Compressing executable..."
	exomizer sfx sys -x1 -Di_line_number=2016 -o bin/$@_exo.prg bin/$@.prg

d64:
	echo "Generating d64 file..."
	$(C1541) -format "the uni games,rq" d64 $(D64_IMAGE)
	$(C1541) $(D64_IMAGE) -write bin/unigames_exo.prg unigames
	$(C1541) $(D64_IMAGE) -write bin/unigames-scores
	$(C1541) $(D64_IMAGE) -list

run:
	echo "Running game"
	$(X64) -verbose -moncommands bin/unigames.sym bin/unigames_exo.prg
#	$(X64) -verbose -moncommands bin/unigames.sym $(D64_IMAGE)

clean:
	rm -f src/*.o bin/*.sym bin/*.prg $(D64_IMAGE)


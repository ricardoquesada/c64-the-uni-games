.SILENT:

.PHONY: all clean res

D64_IMAGE = "bin/unigames.d64"
C1541 = c1541
X64 = x64

all: unigames

SRC=src/intro.s src/main.s src/about.s src/utils.s src/game.s src/highscores.s src/exodecrunch.s src/selectevent.s src/menu.s src/about.s

res:
	exomizer mem -q res/sprites.prg -o src/sprites.prg.exo
	exomizer mem -q res/mainscreen-charset.prg -o src/mainscreen-charset.prg.exo
	exomizer mem -q res/level1-map.prg -o src/level1-map.prg.exo
	exomizer mem -q res/level1-colors.prg -o src/level1-colors.prg.exo
	exomizer mem -q res/level1-charset.prg -o src/level1-charset.prg.exo
	exomizer mem -q res/level-cyclocross-map.prg -o src/level-cyclocross-map.prg.exo
	exomizer mem -q res/level-cyclocross-colors.prg -o src/level-cyclocross-colors.prg.exo
	exomizer mem -q res/level-cyclocross-charset.prg -o src/level-cyclocross-charset.prg.exo
	exomizer mem -q res/intro-charset.prg -o src/intro-charset.prg.exo
	exomizer mem -q res/intro-map.prg -o src/intro-map.prg.exo
	cp res/select_event-map.bin src
	cp res/mainscreen-map.bin src
	cp res/mainscreen-colors.bin src
	cp res/about-map.bin src
	cp res/hiscores-map.bin src
	cp res/Popcorn_2.exo src/maintitle_music.sid.exo
	cp res/Action_G.exo src/game_music1.sid.exo
	cp res/12_Bar_Blues.exo src/game_music2.sid.exo

unigames: ${SRC}
	cl65 -d -g -Ln bin/$@.sym -o bin/$@.prg -u __EXEHDR__ -t c64 -C $@.cfg $^
	exomizer sfx sys -x1 -Di_line_number=2016 -o bin/$@_exo.prg bin/$@.prg
	$(C1541) -format "unigames,rq" d64 $(D64_IMAGE)
	$(C1541) $(D64_IMAGE) -write bin/$@_exo.prg
	$(C1541) $(D64_IMAGE) -list
	$(X64) -moncommands bin/$@.sym $(D64_IMAGE)

clean:
	rm -f src/*.o bin/*.sym bin/*.prg $(D64_IMAGE)


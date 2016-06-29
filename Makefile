.SILENT:

.PHONY: all clean

D64_IMAGE = "bin/unigames.d64"
C1541 = c1541
X64 = x64

all: unigames

SRC=src/main.s src/about.s src/utils.s src/game.s src/highscores.s src/exodecrunch.s src/selectevent.s src/menu.s

exo_res:
	exomizer mem -q res/sprites.prg -o src/sprites.prg.exo
	exomizer mem -q res/mainscreen-map.prg -o src/mainscreen-map.prg.exo
	exomizer mem -q res/mainscreen-charset.prg -o src/mainscreen-charset.prg.exo
	exomizer mem -q res/mainscreen-colors.prg -o src/mainscreen-colors.prg.exo
	exomizer mem -q res/select_event-map.prg -o src/select_event-map.prg.exo
	exomizer mem -q res/level1-map.prg -o src/level1-map.prg.exo
	exomizer mem -q res/level1-colors.prg -o src/level1-colors.prg.exo
	exomizer mem -q res/level1-charset.prg -o src/level1-charset.prg.exo
	exomizer mem -q res/level-cyclocross-map.prg -o src/level-cyclocross-map.prg.exo
	exomizer mem -q res/level-cyclocross-colors.prg -o src/level-cyclocross-colors.prg.exo
	exomizer mem -q res/level-cyclocross-charset.prg -o src/level-cyclocross-charset.prg.exo

unigames: ${SRC}
	cl65 -d -g -Ln bin/$@.sym -o bin/$@.prg -u __EXEHDR__ -t c64 -C $@.cfg $^
	exomizer sfx sys -x1 -Di_line_number=2016 -o bin/$@_exo.prg bin/$@.prg
	$(C1541) -format "unigames,rq" d64 $(D64_IMAGE)
	$(C1541) $(D64_IMAGE) -write bin/$@_exo.prg
	$(C1541) $(D64_IMAGE) -list
	$(X64) -moncommands bin/$@.sym $(D64_IMAGE)

clean:
	rm -f src/*.o bin/*.sym bin/*.prg $(D64_IMAGE)


# Makefile copied from Zoo Mania game

.SILENT:

DIST_IMAGE = "bin/unigames_dist.d64"
DEV_IMAGE = "bin/unigames_dev.d64"
C1541 = c1541
X64 = x64

all: dev dist

SRC=src/main.s src/about.s src/utils.s src/roadrace.s src/highscores.s src/exodecrunch.s src/selectevent.s src/menu.s
prg:
	cl65 -d -g -Ln bin/unigames.sym -u __EXEHDR__ -t c64 -o bin/unigames.prg -C unigames.cfg ${SRC}

exo_res:
	exomizer mem -q res/sprites.prg -o src/sprites.prg.exo
	exomizer mem -q res/mainscreen-map.prg -o src/mainscreen-map.prg.exo
	exomizer mem -q res/select_event-map.prg -o src/select_event-map.prg.exo
	exomizer mem -q res/level1-map.prg -o src/level1-map.prg.exo
	exomizer mem -q res/level1-colors.prg -o src/level1-colors.prg.exo

dev: prg exo_res
	$(C1541) -format "unigames,rq" d64 $(DEV_IMAGE)
	$(C1541) $(DEV_IMAGE) -write bin/unigames.prg
	$(C1541) $(DEV_IMAGE) -list

dist: prg exo_res
	exomizer sfx sys -o bin/unigames_exo.prg bin/unigames.prg
	$(C1541) -format "unigames dist,rq" d64 $(DIST_IMAGE)
	$(C1541) $(DIST_IMAGE) -write bin/unigames_exo.prg "unigames"
	$(C1541) $(DIST_IMAGE) -list

test: dev
	$(X64) -moncommands bin/unigames.sym $(DEV_IMAGE)

testdist: dist
	$(X64) -moncommands bin/unigames.sym $(DIST_IMAGE)

clean:
	rm -f src/*.o bin/unigames.prg bin/unigames_exo.prg bin/unigames.sym $(DEV_IMAGE) $(DIST_IMAGE)



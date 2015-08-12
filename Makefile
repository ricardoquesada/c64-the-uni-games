# Makefile copied from Zoo Mania game

.SILENT:

DIST_IMAGE = "therace_dist.d64"
DEV_IMAGE = "therace_dev.d64"
C1541 = c1541
X64 = x64

all: dev dist

SRC=src/main.s src/about.s src/utils.s src/game.s src/highscores.s
prg:
	cl65 -d -g -Ln therace.sym -u __EXEHDR__ -t c64 -o therace.prg -C therace.cfg ${SRC}

dev: prg
	$(C1541) -format "therace,rq" d64 $(DEV_IMAGE)
	$(C1541) $(DEV_IMAGE) -write therace.prg
	$(C1541) $(DEV_IMAGE) -list

dist: prg
	exomizer sfx sys -o therace_exo.prg therace.prg
	$(C1541) -format "therace dist,rq" d64 $(DIST_IMAGE)
	$(C1541) $(DIST_IMAGE) -write therace_exo.prg "the race"
	$(C1541) $(DIST_IMAGE) -list

test: dev 
	$(X64) -moncommands therace.sym $(DEV_IMAGE)

testdist: dist
	$(X64) -moncommands therace.sym $(DIST_IMAGE)

clean:
	rm -f src/*.o therace.prg therace_exo.prg therace.sym $(DEV_IMAGE) $(DIST_IMAGE)

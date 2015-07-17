# Makefile copied from Zoo Mania game

.SILENT:

IMAGE = "therace_dist.d64"
C1541 = /Applications/Vice/tools/c1541
X64 = /Applications/Vice/x64.app/Contents/MacOS/x64

all: disk

SRC=src/main.s src/about.s src/utils.s
prg:
	cl65 -d -g -Ln therace.sym -u __EXEHDR__ -t c64 -o therace.prg -C therace.cfg ${SRC}

disk: prg
	$(C1541) -format "therace,rq" d64 therace.d64
	$(C1541) therace.d64 -write therace.prg
	$(C1541) therace.d64 -list

dist: prg
	exomizer sfx sys -o therace_exo.prg therace.prg
	$(C1541) -format "therace dist,rq" d64 $(IMAGE)
	$(C1541) $(IMAGE) -write therace_exo.prg "the race"
	$(C1541) $(IMAGE) -list
	rm -f intro.o therace.prg therace_exo.prg

test: disk
	$(X64) -moncommands therace.sym therace.d64

testdist: disk
	$(X64) -moncommands therace.sym therace_dist.d64

clean:
	rm -f *~ *.o therace.prg therace_exo.prg therace.d64 therace.sym $(IMAGE)

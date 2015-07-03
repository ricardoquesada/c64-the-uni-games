# Makefile copied from Zoo Mania game

.SILENT:

IMAGE = "therace_final.d64"
C1541 = /Applications/Vice/tools/c1541
X64 = /Applications/Vice/x64.app/Contents/MacOS/x64

all: disk

prg:
	cl65 -Ln therace.sym -d -g -u __EXEHDR__ -t c64 -o therace.prg -C therace.cfg intro.s
	cp therace.hi.bin therace.hi

disk: prg
	$(C1541) -format "therace,rq" d64 therace.d64
	$(C1541) therace.d64 -write therace.prg
	$(C1541) therace.d64 -write therace.hi
	$(C1541) therace.d64 -list

dist: prg
	exomizer sfx sys -q -n -o therace_exo.prg therace.prg
	$(C1541) -format "therace final,rq" d64 $(IMAGE)
	$(C1541) $(IMAGE) -write therace_exo.prg "the race"
	$(C1541) $(IMAGE) -write therace.hi
	$(C1541) $(IMAGE) -list
	rm -f intro.o therace.prg therace_exo.prg therace.hi

test: disk
	$(X64) -moncommands therace.sym therace.d64

clean: 
	rm -f *~ intro.o therace.prg therace_exo.prg therace.d64 therace.hi therace.sym $(IMAGE)

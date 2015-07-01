# Makefile copied from Zoo Mania game

.SILENT:

IMAGE = "therace_final.d64"
C1541 = /Applications/Vice/tools/c1541

all: disk

prg:
	cl65 -Osi --standard cc65 -u __EXEHDR__ -t c64 -o therace.prg -C therace.cfg main.s
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
	rm -f main.o therace.prg therace_exo.prg therace.hi

test: dist
	x64 $(IMAGE)

clean: 
	rm -f *~ main.o therace.prg therace_exo.prg therace.d64 therace.hi $(IMAGE)

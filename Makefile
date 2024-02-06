PROJECT = do
OBJS = $(PROJECT).prg
INSTDIR=../../Image/bin
.SUFFIXES: .asm .prg

$(PROJECT).bin: $(OBJS)
	link02 -s -S symbols.sym -e $(PROJECT).prg -l ../stdlib.lib -o $(PROJECT).bin

.asm.prg:
	asm02 -l -L $<

clean:
	-rm $(PROJECT).prg
	-rm $(PROJECT).bin
	-rm $(PROJECT).lst
	-rm symbols.sym

install: $(PROJECT).bin
	cp $(PROJECT).bin $(INSTDIR)


BSC = bsc
CC ?= gcc

BLUESTUFFDIR ?= ../../..
include $(BLUESTUFFDIR)/bluestuff.inc.mk
BSVPATH = +:$(BLUESTUFF_DIRS)

# generated files directories
BUILDDIR = build
BDIR = $(BUILDDIR)/bdir
SIMDIR = $(BUILDDIR)/simdir

BSCFLAGS = -p $(BSVPATH)
BSCFLAGS += -bdir $(BDIR)
BSCFLAGS += -simdir $(SIMDIR)
BSCFLAGS += -suppress-warnings T0127:S0080 # no orphan typeclass warning

all: AXI4ReadWidthsExample AXI4WriteWidthsExample

$(SIMDIR):
	mkdir -p $(BDIR) $(SIMDIR)

AXI4ReadWidthsExample: AXI4WidthsExample.bsv $(SIMDIR) $(SIMDIR)/MemSim.o
	$(BSC) $(BSCFLAGS) -check-assert -sim -g testAXI4ReadWidths -u $<
	$(BSC) $(BSCFLAGS) -check-assert -sim -e testAXI4ReadWidths -Xl $(SIMDIR)/MemSim.o -o $@

AXI4WriteWidthsExample: AXI4WidthsExample.bsv $(SIMDIR) $(SIMDIR)/MemSim.o
	$(BSC) $(BSCFLAGS) -check-assert -sim -g testAXI4WriteWidths -u $<
	$(BSC) $(BSCFLAGS) -check-assert -sim -e testAXI4WriteWidths -Xl $(SIMDIR)/MemSim.o -o $@

$(SIMDIR)/MemSim.o: $(BLUEUTILSDIR)/MemSim.c
	$(CC) $(CCFLAGS) -c -o $@ $<

CCFLAGS = -O3  -Wall -Wno-unused -D_FILE_OFFSET_BITS=64 -fPIC

.PHONY: clean

clean:
	rm -f AXI4*WidthsExample
	rm -f AXI4*WidthsExample.so
	rm -rf $(BUILDDIR)

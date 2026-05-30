BSC = bsc
CC ?= gcc

BLUEAXI4DIR ?= ../..
include $(BLUEAXI4DIR)/blueaxi4.inc.mk
BSVPATH = +:$(BLUEAXI4_DIRS)

# generated files directories
BUILDDIR = build
BDIR = $(BUILDDIR)/bdir
SIMDIR = $(BUILDDIR)/simdir

BSCFLAGS = -p $(BSVPATH)
BSCFLAGS += -bdir $(BDIR)
BSCFLAGS += -simdir $(SIMDIR)
BSCFLAGS += -suppress-warnings T0127:S0080 # no orphan typeclass warning

all: basicAXI4FifosExample master

$(SIMDIR):
	mkdir -p $(BDIR) $(SIMDIR)

basicAXI4FifosExample: BasicAXI4FifosExample.bsv $(SIMDIR)/BlueUnixBridges.o $(SIMDIR)
	$(BSC) $(BSCFLAGS) -sim -g testAXI4Fifos -u $<
	$(BSC) $(BSCFLAGS) -sim -e testAXI4Fifos -Xl $(SIMDIR)/BlueUnixBridges.o -o $@

CCFLAGS = -O3  -Wall -Wno-unused -D_FILE_OFFSET_BITS=64 -fPIC

$(SIMDIR)/BlueUnixBridges.o: $(BLUEUNIXBRIDGESDIR)/BlueUnixFifo.c $(BLUEUNIXBRIDGESDIR)/BlueUnixFifo.h $(SIMDIR)
	$(CC) $(CCFLAGS) -I $(BLUEUNIXBRIDGESDIR) -c -o $@ $<

$(SIMDIR)/BlueAXI4UnixBridges.o: $(BLUEAXI4_DIR)/BlueAXI4UnixBridges.c $(BLUEAXI4_DIR)/BlueAXI4UnixBridges.h $(SIMDIR)
	$(CC) $(CCFLAGS) -I $(BLUEAXI4_DIR) -I $(BLUEUNIXBRIDGESDIR) -c -o $@ $<

master: master.o $(SIMDIR)/BlueUnixBridges.o $(SIMDIR)/BlueAXI4UnixBridges.o
	$(CC) $^ -lpthread -o $@

master.o: master.c $(BLUEAXI4_DIR)/BlueAXI4UnixBridges.h $(BLUEUNIXBRIDGESDIR)/BlueUnixBridges.h
	$(CC) -I $(BLUEAXI4_DIR) -I $(BLUEUNIXBRIDGESDIR) -c -o $@ $<

.PHONY: clean

clean:
	rm -f basicAXI4FifosExample
	rm -f basicAXI4FifosExample.so
	rm -rf $(BUILDDIR)
	rm -rf slave
	rm -f master.o
	rm -f master

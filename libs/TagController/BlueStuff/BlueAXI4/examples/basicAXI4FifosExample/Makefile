BSC = bsc
CC ?= gcc

BLUEAXI4_DIR ?= ../..
BLUEAXI4_AXI4_DIR ?= $(BLUEAXI4_DIR)/AXI4
BLUEAXI4_AXI4LITE_DIR ?= $(BLUEAXI4_DIR)/AXI4Lite
BLUEAXI4_AXI4STREAM_DIR ?= $(BLUEAXI4_DIR)/AXI4Stream
BLUEUNIXBRIDGES_DIR ?= $(BLUEAXI4_DIR)/BlueUnixBridges
BLUEBASICS_DIR = $(BLUEUNIXBRIDGES_DIR)/BlueBasics
BSVPATH = +:$(BLUEAXI4_DIR):$(BLUEAXI4_AXI4_DIR):$(BLUEAXI4_AXI4LITE_DIR):$(BLUEAXI4_AXI4STREAM_DIR):$(BLUEUNIXBRIDGES_DIR):$(BLUEBASICS_DIR)

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

$(SIMDIR)/BlueUnixBridges.o: $(BLUEUNIXBRIDGES_DIR)/BlueUnixFifo.c $(BLUEUNIXBRIDGES_DIR)/BlueUnixFifo.h $(SIMDIR)
	$(CC) $(CCFLAGS) -I $(BLUEUNIXBRIDGES_DIR) -c -o $@ $<

$(SIMDIR)/BlueAXI4UnixBridges.o: $(BLUEAXI4_DIR)/BlueAXI4UnixBridges.c $(BLUEAXI4_DIR)/BlueAXI4UnixBridges.h $(SIMDIR)
	$(CC) $(CCFLAGS) -I $(BLUEAXI4_DIR) -I $(BLUEUNIXBRIDGES_DIR) -c -o $@ $<

master: master.o $(SIMDIR)/BlueUnixBridges.o $(SIMDIR)/BlueAXI4UnixBridges.o
	$(CC) $^ -lpthread -o $@

master.o: master.c $(BLUEAXI4_DIR)/BlueAXI4UnixBridges.h $(BLUEUNIXBRIDGES_DIR)/BlueUnixBridges.h
	$(CC) -I $(BLUEAXI4_DIR) -I $(BLUEUNIXBRIDGES_DIR) -c -o $@ $<

.PHONY: clean

clean:
	rm -f basicAXI4FifosExample
	rm -f basicAXI4FifosExample.so
	rm -rf $(BUILDDIR)
	rm -rf slave
	rm -f master.o
	rm -f master

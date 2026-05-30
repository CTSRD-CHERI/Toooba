BSC = bsc
CC ?= gcc

BLUEUNIXBRIDGESDIR ?= ../..
include $(BLUEUNIXBRIDGESDIR)/blueunixbridges.inc.mk
BSVPATH = +:$(BLUEUNIXBRIDGES_DIRS)

# generated files directories
BUILDDIR = $(CURDIR)/build
BDIR = $(BUILDDIR)/bdir
SIMDIR = $(BUILDDIR)/simdir
VDIR = $(BUILDDIR)/vdir
VERILATORDIR = $(CURDIR)/verilatordir

BSCFLAGS = -p $(BSVPATH)
BSCFLAGS += -bdir $(BDIR)

all: bluesim verilatorsim verilog getReq putRsp

$(BDIR):
	mkdir -p $(BDIR)
$(SIMDIR):
	mkdir -p $(SIMDIR)
$(VDIR):
	mkdir -p $(VDIR)

verilog: $(VDIR)/testUnixFifo.v
$(VDIR)/testUnixFifo.v: BasicFifoExample.bsv $(BDIR) $(VDIR)
	$(BSC) $(BSCFLAGS) -vdir $(VDIR) -verilog -g testUnixFifo -u $<

bluesim: BasicFifoExample.bsv $(SIMDIR)/BlueUnixBridges.o $(BDIR) $(SIMDIR)
	$(BSC) $(BSCFLAGS) -sim -g testUnixFifo -u $<
	$(BSC) $(BSCFLAGS) -simdir $(SIMDIR) -sim -e testUnixFifo -Xl $(SIMDIR)/BlueUnixBridges.o -o $@

verilatorsim: $(VDIR)/testUnixFifo.v
	$(eval TMP_V := $(shell mktemp -t testUnixFifo_XXXX.v))
	sed 's/$$imported_//' $< > $(TMP_V)
	verilator \
      -Mdir $(VERILATORDIR) \
      --prefix VtestUnixFifo \
      -o testUnixFifo \
      -y $(VDIR) \
      -y $(BLUESPECDIR)/Verilog \
      -Wno-WIDTH \
      -Wno-STMTDLY \
      -cc \
      $(TMP_V) \
      ../../BlueUnixFifo.v \
      -exe \
      verilator_sim.cpp \
      ../../BlueUnixFifo.c
	make -C $(VERILATORDIR) -j -f VtestUnixFifo.mk testUnixFifo

#CCFLAGS = -O3  -Wall -Wno-unused -D_FILE_OFFSET_BITS=64 -fpermissive -fPIC
CCFLAGS = -O3  -Wall -Wno-unused -D_FILE_OFFSET_BITS=64 -fPIC
$(SIMDIR)/BlueUnixBridges.o: $(BLUEUNIXBRIDGESDIR)/BlueUnixFifo.c $(BLUEUNIXBRIDGESDIR)/BlueUnixFifo.h $(SIMDIR)
	$(CC) $(CCFLAGS) -I $(BLUEUNIXBRIDGESDIR) -c -o $@ $<

getReq: getReq.o $(SIMDIR)/BlueUnixBridges.o
	$(CC) $^ -o $@

getReq.o: getReq.c
	$(CC) -I $(BLUEUNIXBRIDGESDIR) -c -o $@ $<

putRsp: putRsp.o $(SIMDIR)/BlueUnixBridges.o
	$(CC) $^ -o $@

putRsp.o: putRsp.c
	$(CC) -I $(BLUEUNIXBRIDGESDIR) -c -o $@ $<

.PHONY: clean

clean:
	rm -f bluesim
	rm -f bluesim.so
	rm -rf $(BUILDDIR)
	rm -rf $(VERILATORDIR)
	rm -rf fifos
	rm -f getReq
	rm -f getReq.o
	rm -f putRsp
	rm -f putRsp.o

BSC = bsc
CC ?= gcc

BLUEUNIXBRIDGESDIR ?= ../..
BLUEBASICSDIR = $(BLUEUNIXBRIDGESDIR)/BlueBasics
BSVPATH = +:$(BLUEUNIXBRIDGESDIR):$(BLUEBASICSDIR)

# generated files directories
BUILDDIR = build
BDIR = $(BUILDDIR)/bdir
SIMDIR = $(BUILDDIR)/simdir

BSCFLAGS = -p $(BSVPATH)
BSCFLAGS += -bdir $(BDIR)
BSCFLAGS += -simdir $(SIMDIR)

all: basicFifoExample getReq putRsp

$(SIMDIR):
	mkdir -p $(BDIR) $(SIMDIR)

basicFifoExample: BasicFifoExample.bsv $(SIMDIR)/BlueUnixBridges.o $(SIMDIR)
	$(BSC) $(BSCFLAGS) -sim -g testUnixFifo -u $<
	$(BSC) $(BSCFLAGS) -sim -e testUnixFifo -Xl $(SIMDIR)/BlueUnixBridges.o -o $@

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
	rm -f basicFifoExample
	rm -f basicFifoExample.so
	rm -rf $(BUILDDIR)
	rm -rf fifos
	rm -f getReq
	rm -f getReq.o
	rm -f putRsp
	rm -f putRsp.o

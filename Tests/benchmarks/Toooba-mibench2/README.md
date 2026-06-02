```
This material is based upon work supported by the Defense Advanced
Research Project Agency (DARPA) under Contract No. HR0011-18-C-0013. 
Any opinions, findings, conclusions or recommendations expressed in
this material are those of the author(s) and do not necessarily
reflect the views of DARPA.

Distribution Statement "A" (Approved for Public Release, Distribution
Unlimited)
```

# MiBench2 for BESSPIN

This repository is a fork of the
[MiBench2](https://github.com/impedimentToProgress/MiBench2)
benchmark ported for the BESSPIN project.
Please use the `master` and `develop` branches for all BESSPIN-related work.

Every directory in this project is a self-contained benchmark with a standalone
`Makefile`.
The following setting must be specified when compiling a MiBench2 binary:

* `GFE_TARGET`: This can be set to `P1`, `P2`, or `P3`.

The following settings can optionally be specified when compiling a MiBench2
binary:

* `RUNS`: Controls how many times a MiBench2 kernel runs.
  There is no official guidance for how to set this variable.
  This defaults to 1.
* `UART_BAUD_RATE`: Control the baud rate for the VCU118's UART.
  Each binary prints its results over the UART at the end of the test.
  This defaults to 115200.

Here is an example of compiling a MiBench2 benchmark (`basicmath`) for a P1
processor to run for 2 iterations:

```
cd basicmath
make GFE_TARGET=P1 RUNS=2
```

This produces an ELF file `basicmath/main.elf`, which can be run on the FPGA.

There is also a script (`buildAll.sh`) to build every MiBench2 benchmark.
Currently you cannot specify the `RUNS` or `UART_BAUD_RATE` parameters, those
are set to default values.
Here is an example of using that script to build benchmarks for P1:

```
./BuildAll.sh P1
```

This script automatically copies all of the output ELF files to the top-level
directory.

## Compile/Run Status

As of commit `2d00d66f`, not all of the MiBench2 benchmarks are compiling or
running on the GFE.
The following benchmarks compile successfully:

* adpcm_decode
* adpcm_encode
* aes
* basicmath
* blowfish
* crc
* dijkstra
* fft
* limits
* picojpeg
* qsort
* randmath
* rc4
* rsa
* sha

The following benchmarks fail to compile:

* bitcount
* lzfx
* overflow
* patricia
* regress
* stringsearch
* susan
* vcflags

Of the benchmarks that compile, the following have run-time errors on the GFE:

* dijkstra
* picojpeg
* rsa
* sha

The following benchmarks should compile and run without errors on the GFE:

* adpcm_decode
* adpcm_encode
* aes
* basicmath
* blowfish
* crc
* fft
* limits
* qsort
* randmath
* rc4

The remainder of this document contains the original README from the [official
MiBench2 repository](https://github.com/impedimentToProgress/MiBench2).

# MiBench2
[MiBench](http://vhosts.eecs.umich.edu/mibench/) ported for IoT devices.

All benchmarks include [barebench.h](barebench.h).  This file contains the `main()` used in building every benchmark and determines the number of benchmark trials and what happens when a benchmark attempts to print to the screen.

### Prerequisites

You will need a cross-compiler for your target platform. The default target is the ARM-Cortex-M0+.  The easiest way to get a working cross-compiler for the Cortex-M0+ is to download the prebuilt binaries from [Launchpad.net](https://launchpad.net/gcc-arm-embedded).

Whatever toolchain you go with, update the paths and commands in the global [make file](Makefile.mk).

### Building

`cd` to the appropriate benchmark directory.

`make`


Running `make` produces several useful files:
   `main.elf` an ELF executable suitable for loading to a board or simulator using GDB
   `main.bin` a raw binary suitable for loading directly in to the memory of a board or a simulator
   `main.lst` assembly listing


Running `make clean` will remove all files produced during compilation.


To build all benchmarks and move the resulting bin files to the repo's top-level directory, run [buildAll.sh](buildAll.sh).

### Porting

[memmap](memmap) contains the memory map used by the linker to place program sections.  Edit this file to change the size of memory or the location/size of individual program sections (e.g., stack and heap).

[vectors.s](vectors.s) contains the exception jump table and the execution entry point `_start` and exit point `exit`.  You may need to edit this file if you target a different instruction set than the ARMv6-M.

[putget.s](putget.s) contains low level functions written in assembly.  Edit the `putchar` function in this file to change the behavior of all C-level printing operations.

[supportFuncs.c](supportFuncs.c) contains functions needed to port newlib to our target platform.

### Statically Allocated

Benchmark susan: Statically Allocated for this specific data set.

Benchmark fft: Statically Allocated for this specific data set.



\RISCV_FLAGS ?=
LIBS ?=

# Allow users to override the number of time to run a benchmark.
RUNS ?= 1

ifeq ($(CHERI),1)
TOOLCHAIN:=LLVM
endif

CCDIR   ?= /Users/jonathanwoodruff/cheri/output/sdk/bin
ifeq ($(TOOLCHAIN),LLVM)
CC      := $(CCDIR)/clang
LD      := $(CCDIR)/ld.lld
OBJDUMP := $(CCDIR)/llvm-objdump
OBJCOPY := $(CCDIR)/llvm-objcopy

RISCV_FLAGS += -mcmodel=medium -mno-relax
LIBS := 
else # GCC
CC      := riscv64-unknown-elf-gcc
LD      := riscv64-unknown-elf-ld
OBJDUMP := riscv64-unknown-elf-objdump
OBJCOPY := riscv64-unknown-elf-objcopy
RISCV_FLAGS += -mcmodel=medany
LIBS := -lgcc
endif

# Make sure user explicitly defines the target GFE platform.
ifeq ($(TOOLCHAIN),LLVM)
ifeq ($(CHERI),1)
  RISCV_FLAGS += -target riscv64 -march=rv64imafdxcheri -mabi=l64pc128d
else
  RISCV_FLAGS += -target riscv64 -march=rv64imafdc -mabi=lp64
endif
else
  RISCV_FLAGS += -march=rv64imafdc -mabi=lp64d
endif
# 25 MHz clock
CLOCKS_PER_SEC := 25000000

# Define sources and compilation outputs.
COMMON_DIR := ../../Toooba-mibench2
LINKER_SCRIPT := $(COMMON_DIR)/test.ld
COMMON_ASM_SRCS := \
	$(COMMON_DIR)/crt.S
COMMON_C_SRCS := \
	$(COMMON_DIR)/syscalls.c \
	$(COMMON_DIR)/util.c \
	$(COMMON_DIR)/cvt.c
COMMON_OBJS := \
	$(patsubst %.c,%.o,$(notdir $(COMMON_C_SRCS))) \
	$(patsubst %.S,%.o,$(notdir $(COMMON_ASM_SRCS)))
OBJS := $(COMMON_OBJS) $(OBJS)

# Define compile and load/link flags.
CFLAGS := \
	$(RISCV_FLAGS) \
	-DBARE_METAL \
	-DCLOCKS_PER_SEC=$(CLOCKS_PER_SEC) \
	-DHAS_FLOAT=1 \
	-DRUNS=$(RUNS) \
	-O2 \
	-Wall \
	-static \
	-std=gnu99 \
	-ffast-math \
	-fno-common \
	-fno-builtin-printf \
	-I$(COMMON_DIR)
ASFLAGS := $(CFLAGS)
LDFLAGS := \
	-v \
	-static \
	-nostdlib \
	-nodefaultlibs \
	-nostartfiles \
	$(LIBS) \
	-T $(LINKER_SCRIPT)

all: main.elf

%.o: src/%.s
	$(CC) $(ASFLAGS) -c -o $@ $<

%.o: $(COMMON_DIR)/%.S
	$(CC) $(ASFLAGS) -c -o $@ $<

%.o: src/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: $(COMMON_DIR)/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

main.elf: $(OBJS) $(COMMON_C_SRCS) $(COMMON_ASM_SRCS)
	$(CC) $(CFLAGS) $(OBJS) -o main.elf -Xlinker $(LDFLAGS)
#	$(LD) $(OBJS) --allow-shlib-undefined -lm -lc -lclang_rt.profile-riscv64 -Bstatic -T ../test.ld -L/Users/jonathanwoodruff/cheri/build/cheribsd-riscv64-build/Users/jonathanwoodruff/cheri/cheribsd/riscv.riscv64/lib/libclang_rt/profile/ -L/Users/jonathanwoodruff/cheri/build/cheribsd-riscv64-build/Users/jonathanwoodruff/cheri/cheribsd/riscv.riscv64/tmp/usr/lib/ --sysroot=/Users/jonathanwoodruff/cheri/build/cheribsd-riscv64-build/Users/jonathanwoodruff/cheri/cheribsd/riscv.riscv64//tmp/ -o main.elf
	$(OBJDUMP) --disassemble-all main.elf > main.lst
	$(OBJCOPY) main.elf main.bin

clean: more_clean
	rm -rf *.o *.elf output* *.lst *.bin *~

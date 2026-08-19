/local/scratch/yw737/cheri_emte/build/llvm-project-build/bin/clang \
  -mcmodel=medium -mno-relax \
  -march=rv64imafdcxcheri -mabi=l64pc128d \
  -target riscv64-unknown-freebsd \
  --sysroot="/local/scratch/yw737/cheri_emte/output/rootfs-riscv64-purecap" \
  -Wall -fuse-ld=lld -static -std=gnu99 \
  -ffast-math -fno-common -fno-builtin -fno-builtin-printf \
  -I.. syscalls.o util.o cvt.o crt.o patricia.o patricia_test.o \
  -o main.elf \
  -Xlinker -v \
  -Xlinker -z -Xlinker norelro \
  -static -nostdlib -nodefaultlibs -nostartfiles \
  -T ../test.ld

mv main.elf ../../patricia.bin

#!/bin/sh -xe

riscv64-unknown-elf-gcc -o init.o -c init.s
for TEST in memshim memshimwrite hello communication memshimread baselinecommunication
do
riscv64-unknown-elf-gcc -g -o $TEST.o -c $TEST.c
riscv64-unknown-elf-gcc -g -nostdlib -mcmodel=medany -Tlink.ld -o $TEST $TEST.o init.o
riscv64-unknown-elf-gcc -g -nostdlib -mcmodel=medany -Thwlink.ld -o $TEST.hw $TEST.o init.o
riscv64-unknown-elf-objdump -D $TEST > $TEST.dump
riscv64-unknown-elf-objdump -D $TEST.hw > $TEST.dumphw
../elf_to_hex/elf_to_hex $TEST $TEST.hex
done

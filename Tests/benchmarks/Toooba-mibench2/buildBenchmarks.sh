#!/bin/sh

echo $(dirname $0)

for PROG in adpcm_decode adpcm_encode aes basicmath blowfish crc fft limits qsort randmath rc4
do
	echo "Building mibench2 benchmark $(dirname $0)/$PROG"
	cd $(dirname $0)/$PROG
	make GFE_TARGET=$1 clean
	make GFE_TARGET=$1 RUNS=$2
	cp main.elf ../$PROG.elf
	make GFE_TARGET=$1 clean
	echo '`-> Done'
done



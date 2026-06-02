#!/bin/sh

find . -d 1 -type d \( ! -name .\* \) -exec bash -c "cd {} && make GFE_TARGET=$1 clean && make GFE_TARGET=$1 && cp main.elf ../{}.bin && make GFE_TARGET=$1 clean" \;

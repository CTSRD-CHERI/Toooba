#!/bin/bash
echo "Log, Cycles, Instructions"
for file in "$@"
do
  echo "`basename ${file}`, `tac ${file} | grep -m 1 instret | sed 's/^instret:\([[:digit:]]*\).*   \([[:digit:]]*\)$/\2, \1/g'`"
done

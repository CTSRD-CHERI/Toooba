#!/bin/sh -xe

cp ../../Tests/small-tests/communication.hex Mem.hex
cp ../../Tests/small-tests/symbol_table.txt .
./exe_HW_sim +tohost

#!/usr/bin/make -f
#-
# Copyright (c) 2012-2013 Simon W. Moore
# Copyright (c) 2014 Theo Markettos
# Copyright (c) 2018 Jonathan Woodruff
# Copyright (c) 2018 Alexandre Joannou
# All rights reserved.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
# ("CTSRD"), as part of the DARPA CRASH research programme.
# 
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory (Department of Computer Science and
# Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
# DARPA SSITH research programme.
#
# @BERI_LICENSE_HEADER_START@
#
# Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  BERI licenses this
# file to you under the BERI Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.beri-open-systems.org/legal/license-1-0.txt
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @BERI_LICENSE_HEADER_END@
#

BSC=bsc
BSCFLAGS=-keep-fires -cross-info
BSVTST_TOP=RVFI_DII_Test

all: $(SIMDEST) sim

sim: $(BSVTST_TOP).bsv RVFI_DII_Bridge.bsv RVFI_DII_Types.bsv RVFI_DII.bsv SocketPacketUtils/socket_packet_utils.c
	$(BSC) -sim -g mk$(BSVTST_TOP) -u $(BSVTST_TOP).bsv
	CC=gcc-4.8 CXX=g++-4.8 $(BSC) -sim -o mk$(BSVTST_TOP) -e mk$(BSVTST_TOP) mk$(BSVTST_TOP).ba SocketPacketUtils/socket_packet_utils.c
	ln -s -f mk$(BSVTST_TOP)    sim
	ln -s -f mk$(BSVTST_TOP).so sim.so

.PHONY: clean
clean:
	rm -f  *.bi *.bo *.ba *.info *.sched *.h *.o *.so *.cxx mk$(BSVTST_TOP) sim >/dev/null
	rm -f  *.v > /dev/null

#-
# Copyright (c) 2021-2022 Alexandre Joannou
# All rights reserved.
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

SRCS  = WindCoreInterface.bsv
SRCS += WindCoreHi.bsv
SRCS += WindCoreLo.bsv
SRCS += WindCoreMid.bsv
SRCS += WindCoreUtils.bsv

BLUESTUFFDIR = $(CURDIR)/BlueStuff
BLUEAXI4DIR = $(BLUESTUFFDIR)/BlueAXI4
BLUEAXI4DIRS = $(BLUEAXI4DIR):$(BLUEAXI4DIR)/AXI4:$(BLUEAXI4DIR)/AXI4Lite:$(BLUEAXI4DIR)/AXI4Stream:$(BLUEAXI4DIR)/BlueUnixBridges
BLUEBASICSDIR = $(BLUESTUFFDIR)/BlueBasics

# generated files directories
BUILDDIR = build
BDIR = $(BUILDDIR)/bdir

BSC = bsc
BSVPATH = +:$(BLUESTUFFDIR):$(BLUEAXI4DIRS):$(BLUEBASICSDIR):$(BLUEUTILSDIR)
BSCFLAGS = -p $(BSVPATH)
BSCFLAGS += -bdir $(BDIR)
#BSCFLAGS += +RTS -K512M -RTS
#BSCFLAGS += -show-schedule
#BSCFLAGS += -sched-dot
#BSCFLAGS += -show-range-conflict
#BSCFLAGS += -show-rule-rel \* \*
#BSCFLAGS += -steps-warn-interval n
BSCFLAGS += -suppress-warnings T0127:S0080 # no orphan typeclass warning

.PHONY: all
all: $(BDIR)/WindCoreInterface.bo

$(BDIR)/WindCoreInterface.bo: $(SRCS)
	mkdir -p $(BDIR)
	$(BSC) $(BSCFLAGS) -sim -u WindCoreInterface.bsv

.PHONY: clean

clean:
	rm -f -r $(BUILDDIR)

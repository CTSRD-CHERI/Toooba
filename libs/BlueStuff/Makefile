#-
# Copyright (c) 2018 Alexandre Joannou
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

BSC = bsc
#BSC = ~/Downloads/bsc-install-focal/bsc-install/bin/bsc

BLUESTUFFDIR = $(CURDIR)
include $(BLUESTUFFDIR)/bluestuff.inc.mk
BSVPATH = +:$(BLUESTUFF_DIRS)

BSCFLAGS = -p $(BSVPATH)

# generated files directories
BUILDDIR = build
BDIR = $(BUILDDIR)/bdir
SIMDIR = $(BUILDDIR)/simdir

OUTPUTDIR = output

BSCFLAGS += -bdir $(BDIR)

BSCFLAGS += +RTS -K512M -RTS
BSCFLAGS += -show-schedule
BSCFLAGS += -sched-dot
BSCFLAGS += -show-range-conflict
#BSCFLAGS += -show-rule-rel \* \*
#BSCFLAGS += -steps-warn-interval n

EXAMPLESDIR = examples
SIMEXAMPLESSRC = $(wildcard $(EXAMPLESDIR)/Example-*.bsv)
SIMEXAMPLES = $(addprefix sim, $notdir($(basename $(SIMEXAMPLESSRC))))
VERILOGEXAMPLESSRC = $(EXAMPLESDIR)/Example-AXI4-MasterSlave.bsv
VERILOGEXAMPLESSRC += $(EXAMPLESDIR)/Example-AXI4Lite-MasterSlave.bsv
VERILOGEXAMPLES = $(addprefix verilog, $(notdir $(basename $(VERILOGEXAMPLESSRC))))
CFILES = $(BLUEUTILSDIR)/MemSim.c

all: simExamples verilogExamples

include .simExamples
include .verilogExamples

simExample-%: $(EXAMPLESDIR)/Example-%.bsv
	mkdir -p $(OUTPUTDIR)/$@-info $(BDIR) $(SIMDIR)
	#$(BSC) -cpp -Xcpp -I. -info-dir $(OUTPUTDIR)/$@-info -simdir $(SIMDIR) $(BSCFLAGS) -sim -g top -u $<
	$(BSC) -info-dir $(OUTPUTDIR)/$@-info -simdir $(SIMDIR) $(BSCFLAGS) -sim -g top -u $<
	$(BSC) -simdir $(SIMDIR) $(BSCFLAGS) -sim -e top -o $(OUTPUTDIR)/$@ $(CFILES)
	dot -Tsvg $(OUTPUTDIR)/$@-info/top_combined.dot > $(OUTPUTDIR)/$@-info/top_combined.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/top_combined_full.dot > $(OUTPUTDIR)/$@-info/top_combined_full.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/top_conflict.dot > $(OUTPUTDIR)/$@-info/top_conflict.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/top_exec.dot > $(OUTPUTDIR)/$@-info/top_exec.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/top_urgency.dot > $(OUTPUTDIR)/$@-info/top_urgency.svg

verilogExample-%.v:
	mkdir -p $(OUTPUTDIR)/$@-info $(BDIR)
	$(BSC) -info-dir $(OUTPUTDIR)/$@-info -vdir $(OUTPUTDIR) -opt-undetermined-vals -unspecified-to X $(BSCFLAGS) -verilog -g $(patsubst verilogExample-%.v, %, $@) -u $<

#.simExamples: $(patsubst Example-%, %, $(notdir $(SIMEXAMPLESSRC)))
#	echo "simExamples: $^" > .simExamples
.simExamples: $(SIMEXAMPLESSRC)
	rm -f .simExamples
	touch .simExamples
	for f in $^; do tmp=`basename $$f .bsv`; echo "simExamples: simExample-$${tmp#"Example-"}" >> .simExamples; done
	for f in $^; do tmp=`basename $$f .bsv`; echo "simExample-$${tmp#"Example-"}: $$f" >> .simExamples; done

.verilogExamples: $(patsubst %, .gatherModules-%, $(notdir $(VERILOGEXAMPLESSRC)))
	cat $^ > $@

.gatherModules-%: $(EXAMPLESDIR)/%
	awk '/^module/ {print "verilogExample-"$$2".v: $(EXAMPLESDIR)/$*"; print "verilogExamples: " "verilogExample-"$$2".v"}' $(EXAMPLESDIR)/$* > $@

.PHONY: clean mrproper verilogExamples simExamples

clean:
	rm -f .simExamples
	rm -f .verilogExamples
	rm -f .gatherModules-*
	rm -f -r $(BUILDDIR)

mrproper: clean
	rm -f -r $(OUTPUTDIR)

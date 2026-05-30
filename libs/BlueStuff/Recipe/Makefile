#-
# Copyright (c) 2018-2021 Alexandre Joannou
# Copyright (c) 2018 Matthew Naylor
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

BLUEUTILSDIR = ./BlueBasics
BSVPATH = +:$(BLUEUTILSDIR)

BSCFLAGS = -p $(BSVPATH)

# generated files directories
BUILDDIR = build
BDIR = $(BUILDDIR)/bdir
SIMDIR = $(BUILDDIR)/simdir

OUTPUTDIR = output

BSCFLAGS += -bdir $(BDIR)
BSCFLAGS += -simdir $(SIMDIR)

BSCFLAGS += -show-schedule
BSCFLAGS += -sched-dot
BSCFLAGS += -show-range-conflict
#BSCFLAGS += -show-rule-rel \* \*
#BSCFLAGS += -steps-warn-interval n

EXAMPLESDIR = examples
SIMEXAMPLESSRC = $(sort $(wildcard $(EXAMPLESDIR)/Example-*.bsv))
SIMEXAMPLES = $(addprefix sim, $(notdir $(basename $(SIMEXAMPLESSRC))))

all: simExamples

include .simExamples

simExamples: $(SIMEXAMPLES)

simExample-%: $(EXAMPLESDIR)/Example-%.bsv Recipe.bsv
	mkdir -p $(OUTPUTDIR)/$@-info $(BDIR) $(SIMDIR)
	$(BSC) -cpp -Xcpp -I. -info-dir $(OUTPUTDIR)/$@-info -simdir $(SIMDIR) $(BSCFLAGS) -sim -g top -u $<
	$(BSC) -simdir $(SIMDIR) $(BSCFLAGS) -sim -e top -o $(OUTPUTDIR)/$@

.simExamples: $(SIMEXAMPLESSRC)
	echo "simExamples: $^" > .simExamples
	for f in $^; do tmp=`basename $$f .bsv`; echo "simExample-$${tmp#"Example-"}: $$f" >> .simExamples; done

.PHONY: clean mrproper all simExamples

clean:
	rm -f .simExamples
	rm -f -r $(BUILDDIR)

mrproper: clean
	rm -f -r $(OUTPUTDIR)

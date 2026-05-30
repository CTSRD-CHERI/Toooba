#-
# Copyright (c) 2023 Alexandre Joannou
# All rights reserved.
#
# This material is based upon work supported by the DoD Information Analysis
# Center Program Management Office (DoD IAC PMO), sponsored by the Defense
# Technical Information Center (DTIC) under Contract No. FA807518D0004.  Any
# opinions, findings and conclusions or recommendations expressed in this
# material are those of the author(s) and do not necessarily reflect the views
# of the Air Force Installation Contracting Agency (AFICA).
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

BLUEAVALONDIR = $(CURDIR)
BLUEBASICSDIR = $(BLUEAVALONDIR)/BlueBasics
BSVPATH = +:$(BLUEAVALONDIR):$(BLUEBASICSDIR)

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

TESTSDIR = tests

all: simPipelinedAvalonMM_Host_Agent simPipelinedAvalonMem simPipelinedAvalonMem_SubWord

simPipelinedAvalonMM_Host_Agent: $(TESTSDIR)/PipelinedAvalonMM_Host_Agent.bsv
	mkdir -p $(OUTPUTDIR)/$@-info $(BDIR) $(SIMDIR)
	$(BSC) -info-dir $(OUTPUTDIR)/$@-info -simdir $(SIMDIR) $(BSCFLAGS) -sim -g simTop -u $<
	$(BSC) -simdir $(SIMDIR) $(BSCFLAGS) -sim -e simTop -o $(OUTPUTDIR)/$@
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_combined.dot > $(OUTPUTDIR)/$@-info/simTop_combined.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_combined_full.dot > $(OUTPUTDIR)/$@-info/simTop_combined_full.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_conflict.dot > $(OUTPUTDIR)/$@-info/simTop_conflict.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_exec.dot > $(OUTPUTDIR)/$@-info/simTop_exec.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_urgency.dot > $(OUTPUTDIR)/$@-info/simTop_urgency.svg

simPipelinedAvalonMem: $(TESTSDIR)/PipelinedAvalonMem.bsv
	mkdir -p $(OUTPUTDIR)/$@-info $(BDIR) $(SIMDIR)
	$(BSC) -info-dir $(OUTPUTDIR)/$@-info -simdir $(SIMDIR) $(BSCFLAGS) -sim -g simTop -u $<
	$(BSC) -simdir $(SIMDIR) $(BSCFLAGS) -sim -e simTop -o $(OUTPUTDIR)/$@
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_combined.dot > $(OUTPUTDIR)/$@-info/simTop_combined.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_combined_full.dot > $(OUTPUTDIR)/$@-info/simTop_combined_full.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_conflict.dot > $(OUTPUTDIR)/$@-info/simTop_conflict.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_exec.dot > $(OUTPUTDIR)/$@-info/simTop_exec.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_urgency.dot > $(OUTPUTDIR)/$@-info/simTop_urgency.svg

simPipelinedAvalonMem_SubWord: $(TESTSDIR)/PipelinedAvalonMem_SubWord.bsv
	mkdir -p $(OUTPUTDIR)/$@-info $(BDIR) $(SIMDIR)
	$(BSC) -info-dir $(OUTPUTDIR)/$@-info -simdir $(SIMDIR) $(BSCFLAGS) -sim -g simTop -u $<
	$(BSC) -simdir $(SIMDIR) $(BSCFLAGS) -sim -e simTop -o $(OUTPUTDIR)/$@
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_combined.dot > $(OUTPUTDIR)/$@-info/simTop_combined.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_combined_full.dot > $(OUTPUTDIR)/$@-info/simTop_combined_full.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_conflict.dot > $(OUTPUTDIR)/$@-info/simTop_conflict.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_exec.dot > $(OUTPUTDIR)/$@-info/simTop_exec.svg
	dot -Tsvg $(OUTPUTDIR)/$@-info/simTop_urgency.dot > $(OUTPUTDIR)/$@-info/simTop_urgency.svg

clean:
	rm -f -r $(BUILDDIR)

mrproper: clean
	rm -f -r $(OUTPUTDIR)

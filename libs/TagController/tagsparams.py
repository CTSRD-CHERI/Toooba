#! /usr/bin/env python3
#-
# Copyright (c) 2016-2021 Alexandre Joannou
# Copyright (c) 2019 Jonathan Woodruff
# All rights reserved.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
# ("CTSRD"), as part of the DARPA CRASH research programme.
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

import argparse
from datetime import datetime
import functools

def ceillog2 (x):
    return max(0, x.bit_length() - 1)

################################
# Parse command line arguments #
################################

parser = argparse.ArgumentParser(description='''
    Deduce parameters of a tag store covering an associated data store from specified:
      * tag store top address
      * data store base address
      * data store size
    ''')

def auto_int (x):
    return int(x,0)

def auto_roundup_power2 (x):
    return 2**(max(0, auto_int(x)-1)).bit_length()

# positional
parser.add_argument('data_store_size', type=auto_int, metavar='DATA_STORE_SIZE', #default=(2**30+2**20),
                    help="the size in bytes of the covered data store")
parser.add_argument('tag_store_top_addr', type=auto_int, metavar='TAG_STORE_TOP_ADDR', #default=0x40000000,
                    help="memory address at which the tag store should start growing down from")
# optional
parser.add_argument('-v', '--verbose', action='count', default=1,
                    help="turn on output messages")
parser.add_argument('--data-store-base-addr', type=auto_int, default=0x00000000,
                    help="the address at which the covered data store should start growing up from")
parser.add_argument('-c','--tagged-chunk-size', type=auto_roundup_power2, default=256,
                    help="size in bits of a tagged memory chunk (implicitly rounded up to the nearest power of 2)")
parser.add_argument('-s','--structure', type=auto_int, nargs='+', default=[0],
                    help="list from leaf to root of branching factors describing the tags tree")
parser.add_argument('-a','--addr-align', type=auto_int, default=32,
                    help="alignement requirement (in bytes) for table levels addresses")
parser.add_argument('-b','--bsv-import-output', nargs='?', const="TagTableStructure.bsv", default=None,
                    help="generate Bluespec MultiLevelTagLookup module import configuration file")
parser.add_argument('-l','--linker-inc-output', nargs='?', const="tags-params.ld", default=None,
                    help="generate tags configuration linker include file")

args = parser.parse_args()

def verboseprint(lvl, msg):
    if args.verbose >= lvl:
        print(msg)

verboseprint(3, '''NOTE: the tag store is expected to be layed out as follows

      high addrs <---------------------------------------------> low addrs
(tag_store_top_addr)                                        (tag_store_base_addr)
        |                                                            |
   -----|------------------------------------------------------------|-----
    ... | lvl 0 (leaf) | lvl 1 |    ...   | lvl (n-1) | lvl n (root) | ...
   -----|------------------------------------------------------------|-----
''')

####################################
# values the script will work with #
####################################

verboseprint(2, "--- input parameters ---")
verboseprint(2, "data_store_size = 0x{:08x}({:d}) bytes".format(args.data_store_size, args.data_store_size))
verboseprint(2, "tagged_chunk_size = {:d} bits".format(args.tagged_chunk_size))
verboseprint(2, "tag_store_top_addr = 0x{:08x}".format(args.tag_store_top_addr))
verboseprint(2, "addr_align = 0x{:04x}({:d}) bytes (ignore bottom {:d} addr bits)".format(args.addr_align, args.addr_align, ceillog2(args.addr_align)))
verboseprint(2, "structure = {:s}".format(str(args.structure)))

######################
# compute parameters #
######################

class TableLvl():
    def __init__ (self, base_addr, size):
        self.base_addr = base_addr
        self.size = size
    def __repr__(self):
        return str(self)
    def __str__(self):
        return "{{base: 0x{:08x}, {:d} bytes}}".format(self.base_addr, self.size)

def table_lvl(lvl):
    mask = ~0 << ceillog2(args.addr_align)
    if lvl == 0:
        # Note: tagged_chunk_size is a size in bits
        #       data_store_size is a size in bytes
        #       // is floor division
        #       Here we assume a _single_ bit tag per tagged chunk
        size = args.data_store_size // args.tagged_chunk_size
        addr = args.tag_store_top_addr - size
    else:
        t = table_lvl(lvl-1)
        # Note: here we assume that _single_ bits in the (lvl) store cover for
        #       (structure[lvl]) bits in the (lvl-1) store
        size = t.size // args.structure[lvl]
        addr = t.base_addr - size
    return TableLvl (addr&mask, size)

if args.tagged_chunk_size > 0:
    lvls = list( map (table_lvl, range(0,len(args.structure))))
else:
    lvls = [TableLvl(args.tag_store_top_addr,0)]

#######################
# computed parameters #
#######################

tag_store_base_addr = lvls[len(lvls)-1].base_addr
tag_store_top_addr  = args.tag_store_top_addr
tag_store_size      = tag_store_top_addr - tag_store_base_addr

data_store_base_addr = args.data_store_base_addr
data_store_size      = args.data_store_size
data_store_top_addr  = data_store_base_addr + data_store_size

verboseprint(2, "")
verboseprint(2, "--- deduced tag store parameters ---")
verboseprint(2, "lvls = {:s}".format(str(lvls)))
verboseprint(2, "tag store base addr = 0x{:08x}".format(tag_store_base_addr))
verboseprint(2, "tag store  top addr = 0x{:08x}".format(tag_store_top_addr))
verboseprint(2, "(tag store size = 0x{:08x}({:d}) bytes)".format(tag_store_size, tag_store_size))
verboseprint(2, "")
verboseprint(2, "--- deduced data store parameters ---")
verboseprint(2, "data store base addr = 0x{:08x}".format(data_store_base_addr))
verboseprint(2, "data store  top addr = 0x{:08x}".format(data_store_top_addr))
verboseprint(2, "(data store size = 0x{:08x}({:d}) bytes)".format(data_store_size, data_store_size))
if not ((tag_store_base_addr > data_store_top_addr) or (data_store_base_addr > tag_store_top_addr)):
  verboseprint(2, "")
  verboseprint(1, "WARNING: overlapping tag store and data store")

######################################################
# generate bluespec table configuration import file #
######################################################

if args.bsv_import_output:
    verboseprint(2, "")
    verboseprint(2, "generating Bluespec MultiLevelTagLookup module import configuration file %s" % args.bsv_import_output)
    f = open(args.bsv_import_output,'w')
    header = """/*-
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */
"""
    header += "\n// This file was generated by the tagsparams.py script"
    header += "\n// %s\n\n" % str(datetime.now())
    decl = "Vector#(%d, Integer) tableStructure = " % len(args.structure)
    foldr = lambda func, acc, xs: functools.reduce(lambda x, y: func(y, x), xs[::-1], acc)
    structArray = foldr (lambda next, rest: "cons({:d}, {:s})".format(next,rest), "nil", args.structure)
    f.write(header)
    f.write("import Vector::*;\n");
    f.write(decl)
    f.write(structArray)
    f.write(";\n")
    f.write("Integer table_end_addr = 'h{:x};\n".format(tag_store_top_addr))
    f.write("Integer table_start_addr = 'h{:x};\n".format(tag_store_base_addr))
    f.write("Integer covered_start_addr = 'h{:x};\n".format(data_store_base_addr))
    f.write("Integer covered_mem_size  = 'h{:x};\n".format(data_store_size))
#    map(f.write,fill)

#######################################################
# generate ld script table configuration include file #
#######################################################

if args.linker_inc_output:
    verboseprint(2, "")
    verboseprint(2, "generating tags configuration linker include file %s" % args.linker_inc_output)
    f = open(args.linker_inc_output,'w')
    header = """/*-
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */
"""
    header += "\n/* This file was generated by the tagsparams.py script */"
    header += "\n/* {:s} */\n\n".format(str(datetime.now()))
    decl = "__tags_table_size__ = 0x{:x};".format(tag_store_size)
    f.write(header)
    f.write(decl)

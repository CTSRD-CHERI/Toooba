/*-
 * Copyright (c) 2018 Alexandre Joannou
 * Copyright (c) 2018 Jonathan Woodruff
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
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

import Vector::*;

typedef struct {
  Bool v;
  a d;
} VnD#(type a) deriving (Bits, Eq, Bounded, FShow);

function VnD#(a) maybe2vnd(Maybe#(a) x) =
  VnD{v: isValid(x), d: fromMaybe(?,x)};

function VnD#(Bit#(logv)) returnIndex (function Bool pred(element_type x1), Vector#(vsize, element_type) vect)
  provisos (Add#(xx1,1,vsize), Log#(vsize, logv));
  
  VnD#(Bit#(logv)) ret = VnD{v: False, d: ?};
  for (Integer i = 0; i < valueOf(vsize); i=i+1)
    if (pred(vect[i])) ret = VnD{v: True, d: fromInteger(i)};
  return ret;
endfunction

function a fromVnD(a y, VnD#(a) x) = x.v ? x.d : y;
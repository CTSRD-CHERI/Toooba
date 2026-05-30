/*-
 * Copyright (c) 2018 Alexandre Joannou
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

// C function wrappers
// get system time
import "BDPI" function Bit#(64) sysTime ();
// print ipc
import "BDPI" function Action printIPC (Bit#(64) i, Bit#(64) c);

////////////////////////////////
// debug / logging primitives //
////////////////////////////////

function Action printDbg (Maybe#(String) m_str, Fmt msg) = case (m_str) matches
  tagged Valid .str: $display("<%0t, %0s> -- ", $time, str, msg);
  default: noAction;
endcase;

typeclass PrintLog#(type a);
  function Action printLog(a msg);
  function Action printTLog(a msg);
  function Action printLogPlusArgs(String arg, a msg);
  function Action printTLogPlusArgs(String arg, a msg);
  function Action printPlusArgs(String arg, a msg);
  function Action printTPlusArgs(String arg, a msg);
endtypeclass

// Fmt instance
instance PrintLog#(Fmt);

  function Action printLog(Fmt msg) = action
    `ifndef NO_LOGS
      $display(msg);
    `endif
  endaction;
  function Action printTLog(Fmt msg) = action
    `ifndef NO_LOGS
      $display("time %0t -- ", $time, msg);
    `endif
  endaction;
  function Action printLogPlusArgs(String parg, Fmt msg) = action
    `ifndef NO_LOGS
      printPlusArgs(parg, msg);
    `endif
  endaction;
  function Action printTLogPlusArgs(String parg, Fmt msg) = action
    `ifndef NO_LOGS
      printTPlusArgs(parg, msg);
    `endif
  endaction;
  function Action printPlusArgs(String parg, Fmt msg) = action
    Bool doPrint <- $test$plusargs(parg);
    if (doPrint) $display(msg);
  endaction;
  function Action printTPlusArgs(String parg, Fmt msg) = action
    Bool doPrint <- $test$plusargs(parg);
    if (doPrint) $display("time %0t -- ", $time, msg);
  endaction;

endinstance

// String instance
instance PrintLog#(String);

  function Action printLog(String msg) = action
    `ifndef NO_LOGS
      $display(msg);
    `endif
  endaction;
  function Action printTLog(String msg) = action
    `ifndef NO_LOGS
      $display("time %0t -- ", $time, msg);
    `endif
  endaction;
  function Action printLogPlusArgs(String parg, String msg) = action
    `ifndef NO_LOGS
      printPlusArgs(parg, msg);
    `endif
  endaction;
  function Action printTLogPlusArgs(String parg, String msg) = action
    `ifndef NO_LOGS
      printTPlusArgs(parg, msg);
    `endif
  endaction;
  function Action printPlusArgs(String parg, String msg) = action
    Bool doPrint <- $test$plusargs(parg);
    if (doPrint) $display(msg);
  endaction;
  function Action printTPlusArgs(String parg, String msg) = action
    Bool doPrint <- $test$plusargs(parg);
    if (doPrint) $display("time %0t -- ", $time, msg);
  endaction;

endinstance

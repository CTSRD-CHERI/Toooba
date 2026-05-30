/*-
 * Copyright (c) 2022 Alexandre Joannou
 * All rights reserved.
 *
 * This material is based upon work supported by the DoD Information Analysis
 * Center Program Management Office (DoD IAC PMO), sponsored by the Defense
 * Technical Information Center (DTIC) under Contract No. FA807518D0004.  Any
 * opinions, findings and conclusions or recommendations expressed in this
 * material are those of the author(s) and do not necessarily reflect the views
 * of the Air Force Installation Contracting Agency (AFICA).
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

package CreditBasedFlowControl;

import Primitives :: *;
import SourceSink :: *;

import FIFOF :: *;
import Connectable :: *;

typedef struct {
  Source #(t) data;
  Sink #(Bit #(0)) credit;
} SourceWithCredit #(type t);

typedef struct {
  Sink #(t) data;
  Source #(Bit #(0)) credit;
} SinkWithCredit #(type t);

instance Connectable #(SourceWithCredit #(t), SinkWithCredit #(t))
  provisos (Bits #(t, _sz));
  module mkConnection #( SourceWithCredit #(t) src
                       , SinkWithCredit #(t) snk)
                       (Empty);
    mkConnection (src.data, snk.data);
    mkConnection (src.credit, snk.credit);
  endmodule
endinstance

instance Connectable #(SinkWithCredit #(t), SourceWithCredit #(t))
  provisos (Connectable#(SourceWithCredit #(t), SinkWithCredit #(t)));
  module mkConnection #( SinkWithCredit #(t) snk
                       , SourceWithCredit #(t) src )
                       (Empty);
    mkConnection (src, snk);
  endmodule
endinstance

module toSourceWithCredit #(parameter NumProxy #(t_max_credits) _proxy, t_src s)
                           (SourceWithCredit #(t))
  provisos ( ToSource #(t_src, t)
           , NumAlias #(t_credits_w, TLog #(TAdd #(t_max_credits, 1)))
           );

  Reg #(Bit #(t_credits_w)) r_credits <- mkReg (0);
  PulseWire inc_credits <- mkPulseWire;
  PulseWire dec_credits <- mkPulseWire;

  (* fire_when_enabled, no_implicit_conditions *)
  rule book_keeping;
    r_credits <= r_credits + ((inc_credits) ? 1 : 0)
                           - ((dec_credits) ? 1 : 0);
  endrule

  function f (_) = dec_credits.send;

  Bool canPutCredit = r_credits < fromInteger (valueOf (t_max_credits));
  return SourceWithCredit {
    data: onDrop (f, guardSource (toSource (s), r_credits <= 0))
  , credit: interface Sink;
              method canPut = canPutCredit;
              method put (_) if (canPutCredit) = inc_credits.send;
            endinterface
  };
endmodule

module toSinkWithCredit #(parameter NumProxy #(t_max_credits) _proxy, t_snk s)
                         (SinkWithCredit #(t))
  provisos ( ToSink #(t_snk, t)
           , Bits #(t, _sz)
           );

  let buf_ff <- mkSizedFIFOF (valueOf (t_max_credits));
  let credits_ff <- mkFIFOF;
  function sendCredit (_) = credits_ff.enq (?);

  let onResetCount <- mkReg (0);
  let isInit = onResetCount < fromInteger (valueOf (t_max_credits));

  (* fire_when_enabled *)
  rule do_init (isInit);
    onResetCount <= onResetCount + 1;
    sendCredit (?);
  endrule

  mkConnection ( guardSource (onDrop (sendCredit, toSource (buf_ff)), isInit)
               , toSink (s));

  return SinkWithCredit {data: toSink (buf_ff), credit: toSource (credits_ff)};
endmodule

////////////////////////////////////////////////////////////////////////////////

module mkFlatMerge8 #( Source #(a1) src1
                     , Source #(a2) src2
                     , Source #(a3) src3
                     , Source #(a4) src4
                     , Source #(a5) src5
                     , Source #(a6) src6
                     , Source #(a7) src7
                     , Source #(a8) src8 )
  (Source #(merged_a_tuple))
  provisos ( Alias #( merged_a_tuple
                    , Tuple8 #( Maybe #(a1)
                              , Maybe #(a2)
                              , Maybe #(a3)
                              , Maybe #(a4)
                              , Maybe #(a5)
                              , Maybe #(a6)
                              , Maybe #(a7)
                              , Maybe #(a8) ) )
           );

  let doDrop <- mkPulseWire;

  (* fire_when_enabled, no_implicit_conditions *)
  rule drop1 (doDrop && src1.canPeek); src1.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop2 (doDrop && src2.canPeek); src2.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop3 (doDrop && src3.canPeek); src3.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop4 (doDrop && src4.canPeek); src4.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop5 (doDrop && src5.canPeek); src5.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop6 (doDrop && src6.canPeek); src6.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop7 (doDrop && src7.canPeek); src7.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop8 (doDrop && src8.canPeek); src8.drop; endrule

  let mergedFlit = tuple8 ( (src1.canPeek) ? Valid (src1.peek) : Invalid
                          , (src2.canPeek) ? Valid (src2.peek) : Invalid
                          , (src3.canPeek) ? Valid (src3.peek) : Invalid
                          , (src4.canPeek) ? Valid (src4.peek) : Invalid
                          , (src5.canPeek) ? Valid (src5.peek) : Invalid
                          , (src6.canPeek) ? Valid (src6.peek) : Invalid
                          , (src7.canPeek) ? Valid (src7.peek) : Invalid
                          , (src8.canPeek) ? Valid (src8.peek) : Invalid );

  Bool canPeekMerged =    src1.canPeek
                       || src2.canPeek
                       || src3.canPeek
                       || src4.canPeek
                       || src5.canPeek
                       || src6.canPeek
                       || src7.canPeek
                       || src8.canPeek ;

  return interface Source;
    method canPeek = canPeekMerged;
    method peek if (canPeekMerged) = mergedFlit;
    method drop if (canPeekMerged) = doDrop.send;
  endinterface;

endmodule

module mk8CreditChannelTX #(
  parameter NumProxy #(t_max_credits) proxyMaxCredits
, Tuple8 #( t_src_1, t_src_2, t_src_3, t_src_4
          , t_src_5, t_src_6, t_src_7, t_src_8 ) srcs
, function module #(Source #(b)) mkMerger ( Source #(a1) src1
                                          , Source #(a2) src2
                                          , Source #(a3) src3
                                          , Source #(a4) src4
                                          , Source #(a5) src5
                                          , Source #(a6) src6
                                          , Source #(a7) src7
                                          , Source #(a8) src8 ) )
(Tuple2 #(Source #(b), Tuple8 #( Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0)) )))
provisos ( ToSource #(t_src_1, a1)
         , ToSource #(t_src_2, a2)
         , ToSource #(t_src_3, a3)
         , ToSource #(t_src_4, a4)
         , ToSource #(t_src_5, a5)
         , ToSource #(t_src_6, a6)
         , ToSource #(t_src_7, a7)
         , ToSource #(t_src_8, a8) );

  let s1 <- toSourceWithCredit (proxyMaxCredits, tpl_1 (srcs));
  let s2 <- toSourceWithCredit (proxyMaxCredits, tpl_2 (srcs));
  let s3 <- toSourceWithCredit (proxyMaxCredits, tpl_3 (srcs));
  let s4 <- toSourceWithCredit (proxyMaxCredits, tpl_4 (srcs));
  let s5 <- toSourceWithCredit (proxyMaxCredits, tpl_5 (srcs));
  let s6 <- toSourceWithCredit (proxyMaxCredits, tpl_6 (srcs));
  let s7 <- toSourceWithCredit (proxyMaxCredits, tpl_7 (srcs));
  let s8 <- toSourceWithCredit (proxyMaxCredits, tpl_8 (srcs));

  let s <- mkMerger ( s1.data
                    , s2.data
                    , s3.data
                    , s4.data
                    , s5.data
                    , s6.data
                    , s7.data
                    , s8.data );

  return tuple2 (s, tuple8 ( s1.credit
                           , s2.credit
                           , s3.credit
                           , s4.credit
                           , s5.credit
                           , s6.credit
                           , s7.credit
                           , s8.credit ));

endmodule

module mk8CreditChannelRX #(
  parameter NumProxy #(t_max_credits) proxyMaxCredits
, Tuple8 #( t_snk_1, t_snk_2, t_snk_3, t_snk_4
          , t_snk_5, t_snk_6, t_snk_7, t_snk_8 ) snks
, function module #(Sink #(b)) mkUnMerger ( Sink #(a1) snk1
                                          , Sink #(a2) snk2
                                          , Sink #(a3) snk3
                                          , Sink #(a4) snk4
                                          , Sink #(a5) snk5
                                          , Sink #(a6) snk6
                                          , Sink #(a7) snk7
                                          , Sink #(a8) snk8 ) )
(Tuple2 #(Sink #(b), Tuple8 #( Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0)) )))
provisos ( ToSink #(t_snk_1, a1), Bits #(a1, a1_sz)
         , ToSink #(t_snk_2, a2), Bits #(a2, a2_sz)
         , ToSink #(t_snk_3, a3), Bits #(a3, a3_sz)
         , ToSink #(t_snk_4, a4), Bits #(a4, a4_sz)
         , ToSink #(t_snk_5, a5), Bits #(a5, a5_sz)
         , ToSink #(t_snk_6, a6), Bits #(a6, a6_sz)
         , ToSink #(t_snk_7, a7), Bits #(a7, a7_sz)
         , ToSink #(t_snk_8, a8), Bits #(a8, a8_sz) );

  let s1 <- toSinkWithCredit (proxyMaxCredits, tpl_1 (snks));
  let s2 <- toSinkWithCredit (proxyMaxCredits, tpl_2 (snks));
  let s3 <- toSinkWithCredit (proxyMaxCredits, tpl_3 (snks));
  let s4 <- toSinkWithCredit (proxyMaxCredits, tpl_4 (snks));
  let s5 <- toSinkWithCredit (proxyMaxCredits, tpl_5 (snks));
  let s6 <- toSinkWithCredit (proxyMaxCredits, tpl_6 (snks));
  let s7 <- toSinkWithCredit (proxyMaxCredits, tpl_7 (snks));
  let s8 <- toSinkWithCredit (proxyMaxCredits, tpl_8 (snks));

  let s <- mkUnMerger ( s1.data
                      , s2.data
                      , s3.data
                      , s4.data
                      , s5.data
                      , s6.data
                      , s7.data
                      , s8.data );

  return tuple2 (s, tuple8 ( s1.credit
                           , s2.credit
                           , s3.credit
                           , s4.credit
                           , s5.credit
                           , s6.credit
                           , s7.credit
                           , s8.credit ));

endmodule

////////////////////////////////////////////////////////////////////////////////

module mkFlatMerge5 #( Source #(a1) src1
                     , Source #(a2) src2
                     , Source #(a3) src3
                     , Source #(a4) src4
                     , Source #(a5) src5 )
  (Source #(merged_a_tuple))
  provisos ( Alias #( merged_a_tuple
                    , Tuple5 #( Maybe #(a1)
                              , Maybe #(a2)
                              , Maybe #(a3)
                              , Maybe #(a4)
                              , Maybe #(a5) ) )
           );

  let doDrop <- mkPulseWire;

  (* fire_when_enabled, no_implicit_conditions *)
  rule drop1 (doDrop && src1.canPeek); src1.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop2 (doDrop && src2.canPeek); src2.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop3 (doDrop && src3.canPeek); src3.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop4 (doDrop && src4.canPeek); src4.drop; endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule drop5 (doDrop && src5.canPeek); src5.drop; endrule

  let mergedFlit = tuple5 ( (src1.canPeek) ? Valid (src1.peek) : Invalid
                          , (src2.canPeek) ? Valid (src2.peek) : Invalid
                          , (src3.canPeek) ? Valid (src3.peek) : Invalid
                          , (src4.canPeek) ? Valid (src4.peek) : Invalid
                          , (src5.canPeek) ? Valid (src5.peek) : Invalid );

  Bool canPeekMerged =    src1.canPeek
                       || src2.canPeek
                       || src3.canPeek
                       || src4.canPeek
                       || src5.canPeek ;

  return interface Source;
    method canPeek = canPeekMerged;
    method peek if (canPeekMerged) = mergedFlit;
    method drop if (canPeekMerged) = doDrop.send;
  endinterface;

endmodule

module mk5CreditChannelTX #(
  parameter NumProxy #(t_max_credits) proxyMaxCredits
, Tuple5 #(t_src_1, t_src_2, t_src_3, t_src_4, t_src_5) srcs
, function module #(Source #(b)) mkMerger ( Source #(a1) src1
                                          , Source #(a2) src2
                                          , Source #(a3) src3
                                          , Source #(a4) src4
                                          , Source #(a5) src5 ) )
(Tuple2 #(Source #(b), Tuple5 #( Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0))
                               , Sink #(Bit #(0)) )))
provisos ( ToSource #(t_src_1, a1)
         , ToSource #(t_src_2, a2)
         , ToSource #(t_src_3, a3)
         , ToSource #(t_src_4, a4)
         , ToSource #(t_src_5, a5) );

  let s1 <- toSourceWithCredit (proxyMaxCredits, tpl_1 (srcs));
  let s2 <- toSourceWithCredit (proxyMaxCredits, tpl_2 (srcs));
  let s3 <- toSourceWithCredit (proxyMaxCredits, tpl_3 (srcs));
  let s4 <- toSourceWithCredit (proxyMaxCredits, tpl_4 (srcs));
  let s5 <- toSourceWithCredit (proxyMaxCredits, tpl_5 (srcs));

  let s <- mkMerger ( s1.data
                    , s2.data
                    , s3.data
                    , s4.data
                    , s5.data );

  return tuple2 (s, tuple5 ( s1.credit
                           , s2.credit
                           , s3.credit
                           , s4.credit
                           , s5.credit ));

endmodule

module mk5CreditChannelRX #(
  parameter NumProxy #(t_max_credits) proxyMaxCredits
, Tuple5 #(t_snk_1, t_snk_2, t_snk_3, t_snk_4, t_snk_5) snks
, function module #(Sink #(b)) mkUnMerger ( Sink #(a1) snk1
                                          , Sink #(a2) snk2
                                          , Sink #(a3) snk3
                                          , Sink #(a4) snk4
                                          , Sink #(a5) snk8 ) )
(Tuple2 #(Sink #(b), Tuple5 #( Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0))
                             , Source #(Bit #(0)) )))
provisos ( ToSink #(t_snk_1, a1), Bits #(a1, a1_sz)
         , ToSink #(t_snk_2, a2), Bits #(a2, a2_sz)
         , ToSink #(t_snk_3, a3), Bits #(a3, a3_sz)
         , ToSink #(t_snk_4, a4), Bits #(a4, a4_sz)
         , ToSink #(t_snk_5, a5), Bits #(a5, a5_sz) );

  let s1 <- toSinkWithCredit (proxyMaxCredits, tpl_1 (snks));
  let s2 <- toSinkWithCredit (proxyMaxCredits, tpl_2 (snks));
  let s3 <- toSinkWithCredit (proxyMaxCredits, tpl_3 (snks));
  let s4 <- toSinkWithCredit (proxyMaxCredits, tpl_4 (snks));
  let s5 <- toSinkWithCredit (proxyMaxCredits, tpl_5 (snks));

  let s <- mkUnMerger ( s1.data
                      , s2.data
                      , s3.data
                      , s4.data
                      , s5.data );

  return tuple2 (s, tuple5 ( s1.credit
                           , s2.credit
                           , s3.credit
                           , s4.credit
                           , s5.credit ));

endmodule

endpackage

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

package BasicAXI4FifosExample;

import SourceSink :: *;
import BlueAXI4 :: *;
import FIFOF :: *;

module testAXI4Fifos (Empty);

  AXI4_Master #(2, 32, 64, 0, 0, 0, 0, 0) m <- mkUnixFifo_AXI4_Master ("slave");

  let arff <- mkFIFOF;
  rule get_read_req;
    let arflit <- get(m.ar);
    $display ("arflit: \t", fshow (arflit));
    $display ("arflit: \t", fshow (pack(arflit)));
    arff.enq(arflit);
  endrule
  Reg #(Bit #(16)) cnt <- mkReg (0);
  rule put_read_rsp;
    let isLast = cnt == zeroExtend (pack (arff.first.arlen));
    AXI4_RFlit #(2, 64, 0) rflit = defaultValue;
    rflit.rlast = isLast;
    m.r.put(rflit);
    $display ("rflit: \t", fshow (rflit));
    $display ("rflit: \t", fshow (pack(rflit)));
    if (isLast) begin
      cnt <= 0;
      arff.deq;
    end else cnt <= cnt + 1;
  endrule
  //rule handle_write;
  //  let awflit = m.aw.peek;
  //  let wflit <- get (m.w);
  //  $display ("write: \n\t", fshow (awflit), "\n\t", fshow (wflit));
  //  if (wflit.wlast) begin
  //    m.aw.drop;
  //    m.b.put (defaultValue);
  //    $display ("write done");
  //  end
  //endrule
endmodule

endpackage

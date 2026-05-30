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

package AXI4UnixBridges;

import SourceSink :: *;
import AXI4 :: *;
import BlueUnixBridges :: *;

////////////////////////////////////////////////////////////////////////////////
module mkUnixFifo_AXI4_Master #(String dirname)
  (AXI4_Master #( t_id, t_addr, t_data, t_awuser, t_wuser, t_buser
                                      , t_aruser, t_ruser ));

  let awSrc <- mkUnixFifoSource (dirname +  "/awSink");
  let  wSrc <- mkUnixFifoSource (dirname +   "/wSink");
  let  bSnk <- mkUnixFifoSink   (dirname + "/bSource");
  let arSrc <- mkUnixFifoSource (dirname +  "/arSink");
  let  rSnk <- mkUnixFifoSink   (dirname + "/rSource");
  interface aw = awSrc;
  interface  w =  wSrc;
  interface  b =  bSnk;
  interface ar = arSrc;
  interface  r =  rSnk;

endmodule

////////////////////////////////////////////////////////////////////////////////
module mkUnixFifo_AXI4_Slave #(String dirname)
  (AXI4_Slave #( t_id, t_addr, t_data, t_awuser, t_wuser, t_buser
                                     , t_aruser, t_ruser ));

  let awSnk <- mkUnixFifoSink   (dirname + "/awSource");
  let  wSnk <- mkUnixFifoSink   (dirname +  "/wSource");
  let  bSrc <- mkUnixFifoSource (dirname +    "/bSink");
  let arSnk <- mkUnixFifoSink   (dirname + "/arSource");
  let  rSrc <- mkUnixFifoSource (dirname +    "/rSink");
  interface aw = awSnk;
  interface  w =  wSnk;
  interface  b =  bSrc;
  interface ar = arSnk;
  interface  r =  rSrc;

endmodule

////////////////////////////////////////////////////////////////////////////////
module mkUnixSocket_AXI4_Master #( String dirname
                                 , Integer awPort
                                 , Integer  wPort
                                 , Integer  bPort
                                 , Integer arPort
                                 , Integer  rPort )
  (AXI4_Master #( t_id, t_addr, t_data, t_awuser, t_wuser, t_buser
                                      , t_aruser, t_ruser ));

  let awSrc <- mkUnixSocketSource (dirname +  "/awSink", awPort);
  let  wSrc <- mkUnixSocketSource (dirname +   "/wSink",  wPort);
  let  bSnk <- mkUnixSocketSink   (dirname + "/bSource",  bPort);
  let arSrc <- mkUnixSocketSource (dirname +  "/arSink", arPort);
  let  rSnk <- mkUnixSocketSink   (dirname + "/rSource",  rPort);
  interface aw = awSrc;
  interface  w =  wSrc;
  interface  b =  bSnk;
  interface ar = arSrc;
  interface  r =  rSnk;

endmodule

////////////////////////////////////////////////////////////////////////////////
module mkUnixSocket_AXI4_Slave #( String dirname
                                , Integer awPort
                                , Integer  wPort
                                , Integer  bPort
                                , Integer arPort
                                , Integer  rPort )
  (AXI4_Slave #( t_id, t_addr, t_data, t_awuser, t_wuser, t_buser
                                     , t_aruser, t_ruser ));

  let awSnk <- mkUnixSocketSink   (dirname + "/awSource", awPort);
  let  wSnk <- mkUnixSocketSink   (dirname +  "/wSource",  wPort);
  let  bSrc <- mkUnixSocketSource (dirname +    "/bSink",  bPort);
  let arSnk <- mkUnixSocketSink   (dirname + "/arSource", arPort);
  let  rSrc <- mkUnixSocketSource (dirname +    "/rSink",  rPort);
  interface aw = awSnk;
  interface  w =  wSnk;
  interface  b =  bSrc;
  interface ar = arSnk;
  interface  r =  rSrc;

endmodule

endpackage

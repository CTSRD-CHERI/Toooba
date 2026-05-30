/*-
 * Copyright (c) 2018 Jonathan Woodruff
 * Copyright (c) 2018-2019 Alexandre Joannou
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

import DefaultValue::*;
import AXI4::*;
import MemTypesCHERI::*;
import Fabric_Defs::*;

typedef struct {
  AXI4_AWFlit#(id_, addr_, 0) aw;
  AXI4_WFlit#(data_, tag_) w;
} WriteReqFlit#(numeric type id_, numeric type addr_, numeric type data_, numeric type tag_)
deriving (Bits, FShow);

typedef union tagged {
  WriteReqFlit#(id_, addr_, data_, tag_) Write;
  AXI4_ARFlit#(id_, addr_, user_) Read;
} ReqFlit#(numeric type id_, numeric type addr_, numeric type data_, numeric type tag_, numeric type user_)
deriving (Bits, FShow);
instance DefaultValue#(ReqFlit#(id_, addr_, data_, tag_, user_));
  function defaultValue = tagged Read defaultValue;
endinstance

typedef union tagged {
  AXI4_BFlit#(id_, 0) Write;
  AXI4_RFlit#(id_, data_, tag_) Read;
} RspFlit#(numeric type id_, numeric type data_, numeric type tag_)
deriving (Bits, FShow);
instance DefaultValue#(RspFlit#(id_, data_, tag_));
  function defaultValue = tagged Write defaultValue;
endinstance

typedef ReqFlit#(id_, addr_, TMul#(CheriBusBytes, 8), CapsPerFlit, 1) MemReq#(numeric type id_, numeric type addr_);
typedef RspFlit#(id_, TMul#(CheriBusBytes, 8), CapsPerFlit)           MemRsp#(numeric type id_);

typedef ReqFlit#(id_, addr_, TMul#(CheriBusBytes, 8), 0, 0) DRAMReq#(numeric type id_, numeric type addr_);
typedef RspFlit#(id_, TMul#(CheriBusBytes, 8), 0)           DRAMRsp#(numeric type id_);

// Request ranslators between AXI and CHERI Memory

function CheriMemRequest axi2mem_req(MemReq#(id_, addr_) mr)
  provisos (Add#(a__, id_, CheriTransactionIDWidth), Add#(b__, addr_, 64));
  CheriMemRequest req = ?;
  case (mr) matches
    tagged Write .w: begin
      //XXX horrible hack - from 40 bits restriction
      // support addresses up to 64 bits, only considers bottom 40 bits
      Bit#(64) tmp = zeroExtend(w.aw.awaddr);
      req = CheriMemRequest{
        addr: unpack(truncate(tmp)),
        masterID: 0,
        transactionID: zeroExtend(w.aw.awid),
        operation: tagged Write {
                        uncached: (w.aw.awcache < 4), // All options less than 4 look like uncached.
                        conditional: False, // For now?
                        byteEnable: unpack(w.w.wstrb),
                        bitEnable: -1,
                        data: Data{cap: unpack(w.w.wuser), data: w.w.wdata},
                        last: w.w.wlast,
                        length: w.aw.awlen
                    },
        cancelled: False
      };
      req.addr.byteOffset = 0;
    end
    tagged Read .r: begin
      //XXX horrible hack - from 40 bits restriction
      // support addresses up to 64 bits, only considers bottom 40 bits
      Bit#(64) tmp = zeroExtend(r.araddr);
      req = CheriMemRequest{
        addr: unpack(truncate(tmp)),
        masterID: 0,
        transactionID: zeroExtend(r.arid),
        operation: tagged Read {
                        uncached: (r.arcache < 4), // All options less than 4 look like uncached.
                        linked: False, // For now?
                        noOfFlits: unpack(truncate(r.arlen)), // XXX support full burst length
                        bytesPerFlit: unpack(pack(r.arsize)),
                        tagOnlyRead: r.aruser[0] == 1'b1
                    },
        cancelled: False
      };
    end
  endcase
  return req;
endfunction

function DRAMReq#(id_, addr_) mem2axi_req(CheriMemRequest mr)
  provisos(Add#(a__, SizeOf#(ReqId), id_), Add#(b__, addr_, 64));
  DRAMReq#(id_, addr_) req = defaultValue;
  case (mr.operation) matches
    tagged Write .w: begin
      //XXX horrible hack - from 40 bits restriction
      // support addresses up to 64 bits, only considers bottom 40 bits
      Bit#(64) tmp = zeroExtend(pack(mr.addr) & (~0 << pack(cheriBusBytes)));
      Bit#(TAdd#(1, TLog#(CheriBusBytes))) byteEnableOnes = pack(countOnes(pack(w.byteEnable)));
      req = tagged Write WriteReqFlit{
        aw: AXI4_AWFlit{
          awid: zeroExtend(pack(getReqId(mr))),
          awaddr: truncate(tmp + zeroExtend(pack(countZerosLSB(pack(w.byteEnable))))),
          awlen: w.length,
          awsize: unpack(pack(countZerosLSB(byteEnableOnes))), // XXX: Must have power-of-two number of byte-enables set
          awburst: INCR,
          awlock: NORMAL,
          awcache: fabric_default_awcache,
          awprot: 0,
          awqos: 0,
          awregion: 0,
          awuser: ?
        },
        w: AXI4_WFlit{
          wdata: w.data.data,
          wstrb: zeroExtend(pack(w.byteEnable)),
          wlast: w.last,
          wuser: ?
        }
      };
    end
    tagged Read .r: begin
      //XXX horrible hack - from 40 bits restriction
      // support addresses up to 64 bits, only considers bottom 40 bits
      Bit#(64) tmp = zeroExtend(pack(mr.addr));
      req = tagged Read AXI4_ARFlit{
        arid: zeroExtend(pack(getReqId(mr))),
        araddr: truncate(tmp),
        arlen: zeroExtend(pack(r.noOfFlits)),
        arsize: unpack(pack(r.bytesPerFlit)),
        arburst: INCR,
        arlock: NORMAL,
        arcache: fabric_default_arcache,
        arprot: 0,
        arqos: 0,
        arregion: 0,
        aruser: ?
      };
    end
  endcase
  return req;
endfunction

// Response ranslators between AXI and CHERI Memory

function CheriMemResponse axi2mem_rsp(DRAMRsp#(id_) mr)
  provisos (Add#(a__, SizeOf#(ReqId), id_));
  CheriMemResponse rsp = defaultValue;
  case (mr) matches
    tagged Write .w: begin
      ReqId req_id = unpack(truncate(w.bid));
      rsp = CheriMemResponse{
        masterID: req_id.masterID,
        transactionID: req_id.transactionID,
        error: NoError,
        data: ?,
        operation: tagged Write
      };
    end
    tagged Read .r: begin
      ReqId req_id = unpack(truncate(r.rid));
      rsp = CheriMemResponse{
        masterID: req_id.masterID,
        transactionID: req_id.transactionID,
        error: NoError,
        data: Data{cap: ?, data: r.rdata},
        operation: tagged Read {last: r.rlast, tagOnlyRead: False} // XXX support for CLoadTags lost by AXI conversion
      };
    end
  endcase
  return rsp;
endfunction

function MemRsp#(id_) mem2axi_rsp(CheriMemResponse mr)
  provisos (Add#(a__, id_, CheriTransactionIDWidth));
  MemRsp#(id_) rsp = defaultValue;
  ReqId req_id = getRespId(mr);
  case (mr.operation) matches
    tagged Write: begin
      rsp = tagged Write AXI4_BFlit{
        bid: truncate(req_id.transactionID),
        bresp: OKAY,
        buser: ?
      };
    end
    tagged Read .r:
      rsp = tagged Read AXI4_RFlit{
        rid: truncate(req_id.transactionID),
        rdata: mr.data.data,
        rresp: OKAY,
        rlast: r.last,
        ruser: pack(mr.data.cap)
      };
  endcase
  return rsp;
endfunction

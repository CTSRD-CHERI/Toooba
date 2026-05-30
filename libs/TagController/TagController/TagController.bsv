/*-
 * Copyright (c) 2013-2018 Jonathan Woodruff
 * Copyright (c) 2013 Philip Withnall
 * Copyright (c) 2013 Robert M. Norton
 * Copyright (c) 2014-2016 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
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

import MasterSlaveCHERI::*;
import MemTypesCHERI::*;
import RoutableCHERI::*;
import GetPut::*;
import Debug::*;
import Connectable::*;
import FF::*;
import Vector::*;
import Bag::*;
import VnD::*;
import TagTableStructure::*;
`ifdef STATCOUNTERS
import StatCounters::*;
`elsif PERFORMANCE_MONITORING
import PerformanceMonitor::*;
import CacheCore::*;
`endif
//import TagLookup::*;
import MultiLevelTagLookup::*;

/******************************************************************************
 * mkTagController
 *
 * This module provides a proxy for memory accesses which adds support for
 * tagged memory. It connects to memory on one side and the processor/L2 cache
 * on the other. Tag values are stored in memory (currently at the top of DRAM
 * and there is a cache of 32ki tags (representing 1MB memory) stored in BRAM.
 * Read responses are amended with the correct tag value and write requests update
 * the value in the tag cache (which is later written back to memory).
 *
 *****************************************************************************/

// interface types
///////////////////////////////////////////////////////////////////////////////

interface TagControllerIfc;
  interface Slave#(CheriMemRequest, CheriMemResponse)  cache;
  interface Master#(CheriMemRequest, CheriMemResponse) memory;
  `ifdef STATCOUNTERS
  interface Get#(ModuleEvents) cacheEvents;
  `elsif PERFORMANCE_MONITORING
  method EventsCacheCore events;
  `endif
endinterface

typedef struct {
  Bool tagOnlyRead;
  CapOffsetInLine bank;
  CheriMasterID masterID;
  CheriTransactionID transactionID;
} AddrFrame deriving(Bits, Eq, FShow);

// internal types
///////////////////////////////////////////////////////////////////////////////

typedef TLog#(TDiv#(CapWidth, CheriDataWidth)) LogFlitsPerCap;
typedef TMax#(TDiv#(CheriDataWidth,CapWidth), 1) CapsPerFlit;
typedef enum {TagLookupReq, StdReq} MemReqType deriving (FShow, Bits, Eq);
typedef 4 InFlight;
typedef 8 MaxBurstLength;
typedef Bit#(TLog#(MaxBurstLength)) Frame;
typedef Bit#(8) ReqIdCount;

typedef struct {
  ReqId reqId;
  ReqIdCount count; // Less than 256 outstanding transactions for one ID?  Surely?
} TagReqId deriving(Bits, Eq, FShow);

typedef struct {
  ReqId id;
  Bool tagOnlyRead;
} LookupReqInfo deriving(Bits, Eq, FShow);

typedef struct {
  CheriTagResponse rsp;
  Bool tagOnlyRead;
} LookupRspInfo deriving(Bits, Eq, FShow);

// mkTagController module definition
///////////////////////////////////////////////////////////////////////////////

(*synthesize*)
module mkTagController(TagControllerIfc);

  // constant parameters
  /////////////////////////////////////////////////////////////////////////////

  // masterID used for memory requests from the lookup engine
  CheriMasterID mID = 1;

  // components instanciations
  /////////////////////////////////////////////////////////////////////////////

  // tag lookup module
  //TagLookupIfc tagLookup <- mkTagLookup(mID);
  TagLookupIfc tagLookup <- mkMultiLevelTagLookup(
                                mID,
                                unpack(fromInteger(table_end_addr)),
                                tableStructure,
                                unpack(fromInteger(table_start_addr)),
                                covered_mem_size
                            );
  // lookup responses fifo
  // Size of these structures must be >= number of outstandring requests from the L2.
  FFBag#(InFlight, ReqId, LookupRspInfo, InFlight) lookupRsp <- mkFFBag;
  FFBag#(InFlight, ReqId, AddrFrame, InFlight)     addrFrame <- mkFFBag;
  FF#(LookupReqInfo, 2)                            pendingLookups <- mkFF;
  // lookup response frame to access (for multi-flit transactions)
  Reg#(Frame) memoryResponseFrame <- mkReg(0);
  Reg#(CheriTagWrite) tagWrite <- mkReg(unpack(0));
  // memory requests fifo
  FF#(CheriMemRequest, TMul#(MaxBurstLength, 2)) mReqs <- mkUGFF();
  FF#(Bit#(0),InFlight) mReqBurst <- mkUGFF;
  // memory responses fifo
  FF#(CheriMemResponse, TMul#(MaxBurstLength, InFlight)) mRsps <- mkUGFFDebug("TagController_mRsps");

  // Forwarding requests from the tag cache takes priority unless we have an ongoing burst request being forwarded,
  // or if there is not enough space for a full burst.
  Bool slvCanPut =
    tagLookup.cache.request.canPut() &&
    mReqs.notFull() && mReqBurst.notFull() && !addrFrame.full();

  // module rules
  /////////////////////////////////////////////////////////////////////////////

  // drain tag lookup responses out of the tag lookup engine
  rule getTagLookupResponse;
    CheriTagResponse tags <- tagLookup.cache.response.get();
    debug2("tagcontroller", $display("<time %0t TagController> Completed lookup response: ", $time, fshow(tags)));
    LookupReqInfo lookup = pendingLookups.first;
    lookupRsp.enq(lookup.id, LookupRspInfo{rsp: tags, tagOnlyRead: lookup.tagOnlyRead});
    pendingLookups.deq;
  endrule

  // helper functions / signals
  /////////////////////////////////////////////////////////////////////////////
  // generate the next memory response
  ReqId respID = ?;
  VnD#(LookupRspInfo) tagRsp = VnD{v: False, d: ?};
  CheriMemResponse newResp = mRsps.first;
  Bool tagsOnlyResponse = False;
  Bool untrackedResponse = False;
  function Bool isTagOnlyRead (LookupRspInfo x) = x.tagOnlyRead;
  let tagOnlyRsp = lookupRsp.searchFirsts(isTagOnlyRead);
  if (tagOnlyRsp.v && memoryResponseFrame==0) begin
    respID = tagOnlyRsp.d.key;
    tagsOnlyResponse = True;
    tagRsp.d = tagOnlyRsp.d.dat;
    tagRsp.v = True;
    newResp = CheriMemResponse{
        masterID: respID.masterID,
        transactionID: respID.transactionID,
        error: NoError,
        operation: tagged Read{last: True, tagOnlyRead: True},
        data: unpack(0)
    };
    case (tagOnlyRsp.d.dat.rsp.tags) matches
      tagged Covered .ts : newResp.data.data = zeroExtend(pack(ts));
      tagged Uncovered   : newResp.data.data = 0;
    endcase
  end
  if (!tagsOnlyResponse && mRsps.notEmpty) begin
    if (mRsps.first().operation matches tagged Read .rop) begin
      respID = getRespId(mRsps.first);
      tagRsp = lookupRsp.first(respID);
      Vector#(CapsPerFlit,Bool) tags = replicate(True);
      VnD#(AddrFrame) thisAddrFrame = addrFrame.first(respID);
      // look at the tag lookup response
      case (tagRsp.d.rsp.tags) matches
        tagged Covered .ts : begin
          CapOffsetInLine base = thisAddrFrame.d.bank + truncate(memoryResponseFrame >> valueOf(LogFlitsPerCap));
          for (Integer i = 0; i < valueOf(CapsPerFlit); i = i + 1)
            tags[i] = ts[base + fromInteger(i)];
        end
        tagged Uncovered   : tags = unpack(0);
      endcase
      // update the new response with appropriate tags
      newResp.data.cap = tags;
    end else untrackedResponse = True;
  end

  Bool slvCanGet = tagRsp.v || untrackedResponse;

  // Calculate peek of memory request interface.
  CheriMemRequest memoryGetPeek = (mReqBurst.notEmpty) ? mReqs.first:tagLookup.memory.request.peek();
  Bool memoryCanGet = mReqBurst.notEmpty || tagLookup.memory.request.canGet;

  // Comment in when debugging flow control.
/*  rule debug;
    debug2("tagcontroller", $display("<time %0t TagController> slvCanPut:%x tagLookup.cache.request.canPut(1):%x tagLookup.memory.request.canGet(0):%x mReqs.notFull(1):%x",
                                     $time, slvCanPut, tagLookup.cache.request.canPut(), tagLookup.memory.request.canGet(), mReqs.notFull()));
    debug2("tagcontroller", $display("<time %0t TagController> slvCanGet:%x tagRsp.v(1):%x untrackedResponse(1):%x",
                                     $time, slvCanGet, tagRsp.v, untrackedResponse));
  endrule*/

  // module Slave interface
  /////////////////////////////////////////////////////////////////////////////

  interface Slave cache;
    // request side
    ///////////////////////////////////////////////////////
    interface CheckedPut request;
      method Bool canPut() = slvCanPut;
      method Action put(CheriMemRequest req) if (slvCanPut);
        let lineAlignedAddr = pack(req.addr);
        Bit#(TLog#(CpuLineSize)) zero = 0;
        lineAlignedAddr = {truncateLSB(lineAlignedAddr),zero};
        CheriTagRequest tagReq = CheriTagRequest {addr: unpack(lineAlignedAddr), operation: tagged Read};
        debug2("tagcontroller", $display("<time %0t TagController> New request: ", $time, fshow(req)));
        if (req.operation matches tagged Write .wop &&& req.addr >= unpack(fromInteger(table_start_addr)) && req.addr < unpack(fromInteger(table_end_addr))) begin
          req.operation = tagged Write {
              uncached: wop.uncached,
              conditional: wop.conditional,
              byteEnable: replicate(False),
              bitEnable: 0,
              data: wop.data,
              last: wop.last,
              length: wop.length
          };
        end
        ReqId id = getReqId(req);
        Bool tagOnlyRead = False;
        if (req.operation matches tagged Read .rop &&& rop.tagOnlyRead) begin
            tagOnlyRead = True;
        end
        // We only enqueue request to DRAM if this is not a tagOnlyRead
        Bool canDoEnq = !tagOnlyRead;
        if (canDoEnq) begin
            mReqs.enq(req);
            // Signal that the next burst in mReqs can be forwarded downstream.
            // FIXME: If we receive a read request in the middle of a write
            // burst this will erroneously forward the first part of the burst,
            // followed by the read, early, and risk a tag lookup write request
            // being interleaved with it. Currently TagControllerAXI will avoid
            // interleaving the two to work around this limitation.
            if (getLastField(req)) mReqBurst.enq(?);
        end
        if (req.operation matches tagged Read .rop) begin
          // Stash the frame of the incoming address so that we can select the correct tags for the response.
          CheriCapAddress capAddr = unpack(pack(req.addr));
          addrFrame.enq(id, AddrFrame{tagOnlyRead: rop.tagOnlyRead, bank: truncate(capAddr.capNumber), masterID: req.masterID, transactionID: req.transactionID});
        end
        if (req.operation matches tagged Write .wop) begin
            CheriTagWrite newTagWrite = tagWrite;
            CheriCapAddress capAddr = unpack(pack(req.addr));
            Bit#(TLog#(SizeOf#(LineTags))) tagOffsetInLine = truncate(capAddr.capNumber);
            Integer i = 0;
            Integer bot = 0;
            for (i = 0; i < valueOf(CapsPerFlit); i = i + 1) begin
              CapOffsetInLine ibit = fromInteger(i);
              newTagWrite.tags[tagOffsetInLine + ibit] = wop.data.cap[i];
              Bit#(TMin#(CheriBusBytes, CapBytes)) capBEs = pack(wop.byteEnable)[bot+valueOf(TMin#(CheriBusBytes, CapBytes))-1:bot];
              newTagWrite.writeEnable[tagOffsetInLine + ibit] = (capBEs == 0) ? False:True;
              bot = bot + valueOf(CapBytes);
            end
            if (getLastField(req)) begin
              tagReq.operation = tagged Write newTagWrite;
              tagLookup.cache.request.put(tagReq);
              debug2("tagcontroller", $display("<time %0t TagController> Injected Write Lookup: ", $time, fshow(tagReq)));
              newTagWrite = unpack(0);
            end
            tagWrite <= newTagWrite;
        end else begin
          tagLookup.cache.request.put(tagReq);
          pendingLookups.enq(LookupReqInfo{id: id, tagOnlyRead: tagOnlyRead});
        end
      endmethod
    endinterface
    // response side
    ///////////////////////////////////////////////////////
    interface CheckedGet response;
      method Bool canGet() = slvCanGet;
      method CheriMemResponse peek() = newResp;
      method ActionValue#(CheriMemResponse) get() if (slvCanGet);
        // prepare memory response
        CheriMemResponse resp = newResp;
        ReqId id = getRespId(resp);
        // dequeue memory response fifo only when the response is not tagOnlyRead
        if (!tagsOnlyResponse) mRsps.deq();
        // in case of read response ...
        if (resp.operation matches tagged Read .rop) begin
          // on the last flit,
          if (rop.last || rop.tagOnlyRead) begin
            lookupRsp.deq(id); // dequeue the tag lookup response fifo
            addrFrame.deq(id);
            memoryResponseFrame <= 0;  // reset the current frame
          end else memoryResponseFrame <= memoryResponseFrame + 1; // for non last flits, increment frame
        end else memoryResponseFrame <= 0;
        debug2("tagcontroller", $display("<time %0t TagController> Returning response: ", $time, fshow(resp)));
        return resp;
      endmethod
    endinterface
  endinterface

  // module Master interface
  /////////////////////////////////////////////////////////////////////////////

  interface Master memory;
    interface CheckedGet request;
      method Bool canGet() = memoryCanGet;
      method CheriMemRequest peek() = memoryGetPeek;
      method ActionValue#(CheriMemRequest) get() if (memoryCanGet);
        if (mReqBurst.notEmpty) begin
          mReqs.deq();
          if (getLastField(mReqs.first)) mReqBurst.deq();
        end
        else let unused <- tagLookup.memory.request.get();
        debug2("tagcontroller", $display("<time %0t TagController> request to memory (ForwardingMemoryRequest:%d): ", $time, mReqBurst.notEmpty, " ", fshow(memoryGetPeek)));
        return memoryGetPeek;
      endmethod
    endinterface
    interface CheckedPut response;
      method Bool canPut();
        return (mRsps.notFull() && tagLookup.memory.response.canPut());
      endmethod
      method Action put(CheriMemResponse r);
        MemReqType reqType = (r.masterID == mID) ? TagLookupReq : StdReq;
        debug2("tagcontroller", $display("<time %0t TagController> response from memory: ", $time, fshow(reqType), " ", fshow(r)));
        if (reqType == TagLookupReq) begin
          tagLookup.memory.response.put(r);
          debug2("tagcontroller", $display("<time %0t TagController> tag response", $time));
        end else begin
          mRsps.enq(r);
          debug2("tagcontroller", $display("<time %0t TagController> memory response", $time));
        end
      endmethod
    endinterface
  endinterface

  // module cacheEvents interface
  /////////////////////////////////////////////////////////////////////////////

  `ifdef STATCOUNTERS
  interface Get cacheEvents;
    method ActionValue#(ModuleEvents) get () = tagLookup.cacheEvents.get();
  endinterface
  `elsif PERFORMANCE_MONITORING
  method events = tagLookup.events;
  `endif

endmodule

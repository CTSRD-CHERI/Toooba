/*-
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

import ConfigReg::*;
import VnD::*;
import Vector::*;
import FF::*;
import Bag::*;
import UGFFFullOfUniqueInts::*;
import MemTypesCHERI::*;
import Debug::*;

typedef struct {
  Bool ongoing;
  ReqId id;
  Bank first;
  Bank last;
  Bank next;
} TransRecord deriving (Bits, Eq, FShow);

TransRecord defaultTransRecord = TransRecord{
  ongoing: False,
  id: ?,
  first: 0,
  last: 3,
  next: 1
};

typedef struct {
  ReqId id;
  Line line;
  Bank first;
  Bank last;
  VnD#(ReqId) idBeforeMe;
} ReqRec deriving (Bits, Eq, FShow);

typedef TMul#(CORE_COUNT,2) Masters;

function Bool allEmpty(Vector#(n,FF#(x,y)) v);
  //function isEmpty(x) = x.isEmpty;
  function Bool isEmpty(FF#(x,y) a) = !a.notEmpty;
  return all(isEmpty, v);
endfunction

function Bool anyFull(Vector#(n,FF#(x,y)) v);
  //function isFull(x) = x.isFull;
  function Bool isFull(FF#(x,y) a) = !a.notFull;
  return any(isFull, v);
endfunction

function Bool oooNextId(Vector#(n,FF#(ReqId,y)) vec, ReqId id);
  return vec[id.masterID].first == id;
endfunction

interface CacheCorderer#(numeric type inFlight);
  method Bool   reqsEmpty();
  method Bool   reqsFull;

  method Bool   lookupCheckId(ReqId id);
  method Bool   lookupIsOngoing();
  method Bank   lookupFlit(ReqId id, Bank original);
  method Action lookupReport(ReqId id, Bank flit, Bank first, Bank last);

  method Action slaveReq(ReqId id, Line line, Bank first, Bank last);
  method Bool   slaveReqServeReady(ReqId id, Line line);
  method ActionValue#(Bool) slaveReqExecuteReady(ReqId id, Bank flit);
  method Bool   slaveRspIsOngoing();
  method Bool   slaveRspLast(ReqId id, Bank flit);
  method Action slaveRsp(ReqId id, Bool last);
  
  method Bool   mastReqsEmpty();
  method Bool   mastReqsFull();
  method Bit#(5) mastReqsSpaces();
  method CheriTransactionID mastNextId();
  method Bool mastCheckId(ReqId id);
  method Action mastReq(ReqId id, Bank first, Bank last, Line line, Bool read);
  method Action mastRsp(ReqId id, Bool read, Bool last);
  method Bank nextMastRspFlit(ReqId id, Bool read);
endinterface: CacheCorderer

module mkCacheCorderer#(Integer cacheId)(CacheCorderer#(inFlight));
  Bool oneInFlight = valueOf(inFlight) == 1;
  
  Reg#(TransRecord)                          lookupState <- mkConfigReg(defaultTransRecord);
  
  Bag#(inFlight, ReqId, ReqRec)                slaveReqs <- mkSmallBag;
  Bag#(inFlight, Line, ReqId)                 slaveAddrs <- mkSmallBag;
  Bag#(inFlight, ReqId, ReqId)                 slaveDeps <- mkSmallBag; // Record ordering dependencies.
  FF#(ReqId,2)                           waitingSlaveReq <- mkUGFF;
  Reg#(TransRecord)                       slaveRespState <- mkConfigReg(defaultTransRecord);
  
  // Extra capacity for master reqeusts to accomodate writeback reqeusts that are waiting response.
  Bag#(16, ReqId, ReqRec)                       mastReqs <- mkSmallBag;
  //Bag#(TAdd#(inFlight,TMul#(4,inFlight)), ReqId, ReqRec) mastReqs <- mkSmallBag;
  Bag#(16, ReqId, Line)                        mastLines <- mkSmallBag;
  Reg#(TransRecord)                        mastRespState <- mkConfigReg(defaultTransRecord);
  FF#(CheriTransactionID, 16)                 mastReqIds <- mkUGFFFullOfUniqueInts;

  function Bank currentLookupFlit(VnD#(ReqRec) req, ReqId id, Bank defaultFlit);
    Bank flit = defaultFlit;
    // If we're in the middle of a lookup sequence for this one, keep going.
    if (lookupState.ongoing && id == lookupState.id)
      flit = lookupState.next;
    // If we're in the middle of a response for this one, take the next flit from the response record.
    else if (slaveRespState.ongoing && id == slaveRespState.id)
      flit = slaveRespState.next;
    // Start over if this is the first time doing this request.
    else if (req.v)
      flit = req.d.first;
    return flit;
  endfunction
    
  method Bool reqsEmpty;
    return slaveReqs.empty;
  endmethod
  
  method Bool reqsFull;
    Bool slaveReqsFull = (oneInFlight) ? slaveReqs.nextFull:slaveReqs.full;
    return slaveReqsFull;
  endmethod
  
  method Bool lookupCheckId(ReqId id);
    VnD#(ReqRec) req = slaveReqs.isMember(id);
    return req.v;
  endmethod
  method Bool lookupIsOngoing();
    return lookupState.ongoing;
  endmethod
  method Bank lookupFlit(ReqId id, Bank original);
    VnD#(ReqRec) req = slaveReqs.isMember(id);
    Bank next = currentLookupFlit(req, id, original);
    return next;
  endmethod
  // First and last probably shouldn't be necessary here, but it's possible
  // that the request was inserted in the same cycle from a different rule,
  // so just take it again.
  method Action lookupReport(ReqId id, Bank flit, Bank first, Bank last);
    VnD#(ReqRec) req = slaveReqs.isMember(id);
    TransRecord state = lookupState;
    if (req.v) begin
      state.first = req.d.first;
      state.last = req.d.last;
    end else begin
      // If the request was not found, it's probably inserted this cycle.
      debug2("corderer", $display("<time %0t, cache %0d, CacheCorderer> Lookup for unrecorded ID! ", $time, cacheId, fshow(id)));
      // We don't know these two so use the passed-in values. Next time we'll have the proper report in slaveReqs.
      state.first = first;
      state.last = last;
      // Leave the flit default that they tried, since it probably came from the request.
    end
    state.ongoing = (flit != state.last);
    state.next = (flit+1<=state.last) ? flit + 1:state.first;
    state.id = id;
    debug2("corderer", $display("<time %0t, cache %0d, CacheCorderer> Lookup, id:%x, flit:%x:,  slaveDeps.dataMatch(id):%x ", $time, cacheId, id, flit, slaveDeps.dataMatch(id), fshow(req), fshow(lookupState), fshow(state)));
    lookupState <= state;
  endmethod
  
  method Action slaveReq(ReqId id, Line line, Bank first, Bank last);
    // Check if there are any IDs outstanding on this address.
    VnD#(ReqId) idBeforeMe = slaveAddrs.isMember(line);
    ReqRec recReq = ReqRec{id: id, line: line, first: first, last: last, idBeforeMe: idBeforeMe};
    if (idBeforeMe.v) slaveDeps.update(idBeforeMe.d, id);
    debug2("corderer", $display("<time %0t, cache %0d, CacheCorderer> Slave request: ", $time, cacheId, fshow(recReq)));
    // Then overwrite any id for this address.
    slaveAddrs.insert(line, id);
    slaveReqs.insert(id, recReq);
    slaveDeps.insert(id, unpack(~0));
  endmethod
  method Bool slaveReqServeReady(ReqId id, Line line);
    VnD#(ReqRec) req = slaveReqs.isMember(id);
    // We're blocked if there was a blocking request, and record of that dependency is still in slaveDeps.
    Bool anotherIdBlockingThisKey = slaveDeps.dataMatch(id);
    Bool ready = ((!anotherIdBlockingThisKey || oneInFlight) &&
                  !slaveReqs.empty &&
                  !mastLines.dataMatch(line));
    return ready;
  endmethod
  method Bool slaveRspIsOngoing() = slaveRespState.ongoing;
  method ActionValue#(Bool) slaveReqExecuteReady(ReqId id, Bank flit);
    VnD#(ReqRec) req = slaveReqs.isMember(id);
    TransRecord state = slaveRespState;
    
    // Default for the "ongoing" case.
    Bool ready = (id == state.id && flit == state.next);
    
    // We're blocked if there was a blocking request, and that request is still in the bag.
    Bool anotherIdBlockingThisKey = slaveDeps.dataMatch(id);
    if (!state.ongoing)
      ready = ((!anotherIdBlockingThisKey || oneInFlight)
               && req.v // id found in slaveReqs (should be redundant if in queue) 
               && flit == req.d.first); // this is the first flit of the request.
    debug2("corderer", $display("<time %0t, cache %0d, CacheCorderer> Slave Req Execute Ready %d: id:%x, flit:%x, anotherIdBlockingThisKey:%x ", $time, cacheId,
                                ready, id, flit, anotherIdBlockingThisKey, fshow(req), fshow(slaveRespState)));
    return ready;
  endmethod
  method Bool slaveRspLast(ReqId id, Bank flit);
    VnD#(ReqRec) req = slaveReqs.isMember(id);
    return req.v && req.d.last == flit;
  endmethod
  method Action slaveRsp(ReqId id, Bool last);
    VnD#(ReqRec) req = slaveReqs.isMember(id);
    //if (!req.v) panic($display("<time %0t, cache %0d, CacheCorderer> Panic! Delivering response for unrecorded ID! ", $time, cacheId, fshow(id)));
    TransRecord state = slaveRespState;
    Bank flit = state.next;
    if (!state.ongoing) begin
      state = defaultTransRecord;
      state.id = id;
      state.first = req.d.first;
      state.last = req.d.last;
      flit = state.first;
      state.ongoing = True;
    end
    if (last) begin
      slaveReqs.remove(id);
      slaveDeps.remove(id); // Remove any dependency on me if there is one.
      // If there is a record for this id, it will be for our line.
      // It is possible that someone has overwritten our record.
      if (slaveAddrs.dataMatch(id)) slaveAddrs.remove(req.d.line);
      state.ongoing = False;
    end
    state.next = flit + 1;
    debug2("corderer", $display("<time %0t, cache %0d, CacheCorderer> Slave response: last:%d ", $time, cacheId, last, fshow(req), fshow(slaveRespState), fshow(state)));
    slaveRespState <= state;
  endmethod

  method Bool mastReqsEmpty();
    return mastReqs.empty;
  endmethod
  method Bool mastReqsFull();
    return mastReqs.full || !mastReqIds.notEmpty;
  endmethod
  method Bit#(5) mastReqsSpaces();
    return zeroExtend(16 - mastReqIds.remaining);
  endmethod
  method Bool mastCheckId(ReqId id);
    VnD#(ReqRec) req = mastReqs.isMember(id);
    return req.v;
  endmethod
  method CheriTransactionID mastNextId() = mastReqIds.first();
  // Track metadata for master memory requests, but don't track writes for now.
  method Action mastReq(ReqId id, Bank first, Bank last, Line line, Bool expectResponse);
    //if (expectResponse) begin
      if (mastReqs.full) panic($display("<time %0t, cache %0d, CacheCorderer> Panic! Enquing mastReqs when full. ", $time, cacheId));
      ReqRec recReq = ReqRec{id: id, line: ?, first: first, last: last, idBeforeMe: ?};
      debug2("corderer", $display("<time %0t, cache %0d, CacheCorderer> Master request: ", $time, cacheId, fshow(recReq)));
      mastReqs.insert(id, recReq);
      mastLines.insert(id, line);
    //end
    mastReqIds.deq();
  endmethod
  method Action mastRsp(ReqId id, Bool read, Bool last);
    VnD#(ReqRec) req = mastReqs.isMember(id);
    TransRecord state = mastRespState;
    Bank flit = state.next;
    //if (read) begin
      if (!req.v) panic($display("<time %0t, cache %0d, CacheCorderer> Panic! Memory response for unrecorded ID! ", $time, cacheId, fshow(id)));
      if (!state.ongoing) begin
        state = defaultTransRecord;
        state.id = id;
        state.first = req.d.first;
        state.last = req.d.last;
        flit = req.d.first;
        state.ongoing = True;
      end
      if (last) begin
        mastReqs.remove(id);
        mastLines.remove(id);
        state.ongoing = False;
      end
      state.next = flit + 1;
      mastRespState <= state;
      debug2("corderer", $display("<time %0t, cache %0d, CacheCorderer> Master response: ", $time, cacheId, fshow(req), fshow(mastRespState), fshow(state)));
    //end
    if (last) begin
      mastReqIds.enq(id.transactionID);
      //debug2("trace", $display("mastAvailableIdTable:%b", pack(mastAvailableIdTable[1])));
    end
  endmethod
  method Bank nextMastRspFlit(ReqId id, Bool read);
    VnD#(ReqRec) req = mastReqs.isMember(id);
    TransRecord state = mastRespState;
    Bank flit = state.next;
    if (read && !state.ongoing) flit = req.d.first;
    return flit;
  endmethod
endmodule

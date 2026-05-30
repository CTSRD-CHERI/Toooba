/*-
 * Copyright (c) 2014-2018 Jonathan Woodruff
 * Copyright (c) 2015 Alexandre Joannou
 * Copyright (c) 2016 Alan Mujumdar
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249
 * ("MRC2"), as part of the DARPA MRC research programme.
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
 
import Debug::*;
import MemTypesCHERI::*;
import DefaultValue::*;
import Assert::*;
import List::*;
import FIFO::*;
import FF::*;
import SpecialFIFOs::*;
import FIFOF::*;
import GetPut::*;
import MasterSlaveCHERI::*;
import RoutableCHERI::*;
import Vector::*;
import ConfigReg::*;
import SDPMem::*;
import Bag::*;
import VnD::*;
import CacheCorderer::*;
`ifdef STATCOUNTERS
`define MONITOR_EVENTS
  import GetPut::*;
  import StatCounters::*;
`elsif PERFORMANCE_MONITORING
`define MONITOR_EVENTS
  import PerformanceMonitor::*;
`endif

`ifdef CapWidth
  `define USECAP 1
`else
// XXX: Old compatibility definitions; migrate to CapWidth and delete
`ifdef CAP
  `define USECAP 1
`elsif CAP128
  `define USECAP 1
`elsif CAP64
  `define USECAP 1
`endif
`endif
 
interface CacheCore#(numeric type ways,
                     numeric type keyBits,
                     numeric type inFlight);
  method Bool canPut();
  method Action put(CheriMemRequest req);
  method CheckedGet#(CheriMemResponse) response();
  method Action nextWillCommit(Bool nextCommitting);
  method Action invalidate(CheriPhyAddr addr);
  method ActionValue#(Bool) invalidateDone();
  //interface Master#(CheriMemRequest, CheriMemResponse) memory;
  `ifdef STATCOUNTERS
  interface Get#(ModuleEvents) cacheEvents;
  `elsif PERFORMANCE_MONITORING
  method EventsCacheCore events;
  `endif
endinterface: CacheCore

typedef Bit#(tagBits) Tag#(numeric type tagBits);
typedef Bit#(keyBits) Key#(numeric type keyBits);
typedef CheriPhyByteOffset Offset;
typedef struct {
  Tag#(tagBits)    tag;
  Key#(keyBits)    key;
  Bank         bank;
  Offset        offset;
} CacheAddress#(numeric type keyBits, numeric type tagBits) deriving (Bits, Eq, Bounded, FShow);
typedef Bit#(TLog#(ways)) Way#(numeric type ways);

typedef struct {
  Key#(keyBits) key;
  Bank      bank;
} DataKey#(numeric type ways, numeric type keyBits) deriving (Bits, Eq, Bounded, FShow);

typedef struct {
  CheriTransactionID id;
  Bool           commit;
} CacheCommit deriving (Bits, Eq, Bounded, FShow);

`ifdef USECAP
  typedef Vector#(Banks, CapTags) LineCapTags;
`endif

typedef struct {
  Tag#(tagBits)                     tag;
  Bool                            dirty;
  Vector#(CheriBurstSize, Bool)   valid;
  Bool                          pendMem;
  `ifdef USECAP
    LineCapTags                 capTags;
  `endif
} TagLine#(numeric type tagBits) deriving (Bits, Eq, Bounded, FShow);

// Invalid tag constant to use for invalidating tags.
TagLine#(tagBits) invTag = TagLine{
  tag: 0,
  valid: replicate(False),
  pendMem: False,
  dirty: False
  `ifdef USECAP
    , capTags: replicate(replicate(False))
  `endif
};

typedef enum {Init, Serving} CacheState deriving (Bits, Eq, FShow);
typedef enum {Serve, Writeback, MemResponse} LookupCommand deriving (Bits, Eq, FShow);

typedef enum {WriteThrough, WriteAllocate}   WriteMissBehaviour deriving (Bits, Eq, FShow);
typedef enum {OnlyReadResponses, RespondAll} ResponseBehaviour deriving (Bits, Eq, FShow);
typedef enum {InOrder, OutOfOrder} OrderBehaviour deriving (Bits, Eq, FShow);

typedef struct {
  CacheAddress#(keyBits, tagBits) addr;
  TagLine#(tagBits)                tag;
  Way#(ways)                       way;
  Bool                          cached;
  ReqId                          reqId;
} AddrTagWay#(numeric type ways, numeric type keyBits, numeric type tagBits) deriving (Bits, FShow);

typedef struct {
  Tag#(tagBits)                    tag;
  Key#(keyBits)                    key;
  Way#(ways)                       way;
  Bool                           valid;
} InvalidateToken#(numeric type ways, numeric type keyBits, numeric type tagBits) deriving (Bits, FShow);

typedef struct {
  LookupCommand                               command;
  CheriMemRequest                                 req; // Original request that triggered the lookup.
  CacheAddress#(keyBits, tagBits)                addr; // Byte address of the frame that was fetched.
  BytesPerFlit                              readWidth; // Latch read width for speed, in case it is a read.
  DataKey#(ways, keyBits)                     dataKey; // Datakey used in the fetch (which duplicates some of addr and adds the way).
  Way#(ways)                                      way;
  Bool                                           last;
  Bool                                          fresh;
  InvalidateToken#(ways, keyBits, tagBits) invalidate; // Token containing any invalidate request
  TagLine#(tagBits)                      writebackTag; // Tags recorded for a line that is being written back.
  Error                                      rspError;
} ControlToken#(numeric type ways, numeric type keyBits, numeric type tagBits) deriving (Bits, FShow);

typedef struct {
  CheriMemResponse     resp;
  CheriMemRequest       req; // Request to potentially enq into retryReqs.
  ReqId               rspId;
  Bool       reportResponse;
  ReqId               deqId;
  Bool        deqReqCommits;
  Bool          enqRetryReq;
} ResponseToken deriving (Bits, FShow);

typedef struct {
  Key#(keyBits)         key;
  ReqId                inId; // request id of original request
  Bool               inDone;
  ReqId               outId;
  Bool               cached;
  TagLine#(tagBits)  oldTag;
  Way#(ways)         oldWay;
  Bool             oldDirty;
  Bool                write;
} RequestRecord#(numeric type ways, numeric type keyBits, numeric type tagBits) deriving (Bits, Eq, FShow);

typedef struct {
  ReqId inId;
  Bool isSC;
  Bool scResult;
} ReqIdWithSC deriving (Bits, Eq, FShow);

typedef struct {
  Bool             doWrite;
  Key#(keyBits)        key;
  TagLine#(tagBits) newTag;
  Way#(ways)           way;
} TagUpdate#(numeric type ways, numeric type keyBits, numeric type tagBits) deriving (Bits, Eq, FShow);

typedef Vector#(TDiv#(CheriDataWidth,8), Bool) ByteEnable;

`ifdef MONITOR_EVENTS
  typedef struct {
    Bool evt_WRITE;
    Bool evt_WRITE_MISS;
    Bool evt_READ;
    Bool evt_READ_MISS;
    Bool evt_EVICT;
  `ifdef USECAP
      Bool evt_SET_TAG_WRITE;
      Bool evt_SET_TAG_READ;
  `endif
  } EventsCacheCore deriving (Bits, FShow);
`endif

`ifdef PERFORMANCE_MONITORING
  instance BitVectorable#(EventsCacheCore, 1, m) provisos (Bits#(EventsCacheCore, m));
    function to_vector = struct_to_vector;
  endinstance
`endif
/*
 * The CacheCore module is a generic cache engine that is parameterisable
 * by number of sets, number of ways, number of outstanding request,
 * and selectable write-allocate or write-through behaviours.
 * In addition, if the cache core is used as a level1 cache (ICache or DCache)
 * it will return the 64-bit word requested in the bottom of the data field.
 */

module mkCacheCore#(Integer cacheId,
                    WriteMissBehaviour writeBehaviour,
                    ResponseBehaviour responseBehaviour,
                    WhichCache whichCache,
                    // Must be > 5 or we can't issue reads with evictions!
                    // This means that a write-allocate cache must have >=5 capacity in the output fifo.
                    Bit#(10) memReqFifoSpace,
                    FIFOF#(CheriMemRequest) memReqs,
                    FIFOF#(CheriMemResponse) memRsps)
                   (CacheCore#(ways, keyBits, inFlight))
  provisos (
      Bits#(CheriPhyAddr, paddr_size),
      Log#(TDiv#(TMul#(CheriBusBytes, 8), 2), offset_size), // The line size is different for each bus width. XXX: Don't hardcode?
      Add#(TAdd#(offset_size, keyBits), tagBits, paddr_size),
      Add#(smaller1, TLog#(ways), keyBits),
      Add#(smaller2, TLog#(ways), tagBits),
      Add#(smaller3, tagBits, 30),
      Add#(0, TLog#(TMin#(TExp#(keyBits), 16)), wayPredIndexSize),
      Add#(smaller4, wayPredIndexSize, keyBits),
      Add#(smaller5, 4, keyBits),
      Add#(b__, 1, ways),
      Bits#(CacheAddress#(keyBits, tagBits), 40),
      Add#(a__, TLog#(inFlight), keyBits)
    );
  Bool oneInFlight = valueOf(inFlight) == 1;
  
  Wire#(VnD#(CheriMemRequest))                                   newReq <- mkDWire(VnD{v: False, d:?});
  Bag#(inFlight, ReqId, CheriMemRequest)                      retryReqs <- mkSmallBag;

  Reg#(Bool)                                                  nextEmpty <- mkConfigRegU;
  ResponseToken defaultResponseToken = ResponseToken{
    resp: ?,
    req: defaultValue,
    rspId: ?,
    enqRetryReq: False,
    reportResponse: False,
    deqId: ?,
    deqReqCommits: False
  };
  Wire#(ResponseToken)                                            resps <- mkDWire(defaultResponseToken);
  Wire#(Bool)                                                respsReady <- mkDWire(False);
  Wire#(Bool)                                                   gotResp <- mkDWire(False);
  Wire#(Bool)                                                missedResp <- mkDWire(False);
  Wire#(Bool)                                                    putReq <- mkDWire(False);
  FF#(ReqIdWithSC,TMul#(inFlight,2))                         writeResps <- mkUGFFDebug("CacheCoreRealAssociative_writeResps");
  ControlToken#(ways, keyBits, tagBits) null_ct = ?;
  null_ct.command = MemResponse;
  null_ct.req.operation = tagged CacheOp CacheOperation{inst: CacheNop, cache: whichCache, indexed: True};
  null_ct.req.masterID = -1; // Not matching any real master.
  null_ct.fresh = False;
  null_ct.invalidate.valid = False;
  null_ct.writebackTag = invTag;
  ControlToken#(ways, keyBits, tagBits) initCt = null_ct;
  initCt.req = defaultValue;
  initCt.last = True;
  Reg#(ControlToken#(ways, keyBits, tagBits))                       cts <- mkConfigReg(initCt);
  Reg#(CacheState)                                           cacheState <- mkConfigReg(Init);
  Vector#(ways,MEM2#(Key#(keyBits),TagLine#(tagBits)))             tags <- replicateM(mkMEMNoFlow2());
  Vector#(ways,MEM#(DataKey#(ways, keyBits), DataMinusCapTags#(CheriDataWidth))) data <- replicateM(mkMEMNoFlow());
  Reg#(Way#(ways))                                              nextWay <- mkConfigReg(0);
  Reg#(Key#(keyBits))                                         initCount <- mkReg(0);
  FF#(Bool, 16)                                             req_commits <- mkUGFFBypass; // Plenty big!
  
  FIFOF#(AddrTagWay#(ways, keyBits, tagBits))                writebacks <- mkUGFIFOF1;
  Reg#(Bank)                                     writebackWriteBank <- mkConfigReg(0);
  // Only used if "supportDirtyBytes" is set, currently in the DCache when it is in Writeback mode.
  `ifdef WRITEBACK_DCACHE
    Vector#(ways,MEM#(DataKey#(ways, keyBits), ByteEnable))    dirtyBytes <- replicateM(mkMEMNoFlow());
  `endif
  // These will only be used if "supportInvalidates" is set, as selected below.
  FIFOF#(AddrTagWay#(ways, keyBits, tagBits))      invalidateWritebacks <- mkUGFIFOF1;
  Reg#(Bank)                               invalidateWritebackWriteBank <- mkConfigReg(0);
  FF#(CheriPhyAddr,4)                                       invalidates <- mkUGFFDebug("CacheCore_invalidates");
  FF#(InvalidateToken#(ways, keyBits, tagBits),8)    delayedInvalidates <- mkUGFFDebug("CacheCore_delayedInvalidates");
  FF#(Bool,32)                                          invalidatesDone <- mkUGFFDebug("CacheCore_invalidatesDone");
  FF#(void,2)                                          writethroughNext <- mkUGFFDebug("CacheCore_writethroughNext");
  
  CacheCorderer#(inFlight)                                      orderer <- mkCacheCorderer(cacheId);
  
  Bag#(inFlight, ReqId, RequestRecord#(ways, keyBits, tagBits))readReqs <- mkSmallBag; // Hold data for outstanding memory requests
  VnD#(RequestRecord#(ways, keyBits, tagBits)) readReqRegDefault = VnD{v:False, d:?};
  readReqRegDefault.d.outId = unpack(-1);
  Reg#(VnD#(RequestRecord#(ways, keyBits, tagBits)))         readReqReg <- mkConfigReg(readReqRegDefault); // Hold data for outstanding memory request
  `ifdef MONITOR_EVENTS
    Wire#(EventsCacheCore) eventsWire <- mkDWire(unpack(0));
    `ifdef USECAP
      Reg#(ReqId) lastRespId <- mkReg(unpack(~0));
    `endif
  `endif
  
  Bool writeThrough = writeBehaviour==WriteThrough;
  Bool supportInvalidates = (writeBehaviour==WriteAllocate && whichCache==DCache);
  `ifdef MULTI
  `ifndef TIMEBASED
    supportInvalidates = True;
  `endif
  `endif
  Bool supportDirtyBytes = (writeBehaviour==WriteAllocate && whichCache==DCache);
  
  `ifdef MULTI
    Bool performWritethrough = (writeThrough || writethroughNext.notEmpty);
  `else
    Bool performWritethrough = writeThrough;
  `endif
  
  Bool roomForOneRequest = memReqFifoSpace >= 1 && !orderer.mastReqsFull;
  // If the cache is writethrough, we never need to writeback.
  Bool roomForWriteback        = (writeThrough) ? True:(memReqFifoSpace >= 4 && orderer.mastReqsSpaces >= 4);
  Bool roomForReadAndWriteback = (writeThrough) ? roomForOneRequest:(memReqFifoSpace >= 5 && orderer.mastReqsSpaces >= 5);
  
  CheriMemResponse memResp = memRsps.first;
  ReqId memRspId = getRespId(memResp);
  Bool memRspIsWrite = False;
  if (memResp.operation matches tagged Write) memRspIsWrite = True;
  Bool readRegMatchesMemResp = readReqReg.d.outId==getRespId(memResp) && // If the IDs match
                               (readReqReg.v || (!oneInFlight)); // If the readReqReg is valid (but only check this if there is oneInFlight as the ids matching is sufficient otherwise).
  Bool memRspHasResponseRecord = memRsps.notEmpty && ((oneInFlight) ? readRegMatchesMemResp:readReqs.isMember(memRspId).v);
  Bool responseRecordValid = memRsps.notEmpty && readRegMatchesMemResp; 
                             
    
  rule initialize(cacheState == Init);
    debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Initializing tag %0d", $time, cacheId, initCount));
    for (Integer i=0; i<valueOf(ways); i=i+1) tags[i].write(pack(initCount), invTag);
    if (initCount == 0-1) begin
      cacheState <= Serving;
      initCount <= 0;
    end else begin
      initCount <= initCount + 1;
    end
  endrule
  
  rule writeNextEmpty;
    nextEmpty <= orderer.reqsEmpty;
  endrule

  function ActionValue#(VnD#(Way#(ways))) findWay(Vector#(ways,TagLine#(tagBits)) tagVec,Tag#(tagBits) tag, Bank bank
    `ifdef USECAP
      , Bool tagOnlyRead
    `endif
    );
    actionvalue
    `ifdef USECAP
      function Bool validBank(TagLine#(tagBits) t) = tagOnlyRead? (tag==t.tag && pack(t.valid)==-1) : (tag==t.tag && t.valid[bank]);
    `else
      function Bool validBank(TagLine#(tagBits) t) = (tag==t.tag && t.valid[bank]);
    `endif
    return returnIndex(validBank, tagVec);
    endactionvalue
  endfunction
  
  function ActionValue#(VnD#(Way#(ways))) needsInvalidate(Vector#(ways,TagLine#(tagBits)) tagVec,Tag#(tagBits) tag);
    actionvalue
    function Bool validBank(TagLine#(tagBits) t) = (tag==t.tag && (pack(t.valid)!=0||t.pendMem));
    return returnIndex(validBank, tagVec);
    endactionvalue
  endfunction
  
  function ActionValue#(VnD#(Way#(ways))) findPendingWay(Vector#(ways,TagLine#(tagBits)) tagVec);
    actionvalue
    function Bool pending(TagLine#(tagBits) t) = t.pendMem;
    //VnD#(Way#(ways)) way = 
    /*for (Integer i = 0; i < valueOf(ways); i = i + 1) begin
      if (tagVec[i].pendMem) way = VnD(fromInteger(i));
    end */
    VnD#(Way#(ways)) ret = returnIndex(pending, tagVec);
    //$display("returned: ", fshow(ret), fshow(tagVec));
    return ret;
    endactionvalue
  endfunction
  
  (* no_implicit_conditions *)
  rule startLookup(cacheState != Init);
    // ===========================================================================================
    // Second half of rule that begins new lookup 
    // ===========================================================================================
    Bool valid = False;
    ControlToken#(ways, keyBits, tagBits) newCt = null_ct;
    newCt.req = newReq.d;
    newCt.addr = unpack(pack(newCt.req.addr));
    newCt.rspError = NoError;
    Bool last = True;
    
    Bool multiFlitReq = False;
        
    // If we have a valid new request, always run it immediatly.
    if (newReq.v) begin
      newCt.fresh = True;
      debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Selecting a fresh request ", $time, cacheId, fshow(newReq)));
      valid = True;
      Flit size = 0;
      if (newCt.req.operation matches tagged Read .rop) size = rop.noOfFlits;
      orderer.lookupReport(getReqId(newCt.req), newCt.addr.bank, newCt.addr.bank, newCt.addr.bank + truncate(size));
    end else begin
      // All the "non-fresh" cases which are less timing critical.
      CheriMemRequest lookupReq = defaultValue;
      newCt = cts;
      lookupReq = cts.req;
      if (orderer.lookupIsOngoing()) begin
        // Continue lookup in register if the previous one was not the last.
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Selecting a continuing request ", $time, cacheId, fshow(lookupReq)));
        valid = True;
      end else if (oneInFlight && (!nextEmpty||cts.fresh)) begin
        // Continue lookup in register if we are a "oneInFlight" cache and therefore don't need retryReqs.
        newCt.fresh = False;
        valid = True;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Selecting to Recycle request in cts ", $time, cacheId, fshow(lookupReq), fshow(cts)));
      end else if (!oneInFlight && retryReqs.nextData().v) begin
        newCt.fresh = False;
        lookupReq = retryReqs.nextData().d;
        valid = True;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Selecting a recycled request ", $time, cacheId, fshow(lookupReq)));
        retryReqs.iterateNext();
      end else newCt.fresh = False;
      
      // Reset the lookup flit counter if this request is for another ID.
      newCt.addr = unpack(pack(lookupReq.addr));
      newCt.req = lookupReq;
      ReqId reqId = getReqId(lookupReq);
      
      if (valid) begin
        newCt.addr.bank = orderer.lookupFlit(reqId, newCt.addr.bank);
        CacheAddress#(keyBits, tagBits) ca = newCt.addr;
        Flit size = 0;
        if (newCt.req.operation matches tagged Read .rop) size = rop.noOfFlits;
        orderer.lookupReport(getReqId(newCt.req), ca.bank, ca.bank, ca.bank + truncate(size));
      end
      
      if ((memRsps.notEmpty && !orderer.slaveRspIsOngoing()) || !orderer.slaveReqServeReady(reqId,truncateLSB(lookupReq.addr.lineNumber))) begin
        valid = False;
        //newCt = cts;
        newCt.fresh = False;
        //lookupReq = cts.req;
        newCt.command = MemResponse;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Trying a memory response by default ", $time, cacheId));
      end
    end
    
    newCt.way = nextWay;
    
    // Only issue a writeback there are no outstanding requests, just to be safe.
    // We must not overwrite a fresh request, but we block at the put method when writebacks.notEmpty
    // to prevent it, improving timing.
    if (writebacks.notEmpty /* && !newCt.fresh*/) begin // Take a writeback request with the highest priority.
      // Make sure it is obvious to an optimiser that a writethrough cache will not ever do this.
      if (!writeThrough) begin
        newCt.command = Writeback;
        AddrTagWay#(ways, keyBits, tagBits) evict = writebacks.first;
        newCt.way = evict.way;
        evict.addr.bank = writebackWriteBank;
        newCt.addr = unpack(pack(evict.addr));
        newCt.writebackTag = evict.tag;
        newCt.fresh = False;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Started Eviction, evict write bank: %x ", $time, cacheId, writebackWriteBank, fshow(evict)));
        last = (writebackWriteBank == 3); // Signal the last eviction frame to the lookup stage.
        Bank nextFetch = writebackWriteBank + 1;
        if (writebackWriteBank == 3) begin
          writebacks.deq();
          writebackWriteBank <= 0;
        end else writebackWriteBank <= nextFetch;
      end else writebacks.deq();
    // Similiar to above, when the invalidateWriteback fifo is not empty, fresh requests are blocked at the put interface.
    end else if (supportInvalidates && invalidateWritebacks.notEmpty /*&& !newCt.fresh*/) begin
      // Make sure it is obvious to an optimiser that a writethrough cache will not ever do this.
      if (!writeThrough) begin
        newCt.command = Writeback;
        AddrTagWay#(ways, keyBits, tagBits) evict = invalidateWritebacks.first;
        newCt.way = evict.way;
        evict.addr.bank = invalidateWritebackWriteBank;
        newCt.addr = unpack(pack(evict.addr));
        newCt.writebackTag = evict.tag;
        newCt.fresh = False;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Started Invalidate Eviction, evict write bank: %x ", $time, cacheId, writebackWriteBank, fshow(evict)));
        last = (invalidateWritebackWriteBank == 3); // Signal the last eviction frame to the lookup stage.
        Bank nextFetch = invalidateWritebackWriteBank + 1;
        if (invalidateWritebackWriteBank == 3) begin
          invalidateWritebacks.deq();
          invalidateWritebackWriteBank <= 0;
        end else invalidateWritebackWriteBank <= nextFetch;
      end else invalidateWritebacks.deq();
    end else if (valid) begin
      newCt.command = Serve;
      if (newCt.req.operation matches tagged CacheOp .cop) begin
        if (cop.indexed) newCt.way = truncate(newCt.addr.tag);
        if (cop.inst == CacheNop) begin // Special state identical to MemResponse except that it gives a null response to the pipeline.
          newCt.command = MemResponse;
          //debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Trying a memory response ", $time, cacheId));
        end
      end
      debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Started memory request, last:%x started lookup, way:%x nextWay:%x ", 
                                    $time,     cacheId,                                      last, newCt.way, nextWay, fshow(newCt.addr), fshow(newCt.req)));
    end
    // Always start the fetch so that memory responses can be consumed!
    newCt.dataKey = DataKey{key:newCt.addr.key, bank: newCt.addr.bank};
    newCt.last = last;
    
    // Only service an invalidate if there are no pending writebacks.
    // Service any invalidate if there is one...
    if (supportInvalidates) begin
      if (delayedInvalidates.notEmpty) begin
        newCt.invalidate = delayedInvalidates.first;
        delayedInvalidates.deq;
        CacheAddress#(keyBits, tagBits) invAddr = unpack(0);
        invAddr.key = newCt.invalidate.key;
        invAddr.tag = newCt.invalidate.tag;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Dequed delayed invalidate, addr: %x", $time, cacheId, invAddr));
        for (Integer i=0; i<valueOf(ways); i=i+1) tags[i].readB.put(newCt.invalidate.key);
      end else if (invalidates.notEmpty) begin
        CacheAddress#(keyBits, tagBits) invAddr = unpack(pack(invalidates.first));
        invalidates.deq;
        newCt.invalidate.tag = invAddr.tag;
        newCt.invalidate.key = invAddr.key;
        newCt.invalidate.valid = True;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Dequed an invalidate, addr: %x", $time, cacheId, invAddr));
        for (Integer i=0; i<valueOf(ways); i=i+1) tags[i].readB.put(invAddr.key);
      end else newCt.invalidate.valid = False;
    end
    
    // Start tag lookup
    for (Integer i=0; i<valueOf(ways); i=i+1) tags[i].read.put(newCt.dataKey.key);
    // Start data lookup
    for (Integer i=0; i<valueOf(ways); i=i+1) data[i].read.put(newCt.dataKey);
    `ifdef WRITEBACK_DCACHE
      if (supportDirtyBytes) begin
        for (Integer i=0; i<valueOf(ways); i=i+1) dirtyBytes[i].read.put(newCt.dataKey);
      end
    `endif
    cts <= newCt;
  endrule
  
  Bool noReqs = orderer.reqsEmpty;
  
  (* no_implicit_conditions *)
  rule finishLookup(cacheState != Init);
    // ===========================================================================================
    // First half of rule that looks at the present lookup and potentially writes 
    // ===========================================================================================
    VnD#(Bool) commit = VnD{v:req_commits.notEmpty, d:req_commits.first()};
    
    // If we are in the serving state and our unguarded fifos are not full.
    ControlToken#(ways, keyBits, tagBits)     ct  =  cts;
    CacheAddress#(keyBits, tagBits)         addr  =  ct.addr;
    Vector#(ways,TagLine#(tagBits))     tagsRead = ?;
    for (Integer i=0; i<valueOf(ways); i=i+1) tagsRead[i] <- tags[i].read.get();

    `ifdef USECAP
      Bool tagOnlyRead = False; // True should be rare.
      tagOnlyRead = {case (ct.req.operation) matches
                        tagged Read .rop:  return rop.tagOnlyRead;
                        default: return False;
                      endcase};
      tagOnlyRead = tagOnlyRead && (whichCache!=TCache);
    `endif

    VnD#(Way#(ways)) mWay <- findWay(tagsRead,addr.tag,addr.bank
    `ifdef USECAP
      ,tagOnlyRead
    `endif
    );
    Bool miss = !mWay.v;
    Way#(ways) way = mWay.d;
    if (writeBehaviour==WriteAllocate && miss) way = ct.way;
    //if (ct.command!=Writeback) way <- findWay(tagsRead,addr.tag,addr.bank);
        
    // Independantly of the tag match, get the data from all the ways and shift it down.
    // This moves the shift from later to now where it can be in parallel with the match and select.
    function ActionValue#(DataMinusCapTags#(CheriDataWidth)) getData(MEM#(DataKey#(ways, keyBits), DataMinusCapTags#(CheriDataWidth)) bram) = bram.read.get();
    Vector#(ways, DataMinusCapTags#(CheriDataWidth)) datasRead <- mapM(getData,data);
    Offset dataShift = 0;
    `ifdef USECAP
      Bit#(TLog#(CapsPerFlit)) capShift = 0;
    `endif
    if (whichCache==DCache || whichCache==ICache) begin
      dataShift = {truncateLSB(addr.offset),3'b0};
      `ifdef USECAP
        capShift = truncateLSB(dataShift);
      `endif
    end
    function DataMinusCapTags#(CheriDataWidth) shiftDataMinusTags(DataMinusCapTags#(CheriDataWidth) data) = 
              DataMinusCapTags{
                data: (data.data)>>{dataShift,3'b0}
              };
    function Data#(CheriDataWidth) shiftData(Data#(CheriDataWidth) data) = 
              Data{
                data: (data.data)>>{dataShift,3'b0}
                `ifdef USECAP
                  , cap: unpack(pack(data.cap)>>capShift)
                `endif
              };
    // Put the 64-bit word of interest in the bottom.
    Vector#(ways, DataMinusCapTags#(CheriDataWidth)) shiftedDatasRead = map(shiftDataMinusTags,datasRead);
    DataMinusCapTags#(CheriDataWidth) shiftedDataRead = shiftedDatasRead[way];
    
    // Select the data that matched the way.
    DataMinusCapTags#(CheriDataWidth) dataRead = datasRead[way];
    ByteEnable dirties = unpack(-1);
    `ifdef WRITEBACK_DCACHE
      if (supportDirtyBytes) begin
        dirties <- dirtyBytes[way].read.get();
      end
    `endif
    // After data is selected with the matched way, handle the other "way" cases that don't need matching data.
    // This fast-tracks data selection, but lets things like invalidates, which need another source for way, still work.
    if (cts.req.operation matches tagged CacheOp .cop &&& cop.indexed) way = cts.way;
    else if (ct.command==Serve && miss) way = cts.way;
    
    TagLine#(tagBits) tag = tagsRead[way];
    TagUpdate#(ways, keyBits, tagBits) tagUpdate = TagUpdate{
      doWrite: False,
      key: addr.key,
      newTag: tag,
      way: way
    };
    
    Bool firstFresh = cts.fresh && pack(cts.req.addr)==pack(cts.addr); // This is the first of a set of fresh requests.
    Bool cached = True; // Just a default value.
    Bool scResult = False;
    
    Bool invalidateDone = False;
    Bool failedInvalidate = False;
    VnD#(Way#(ways)) invPendWay = VnD{v: False, d: 0/*?*/};
    TagLine#(tagBits) shadowTag = invTag/*?*/;
    if (supportInvalidates && ct.invalidate.valid) begin
      // Do tag match for invalidates ("shadow" tags, i.e. 2nd read port of tags).
      Vector#(ways,TagLine#(tagBits)) shadowTags = ?;
      for (Integer i=0; i<valueOf(ways); i=i+1) shadowTags[i] <- tags[i].readB.get();
      VnD#(Way#(ways)) invWay <- needsInvalidate(shadowTags,ct.invalidate.tag);
      shadowTag = shadowTags[invWay.d];
      invPendWay.d = invWay.d;
      ct.invalidate.way = invWay.d;
      VnD#(Way#(ways)) invPending = VnD{v: shadowTag.pendMem, d:invWay.d};
      debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Invalidate lookup. ", $time, cacheId, fshow(ct.invalidate), fshow(shadowTags)));
      if (invWay.v) begin
        invalidateDone = False;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Invalidate hit. key: %x, invWay.d: %x, shadowTag.pendMem: %x, isValid(pending)", 
                                      $time, cacheId, ct.invalidate.key, invWay.d, shadowTag.pendMem, invPending.v));
        if (invPending.v) begin
          invPendWay.v = True;
          if (readReqReg.d.write && writethroughNext.notFull) writethroughNext.enq(?);
          //if (!oneInFlight) panic($display("Panic!  Pending invalidation not supported yet with more than one in flight in CacheCore."));
        end
      end else invalidateDone = True; // Invalidate is done if it is not a hit!
    end
    
    CheriMemRequest req = ct.req;
    Bool dead = False;  // To allow us to kill this operation at any stage.

    Bool cachedResponse = False;
    Bool cachedWrite = False;
    Bool returnTag = False;
    Bool doInvalidate = False;
    Bool writeTags = False;
    Bool writeTagsEvenIfDead = False;
    Bool expectResponse = False;
    Bool evict = False;
    /*Bool isPftch = {case (req.operation) matches
                    tagged CacheOp .cop &&& (cop.inst == CachePrefetch && cop.cache == whichCache): return True;
                    default: return False;
                   endcase};*/
    Bool reportResponse = False;
    ReqId deqId = getReqId(req);
    Bool deqReqCommits = False;
    Bool linked = {case (req.operation) matches
                      tagged Read .rop:  return rop.linked;
                      default: return False;
                    endcase};
    Bool conditional = {case (req.operation) matches
                      tagged Write .wop: return wop.conditional;    
                      default: return False;
                    endcase};
    cached = {case (req.operation) matches
                      tagged Read .rop:  return !rop.uncached;
                      tagged Write .wop: return !wop.uncached;
                      //tagged CacheOp .cop &&& (cop.inst == CachePrefetch && cop.cache == whichCache): True;
                      default: return False;
                    endcase};
    `ifdef USECAP
      // If this is a tagOnlyRead, check our own cache first. Turn it into
      // uncached after it is a miss.
      if (tagOnlyRead) cached = True;
    `endif
    //Bool prefetchMissLocal = (isPftch && miss);

    // If this is not the last-level cache, then a lower level will handle ordering
    // of load-linked and store conditional.
    Bool handleLinked = whichCache==L2;
    
    // If this cache doesn't handle load linked, then force a miss.
    Bool passConditional = (!handleLinked && (linked||conditional));

    CacheAddress#(keyBits, tagBits) reqAddr = unpack(pack(cts.req.addr)); // Address of original request.
    ReqId reqId = getReqId(req);
    ReqId rspId = reqId; // Only valid for the in-order case.

    Bool isWrite = False;
    if (req.operation matches tagged Write .wop) isWrite = True;
    //if (prefetchMissLocal) isWrite = True;
    Bool isRead = False;
    if (req.operation matches tagged Read .rop) isRead = True;
    
    Bool serveThisReq = (orderer.slaveReqServeReady(reqId, truncateLSB(cts.req.addr.lineNumber))
                        && !tag.pendMem && commit.v); // If this is the next flit expected
    Bool exeThisReq = False;
    // If this is the last flit of transaction
    Bool thisReqLast = orderer.slaveRspLast(reqId, addr.bank);
    
    // Setup any memory responses ====
    Data#(CheriDataWidth) shiftedMemRespData = shiftData(memResp.data);
    
    Bool respValid = False;
    CheriMemResponse cacheResp = defaultValue;
    cacheResp.masterID = req.masterID;
    cacheResp.transactionID = req.transactionID;
    cacheResp.error = ct.rspError;
    // Pull assignment of cacheResp.data out of all other conditionals for speed.
    cacheResp.data.data = shiftedDataRead.data;
    `ifdef USECAP
      cacheResp.data.cap = unpack((pack(tag.capTags[addr.bank]) >> capShift));
      if (tagOnlyRead) begin
        cacheResp.data.data = zeroExtend(pack(tag.capTags));
        cacheResp.operation = tagged Read{last: True, tagOnlyRead: True};
      end
    `endif
    if (ct.command == MemResponse) begin
      cacheResp.data = shiftedMemRespData;
      cacheResp.operation = memResp.operation;
    end
    
    // These hold and control enqing the request to the retry fifo.
    CheriMemRequest memReq = req; // Request to forward to memory.
    Bool enqRetryReq = False;
    
    if (!noReqs) debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Commit:%x, Serving request ", $time, cacheId, commit, fshow(ct), fshow(dataRead), fshow(tagsRead)));

    `ifdef MONITOR_EVENTS
      EventsCacheCore events = unpack(0);
    `endif
    
    VnD#(RequestRecord#(ways, keyBits, tagBits)) newReadReqReg = readReqReg;
    
    case (ct.command) matches
      Writeback: begin
        if (memRsps.notEmpty && !memRspHasResponseRecord) begin
          if (memRspIsWrite) begin
            memRsps.deq;
            if (!oneInFlight) begin
              newReadReqReg.v = False;
              newReadReqReg.d.outId = getRespId(memResp);
            end
            orderer.mastRsp(getRespId(memResp), False, getLastField(memResp));
            debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> received write memory response in Writeback case ", $time, cacheId, fshow(memResp)));
          end
        end
        Bool lineDirty = True;
        if (supportDirtyBytes) begin
          lineDirty = pack(dirties) != 0;
          //debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Checking dirties for writeback, bank %x, way %d, %x, lineDirty: %d", $time, cacheId, ct.dataKey, way, dirties, lineDirty));
        end
        // Make it obvious to the optimiser that this logic isn't required for a writethrough cache.
        if (!writeThrough && lineDirty) begin
          req.operation = tagged Write {
                      uncached: False,//True,
                      conditional: False,
                      byteEnable: dirties,
                      bitEnable: -1,
                      data: Data{ data: dataRead.data
                      `ifdef USECAP
                        , cap: ct.writebackTag.capTags[addr.bank]
                      `endif
                      },
                      last: True,
                      length: 0
                  };
          req.addr = unpack(pack(ct.addr));
          req.masterID = fromInteger(cacheId);
          req.transactionID = orderer.mastNextId;
          debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Issuing external writeback memory request memReqs.notFull:%x, memReqFifoSpace:%x addr:%x ", 
                                         $time, cacheId, memReqs.notFull, memReqFifoSpace, req.addr, fshow(getReqId(req))));
          if (orderer.mastCheckId(getReqId(req))) panic($display("Panic!  Issuing duplicate request IDs!"));
          memReqs.enq(req);
          orderer.mastReq(getReqId(req), ct.addr.bank, ct.addr.bank, truncateLSB(req.addr.lineNumber), False);

          `ifdef WRITEBACK_DCACHE
            if (supportDirtyBytes) begin
              dirtyBytes[cts.way].write(ct.dataKey, unpack(0)); // Line is now clean.
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> updated dirties bank %x, way %x with %x",$time, cacheId, 
                                            ct.dataKey, cts.way, 0));
            end
          `endif
          `ifdef MONITOR_EVENTS
            if (ct.addr.bank==0) events.evt_EVICT = True; // trace a writeback once per line.
          `endif
        end
      end
      MemResponse: begin
        Bool lastlastMismatch = False;
        Bool last = getLastField(memResp);
        // Put in a Read flit by default so that the later "hack" will not interpret a Write command as a memory read fill.
        ct.req.operation = tagged Read {
          uncached: False/*?*/,
          linked: False/*?*/,
          noOfFlits: 0/*?*/,
          bytesPerFlit: ?
          `ifdef USECAP
            ,tagOnlyRead: False
          `endif
        };
        Bool forceResponse = False;
        Bool readResponse = False;
        if (memResp.operation matches tagged Read .rr) readResponse = True;
        Bool readRespForWrite = False;
        
        if (memRsps.notEmpty) begin
          debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> attempting memory response, id: %x, registered_id: %x, responseRecordValid: %d, memRsps.notEmpty: %d, readReqReg.d.outId==getRespId(memResp): %d", 
                                  $time, cacheId, getRespId(memResp), readReqReg.d.outId, responseRecordValid, memRsps.notEmpty, readReqReg.d.outId==getRespId(memResp)));
          if (responseRecordValid) begin // Only proceed with a read fill if we guessed the correct id in the lookup stage.
            
            newReadReqReg.v = True; // Mark the readReqReg as serving an active reqeust.
            RequestRecord#(ways, keyBits, tagBits) reqRec = readReqReg.d;
            debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Trying memory response. ct.reqRec.d.outId:%x, memResp.id:%x, memRsps.notEmpty:%x, memRspIsWrite: %d",
                                        $time, cacheId, reqRec.outId, getRespId(memResp), memRsps.notEmpty, memRspIsWrite));
            
            reqId = reqRec.inId;
            // Early indication that a slave response based on this master response can proceed.
            
            Bank rspFlit = orderer.nextMastRspFlit(getRespId(memResp), True);
            // If this is the next flit expected
            exeThisReq <- orderer.slaveReqExecuteReady(reqId,rspFlit);
            
            exeThisReq = (exeThisReq && !reqRec.inDone && commit.v);
            thisReqLast = orderer.slaveRspLast(reqId, rspFlit);
            if (thisReqLast != last) lastlastMismatch = True;
            thisReqLast = thisReqLast || last;
            
            way              = reqRec.oldWay;
            tagUpdate.newTag = reqRec.oldTag;
            tag = tagUpdate.newTag;
            CacheAddress#(keyBits, tagBits) tmpAddr = unpack(pack(ct.req.addr));
            ct.addr.bank = rspFlit;
            ct.addr.tag = tagUpdate.newTag.tag;
            ct.addr.key = reqRec.key;
            cached      = reqRec.cached;
            ct.req.masterID      = reqRec.inId.masterID;
            ct.req.transactionID = reqRec.inId.transactionID;
            ct.rspError = memResp.error;
            // Store original request address before updating the bank.
            ct.req.addr = unpack(pack(ct.addr));
            addr = ct.addr; // addr = address of incoming data
            ct.dataKey = DataKey{key:ct.addr.key, bank: ct.addr.bank};
            ct.req.operation = tagged Write {
                                    uncached: !cached,
                                    conditional: False,
                                    byteEnable: replicate(True),
                                    bitEnable: -1,
                                    data: memResp.data,
                                    last: last,
                                    length: ?
                                  };
            case (memResp.operation) matches
              tagged Read .rr: begin
                memRsps.deq;
                orderer.mastRsp(getRespId(memResp), True, last);
                readRespForWrite = reqRec.write;
                //debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Memory response lookup, last:%x ", $time, cacheId, last, fshow(ct.req)));                                    
                // Construct reqId to recall key.
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Found %x in ID table ", $time, cacheId, memRspId, fshow(reqRec)));
                if (last) begin
                  debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Removing %x from ID table ", $time, cacheId, memRspId));
                  if (!oneInFlight) readReqs.remove(memRspId);
                  newReadReqReg.v = False;
                end
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> received memory response ", $time, cacheId, fshow(memResp)));
                ct.last = last;
              end
              tagged Write &&& exeThisReq: begin
                memRsps.deq;
                orderer.mastRsp(getRespId(memResp), True, last);
                forceResponse = True;
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Removing %x from ID table for Write response", $time, cacheId, memRspId));
                if (!oneInFlight) readReqs.remove(memRspId);
                newReadReqReg.v = False;
              end
              tagged SC .scr &&& exeThisReq: begin
                memRsps.deq;
                orderer.mastRsp(getRespId(memResp), True, last);
                scResult = scr;
                cacheResp.operation = tagged SC scResult;
                forceResponse = True;
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Removing %x from ID table", $time, cacheId, memRspId, fshow(scr)));
                if (!oneInFlight) readReqs.remove(memRspId);
                newReadReqReg.v = False;
                //debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> store conditional response lookup, scResult:%x, last:%x ", $time, cacheId, scResult, last, fshow(ct.req)));
              end
            endcase
            if (!noReqs) debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> exeThisReq:%x, reqId:%x, last:%x, addr.bank: %x, rspFlit:%x, isValid(commit):%x",
                                                        $time,    cacheId,              exeThisReq,    reqId,    last,    addr.bank,     rspFlit,    commit.v));
          end else if (memRspIsWrite && !memRspHasResponseRecord) begin
            memRsps.deq;
            Bool uncachedResp = False;
            if (!oneInFlight) begin
                newReadReqReg.v = False;
                newReadReqReg.d.outId = getRespId(memResp);
            end
            orderer.mastRsp(getRespId(memResp), uncachedResp, getLastField(memResp));
            debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> received write memory response with no response record, id: %x", 
                                          $time, cacheId, getRespId(memResp)));
          end
        end
        
        Bool cacheNop = False;
        
        req = ct.req;
        deqId = getReqId(req);
        deqReqCommits = False;
        linked = False;
        conditional = False;
        
        // Setup response ID fields in case we return the response.
        cacheResp.masterID = reqId.masterID;
        cacheResp.transactionID = reqId.transactionID;
        
        case (ct.req.operation) matches
          tagged Write .wop: begin
            if (cached && readResponse) begin
              // Do fill
              data[way].write(ct.dataKey, DataMinusCapTags{data: wop.data.data});  
              `ifdef WRITEBACK_DCACHE
                if (supportDirtyBytes) begin
                  dirtyBytes[way].write(ct.dataKey, unpack(0));  
                  debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> updated dirties bank %x, way %x with %x",$time, cacheId, 
                                            ct.dataKey, way, 0));
                end
              `endif
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> filled cache bank %x, way %x with %x", 
                                          $time, cacheId, ct.dataKey, way, wop.data));
              // If pendMem is already clear, this line has been invalidated previously, so don't do a tag update.
              if (tag.pendMem) begin
                tag.valid[addr.bank] = True;
                `ifdef USECAP
                  tag.capTags[ct.dataKey.bank] = wop.data.cap;
                `endif
                // If there was an error, declare the whole line valid to prevent deadlock due to repeated refetching.
                // If we think there should be another response flit but there is not, this is also a serious error.
                if (memResp.error!=NoError || lastlastMismatch) tag.valid = unpack(-1);
                if (ct.last) tag.pendMem = False;
                tagUpdate.newTag = tag;
                tagUpdate.way = way;
                //tags.write(ct.dataKey.key, tagsUpdate.newTags);
                tagUpdate.doWrite = True;
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Wrote tags key=0x%0x, way=%d ", $time, cacheId, addr.key, way, fshow(tag)));
              end
              RequestRecord#(ways, keyBits, tagBits) newRec = RequestRecord{
                                                                    key: ct.dataKey.key, 
                                                                    inId: readReqReg.d.inId,
                                                                    inDone: readReqReg.d.inDone,
                                                                    outId: readReqReg.d.outId,
                                                                    cached: cached,
                                                                    oldTag: tagUpdate.newTag,
                                                                    oldWay: way,
                                                                    oldDirty: tag.dirty && any(id,tag.valid),
                                                                    write: readRespForWrite
                                                                };
              newReadReqReg.d = newRec; // In order to update the tag record.
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Updating %x in ID table", $time, cacheId, memRspId, fshow(newRec)));
            end else if (!readResponse) begin
              //respValid = True;
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> cached and store conditional ", $time, cacheId, fshow(getRespId(cacheResp))));
              dead = True;
              // If pendMem is already clear, this line has been invalidated previously, so don't do a tag update.
              if (tag.pendMem) begin
                // Clear the "pendMem" flag in the tags for this line.
                tag.pendMem = False;
                tagUpdate.newTag = tag;
                tagUpdate.way = way;
                tagUpdate.doWrite = True;
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Wrote tags key=0x%0x, way=%d ", $time, cacheId, addr.key, way, fshow(tag)));
              end
            end
            // doWrite set above.
            tagUpdate.key = ct.dataKey.key;
          end
          default: exeThisReq = False; // Don't send a response if we've had no memory response!
        endcase
        
        // These few lines send a basic response to a CacheNop request if we have one.
        // Feeding CacheNop's through this path allows us to consume memory responses
        // while responding to Nops.
        
        // Look at original request, not the possibly overwritten version.
        if (cts.req.operation matches tagged CacheOp .cop &&& cop.inst == CacheNop && serveThisReq) cacheNop = True;
        if (cacheNop) begin
          forceResponse = True;
          last = True;
          thisReqLast = True;
          cacheResp.operation = tagged Write;
          cacheResp.masterID = cts.req.masterID;
          cacheResp.transactionID = cts.req.transactionID;
        end
        if (forceResponse) begin
          exeThisReq = True;
          readRespForWrite = False;
        end
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> exeThisReq:%x, readRespForWrite:%x, reqId:%x, last:%x, noReqs:%x",
                                    $time, cacheId, exeThisReq, readRespForWrite, reqId, last, noReqs));
        // Send a response if this memory response was for the request that is next, 
        // and if this request was not a write request.
        if (exeThisReq && !readRespForWrite) begin
          if (!forceResponse) begin
            cacheResp.operation = tagged Read {
                last: thisReqLast
                `ifdef USECAP
                  ,tagOnlyRead: tagOnlyRead
                `endif
            };
          end
          
          respValid = True;
          if (cacheResp.operation matches tagged Write &&& responseBehaviour==OnlyReadResponses) respValid = False;
          reportResponse = True;
          if (thisReqLast) begin
            if (getRespId(cacheResp) == newReadReqReg.d.inId) newReadReqReg.d.inDone = True;
            deqReqCommits = True;
          end
          rspId = getRespId(cacheResp);
        end
      end
      Serve: begin
        if (memRsps.notEmpty && !memRspHasResponseRecord) begin
          if (memRspIsWrite) begin
            memRsps.deq;
            if (!oneInFlight) begin
                newReadReqReg.v = False;
                newReadReqReg.d.outId = getRespId(memResp);
            end
            orderer.mastRsp(getRespId(memResp), False, getLastField(memResp));
            debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> received write memory response in serve (no record) ", $time, cacheId, fshow(getRespId(memResp))));
          end
        end
        Bool doMemRequest = False;
        function ActionValue#(Bool) doWriteback = actionvalue
          Bool failed = False;
          if (tag.valid[addr.bank] && tag.dirty && !writeThrough) begin
            if (roomForWriteback) begin
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Requesting eviction! Address: %x", $time, cacheId, CacheAddress{tag: tag.tag, key: addr.key, bank: addr.bank, offset: 0}));
              writebacks.enq(AddrTagWay{
                way   : way,
                tag   : tag,
                addr  : CacheAddress{tag: tag.tag, key: addr.key, bank: addr.bank, offset: 0},
                cached: True,
                reqId : reqId
              });
            end else failed = True;
          end
          return failed;
        endactionvalue;
        
        Bool needWriteback = False;
        Bool dontCommit = req.cancelled;
        
        exeThisReq <- orderer.slaveReqExecuteReady(reqId, addr.bank);
        if (!noReqs) debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> serveThisReq:%x, exeThisReq:%x, reqId:%x, thisReqLast:%x, addr.bank: %x, isValid(commit):%x, miss:%x",
                                                      $time, cacheId,              serveThisReq,    exeThisReq,    reqId,    thisReqLast,    addr.bank,     commit.v,           miss));
      

        // If the instruction did not commit, don't perform the cache instruction.
        if (commit.v && !commit.d) dontCommit = True;
        // Unless it is a CacheWriteback, since it might be injected as a cache flush for coherency, and it doesn't modify state anyway. 
        if (req.operation matches tagged CacheOp .cop &&& cop.inst matches tagged CacheWriteback) dontCommit = False;
        if (req.operation matches tagged CacheOp .cop &&& cop.inst matches tagged CacheSync)      dontCommit = False;
        if (serveThisReq && dontCommit) begin
          debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Don't commit, NULL response! ", $time, cacheId));
          Bool giveReadResponse = False;
          if (req.operation matches tagged Read .rop)  giveReadResponse = True;
          
          if (giveReadResponse) cacheResp.operation = tagged Read {
                                    last: thisReqLast
                                    `ifdef USECAP
                                      ,tagOnlyRead: tagOnlyRead
                                    `endif
                                };
          else if (req.operation matches tagged Write .wop &&& wop.conditional)
                                cacheResp.operation = tagged SC False;
          
          respValid = True;
        // This case will skip an attempt at success for now under the following conditions:
        end else if ( !serveThisReq // skip this request if we're not serving and this was a miss.
                      || (!exeThisReq && !cached) // skip this request if we can't execute and it's uncached.
                      || writebacks.notEmpty // If there is an unfinished writeback request so that we don't overfill request fifo.
                      || invalidateWritebacks.notEmpty
                    ) begin
          // If this request is uncached and not next, don't do a lookup because an uncached load must be at the head of the queue
          // when the response comes back or the response will be dropped on the floor because it is not stored in the cache.
          // If it is in the head of the queue when we first issue the request, it will certainly be there when it gets back.
          //
          // Cached requests can begin early (though we will still respond in order).
          dead = True;
          debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> failing early - noReqs(%x), miss(%x), (!serveThisReq(%x) && !cached(%x)), writebacks.notEmpty(%x), ct.fresh(%x)", 
                                       $time, cacheId, noReqs, miss, serveThisReq, cached, writebacks.notEmpty, ct.fresh));
        end else begin
          case (req.operation) matches
            tagged CacheOp .cop /*&&& (!prefetchMissLocal)*/: begin
              if (cop.cache == whichCache) begin
                respValid = True;
                if (cop.indexed) miss = False;
                case (cop.inst) matches
                  CacheInvalidate &&& (!miss): begin
                    doInvalidate = True;
                  end
                  CacheInvalidateWriteback &&& (!miss): begin
                    doInvalidate = True;
                    Bool failed <- doWriteback;
                    if (failed) dead = True;
                  end
                  CacheWriteback &&& (!miss): begin
                    Bool failed <- doWriteback;
                    if (failed) dead = True;
                  end
                  CacheLoadTag: begin
                    returnTag = True;
                  end
                  // TIME-BASED COHERENCE, manage barrier instructions
                  CacheSync: begin
                    `ifdef TIMEBASED
                      // When we get a SYNC for the self-invalidate case, we just toast the whole cache.
                      // We had better not have any dirty lines in this case!
                      cacheState <= Init;
                      debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Cache SYNC received, reinitialising cache", $time, cacheId));
                    `endif
                  end
                endcase
              end else begin
                doMemRequest = True;
                respValid = True;
              end
            end
            tagged Read .rop &&& (!miss && passConditional && !writeThrough && tag.dirty): begin
              doInvalidate = True;
              Bool failed <- doWriteback;
              if (failed) dead = True;
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Load Linked - Dirty line, requires writeback", $time, cacheId, addr.key));
            end
            tagged Read .rop &&& (!miss && (cached
                `ifdef USECAP
                  || tagOnlyRead
                `endif
                ) && !passConditional): begin
              cachedResponse=True;
            end
            tagged Read .rop &&& (!miss && !cached && !passConditional): begin
              writeTagsEvenIfDead = True;
              if (tag.dirty) begin
                if (roomForWriteback) begin
                  Bool wontFail <- doWriteback;
                  doInvalidate = True;
                end
                dead = True;
              end else doInvalidate = True;
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Uncached Read Hit - tag.dirty: %x, roomForWriteback: %x", $time, cacheId, tag.dirty, roomForWriteback));
            end
            tagged Write .wop &&& (passConditional || !cached): begin
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Passing store conditional or uncached write in CacheCore, addr %x", $time, cacheId, addr));
              // If the tag we are going to use is dirty, evict. 
              // (not really sure why we need a tag slot, but that's how the mechanism works in the general case, so we'll go with it.)
              if (tag.dirty) begin
                doMemRequest = False;
                dead = True;
                if (roomForWriteback) begin
                  Bool wontFail <- doWriteback;
                  doInvalidate = True;
                  writeTagsEvenIfDead = True;
                end
              end else begin
                doMemRequest = True;
                // Setup flags for outstanding request.
                // It should not be necessary to always invalidate the line, but we must let
                // later operations know that there is an pending memory request on this line.
                tagUpdate.newTag = invTag;
                tagUpdate.newTag.pendMem = cached;
                tagUpdate.way = way;
                writeTags = !miss;
                writeTagsEvenIfDead = !miss;
                ct.way = way;
                // done with tag update.
                expectResponse = True;
              end
            end
            tagged Write .wop &&& (!miss && cached && !passConditional): begin
              cachedWrite = True;
              tagUpdate.newTag = TagLine{
                tag      : tag.tag,
                dirty    : (performWritethrough) ? False:True,
                pendMem  : tag.pendMem,
                `ifdef USECAP
                  capTags : tag.capTags,
                `endif
                valid    : tag.valid
              };
              //if (!writeThrough && tag.dirty != True)
              writeTags = True;
              if (performWritethrough) doMemRequest = True;
            end
            /*tagged Write .wop &&& (!cached): begin
              //Write directly to memory.
              doMemRequest = True;
              if (!miss) begin
                writeTagsEvenIfDead = True;
                if (tag.dirty) begin
                  if (roomForWriteback) begin
                    Bool wontFail <- doWriteback;
                    doInvalidate = True;
                  end
                  dead = True;
                end else doInvalidate = True;
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Uncached Write Hit - tag.dirty: %x, roomForWriteback: %x", $time, cacheId, tag.dirty, roomForWriteback));
              end else debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Sending ", $time, cacheId, fshow(getReqId(memReq))));
              expectResponse = True;
            end*/
            tagged Write .wop &&& (performWritethrough): begin
              doMemRequest = True;
              if (!miss) doInvalidate = True;
            end
            default: begin  // It's a miss!
              `ifdef USECAP
                // Turn it into uncached if we had a miss on tagOnlyRead, because
                // a miss makes tagOnlyRead behave like uncached reads
                if (tagOnlyRead) cached = False;
              `endif
              // If it's a cached operation, align the access.
              if (cached) begin
                memReq.addr = unpack(pack(CacheAddress{
                                          tag: addr.tag, 
                                          key: addr.key, 
                                          bank: 0,
                                          offset:0
                                       }));
                // If the conditions for a fill are good and we need to, do an eviction.
                if (tag.dirty) begin
                  debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> CacheCore - attempting Writeback roomForReadAndWriteback: %x ", $time, cacheId, roomForReadAndWriteback));
                  if (roomForReadAndWriteback && exeThisReq) Bool wontFail <- doWriteback;
                  else dead = True;
                end
              end
              
              if (!dead) begin
                memReq.operation = tagged Read {
                                      uncached: !cached,
                                      `ifdef USECAP
                                        tagOnlyRead: tagOnlyRead,
                                      `endif
                                      linked: linked,
                                      noOfFlits: (cached) ? 3:0,
                                      bytesPerFlit: (cached) ? cheriBusBytes : (case (req.operation) matches
                                          tagged Read .rop : return rop.bytesPerFlit;
                                        endcase)
                                  };
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> CacheCore - Fetch on write Miss / cached Miss ", $time, cacheId, fshow(getReqId(req))));
                doMemRequest = True;
                expectResponse = True;
              end
            end
          endcase

          // If we intend to issue a new memory request, but an existing memory request is outstanding (and we only support one in flight)...
          if (doMemRequest && oneInFlight && readReqReg.v) dead = True;
          // If this is not the next request, kill the external request under two conditions...
          if (!exeThisReq && !isRead) dead = True;
          if (doMemRequest && !dead) begin
            // Don't issue a memory request if:
            //   Our table of outstanding memory requests if full
            //   If we don't have room for one more request in the output FIFO
            //   If this line already has an outstanding memory request
            Bool doMemRequestShouldSucceed = (roomForOneRequest);
            if (!doMemRequestShouldSucceed) debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> External memory request failing: roomForOneRequest:%x", $time, cacheId, roomForOneRequest));
            if (doMemRequestShouldSucceed && !dead) begin // And if this is the next request in the queue.
              ReqId outReqId = ReqId{masterID: req.masterID, transactionID: orderer.mastNextId};
              memReq.masterID = outReqId.masterID;
              memReq.transactionID = outReqId.transactionID;
              memReqs.enq(memReq);
              // Report the new memory request to the orderer so that it can track the responses.
              CacheAddress#(keyBits, tagBits) ca = unpack(pack(memReq.addr));
              Bool read = False;
              Bank first = ca.bank;
              Bank last = first + 0;
              if (memReq.operation matches tagged Read .rop) begin
                read = True;
                last = first + truncate(rop.noOfFlits);
              end
              orderer.mastReq(outReqId, first, last, truncateLSB(memReq.addr.lineNumber), expectResponse); 
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Issuing external memory request, memReqs.notFull:%x, memReqFifoSpace:%x ", 
                                            $time, cacheId, memReqs.notFull, memReqFifoSpace, fshow(memReq)));
              if (expectResponse) begin
                if (cached) begin
                  tagUpdate.newTag = TagLine{
                    tag     : addr.tag,
                    pendMem : True,
                    valid   : replicate(False),
                    `ifdef USECAP
                      capTags : replicate(replicate(False)),
                    `endif
                    dirty   : False
                  };
                  writeTags = True;  // This must happen!
                  writeTagsEvenIfDead = True;
                  ct.way = way;
                  tagUpdate.way = way;
                  nextWay <= nextWay + 1; // Increment nextWay after each cache fill so that the next fill will be to a different way.
                end
                RequestRecord#(ways, keyBits, tagBits) reqRec = RequestRecord{
                                                                  key: addr.key, 
                                                                  inId: reqId, // request id of original request
                                                                  inDone: False,
                                                                  outId: getReqId(memReq),
                                                                  cached: cached,
                                                                  oldTag: tagUpdate.newTag,
                                                                  oldWay: way,
                                                                  oldDirty: tag.dirty&&any(id,tag.valid),
                                                                  write: isWrite
                                                               };
                debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Inserting %x into ID table", $time, cacheId, outReqId, fshow(reqRec)));
                // Insert info about the outstanding request keyed by external request id.
                if (oneInFlight) newReadReqReg = VnD{v: True, d: reqRec};
                else readReqs.insert(outReqId, reqRec);
              end
            end else begin // Kill the operation if we were meant to send a memory request but couldn't
              dead = True;
              // Don't write tags for fill if we didn't send a request.
              if (expectResponse) writeTags = False;
            end
          end

          // Report state of lookup
          if (firstFresh) begin // Only report once, when the lookup is fresh
            cycReport($display("%s[$%s%s%s] %x",
            `ifdef MULTI
              case (cacheId)
                0,1: return "c0";
                2,3: return "c1";
                4,5: return "c2";
                6,7: return "c3";
                default: return "";
              endcase,
            `else
               "",
            `endif
            case (whichCache)
              ICache: return "IL1";
              DCache: return "DL1";
              L2:     return "L2";
              TCache: return "T";
            endcase,
            req.operation matches tagged Read .* ?"R":"W",(miss)?"M":"H", addr));
          end
          `ifdef MONITOR_EVENTS
            events.evt_WRITE = firstFresh && isWrite;
            events.evt_WRITE_MISS = firstFresh && isWrite && miss;
            events.evt_READ = firstFresh && isRead;
            events.evt_READ_MISS = firstFresh && isRead && miss;
            //incHitPftch:   (firstFresh && !miss && isPftch),
            //incMissPftch:  (firstFresh &&  miss && isPftch),
            //incPftchEvict: (evict && isPftch)
          `endif
          
          if (cachedResponse) begin
            //Return cached data.
            cacheResp.operation = tagged Read {
                last: thisReqLast
                `ifdef USECAP
                  ,tagOnlyRead: tagOnlyRead
                `endif
            };
            
            respValid = True;
            debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> returning @0x%0x:0x%0x", $time, cacheId, addr, dataRead));
          end
          
          // From this point on, kill the request completely if it is not next or if there is an outstanding memory request on this line.
          if (!exeThisReq) dead = True;
          
          // Do any tag update that has been requested if this update is committing (or if we issued a memory request).
          if (!dead||writeTagsEvenIfDead) begin
            if (doInvalidate) begin
              tagUpdate.newTag = invTag;
              //tags.write(addr.key, tagsUpdate);
              tagUpdate.doWrite = True;
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Invalidating key=0x%0x, way=%d", $time, cacheId, addr.key, way));
            end else if (writeTags) begin
              tagUpdate.way = way;
              //tags.write(addr.key, tagsUpdate);
              tagUpdate.doWrite = True;
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Wrote tags key=0x%0x, way=%d ", $time, cacheId, addr.key, way, fshow(tagUpdate)));
            end
          end
          
          // Only finish the write if this is the next operation in order.
          if (req.operation matches tagged Write .wop &&& !dead && cached) begin
            cacheResp.operation = tagged Write;
            if (cachedWrite) begin
              //Construct new line.
              function Byte choose(Byte o, Byte n, Bool sel) = (sel) ? ((n&wop.bitEnable)|(o&~wop.bitEnable)):o;
              // zipWith3 combines the three vectors with the function "choose", defined above, producing another vector.
              // In this case it is just selecting the old byte or new byte based on byteEnable.
              Vector#(CheriBusBytes,Byte) maskedWriteVec = zipWith3(choose, unpack(dataRead.data), unpack(wop.data.data), wop.byteEnable);
              DataMinusCapTags#(CheriDataWidth) maskedWrite;
              maskedWrite.data = pack(maskedWriteVec);
              `ifdef USECAP
                // Fold in capability tags.
                CapTags capTags = tag.capTags[addr.bank];
                Integer i;
                for (i=0; i<valueOf(CapsPerFlit); i=i+1) begin
                  Integer bot = i*valueOf(CapBytes);
                  Integer top = bot + valueOf(CapBytes);
                  Bit#(CapBytes) capBytes = pack(wop.byteEnable)[min(top,valueOf(CheriBusBytes))-1:bot];
                  if (capBytes != 0) capTags[i] = wop.data.cap[i];
                end
                //$display("capTags: %x", capTags);
                tag.capTags[addr.bank] = capTags; // Is this necessary?
                tagUpdate.newTag.capTags[addr.bank] = capTags;
                `ifdef MONITOR_EVENTS
                  `ifdef USECAP
                    events.evt_SET_TAG_WRITE = pack(capTags) != 0;
                  `endif
                `endif
              `endif
              //Write updated line to cache.
              debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> wrote cache bank %x, way %x with %x",$time, cacheId, 
                                           {addr.key, pack(addr.bank)}, way, maskedWrite));
              dataRead = maskedWrite;
              data[way].write(DataKey{key:addr.key, bank:addr.bank}, dataRead);
              `ifdef WRITEBACK_DCACHE
                if (supportDirtyBytes) begin
                  // Update the dirty bytes if we didn't write through.  Could check performWritethrough, but possibly checking doMemRequest is more reliable.
                  if (!writeThrough && !doMemRequest) dirties = unpack(pack(dirties)|pack(wop.byteEnable)); // Mark newly written bytes as dirty.
                  else dirties = unpack(pack(dirties)&~pack(wop.byteEnable)); // If we have written through, these bytes are clean.
                  dirtyBytes[way].write(DataKey{key:addr.key, bank:addr.bank}, dirties);
                  debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> updated dirties bank %x, way %x with %x, doMemRequest: %d",$time, cacheId, 
                                            {addr.key, pack(addr.bank)}, way, dirties, doMemRequest));
                end
              `endif
              respValid = True;
            end
            // If this is a store conditional and we're not handling it,
            // the response is coming later.
            if (conditional && (performWritethrough)) dead = True;
            if (supportInvalidates && writethroughNext.notEmpty && doMemRequest && !dead) writethroughNext.deq;
            if (miss && (performWritethrough)) respValid = True;
          end
        end

        if (dead) respValid = False;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Request Dead %x, noReqs %x", 
                                      $time, cacheId, dead, noReqs));
        // Report the hit or miss of this lookup, only once per access.
        if (respValid) begin
          reportResponse = True;
          if (thisReqLast) begin
            debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Finishing request ", $time, cacheId, fshow(getReqId(req))));
            // If this successful response came from the retry fifo, deq it now.
            if (getRespId(cacheResp) == newReadReqReg.d.inId) newReadReqReg.d.inDone = True;
            deqId = getRespId(cacheResp);
            deqReqCommits = True;
          end else begin
            rspId = getRespId(cacheResp);
          end
          if (responseBehaviour == OnlyReadResponses) begin
            case (cacheResp.operation) matches
              tagged Read .rop: respValid = respValid; // Do nothing, we're only interested in the default case.
              tagged SC   .scr: respValid = respValid; // Do nothing, we're only interested in the default case.
              default: respValid = False;
            endcase
          end
          `ifdef MONITOR_EVENTS
            `ifdef USECAP
              if (cacheResp.operation matches tagged Read .rop &&& getRespId(cacheResp) != lastRespId) begin
                events.evt_SET_TAG_READ = pack(cacheResp.data.cap) != 0;
              end
              lastRespId <= getRespId(cacheResp);
            `endif
          `endif
        end
      end
    endcase
    
    if (firstFresh) begin
      debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Enquing fresh request to retry reqs fifo ", $time, cacheId, fshow(getReqId(cts.req))));
      enqRetryReq = True;
    end

    `ifdef MONITOR_EVENTS
      eventsWire <= events;
    `endif
    
    Bool needInvWriteback = False;
    if (supportInvalidates) begin
      // If we're meant to write an invalidate but we need to write tags for a regular lookup, mark the failure so we can retry.
      if (ct.invalidate.valid && tagUpdate.doWrite) failedInvalidate = True;
    end
    if (tagUpdate.doWrite) tags[tagUpdate.way].write(tagUpdate.key,tagUpdate.newTag);
    else if (supportInvalidates && ct.invalidate.valid && !invalidateDone && !failedInvalidate ) begin
      Bool failedWriteback = False;
      TagLine#(tagBits) oldTag = shadowTag;
      needInvWriteback = oldTag.valid[0] && oldTag.dirty && !writeThrough;
      if (needInvWriteback) begin
        if (roomForWriteback && invalidateWritebacks.notFull) begin
          debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Requesting eviction for invalidate! Address: %x ", 
                                      $time, cacheId, CacheAddress{tag: tag.tag, key: addr.key, bank: addr.bank, offset: 0}, fshow(ct.invalidate)));
          invalidateWritebacks.enq(AddrTagWay{
            way   : ct.invalidate.way,
            tag   : oldTag,
            addr  : CacheAddress{tag: oldTag.tag, key: ct.invalidate.key, bank: 0, offset: 0},
            cached: True,
            reqId : reqId
          });
        end else failedWriteback = True;
      end
      if (!failedWriteback) begin
        invalidateDone = True;
        tags[ct.invalidate.way].write(ct.invalidate.key, invTag);
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Invalidate, wrote tags key: %x", $time, cacheId, ct.invalidate.key));
        // If this way is also pending, wipe out the copy of the tags in the readReqReg (only works with oneInFlight)
        if (invPendWay.v) begin
          newReadReqReg.d.oldTag = invTag;
          debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Invalidated pending tag record, readReqReg.oldTag <- invalidTags", $time, cacheId));
        end
      end
      //failedInvalidate = failedWriteback;
    end
    if (supportInvalidates && ct.invalidate.valid) begin
      if (!invalidateDone) delayedInvalidates.enq(cts.invalidate);
      else begin
        invalidatesDone.enq(needInvWriteback);
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> enqued Invalidates done, needInvWriteback: %x", $time, cacheId, needInvWriteback));
      end
    end
    if (!oneInFlight) begin
      VnD#(RequestRecord#(ways, keyBits, tagBits)) maybeNewReadReq = VnD{v: False, d: ?};
      if (!newReadReqReg.v) begin
        if (memRsps.notEmpty) begin
          maybeNewReadReq = readReqs.isMember(memRspId);
        end else if (!readReqs.empty) begin
          maybeNewReadReq = readReqs.nextData;
        end
      end
      // Mark as not valid, meaning speculative/not yet ongoing if this cache supports multiple requests in flight.
      if (!newReadReqReg.v && maybeNewReadReq.v) newReadReqReg = VnD{v: oneInFlight, d: maybeNewReadReq.d};
    end
    readReqReg <= newReadReqReg;
    debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Writing readReqReg ", $time, cacheId, fshow(newReadReqReg)));
    
    // Save all the state-changing writes for the get method.
    resps <= ResponseToken{
      resp: cacheResp,
      req: cts.req,
      rspId: rspId,
      enqRetryReq: enqRetryReq,
      reportResponse: reportResponse,
      deqId: deqId,
      deqReqCommits: deqReqCommits
    };
    respsReady <= respValid;
    if (respValid) debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Setting valid response ", $time, cacheId, fshow(getRespId(cacheResp))));
  endrule
  
  (* no_implicit_conditions, fire_when_enabled *)
  rule commonStateUpdate; // Ensure that next is dequed every time it is requested to be dequed.
    ResponseToken rt = resps;
    Bool finishedNewReq = False;
    if (!missedResp) begin
      Bool respLast = getLastField(rt.resp);
      if (rt.reportResponse) begin
        orderer.slaveRsp(rt.rspId, respLast);
        if (respLast) begin
          retryReqs.remove(rt.rspId);
          if (rt.rspId == getReqId(rt.req)) finishedNewReq = True;
          debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Removing id %x from retry reqs, finishedNewReq: %d",
                                       $time, cacheId, rt.rspId, finishedNewReq));
        end
      end
      if (rt.deqReqCommits && req_commits.notEmpty) begin
        req_commits.deq;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Dequed req_commits ", $time, cacheId, fshow(req_commits.first)));
      end
      
      if (rt.reportResponse || rt.deqReqCommits || rt.enqRetryReq)
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Updating cache state ", $time, cacheId));
    end
    
    if (!oneInFlight && rt.enqRetryReq && !finishedNewReq) begin
      debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Enqued retry reqs ", $time, cacheId));
      retryReqs.insert(getReqId(rt.req), rt.req);
    end
  endrule
  
  // This function encapsulates the actions that should be taken to serve
  // the response wires if we will not consume them in the response method.
  // This may be done either in the catchResponse rule or in the method itself
  // if it chooses a write response.
  function Action updateStateNoResponse();
    action
      ResponseToken rt = resps;
      Bool missedRespSig = True;
      if (respsReady) debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> updateStateNoResponse called", $time, cacheId));
      if (!respsReady) begin
        missedRespSig = False;
      end else if (rt.resp.operation matches tagged Write &&& writeResps.notFull && whichCache!=ICache) begin
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Missed Delivering write response, buffered it ", $time, cacheId, fshow(rt)));
        ReqIdWithSC enqToWriteResps = ReqIdWithSC{inId: getRespId(rt.resp), isSC: False, scResult: False};
        writeResps.enq(enqToWriteResps);
        missedRespSig = False;
      end else if (rt.resp.operation matches tagged SC .sc &&& writeResps.notFull && whichCache!=ICache) begin
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Missed Delivering SC response, buffered it ", $time, cacheId, fshow(rt)));
        ReqIdWithSC enqToWriteResps = ReqIdWithSC{inId: getRespId(rt.resp), isSC: True, scResult: sc};
        writeResps.enq(enqToWriteResps);
        missedRespSig = False;
      end
      missedResp <= missedRespSig;
    endaction
  endfunction
  
  rule catchResponse(!gotResp);
    updateStateNoResponse();
  endrule
  
  // These conditions tell us whether a new request will certainly be caught if it is inserted.  
  Bool putCondition = (!orderer.reqsFull && cacheState != Init && !writebacks.notEmpty && !invalidateWritebacks.notEmpty);
  
  method Bool canPut() = putCondition;
  method Action put(CheriMemRequest req) if (putCondition);
    debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Putting new request ", $time, cacheId, fshow(req)));
    CacheAddress#(keyBits, tagBits) ca = unpack(pack(req.addr));
    ReqId id = getReqId(req);
    // Report the fresh request to the orderer module.
    Flit noOfFlits = 0;
    if (req.operation matches tagged Read .rop) noOfFlits = rop.noOfFlits;
    orderer.slaveReq(id, truncateLSB(pack(req.addr.lineNumber)), ca.bank, ca.bank + truncate(noOfFlits));
    newReq <= VnD{v: True, d: req};
  endmethod
  
  interface CheckedGet response;
    method canGet = respsReady||writeResps.notEmpty;
    method CheriMemResponse peek;
      ResponseToken rt = resps;
      CheriMemResponse ret = rt.resp;
      if (writeResps.notEmpty) begin
        ret = defaultValue;
        ret.masterID = writeResps.first.inId.masterID;
        ret.transactionID = writeResps.first.inId.transactionID;
        ret.operation = writeResps.first.isSC ? tagged SC  writeResps.first.scResult : tagged Write;
      end
      return ret;
    endmethod
    method ActionValue#(CheriMemResponse) get;
      gotResp <= True;
      ResponseToken rt = resps;
      CheriMemResponse ret = rt.resp;
      debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> get called ", $time, cacheId));
      if (writeResps.notEmpty) begin
        ret = defaultValue;
        ret.masterID = writeResps.first.inId.masterID;
        ret.transactionID = writeResps.first.inId.transactionID;
        ret.operation = writeResps.first.isSC ? tagged SC  writeResps.first.scResult : tagged Write;
        writeResps.deq;
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Delivering valid buffered write response, last: %d ", $time, cacheId, getLastField(ret), fshow(getRespId(ret))));
        updateStateNoResponse();
      end else begin // respsReady in this case.
        debug2("CacheCore", $display("<time %0t, cache %0d, CacheCore> Delivering valid response ", $time, cacheId, fshow(ret)));
      end
      return ret;
    endmethod
  endinterface
  
  method Action nextWillCommit(Bool nextCommitting) if (req_commits.notFull);
    req_commits.enq(nextCommitting);
  endmethod
  
  method Action invalidate(CheriPhyAddr addr) if (invalidates.notFull && (delayedInvalidates.remaining > 4));
    if (supportInvalidates) invalidates.enq(addr);
  endmethod
  // The cache is ~consistent if there are no outstanding invalidates.
  method ActionValue#(Bool) invalidateDone() if (invalidatesDone.notEmpty);
    Bool ret = False;
    if (supportInvalidates) begin
      ret = invalidatesDone.first;
      invalidatesDone.deq;
    end
    return ret;
  endmethod

  `ifdef STATCOUNTERS
  interface Get cacheEvents;
      method ActionValue#(ModuleEvents) get;
          let cacheCoreEvents = CacheCoreEvents {
            id: fromInteger(cacheId),
            whichCache: whichCache,
            incHitWrite:   eventsWire.evt_WRITE && !eventsWire.evt_WRITE_MISS,
            incMissWrite:  eventsWire.evt_WRITE_MISS,
            incHitRead:    eventsWire.evt_READ && !eventsWire.evt_READ_MISS,
            incMissRead:   eventsWire.evt_READ_MISS,
            //incHitPftch:   eventsWire. ,
            //incMissPftch:  eventsWire. ,
            incEvict:      eventsWire.evt_EVICT
            //incPftchEvict: eventsWire. 
            `ifdef USECAP
              ,
              incSetTagWrite: eventsWire.evt_SET_TAG_WRITE,
              incSetTagRead:  eventsWire.evt_SET_TAG_READ
            `endif
          };
          return tagged CacheCore_E cacheCoreEvents;
      endmethod
  endinterface
  `elsif PERFORMANCE_MONITORING
  method events = eventsWire;
  `endif
endmodule

//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Alexandre Joannou
//     Copyright (c) 2020 Jonathan Woodruff
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
//-

package LLC_AXI4_Adapter;

// ================================================================
// BSV lib imports

import ConfigReg :: *;
import Assert    :: *;
import FIFOF     :: *;
import Vector    :: *;

// ----------------
// BSV additional libs

import GetPut_Aux     :: *;
import Cur_Cycle      :: *;
import Semi_FIFOF     :: *;
import CreditCounter  :: *;

// ================================================================
// Project imports

// ----------------
// From MIT RISCY-OOO

import Types       :: *;
import CacheUtils  :: *;
import CCTypes     :: *;

// ----------------
// From Bluespec Pipes

import AXI4 :: *;
import SourceSink :: *;
import Fabric_Defs  :: *;
import Memory_Config :: *;
import SoC_Map      :: *;
import Assert       :: *;

import VnD :: *;
import Bag :: *;
import ProcTypes :: *;

// ================================================================

interface LLC_AXI4_Adapter_IFC;
   method Action reset;

   // Fabric master interface for memory
   interface AXI4_Master #(Wd_MId, Wd_Addr, Wd_Data,
                           Wd_AW_User, Wd_W_User, Wd_B_User,
                           Wd_AR_User, Wd_R_User) mem_master;
endinterface

// ================================================================

typedef struct {
    Bool tag_req; // meaningful to upgrade to E if toState is S
    idT id; // slot id in child cache
    childT child; // from which child
} LLC_AXI_ID#(type idT, type childT) deriving(Bits, Eq, FShow);

typedef 16 OutstandingWrites;
typedef 16 OutstandingReads;
typedef TAdd#(OutstandingReads, 1) ReadResponseFifos;
typedef 16 WriteAddressHashW;
typedef TDiv#(AccessWidth, 8) AccessBytes;
typedef TDiv#(CLineDataNumBytes, AccessBytes) AccessesPerCLine;
typedef AXI4_RFlit#(Wd_MId, Wd_Data, Wd_R_User) LLCReadResponse;
typedef Bit#(SizeOf#(LLCReadResponse)) LLCReadResponseBits;

Bit#(LogCLineNumMemDataBytes) zeroOffset = 0;
AXI4_Size axiAccessSize = unpack(fromInteger(valueOf(TLog#(AccessBytes))));

module mkLLC_AXi4_Adapter #(MemFifoClient #(idT, childT) llc)
                          (LLC_AXI4_Adapter_IFC)
   provisos(Bits#(idT, idSz),
            Bits#(childT, childSz),
            Eq#(idT),
            Eq#(childT),
            FShow#(ToMemMsg#(idT, childT)),
            FShow#(MemRsAccessMsg#(idT, childT)),

            Add#(a__, SizeOf#(LLC_AXI_ID#(idT, childT)), Wd_MId) // LLC_AXI_ID must fit into the external ID.
           );

   staticAssert(valueOf(AccessesPerCLine) == valueOf(CLineNumAccesses),
                "AXI cache-line burst length must match the cache access count");

   // Verbosity: 0: quiet; 1: LLC transactions; 2: loop detail
   Integer verbosity = 0;
   Reg #(Bit #(4)) cfg_verbosity <- mkConfigReg (fromInteger (verbosity));

   // ================================================================
   // Fabric request/response

   let masterPortShim <- mkAXI4ShimFF;

   // For discarding write-responses
   CreditCounter_IFC #(TLog#(OutstandingWrites)) ctr_wr_rsps_pending <- mkCreditCounter; // 16 outstanding writes.

   Bag#(OutstandingWrites, Bit#(Wd_MId), Bit#(WriteAddressHashW)) outstandingWrites <- mkSmallBag;

   // ================================================================
   // Functions to interact with the fabric

   // Send a read-request into the fabric
   function Action fa_fabric_send_read_req (Fabric_Addr  addr, LLC_AXI_ID#(idT, childT) id);
      action
         Bit#(Wd_MId) arid = zeroExtend(pack(id));
         let mem_req_rd_addr = AXI4_ARFlit {arid:     arid,
                                            araddr:   addr,
                                            arlen:    fromInteger(valueOf(AccessesPerCLine) - 1),
                                            arsize:   id.tag_req ? 1 : axiAccessSize,
                                            arburst:  INCR,
                                            arlock:   fabric_default_lock,
                                            arcache:  fabric_default_arcache,
                                            arprot:   fabric_default_prot,
                                            arqos:    fabric_default_qos,
                                            arregion: fabric_default_region,
                                            aruser:   pack(id.tag_req)};

         masterPortShim.slave.ar.put(mem_req_rd_addr);

         // Debugging
         if (cfg_verbosity > 1) begin
            $display ("    ", fshow (mem_req_rd_addr));
         end
      endaction
   endfunction

   // ================================================================
   // Handle read requests and responses

   Bag#(OutstandingReads, Bit#(Wd_MId), LdMemRq#(idT, childT)) pendingReads <- mkSmallBag;
   Bag#(OutstandingReads, Bit#(Wd_MId), CLineAccessSel) readReceiveAccess <- mkSmallBag;
   // At most OutstandingReads keys exist, each with at most one line burst.
   // Keep a spare keyed FIFO. Do not use FFBag.full: another RID's complete
   // queued burst must not prevent reception of the selected RID's next beat.
   // Per-ID access/RLAST assertions bound each queue to AccessesPerCLine.
   FFBag#(ReadResponseFifos, Bit#(Wd_MId),
          LLCReadResponseBits, AccessesPerCLine) readResponses <- mkFFBag;
   FIFOF#(Bit#(Wd_MId)) readyReadIds <- mkSizedFIFOF(valueOf(OutstandingReads));
   Reg#(CLineAccessSel) rg_rd_drain_access <- mkReg(0);

   rule rl_handle_read_req (llc.toM.first matches tagged Ld .ld
                            &&& (ctr_wr_rsps_pending.value == 0));
      LLC_AXI_ID#(idT, childT) llcId = LLC_AXI_ID {
         tag_req: ld.tag_req, id: ld.id, child: ld.child
      };
      Bit#(Wd_MId) arid = zeroExtend(pack(llcId));
      let active = pendingReads.isMember(arid);
      if (!pendingReads.full && !active.v) begin
         dynamicAssert(!active.v, "duplicate active AXI read ID");
         if (cfg_verbosity > 0) begin
            $display ("%0d: LLC_AXI4_Adapter.rl_handle_read_req: Ld request from LLC to memory",
                      cur_cycle);
            $display ("    ", fshow (ld));
         end

         Addr line_addr = {truncateLSB(ld.addr), zeroOffset};
         fa_fabric_send_read_req(line_addr, llcId);
         pendingReads.insert(arid, ld);
         readReceiveAccess.insert(arid, 0);
         llc.toM.deq;
      end
   endrule

   // Responses may interleave across IDs. Select a burst on its first beat,
   // then drain it as beats arrive; other IDs retain their keyed beat queues.
   // Never wait for RLAST to make the selected burst visible to the LLC.
   rule rl_receive_read_rsp;
      let mem_rsp <- get(masterPortShim.slave.r);
      let pending = pendingReads.isMember(mem_rsp.rid);
      let receiveAccess = readReceiveAccess.isMember(mem_rsp.rid);
      dynamicAssert(pending.v, "AXI read response has unknown RID");
      dynamicAssert(receiveAccess.v, "AXI read response RID has no receive position");

      if (cfg_verbosity > 1) begin
         $display ("%0d: LLC_AXI4_Adapter.rl_receive_read_rsp: ", cur_cycle);
         $display ("    ", fshow (mem_rsp));
      end
      if (mem_rsp.rresp != OKAY) begin
         // TODO: need to raise a non-maskable interrupt (NMI) here
         $display ("%0d: LLC_AXI4_Adapter.rl_receive_read_rsp: fabric response error; exit", cur_cycle);
         $display ("    ", fshow (mem_rsp));
         $finish (1);
      end

      if (pending.v && receiveAccess.v) begin
         LLC_AXI_ID#(idT, childT) expectedId = LLC_AXI_ID {
            tag_req: pending.d.tag_req, id: pending.d.id, child: pending.d.child
         };
         dynamicAssert(mem_rsp.rid == zeroExtend(pack(expectedId)),
                       "AXI read response full RID does not match request metadata");
         Bool expectedLast = receiveAccess.d == fromInteger(valueOf(AccessesPerCLine) - 1);
         dynamicAssert(mem_rsp.rlast == expectedLast,
                       "AXI read response RLAST is at the wrong per-ID access");
         readResponses.enq(mem_rsp.rid, pack(mem_rsp));
         if (receiveAccess.d == 0)
            readyReadIds.enq(mem_rsp.rid);
         if (mem_rsp.rlast) begin
            readReceiveAccess.remove(mem_rsp.rid);
         end
         else
            readReceiveAccess.update(mem_rsp.rid, receiveAccess.d + 1);
      end
   endrule

   // The selected RID owns the contiguous cache response until its last beat.
   // A gap in that RID stalls drainage, but reception of other RIDs continues.
   rule rl_drain_read_rsp (readResponses.first(readyReadIds.first).v);
      Bit#(Wd_MId) activeRid = readyReadIds.first;
      let buffered = readResponses.first(activeRid);
      let pending = pendingReads.isMember(activeRid);
      dynamicAssert(pending.v, "selected AXI read ID has no request metadata");

      if (pending.v) begin
         LLCReadResponse mem_rsp = unpack(buffered.d);
         dynamicAssert(mem_rsp.rid == activeRid,
                       "buffered AXI read response RID is inconsistent");
         Bool expectedLast = rg_rd_drain_access == fromInteger(valueOf(AccessesPerCLine) - 1);
         dynamicAssert(mem_rsp.rlast == expectedLast,
                       "AXI read drain access order is inconsistent with RLAST");
         CLineAccess accessData = CLineAccess {
            tag: unpack(truncate(mem_rsp.ruser)),
            data: truncate(mem_rsp.rdata)
         };
         MemRsAccessMsg#(idT, childT) resp = MemRsAccessMsg {
            data: accessData,
            access: rg_rd_drain_access,
            last: mem_rsp.rlast,
            child: pending.d.child,
            id: pending.d.id
         };
         llc.rsFromM.enq(resp);
         readResponses.deq(activeRid);

         if (cfg_verbosity > 1)
            $display ("    Response access to LLC: ", fshow (resp));

         if (mem_rsp.rlast) begin
            dynamicAssert(rg_rd_drain_access == fromInteger(valueOf(AccessesPerCLine) - 1),
                          "AXI read burst drained with an invalid access count");
            pendingReads.remove(activeRid);
            readyReadIds.deq;
            rg_rd_drain_access <= 0;
         end
         else begin
            dynamicAssert(rg_rd_drain_access < fromInteger(valueOf(AccessesPerCLine) - 1),
                          "AXI read drain access advanced past the burst length");
            rg_rd_drain_access <= rg_rd_drain_access + 1;
         end
      end
   endrule

   // ================================================================
   // Handle write requests and responses

   // Select successive access-width slices from a cache line.
   Reg #(Bit #(6)) rg_wr_req_beat <- mkReg (0);
   Reg#(Bit#(Wd_MId)) wid_reg <- mkRegU;
   Addr wAddr = ?;
   if (llc.toM.first matches tagged Wb .wb) wAddr = {truncateLSB(wb.addr), zeroOffset};

   rule rl_handle_write_req (llc.toM.first matches tagged Wb .wb &&&
                             ((!outstandingWrites.isMember(wid_reg).v && !outstandingWrites.dataMatch(hash(wAddr)))
                              || (rg_wr_req_beat != 0)
                             )
                            );
      if ((cfg_verbosity > 0) && (rg_wr_req_beat == 0)) begin
         $display ("%d: LLC_AXI4_Adapter.rl_handle_write_req: Wb request from LLC to memory:", cur_cycle);
         $display ("    ", fshow (wb));
      end


      // on first flit...
      // ================
      if (rg_wr_req_beat == 0) begin

         // send AXI4 AW flit
         masterPortShim.slave.aw.put (AXI4_AWFlit {
           awid:     wid_reg,
           awaddr:   wAddr,
           awlen:    fromInteger(valueOf(AccessesPerCLine) - 1),
           awsize:   axiAccessSize,
           awburst:  INCR,
           awlock:   fabric_default_lock,
           awcache:  fabric_default_awcache,
           awprot:   fabric_default_prot,
           awqos:    fabric_default_qos,
           awregion: fabric_default_region,
           awuser:   0});
         // Expect a fabric response
         ctr_wr_rsps_pending.incr;
         outstandingWrites.insert(wid_reg, hash(wAddr));
         wid_reg <= wid_reg + 1;
      end

      // on last flit...
      // ===============
      if (rg_wr_req_beat == fromInteger(valueOf(AccessesPerCLine) - 1)) begin
         llc.toM.deq;
         rg_wr_req_beat <= 0;
      end else // increment flit counter
         rg_wr_req_beat <= rg_wr_req_beat + 1;

      // on each flit ...
      // ================
      Vector #(AccessesPerCLine, Bit #(AccessBytes)) line_strb = unpack(pack(wb.byteEn));
      Vector #(AccessesPerCLine, Bit #(AccessWidth)) line_data = unpack(pack(wb.data.data));
      Vector #(AccessesPerCLine, Bit #(Wd_W_User)) line_tags = unpack(pack(wb.data.tag));
      // send AXI4 W flit
      masterPortShim.slave.w.put(AXI4_WFlit {
        wdata:  line_data[rg_wr_req_beat],
        wstrb:  line_strb[rg_wr_req_beat],
        wlast:  rg_wr_req_beat == fromInteger(valueOf(AccessesPerCLine) - 1),
        wuser:  line_tags[rg_wr_req_beat]
      });
   endrule

   // ----------------
   // Discard write-responses from the fabric

   rule rl_discard_write_rsp;
      let wr_resp <- get(masterPortShim.slave.b);

      if (ctr_wr_rsps_pending.value == 0) begin
         $display ("%0d: ERROR: LLC_AXI4_Adapter.rl_discard_write_rsp: unexpected Wr response (ctr_wr_rsps_pending.value == 0)",
                   cur_cycle);
         $display ("    ", fshow (wr_resp));
         $finish (1);    // Assertion failure
      end

      ctr_wr_rsps_pending.decr;
      outstandingWrites.remove(wr_resp.bid);

      if (wr_resp.bresp != OKAY) begin
         // TODO: need to raise a non-maskable interrupt (NMI) here
         $display ("%0d: LLC_AXI4_Adapter.rl_discard_write_rsp: fabric response error: exit", cur_cycle);
         $display ("    ", fshow (wr_resp));
         $finish (1);
      end
   endrule

   // ================================================================
   // INTERFACE

   method Action reset;
      error("Reset called for LLC AXI4 adapter");
      // XXX resetting this module would cause wedges unless the surrounding
      // fabric was also fully reset
   endmethod

   // Fabric interface for memory
   interface mem_master = masterPortShim.master;
endmodule

// ================================================================

endpackage

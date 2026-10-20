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
import SoC_Map      :: *;

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
typedef 16 WriteAddressHashW;

Bit#(LogCLineNumMemDataBytes) zeroOffset = 0;

module mkLLC_AXi4_Adapter #(MemFifoClient #(idT, childT) llc)
                          (LLC_AXI4_Adapter_IFC)
   provisos(Bits#(idT, idSz),
            Bits#(childT, childSz),
            FShow#(ToMemMsg#(idT, childT)),
            FShow#(MemRsMsg#(idT, childT)),
            Add#(a__, SizeOf#(LLC_AXI_ID#(idT, childT)), Wd_MId) // LLC_AXI_ID must fit into the external ID.
           );

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
                                            arlen:    id.tag_req ? 0 : fromInteger(valueOf(CLineDataNumBytes)/64 - 1),
                                            arsize:   id.tag_req ? 1 : 64,
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

   // The tag controller returns consecutive data beats for each line.
   // Tag-only responses carry the complete bitmap in rdata and may overtake
   // an earlier data request, so route responses using their AXI ID.
   Reg #(CLine) rg_cline <- mkReg (unpack(0));

   rule rl_handle_read_req (llc.toM.first matches tagged Ld .ld
                            &&& (ctr_wr_rsps_pending.value == 0));
      if ((cfg_verbosity > 0)) begin
         $display ("%0d: LLC_AXI4_Adapter.rl_handle_read_req: Ld request from LLC to memory",
                   cur_cycle);
         $display ("    ", fshow (ld));
      end

      Addr  line_addr = {truncateLSB(ld.addr), zeroOffset }; // Addr of containing cache line
      fa_fabric_send_read_req (line_addr, LLC_AXI_ID{tag_req: ld.tag_req, id: ld.id, child: ld.child});
      llc.toM.deq;
   endrule

   rule rl_handle_read_rsps;
      let mem_rsp <- get(masterPortShim.slave.r);
      if (cfg_verbosity > 1) begin
         $display ("%0d: LLC_AXI4_Adapter.rl_handle_read_rsps: ", cur_cycle);
         $display ("    ", fshow (mem_rsp));
      end
      if (mem_rsp.rresp != OKAY) begin
         // TODO: need to raise a non-maskable interrupt (NMI) here
         $display ("%0d: LLC_AXI4_Adapter.rl_handle_read_rsp: fabric response error; exit", cur_cycle);
         $display ("    ", fshow (mem_rsp));
         $finish (1);
      end

      // Shift the next 64-byte fabric beat into the cache line being assembled.
      let new_cline_tag = { mem_rsp.ruser, truncateLSB(pack(rg_cline.tag)) };
      let new_cline_data = { mem_rsp.rdata, truncateLSB(pack(rg_cline.data)) };
      let new_cline = CLine { tag: unpack(new_cline_tag)
                            , data: unpack(new_cline_data) };
      LLC_AXI_ID#(idT, childT) id = unpack(truncate(mem_rsp.rid));

      if (mem_rsp.rlast) begin
         MemRsMsg #(idT, childT) resp = MemRsMsg {data:  new_cline,
                                                  child: id.child,
                                                  id:    id.id};
         if (id.tag_req)
            resp.data = CLine {tag: unpack(truncate(mem_rsp.rdata)), data: ?};

         llc.rsFromM.enq (resp);

         if (cfg_verbosity > 1)
            $display ("    Response to LLC: ", fshow (resp));

         if (!id.tag_req)
            rg_cline <= unpack(0);
      end else begin
         rg_cline <= new_cline;
      end
   endrule

   // ================================================================
   // Handle write requests and responses

   // Each beat handles 512-bits; e.g. 512b cache line takes 1 beat.
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
           awlen:    (fromInteger(valueOf(CLineDataNumBytes)/64))-1, // burst len = awlen+1
           awsize:   64,
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
      if (rg_wr_req_beat == (fromInteger(valueOf(CLineDataNumBytes)/64))-1) begin
         llc.toM.deq;
         rg_wr_req_beat <= 0;
      end else // increment flit counter
         rg_wr_req_beat <= rg_wr_req_beat + 1;

      // on each flit ...
      // ================
      Vector #(TDiv#(CLineDataNumBytes,64), Bit #(64)) line_strb = unpack(pack(wb.byteEn));
      Vector #(CLineNumMemTaggedData, MemTaggedData) line_data = clineToMemTaggedDataVector(wb.data);
      // send AXI4 W flit
      masterPortShim.slave.w.put(AXI4_WFlit {
        wdata:  {pack(line_data[{rg_wr_req_beat,2'd3}].data),
                 pack(line_data[{rg_wr_req_beat,2'd2}].data),
                 pack(line_data[{rg_wr_req_beat,2'd1}].data),
                 pack(line_data[{rg_wr_req_beat,2'd0}].data)
                },
        wstrb:  line_strb[rg_wr_req_beat],
        wlast:  rg_wr_req_beat == (fromInteger(valueOf(CLineDataNumBytes)/64))-1,
        wuser:  {pack(line_data[{rg_wr_req_beat,2'd3}].tag),
                 pack(line_data[{rg_wr_req_beat,2'd2}].tag),
                 pack(line_data[{rg_wr_req_beat,2'd1}].tag),
                 pack(line_data[{rg_wr_req_beat,2'd0}].tag)
                }
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

/*****************************************************************************
 Avalon2ClientServer
 ===================
 
 Provides Avalon (Altera's switched bus standard) slave and master interfaces
 to Bluespec Client and Server interfaces
 *****************************************************************************/


package Avalon2ClientServer;

import FIFO::*;
import FIFOF::*;
import FIFOLevel::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import SpecialFIFOs::*;
import StmtFSM::*;

// Type for avalon bus data
//typedef UInt#(32) UInt#(data_width);
//typedef Maybe#(UInt#(data_width)) ReturnedDataT;

// Memory access type.  Note that MemNull used as part of arbiterlock release message.
typedef enum { MemRead, MemWrite, MemNull } MemAccessT deriving(Bits,Eq);

// Structure for memory requests
typedef struct {
   MemAccessT   rw;
   UInt#(word_address_width)  addr; // word address
   UInt#(data_width)  data;
   Bool arbiterlock;
   Bit#(TDiv#(data_width, 8)) byteenable;
   } MemAccessPacketT#(numeric type word_address_width, numeric type data_width) deriving(Bits,Eq);
	

// Structure for memory requests
typedef struct {
   MemAccessT   rw;
   UInt#(word_address_width)  addr; // word address
   UInt#(data_width)  data;
   Bit#(TDiv#(data_width, 8)) byteenable;
   UInt#(TAdd#(TLog#(burst_length), 1)) burstcount;
   } BurstMemAccessPacketT#(numeric type word_address_width, numeric type data_width, numeric type burst_length) deriving(Bits,Eq);

/*****************************************************************************
   Avalon slave interface to Bluepsec Client interface
   ===================================================
   Simon Moore, September 2009
 *****************************************************************************/


// Avalon Slave Interface
// notes:
//  - all methods are ready and enabled
//  - names are chosen to match what SOPC builder expects for variable names
//    in the Verilog code - don't change!
(* always_ready, always_enabled *)
interface AvalonSlaveIfc#(numeric type word_address_width, numeric type data_width);
   method Action s0(UInt#(word_address_width) address, UInt#(data_width) writedata, Bit#(TDiv#(data_width, 8)) byteenable,
		    Bool write, Bool read, Bool arbiterlock); //, Bool resetrequest);
   method UInt#(data_width) s0_readdata;
   method Bool s0_waitrequest;
endinterface


interface AvalonSlave2ClientIfc#(numeric type word_address_width, numeric type data_width);
   interface AvalonSlaveIfc#(word_address_width, data_width) avs;
   interface Client#(MemAccessPacketT#(word_address_width, data_width),Maybe#(UInt#(data_width))) client;
//(* always_read, always_enabled *)  method Bool reset_from_bus;
endinterface


module mkAvalonSlave2Client(AvalonSlave2ClientIfc#(word_address_width, data_width))
   provisos(Max#(word_address_width,31,31));

   // bypass wires for incoming Avalon slave signals
   Wire#(UInt#(word_address_width)) address_w   <- mkBypassWire;
   Wire#(UInt#(data_width)) writedata_w          <- mkBypassWire;
   Wire#(Bool)        read_w               <- mkBypassWire;
   Wire#(Bool)        write_w              <- mkBypassWire;
   Wire#(Bool)        arbiterlock_w        <- mkBypassWire;
   Wire#(Bit#(TDiv#(data_width, 8)))        byteenable_w        <- mkBypassWire;
   Reg# (Bool)        prev_arbiterlock     <- mkReg(False);
//   Wire#(Bool)        resetrequest_w       <- mkBypassWire;
   
   // bypass wire for Avalon wait signal + pulsewires to clear
   Wire#(Bool)        avalonwait           <- mkBypassWire;
   PulseWire          avalonwait_end_read  <- mkPulseWire;
   PulseWire          avalonwait_end_write <- mkPulseWire;

   // DWire for read data returned to Avalon slave bus
   Wire#(UInt#(data_width)) datareturned <- mkDWire(0);

   // reg indicating that the Avalon request is being processed and further
   // requests should be ignored until the avalonwait signal has been released
   // (gone low)
   Reg#(Bool) ignore_further_requests <- mkReg(False);

   // FIFO holding requests received from Avalon slave bus sent out via
   // the client request interface
   FIFOF#(MemAccessPacketT#(word_address_width, data_width)) outbuf <- mkFIFOF;
   
   // provide the avalonwait signal
   // note: this must appear within the same clock cycle that a read or write
   //       is initiated
   (* no_implicit_conditions *)
   rule wire_up_avalonwait;
      avalonwait <= (read_w && !avalonwait_end_read) || (write_w && !avalonwait_end_write);
   endrule
   
   rule arbiterlock_history;
      prev_arbiterlock <= arbiterlock_w;
   endrule
   
   rule handle_end_arbiterlock (prev_arbiterlock && !arbiterlock_w && !read_w && !write_w);
      outbuf.enq(MemAccessPacketT{
	 rw:   MemNull,     // send MemNull to clear arbiter lock
	 addr: address_w,   // don't care what the address and data are but keep...
	 data: writedata_w, // ...consistent with next rule to simplify implementation
	 arbiterlock: arbiterlock_w,
	 byteenable: byteenable_w});
   endrule
   
   // if this is a new Avalon slave bus request then enqueue
   // note: if outbuf FIFO is full, Avalon slave forced to wait
   rule hanlde_bus_requests ((read_w || write_w) && !ignore_further_requests);
      outbuf.enq(MemAccessPacketT{
	 rw: read_w ? MemRead : MemWrite,
	 addr: address_w,
	 data: writedata_w, // N.B. "data" is undefined for reads
	 arbiterlock: arbiterlock_w,
	 byteenable: byteenable_w});
      ignore_further_requests <= read_w;
      // release avalonwait for writes since the request has been enqueued
      if(write_w) avalonwait_end_write.send;
   endrule
   
   // once avalonwait has gone low, get ready to respond to next request
   // from the Avalon bus
   rule cancel_ingore_further_requests(!avalonwait && ignore_further_requests);
      ignore_further_requests <= False;
   endrule
   
   // Avalon slave interface - just wiring
   interface AvalonSlaveIfc avs;
      method Action s0(UInt#(word_address_width) address, UInt#(data_width) writedata, Bit#(TDiv#(data_width, 8)) byteenable,
		    Bool write, Bool read, Bool arbiterlock);
	 address_w     <= address;
	 writedata_w   <= writedata;
	 write_w       <= write;
	 read_w        <= read;
	 arbiterlock_w <= arbiterlock;
//	 resetrequest_w <= resetrequest;
	 byteenable_w <= byteenable;
      endmethod
      
      method s0_readdata;
	 return datareturned;
      endmethod
      
      method s0_waitrequest; 
	 return avalonwait;
      endmethod
      
   endinterface

   // client interface   
   interface Client client;
      interface request = toGet(outbuf);
      
      interface Put response;
	 method Action put(d);
	    // note: respond to data read
	    // currently if d is Invalid then ignored but it could be used
	    // to do a avalonwait_end_write.send if it was required the
	    // clients waited on writes until the writes had completed
	    if(isValid(d))
	       begin
		  // note duality of DWire for data and PulseWire for
		  //  associated signal
		  datareturned <= fromMaybe(0,d);
		  avalonwait_end_read.send;
	       end
	 endmethod
      endinterface
   endinterface

//   method Bool reset_from_bus;
//      return resetrequest_w;
//   endmethod
endmodule

/*****************************************************************************
   Avalon slave interface to Bluepsec Client interface, with burst additions
   ===================================================
   Simon Moore, September 2009 Paul Fox, January 2010
 *****************************************************************************/


// Avalon Slave Interface
// notes:
//  - all methods are ready and enabled
//  - names are chosen to match what SOPC builder expects for variable names
//    in the Verilog code - don't change!
(* always_ready, always_enabled *)
interface BurstAvalonSlaveIfc#(numeric type word_address_width, numeric type data_width, numeric type burst_length);
   method Action s0(UInt#(word_address_width) address, UInt#(data_width) writedata,
		    Bool write, Bool read, Bool arbiterlock, Bit#(TDiv#(data_width, 8)) byteenable, UInt#(TAdd#(TLog#(burst_length), 1)) burstcount); //, Bool resetrequest);
   method UInt#(data_width) s0_readdata;
   method Bool s0_waitrequest;
   method Bool s0_readdatavalid;
endinterface


interface BurstAvalonSlave2ClientIfc#(numeric type word_address_width, numeric type data_width, numeric type burst_length);
   interface BurstAvalonSlaveIfc#(word_address_width, data_width, burst_length) avs;
   interface Client#(BurstMemAccessPacketT#(word_address_width, data_width, burst_length), Maybe#(UInt#(data_width))) client;
//(* always_read, always_enabled *)  method Bool reset_from_bus;
endinterface


module mkBurstAvalonSlave2Client(BurstAvalonSlave2ClientIfc#(word_address_width, data_width, burst_length))
   provisos(Max#(word_address_width,31,31));

   // bypass wires for incoming Avalon slave signals
   Wire#(UInt#(word_address_width)) address_w   <- mkBypassWire;
   Wire#(UInt#(data_width)) writedata_w          <- mkBypassWire;
   Wire#(Bool)        read_w               <- mkBypassWire;
   Wire#(Bool)        write_w              <- mkBypassWire;
   Wire#(Bool)        arbiterlock_w        <- mkBypassWire;
   Wire#(Bit#(TDiv#(data_width, 8)))        byteenable_w        <- mkBypassWire;
   Reg# (Bool)        prev_arbiterlock     <- mkReg(False);
//   Wire#(Bool)        resetrequest_w       <- mkBypassWire;
   Reg#(UInt#(TAdd#(TLog#(burst_length), 1))) burstcount_w <- mkBypassWire;
   (* keep *)
   Wire#(UInt#(8)) bufferCount <- mkWire;
   
   // bypass wire for Avalon wait signal + pulsewires to clear
   Wire#(Bool)        avalonwait           <- mkBypassWire;

   // DWire for read data returned to Avalon slave bus
   Wire#(UInt#(data_width)) datareturned <- mkDWire(0);
   Wire#(Bool) readdatavalid <- mkDWire(False);

   // reg indicating that the Avalon request is being processed and further
   // requests should be ignored until the avalonwait signal has been released
   // (gone low)
   Reg#(Bool) ignore_further_requests <- mkReg(False);

   // FIFO holding requests received from Avalon slave bus sent out via
   // the client request interface
   FIFOF#(BurstMemAccessPacketT#(word_address_width, data_width, burst_length)) outbuf <- mkSizedFIFOF(128);
   
   // Burst related
   Reg#(Bool) readBurstInProgress <- mkReg(False);
   Reg#(Bool) writeBurstInProgress <- mkReg(False);
   //Reg#(UInt#(TAdd#(TLog#(burst_length), 1))) readBurstCount <- mkReg(0);
   Reg#(UInt#(TAdd#(TLog#(burst_length), 1))) writeBurstCount <- mkReg(0);
   //Reg#(UInt#(word_address_width)) readBurstAddress <- mkReg(0);
   Reg#(UInt#(word_address_width)) writeBurstAddress <- mkReg(0);
   PulseWire readRequested <- mkPulseWire;
   PulseWire writeRequested <- mkPulseWire;
   FIFO#(UInt#(data_width)) returnBuffer <- mkBypassFIFO;
   
   
   rule start_read_burst(read_w && !readBurstInProgress && burstcount_w != 0);  
   	//$display("start read burst");
   	readBurstInProgress <= True;
   	readRequested.send;
   endrule
   
   rule start_write_burst(write_w && !writeBurstInProgress && burstcount_w != 0);
      	writeBurstCount <= burstcount_w;
      	writeBurstAddress <= address_w;
      	writeBurstInProgress <= True;
      	writeRequested.send;
   endrule
   
   // provide the avalonwait signal
   // note: this must appear within the same clock cycle that a read or write
   //       is initiated
   (* no_implicit_conditions *)
   rule wire_up_avalonwait;
      avalonwait <= (read_w && !readBurstInProgress) || (write_w && !writeBurstInProgress) || !outbuf.notFull;// || readBurstCount > 1;
   endrule
   
   // if this is a new Avalon slave bus request then enqueue
   // note: if outbuf FIFO is full, Avalon slave forced to wait
   
   (* descending_urgency = "handle_read_requests, handle_write_requests" *)
   rule handle_read_requests(readRequested /*&& outbuf.notFull*/);
   	// Address and count for next time
   	//$display("handle read requests");
      outbuf.enq(BurstMemAccessPacketT{
	 rw: MemRead,
	 addr: address_w,
	 data: ?,
	 byteenable: byteenable_w,
	 burstcount: burstcount_w});
   endrule
   
   rule handle_write_requests ((writeBurstInProgress || writeRequested) && write_w && outbuf.notFull );
      	// Address and count for next time
      	if (writeBurstInProgress) begin
      		writeBurstCount <= writeBurstCount - 1;
      		writeBurstAddress <= writeBurstAddress + 1;
      		writeBurstInProgress <= (writeBurstCount>1)? True : False;
      	end
         outbuf.enq(BurstMemAccessPacketT{
   	 rw: MemWrite,
   	 addr: writeBurstAddress,
   	 data: writedata_w, // N.B. "data" is undefined for reads
   	 byteenable: byteenable_w,
   	 burstcount: 1});
         //ignore_further_requests <= read_w;
         // release avalonwait for writes since the request has been enqueued
         
   endrule
   
   rule doResponse;
   	datareturned <= returnBuffer.first;
   	returnBuffer.deq;
   	readdatavalid <= True;
   endrule
   
    // Avalon slave interface - just wiring
   interface BurstAvalonSlaveIfc avs;
      method Action s0(address, writedata, write, read, arbiterlock, byteenable, burstcount); //, resetrequest);
	 address_w     <= address;
	 writedata_w   <= writedata;
	 write_w       <= write;
	 read_w        <= read;
	 arbiterlock_w <= arbiterlock;
	 byteenable_w <= byteenable;
//	 resetrequest_w <= resetrequest;
	burstcount_w <= burstcount;
      endmethod
      
      method s0_readdata;
	 return datareturned;
      endmethod
      
      method s0_waitrequest;
	 return avalonwait;
      endmethod
      
      method s0_readdatavalid;
      	return readdatavalid;
      endmethod
      
   endinterface

   // client interface   
   interface Client client;
      interface request = toGet(outbuf);
      
      interface Put response;
	 method Action put(d); 
	    // note: respond to data read
	    // currently if d is Invalid then ignored but it could be used
	    // to do a avalonwait_end_write.send if it was required the
	    // clients waited on writes until the writes had completed
	    if(isValid(d))
	       begin
		  // note duality of DWire for data and PulseWire for
		  //  associated signal
		  returnBuffer.enq(fromMaybe(0,d));
	       end
	 endmethod
      endinterface
   endinterface

//   method Bool reset_from_bus;
//      return resetrequest_w;
//   endmethod
endmodule

/*****************************************************************************
   Bluespec Server interface to Avalon master interface
   ====================================================
   Simon Moore, October 2009
 *****************************************************************************/


// Avalon Master Interface
// notes:
//  - all methods are ready and enabled
//  - names are chosen to match what SOPC builder expects for variable names
//    in the Verilog code - don't change!
//  - initally a long latency (too much buffering?) but (hopfully) robust
//    design remove some latch stages in the future

(* always_ready, always_enabled *)
interface AvalonMasterIfc#(numeric type word_address_width, numeric type data_width);
   method Action m0(UInt#(data_width) readdata, Bool waitrequest);
   method UInt#(data_width) m0_writedata;
   method UInt#(TAdd#(2,word_address_width)) m0_address;
   method Bool m0_read;
   method Bool m0_write;
   method Bool m0_arbiterlock;
endinterface


interface Server2AvalonMasterIfc#(numeric type word_address_width, numeric type data_width);
   interface AvalonMasterIfc#(word_address_width, data_width) avm;
   interface Server#(MemAccessPacketT#(word_address_width, data_width),Maybe#(UInt#(data_width))) server;
endinterface


module mkServer2AvalonMaster(Server2AvalonMasterIfc#(word_address_width, data_width))
   provisos(//Max#(word_address_width,31,31),
	    Add#(word_address_width, 2, TAdd#(2, word_address_width)));
   // bypass wires for incoming Avalon master signals
   // N.B. avalon master address is a byte address, so need to add 2 bits
   Reg#(UInt#(word_address_width))  address_r       <- mkReg(0);
   Reg#(UInt#(data_width))  writedata_r     <- mkReg(0);
   Reg#(Bool)         read_r          <- mkReg(False);
   Reg#(Bool)         write_r         <- mkReg(False);
   Reg#(Bool)         arbiterlock_r   <- mkReg(False);
   PulseWire          signal_read     <- mkPulseWire;
   PulseWire          signal_write    <- mkPulseWire;
   Wire#(Bool)        avalonwait      <- mkBypassWire;
   Wire#(UInt#(data_width)) avalonreaddata  <- mkBypassWire;
   
   // buffer data returned
   // TODO: could this buffer be removed by not initiating the transaction
   // until the returndata get operation was active, then do the memory 
   // transaction and return the value to the get without buffering?
   //  - possibly not if the interface is fully pipelined because there
   //    can be several transactions ongoing (several addresses issued, etc.)
   //    before data comes back
   
   // FIFO of length 4 which is:
   // Unguarded enq since it it guarded by the bus transaction initiation
   // Guarded deq
   // Unguarded count so isLessThan will not block
   FIFOLevelIfc#(Maybe#(UInt#(data_width)),4) datareturnbuf <- mkGFIFOLevel(True,False,True);
   FIFO#(MemAccessT) pending_acks <- mkFIFO;
   
   let write_ack = write_r && !read_r && !avalonwait;
   let read_ack  = !write_r && read_r && !avalonwait;
   
   rule buffer_data_read (read_ack && (pending_acks.first==MemRead));
      datareturnbuf.enq(tagged Valid avalonreaddata);
      $display("   %05t: Avalon2ClientServer returning data",$time);
      pending_acks.deq;
   endrule
   
   rule signal_data_write (write_ack && (pending_acks.first==MemWrite));
      datareturnbuf.enq(tagged Invalid); // signal write has happened
      pending_acks.deq;
   endrule

   rule signal_mem_null (pending_acks.first==MemNull);
      datareturnbuf.enq(tagged Invalid); // signal null has happened
      pending_acks.deq;
   endrule

   (* no_implicit_conditions *)
   rule do_read_reg;
      if(signal_read) read_r <= True;
      else if(!avalonwait) read_r <= False;
   endrule
   
   (* no_implicit_conditions *)
   rule do_write_reg;
      if(signal_write) write_r <= True;
      else if(!avalonwait) write_r <= False;
   endrule
   
   // Avalon master interface - just wiring
   interface AvalonMasterIfc avm;
      method Action m0(readdata, waitrequest);
	 avalonreaddata <= readdata;
	 avalonwait <= waitrequest;
      endmethod
      
      method m0_writedata;   return writedata_r;    endmethod
      method m0_address;     return unpack({pack(address_r),2'b00});   endmethod
      method m0_read;        return read_r;         endmethod
      method m0_write;       return write_r;        endmethod
      method m0_arbiterlock; return arbiterlock_r;  endmethod
   endinterface

   // server interface   
   interface Server server;
      interface response = toGet(datareturnbuf);
      
      interface Put request;
	 method Action put(packet) if (!avalonwait && datareturnbuf.isLessThan(2));
	    address_r     <= packet.addr;
	    writedata_r   <= packet.data;
	    arbiterlock_r <= packet.arbiterlock;
	    pending_acks.enq(packet.rw);
	    case(packet.rw)
	       MemRead:  signal_read.send();
	       MemWrite: signal_write.send();
	    endcase
	 endmethod
      endinterface
   endinterface

endmodule

/*****************************************************************************
   Bluespec Server interface to Avalon master interface, Burst version
   ====================================================
   Simon Moore, October 2009 Paul Fox, January 2010
 *****************************************************************************/


// Avalon Master Interface
// notes:
//  - all methods are ready and enabled
//  - names are chosen to match what SOPC builder expects for variable names
//    in the Verilog code - don't change!
//  - initally a long latency (too much buffering?) but (hopfully) robust
//    design remove some latch stages in the future

(* always_ready, always_enabled *)
interface BurstAvalonMasterIfc#(numeric type word_address_width, numeric type data_width, numeric type burst_length);
   method Action m0(UInt#(data_width) readdata, Bool waitrequest, Bool readdatavalid);
   method UInt#(data_width) m0_writedata;
   method UInt#(TAdd#(2,word_address_width)) m0_address;
   method Bool m0_read;
   method Bool m0_write;
   method UInt#(TAdd#(TLog#(burst_length), 1)) m0_burstcount;
   method Bit#(TDiv#(data_width, 8)) m0_byteenable;
endinterface


interface BurstServer2AvalonMasterIfc#(numeric type word_address_width, numeric type data_width, numeric type burst_length);
   interface BurstAvalonMasterIfc#(word_address_width, data_width, burst_length) avm;
   interface Server#(BurstMemAccessPacketT#(word_address_width, data_width, burst_length),Maybe#(UInt#(data_width))) server;
endinterface


module mkBurstServer2AvalonMaster(BurstServer2AvalonMasterIfc#(word_address_width, data_width, burst_length))
   provisos(Max#(word_address_width,31,31),
	    Add#(word_address_width, 2, TAdd#(2, word_address_width)),
	    Add#(b__, TAdd#(TLog#(burst_length), 1), 32)
   );
   // bypass wires for incoming Avalon master signals
   // N.B. avalon master address is a byte address, so need to add 2 bits
   Reg#(UInt#(word_address_width))  address_r       <- mkReg(0);
   Reg#(UInt#(data_width))  writedata_r     <- mkReg(0);
   Reg#(Bool)         read_r          <- mkReg(False);
   Reg#(Bool)         write_r         <- mkReg(False);
   Reg#(UInt#(TAdd#(TLog#(burst_length), 1))) burstcount_r <- mkReg(0);
   Reg#(Bit#(TDiv#(data_width, 8))) byteenable_r <- mkReg(0);
   PulseWire          signal_read     <- mkPulseWire;
   PulseWire          signal_write    <- mkPulseWire;
   PulseWire          signal_write_done    <- mkPulseWire;
   Wire#(Bool)        avalonwait      <- mkBypassWire;
   Wire#(Bool)	      avalonreaddatavalid <- mkBypassWire;
   Wire#(UInt#(data_width)) avalonreaddata  <- mkBypassWire;

   FIFO#(BurstMemAccessPacketT#(word_address_width, data_width, burst_length)) requestFIFO <- mkLFIFO;
   
   // buffer data returned
   // TODO: could this buffer be removed by not initiating the transaction
   // until the returndata get operation was active, then do the memory 
   // transaction and return the value to the get without buffering?
   //  - possibly not if the interface is fully pipelined because there
   //    can be several transactions ongoing (several addresses issued, etc.)
   //    before data comes backextend
   
   // FIFO of length 4 which is:
   // Unguarded enq since it it guarded by the bus transaction initiation
   // Guarded deq
   // Unguarded count so isLessThan will not block
   FIFOLevelIfc#(Maybe#(UInt#(data_width)),8) datareturnbuf <- mkGFIFOLevel(True,False,True);
   //FIFO#(MemAccessT) pending_acks <- mkFIFO;
   Reg#(UInt#(32)) outstandingReads <- mkReg(0);
   PulseWire outstandingReadsDecrement <- mkPulseWire;
   RWire#(UInt#(TAdd#(TLog#(burst_length), 1))) outstandingReadsIncrement <- mkRWire;
   
   rule outstanding_increment(isValid(outstandingReadsIncrement.wget));
	outstandingReads <= outstandingReads + extend(fromMaybe(0, outstandingReadsIncrement.wget));
   endrule

   rule outstanding_decrement(outstandingReadsDecrement);
	outstandingReads <= outstandingReads - 1;
   endrule

   (* preempts = "outstanding_both, outstanding_decrement" *)
   (* preempts = "outstanding_both, outstanding_increment" *)
   rule outstanding_both(outstandingReadsDecrement && isValid(outstandingReadsIncrement.wget));
	outstandingReads <= outstandingReads + (extend(fromMaybe(0, outstandingReadsIncrement.wget)) - 1);
   endrule

   
   rule buffer_data_read (avalonreaddatavalid && outstandingReads > 0);
      datareturnbuf.enq(tagged Valid avalonreaddata);
      outstandingReadsDecrement.send;
   endrule
   
   (* no_implicit_conditions *)
   rule do_read_reg;
      if(signal_read) read_r <= True;
      else if(!avalonwait) read_r <= False;
   endrule
   
   (* no_implicit_conditions *)
   rule do_write_reg;
      if(signal_write) begin 
          write_r <= True;
      end
      else if(!avalonwait) begin 
	write_r <= False;
        if (write_r) begin
		signal_write_done.send;	
        end
      end
   endrule

   let packet = requestFIFO.first;

   rule handle_request_read (!avalonwait && datareturnbuf.isLessThan(2) && packet.rw == MemRead && outstandingReads < 16); 
            requestFIFO.deq;
	    address_r     <= packet.addr;
	    writedata_r   <= packet.data;
	    byteenable_r <= packet.byteenable;
	    burstcount_r <= packet.burstcount;
	    signal_read.send;
	    outstandingReadsIncrement.wset(packet.burstcount);
   endrule

   rule handle_request_write_start (!avalonwait && packet.rw == MemWrite); 
            requestFIFO.deq;
	    address_r     <= packet.addr;
	    writedata_r   <= packet.data;
	    byteenable_r <= packet.byteenable;
	    burstcount_r <= packet.burstcount;
	    signal_write.send;
   endrule

   rule handle_request_discard (packet.rw != MemRead && packet.rw != MemWrite); 
            requestFIFO.deq;
   endrule
   
   // Avalon master interface - just wiring
   interface BurstAvalonMasterIfc avm;
      method Action m0(readdata, waitrequest, readdatavalid);
	 avalonreaddata <= readdata;
	 avalonwait <= waitrequest;
	 avalonreaddatavalid <= readdatavalid;
      endmethod
      
      method m0_writedata;   return writedata_r;    endmethod
      method m0_address;     return unpack({pack(address_r),2'b00});   endmethod
      method m0_read;        return read_r;         endmethod
      method m0_write;       return write_r;        endmethod
      method m0_byteenable; return byteenable_r; endmethod
      method m0_burstcount; return burstcount_r; endmethod
   endinterface

   // server interface   
   interface server = Server{request: toPut(requestFIFO), response: toGet(datareturnbuf)};
endmodule



/*****************************************************************************
   Bluespec Server interface to Avalon master PIPELINED interface, burst version
   ==============================================================
   Simon Moore, October 2009 Paul Fox, January 2010
 *****************************************************************************/


// Avalon Master Interface - pipelined version
//  - partially working - really need "flush" signal
// notes:
//  - all methods are ready and enabled
//  - names are chosen to match what SOPC builder expects for variable names
//    in the Verilog code - don't change!
//  - initally a long latency (too much buffering?) but (hopfully) robust
//    design remove some latch stages in the future

(* always_ready, always_enabled *)
interface BurstAvalonPipelinedMasterIfc#(numeric type word_address_width, numeric type data_width);
   method Action m0(UInt#(data_width) readdata, Bool readdatavalid, Bool waitrequest);
   method UInt#(data_width) m0_writedata;
   method UInt#(TAdd#(2,word_address_width)) m0_address;
   method Bool m0_read;
   method Bool m0_write;
endinterface


interface BurstServer2AvalonPipelinedMasterIfc#(numeric type word_address_width, numeric type data_width, numeric type burst_length);
   interface BurstAvalonPipelinedMasterIfc#(word_address_width, data_width) avm;
   interface Server#(BurstMemAccessPacketT#(word_address_width, data_width, burst_length),Maybe#(UInt#(data_width))) server;
endinterface


module mkBurstServer2AvalonPipelinedMaster(BurstServer2AvalonPipelinedMasterIfc#(word_address_width, data_width, burst_length))
   provisos(Max#(word_address_width,31,31),
	    Add#(word_address_width, 2, TAdd#(2, word_address_width)));
   // bypass wires for incoming Avalon master signals
   // N.B. avalon master address is a byte address, so need to add 2 bits
   Reg#(UInt#(word_address_width))  address_r       <- mkReg(0);
   Reg#(UInt#(data_width))  writedata_r     <- mkReg(0);
   Reg#(Bool)         read_r          <- mkReg(False);
   Reg#(Bool)         write_r         <- mkReg(False);
   PulseWire          signal_read     <- mkPulseWire;
   PulseWire          signal_write    <- mkPulseWire;
   Wire#(Bool)        avalonwait      <- mkBypassWire;
   Wire#(Bool)        avalonreadvalid <- mkBypassWire;
   Wire#(UInt#(data_width)) avalonreaddata  <- mkBypassWire;
   
   // buffer data returned
   // TODO: could this buffer be removed by not initiating the transaction
   // until the returndata get operation was active, then do the memory 
   // transaction and return the value to the get without buffering?
   //  - possibly not if the interface is fully pipelined because there
   //    can be several transactions ongoing (several addresses issued, etc.)
   //    before data comes back
   
   // FIFO of length 4 which is:
   // Unguarded enq since it it guarded by the bus transaction initiation
   // Guarded deq
   // Unguarded count so isLessThan will not block
   FIFOLevelIfc#(Maybe#(UInt#(data_width)),4) datareturnbuf <- mkGFIFOLevel(True,False,True);
   FIFO#(MemAccessT) pending_acks <- mkSizedFIFO(4);
   FIFO#(MemAccessT) pending_write_acks <- mkSizedFIFO(4);
   
   let write_ack = write_r && !read_r && !avalonwait;
   
   rule buffer_data_read (avalonreadvalid && (pending_acks.first==MemRead));
      datareturnbuf.enq(tagged Valid avalonreaddata);
      $display("   %05t: Avalon2ClientServer returning data",$time);
      pending_acks.deq;
   endrule
   
   rule data_read_error (avalonreadvalid && (pending_acks.first!=MemRead));
      $display("ERROR: Server2AvalonPipelinedMaster - read returned when expeting a write or null ack");
   endrule
   
   rule buffer_data_write_during_readvalid (avalonreadvalid && write_ack);
      pending_write_acks.enq(MemWrite);
   endrule
   
   rule signal_data_write (!avalonreadvalid && write_ack && (pending_acks.first==MemWrite));
      datareturnbuf.enq(tagged Invalid); // signal write has happened
      pending_acks.deq;
   endrule

   rule signal_mem_null (pending_acks.first==MemNull);
      datareturnbuf.enq(tagged Invalid); // signal null has happened
      pending_acks.deq;
   endrule

   rule resolve_pending_write_acks (!avalonreadvalid && !write_ack && (pending_acks.first==MemWrite));
      pending_write_acks.deq; // N.B. only fires if this dequeue can happen
      datareturnbuf.enq(tagged Invalid);
      pending_acks.deq;
   endrule
   
   (* no_implicit_conditions *)
   rule do_read_reg;
      if(signal_read) read_r <= True;
      else if(!avalonwait) read_r <= False;
   endrule
   
   (* no_implicit_conditions *)
   rule do_write_reg;
      if(signal_write) write_r <= True;
      else if(!avalonwait) write_r <= False;
   endrule
   
   // Avalon master interface - just wiring
   interface BurstAvalonPipelinedMasterIfc avm;
      method Action m0(readdata, readdatavalid, waitrequest);
	 avalonreaddata <= readdata;
	 avalonreadvalid <= readdatavalid;
	 avalonwait <= waitrequest;
      endmethod
      
      method m0_writedata;   return writedata_r;    endmethod
      method m0_address;     return unpack({pack(address_r),2'b00});   endmethod
      method m0_read;        return read_r;         endmethod
      method m0_write;       return write_r;        endmethod
   endinterface

   // server interface   
   interface Server server;
      interface response = toGet(datareturnbuf);
      
      interface Put request;
	 method Action put(packet) if (!avalonwait && datareturnbuf.isLessThan(2));
	    address_r     <= packet.addr;
	    writedata_r   <= packet.data;
	    pending_acks.enq(packet.rw);
	    case(packet.rw)
	       MemRead:  signal_read.send();
	       MemWrite: signal_write.send();
	    endcase
	 endmethod
      endinterface
   endinterface

endmodule



/*****************************************************************************
 Avalon Bridge
 N.B. as usual the names on interfaces are chosen to match what SOPC
 builder expects, so don't change!
 ****************************************************************************/

interface AvalonBridgeIfc#(numeric type word_address_width, numeric type data_width);
   interface AvalonSlaveIfc#(word_address_width, data_width) avs;
   interface AvalonMasterIfc#(word_address_width, data_width) avm;
endinterface
   

module mkAvalonBridge(AvalonBridgeIfc#(word_address_width, data_width))
   provisos(Max#(word_address_width,31,31),
	    Add#(master_data_width, 0, slave_data_width));

   AvalonSlave2ClientIfc#(word_address_width, data_width) client <- mkAvalonSlave2Client;
   Server2AvalonMasterIfc#(word_address_width, data_width) server <- mkServer2AvalonMaster;
   
   //mkConnection(client.client,server.server);
   
   interface avs = client.avs;
   interface avm = server.avm;
endmodule		

module mkBurstTest(Empty);
	BurstAvalonSlave2ClientIfc#(28, 32, 1) client <- mkBurstAvalonSlave2Client;
	Reg#(UInt#(28)) addressInput <- mkReg(0);
	Reg#(UInt#(32)) dataInput <- mkReg(0);
	Reg#(Bool) writeEnableInput <- mkReg(False);
	Reg#(Bool) readEnableInput <- mkReg(False);
	Reg#(Bool) arbiterLockInput <- mkReg(False);
	Reg#(Bit#(4)) byteEnableInput <- mkReg(4'b0000);
	Reg#(UInt#(4)) burstCountInput <- mkReg(0);
	
	Stmt testSeq = (seq
		// Burst read of 3 items
		(par
			writeEnableInput <= False;
			readEnableInput <= True;
			addressInput <= 128;
			burstCountInput <= 3;
			byteEnableInput <= 4'b1111;
			
		endpar);
		(par
			writeEnableInput <= False;
			readEnableInput <= False;
			addressInput <= 0;
			burstCountInput <= 0;
			byteEnableInput <= 4'b0000;
			dataInput <= 0;
		endpar);
		noAction;
		noAction;
		noAction;
		noAction;
		(par
			writeEnableInput <= True;
			readEnableInput <= False;
			addressInput <= 128;
			burstCountInput <= 1;
			byteEnableInput <= 4'b1111;
			dataInput <= 1234;

		endpar);
		(par
			writeEnableInput <= False;
			readEnableInput <= False;
			addressInput <= 0;
			burstCountInput <= 0;
			byteEnableInput <= 4'b0000;
			dataInput <= 0;
		endpar);
		
		noAction;
		noAction;
		noAction;
		noAction;

		$finish(0);
	endseq);

	FSM test <- mkFSM(testSeq);
	Reg#(Bool) running <- mkReg(False);

	rule createReply;
		let req <- client.client.request.get;
		Maybe#(UInt#(32)) reply = tagged Invalid;
		if (req.rw == MemRead) begin
			reply = tagged Valid 789;
		end
		client.client.response.put(reply);
	endrule
	
	rule presentInput;
		client.avs.s0(addressInput, dataInput, writeEnableInput, readEnableInput, arbiterLockInput, 4'hF, 1);	
	endrule
	
	rule displayOutput;
		$display("readData: %0d waitRequest: %0d", client.avs.s0_readdata, client.avs.s0_waitrequest);
		
	endrule
	
	rule start (!running);
		running <= True;
		test.start;
	endrule	
endmodule : mkBurstTest


endpackage

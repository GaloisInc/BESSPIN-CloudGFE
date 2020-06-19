package AXI4_ClockCrossing;

import Clocks ::*;
import SourceSink ::*;
import AXI4_Types ::*;
import Connectable ::*;

instance ToSource#(SyncFIFOIfc#(t), t);
  function toSource (ff) = interface Source#(t);
    method canPeek = ff.notEmpty;
    method peek    = ff.first;
    method drop    = ff.deq;
  endinterface;
endinstance

instance ToSink#(SyncFIFOIfc#(t), t);
  function toSink (ff) = interface Sink;
    method canPut = ff.notFull;
    method put    = ff.enq;
  endinterface;
endinstance

module mkAXI4_ClockCrossing #(Clock master_clock,
			      Reset master_reset,
			      Clock slave_clock,
			      Reset slave_reset)
		       (AXI4_Shim #(id_, addr_, data_, awu_,wu_,bu_,aru_,ru_));

   SyncFIFOIfc #(AXI4_AWFlit #(id_, addr_, awu_)) f_aw <- mkSyncFIFO (4, master_clock, master_reset,  slave_clock);
   SyncFIFOIfc #(AXI4_WFlit  #(data_, wu_))       f_w  <- mkSyncFIFO (4, master_clock, master_reset,  slave_clock);
   SyncFIFOIfc #(AXI4_BFlit  #(id_, bu_))         f_b  <- mkSyncFIFO (4,  slave_clock,  slave_reset, master_clock);

   SyncFIFOIfc #(AXI4_ARFlit #(id_, addr_, aru_)) f_ar <- mkSyncFIFO (4, master_clock, master_reset,  slave_clock);
   SyncFIFOIfc #(AXI4_RFlit  #(id_, data_, ru_))  f_r  <- mkSyncFIFO (4,  slave_clock,  slave_reset, master_clock);


   interface AXI4_Slave slave;
      interface aw = toSink  (f_aw);
      interface w  = toSink  (f_w);
      interface b  = toSource(f_b);
      interface ar = toSink  (f_ar);
      interface r  = toSource(f_r);
   endinterface

   interface AXI4_Master master;
      interface aw = toSource(f_aw);
      interface w  = toSource(f_w);
      interface b  = toSink  (f_b);
      interface ar = toSource(f_ar);
      interface r  = toSink  (f_r);
   endinterface
endmodule

module mkAXI4_ClockCrossingToCC #(Clock master_clock, Reset master_reset)
			   (AXI4_Shim #(id_, addr_, data_, awu_,wu_,bu_,aru_,ru_));
   let slave_clock <- exposeCurrentClock;
   let slave_reset <- exposeCurrentReset;
   let crossing <- mkAXI4_ClockCrossing (master_clock, master_reset, slave_clock, slave_reset);

   return crossing;
endmodule


endpackage

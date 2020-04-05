import DefaultValue::*;
import GetPut::*;
import SceMi::*;

import FourCycle::*;
import ResetXactor::*;
import Types::*;

(* synthesize *)
module [Module] mkAGCWrapper (AGC);
    let m <- mkAGC();
    return m;
endmodule

// Main SceMi harness
module [SceMiModule] mkSceMiHarness();

    SceMiClockConfiguration conf = defaultValue;

    SceMiClockPortIfc clkPort <- mkSceMiClockPort(conf);
    AGC dut <- buildDutWithSoftReset(mkAGCWrapper, clkPort);

    Empty ioAGCToHost <- mkGetXactor(toGet(dut.hostIO.hostIO.agcToHost), clkPort);
    Empty ioHostToAGC <- mkPutXactor(toPut(dut.hostIO.hostIO.hostToAGC), clkPort);
    Empty ioInit <- mkPutXactor(toPut(dut.hostIO.init), clkPort);
    Empty start <- mkPutXactor(toPut(dut.start), clkPort);
    Empty memInit <- mkPutXactor(dut.memInit.request, clkPort);

    Empty shutdown <- mkShutdownXactor();
endmodule

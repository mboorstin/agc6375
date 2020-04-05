// A lot of this is VERY liberally copied from 6.375's RISCV test harness

import DefaultValue::*;
import GetPut::*;
import SceMi::*;

import FourCycle::*;
import ResetXactor::*;
import Types::*;

typedef AGC DutInterface;

(* synthesize *)
module [Module] mkDutWrapper (DutInterface);
    let m <- mkAGC();
    return m;
endmodule

module [SceMiModule] mkSceMiHarness();

    SceMiClockConfiguration conf = defaultValue;

    SceMiClockPortIfc clkPort <- mkSceMiClockPort(conf);
    DutInterface dut <- buildDutWithSoftReset(mkDutWrapper, clkPort);

    Empty ioAGCToHost <- mkGetXactor(toGet(dut.hostIO.hostIO.agcToHost), clkPort);
    Empty ioHostToAGC <- mkPutXactor(toPut(dut.hostIO.hostIO.hostToAGC), clkPort);
    Empty ioInit <- mkPutXactor(toPut(dut.hostIO.init), clkPort);
    Empty start <- mkPutXactor(toPut(dut.start), clkPort);
    Empty memInit <- mkPutXactor(dut.memInit.request, clkPort);

    Empty shutdown <- mkShutdownXactor();
endmodule


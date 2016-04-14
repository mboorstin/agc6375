// A lot of this is VERY liberally copied from 6.375's RISCV test harness

import DefaultValue::*;
import GetPut::*;
import SceMi::*;

import Types::*;
import ResetXactor::*;

// Where to find mkAGC
// AGC_FILE is defined differently for each scemi build target
import `AGC_FILE::*;

typedef AGC DutInterface;

(* synthesize *)
module [Module] mkDutWrapper (DutInterface);
    let m <- mkAGC();
    return m;
endmodule

module [SceMiModule] mkSceMiLayer();

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


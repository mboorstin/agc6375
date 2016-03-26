import AGCMemory::*;
import InterStage::*;
import TopLevelIfaces::*;
import Types::*;

(* synthesize *)
module mkAGC(AGC);
    AGCMemory memory <- mkAGCMemory();


    method ActionValue#(IOPacket) ioAGCToHost;
        return ?;
    endmethod

    method Action ioHostToAGC(IOPacket packet);

    endmethod

    // Should probably slap some guards on this (memory.isInit?)
    method Action start(Addr startZ);
        $display("Start received with address %x", startZ);
    endmethod

    interface MemInitIfc memInit = memory.init;
endmodule

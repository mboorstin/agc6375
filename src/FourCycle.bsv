import AGCMemory::*;
import InterStage::*;
import TopLevelIfaces::*;
import Types::*;

(* synthesize *)
module mkAGC(AGC);
    AGCMemory memory <- mkAGCMemory();
    Reg#(Bool) started <- mkReg(False);

    // Should dequeue from a FIFO of requests or something like that
    // For now, guarding so that it doesn't constantly run
    method ActionValue#(IOPacket) ioAGCToHost if (False);
        return ?;
    endmethod

    method Action ioHostToAGC(IOPacket packet) if (started);

    endmethod

    method Action start(Addr startZ) if (memory.init.done);
        started <= True;
    endmethod

    interface MemInitIfc memInit = memory.init;
endmodule

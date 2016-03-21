import AGCMemory::*;
import MemTypes::*;
import Types::*;

(*synthesize*)

module mkAGCMemoryTester(Empty);
    AGCMemory memory <- mkAGCMemory();

    rule runTest;
        $display("Hello, world!");
        $finish();
    endrule

endmodule

import GetPut::*;
import InterStage::*;
import Exec::*;
import Types::*;
import Vector::*;
import AGCMemory::*;

(* synthesize *)
module mkExecTest ();
    //state
    Reg#(Bool) started <- mkReg(False);
    Reg#(Bool) memready <- mkReg(False);
    Reg#(Bool) done <- mkReg(False);
    //AGCMemory memory <- mkAGCMemory();

    //test inputs
    Vector#(10, ExecFuncArgs) in = newVector;
    Bit#(16) mem_val = {15'h0240, 1'b0};
    in[0] = ExecFuncArgs{
    	z:12'b0,
        inst:{opAD, 12'h010, 1'b0},
        isExtended:False,
        memResp:tagged Valid mem_val,
        regResp:tagged Valid 16'h0134
    };
    in[1] = ExecFuncArgs{
    	z:12'b0,
        inst:{opADS, qcADS, 10'h010, 1'b0},
        isExtended:False,
        memResp:tagged Valid mem_val,
        regResp:tagged Valid 16'h0154
    };
    /*in[2] = {};
    in[3] = {};
    in[4] = {};
    in[5] = {};
    in[6] = {};
    in[7] = {};
    in[8] = {};
    in[9] = {};*/


    //starting up
    rule init(!started);
        started <= True;
        //memory.init.request.put(tagged InitDone);
    endrule

    rule prepare_memory(started && !memready);
        //
        //memory.storer.regStore(rA, 16'o0000);
        //memory.storer.memStore(12'd0100, 16'o0143);
        memready <= True;
    endrule
    
    rule one_in (memready && !done);
        //send in data
        for (Integer i = 0; i < 2; i = i + 1) begin
            Exec2Writeback result = exec(in[i]);
            $display(fshow(result));
        end
        done <= True;
    endrule

    //all done!
    rule finish(done);
        $finish();
    endrule
    
endmodule


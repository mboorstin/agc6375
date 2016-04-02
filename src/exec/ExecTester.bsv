import FShow::*;
import GetPut::*;
import Vector::*;

import Exec::*;
import InterStage::*;
import Types::*;

typedef 10 NTESTS;

typedef struct {
    ExecFuncArgs args;
    Exec2Writeback expected;
} TestData deriving (Eq, Bits, FShow);

(* synthesize *)
module mkExecTest ();
    Reg#(Bool) done <- mkReg(False);

    Vector#(NTESTS, TestData) in = newVector;
    Bit#(16) memVal = {15'h0240, 1'b0};
    in[0] = TestData{
        args: ExecFuncArgs{
            z:12'b0,
            inst:{opAD, 12'h010, 1'b0},
            isExtended:False,
            memResp:tagged Valid memVal,
            regResp:tagged Valid 16'h0134
        },
        expected: Exec2Writeback {
            eRes1: ?,
            eRes2: ?,
            memAddr: ?,
            regNum: ?,
            newZ: tagged Invalid
        }
    };

    in[1] = TestData{
        args: ExecFuncArgs{
            z:12'b0,
            inst:{opADS, qcADS, 10'h010, 1'b0},
            isExtended:False,
            memResp:tagged Valid memVal,
            regResp:tagged Valid 16'h0154
        },
        expected: Exec2Writeback {
            eRes1: ?,
            eRes2: ?,
            memAddr: ?,
            regNum: ?,
            newZ: tagged Invalid
        }
    };

    in[2] = TestData {
        args: ExecFuncArgs {
            z: 12'b0,
            inst: {opAUG, qcAUG, 10'h80, 1'b0},
            isExtended: True,
            memResp: tagged Valid memVal,
            regResp: tagged Invalid
        },
        expected: Exec2Writeback {
            eRes1: {15'h0241, 1'b0},
            eRes2: 0,
            memAddr: tagged Valid 'h80,
            regNum: tagged Invalid,
            newZ: tagged Invalid
        }
    };

    in[3] = TestData {
        args: ExecFuncArgs {
            z: 12'b0,
            inst: {opBZF, 'O2000, 1'b0},
            isExtended: True,
            memResp: tagged Invalid,
            regResp: tagged Valid 0
        },
        expected: Exec2Writeback {
            eRes1: 0,
            eRes2: 0,
            memAddr: tagged Invalid,
            regNum: tagged Invalid,
            newZ: tagged Valid 'O2000
        }
    };

    in[4] = TestData {
        args: ExecFuncArgs {
            z: 12'b0,
            inst: {opBZMF, 'O2000, 1'b0},
            isExtended: True,
            memResp: tagged Invalid,
            regResp: tagged Valid 'hC000
        },
        expected: Exec2Writeback {
            eRes1: 0,
            eRes2: 0,
            memAddr: tagged Invalid,
            regNum: tagged Invalid,
            newZ: tagged Valid 'O2000
        }
    };

    in[5] = TestData {
        args: ExecFuncArgs {
            z: 12'b0,
            inst: {opCA, 'O2000, 1'b0},
            isExtended: False,
            memResp: tagged Valid 'hBEEE,
            regResp: tagged Invalid
        },
        expected: Exec2Writeback {
            eRes1: 0,
            eRes2: 'hDF77,
            memAddr: tagged Invalid,
            regNum: tagged Valid 0,
            newZ: tagged Invalid
        }
    };

    in[6] = TestData {
        args: ExecFuncArgs {
            z: 12'b0,
            inst: {opCCS, qcCCS, 0, 1'b0},
            isExtended: False,
            memResp: tagged Valid 'h4001,
            regResp: tagged Invalid
        },
        expected: Exec2Writeback {
            eRes1: 0,
            eRes2: 'h4000,
            memAddr: tagged Invalid,
            regNum: tagged Valid 0,
            newZ: tagged Valid 1
        }
    };

    in[7] = TestData {
        args: ExecFuncArgs {
            z: 12'b0,
            inst: {opCCS, qcCCS, 0, 1'b0},
            isExtended: False,
            memResp: tagged Valid 'h4000,
            regResp: tagged Invalid
        },
        expected: Exec2Writeback {
            eRes1: 0,
            eRes2: 'h3FFF,
            memAddr: tagged Invalid,
            regNum: tagged Valid 0,
            newZ: tagged Valid 1
        }
    };

    // Test 15 bits
    in[8] = TestData {
        args: ExecFuncArgs {
            z: 12'b0,
            inst: {opCS, 'O2000, 1'b0},
            isExtended: False,
            memResp: tagged Valid 'hAAAA,
            regResp: tagged Invalid
        },
        expected: Exec2Writeback {
            eRes1: 0,
            eRes2: 'h2AAA,
            memAddr: tagged Invalid,
            regNum: tagged Valid 0,
            newZ: tagged Invalid
        }
    };

    // Test 16 bits
    in[9] = TestData {
        args: ExecFuncArgs {
            z: 12'b0,
            inst: {opCS, 0},
            isExtended: False,
            memResp: tagged Valid 'hAAAA,
            regResp: tagged Invalid
        },
        expected: Exec2Writeback {
            eRes1: 0,
            eRes2: 'h5555,
            memAddr: tagged Invalid,
            regNum: tagged Valid 0,
            newZ: tagged Invalid
        }
    };

    // We're just testing a bunch of combinational logic, so we can
    // do a single massive rule
    rule doTest (!done);
        //send in data
        for (Integer i = 0; i < valueOf(NTESTS); i = i + 1) begin
            Exec2Writeback result = exec(in[i].args);
            if (result != in[i].expected) begin
                $display("Failed on input %d", i);
                $display("Expect: ", fshow(in[i].expected));
                $display("Result: ", fshow(result));
            end else begin
                $display("Passed input %d", i);
            end
        end
        done <= True;
    endrule

    //all done!
    rule finish(done);
        $finish();
    endrule

endmodule


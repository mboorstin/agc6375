
import Vector::*;
import ArithUtil::*;
import Types::*;

(* synthesize *)
module mkArithUtilTest ();
    //state
    Reg#(Bool) started <- mkReg(False);
    Reg#(Bool) done <- mkReg(False);

    //test inputs
    Vector#(10, SP) spin1 = newVector;
    spin1[0] = 15'o00000;
    spin1[1] = 15'o00001;
    spin1[2] = 15'o00001;
    spin1[3] = 15'o00010;
    spin1[4] = 15'o00000;
    spin1[5] = 15'o00000;
    spin1[6] = 15'o00000;
    spin1[7] = 15'o00000;
    spin1[8] = 15'o00000;
    spin1[9] = 15'o00000;

    Vector#(10, SP) spin2 = newVector;
    spin2[0] = 15'o00000;
    spin2[1] = 15'o00001;
    spin2[2] = 15'o77776;
    spin2[3] = 15'o77767;
    spin2[4] = 15'o00000;
    spin2[5] = 15'o00000;
    spin2[6] = 15'o00000;
    spin2[7] = 15'o00000;
    spin2[8] = 15'o00000;
    spin2[9] = 15'o00000;


    //starting up
    rule init(!started);
        started <= True;
    endrule
    
    rule one_in (started && !done);
        //send in data
        for (Integer i = 0; i < 10; i = i + 1) begin
            SP result = subOnes(spin1[i], spin2[i]);
            $display("%b - %b = %b", spin1[i], spin2[i], result);
        end
        done <= True;
    endrule

    //all done!
    rule finish(done);
        $finish();
    endrule
    
endmodule


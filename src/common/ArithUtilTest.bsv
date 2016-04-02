
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
    spin1[4] = 15'o37777;
    spin1[5] = 15'o37776;
    spin1[6] = 15'o37776;
    spin1[7] = 15'o05760;
    spin1[8] = 15'o00010;
    spin1[9] = 15'o70000;

    Vector#(10, SP) spin2 = newVector;
    spin2[0] = 15'o00000;
    spin2[1] = 15'o00001;
    spin2[2] = 15'o77776;
    spin2[3] = 15'o77767;
    spin2[4] = 15'o00001;
    spin2[5] = 15'o00001;
    spin2[6] = 15'o37776;
    spin2[7] = 15'o00001;
    spin2[8] = 15'o00001;
    spin2[9] = 15'o37776;

    Vector#(10, DP) dpin1 = newVector;
    dpin1[0] = 30'o00000_00000;
    dpin1[1] = 30'o00001_00001;
    dpin1[2] = 30'o00001_00001;
    dpin1[3] = 30'o00010_10000;
    dpin1[4] = 30'o37777_40000;
    dpin1[5] = 30'o37776_00001;
    dpin1[6] = 30'o00000_00001;
    dpin1[7] = 30'o40300_45600;
    dpin1[8] = 30'o00000_00000;
    dpin1[9] = 30'o00000_00001;
    Vector#(10, Fmt) fmt1 = newVector;
    for (Integer i = 0; i < 10; i = i + 1) begin
        fmt1[i] = $format("(") + displayDecimal(dpin1[i][29:15]) + $format(",    ") + displayDecimal(dpin1[i][14:0]) + $format(")");
    end

    Vector#(10, DP) dpin2 = newVector;
    dpin2[0] = 30'o00000_00000;
    dpin2[1] = 30'o00001_00001;
    dpin2[2] = 30'o77776_00010;
    dpin2[3] = 30'o77767_00010;
    dpin2[4] = 30'o00000_00001;
    dpin2[5] = 30'o00000_00001;
    dpin2[6] = 30'o00000_37777;
    dpin2[7] = 30'o00000_00111;
    dpin2[8] = 30'o00000_10111;
    dpin2[9] = 30'o00000_11111;
    Vector#(10, Fmt) fmt2 = newVector;
    for (Integer i = 0; i < 10; i = i + 1) begin
        fmt2[i] = $format("(") + displayDecimal(dpin2[i][29:15]) + $format(",    ") + displayDecimal(dpin2[i][14:0]) + $format(")");
    end


    //starting up
    rule init(!started);
        started <= True;
    endrule
    
    rule one_in (started && !done);
        //send in data
        for (Integer i = 0; i < 10; i = i + 1) begin
            //SP result = subOnes(spin1[i], spin2[i]);
            //DP result = addDP(dpin1[i], dpin2[i]);
            //DP result = makeConsistentSign(dpin1[i]);

            //toTwos and toOnes test
            /*SP twos = toTwos(spin2[i]);
            SP ones = toOnes(twos);
            if (ones != spin2[i]) begin
                $display("Failed: %b => %b => %b", spin2[i], twos, ones);
            end*/

            //multiplication test
            DP prod = multOnes(spin1[i], spin2[i]);
            $display(displayDecimal(spin1[i]), "    *    ", displayDecimal(spin2[i]));
            $display($format("(") + displayDecimal(prod[29:15]) + $format(",    ") + displayDecimal(prod[14:0]) + $format(")"));


            //Fmt fmt_result = $format("(") + displayDecimal(result[29:15]) + $format(",    ") + displayDecimal(result[14:0]) + $format(")");
            //$display(displayDecimal(spin1[i]), $format("    -    "), displayDecimal(spin2[i]), $format("    =    "), displayDecimal(result));
            //$display("%b", spin2[i]);
            //$display(displayDecimal(spin2[i]));
            //$display("{%b, %b} => {%b, %b}", dpin1[i][29:15], dpin1[i][14:0], result[29:15], result[14:0]);
            //$display(fmt1[i], $format(" => "), fmt_result);
            //$display("{%b, %b} + {%b, %b} => {%b, %b}", dpin1[i][29:15], dpin1[i][14:0], dpin2[i][29:15], dpin2[i][14:0], result[29:15], result[14:0]);
            //$display(fmt1[i], $format("    +    "), fmt2[i], $format("    =    "), fmt_result);
        end
        done <= True;
    endrule

    //all done!
    rule finish(done);
        $finish();
    endrule
    
endmodule


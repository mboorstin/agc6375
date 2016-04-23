
import Vector::*;
import ArithUtil::*;
import Types::*;

(* synthesize *)
module mkArithUtilTest ();
    //state
    Reg#(Bool) started <- mkReg(False);
    Reg#(Bool) done <- mkReg(False);
    Reg#(Bool) testing_module <- mkReg(False); //is this testbench currently testing a module?
                                                //use this to control rule behavior.
    Reg#(Bool) requesting <- mkReg(True);
    Reg#(DP) curr_dpin1 <- mkReg(30'b0);
    Reg#(DP) curr_dpin2 <- mkReg(30'b0);
    Reg#(SP) curr_spin1 <- mkReg(15'b0);
    Reg#(SP) curr_spin2 <- mkReg(15'b0);
    Reg#(Bit#(6)) counter <- mkReg(6'b0);

    Divider divider <- mkDivider();

    //test inputs
    Vector#(10, SP) spin1 = newVector;
    spin1[0] = 15'o37776;
    spin1[1] = 15'o77776;
    spin1[2] = 15'o00001;
    spin1[3] = 15'o00010;
    spin1[4] = 15'o37777;
    spin1[5] = 15'o37776;
    spin1[6] = 15'o37776;
    spin1[7] = 15'o05760;
    spin1[8] = 15'o40000;
    spin1[9] = 15'o70000;

    Vector#(10, SP) spin2 = newVector;
    spin2[0] = 15'o00002;
    spin2[1] = 15'o77776;
    spin2[2] = 15'o77776;
    spin2[3] = 15'o77767;
    spin2[4] = 15'o00001;
    spin2[5] = 15'o00001;
    spin2[6] = 15'o37776;
    spin2[7] = 15'o00001;
    spin2[8] = 15'o77775;
    spin2[9] = 15'o37776;

    Vector#(10, DP) dpin1 = newVector;
    dpin1[0] = 30'o37777_00000;
    dpin1[1] = 30'o00000_77777;
    dpin1[2] = 30'o00001_00001;
    dpin1[3] = 30'o00010_10000;
    dpin1[4] = 30'o77777_40000;
    dpin1[5] = 30'o77776_00001;
    dpin1[6] = 30'o00001_40000;
    dpin1[7] = 30'o40300_45600;
    dpin1[8] = 30'o37777_40000;
    dpin1[9] = 30'o37776_00001;
    Vector#(10, Fmt) fmt1 = newVector;
    for (Integer i = 0; i < 10; i = i + 1) begin
        fmt1[i] = $format("(") + displayDecimal(dpin1[i][29:15]) + $format(",    ") + displayDecimal(dpin1[i][14:0]) + $format(")");
    end

    Vector#(10, DP) dpin2 = newVector;
    dpin2[0] = 30'o00001_00001;
    dpin2[1] = 30'o00001_00001;
    dpin2[2] = 30'o77776_00010;
    dpin2[3] = 30'o77767_00010;
    dpin2[4] = 30'o00000_00001;
    dpin2[5] = 30'o00000_00001;
    dpin2[6] = 30'o00000_77776;
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
    
    rule one_in (started && !done && !testing_module);
        //send in data
        for (Integer i = 0; i < 10; i = i + 1) begin
            //overflow correction test
            //Bit#(1) lead1 = truncateLSB(spin1[i]);
            //Bit#(1) lead2 = truncateLSB(spin2[i]);
            //Bit#(16) result0 = addOnes({lead1, spin1[i]}, {lead2,spin2[i]});
            //SP result = overflowCorrect(result0);
            //DP result = addDP(dpin1[i], dpin2[i]);
            

            //toTwos and toOnes test
            /*SP twos = toTwos(spin2[i]);
            SP ones = toOnes(twos);
            if (ones != spin2[i]) begin
                $display("Failed: %b => %b => %b", spin2[i], twos, ones);
            end*/

            //multiplication test
/*            DP prod = multOnes(spin1[i], spin2[i]);
            DP prod_slow = multOnesSlow(spin1[i], spin2[i]);
            if (prod != prod_slow) begin
                $display(displayDecimal(spin1[i]), "    *    ", displayDecimal(spin2[i]));
                $display($format("(") + displayDecimal(prod[29:15]) + $format(",    ") + displayDecimal(prod[14:0]) + $format(")"));
                $display($format("(") + displayDecimal(prod_slow[29:15]) + $format(",    ") + displayDecimal(prod_slow[14:0]) + $format(")"));
            end
*/

            //overflow addition test
            //SP result = addOnesUncorrected(spin1[i], spin2[i]);
            //$display(displayDecimal(spin1[i]), $format("    +    "), displayDecimal(spin2[i]), $format("    =    "), displayDecimal(result));
            
            //DAS test
            Bit#(33) result_prelim = addDP(dpin1[i], dpin2[i]);
            DP result = truncate(result_prelim);
            Fmt fmt_result = $format("(") + displayDecimal(result[29:15]) + $format(",    ") + displayDecimal(result[14:0]) + $format(")");
            $display(fmt1[i], $format(" + "), fmt2[i], $format(" = "), fmt_result);
            if (result_prelim[32] == 1) begin
                Fmt direction = (result_prelim[31] == 1) ? $format("negative ") : $format("positive ");
                $display(direction, $format("overflow"));
            end
            $display(displayDecimal(16'b1));

            //dABS test
            //SP result = dABS(spin1[i]);
            //$display(displayDecimal(spin1[i]), $format(" => "), displayDecimal(result));

            //slow division test
            /*DP quot1 = divideSlow(dpin1[i], spin1[i]);
            $display(displayDecimal({dpin1[i][29:15], dpin1[i][13:0]}), "    /    ", displayDecimal(spin1[i]));
            $display($format("(") + displayDecimal(quot1[29:15]) + $format(",    ") + displayDecimal(quot1[14:0]) + $format(")"));
            $display("");

            DP quot2 = divideSlow(dpin2[i], spin2[i]);
            $display(displayDecimal({dpin2[i][29:15], dpin2[i][13:0]}), "    /    ", displayDecimal(spin2[i]));
            $display($format("(") + displayDecimal(quot2[29:15]) + $format(",    ") + displayDecimal(quot2[14:0]) + $format(")"));
            $display("");*/

            //consistent sign test
            /*DP result = makeConsistentSign(dpin1[i]);
            Fmt fmt_result = $format("(") + displayDecimal(result[29:15]) + $format(",    ") + displayDecimal(result[14:0]) + $format(")");
            $display(fmt1[i], $format(" => "), fmt_result);
            */


            //$display(displayDecimal(spin1[i]), $format("    +    "), displayDecimal(spin2[i]), $format("    =    "), displayDecimal(result));
            //$display("%b", spin2[i]);
            //$display(displayDecimal(spin2[i]));
            //$display("{%b, %b} => {%b, %b}", dpin1[i][29:15], dpin1[i][14:0], result[29:15], result[14:0]);
            //$display(fmt1[i], $format(" => "), fmt_result);
            //$display("{%b, %b} + {%b, %b} => {%b, %b}", dpin1[i][29:15], dpin1[i][14:0], dpin2[i][29:15], dpin2[i][14:0], result[29:15], result[14:0]);
            //$display(fmt1[i], $format("    +    "), fmt2[i], $format("    =    "), fmt_result);
        end
        done <= True;
    endrule

    rule request (started && requesting && testing_module);

        //divide test
        Fmt curr_dfmt1 = $format("(") + displayDecimal(curr_dpin1[29:15]) + $format(",    ") + displayDecimal(curr_dpin1[14:0]) + $format(")");
        Fmt curr_sfmt1 = displayDecimal(curr_spin1);
        $display(curr_dfmt1, $format(" / "), curr_sfmt1);
        divider.req(curr_dpin1, curr_spin1);
        

        requesting <= False;
    endrule

    rule respond (started && !requesting && testing_module);
        //catch answers
        DP out <- divider.resp();
        SP quo = truncateLSB(out);
        SP rem = truncate(out);

        Fmt quo_fmt = displayDecimal(quo);
        Fmt rem_fmt = displayDecimal(rem);

        $display($format(" = "), quo_fmt, $format(" , "), rem_fmt);
        $display("");

        requesting <= True;

        curr_dpin1 <= curr_dpin1 + 30'o03323_05514;
        curr_spin1 <= curr_spin1 + 15'o07365;
        counter <= counter + 1;

        if (counter == 6'd20) begin
            done <= True;
        end
    endrule

    //all done!
    rule finish(done);
        $finish();
    endrule
    
endmodule


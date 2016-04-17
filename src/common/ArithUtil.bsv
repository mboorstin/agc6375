import Types::*;


//single and double precision integers
typedef Bit#(15) SP;
typedef Bit#(30) DP;

//Divider module interface
//req begins the division a / b
//a call to resp will only be successful when the division is done.
//a call to req, if division is ongoing, will overwrite current division.
//DP returned by resp is of the form {q,r} with q and r of type SP
//q = floor(a/b) = quotient
//r = a - (q * b) = remainder
interface Divider;
    method Action req(DP a, SP b);
    method ActionValue#(DP) resp();
endinterface


//functions for ones complement arithmetic

//addition.
//overflow could be an issue.
//As in the original AGC, (-1) + (+1) = (-0)
function Bit#(n) addOnes (Bit#(n) a, Bit#(n) b);
    //
    Bit#(TAdd#(n,1)) sum_u = addOnesCarry(a, b);

    Bit#(n) sum;
    Bit#(1) msb = truncateLSB(sum_u);

    if (msb == 1) begin //if the carry bit overflows to the left
        //wrap it back around to the right.
        sum_u = truncate(addOnesCarry(sum_u, fromInteger(1)));
    end

    //return truncated sum.
    sum = truncate(sum_u);

    return sum;

endfunction

//addition
//automatically overflow-corrected
function SP addOnesOverflow (SP a, SP b);
    //
    Bit#(16) a_ext = {a[14], a[14:0]};
    Bit#(16) b_ext = {b[14], b[14:0]};
    Bit#(16) uncorrected = addOnes(a_ext, b_ext);
    SP corrected = overflowCorrect(uncorrected);
    return corrected;
endfunction

//returns the sum of a and b with a carry bit as the MSB
function Bit#(TAdd#(n,1)) addOnesCarry (Bit#(n) a, Bit#(n) b);
    //
    Bit#(TAdd#(n,1)) sum_u = {1'b0, a} + {1'b0, b};

    return sum_u;

endfunction

//subtraction.
//a - b is returned.
function Bit#(n) subOnes (Bit#(n) a, Bit#(n) b);
    //invert b, add.
    return addOnes(a, ~b);
endfunction

//multiplication
//a * b is returned.
//functions by converting to 2's complement and multiplying.
//takes in two SP values, outputs one DP value
//
function DP multOnesSlow (SP a, SP b);
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(1) sign_b = truncateLSB(b);

    //unsigned a and b
    Bit#(15) u_a = (sign_a == 1) ? (~a[14:0]) : a[14:0];
    Bit#(15) u_b = (sign_b == 1) ? (~b[14:0]) : b[14:0];

    //convert magnitudes to 2's complement
    Bit#(15) twos_a = toTwos(u_a);
    Bit#(15) twos_b = toTwos(u_b);
    Bit#(28) prod2s = zeroExtend(twos_a) * zeroExtend(twos_b);
    DP prod1s;

    if (sign_a != sign_b) begin
        prod1s = {1'b1, ~prod2s[27:14], 1'b1, ~prod2s[13:0]};
    end
    else begin
        prod1s = {1'b0, prod2s[27:14], 1'b0, prod2s[13:0]};
    end

    return prod1s;
endfunction

//multiplication
//probably faster than above
function DP multOnes (SP a, SP b);
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(1) sign_b = truncateLSB(b);

    //unsigned a and b
    //these have an assumed leading zero (positive)
    Bit#(14) u_a = (sign_a == 1) ? (~a[13:0]) : a[13:0];
    Bit#(14) u_b = (sign_b == 1) ? (~b[13:0]) : b[13:0];

    //
    Bit#(5) top_a = {1'b0, u_a[13:10]}; // << 10
    Bit#(5) mid_a = u_a[9:5]; // << 5
    Bit#(5) low_a = u_a[4:0];

    Bit#(5) top_b = {1'b0, u_b[13:10]}; // << 10
    Bit#(5) mid_b = u_b[9:5]; // << 5
    Bit#(5) low_b = u_b[4:0];

    //multiply cases
    Bit#(8) t_t0 = zeroExtend(top_a) * zeroExtend(top_b);
    Bit#(9) t_m0 = zeroExtend(top_a) * zeroExtend(mid_b);
    Bit#(9) t_l0 = zeroExtend(top_a) * zeroExtend(low_b);
    Bit#(9) m_t0 = zeroExtend(mid_a) * zeroExtend(top_b);
    Bit#(10) m_m0 = zeroExtend(mid_a) * zeroExtend(mid_b);
    Bit#(10) m_l0 = zeroExtend(mid_a) * zeroExtend(low_b);
    Bit#(9) l_t0 = zeroExtend(low_a) * zeroExtend(top_b);
    Bit#(10) l_m0 = zeroExtend(low_a) * zeroExtend(mid_b);
    Bit#(10) l_l0 = zeroExtend(low_a) * zeroExtend(low_b);

    //shift cases to final positions
    Bit#(28) t_t = zeroExtend(t_t0) << 20;
    Bit#(28) t_m = zeroExtend(t_m0) << 15;
    Bit#(28) t_l = zeroExtend(t_l0) << 10;
    Bit#(28) m_t = zeroExtend(m_t0) << 15;
    Bit#(28) m_m = zeroExtend(m_m0) << 10;
    Bit#(28) m_l = zeroExtend(m_l0) << 5;
    Bit#(28) l_t = zeroExtend(l_t0) << 10;
    Bit#(28) l_m = zeroExtend(l_m0) << 5;
    Bit#(28) l_l = zeroExtend(l_l0);

    //sum all cases
    Bit#(28) result = t_t + t_m + t_l + m_t + m_m + m_l + l_t + l_m + l_l;

    //turn into double precision
    DP dp = (sign_a == sign_b) ? ({1'b0, result[27:14], 1'b0, result[13:0]}) : ({1'b1, ~result[27:14], 1'b1, ~result[13:0]});
    return dp;
endfunction

//returns 2's complement version of the input 1's complement value
function Bit#(n) toTwos(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(n) twos = (sign_a == 1) ? (a+1) : a;
    return twos;
endfunction

//returns 1's complement version of the input 2's complement value
//does not work for a = 1000000000...0
function Bit#(n) toOnes(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(n) ones = (sign_a == 1) ? (a-1) : a;
    return ones;
endfunction

//functions for converting SP/DP values and performing arithmetic with them
function SP addSP (SP a, SP b);
    return addOnes(a, b);
endfunction


function DP addDP(DP a, DP b);
    //holders
    DP a_con = makeConsistentSign(a);
    DP b_con = makeConsistentSign(b);

    //preliminary addition
    Bit#(29) result = addOnes({a_con[29:15],a_con[13:0]},{b_con[29:15],b_con[13:0]});

    DP out = {result[28:14], result[28], result[13:0]};

    return out;
endfunction


//sometimes DP values can have inconsistent signs.  The output of this function will have consistent signs.
function DP makeConsistentSign(DP a);
    DP out;

    if (a[29] != a[14]) begin //if not currently consistent
        SP high = a[29:15];
        SP low = a[14:0];

        SP new_high;
        SP new_low;

        if (high == 15'b0) begin //special cases where larger SP is +/-0
            new_high = 15'o77777;
            new_low = low;
        end
        else if (~high == 15'b0) begin
            new_high = 15'b0;
            new_low = low;
        end
        else begin //ordinary use
            if (a[29] == 1) begin //if larger portion is negative
                new_high = addOnes(high, fromInteger(1)); //move amount from smaller SP to larger SP
                new_low = subOnes(low, 15'b100_000_000_000_000);
            end
            else begin //otherwise

                if (high == 15'b1) begin //be careful of special case; can end up with -0 instead of 0
                    new_high = 15'b0; //move amount from larger SP to smaller SP
                end
                else begin
                    new_high = subOnes(high, 15'b1);
                end

                new_low = addOnes(low, 15'b100_000_000_000_000);
            end
            
        end

        out = {new_high, new_low}; //new value (should be equivalent to old value)
    end
    else begin
        out = a;
    end
    return out;
endfunction

//overflow correction of a value like that in the accumulator
//bit 15 is only used for overflow correction / checking
//usual use case is transferring an accumulator value outside
//running it on a value which has not overflowed should return the same value.
function SP overflowCorrect(Bit#(16) a);
    SP result = {a[15],a[13:0]}; //extract magnitude bits and corrected sign bit from a
    return result;
endfunction


function DP divideSlow (DP a, SP b);
    DP consistent = makeConsistentSign(a);
    DP dp;

    //sign bits
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(1) sign_b = truncateLSB(b);

    //unsigned a and b magnitudes
    //these have a leading zero (positive)
    Bit#(28) u_a = (sign_a == 1) ? ({~a[28:15], ~a[13:0]}) : ({a[28:15], a[13:0]});
    Bit#(14) u_b = (sign_b == 1) ? (~b[13:0]) : b[13:0];

    if (u_a == 0 && u_b == 0) begin //output 0 if dividing by 0
        dp = {sign_a, 14'b0, sign_a, 14'b0};
    end
    else if (u_b == 0) begin
        dp = {sign_a, 14'b0, sign_a, 14'b0};
    end
    else if (u_a == {u_b, 14'b0}) begin //if inputs are equal
        Bit#(15) accum = 15'o37777; //store 37777 in A
        dp = {accum, b}; //and divisor in L
    end
    else if (u_a > {u_b, 14'b0}) begin //this value means divisor is larger
        dp = {sign_a, 14'd0, sign_a, 14'd12};
    end
    else begin
        //
        Bit#(14) quotient = truncate(u_a / zeroExtend(u_b));
        Bit#(14) remainder = truncate(u_a - zeroExtend(quotient * u_b));
        Bit#(14) remainder_signed = (sign_a == 1) ? (~remainder) : (remainder);
        Bit#(28) result;

        result = {quotient, remainder_signed};

        //synthesize output
        dp = (sign_a == sign_b) ? ({1'b0, result[27:14], sign_a, result[13:0]}) : ({1'b1, ~result[27:14], sign_a, result[13:0]});
    end
    //



    return dp;
endfunction

(* synthesize *)
module mkDivider(Divider);
    //
    Reg#(Bit#(14)) quo <- mkRegU();              //in-progress quotient
    Reg#(Bit#(14)) rem <- mkRegU();              //in-progress remainder
    Reg#(Bit#(28)) dividend <- mkRegU();         //magnitude of a, modified by computation process
    Reg#(Bit#(14)) divisor <- mkRegU();          //magnitude of b
    Reg#(Bit#(1)) sign_q <- mkRegU();            //sign of output value, 1 negative
    Reg#(Bit#(1)) sign_r <- mkRegU();            //sign of remainder
    Reg#(Bit#(5)) stage <- mkReg(15);            //stage.
    //15: default start value, should never appear otherwise
    //0-14: number of shifts applied to divisor before comparing to remaining dividend
    //31: calculating remainder
    //30: ready to be output
    //29: waiting for input

    rule step (stage < 5'd15);
        //scaled divisor.
        Bit#(28) shift_div = {14'b0, divisor} << stage;

        //if the scaled divisor can't be subtracted out of the dividend
        if (shift_div > dividend) begin
            //the answer for this bit is 0
            quo <= (quo << 1);
        end
        else begin //otherwise
            dividend <= dividend - shift_div;
            quo <= (quo << 1) + 1; //the answer for this bit is 1
        end
        

        //increment stage; the next time this rule is executed,
        //shift_div will be one to the right.
        //will eventually wrap around to 31, which signals that the division is done.
        stage <= stage - 1;
    endrule

    rule remainder (stage == 5'd31);
        //determine the remainder depending on the sign
        /* sign_q, sign_r
        * 00: a and b positive,       remainder = dividend remaining
        * 01: a and b negative,       remainder = dividend remaining
        * 10: a negative, b positive, remainder = inverted
        * 11: a positive, b negative, remainder = inverted
        */
        if (sign_q == 0) begin // |quotient * b| < |a|  
            rem <= truncate(dividend);
        end
        else begin             // |quotient * b| > |a| 
            //remainder = divisor - dividend
            //divisor > dividend at this point
            if (divisor <= truncate(dividend)) begin
                $display("Divider: error, divisor is not greater than remainder");
            end
            quo <= quo + 1;
            rem <= divisor - truncate(dividend);
        end

        //now ready to be output!
        stage <= 5'd30;
    endrule

    method Action req(DP a, SP b);
        //extract information
        DP a_cons = makeConsistentSign(a);
        //Fmt a_cons_fmt = $format("(") + displayDecimal(a_cons[29:15]) + $format(",    ") + displayDecimal(a_cons[14:0]) + $format(")");
        //$display(a_cons_fmt);

        Bit#(1) sign_a = truncateLSB(a_cons); //input signs
        Bit#(1) sign_b = truncateLSB(b);
        sign_q <= (sign_a == sign_b) ? (0) : (1); //output signs
        sign_r <= sign_b;

        //unsigned a and b magnitudes
        //these have a leading zero (positive)
        Bit#(28) u_a = (sign_a == 1) ? ({~a_cons[28:15], ~a_cons[13:0]}) : ({a_cons[28:15], a_cons[13:0]});
        Bit#(14) u_b = (sign_b == 1) ? (~b[13:0]) : b[13:0];

        //check for special cases
        //special cases are ready for output immediately.
        if ({u_b, 14'b0} < u_a) begin
            //$display("Divider: would return a quotient > 1.");
            //return dummy value
            stage <= 5'd30;
            quo <= 14'd12;
            rem <= 14'd12;
        end
        else if ({u_b, 14'b0} == u_a) begin //if divisor == divident
            //outputs
            stage <= 5'd30;
            quo <= 14'o37777;
            rem <= u_b;
        end
        else begin //no special cases; do the division
            //set registers
            quo <= 0;
            rem <= 0;
            dividend <= u_a;
            divisor <= u_b;
            stage <= 5'd14;
        end

        //
    endmethod

    method ActionValue#(DP) resp() if (stage == 5'd30);
        //synthesize output DP value
        SP quotient =  (sign_q == 0) ? {1'b0, quo} : {1'b1, ~quo};
        SP remainder = (sign_r == 0) ? {1'b0, rem} : {1'b1, ~rem};
        //set stage to wait for input
        stage <= 5'd29;

        return {quotient, remainder};
    endmethod
endmodule

function Fmt displayDecimal(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(TSub#(n,1)) mag = truncate(a);
    Bit#(1) sign = truncateLSB(a);
    Fmt out;

    if (sign == 1'b1) begin
        out = $format("-%d", ~mag);
    end
    else begin
        out = $format("+%d", mag);
    end

    return out;
endfunction

//  DABS(x)=|x|-1 if |x|>1, or +0 otherwise.
function Bit#(n) dABS(Bit#(n) x);
    // If is negative, make positive
    Bit#(TSub#(n, 1)) abs = (x[valueOf(TSub#(n, 1))] == 1) ? ~truncate(x) : truncate(x);
    // Subtract one if appropriate
    return zeroExtend(((abs == 0) || (abs == 1)) ? 0 : subOnes(abs, 1));
endfunction

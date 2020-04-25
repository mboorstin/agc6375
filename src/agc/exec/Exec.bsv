import InterStage::*;
import Types::*;
import ArithUtil::*;

/*
TAGLSB: places dependent on the choice of LSB 0 for 15-bit memory in 16-bit words
TAGEXCEPTION: places with overflows/other exceptions to be implemented



*/

//(* noinline *)
function Exec2Writeback exec(ExecFuncArgs args);
    case (args.instNum)
        AD: return ad(args);
        ADS: return ads(args);
        AUG: return aug(args);
        BZF: return bzf(args);
        BZMF: return bzmf(args);
        CA: return ca(args);
        CCS: return ccs(args);
        CS: return cs(args);
        DAS: return das(args);
        DCA: return dca(args);
        DCS: return dcs(args);
        DXCH: return dxch(args);
        DIM: return dim(args);
        DV: return dv(args);
        EDRUPT: return edrupt(args);
        // Bunch of stuff here
        INCR: return incr(args);
        INDEX: return index(args);
        // Bunch of other stuff here
        INHINT: return inhint(args);
        LXCH: return regXCH(args, rL);
        MASK: return mask(args);
        MP: return mp(args);
        MSU: return msu(args);
        // Bunch of stuff here
        QXCH: return regXCH(args, rQ);
        // Bunch of stuff here
        RAND: return ioRead(args);
        READ: return ioRead(args);
        RELINT: return relint(args);
        RETURN: return returnFunc(args);
        ROR: return ioRead(args);
        RXOR: return ioRead(args);
        // Bunch of stuff here
        SU: return su(args);
        TC: return tc(args);
        TCF: return tcf(args);
        TS: return ts(args);
        // Bunch of stuff here
        WAND: return ioWrite(args);
        WOR: return ioWrite(args);
        WRITE: return ioWrite(args);
        XCH: return regXCH(args, rA);
        // Bunch of stuff here
        // Once we're done with everything, should turn into a
        // raise unimplemented error
        default: return unimplemented(args);
    endcase
endfunction


//All of the functions to execute opcodes.
//these functions have the same information as Exec does.
//They should be inlined.

//add
//adds the contents of a memory location into the accumulator (rA)
function Exec2Writeback ad(ExecFuncArgs args);
    //address is 12 bits; not an extracode, so ignore LSB.
    //Addr k = args.inst[12:1];

    Word mem_resp = args.memOrIOResp[15:0];
    Word reg_resp = args.regResp[15:0];
    Addr memAddr = args.inst[12:1]; //TAGLSB


    //mem_resp is the value to be added to the accumulator.
    //TAGLSB
    //Word mem_val = {mem_resp[15], truncateLSB(mem_resp)};
    Word mem_val = is16BitRegM(memAddr) ? mem_resp : {mem_resp[15], mem_resp[15:1]};

    Word sum = addOnesUncorrected(mem_val, reg_resp); //assume values are extended left

    if (sum[15] != sum[14]) begin
        //overflow-- TAGEXCEPTION
    end

    //return
    Exec2Writeback e2w = Exec2Writeback{
        eRes1: {?, mem_resp},
        eRes2: {?, sum}, //write sum back to accumulator only
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA, //accumulator
        newZ: args.z + 1
    };
    return e2w;
endfunction

//add to storage
//adds the contents of a erasable memory location to the accumulator
//and stores the result back in both the accumulator and memory location.
function Exec2Writeback ads(ExecFuncArgs args);

    Word mem_resp = args.memOrIOResp[15:0];
    Word reg_resp = args.regResp[15:0];
    Addr memAddr = zeroExtend(args.inst[10:1]); // TAGLSB

    //mem_resp is the value to be added to the accumulator.
    //TAGLSB
    //Word mem_val = {mem_resp[15], truncateLSB(mem_resp)};
    Bool is16Bits = is16BitRegM(memAddr);
    Word mem_val = is16Bits ? mem_resp : {mem_resp[15], mem_resp[15:1]};

    Word sum = addOnesUncorrected(mem_val, reg_resp); //assume values are extended left
    Word memRes = is16Bits ? sum : {overflowCorrect(sum), 1'b0};

    if (sum[15] != sum[14]) begin
        //overflow-- TAGEXCEPTION
    end

    //return
    Exec2Writeback e2w = Exec2Writeback{
        eRes1: {?, memRes}, //TAGLSB
        eRes2: {?, sum}, //write sum back to both
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Valid rA, //accumulator
        newZ: args.z + 1
    };
    return e2w;
endfunction

// augment
// Increments a positive value in an erasable-memory location in-place by +1
// or a negative value by -1
// Parameterized helper function
function Bit#(n) addOrSub(Bit#(n) val)
        provisos(Add#(1, a__, n),
                Add#(a__, b__, TAdd#(n, 1)),
                 Add#(c__, a__, TAdd#(n,2))
                );
    if (val[valueOf(TSub#(n, 1))] == 0) begin
        return addOnesUncorrected(val, 1);
    end else begin
        return subOnesUncorrected(val, 1);
    end
endfunction

function Exec2Writeback aug(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];

    Word auged;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        auged = addOrSub(memResp);
    end else begin
        // TAGLSB
        auged = {addOrSub(memResp[15:1]), 1'b0};
    end

    return Exec2Writeback {
        eRes1: {?, auged},
        // Should be ? but setting to 0 to keep tests happy
        eRes2: ?,
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// Branch Zero to Fixed
// The "Branch Zero to Fixed" instruction jumps to a memory location
// in fixed (as opposed to erasable) memory if the accumulator is zero
function Exec2Writeback bzf(ExecFuncArgs args);
    Word acc = args.regResp[15:0];

    Bool doBranch = (acc[15] == acc[14]) && ((acc[14:0] == 0) || (acc[14:0] == ~0));

    Addr newZ = (doBranch ? args.inst[12:1] : args.z) + 1;

    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: newZ
    };
endfunction

// Branch Zero or Minus to Fixed
// The "Branch Zero or Minus to Fixed" instruction jumps to a memory
// location in fixed (as opposed to erasable) memory if the accumulator is zero or negative.
function Exec2Writeback bzmf(ExecFuncArgs args);
    Word acc = args.regResp[15:0];

    Bool doBranch = (acc[15] == acc[14]) ? ((acc[14:0] == 0) || acc[14] == 1) : (acc[15:14] == 2'b10);

    Addr newZ = (doBranch ? args.inst[12:1] : args.z) + 1;

    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: newZ
    };
endfunction

// Clear and Add
// The "Clear and Add" (or "Clear and Add Erasable" or "Clear and Add Fixed")
// instruction moves the contents of a memory location into the accumulator.
function Exec2Writeback ca(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Addr memAddr = args.inst[12:1]; // TAGLSB

    // TAGLSB
    Word newAcc = is16BitRegM(memAddr) ? memResp : {memResp[15], memResp[15:1]};

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, newAcc},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// Counct, Compare, and Skip
// The "Count, Compare, and Skip" instruction stores a variable from erasable memory into the
// accumulator (which is decremented), and then performs one of several jumps based on the original
// value of the variable.  This is the only "compare" instruction in the AGC instruction set.
function Exec2Writeback ccs(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Addr memAddr = args.inst[12:1]; // TAGLSB

    Bool is16Bits = is16BitRegM(memAddr);

    Word memRespCleaned = is16Bits ? memResp : {memResp[15], memResp[15:1]};

    Word dabs = dABS(memRespCleaned);

    // This could probably be made more efficient - we're choosing to do dynamic addition, but
    // might be worth the extra space and do static addition?  Unclear.  On the other hand, the
    // compiler can hopefully figure out that there are only 4 options for addend.
    Addr addend;

    // Note that positive numbers in 1's and 2's complement are the same
    if (memRespCleaned == 0) begin
        addend = 2;
    // == -0
    end else if (memRespCleaned == ~0) begin
        addend = 4;
    // > +0
    end else if (memRespCleaned[15] == 0) begin
        addend = 1;
    // < -0
    end else begin
        addend = 3;
    end

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, dabs},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + addend
    };
endfunction

// Clear and Subtract
// The "Clear and Subtract" instruction moves the 1's-complement (i.e., the negative) of a memory location into
// the accumulator.
function Exec2Writeback cs(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Addr memAddr = args.inst[12:1]; // TAGLSB

    Bit#(15) upper = ~memResp[15:1];

    Bool is16Bits = is16BitRegM(memAddr);

    Word acc = is16BitRegM(memAddr) ? {upper, ~memResp[0]} : signExtend(upper);

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, acc},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// Diminish
// The "Diminish" instruction decrements a positive non-zero value in an
// erasable-memory location in-place, or increments a negative non-zero value.
// It's difficult to get this to share hardware with AUG because of the differing
// handling of +/- 0.  Code-wise, Bluespec doesn't allow function pointers, so it's
// not really worth the overhead of combining aug and dim.
// Parameterized helper function
function Bit#(n) subOrAddNonZero(Bit#(n) val)
        provisos(Add#(1, a__, n),
            Add#(a__, b__, TAdd#(n, 1)),
            Add#(c__, a__, TAdd#(n,2))
            );
    if ((val == 0) || (val == ~0)) begin
        return val;
    end else if (val[valueOf(TSub#(n, 1))] == 0) begin
        return subOnesUncorrected(val, 1);
    end else begin
        return addOnesUncorrected(val, 1);
    end
endfunction

// Double add to storage
// The "Double Add to Storage" instruction does a double-precision (DP) add of
// the A,L register pair to a pair of variables in erasable memory.
function Exec2Writeback das(ExecFuncArgs args);
    //words from memory
    Word kResp = args.memOrIOResp[31:16];
    Word kp1Resp = args.memOrIOResp[15:0];

    Addr memAddr = args.inst[12:1] - 1;

    Word rResp = args.regResp[31:16];
    Word r2Resp = args.regResp[15:0];
    SP aVal;
    SP lVal;
    SP k_sp;
    SP kp1_sp;
    Word new_aVal;
    Word new_k;
    Word new_kp1;

    //extract values
    aVal = rResp[14:0];
    lVal = r2Resp[14:0];
    k_sp = is16BitRegM(memAddr) ? kResp[14:0] : kResp[15:1];
    kp1_sp = is16BitRegM(memAddr + 1) ? kp1Resp[14:0] : kp1Resp[15:1];

    //perform addition
    //TAGLSB
    Bit#(33) result = addDP({aVal, lVal}, {k_sp, kp1_sp});
    new_k = is16BitRegM(memAddr) ? result[30:15] : {overflowCorrect(result[30:15]), 1'b0};
    new_kp1 = is16BitRegM(memAddr + 1) ? signExtend(result[14:0]) : {result[14:0], 1'b0};
    new_aVal = (result[32]==1) ? ((result[31]==0) ? (16'b1) : ~(16'b1)) : (16'b0);

    Bool isDDOUBL = (memAddr == 0);

    return Exec2Writeback {
        eRes1: {new_kp1, new_k},
        eRes2: {16'b0, new_aVal},
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: isDDOUBL ? tagged Invalid : (tagged Valid rA),
        newZ: args.z + 1
    };
endfunction

// Double clear-and-add
// The "Double Clear and Add" instruction moves the contents of a pair of
// memory locations into the A,L register pair.
function Exec2Writeback dca(ExecFuncArgs args);
    Word kResp = args.memOrIOResp[31:16];
    Word kp1Resp = args.memOrIOResp[15:0];

    Addr memAddr = args.inst[12:1] - 1;

    Word aVal;
    Word lVal;

    // If is L, both A and L get Q
    if (memAddr == zeroExtend(rL)) begin
        // A and L get the overflow-corrected version of Q because "DCA L" is actually defined as
        // "load L with Q, then A with L", and DCA writes overflow corrected values to L
        Word corrected = signExtend(overflowCorrect(kp1Resp));
        aVal = corrected;
        lVal = corrected;
    end else begin
        aVal = is16BitRegM(memAddr) ? kResp : signExtend(kResp[15:1]);
        lVal = signExtend(overflowCorrect(is16BitRegM(memAddr + 1) ? kp1Resp : signExtend(kp1Resp[15:1])));
    end

    return Exec2Writeback {
        eRes1: args.memOrIOResp,
        eRes2: {lVal, aVal},
        // Writing back never hurts us (except for losing a cycle), so we can
        // afford to write back both words
        memAddrOrIOChannel: (memAddr == zeroExtend(rBRUPT) || isCSCE(memAddr)) ? tagged Addr memAddr : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// Double Clear and Subtract
// The "Double Clear and Subtract" instruction moves the 1's-complement (i.e., the
// negative) of the contents of a pair of memory locations into the A,L register pair.
function Exec2Writeback dcs(ExecFuncArgs args);
    Word kResp = args.memOrIOResp[31:16];
    Word kp1Resp = args.memOrIOResp[15:0];

    Addr memAddr = args.inst[12:1] - 1;

    Word aVal;
    Word lVal;

    // If is L, both A and L get Q
    if (memAddr == zeroExtend(rL)) begin
        aVal = ~kp1Resp;
        lVal = ~kp1Resp;
    end else begin
        aVal = ~(is16BitRegM(memAddr) ? kResp : signExtend(kResp[15:1]));
        lVal = ~(is16BitRegM(memAddr + 1) ? kp1Resp : signExtend(kp1Resp[15:1]));
    end

    lVal = signExtend(overflowCorrect(lVal));

    return Exec2Writeback {
        eRes1: args.memOrIOResp,
        eRes2: {lVal, aVal},
        // Writing back never hurts us (except for losing a cycle), so we can
        // afford to write back both words
        memAddrOrIOChannel: (memAddr == zeroExtend(rBRUPT) || isCSCE(memAddr)) ? tagged Addr memAddr : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

function Exec2Writeback dim(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];

    Word dimmed;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        dimmed = subOrAddNonZero(memResp);
    end else begin
        // TAGLSB
        dimmed = {subOrAddNonZero(memResp[15:1]), 1'b0};
    end

    return Exec2Writeback {
        eRes1: {?, dimmed},
        // Should be ? but setting to 0 to keep tests happy
        eRes2: ?,
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// Double Exchange
//The "Double Exchange" instruction exchanges the double-precision (DP) value in the
// register-pair A,L with a value stored in the erasable memory variable pair K,K+1.
function Exec2Writeback dxch(ExecFuncArgs args);
    Word kResp = args.memOrIOResp[31:16];
    Word kp1Resp = args.memOrIOResp[15:0];

    Word aResp = args.regResp[31:16];
    Word lResp = args.regResp[15:0];

    Addr memAddr = zeroExtend(args.inst[10:1] - 1);

    Word aVal;
    Word lVal;

    Word kVal;
    Word kp1Val;

    // If K is L, Q goes into A, A goes into L, and L goes into Q
    if (memAddr == zeroExtend(rL)) begin
        aVal = kp1Resp;
        lVal = aResp;
        kVal = aResp;
        kp1Val = lResp;
    end else begin
        Bool kIsQ = (memAddr == zeroExtend(rQ));
        aVal = kIsQ ? kResp : signExtend(kResp[15:1]);
        lVal = signExtend(kp1Resp[15:1]);
        kVal = kIsQ ? aResp : {overflowCorrect(aResp), 1'b0};
        kp1Val = {overflowCorrect(lResp), 1'b0};
    end

    lVal = signExtend(overflowCorrect(lVal));

    Bool isA = (memAddr == zeroExtend(rA));

    if (memAddr == zeroExtend(rZ)) begin
        kVal = kVal + 2;
    end

    return Exec2Writeback {
        eRes1: {kp1Val, kVal},
        eRes2: {lVal, aVal},
        memAddrOrIOChannel: isA ? tagged None : tagged Addr memAddr,
        regNum: isA ? tagged Invalid : tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// DV
// Most of this is handled in the processor, this just saves Z
function Exec2Writeback dv(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: ?,
        regNum: ?,
        newZ: args.z + 1
    };
endfunction

// EDRUPT
// The "EDRUPT" instruction is a special kind of interrupt which inhibits interrupts, loads
// Z into ZRUPT, and takes the next instruction from address 0.
function Exec2Writeback edrupt(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: {?, args.z},
        memAddrOrIOChannel: ?,
        regNum: tagged Valid rZRUPT,
        // We want the next instruction to be 0, so this needs to be one more than that
        newZ: 1
    };
endfunction

// INCR
// The "Increment" instruction increments an erasable-memory location in-place by +1.
function Exec2Writeback incr(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];

    Word auged;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        auged = addOnesCorrected(memResp, 1);
    end else begin
        // TAGLSB
        auged = {addOnesCorrected(memResp[15:1], 1), 1'b0};
    end

    return Exec2Writeback {
        eRes1: {?, auged},
        // Should be ? but setting to 0 to keep tests happy
        eRes2: ?,
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// INDEX
// Note that eRes2 is added to the next instruction.
function Exec2Writeback index(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    // This is not stricly correct, because is 12 bits when INDEX is used as an extracode,
    // but we only use it for is16BItRegM and isCSCE.
    Addr memAddr = zeroExtend(args.inst[10:1]);

    Word toAdd = is16BitRegM(memAddr) ? {overflowCorrect(memResp), 0} : memResp;

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, toAdd},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// INHINT
// Disable interrupts.  For now, doing nothing.
function Exec2Writeback inhint(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// XCH, LXCH and QXCH
// The "Exchange A/L/Q and K" instruction exchanges the value in the A/L/Q register with a
// value stored in erasable memory.
function Exec2Writeback regXCH(ExecFuncArgs args, RegIdx regNum);
    Word memResp = args.memOrIOResp[15:0];
    Word rResp = args.regResp[15:0];

    Addr memAddr = {2'b0, args.inst[10:1]};

    Bool is16Bits = is16BitRegM(memAddr);

    // TAGLSB
    Word newL = is16Bits ? memResp : signExtend(memResp[15:1]);
    Word newMem = is16Bits ? rResp : {overflowCorrect(rResp), 1'b0};

    return Exec2Writeback {
        eRes1: {?, newMem},
        eRes2: {?, newL},
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Valid regNum,
        newZ: args.z + 1
    };
endfunction

// MASK
// The "Mask A by K" instruction logically ANDs the contents of a memory
// location bitwise into the accumulator.
function Exec2Writeback mask(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Word aResp = args.regResp[15:0];

    Addr memAddr = {2'b0, args.inst[10:1]};

    Word newA;
    // Hopefully the compiler figures out it can use most of these
    // & gates for both cases...right?
    if (is16BitRegM(memAddr)) begin
        newA = memResp & aResp;
    end else begin
        // TAGEXCEPTION
        newA = signExtend(memResp[15:1] & aResp[14:0]);
    end

    return Exec2Writeback {
        eRes1: ?,
        eRes2: {?, newA},
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

//MP
//A and K contain SP values
//
function Exec2Writeback mp(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Word aResp = args.regResp[15:0];

    Addr memAddr = args.inst[12:1];

    //extract SP values.  Accumulator is overflow-adjusted.
    SP a = overflowCorrect(aResp);
    SP b = is16BitRegM(memAddr) ? overflowCorrect(memResp) : memResp[15:1];

    DP result = multOnes(a, b);

    Word newA = signExtend(result[29:15]);
    Word newL = signExtend(result[14:0]);

    //

    return Exec2Writeback {
        eRes1: ?,
        eRes2: {newL, newA},
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

//MSU
//A and K are assumed to contain 2's complement unsigned values
//A and K are subtracted as 1's complement values and the answer is stored in A
//A is overflow-corrected iff K is 15-bit.
function Exec2Writeback msu(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Word aResp = args.regResp[15:0];

    Addr memAddr = {2'b0, args.inst[10:1]};

    Word newA;

    if (memAddr == zeroExtend(rQ)) begin //just Q
        Bit#(16) a = aResp;
        Bit#(16) b = memResp;
        Bit#(16) result = modularSubtract(a, b);

        if (~result == 16'b0) begin
            result = ~result;
        end

        newA = result;
    end else if (is16BitRegM(memAddr)) begin //not 100% sure that this is the desired functionality.
                                                //if MSU L is acting strangely, it's possible that
                                                //it's supposed to use 16 bit values instead.
        Bit#(15) a = overflowCorrect(aResp);
        Bit#(15) b = overflowCorrect(memResp[15:0]);
        Bit#(15) result = modularSubtract(a, b);

        if (~result == 15'b0) begin
            result = ~result;
        end

        newA = signExtend(result);
    end else begin
        Bit#(15) a = overflowCorrect(aResp);
        Bit#(15) b = memResp[15:1];
        Bit#(15) result = modularSubtract(a, b);

        if (~result == 15'b0) begin
            result = ~result;
        end

        newA = signExtend(result);
    end

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, newA},
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// RELINT
// Enable interrupts.  For now, doing nothing.
function Exec2Writeback relint(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// RETURN
// This is really a special case of TC
function Exec2Writeback returnFunc(ExecFuncArgs args);
    Addr newAddr = truncate(args.regResp[15:0]);

    return Exec2Writeback {
        eRes1: ?,
        eRes2: {?, 16'h3},
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rQ,
        newZ: newAddr + 1
    };
endfunction

// SU
// The "Subtract" instruction subtracts a memory value from the accumulator.
function Exec2Writeback su(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Word aResp = args.regResp[15:0];
    Addr memAddr = zeroExtend(args.inst[10:1]);

    Word aSubbed = subOnesUncorrected(aResp, is16BitRegM(memAddr) ? memResp : signExtend(memResp[15:1]));

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, aSubbed},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// TC
// The "Transfer Control" (or "Transfer Control setting up a Return") instruction calls a subroutine,
// first preparing for a later return to the instruction following the TC instruction.
function Exec2Writeback tc(ExecFuncArgs args);
    // Have to pad it on the right to mimic Z's parity bit (which last.z, being an address,
    // doesn't store).
    // It's important to get this data from args.z, rather than loading rZ directly, because
    // if there's an interrupt during the execution of TC, rZ won't be correct after we RESUME
    // and finish execution of the TC (rZ will be pointing to the address after the RESUME until the
    // TC finishes executing).
    Word zData = zeroExtend({args.z, 1'b0});

    return Exec2Writeback {
        eRes1: ?,
        // Note that "The Q register is set up with the address following the instruction.",
        // and Z already has the address following the instruction.
        eRes2: {?, {zData[15], zData[15:1]}},
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rQ,
        newZ: args.inst[12:1] + 1
    };
endfunction

// TCF
// The "Transfer Control to Fixed" instruction jumps to a memory location in fixed
// (as opposed to erasable) memory.
function Exec2Writeback tcf(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: args.inst[12:1] + 1
    };
endfunction

// TS
//The "Transfer to Storage" instruction copies the accumulator into memory ... and so much more.
function Exec2Writeback ts(ExecFuncArgs args);
    Word aResp = args.regResp[15:0];
    Bool hasOverflow = (aResp[15] != aResp[14]);
    Addr memAddr = {2'b0, args.inst[10:1]};

    Bit#(15) top = signExtend(aResp[15]);

    return Exec2Writeback {
        eRes1: {?, is16BitRegM(memAddr) ? aResp : {overflowCorrect(aResp), 1'b0}},
        // Bluespec doesn't seem to like {15'b(aResp[15]), 1'b(!aResp[15])}.
        eRes2: {?, {top, ~aResp[15]}},
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: (hasOverflow && (args.inst[10:1] != zeroExtend(rA))) ? tagged Valid rA : tagged Invalid,
        newZ: hasOverflow ? (args.z + 2) : (args.z + 1)
    };
endfunction

// READ, RAND, ROR, RXOR
// These are all IO instructions.  Sadly Bluespec doesn't have function passing, so we have
// to use a big case statement here instead of passing in operations in exec.  Oh well.
// A should be the IO channel response, B should be the reg (probably acc) response.
function Bit#(n) ioReadOp(InstNum instNum, Bit#(n) a, Bit#(n) b);
    case (instNum)
        READ: return a;
        RAND: return a & b;
        ROR: return a | b;
        RXOR: return a ^ b;
        // Really should never hit here
        default: return ?;
    endcase
endfunction

function Exec2Writeback ioRead(ExecFuncArgs args);
    Word aResp = is16BitChannel(args.inst[7:1]) ?
                 ioReadOp(args.instNum, args.memOrIOResp[15:0], args.regResp[15:0]) :
                 signExtend(ioReadOp(args.instNum, args.memOrIOResp[15:1], overflowCorrect(args.regResp[15:0])));

    return Exec2Writeback {
        eRes1: ?,
        eRes2: {?, aResp},
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// WRITE, WAND, WOR
// These are all IO instructions.  See the comment on ioReadOp for more info.
function Bit#(n) ioWriteOp(InstNum instNum, Bit#(n) a, Bit#(n) b);
    case (instNum)
        WRITE: return b;
        WAND: return a & b;
        WOR: return a | b;
        default: return ?;
    endcase
endfunction

// The "Write Channel KC" instruction moves the contents of the accumulator into an i/o channel.
function Exec2Writeback ioWrite(ExecFuncArgs args);
    IOChannel channel = args.inst[7:1];
    Bool is16Bits = is16BitChannel(channel);

    Word resp = is16Bits ?
                ioWriteOp(args.instNum, args.memOrIOResp[15:0], args.regResp[15:0]) :
                signExtend(ioWriteOp(args.instNum, args.memOrIOResp[15:1], overflowCorrect(args.regResp[15:0])));

    if (channel == 'O33) begin
        // Bits 11 through 15 are latched inputs, and we have to do this to keep their values  See comment
        // at https://github.com/virtualagc/virtualagc/blob/f1ff0cf084f65e1f0bf26d1621b91409cbe0ccac/yaAGC/agc_engine.c#L409.
        // Note that at this point we only care about the *bottom* 15 bits of resp (see below where
        // we take resp[14:0]).
        resp = resp | 'O76000;
    end

    return Exec2Writeback {
        eRes1: is16Bits ? {?, resp} : {?, resp[14:0], 1'b0},
        eRes2: {?, resp},
        memAddrOrIOChannel: tagged IOChannel channel,
        // Extra write to rA for WRITE doesn't hurt
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction


function Exec2Writeback unimplemented(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

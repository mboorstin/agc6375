import InterStage::*;
import Types::*;
import ArithUtil::*;

/*
TAGLSB: places dependent on the choice of LSB 0 for 15-bit memory in 16-bit words
TAGEXCEPTION: places with overflows/other exceptions to be implemented



*/

(* noinline *)
function Exec2Writeback exec(ExecFuncArgs args);
    //exec

    //pulling data out of inst
    Bit#(3) ccc = args.inst[15:13]; //primary opcode values
    //Bit#(13) addr = args.inst[12:0]; //all bits that may contain address info
    Bit#(2) qq = args.inst[12:11]; //secondary opcode values (qc values)
    Bit#(3) ppp = args.inst[12:10]; //secondary opcode values for IO instructions (pc values)


    //maybe there's a better way to set this up?  Either way, I'm so sorry.
    //extracode
    if (args.isExtended) begin
        //
        case(ccc)
            opIO: begin //corresponds to I/O instructions
                case(ppp)
                    qcioREAD: begin //READ
                        return ?;
                    end
                    qcioWRITE: begin //WRITE
                        return ?;
                    end
                    qcioRAND: begin //RAND
                        return ?;
                    end
                    qcioWAND: begin //WAND
                        return ?;
                    end
                    qcioROR: begin //ROR
                        return ?;
                    end
                    qcioWOR: begin //WOR
                        return ?;
                    end
                    qcioRXOR: begin //RXOR
                        return ?;
                    end
                    qcioEDRUPT: begin //EDRUPT
                        return ?;
                    end
                endcase
            end
            opDV: begin //corresponds to DV and BZF
                if (qq == qcDV) begin //DV
                    return ?;
                end
                else begin //BZF
                    return bzf(args);
                end
            end
            opMSU: begin //corresponds to MSU, QXCH, AUG, and DIM
                case(qq)
                    qcMSU: begin //MSU
                        return ?;
                    end
                    qcQXCH: begin //QXCH
                        return ?;
                    end
                    qcAUG: begin //AUG
                        return aug(args);
                    end
                    qcDIM: begin //DIM
                        return dim(args);
                    end
                endcase
            end
            opDCA: begin //DCA
                return ?;
            end
            opDCS: begin //DCS
                return ?;
            end
            opINDEX: begin //INDEX
                return ?;
            end
            opSU: begin //corresponds to SU and BZMF
                if  (qq == qcSU) begin //SU
                    return ?;
                end
                else begin //BZMF
                    return bzmf(args);
                end
            end
            opMP: begin //MP
                return ?;
            end
        endcase
    end
    else begin //not extracode
        case (ccc)
            opTC: begin //TC
                return ?;
            end
            opCCS: begin //corresponds to CCS and TCF
                if (qq == qcCCS) begin //CCS
                    return ccs(args);
                end
                else begin //TCF
                    return ?;
                end
            end
            opDAS: begin //corresponds to DAS, LXCH, INCR, and ADS
                case (qq)
                    qcDAS: begin //DAS
                        return ?;
                    end
                    qcLXCH: begin //LXCH
                        return lxch(args);
                    end
                    qcINCR: begin //INCR
                        return incr(args);
                    end
                    qcADS: begin //ADS
                        return ads(args);
                    end
                endcase
            end
            opCA: begin //CA
                return ca(args);
            end
            opCS: begin //CS
                return cs(args);
            end
            opINDEX: begin //corresponds to INDEX, DXCH, TS, XCH
                case (qq)
                    qcINDEX: begin //INDEX
                        return ?;
                    end
                    qcDXCH: begin //DXCH
                        return ?;
                    end
                    qcTS: begin //TS
                        return ?;
                    end
                    qcXCH: begin //XCH
                        return ?;
                    end
                endcase
            end
            opAD: begin //AD
                return ad(args);
            end
            opMASK: begin //MASK
                return mask(args);
            end
        endcase
    end

    //encoding output
    /*Exec2Writeback e2w = Exec2Writeback{
    eRes1:eRes1,
    eRes2:eRes2,
    memAddr:memAddr,
    regNum:regNum,
    newZ:newZ,
    };
    return e2w;*/

endfunction


//All of the functions to execute opcodes.
//these functions have the same information as Exec does.
//They should be inlined.

//add
//adds the contents of a memory location into the accumulator (rA)
function Exec2Writeback ad(ExecFuncArgs args);
    //address is 12 bits; not an extracode, so ignore LSB.
    //Addr k = args.inst[12:1];

    Word mem_resp = fromMaybe(?, args.memResp);
    Word reg_resp = fromMaybe(?, args.regResp);


    //mem_resp is the value to be added to the accumulator.
    //TAGLSB
    Word mem_val = {mem_resp[15], truncateLSB(mem_resp)};

    Word sum = addOnes(mem_val, reg_resp); //assume values are extended left

    if (sum[15] != sum[14]) begin
        //overflow-- TAGEXCEPTION
    end

    //return
    Exec2Writeback e2w = Exec2Writeback{
        eRes1:16'b0,
        eRes2:sum, //write sum back to accumulator only
        memAddr: tagged Invalid,
        regNum: tagged Valid rA, //accumulator
        newZ: tagged Invalid
    };
    return e2w;
endfunction

//add to storage
//adds the contents of a erasable memory location to the accumulator
//and stores the result back in both the accumulator and memory location.
function Exec2Writeback ads(ExecFuncArgs args);

    Word mem_resp = fromMaybe(?, args.memResp);
    Word reg_resp = fromMaybe(?, args.regResp);

    //mem_resp is the value to be added to the accumulator.
    //TAGLSB
    Word mem_val = {mem_resp[15], truncateLSB(mem_resp)};

    Word sum = addOnes(mem_val, reg_resp); //assume values are extended left

    if (sum[15] != sum[14]) begin
        //overflow-- TAGEXCEPTION
    end

    //return
    Addr mem_addr_wb = {2'b0, args.inst[10:1]}; //10 bit k, from instruction
    Exec2Writeback e2w = Exec2Writeback{
        eRes1:sum,
        eRes2:sum, //write sum back to both
        memAddr: tagged Valid mem_addr_wb,
        regNum: tagged Valid rA, //accumulator
        newZ: tagged Invalid
    };
    return e2w;
endfunction

// augment
// Increments a positive value in an erasable-memory location in-place by +1
// or a negative value by -1
// Parameterized helper function
function Bit#(n) addOrSub(Bit#(n) val);
    if (val[valueOf(TSub#(n, 1))] == 0) begin
        return addOnes(val, 1);
    end else begin
        return subOnes(val, 1);
    end
endfunction

function Exec2Writeback aug(ExecFuncArgs args);
    Word memResp = fromMaybe(?, args.memResp);

    Word auged;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        auged = addOrSub(memResp);
    end else begin
        // TAGLSB
        auged = {addOrSub(memResp[15:1]), 1'b0};
    end

    return Exec2Writeback {
        eRes1: auged,
        // Should be ? but setting to 0 to keep tests happy
        eRes2: 0,
        memAddr: tagged Valid memAddr,
        regNum: tagged Invalid,
        newZ: tagged Invalid
    };
endfunction

// Branch Zero to Fixed
// The "Branch Zero to Fixed" instruction jumps to a memory location
// in fixed (as opposed to erasable) memory if the accumulator is zero
function Exec2Writeback bzf(ExecFuncArgs args);
    // TAGEXCEPTION
    // I *think* this is the correct handling of overflow, but should check
    Word acc = fromMaybe(?, args.regResp);

    Bool doBranch = (acc[15] == acc[14]) && ((acc[14:0] == 0) || (acc[14:0] == ~0));

    Maybe#(Addr) newZ = doBranch ? tagged Valid args.inst[12:1] : tagged Invalid;

    return Exec2Writeback {
        eRes1: 0,
        eRes2: 0,
        memAddr: tagged Invalid,
        regNum: tagged Invalid,
        newZ: newZ
    };
endfunction

// Branch Zero or Minus to Fixed
// The "Branch Zero or Minus to Fixed" instruction jumps to a memory
// location in fixed (as opposed to erasable) memory if the accumulator is zero or negative.
function Exec2Writeback bzmf(ExecFuncArgs args);
    // TAGEXCEPTION
    // I *think* this is the correct handling of overflow, but should check
    Word acc = fromMaybe(?, args.regResp);

    Bool doBranch = (acc[15] == acc[14]) ? ((acc[14:0] == 0) || acc[14] == 1) : (acc[15:14] == 2'b10);

    Maybe#(Addr) newZ = doBranch ? tagged Valid args.inst[12:1] : tagged Invalid;

    return Exec2Writeback {
        eRes1: 0,
        eRes2: 0,
        memAddr: tagged Invalid,
        regNum: tagged Invalid,
        newZ: newZ
    };
endfunction

// Clear and Add
// The "Clear and Add" (or "Clear and Add Erasable" or "Clear and Add Fixed")
// instruction moves the contents of a memory location into the accumulator.
function Exec2Writeback ca(ExecFuncArgs args);
    Word memResp = fromMaybe(?, args.memResp);
    Addr memAddr = args.inst[12:1]; // TAGLSB

    // TAGLSB
    Word newAcc = is16BitRegM(memAddr) ? memResp : {memResp[15], memResp[15:1]};

    return Exec2Writeback {
        eRes1: 0,
        eRes2: newAcc,
        memAddr: tagged Invalid,
        regNum: tagged Valid rA,
        newZ: tagged Invalid
    };
endfunction

// Counct, Compare, and Skip
// The "Count, Compare, and Skip" instruction stores a variable from erasable memory into the
// accumulator (which is decremented), and then performs one of several jumps based on the original
// value of the variable.  This is the only "compare" instruction in the AGC instruction set.
function Exec2Writeback ccs(ExecFuncArgs args);
    Word memResp = fromMaybe(?, args.memResp);
    Addr memAddr = args.inst[12:1]; // TAGLSB

    Bool is16Bits = is16BitRegM(memAddr);

    // This makes two copies of the dABS logic - can we do better?
    Word dabs;
    if (is16Bits) begin
        dabs = dABS(memResp);
    end else begin
        dabs = {dABS(memResp[15:1]), 0};
    end

    // I think this is the correct interpretation of how to handle overflow here: just
    // ignore the fact that it exists, and treat A, L, and Q as 16 bits.  We basically treat
    // A, L, and Q as 15 bit registers, and then correct for the 1 cases where this is wrong
    // This could probably be made more efficient - we're choosing to do dynamic addition, but
    // might be worth the extra space and do static addition?  Unclear.  On the other hand, the
    // compiler can hopefully figure out that there are only 4 options for addend.
    Addr addend;

    // Note that positive numbers in 1's and 2's complement are the same
    // Be wary of changing the order of this logic - this is written in such a way that
    // the 16 bit value 1111111111111110 falls through to < -0, which saves us an A/L/Q fix,
    // even though it "should" be == -0
    // == +0
    if (dabs[15:1] == 0) begin
        addend = 2;
    // == -0
    end else if (dabs[15:1] == {1'b1, 0}) begin
        addend = 4;
    // > +0
    end else if (dabs[15] == 0) begin
        addend = 1;
    // < -0
    end else begin
        addend = 3;
    end

    // Fix A, L, and Q
    if (is16Bits && (memResp == 1)) begin
        addend = 1;
    end

    return Exec2Writeback {
        eRes1: 0,
        eRes2: dabs,
        memAddr: tagged Invalid,
        regNum: tagged Valid rA,
        newZ: tagged Valid addOnes(args.z, addend)
    };
endfunction

// Clear and Subtract
// The "Clear and Subtract" instruction moves the 1's-complement (i.e., the negative) of a memory location into
// the accumulator.
function Exec2Writeback cs(ExecFuncArgs args);
    Word memResp = fromMaybe(?, args.memResp);
    Addr memAddr = args.inst[12:1]; // TAGLSB

    Bit#(15) upper = ~memResp[15:1];

    Bool is16Bits = is16BitRegM(memAddr);

    Word acc = is16BitRegM(memAddr) ? {upper, ~memResp[0]} : signExtend(upper);

    return Exec2Writeback {
        eRes1: 0,
        eRes2: acc,
        memAddr: tagged Invalid,
        regNum: tagged Valid rA,
        newZ: tagged Invalid
    };
endfunction

// Diminish
// The "Diminish" instruction decrements a positive non-zero value in an
// erasable-memory location in-place, or increments a negative non-zero value.
// It's difficult to get this to share hardware with AUG because of the differing
// handling of +/- 0.  Code-wise, Bluespec doesn't allow function pointers, so it's
// not really worth the overhead of combining aug and dim.
// Parameterized helper function
function Bit#(n) subOrAddNonZero(Bit#(n) val);
    if ((val == 0) || (val == ~0)) begin
        return val;
    end else if (val[valueOf(TSub#(n, 1))] == 0) begin
        return subOnes(val, 1);
    end else begin
        return addOnes(val, 1);
    end
endfunction

function Exec2Writeback dim(ExecFuncArgs args);
    Word memResp = fromMaybe(?, args.memResp);

    Word dimmed;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        dimmed = subOrAddNonZero(memResp);
    end else begin
        // TAGLSB
        dimmed = {subOrAddNonZero(memResp[15:1]), 1'b0};
    end

    return Exec2Writeback {
        eRes1: dimmed,
        // Should be ? but setting to 0 to keep tests happy
        eRes2: 0,
        memAddr: tagged Valid memAddr,
        regNum: tagged Invalid,
        newZ: tagged Invalid
    };
endfunction

// INCR
// The "Increment" instruction increments an erasable-memory location in-place by +1.
function Exec2Writeback incr(ExecFuncArgs args);
    Word memResp = fromMaybe(?, args.memResp);

    Word auged;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        auged = addOnes(memResp, 1);
    end else begin
        // TAGLSB
        auged = {addOnes(memResp[15:1], 1), 1'b0};
    end

    return Exec2Writeback {
        eRes1: auged,
        // Should be ? but setting to 0 to keep tests happy
        eRes2: 0,
        memAddr: tagged Valid memAddr,
        regNum: tagged Invalid,
        newZ: tagged Invalid
    };
endfunction

// LXCH
// The "Exchange L and K" instruction exchanges the value in the L register with a
// value stored in erasable memory.
function Exec2Writeback lxch(ExecFuncArgs args);
    Word memResp = fromMaybe(?, args.memResp);
    Word lResp = fromMaybe(?, args.regResp);

    Addr memAddr = {2'b0, args.inst[10:1]};

    Bool is16Bits = is16BitRegM(memAddr);

    // TAGLSB
    Word newL = is16Bits ? memResp : signExtend(memResp[15:1]);
    // TAGEXCEPTION
    Word newMem = is16Bits ? lResp : {lResp[14:0], 0};

    return Exec2Writeback {
        eRes1: newMem,
        eRes2: newL,
        memAddr: tagged Valid memAddr,
        regNum: tagged Valid rL,
        newZ: tagged Invalid
    };
endfunction

// MASK
// The "Mask A by K" instruction logically ANDs the contents of a memory
// location bitwise into the accumulator.
function Exec2Writeback mask(ExecFuncArgs args);
    Word memResp = fromMaybe(?, args.memResp);
    Word aResp = fromMaybe(?, args.regResp);

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
        eRes1: 0,
        eRes2: newA,
        memAddr: tagged Invalid,
        regNum: tagged Valid rA,
        newZ: tagged Invalid
    };
endfunction
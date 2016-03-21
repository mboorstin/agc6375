import BRAM::*;
import Vector::*;

import MemInit::*;
import MemTypes::*;
import Types::*;

// Although RWMemAddr and ROMemAddr are both
// MemAddr's, it's nice for error checking to
// be able to tell them apart
typedef union tagged {
    Bit#(LNRegs) RegNum;
    MemAddr RWMemAddr;
    MemAddr ROMemAddr;
} RealMemAddr deriving(Eq, Bits, FShow);

typedef 8 EBanks;
typedef TLog#(EBanks) LEBanks;
typedef 256 EBankWords;
typedef TLog#(EBankWords) LEBankWords;

typedef 36 FBanks;
typedef TLog#(FBanks) LFBanks;
typedef 1024 FBankWords;
typedef TLog#(FBankWords) LFBankWords;

typedef 2048 FFWords;
typedef TLog#(FFWords) LFFWords;
// Real memory layout - note that we think of this
// in 16 bit (ie, word-addresssed) rather than in
// 32 bit (ie, dword-addressed) terms
typedef TMul#(EBanks, EBankWords) FBankStart;
typedef TAdd#(FBankStart, TMul#(FBanks, FBankWords)) FFStart;

(* synthesize *)
module mkAGCMemory(AGCMemory);
    // Main state: BRAM and regfile
    // TODO: Should probably allow passing in the BRAM instead of creating it here
    BRAM_Configure cfg = defaultValue;
    BRAM2PortBE#(DMemAddr, DoubleWord, TDiv#(DoubleWordSz, 8)) bram <- mkBRAM2ServerBE(cfg);
    MemInitIfc memInit <- mkMemInitBRAM(bram);

    Vector#(NRegs, Reg#(Word)) regs <- replicateM(mkRegU);
    Reg#(Bool) superbnk <- mkReg(False);

    // Convert an AGC4 12-bit memory address to either a register
    // number or a 16-bit internal MemAddr;
    function RealMemAddr toRealAddr(Addr addr);
        if (addr < fromInteger(valueOf(NRegs))) begin
            // Register
            return tagged RegNum truncate(addr);
        end else if (addr <= 'O1377) begin
            // Unswitched erasable
            // Goes directly to one of the lower 3 E banks
            // Note that we've already intercepted the registers
            // at the bottom of E0
            return tagged RWMemAddr zeroExtend(addr);
        end else if (addr <= 'O1777) begin
            // Switched erasable
            Bit#(LEBanks) ebank = truncate(regs[rEB] >> 8);
            Bit#(LEBankWords) addrInBank = truncate(addr);
            // Intercept the registers at the bottom of E0, otherwise
            // use the appropriate bank
            if ((ebank == 0) && (addrInBank < fromInteger(valueOf(NRegs)))) begin
                return tagged RegNum truncate(addrInBank);
            end else begin
                return tagged RWMemAddr zeroExtend({ebank, addrInBank});
            end
        end else if (addr <= 'O3777) begin
            // Common fixed
            Bit#(LFBanks) fbank = truncate(regs[rFB] >> 10);
            Bit#(LFBankWords) addrInBank = truncate(addr);
            // Lower banks are directly accessible via FB; upper ones
            // are switched via the FEB bit.
            if ((fbank >= 24) && superbnk) begin
                fbank = fbank + 8;
                // Banks 36 - 39 didn't physicall exist - we don't implement them
                //if (fbank >= 36) begin
                //    $display("Error - attempted to access nonexistent fixed bank %d", fbank);
                //    $finish();
                //end
            end
            return tagged ROMemAddr zeroExtend(fromInteger(valueOf(FBankStart)) + {fbank, addrInBank});
        end else begin
            // Fixed fixed - goes up to 4'O7777 = 2^12 - 1
            Bit#(LFFWords) ffAddr = truncate(addr);
            return tagged ROMemAddr zeroExtend(fromInteger(valueOf(FFStart)) + ffAddr);
        end
    endfunction

    interface IMemory imem;
        method Action req(Addr addr);

        endmethod

        method ActionValue#(Instruction) resp();
            return ?;
        endmethod

        interface MemInitIfc init = memInit;
    endinterface

    interface DMemoryFetcher fetcher;
        method Action memReq(Addr addr);

        endmethod

        method Action regReq(Addr addr);

        endmethod

        method ActionValue#(DoubleWord) memResp();
            return ?;
        endmethod

        method ActionValue#(DoubleWord) regResp();
            return ?;
        endmethod

        interface MemInitIfc init = memInit;
    endinterface

    interface DMemoryStorer storer;
        method Action memStore(Addr addr, DoubleWord data, Bool isDouble);

        endmethod

        method Action regStore(Addr addr, DoubleWord data, Bool isDouble);

        endmethod

        interface MemInitIfc init = memInit;
    endinterface

endmodule

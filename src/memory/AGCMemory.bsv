import BRAM::*;
import Vector::*;

import TopLevelIfaces::*;
import Ehr::*;
import Fifo::*;
import MemAndRegWrapper::*;
import MemInit::*;
import MemTypes::*;
import Types::*;

typedef 8 EBanks;
typedef TLog#(EBanks) LEBanks;
typedef 256 EBankWords;
typedef TLog#(EBankWords) LEBankWords;

typedef 36 FBanks;
typedef 5 LFBanks;
typedef 1024 FBankWords;
typedef TLog#(FBankWords) LFBankWords;

// Real memory layout
typedef TMul#(EBanks, EBankWords) FBankStart;

(* synthesize *)
// This is basically an MMU
module mkAGCMemory(AGCMemory);
    // Main state: BRAM and regFile
    BRAM_Configure cfg = defaultValue;
    // Load a VMH in simulation so we don't have to transfer it over SceMi
    `ifdef SIM
        cfg.loadFormat = Hex("program.vmh");
    `endif

    BRAM1Port#(MemAddr, Word) bram <- mkBRAM1Server(cfg);
    MemInitIfc memInit <- mkMemInitBRAM(bram);

    Vector#(NRegs, Ehr#(4, Word)) regFile <- replicateM(mkEhr(0));
    Reg#(Bool) superbankBit <- mkReg(False);

    // HACK: Write ports need to be first to keep pipeline FIFO's happy, and we know
    // iMemWrapper is never going to be used to write except for writeZImm,
    MemAndRegWrapper iMemWrapper <- mkMemAndRegWrapper(bram.portA, regFile, 1, 0, 0, 0);
    MemAndRegWrapper dMemWrapper <- mkMemAndRegWrapper(bram.portA, regFile, 3, 1 /*not actually used*/, 1, 2);

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
            return tagged MemAddr zeroExtend(addr);
        end else if (addr <= 'O1777) begin
            // Switched erasable
            Bit#(LEBanks) ebank = truncate(iMemWrapper.readRegImm(rEB) >> 9);
            Bit#(LEBankWords) addrInBank = truncate(addr);
            // Intercept the registers at the bottom of E0, otherwise
            // use the appropriate bank
            if ((ebank == 0) && (addrInBank < fromInteger(valueOf(NRegs)))) begin
                return tagged RegNum truncate(addrInBank);
            end else begin
                return tagged MemAddr zeroExtend({ebank, addrInBank});
            end
        end else begin
            // Switched fixed and fixed - fixed.
            Bit#(LFBanks) fbank;
            Bit#(LFBankWords) addrInBank = truncate(addr);
            // Switched fixed
            if (addr <= 'O3777) begin
                fbank = truncateLSB(iMemWrapper.readRegImm(rFB));
                // Lower banks are directly accessible via FB; upper ones
                // are switched via the FEB bit.
                if ((fbank >= 24) && superbankBit) begin
                    fbank = fbank + 8;
                    // Banks 36 - 39 didn't physically exist - we don't implement them
                    // TODO: HAVE A WARNING HERE!
                end
            end else if (addr <= 'O5777) begin
                // Lower half of fixed-fixed: really fixed bank 02
                fbank = 2;
            end else begin
                // Upper half of fixed-fixed: really fixed bank 03
                fbank = 3;
            end
            return tagged MemAddr zeroExtend(fromInteger(valueOf(FBankStart)) + {fbank, addrInBank});
        end
    endfunction

    interface IMemory imem;
        method Action req(Addr addr) if (memInit.done);
            iMemWrapper.readMem(toRealAddr(addr));
        endmethod

        method ActionValue#(Instruction) resp() if (memInit.done);
            Instruction ret <- iMemWrapper.memResp();
            return ret;
        endmethod

        method Word getZ() if (memInit.done);
            return iMemWrapper.readRegImm(rZ);
        endmethod

        method Action setZ(Word data) if (memInit.done);
            iMemWrapper.writeZImm(data);
        endmethod
    endinterface

    interface DMemoryFetcher fetcher;
        method Action memReq(Addr addr) if (memInit.done);
            dMemWrapper.readMem(toRealAddr(addr));
        endmethod

        method Action regReq(RegIdx idx) if (memInit.done);
            dMemWrapper.readReg(idx);
        endmethod

        method ActionValue#(Word) memResp() if (memInit.done);
            Instruction ret <- dMemWrapper.memResp();
            return ret;
        endmethod

        method ActionValue#(Word) regResp() if (memInit.done);
            Instruction ret <- dMemWrapper.regResp();
            return ret;
        endmethod
    endinterface

    interface DMemoryStorer storer;
        method Action memStore(Addr addr, Word data) if (memInit.done);
            dMemWrapper.writeMem(toRealAddr(addr), data);
        endmethod

        method Action regStore(RegIdx idx, Word data) if (memInit.done);
            dMemWrapper.writeReg(idx, data);
        endmethod
    endinterface

    interface SuperbankProvider superbank;
        method Action set(Word data) if (memInit.done);
            superbankBit <= (data[7] == 1);
        endmethod

        method Word get() if (memInit.done);
            return {0, superbankBit ? 1'b1 : 1'b0, 7'b0};
        endmethod
    endinterface

    interface MemInitIfc init = memInit;

endmodule

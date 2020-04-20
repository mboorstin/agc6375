
import BRAM::*;
import Vector::*;

import ArithUtil::*;
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
typedef TLog#(FBanks) LFBanks;
typedef 1024 FBankWords;
typedef TLog#(FBankWords) LFBankWords;

// Real memory layout
typedef TMul#(EBanks, EBankWords) FBankStart;

// Cycles per 1 ms.  On my Toshiba laptop in simulation it comes out to about 350.  Should figure out a better way of estimating this (perhaps a demo program),
// and how to get the clock timing in FPGAs.
typedef 350 TICKS_PER_MS;
// Cycles per 500 us (useful to get the 7.5ms).
typedef TDiv#(TICKS_PER_MS, 2) TICKS_PER_500US;

(* synthesize *)
// This is basically an MMU
module mkAGCMemory(AGCMemory);
    // Main state: BRAM and regFile
    BRAM_Configure cfg = defaultValue;
    `ifdef SIM
        // Load a VMH in simulation so we don't have to transfer it over SceMi
        // It's difficult to pass environment variables into Bluesim ($test$plusargs exists
        // but $value$plusargs does not), so instead the Makefile symlinks the requested program
        // to load at path PROGRAM_PATH.
        cfg.loadFormat = Hex(`PROGRAM_PATH);
    `endif

    BRAM1Port#(MemAddr, Word) bram <- mkBRAM1Server(cfg);
    MemInitIfc memInit <- mkMemInitBRAM(bram);

    Vector#(NRegs, Ehr#(5, Word)) regFile <- replicateM(mkEhr(0));
    Reg#(Bool) superbankBit <- mkReg(False);

    // Start this at 1 to skip the initial T3 increment so its first fire is 10ms after startup.
    Reg#(Bit#(19)) masterTimer <- mkReg(0);
    Reg#(Bool) t3IRUPT <- mkReg(False);
    Reg#(Bool) t4IRUPT <- mkReg(False);
    Reg#(Bool) t5IRUPT <- mkReg(False);
    Reg#(Bool) downrupt <- mkReg(False);

    // HACK: Write ports need to be first to keep pipeline FIFO's happy, and we know
    // iMemWrapper is never going to be used to write except for writeZImm,
    MemAndRegWrapper iMemWrapper <- mkMemAndRegWrapper(bram.portA, regFile, 1, 0, 0, 0);
    MemAndRegWrapper dMemWrapper <- mkMemAndRegWrapper(bram.portA, regFile, 3, 1 /*not actually used*/, 1, 2);

    // Trigger timers when necessary.  One cycle of masterTimer takes 10 ms.  T1, T3, T4, and T5 are *incremented* every 10ms.
    // T1 (and its associated T2) don't cause interrupts, so we can increment them at the same time as T3.
    // T5 canonically increments 5ms after T3, and T4 canonically increments 7.5ms after T3 (T3-T5 fire when overflowed, but
    // software usually resets them very close to the overflow point to get a faster fire).  DOWNRUPT *fires* every 20ms.  This
    // loop takes 20ms, so we increment T3 at 0 and 10ms, increment T4 at 7.5ms and 17.5ms, increment T5 at 5 ms and 15ms, and fire
    // DOWNRUPT at 13ms.  There's no guidance for when exactly DOWNRUPT fires so we've chosen 13 to do our best to space things out.
    // TODO: Make this logic more elegant and figure out how to templatize it
    rule tick(memInit.done);
        Bit#(19) newTime = masterTimer + 1;
        if ((masterTimer == 0) ||
            (masterTimer == fromInteger(valueOf(TMul#(10, TICKS_PER_MS))))) begin
            // 0ms and 10ms: Increment T1 and T3

            // T1
            Bit#(15) newT1 = addOnesUncorrected(regFile[rTIME1][4][15:1], zeroExtend(1'b1));
            // Overflow, so increment T2
            if (newT1 == {1'b1, 0}) begin
                newT1 = 0;
                // Note that TIME2 is only 14 bits, not 15 as usual
                regFile[rTIME2][4] <= {zeroExtend(addOnesUncorrected(regFile[rTIME2][4][14:1], zeroExtend(1'b1))), 1'b0};
            end
            regFile[rTIME1][4] <= {newT1, 1'b0};

            // T3
            Bit#(15) newVal = addOnesUncorrected(regFile[rTIME3][4][15:1], zeroExtend(1'b1));
            // Ie, overflowed into negatives
            if (newVal == {1'b1, 0}) begin
                t3IRUPT <= True;
                newVal = 0;
            end
            regFile[rTIME3][4] <= {newVal, 1'b0};
        end else if ((masterTimer == fromInteger(valueOf(TAdd#(TMul#(7, TICKS_PER_MS), TICKS_PER_500US)))) ||
                     (masterTimer == fromInteger(valueOf(TAdd#(TMul#(17, TICKS_PER_MS), TICKS_PER_500US))))) begin
            // 7.5ms and 17.5ms: Increment T4

            Bit#(15) newVal = addOnesUncorrected(regFile[rTIME4][4][15:1], zeroExtend(1'b1));
            // Ie, overflowed into negatives
            if (newVal == {1'b1, 0}) begin
                t4IRUPT <= True;
                newVal = 0;
            end
            regFile[rTIME4][4] <= {newVal, 1'b0};
        end else if ((masterTimer == fromInteger(valueOf(TMul#(5, TICKS_PER_MS)))) ||
                     (masterTimer == fromInteger(valueOf(TMul#(15, TICKS_PER_MS))))) begin
            // 5ms and 15ms: Increment T5

            Bit#(15) newVal = addOnesUncorrected(regFile[rTIME5][4][15:1], zeroExtend(1'b1));
            // Ie, overflowed into negatives
            if (newVal == {1'b1, 0}) begin
                t5IRUPT <= True;
                newVal = 0;
            end
            regFile[rTIME5][4] <= {newVal, 1'b0};
        end else if (masterTimer == fromInteger(valueOf(TMul#(13, TICKS_PER_MS)))) begin
            // 13: Fire Downrupt

            downrupt <= True;
        end else if (masterTimer == fromInteger(valueOf(TMul#(20, TICKS_PER_MS)))) begin
            // 20ms: Reset the loop

            newTime = 0;
        end

        masterTimer <= newTime;
    endrule

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
                // We want the top 5 bits from FB; the 6th bit is only needed for possible
                // overflow when we check the superbankBit below.
                fbank = {1'b0, truncateLSB(iMemWrapper.readRegImm(rFB))};
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
            return tagged MemAddr (fromInteger(valueOf(FBankStart)) + {fbank, addrInBank});
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

        method Bool hasOverflows() if (memInit.done);
            return dMemWrapper.hasOverflows();
        endmethod

        method Word readRegImm(RegIdx idx) if (memInit.done);
            return dMemWrapper.readRegImm(idx);
        endmethod

        method Addr getZRUPT() if (memInit.done);
            return dMemWrapper.getZRUPT();
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

    interface TimerProvider timers;
        method Bool t3IRUPT() if (memInit.done);
            return t3IRUPT;
        endmethod

        method Action clearT3IRUPT() if (memInit.done);
            t3IRUPT <= False;
        endmethod

        method Bool t4IRUPT() if (memInit.done);
            return t4IRUPT;
        endmethod

        method Action clearT4IRUPT() if (memInit.done);
            t4IRUPT <= False;
        endmethod

        method Bool t5IRUPT() if (memInit.done);
            return t5IRUPT;
        endmethod

        method Action clearT5IRUPT() if (memInit.done);
            t5IRUPT <= False;
        endmethod

        method Bool downrupt() if (memInit.done);
            return downrupt;
        endmethod

        method Action clearDOWNRUPT() if (memInit.done);
            downrupt <= False;
        endmethod
    endinterface

    interface MemInitIfc init = memInit;

endmodule

import Vector::*;

import ArithUtil::*;
import TopLevelIfaces::*;
import Types::*;

// Cycles per 1 ms.  On my Toshiba laptop in simulation it comes out to about 350.  Should figure out a better way of estimating this (perhaps a demo program),
// and how to get the clock timing in FPGAs.
// TODO: Speed me back up
typedef 350 TICKS_PER_MS;
// Cycles per 500 us (useful to get the 7.5ms).
typedef TDiv#(TICKS_PER_MS, 2) TICKS_PER_500US;

module mkAGCTimers(RegisterPort regPort, InternalIO internalIO, MemInitIfc init, AGCTimers ifc);

    // Start this at 1 to skip the initial T3 increment so its first fire is 10ms after startup.
    Reg#(Bit#(19)) masterTimer <- mkReg(0);
    Vector#(NInterrupts, Reg#(Bool)) interrupts <- replicateM(mkReg(False));

    // Trigger timers when necessary.  One cycle of masterTimer takes 10 ms.  T1, T3, T4, and T5 are *incremented* every 10ms.
    // T1 (and its associated T2) don't cause interrupts, so we can increment them at the same time as T3.
    // T5 canonically increments 5ms after T3, and T4 canonically increments 7.5ms after T3 (T3-T5 fire when overflowed, but
    // software usually resets them very close to the overflow point to get a faster fire).  DOWNRUPT *fires* every 20ms.  This
    // loop takes 20ms, so we increment T3 at 0 and 10ms, increment T4 at 7.5ms and 17.5ms, increment T5 at 5 ms and 15ms, and fire
    // DOWNRUPT at 13ms.  There's no guidance for when exactly DOWNRUPT fires so we've chosen 13 to do our best to space things out.
    // TODO: Make this logic more elegant and figure out how to templatize it
    rule tick(init.done);
        Bit#(19) newTime = masterTimer + 1;
        if ((masterTimer == 0) ||
            (masterTimer == fromInteger(valueOf(TMul#(10, TICKS_PER_MS))))) begin
            // 0ms and 10ms: Increment T1 and T3

            // T1
            Bit#(15) newT1 = addOnesUncorrected(regPort[rTIME1][15:1], zeroExtend(1'b1));
            // Overflow, so increment T2
            if (newT1 == {1'b1, 0}) begin
                newT1 = 0;
                // Note that TIME2 is only 14 bits, not 15 as usual
                Word newT2 = {zeroExtend(addOnesUncorrected(regPort[rTIME2][14:1], zeroExtend(1'b1))), 1'b0};
                regPort[rTIME2] <= newT2;
            end
            regPort[rTIME1] <= {newT1, 1'b0};

            // T3
            Bit#(15) newVal = addOnesUncorrected(regPort[rTIME3][15:1], zeroExtend(1'b1));
            // Ie, overflowed into negatives
            if (newVal == {1'b1, 0}) begin
                interrupts[ruptT3] <= True;
                newVal = 0;
            end
            regPort[rTIME3] <= {newVal, 1'b0};
        end else if ((masterTimer == fromInteger(valueOf(TAdd#(TMul#(7, TICKS_PER_MS), TICKS_PER_500US)))) ||
                     (masterTimer == fromInteger(valueOf(TAdd#(TMul#(17, TICKS_PER_MS), TICKS_PER_500US))))) begin
            // 7.5ms and 17.5ms: Increment T4

            Bit#(15) newVal = addOnesUncorrected(regPort[rTIME4][15:1], zeroExtend(1'b1));
            // Ie, overflowed into negatives
            if (newVal == {1'b1, 0}) begin
                interrupts[ruptT4] <= True;
                newVal = 0;
            end
            regPort[rTIME4] <= {newVal, 1'b0};
        end else if ((masterTimer == fromInteger(valueOf(TMul#(5, TICKS_PER_MS)))) ||
                     (masterTimer == fromInteger(valueOf(TMul#(15, TICKS_PER_MS))))) begin
            // 5ms and 15ms: Increment T5

            Bit#(15) newVal = addOnesUncorrected(regPort[rTIME5][15:1], zeroExtend(1'b1));
            // Ie, overflowed into negatives
            if (newVal == {1'b1, 0}) begin
                interrupts[ruptT5] <= True;
                newVal = 0;
            end
            regPort[rTIME5] <= {newVal, 1'b0};
        end else if (masterTimer == fromInteger(valueOf(TMul#(13, TICKS_PER_MS)))) begin
            // 13: Fire Downrupt

            interrupts[ruptDown] <= True;
        end else if (masterTimer == fromInteger(valueOf(TMul#(20, TICKS_PER_MS)))) begin
            // 20ms: Reset the loop

            newTime = 0;
        end

        masterTimer <= newTime;
    endrule


    // T6 increments every 1/1600th of a second, or every 0.625 ms.  It seems to be allowed to fire concurrently with
    // the other timers, so it gets its own rule.  Note that masterTimer lasts 20ms; conveniently 20 / 0.625 = 32, so
    // this just needs to fire when masterTimer % 32 = 0.  This function implements the DINC "unprogrammed sequence",
    // though for now there's no reason to output the ZOUT, POUT, or MOUT signals since there's nothing to do with them.
    rule tickT6(init.done && (masterTimer % 32 == 0) && (internalIO.readImm('O13)[15] == 1));
        Bit#(15) t6 = regPort[rTIME6][15:1];

        if ((t6 == 0) || (t6 == ~0)) begin
            // +/-0, so fire the interrupt and disable T6
            interrupts[ruptT6] <= True;
            Word newChan13 = {1'b0, internalIO.readImm('O13)[14:0]};
            internalIO.write('O13, newChan13);
        end else begin
            // Otherwise, move it closer to zero
            regPort[rTIME6] <= {subOrAddNonZero(t6), 1'b0};
        end
    endrule

    method Bool interruptNeeded(InterruptIdx interrupt);
        return interrupts[interrupt];
    endmethod

    method Action clearInterrupt(InterruptIdx interrupt);
        interrupts[interrupt] <= False;
    endmethod

endmodule

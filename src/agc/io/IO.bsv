import BRAM::*;
import Vector::*;

import Fifo::*;
import InterStage::*;
import TopLevelIfaces::*;
import Types::*;

// It's extremely important to use DMemory's memReq, memResp, and memStore methods to
// get/set rL and rQ here, because they're the only ones we're guaranteed to not have
// a conflict with (because we can never request IO and memory in the same instruction)

module mkAGCIO(DMemoryFetcher fetcher, DMemoryStorer storer, SuperbankProvider superbank, MemInitIfc init, AGCIO ifc);
    // We use a 128 word BRAM to buffer the state of the IO
    // channels, since we obviously can't have a bunch of physical
    // wires that the AGC can read from at will
    // Note that we use the same convention as main memory: bottom bit is parity.
    // This is initialized by the testbench.

    Vector#(NIOChannels, Reg#(Word)) ioBuffer <- replicateM(mkReg(0));
    Vector#(NIOChannels, Reg#(IOMask)) ioMasks <- replicateM(mkReg(15'h7FFF));

    // Keep track of the interrupts we need to throw
    Vector#(NIOInterrupts, Reg#(Bool)) interrupts <- replicateM(mkReg(False));
    // Whether or not the hand controller is in detent (needed for I/O channel 031)
    Reg#(Bool) inDetent <- mkReg(True);

    // It's important to use a bypass FIFO here so requests
    // can go out ASAP
    // TODO: Might want to increase the size of this if SceMI turns
    // out to be really slow.
    Fifo#(2, IOPacket) agcToHostQ <- mkPipelineFifo();

    Fifo#(2, Word) ioDelayed <- mkCFFifo();

    interface HostIO hostIO;
        method ActionValue#(IOPacket) agcToHost if (init.done);
            agcToHostQ.deq();
            return agcToHostQ.first();
        endmethod

        // There's not much point to putting a FIFO in front
        // of this as a buffer, because then you'd only be able
        // to do one queue a cycle instead of one BRAM request
        // We don't need to worry about rL and rQ here because they're not
        // I/O channels so external things aren't allowed to write to them
        method Action hostToAGC(IOPacket packet);

            if (packet.u) begin
                ioMasks[packet.channel] <= packet.data[14:0];
            end else begin
                IOMask newVal = (ioBuffer[packet.channel][15:1] & ~ioMasks[packet.channel]) | packet.data[14:0];
                ioBuffer[packet.channel] <= {newVal, 1'b0};

                // Check for interrupts we need to throw
                case (packet.channel)
                    // DSKY (015) and thruster panel (032) use the same interrupt
                    'O15: interrupts[ruptDSKY] <= True;
                    'O31: begin
                        // Only fire if transitioning from in detent to not in detent
                        // Top bit is 0 if not in detent; 1 if in detent
                        Bool newInDetent = unpack(packet.data[14]);
                        if (inDetent && !newInDetent) begin
                            $display("Firing ruptHand");
                            interrupts[ruptHand] <= True;
                        end
                        inDetent <= newInDetent;
                    end
                    'O32: interrupts[ruptDSKY] <= True;
                    // 166-170 are fake channels that VirtualAGC software uses to mimic the hand controller
                    // TODO: Need to re-emit on an output channel?
                    'O166: storer.memStore(zeroExtend(rRHCP), {packet.data[14:0], 1'b0});
                    'O167: storer.memStore(zeroExtend(rRHCY), {packet.data[14:0], 1'b0});
                    'O170: storer.memStore(zeroExtend(rRHCR), {packet.data[14:0], 1'b0});
                endcase
            end
        endmethod
    endinterface

    interface InternalIO internalIO;
        method Word readImm(IOChannel channel) if (init.done);
            return ioBuffer[channel];
        endmethod

        method Action readReq(IOChannel channel) if (init.done);
            Bool lOrQ = is16BitChannel(channel);
            if (lOrQ) begin
                fetcher.memReq(zeroExtend(channel));
            end else if (channel == 7) begin
                ioDelayed.enq(superbank.get());
            end else begin
                ioDelayed.enq(ioBuffer[channel]);
            end
        endmethod

        method ActionValue#(Word) readResp() if (init.done);
            Word ret;
            if (ioDelayed.notEmpty) begin
                ret = ioDelayed.first();
                ioDelayed.deq();
            end else begin
                ret <- fetcher.memResp();
            end
            return ret;
        endmethod

        method Action write(IOChannel channel, Word data) if (init.done);
            Bool lOrQ = is16BitChannel(channel);
            if (lOrQ) begin
                storer.memStore(zeroExtend(channel), data);
            end else if (channel == 7) begin
                superbank.set(data);
            end else begin
                agcToHostQ.enq(IOPacket{channel: channel, data: {1'b0, data[15:1]}, u: False});
                ioBuffer[channel] <= data;
            end
        endmethod

        method Bool interruptNeeded(IOInterruptIdx interrupt);
            return interrupts[interrupt];
        endmethod

        method Action clearInterrupt(IOInterruptIdx interrupt);
            interrupts[interrupt] <= False;
        endmethod
    endinterface
endmodule

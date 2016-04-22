import BRAM::*;

import Fifo::*;
import InterStage::*;
import TopLevelIfaces::*;
import Types::*;

// It's extremely important to use DMemory's memReq, memResp, and memStore methods to
// get/set rL and rQ here, because they're the only ones we're guaranteed to not have
// a conflict with (because we can never request IO and memory in the same instruction)

module mkAGCIO(DMemoryFetcher fetcher, DMemoryStorer storer, AGCIO ifc);
    // We use a 128 word BRAM to buffer the state of the IO
    // channels, since we obviously can't have a bunch of physical
    // wires that the AGC can read from at will
    // Note that we use the same convention as main memory: bottom bit is parity.
    // This is initialized by the testbench.
    BRAM_Configure cfg = defaultValue;
    BRAM2Port#(IOChannel, Word) ioBuffer <- mkBRAM2Server(cfg);

    // It's important to use a bypass FIFO here so requests
    // can go out ASAP
    // TODO: Might want to increase the size of this if SceMI turns
    // out to be really slow.
    Fifo#(2, IOPacket) agcToHostQ <- mkBypassFifo;

    // There's almost certainly some way of interrogating the modules concerned
    // to see if they have responses, but this seems cleaner
    Reg#(Bool) respFromFetcher <- mkReg(False);

    interface HostIO hostIO;
        method ActionValue#(IOPacket) agcToHost;
            agcToHostQ.deq();
            return agcToHostQ.first();
        endmethod

        // There's not much point to putting a FIFO in front
        // of this as a buffer, because then you'd only be able
        // to do one queue a cycle instead of one BRAM request
        // We don't need to worry about rL and rQ here because they're not
        // I/O channels so external things aren't allowed to write to them
        method Action hostToAGC(IOPacket packet);
            ioBuffer.portA.request.put(BRAMRequest{
                write: True,
                responseOnWrite: False,
                address: packet.channel,
                datain: {packet.data[14:0], 1'b0}
            });
        endmethod
    endinterface

    interface InternalIO internalIO;
        method Action readReq(IOChannel channel);
            Bool lOrQ = is16BitChannel(channel);
            respFromFetcher <= lOrQ;
            if (lOrQ) begin
                fetcher.memReq(zeroExtend(channel));
            end else begin
                ioBuffer.portB.request.put(BRAMRequest{
                    write: False,
                    responseOnWrite: False,
                    address: channel,
                    datain: ?
                });
            end
        endmethod

        method ActionValue#(Word) readResp();
            Word ret <- respFromFetcher ? fetcher.memResp() : ioBuffer.portB.response.get();
            return ret;
        endmethod

        method Action write(IOChannel channel, Word data);
            Bool lOrQ = is16BitChannel(channel);
            if (lOrQ) begin
                storer.memStore(zeroExtend(channel), data);
            end else begin
                agcToHostQ.enq(IOPacket{channel: channel, data: {1'b0, data[15:1]}});
                ioBuffer.portB.request.put(BRAMRequest{
                    write: True,
                    responseOnWrite: False,
                    address: channel,
                    datain: data
                });
            end
        endmethod
    endinterface

endmodule

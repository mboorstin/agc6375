import BRAM::*;

import Fifo::*;
import InterStage::*;
import TopLevelIfaces::*;
import Types::*;

module mkAGCIO(AGCIO);
    // We use a 128 word BRAM to buffer the state of the IO
    // channels, since we obviously can't have a bunch of physical
    // wires that the AGC can read from at will
    BRAM_Configure cfg = defaultValue;
    // TODO: Does this need to be initialized?
    BRAM2Port#(IOChannel, Word) ioBuffer <- mkBRAM2Server(cfg);

    // It's important to use a bypass FIFO here so requests
    // can go out ASAP
    // TODO: Might want to increase the size of this if SceMI turns
    // out to be really slow.
    Fifo#(2, IOPacket) agcToHostQ <- mkBypassFifo;

    interface HostIO hostIO;
        method ActionValue#(IOPacket) agcToHost;
            agcToHostQ.deq();
            return agcToHostQ.first();
        endmethod

        // There's not much point to putting a FIFO in front
        // of this as a buffer, because then you'd only be able
        // to do one queue a cycle instead of one BRAM request
        method Action hostToAGC(IOPacket packet);
            ioBuffer.portA.request.put(BRAMRequest{
                write: True,
                responseOnWrite: False,
                address: packet.channel,
                datain: packet.data
            });
        endmethod
    endinterface

    interface InternalIO internalIO;
        // TODO: Do memory mapping here!
        method Action readReq(IOChannel channel);
            ioBuffer.portB.request.put(BRAMRequest{
                write: False,
                responseOnWrite: False,
                address: channel,
                datain: ?
            });
        endmethod

        method ActionValue#(Word) readResp();
            Word ret <- ioBuffer.portB.response.get;
            return ret;
        endmethod

        method Action write(IOChannel channel, Word data);
            agcToHostQ.enq(IOPacket{channel: channel, data: data});
            ioBuffer.portB.request.put(BRAMRequest{
                write: True,
                responseOnWrite: False,
                address: channel,
                datain: data
            });
        endmethod
    endinterface

endmodule

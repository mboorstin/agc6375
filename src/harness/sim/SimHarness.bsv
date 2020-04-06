import CharIO :: *;
import GetPut::*;
import MasterSlave :: *;
import SourceSink :: *;
import Vector::*;

import FourCycle::*;
import Types::*;

// A harness designed to run the AGC in simulation.  For 6.375 we ran host-to-AGC communication
// over SceMI, but the SceMI module for Bluespec is still closed-source.  Thus, we just use our
// own very simple protocol over a UNIX socket.  For now all of it is here; depending on what the
// FPGA harnesses look like we may split some of this out.  Refer to the README for a high-level
// listing of which functions harnesses need to implement.  Note that AGC words (2 bytes) are big-endian,
// and we use big-endian for addresses and data in this protocol as well.
// In theory send and receive commands should be able to overlap (since each will only be sent in
// one direction), but it will be very confusing if we ever move to a more complicated transport.
//
// InitLoad:  0x01 [2 byte address] [2 byte data]
// InitDone:  0x02
// Start:     0x03 [2 byte address]
// HostToAGC: 0x04 [[1 bit u] [7 bits channel]] [2 byte data].
// AGCToHost: 0x05 [[1 bit always 0] [7 bits channel]] [2 byte data].

typedef enum {
    // Leaving 0 open because it makes it a little easier to look at when debugging
    Invalid   = 0,
    InitLoad  = 1,
    InitDone  = 2,
    Start     = 3,
    HostToAGC = 4,
    AGCToHost = 5
} Command deriving (Eq, Bits, FShow);

typedef 5 ReadBufSz;

(* synthesize *)
module mkSimHarness ();

    // The AGC itself
    AGC agc <- mkAGC();

    // CharIO module for socket communication
    CharIO charIO <- mkSocketCharIO("AGCHarness", `SIM_HARNESS_PORT);

    // Read buffer: We only need a total of 5 bytes for the read buffer.  Different commands
    // have different lengths so it's easier to use our own Buffer rather than using the
    // built-in ones.
    Vector#(ReadBufSz, Reg#(Bit#(8))) readBuf <- replicateM(mkReg(0));
    // Points to the next entry to fill in.  Needs to be able to point one past the buffer size
    // to indicate that it's full.
    Reg#(Bit#(TLog#(TAdd#(ReadBufSz, 1)))) readBufLoc <- mkReg(0);

    function Command currentCommand();
        return unpack(truncate(readBuf[0]));
    endfunction

    // Bluespec's rule evaluation makes it difficult to read and execute in a single rule, because
    // some of the AGC methods have guards on them that, when invalid, block the entire rule.  In theory
    // the (* split *) directive is supposed to allow ignoring them but I haven't been able to get
    // it to work, and anyway this is arguably more elegant.  So, there's a rule for reading and then
    // a rule for each command.  The command rules conflict with readNextByte because they all write to
    // readBufLoc, so they're set to higher precedence (thus preventing readNextByte from overwriting the buffer
    // in a cycle if they're reading it).
    (* descending_urgency = "doHostToAGC, doStart, doInitDone, doInitLoad, readNextByte" *)
    rule readNextByte;
        Bit#(8) data <- get(charIO.source);
        readBuf[readBufLoc] <= data;
        readBufLoc <= readBufLoc + 1;
    endrule

    rule doInitLoad((currentCommand() == InitLoad) && (readBufLoc == 5));
        $display("[Harness] Passing InitLoad to AGC");
        agc.memInit.request.put(tagged InitLoad MemInitLoad{
            addr: {readBuf[1], readBuf[2]},
            data: {readBuf[3], readBuf[4]}
        });
        readBufLoc <= 0;
    endrule

    rule doInitDone((currentCommand() == InitDone) && (readBufLoc == 1));
        $display("[Harness] Passing InitDone to AGC");
        agc.memInit.request.put(InitDone);
        readBufLoc <= 0;
    endrule

    rule doStart((currentCommand() == Start) && (readBufLoc == 3));
        $display("[Harness] Passing Start to AGC");
        agc.start({truncate(readBuf[1]), readBuf[2]});
        readBufLoc <= 0;
    endrule

    rule doHostToAGC((currentCommand() == HostToAGC) && (readBufLoc ==  5));
        $display("[Harness] Passing HostToAGC to AGC");
        // TODO!
        readBufLoc <= 0;
    endrule

    // TODO: Write rule!
endmodule

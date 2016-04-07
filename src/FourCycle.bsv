import AGCMemory::*;
import Decode::*;
import Exec::*;
import Fifo::*;
import InterStage::*;
import IO::*;
import TopLevelIfaces::*;
import Types::*;

typedef enum {
    Init,
    Fetch,
    Decode,
    Exec,
    Writeback,
    Finished
} Stage deriving(Eq, Bits, FShow);

(* synthesize *)
module mkAGC(AGC);
    // General state
    AGCMemory memory <- mkAGCMemory();
    AGCIO io <- mkAGCIO();

    // Stage management
    Reg#(Stage) stage <- mkReg(Init);
    Fifo#(2, Fetch2Decode) f2d <- mkPipelineFifo;
    Fifo#(2, Decode2Exec) d2e <- mkPipelineFifo;
    Fifo#(2, Exec2Writeback) e2w <- mkPipelineFifo;

    // Random flags
    Reg#(Maybe#(Word)) indexAddend <- mkReg(tagged Invalid);
    Reg#(Bool) isExtended <- mkReg(False);

    // TODO: Handle appropriately!
    function Instruction handleIndex(Instruction inst);
        return inst;
    endfunction

    rule fetch((stage == Fetch) && memory.init.done);
        $display("\n\nFetch");
        // Get the PC
        Word z = memory.imem.getZ();

        // Get the actual address out of Z
        // TAGLSB
        Addr zAddr = z[12:1];

        // Fire the load request
        memory.imem.req(zAddr);

        // Notify decode of the address
        f2d.enq(Fetch2Decode{z: zAddr});

        // And set the new stage
        stage <= Decode;
    endrule

    rule decode((stage == Decode) && memory.init.done);
        $display("Decode");
        // Get the addr from Fetch
        Fetch2Decode last = f2d.first();
        $display("f2d.first: ", fshow(last));
        f2d.deq();

        // Get the instruction from memory
        Instruction inst <- memory.imem.resp();

        // Add the index to it if necessary
        inst = handleIndex(inst);

        // Do the decode
        DecodeRes decoded = decode(inst, isExtended);

        $display("Decoded instruction: ", fshow(decoded.instNum));

        // Do the memory and IO requests
        MemOrIODeq deqFromMemOrIO = None;
        if (decoded.memAddrOrIOChannel matches tagged Addr .addr) begin
           memory.fetcher.memReq(addr);
           deqFromMemOrIO = Mem;
        end else if (decoded.memAddrOrIOChannel matches tagged IOChannel .channel) begin
            io.internalIO.readReq(channel);
            deqFromMemOrIO = IO;
        end

        if (isValid(decoded.regNum)) begin
            memory.fetcher.regReq(fromMaybe(?, decoded.regNum));
        end

        // Set state flags if necessary
        if (decoded.instNum == EXTEND) begin
            isExtended <= True;
        end else if (decoded.instNum != INDEX) begin
            isExtended <= False;
        end

        // Notify execute
        d2e.enq(Decode2Exec{
            z: last.z,
            inst: inst,
            instNum: decoded.instNum,
            deqFromMemOrIO: deqFromMemOrIO,
            deqFromReg: isValid(decoded.regNum)
        });

        // Set the new stage
        if (decoded.instNum == EDRUPT) begin
            $display("Got EDRUPT!");
            stage <= Finished;
        end else begin
            stage <= Exec;
        end

    endrule

    rule execute((stage == Exec) && memory.init.done);
        $display("Execute");
        // Get the data from decode
        Decode2Exec last = d2e.first();
        $display("d2e.first: ", fshow(last));
        d2e.deq();

        // Get the memory responses if necessary.
        // Doing if's because of ActionValue sadness
        Maybe#(Word) memOrIOResp;
        if (last.deqFromMemOrIO == Mem) begin
            let memResp <- memory.fetcher.memResp();
            memOrIOResp = tagged Valid memResp;
        end else if (last.deqFromMemOrIO == IO) begin
            let ioResp <- io.internalIO.readResp();
            memOrIOResp = tagged Valid ioResp;
        end else begin
            memOrIOResp = tagged Invalid;
        end

        Maybe#(Word) regResp;
        if (last.deqFromReg) begin
            let regRespVal <- memory.fetcher.regResp();
            regResp = tagged Valid regRespVal;
        end else begin
            regResp = tagged Invalid;
        end

        // Set the index addend if necessary
        indexAddend <= (last.instNum == INDEX) ? memOrIOResp : tagged Invalid;

        // Do the actual computations
        ExecFuncArgs execArgs = ExecFuncArgs{
            z: last.z,
            inst: last.inst,
            instNum: last.instNum,
            memOrIOResp: memOrIOResp,
            regResp: regResp
        };
        Exec2Writeback execRes = exec(execArgs);

        // Notifiy writeback
        e2w.enq(execRes);

        // Set the new stage
        stage <= Writeback;
    endrule

    rule writeback((stage == Writeback) && memory.init.done);
        $display("Writeback");
        // Get the data from execute
        Exec2Writeback last = e2w.first();
        $display("e2w.first: ", fshow(last));
        e2w.deq();

        // Set Z
        memory.imem.setZ({0, last.newZ, 1'b0});

        // Make the memory and I/O requests if necessary
        if (last.memAddrOrIOChannel matches tagged Addr .addr) begin
            memory.storer.memStore(addr, last.eRes1);
        end else if (last.memAddrOrIOChannel matches tagged IOChannel .channel) begin
            io.internalIO.write(channel, last.eRes1);
        end
        if (isValid(last.regNum)) begin
            memory.storer.regStore(fromMaybe(?, last.regNum), last.eRes2);
        end

        // Set the new stage
        stage <= Fetch;
    endrule

    // Need guards so can't just do interface HostIO hostIO = io
    interface HostIO hostIO;
        method ActionValue#(IOPacket) agcToHost if (memory.init.done);
            IOPacket ret <- io.hostIO.agcToHost();
            return ret;
        endmethod

        method Action hostToAGC(IOPacket packet) if ((stage != Init) && memory.init.done);
            io.hostIO.hostToAGC(packet);
        endmethod
    endinterface

    method Action start(Addr startZ) if ((stage == Init) && memory.init.done);
        $display("Called start!");
        memory.imem.setZ({0, startZ, 1'b0});
        stage <= Fetch;
    endmethod

    interface MemInitIfc memInit = memory.init;
endmodule

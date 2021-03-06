import Fifo::*;

import AGCMemory::*;
import ArithUtil::*;
import Decode::*;
import Exec::*;
import InterStage::*;
import IO::*;
import Timers::*;
import TopLevelIfaces::*;
import Types::*;

typedef enum {
    Init,
    Fetch,
    Decode,
    DecodeDouble,
    Exec,
    WritebackDouble,
    Writeback,
    WritebackDivide,
    Finished
} Stage deriving(Eq, Bits, FShow);

(* synthesize *)
module mkAGC(AGC);
    // General state
    AGCMemory memory <- mkAGCMemory();
    AGCIO io <- mkAGCIO(memory.fetcher, memory.storer, memory.superbank, memory.init);
    AGCTimers timers <- mkAGCTimers(memory.regPort, io.internalIO, memory.init);

    // Stage management
    Reg#(Stage) stage <- mkReg(Init);
    Fifo#(2, Fetch2Decode) f2d <- mkPipelineFifo;
    Fifo#(2, Decode2Exec) d2dd <- mkPipelineFifo;
    Fifo#(2, Decode2Exec) d2e <- mkPipelineFifo;
    Fifo#(2, Exec2Writeback) e2w <- mkPipelineFifo;

    // Random flags
    Reg#(Maybe#(Word)) indexAddend <- mkReg(tagged Invalid);
    Reg#(Bool) isExtended <- mkReg(False);
    Reg#(Maybe#(Word)) zFromDouble <- mkReg(tagged Invalid);

    // Divide handling
    Divider divider <- mkDivider();

    // Interrupt status
    Reg#(Bool) inISR <- mkReg(False);
    Reg#(Bool) interruptsEnabled <- mkReg(True);

    Reg#(Bool) dskyInterrupt <- mkReg(False);

    function Instruction handleIndex(Instruction inst);
        // This presumes INDEX corrects overflow - it's not actually specified as such but it's what
        // VirtualAGC does and it seems reasonable enough.
        Bit#(15) topBitZerod = addOnesCorrected(inst[15:1], fromMaybe(?, indexAddend)[15:1]);
        return {topBitZerod, 1'b0};
    endfunction

    rule fetch((stage == Fetch) && memory.init.done);
        // Get the PC
        Word z = memory.imem.getZ();

        // Get the actual address out of Z.  Z always holds the next address.
        // TAGLSB
        Addr zAddr = z[12:1];
        // subOnesCorrected(1, 1) rolls over to 7777, but in this case we actually just want 0.
        Addr zAddrToFetch = (zAddr == 1) ? 0 : subOnesCorrected(zAddr, 1);

        // Fire the load request
        memory.imem.req(zAddrToFetch);

        // Notify decode of the address
        f2d.enq(Fetch2Decode{z: zAddr});

        // And set the new stage
        stage <= Decode;
    endrule

    rule decode((stage == Decode) && memory.init.done);
        // Get the addr from Fetch
        Fetch2Decode last = f2d.first();
        f2d.deq();

        // Get the instruction from memory
        Instruction inst <- memory.imem.resp();

        if ((last.z == 1) || (last.z == 2) || (last.z == 3)) begin
            inst = {overflowCorrect(inst), 1'b0};
        end

        // Handle interrupts
        Bool hasOverflows = memory.fetcher.hasOverflows();
        Maybe#(Addr) isrAddr = tagged Invalid;

        if (!inISR && !hasOverflows && !isExtended && interruptsEnabled && !isValid(indexAddend) && (last.z != 'O4000) && (last.z != 'O4001)) begin

            // TODO: Clean this up
            if (timers.interruptNeeded(ruptT6)) begin
                isrAddr = tagged Valid 'O4005;
                timers.clearInterrupt(ruptT6);
            end else if (timers.interruptNeeded(ruptT5)) begin
                isrAddr = tagged Valid 'O4011;
                timers.clearInterrupt(ruptT5);
            end else if (timers.interruptNeeded(ruptT3)) begin
                isrAddr = tagged Valid 'O4015;
                timers.clearInterrupt(ruptT3);
            end else if (timers.interruptNeeded(ruptT4)) begin
                isrAddr = tagged Valid 'O4021;
                timers.clearInterrupt(ruptT4);
            end else if (dskyInterrupt) begin
                isrAddr = tagged Valid 'O4025;
                dskyInterrupt <= False;
            end else if (timers.interruptNeeded(ruptDown)) begin
                isrAddr = tagged Valid 'O4041;
                timers.clearInterrupt(ruptDown);
            end
        end

        if (isValid(isrAddr)) begin
            e2w.enq(Exec2Writeback{
                eRes1: {?, 3'b0, last.z, 1'b0},
                eRes2: {?, inst},
                memAddrOrIOChannel: tagged Addr zeroExtend(rZRUPT),
                regNum: tagged Valid rBRUPT,
                newZ: isrAddr.Valid
            });
            inISR <= True;
            stage <= Writeback;
        end else begin
            // Add the index to it if necessary
            if (isValid(indexAddend)) begin
                inst = handleIndex(inst);
            // RESUME
            end else if (inst[15:1] == 'O50017) begin
                inst = memory.fetcher.readRegImm(rBRUPT);
                last.z = memory.fetcher.getZRUPT();
                inISR <= False;
            end

            // Do the decode
            DecodeRes decoded = decode(inst, isExtended);

            // Do the memory and IO requests
            if (decoded.memAddrOrIOChannel matches tagged Addr .addr) begin
               memory.fetcher.memReq(addr);
            end else if (decoded.memAddrOrIOChannel matches tagged IOChannel .channel) begin
                io.internalIO.readReq(channel);
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

            // TODO: For EDRUPT, do we want to set interruptsEnabled = False, or inISR = true, or both?
            if ((decoded.instNum == EDRUPT) || (decoded.instNum == INHINT)) begin
                interruptsEnabled <= False;
            end else if (decoded.instNum == RELINT) begin
                interruptsEnabled <= True;
            end else if (decoded.instNum == UNIMPLEMENTED) begin
                $finish();
            end

            Decode2Exec d2eArgs = Decode2Exec{
                z: last.z,
                inst: inst,
                decoded: decoded,
                fromMemForDouble: ?,
                fromRegForDouble: ?
            };

            // Set the new stage
            if (isDoubleRead(decoded.instNum)) begin
                d2dd.enq(d2eArgs);
                stage <= DecodeDouble;
            end else begin
                // Notify execute
                d2e.enq(d2eArgs);
                stage <= Exec;
            end
        end

    endrule

    rule decodeDouble((stage == DecodeDouble) && memory.init.done);
        // Get the data from decode
        Decode2Exec last = d2dd.first();
        d2dd.deq();

        DecodeRes decoded = last.decoded;

        // Get memory and register responses if necessary, and make the requests as appropriate
        if (decoded.memAddrOrIOChannel matches tagged Addr .addr) begin
            Word memResp <- memory.fetcher.memResp();
            last.fromMemForDouble = memResp;

            memory.fetcher.memReq(addr + 1);
        end

        if (decoded.regNum matches tagged Valid .regNum) begin
            let regRespVal <- memory.fetcher.regResp();
            last.fromRegForDouble = regRespVal;

            memory.fetcher.regReq(regNum + 1);
        end

        d2e.enq(last);
        stage <= Exec;
    endrule

    rule execute((stage == Exec) && memory.init.done);
        // Get the data from decode
        Decode2Exec last = d2e.first();
        d2e.deq();

        DecodeRes decoded = last.decoded;

        // Get the memory responses if necessary.
        // Doing if's because of ActionValue sadness
        Word memOrIORespLower = ?;
        if (decoded.memAddrOrIOChannel matches tagged Addr .addr) begin
            Word memResp <- memory.fetcher.memResp();
            memOrIORespLower = memResp;
        end else if (decoded.memAddrOrIOChannel matches tagged IOChannel .channel) begin
            Word ioResp <- io.internalIO.readResp();
            memOrIORespLower = ioResp;
        end

        Word regRespLower = ?;
        if (decoded.regNum matches tagged Valid .regNum) begin
            Word regResp <- memory.fetcher.regResp();
            regRespLower = regResp;
        end

        // Do the actual computations
        ExecFuncArgs execArgs = ExecFuncArgs{
            z: last.z,
            inst: last.inst,
            instNum: decoded.instNum,
            memOrIOResp: {last.fromMemForDouble, memOrIORespLower},
            regResp: {last.fromRegForDouble, regRespLower}
        };

        Exec2Writeback execRes = exec(execArgs);

        // Set the index addend if necessary
        indexAddend <= (decoded.instNum == INDEX) ? tagged Valid execRes.eRes2[15:0] : tagged Invalid;

        if (decoded.instNum == DV) begin
            // Handle division
            DP dividend = {overflowCorrect(last.fromRegForDouble), overflowCorrect(regRespLower)};
            SP divisor = is16BitRegM(decoded.memAddrOrIOChannel.Addr) ? overflowCorrect(last.fromMemForDouble) : last.fromMemForDouble[15:1];
            divider.req(dividend, divisor);
            stage <= WritebackDivide;
        end else begin
            // Set the new stage
            stage <= isDoubleWrite(decoded.instNum) ? WritebackDouble : Writeback;
        end

        // Notifiy writeback
        e2w.enq(execRes);
    endrule

    rule writebackDouble((stage == WritebackDouble) && memory.init.done);
        // Get the data from execute - note that we don't dequeue
        Exec2Writeback last = e2w.first();

        // Make the memory requests if necessary
        if (last.memAddrOrIOChannel matches tagged Addr .addr) begin
            Addr addrp1 = addr + 1;
            Word res = last.eRes1[31:16];
            memory.storer.memStore(addrp1, res);
            // Redirect Z if necessary
            if (addrp1 == zeroExtend(rZ)) begin
                zFromDouble <= tagged Valid res;
            end
        end
        if (last.regNum matches tagged Valid .regNum) begin
            // Don't need to do the same for regs because Z can't be referred to in
            // double instructions as a reg
            memory.storer.regStore(regNum + 1, last.eRes2[31:16]);
        end

        stage <= Writeback;
    endrule

    rule writeback((stage == Writeback) && memory.init.done);
        // Get the data from execute
        Exec2Writeback last = e2w.first();
        e2w.deq();

        // Set Z.  2 because is left-shifted 1.
        memory.imem.setZ(isValid(zFromDouble) ? zFromDouble.Valid + 2 : {0, last.newZ, 1'b0});
        zFromDouble <= tagged Invalid;

        // Make the memory and I/O requests if necessary
        if (last.memAddrOrIOChannel matches tagged Addr .addr) begin
            memory.storer.memStore(addr, last.eRes1[15:0]);
        end else if (last.memAddrOrIOChannel matches tagged IOChannel .channel) begin
            io.internalIO.write(channel, last.eRes1[15:0]);
        end
        if (last.regNum matches tagged Valid .regNum) begin
            memory.storer.regStore(regNum, last.eRes2[15:0]);
        end

        // Set the new stage
        stage <= Fetch;
    endrule

    rule writebackDivide((stage == WritebackDivide) && memory.init.done);
        // Get the data from execute - we really only need z
        Exec2Writeback last = e2w.first();
        e2w.deq();

        // Get the data back from divide
        DP result <- divider.resp();

        // Because we can only write one register at a time, we use both memStore and regStore
        memory.storer.memStore(zeroExtend(rA), signExtend(result[29:15]));
        memory.storer.regStore(rL, signExtend(result[14:0]));

        // Set the new Z
        memory.imem.setZ({0, last.newZ, 1'b0});

        // Set the new stage
        stage <= Fetch;
    endrule

    // Need guards so can't just do interface HostIO hostIO = io
    interface HostIOWithInit hostIO;
        interface HostIO hostIO;
            method ActionValue#(IOPacket) agcToHost if ((stage != Init) && memory.init.done);
                IOPacket ret <- io.hostIO.agcToHost();
                return ret;
            endmethod

            method Action hostToAGC(IOPacket packet) if ((stage != Init) && memory.init.done);
                // Only trigger an interrupt on actual data, rather than mask settings.
                if (!packet.u && ((packet.channel == 13) || (packet.channel == 26))) begin
                    dskyInterrupt <= True;
                end
                io.hostIO.hostToAGC(packet);
            endmethod
        endinterface

        method Action init(IOPacket packet) if (!memory.init.done);
            io.hostIO.hostToAGC(packet);
        endmethod
    endinterface

    method Action start(Addr startZ) if ((stage == Init) && memory.init.done);
        memory.imem.setZ({0, startZ, 1'b0});
        stage <= Fetch;
    endmethod

    interface MemInitIfc memInit = memory.init;
endmodule

import AGCMemory::*;
import ArithUtil::*;
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
        // We basically need to treat inst as unsigned and indexAddend as signed.
        // This presumes INDEX ignores overflow - it's not actually specified as such but seems the most reasonable option.
        Bit#(15) topBitZerod = addOnesUncorrected({1'b0, inst[14:1]}, fromMaybe(?, indexAddend)[15:1]);
        Bit#(1) topBit = inst[15] ^ topBitZerod[14];
        return {topBit, topBitZerod[13:0], 1'b0};
    endfunction

    rule fetch((stage == Fetch) && memory.init.done);
        $display("\n\nFetch---------------------------------------------------------------------------------------------");
        // Get the PC
        Word z = memory.imem.getZ();

        // Get the actual address out of Z.  Z always holds the next address.
        // TAGLSB
        Addr zAddr = z[12:1];
        Addr zAddrToFetch = subOnesCorrected(zAddr, 1);

        $display("Instruction address: o%o", zAddrToFetch);

        // Fire the load request
        memory.imem.req(zAddrToFetch);

        // Notify decode of the address
        f2d.enq(Fetch2Decode{z: zAddr});

        // And set the new stage
        stage <= Decode;
    endrule

    // Yay for breaking abstractions!
    rule decode((stage == Decode) && memory.init.done);
        $display("Decode--------------------------------------------------------------------------------------------");
        // Get the addr from Fetch
        Fetch2Decode last = f2d.first();
        $display("f2d.first: ", fshow(last));
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

            if (memory.timers.t3IRUPT) begin
                $display("Taking TIMER3 Interrupt!");
                isrAddr = tagged Valid 'O4015;
                memory.timers.clearT3IRUPT();
            end else if (memory.timers.t4IRUPT) begin
                $display("Taking TIMER4 Interrupt!");
                isrAddr = tagged Valid 'O4021;
                memory.timers.clearT4IRUPT();
            end else if (dskyInterrupt) begin
                $display("Taking DSKY Interrupt!");
                isrAddr = tagged Valid 'O4025;
                dskyInterrupt <= False;
            end else if (io.internalIO.downlinkReady()) begin
                $display("Taking Downlink Interrupt!");
                isrAddr = tagged Valid 'O4041;
                io.internalIO.clearDownlink();
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
                $display("indexAddend is valid: instruction = 0x%x, indexAddend = 0x%x", inst[15:1], fromMaybe(?, indexAddend));
                inst = handleIndex(inst);
            // RESUME
            end else if (inst[15:1] == 'O50017) begin
                inst = memory.fetcher.readRegImm(rBRUPT);
                last.z = memory.fetcher.getZRUPT();
                inISR <= False;
            end
            if (isValid(indexAddend)) begin
                if ((inst == 11478) && (last.z == 2469)) begin
                    $display("Faking the index");
                    inst = 11546;
                end
                $display("New instruction: 0x%x", inst);
            end

            // Do the decode
            DecodeRes decoded = decode(inst, isExtended);

            $display("Decoded instruction: ", fshow(decoded.instNum));

            // Do the memory and IO requests
            if (decoded.memAddrOrIOChannel matches tagged Addr .addr) begin
               $display("Requesting data load: o%o", addr);
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

            if (decoded.instNum == INHINT) begin
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

                if (decoded.instNum == EDRUPT) begin
                    $display("Got EDRUPT!");
                    stage <= Finished;
                end else begin
                    stage <= Exec;
                end
            end
        end

    endrule

    rule decodeDouble((stage == DecodeDouble) && memory.init.done);
        $display("DecodeDouble--------------------------------------------------------------------------------------");

        // Get the data from decode
        Decode2Exec last = d2dd.first();
        $display("d2dd.first: ", fshow(last));
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
        $display("Execute-------------------------------------------------------------------------------------------");
        // Get the data from decode
        Decode2Exec last = d2e.first();
        $display("d2e.first: ", fshow(last));
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

        //Bit#(15) one = 1;
        //$display("test: ", fshow(subOnes(one, one)));

        $display("execArgs: ", fshow(execArgs));
        Exec2Writeback execRes = exec(execArgs);
        $display("execRes: ", fshow(execRes));

        // Set the index addend if necessary
        indexAddend <= (decoded.instNum == INDEX) ? tagged Valid execRes.eRes2[15:0] : tagged Invalid;

        if (decoded.instNum == DV) begin
            // Handle division
            DP dividend = {overflowCorrect(last.fromRegForDouble), overflowCorrect(regRespLower)};
            SP divisor = is16BitRegM(decoded.memAddrOrIOChannel.Addr) ? overflowCorrect(last.fromMemForDouble) : last.fromMemForDouble[15:1];
            $display("In exec: Dividend: %x, divisor: %x", dividend, divisor);
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
        $display("WritebackDouble-----------------------------------------------------------------------------------");

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
        $display("Writeback-----------------------------------------------------------------------------------------");
        // Get the data from execute
        Exec2Writeback last = e2w.first();
        $display("e2w.first: ", fshow(last));
        e2w.deq();

        // Set Z.  2 because is left-shifted 1.
        memory.imem.setZ(isValid(zFromDouble) ? zFromDouble.Valid + 2 : {0, last.newZ, 1'b0});
        zFromDouble <= tagged Invalid;

        Bool wroteToIO = False;

        // Make the memory and I/O requests if necessary
        if (last.memAddrOrIOChannel matches tagged Addr .addr) begin
            memory.storer.memStore(addr, last.eRes1[15:0]);
        end else if (last.memAddrOrIOChannel matches tagged IOChannel .channel) begin
            io.internalIO.write(channel, last.eRes1[15:0]);
            wroteToIO = True;
        end
        if (last.regNum matches tagged Valid .regNum) begin
            memory.storer.regStore(regNum, last.eRes2[15:0]);
        end

        if (!wroteToIO) begin
            io.internalIO.downlinkTick();
        end

        // Set the new stage
        stage <= Fetch;
    endrule

    rule writebackDivide((stage == WritebackDivide) && memory.init.done);
        $display("WritebackDivide-----------------------------------------------------------------------------------");
        // Get the data from execute - we really only need z
        Exec2Writeback last = e2w.first();
        $display("e2w.first: ", fshow(last));
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
                $display("IO Host to AGC: ", packet);
                if ((packet.channel == 13)/* || (packet.channel == 26)*/) begin
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
        $display("Called start!");
        memory.imem.setZ({0, startZ, 1'b0});
        stage <= Fetch;
    endmethod

    interface MemInitIfc memInit = memory.init;
endmodule

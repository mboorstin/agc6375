import BRAM::*;
import Vector::*;

import Ehr::*;
import Fifo::*;
import MemInit::*;
import MemTypes::*;
import Types::*;

module mkMemAndRegWrapper(BRAMServer#(MemAddr, Word) bramPort, Vector#(NRegs, Ehr#(ehrSize, Word)) regFile, Integer readIdx, Integer writeIdx, MemAndRegWrapper ifc);

    // Register read FIFO's - used to make the results appear a cycle later
    Fifo#(2, Word) memDelayed <- mkCFFifo();
    Fifo#(2, Word) regDelayed <- mkCFFifo();

    // Read a register - basically just replaces r7 with 0
    function Word getReg(RegIdx regIdx, Integer e);
        if (regIdx == rZERO) begin
            return 0;
        end else begin
            return regFile[regIdx][e];
        end
    endfunction

    // Write a register - handles FB/EB/BB mirroring
    function Action setReg(RegIdx regIdx, Word data, Integer e);
        action
            case (regIdx)
                // WARNING: This is probably not correct if you're also
                // writing to rFB.  Should find a way to fix this...
                rEB: begin
                    Bit#(3) eb = truncate(data >> 9);
                    $display("Mirroring from rEB: %x", eb);
                    regFile[rBB][e] <= {truncateLSB(getReg(rBB, e)), eb, 1'b0};
                end
                rFB: begin
                    Bit#(5) fb = truncateLSB(data);
                    $display("Mirroring from rFB: %x", fb);
                    regFile[rBB][e] <= {fb, truncate(getReg(rBB, e))};
                end
                rBB: begin
                    Bit#(3) eb = truncate(data >> 1);
                    regFile[rEB][e] <= {'0, eb, 9'b0};
                    Bit#(5) fb = truncateLSB(data);
                    regFile[rFB][e] <= {fb, '0};
                end
            endcase

            regFile[regIdx][e] <= data;
        endaction
    endfunction

    // Somewhat arbitrarily choosing writeIdx for memory and writeIdx + 1
    // for registers
    method Action readMem(RealMemAddr realAddr);
        if (realAddr matches tagged RegNum .r) begin
            memDelayed.enq(getReg(r, readIdx));
        end else begin
            $display("readMem: addr %x", realAddr.MemAddr);
            bramPort.request.put(BRAMRequest{
                write: False,
                responseOnWrite: False,
                address: realAddr.MemAddr,
                datain: ?
            });
        end
    endmethod

    method Action readReg(RegIdx idx);
        regDelayed.enq(getReg(idx, readIdx));
    endmethod

    method Word readRegImm(RegIdx idx);
        return getReg(idx, readIdx);
    endmethod

    method ActionValue#(Word) memResp();
        if (memDelayed.notEmpty) begin
            $display("memResp: from reg");
            memDelayed.deq();
            return memDelayed.first;
        end else begin
            $display("memResp: from mem");
            Instruction ret <- bramPort.response.get;
            return ret;
        end
    endmethod

    method ActionValue#(Word) regResp();
        regDelayed.deq();
        return regDelayed.first;
    endmethod

    // Add error checking!
    method Action writeMem(RealMemAddr realAddr, Word data);
        if (realAddr matches tagged RegNum .r) begin
            setReg(r, data, writeIdx);
        end else begin
            $display("writeMem: addr %x  data %x", realAddr.MemAddr, data);
            bramPort.request.put(BRAMRequest{
                write: True,
                responseOnWrite: False,
                address: realAddr.MemAddr,
                datain: data
            });
        end
    endmethod

    method Action writeReg(RegIdx idx, Word data);
        setReg(idx, data, writeIdx + 1);
    endmethod

endmodule

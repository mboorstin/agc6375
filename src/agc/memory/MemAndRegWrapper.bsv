import BRAM::*;
import Vector::*;

import Ehr::*;
import Fifo::*;
import MemInit::*;
import MemTypes::*;
import Types::*;

module mkMemAndRegWrapper(BRAMServer#(MemAddr, Word) bramPort, Vector#(NRegs, Ehr#(ehrSize, Word)) regFile, Integer readIdx, Integer writeZIdx, Integer writeMemIdx, Integer writeRegIdx, MemAndRegWrapper ifc);

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

    // Write a register - handles FB/EB/BB mirroring and CSCE
    function Action setReg(RegIdx regIdx, Word data, Integer e);
        action
            case (regIdx)
                rCYR: begin
                    data = {data[1], data[15:2], data[0]};
                end
                rSR: begin
                    data = {data[15], data[15:2], data[0]};
                end
                rCYL: begin
                    data = {data[14:1], data[15], data[0]};
                end
                rEDOP: begin
                    data = {8'b0, data[14:8], 1'b0};
                end
                // WARNING: This is probably not correct if you're also
                // writing to rFB.  Should find a way to fix this...
                rEB: begin
                    Bit#(3) eb = truncate(data >> 9);
                    regFile[rBB][e] <= {truncateLSB(getReg(rBB, e)), eb, 1'b0};
                end
                rFB: begin
                    Bit#(5) fb = truncateLSB(data);
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

    method Bool hasOverflows();
        Word a = getReg(rA, readIdx);
        Word l = getReg(rL, readIdx);
        Word q = getReg(rQ, readIdx);
        return (a[15] != a[14]) || (l[15] != l[14]) || (q[15] != q[14]);
    endmethod

    method Addr getZRUPT();
        return getReg(rZRUPT, readIdx)[12:1];
    endmethod

    method ActionValue#(Word) memResp();
        if (memDelayed.notEmpty) begin
            memDelayed.deq();
            return memDelayed.first;
        end else begin
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
            setReg(r, data, writeMemIdx);
        end else begin
            bramPort.request.put(BRAMRequest{
                write: True,
                responseOnWrite: False,
                address: realAddr.MemAddr,
                datain: data
            });
        end
    endmethod

    method Action writeReg(RegIdx idx, Word data);
        setReg(idx, data, writeRegIdx);
    endmethod

    method Action writeZImm(Word data);
        setReg(rZ, data, writeZIdx);
    endmethod

endmodule

import AGCMemory::*;
import InterStage::*;
import TopLevelIfaces::*;
import Types::*;

(* synthesize *)
module mkAGC(AGC);
    AGCMemory memory <- mkAGCMemory();
    Reg#(Bool) started <- mkReg(False);
    Reg#(Bool) lightOn <- mkReg(False);
    Reg#(Bool) sendMessage <- mkReg(False);
    Reg#(Bool) requestMade <- mkReg(False);

    // Memory initialization test: should print out C020
    rule makeRequest (!requestMade);
        memory.imem.req('O4032);
        requestMade <= True;
    endrule

    rule dispResp (requestMade);
        let inst <- memory.imem.resp();
        $display("Result from 'O4032: %x", inst);
    endrule

    // Test I/O ports
    // Should dequeue from a FIFO of requests or something like that
    method ActionValue#(IOPacket) ioAGCToHost if (started && sendMessage);
        $display("Sending packet");
        sendMessage <= False;
        return IOPacket{channel: 'O11, data: (lightOn ? 'hFFFF : 0)};
    endmethod

    method Action ioHostToAGC(IOPacket packet);
        $display("Packet received: channel %x, data %x", packet.channel, packet.data);
        sendMessage <= True;
        lightOn <= !lightOn;
    endmethod

    // Should probably slap some guards on this (memory.isInit?)
    method Action start(Addr startZ);
        $display("Start received with address %x", startZ);
        started <= True;
    endmethod

    interface MemInitIfc memInit = memory.init;
endmodule
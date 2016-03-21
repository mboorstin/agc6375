// Modified version of MemInit.bsv with a couple things copied from MemTypes.bsv

import GetPut::*;
import BRAM::*;

import MemTypes::*;
import Types::*;

module mkMemInitBRAM(BRAM2PortBE#(DMemAddr, DoubleWord, n) mem, MemInitIfc ifc);
    Reg#(Bool) initialized <- mkReg(False);

    interface Put request;
        method Action put(MemInit x) if (!initialized);
          case (x) matches
            tagged InitLoad .l: begin
                BRAMRequestBE#(DMemAddr, DoubleWord, n) initRequest = BRAMRequestBE{
                    writeen: '1,
                    responseOnWrite: False,
                    address: truncate(l.addr),
                    datain: l.data
                };

                mem.portA.request.put(initRequest);
            end

            tagged InitDone: begin
                initialized <= True;
            end
          endcase
        endmethod
    endinterface

    method Bool done() = initialized;

endmodule

//module mkDummyMemInit(MemInitIfc);
//    Reg#(Bool) initialized <- mkReg(False);

//    interface Put request;
//        method Action put(MemInit x) if (!initialized);
//          case (x) matches
//            tagged InitDone: begin
//                initialized <= True;
//            end
//          endcase
//        endmethod
//    endinterface

//    method Bool done() = initialized;

//endmodule

import InterStage::*;
import Types::*;
import Vector::*;
import GetPut::*;

typedef Server#(
    Decode2Exec,
    Exec2Writeback
) Exec;

(* synthesize *)
module mkExec(Exec);
    //fifos
    Fifo#(2, Decode2Exec) inputFIFO <- mkConflictFifo();
    Fifo#(2, Exec2Writeback) outputFIFO <- mkConflictFifo();

    //flags
    Reg#(Bool) extracode <- mkReg#(False);
    Reg#(Instruction) prev_inst <- mkRegU;

    //exec
    rule exec();
        //pull data from decode
	Decode2Exec d2e = inputFIFO.first;
	inputFIFO.deq;

	Bit#(3) ccc = d2e.inst[15:13];
	Bit#(12) addr = d2e.inst[12:0];
	Bit#(2) qq = d2e.inst[12:11];
	Bit#(3) ppp = d2e.inst[12:10];

	Word eRes1;
	Word eRes2;
	Maybe#(Addr) memAddr;
	Maybe#(RegIdz) regNum;
	Maybe#(Addr) newZ;

	//maybe there's a better way to set this up?  Either way, I'm so sorry.
	//extracode
	if (extracode) begin
	    //
	    case(ccc)
		opIO: begin //corresponds to I/O instructions
                    case(ppp)
                        qcioREAD: begin //READ
                            //
			end
			qcioWRITE: begin //WRITE
                            //
			end
			qcioRAND: begin //RAND
                            //
			end
			qcioWAND: begin //WAND
                            //
			end
			qcioROR: begin //ROR
                            //
			end
			qcioWOR: begin //WOR
                            //
			end
			qcioRXOR: begin //RXOR
                            //
			end
			qcioEDRUPT: begin //EDRUPT
                            //
			end
		    endcase
		end
		opDV: begin //corresponds to DV and BZF
                    if (qq == qcDV) begin //DV
                        //
	            end
	            else begin //BZF
                        //
	            end
	        end
		opMSU: begin //corresponds to MSU, QXCH, AUG, and DIM
                    case(qq)
                        qcMSU: begin //MSU
                            //
			end
			qcQXCH: begin //QXCH
                            //
			end
			qcAUG: begin //AUG
                            //
			end
			qcDIM: begin //DIM
                            //
			end
	            endcase
		end
		opDCA: begin //DCA
                    //
	        end
		opDCS: begin //DCS
                    //
		end
		opINDEX: begin //INDEX
                    //
	        end
		opSU: begin //corresponds to SU and BZMF
                    if  (qq == qcSU) begin //SU
                        //
		    end
		    else begin //BZMF
			//
		    end
	        end
		opMP: begin //MP
                    //
	        end
	    endcase
	end 
	else begin //otherwise
            case (aaa)
                opTC: begin //TC
		    //
		end
		opCCS: begin //corresponds to CCS and TCF
		    if (qq == qqCCS) begin //CCS
	                //
		    end
		    else begin //TCF
			//
		    end
		end
		opDAS: begin //corresponds to DAS, LXCH, INCR, and ADS
		    case (qq)
		        qcDAS: begin //DAS
			    //
			end
			qcLXCH: begin //LXCH
			    //
			end
			qcINCR: begin //INCR
			    //
			end
			qcADS: begin //ADS
			    //
			end
		    endcase
		end
		opCA: begin //CA
		    //
		end
		opCS: begin //CS
		    //
		end
		opINDEX: begin //corresponds to INDEX, DXCH, TS, XCH
		    case (qq)
			qcINDEX: begin //INDEX
			    //
			end
			qcDXCH: begin //DXCH
			    //
			end
			qcTS: begin //TS
			    //
			end
			qcXCH: begin //XCH
			    //
			end
		    endcase
		end
		opAD: begin //AD
		    //
		end
		opMASK: begin //MASK
		    //
		end
	    endcase
	end

	//encoding output
	Exec2Writeback e2w = Exec2Writeback{
	    eRes1:eRes1,
	    eRes2:eRes2,
	    memAddr:memAddr,
	    regNum:regNum,
	    newZ:newZ,
	};
	outputFIFO.enq(e2w);
    endrule

    //get put
    interface Put request;
        method Action put(Decode2Exec x);
            inputFIFO.enq(x);
	endmethod
    endinterface
    interface get response = toGet(outputFIFO);

endmodule


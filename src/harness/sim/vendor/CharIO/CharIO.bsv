// Vendored from https://raw.githubusercontent.com/CTSRD-CHERI/BlueStuff/master/CharIO.bsv
// with the AXI4Lite bits removed

/*-
 * Copyright (c) 2018-2019 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */

package CharIO;

import FIFOF :: *;
import SpecialFIFOs :: *;

import SourceSink :: *;
import MasterSlave :: *;

// C imports
import "BDPI" function ActionValue#(Bit#(64)) serv_socket_create(String name, Bit#(32) dflt_port);
import "BDPI" function Action serv_socket_init(Bit#(64) ptr);
import "BDPI" function ActionValue#(Bit#(32)) serv_socket_get8(Bit#(64) ptr);
import "BDPI" function ActionValue#(Bool) serv_socket_put8(Bit#(64) ptr, Bit#(8) b);

// simple Slave interface
////////////////////////////////////////////////////////////////////////////////

typedef Slave#(Bit#(8), Bit#(8)) CharIO;

module mkSocketCharIO#(String name, Integer dflt_port) (CharIO);
  // prepare C socket
  Reg#(Bool)      is_initialized <- mkReg(False);
  Reg#(Bit#(64)) serv_socket_ptr <- mkRegU;
  rule do_init (!is_initialized);
    let tmp <- serv_socket_create(name, fromInteger(dflt_port));
    serv_socket_init(tmp);
    serv_socket_ptr <= tmp;
    is_initialized  <= True;
  endrule
  // output char
  let outff <- mkBypassFIFOF;
  rule outputChar (is_initialized);
    let sent <- serv_socket_put8(serv_socket_ptr, outff.first);
    if (sent) outff.deq;
  endrule
  // input char
  let inff  <- mkBypassFIFOF;
  rule inputChar (is_initialized);
    let tmp <- serv_socket_get8(serv_socket_ptr);
    if (tmp != -1) inff.enq(truncate(tmp));
  endrule
  // interface
  interface source = toSource(inff);
  interface sink   = toSink(outff);
endmodule

module mkFileCharIOCore#(File inf, File outf) (CharIO);
  let inff  <- mkBypassFIFOF;
  let outff <- mkBypassFIFOF;
  rule readFromIn;
    let c <- $fgetc(inf);
    inff.enq(truncate(pack(c)));
  endrule
  rule writeToOut;
    $fwrite(outf, "%c", outff.first);
    outff.deq;
  endrule
  interface source = toSource(inff);
  interface sink   = toSink(outff);
endmodule

module mkFileCharIO#(String inf, String outf) (CharIO);
  let infh  <- mkReg(InvalidFile);
  rule init_infh (infh == InvalidFile);
    File in_fh <- $fopen(inf, "r");
    if (in_fh == InvalidFile) begin
      $display("cannot open %s", inf);
      $finish(0);
    end
    infh <= in_fh;
  endrule
  let outfh <- mkReg(InvalidFile);
  rule init_outfh (outfh == InvalidFile);
    File out_fh <- $fopen(outf, "r");
    if (out_fh == InvalidFile) begin
      $display("cannot open %s", outf);
      $finish(0);
    end
    outfh <= out_fh;
  endrule
  let core <- mkFileCharIOCore(infh, outfh);
  return core;
endmodule

module mkCharIO (CharIO);
  let core <- mkFileCharIOCore(stdin, stdout);
  return core;
endmodule

endpackage

// Copyright Bluespec Inc. 2011-2012

`ifdef SCEMI_PCIE_VIRTEX5
  `ifdef BOARD_ML507
    `ifdef DDR2_SODIMM_STYLE
      `include "Bridge_VIRTEX5_ML50X_DDR2.bsv"
    `else
      `include "Bridge_VIRTEX5_ML50X.bsv"
     `endif
  `endif
  `ifdef BOARD_XUPV5
    `ifdef DDR2_SODIMM_STYLE
      `include "Bridge_VIRTEX5_ML50X_DDR2.bsv"
    `else
      `include "Bridge_VIRTEX5_ML50X.bsv"
    `endif
   `endif
`endif

`ifdef SCEMI_PCIE_VIRTEX6
  `ifdef BOARD_ML605
    `ifdef DDR3_SODIMM_STYLE
      `include "Bridge_VIRTEX6_ML605_DDR3.bsv"
    `else
      `include "Bridge_VIRTEX6_ML605.bsv"
     `endif
  `endif
  `ifdef BOARD_10GHXTLL
    `include "Bridge_DINI_10GHXTLL.bsv"
  `endif
`endif

`ifdef SCEMI_PCIE_KINTEX7
  `ifdef BOARD_KC705
    `ifdef DDR3_SODIMM_STYLE
      `include "Bridge_KINTEX7_KC705_DDR3.bsv"
    `else
      `include "Bridge_KINTEX7_KC705.bsv"
    `endif
  `endif
  `ifdef BOARD_10GK7LL
    `ifdef DDR3_SODIMM_STYLE
      `include "Bridge_DINI_10GK7LL_DDR3.bsv"
    `else
      `include "Bridge_DINI_10GK7LL.bsv"
    `endif
  `endif
`endif

`ifdef SCEMI_PCIE_VIRTEX7
  `ifdef BOARD_VC707
    `ifdef DDR3_SODIMM_STYLE
      `include "Bridge_VIRTEX7_VC707_DDR3.bsv"
    `else
      `include "Bridge_VIRTEX7_VC707.bsv"
    `endif
  `endif
  `ifdef BOARD_DH2000TQ
    `ifdef DDR2_SODIMM_STYLE
      `include "Bridge_VIRTEX7_DH2000TQ_DDR2.bsv"
    `else
      `include "Bridge_VIRTEX7_DH2000TQ.bsv"
    `endif
  `endif
  `ifdef BOARD_B2000T
    `ifdef DDR3_SODIMM_STYLE
      `include "Bridge_VIRTEX7_B2000T_DDR3.bsv"
    `else
      `include "Bridge_VIRTEX7_B2000T.bsv"
    `endif
  `endif
  `ifdef BOARD_PDV72KR2
    `include "Bridge_VIRTEX7_PDV72KR2.bsv"
  `endif
  `ifdef BOARD_DNV7F2A
    `ifdef DDR3_SODIMM_STYLE
      `include "Bridge_DINI_DNV7F2A_DDR3.bsv"
    `else
      `include "Bridge_DINI_DNV7F2A.bsv"
    `endif
  `endif
  `ifdef BOARD_RPP2
    `ifdef DDR3_SODIMM_STYLE
      `include "Bridge_DINI_RPP2_DDR3.bsv"
    `else
      `include "Bridge_DINI_RPP2.bsv"
    `endif
  `endif
  `ifdef BOARD_RPP2SPLIT
    `ifdef DDR3_SODIMM_STYLE
      `include "Bridge_DINI_RPP2SPLIT_DDR3.bsv"
    `else
      `include "Bridge_DINI_RPP2SPLIT.bsv"
    `endif
  `endif
`endif

`ifdef SCEMI_PCIE_DINI
  `ifdef BOARD_7002
    `ifdef DDR2_SODIMM_STYLE
      `include "Bridge_DINI_7002_DDR2.bsv"
    `else
      `ifdef SRAM_SODIMM_STYLE
        `include "Bridge_DINI_7002_SRAM.bsv"
      `else
  `include "Bridge_DINI_7002.bsv"
      `endif
    `endif
  `endif
  `ifdef BOARD_7006
    `ifdef DDR2_SODIMM_STYLE
      `include "Bridge_DINI_7006_DDR2.bsv"
    `else
      `ifdef SRAM_SODIMM_STYLE
        `include "Bridge_DINI_7006_SRAM.bsv"
      `else
  `include "Bridge_DINI_7006.bsv"
      `endif
    `endif
  `endif
  `ifdef BOARD_7406
    `ifdef DDR2_SODIMM_STYLE
      `include "Bridge_DINI_7406_DDR2.bsv"
    `else
      `ifdef SRAM_SODIMM_STYLE
        `include "Bridge_DINI_7406_SRAM.bsv"
      `else
  `include "Bridge_DINI_7406.bsv"
      `endif
    `endif
  `endif
`endif

`ifdef SCEMI_TCP
  `include "Bridge_TCP.bsv"
`endif

`ifdef SCEMI_SCEMI
`define SCEMI_LT SCEMI
`include "Bridge_SCEMI.bsv"
`endif

`ifdef SCEMI_EVE
`define SCEMI_LT EVE
`include "Bridge_SCEMI.bsv"
`endif

// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

 `include "axi/assign.svh"
 `include "axi/typedef.svh"

module eros_top_wrapper_axi
//  import eros_obi_pkg::*;
  import reg_pkg::*;
  import eros_pkg::*;
#(
    parameter NHARTS  = 3,
    parameter N_BANKS = 2,

    parameter S00_AXI_ADDR_WIDTH        = 32,
    parameter S00_AXI_DATA_WIDTH        = 32,
    parameter S00_AXI_ID_WIDTH_SLAVE    = 32,
    parameter S00_AXI_USER_WIDTH        = 32,

    parameter S01_AXI_ADDR_WIDTH        = 32,
    parameter S01_AXI_DATA_WIDTH        = 32,
    parameter S01_AXI_ID_WIDTH_SLAVE    = 32,
    parameter S01_AXI_USER_WIDTH        = 32,
    parameter type axi_slv_req_t        = logic,
    parameter type axi_slv_rsp_t        = logic,
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Top level clock gating unit enable
    input logic en_i,

    //Bus External Slave
    output obi_req_t  ext_slave_req_o,
    input  obi_resp_t ext_slave_resp_i,

    // ----------------------------------------------
    // Ports of Axi Slave Bus Interface S00_AXI -> OBI
    // ----------------------------------------------
    input  axi_slv_req_t    axi_S00_req_i,
    output axi_slv_rsp_t    axi_S00_rsp_o,

    // ---------------------------------------------

    // ----------------------------------------------
    // Ports of Axi Slave Bus Interface S01_AXI -> REG
    // ----------------------------------------------
    input  axi_slv_req_t    axi_S01_req_i,
    output axi_slv_rsp_t    axi_S01_rsp_o,

    output logic            axi_S01_busy_o,

    // ----------------------------------------------

    // Debug Interface
    input  logic              debug_req_i,
    output logic [NHARTS-1:0] sleep_o,

    // power manager signals that goes to the ASIC macros
    input  logic [N_BANKS-1:0] pwrgate_ni,
    output logic [N_BANKS-1:0] pwrgate_ack_no,
    input  logic [N_BANKS-1:0] set_retentive_ni,

    // Interrupt Interface
    output logic interrupt_o
);
    // Slave AXI - Slave OBI
    obi_req_t     axi_obi_master_req;
    obi_resp_t    axi_obi_master_resp;

    // Slave AXI-LITE - Slave REG
    reg_req_t axi_reg_master_req;
    reg_rsp_t axi_reg_master_rsp;

//////////////////////////////////////////////
//              AXI -> REG                  //
//////////////////////////////////////////////

axi_to_reg_v2 #(
    /// The width of the address.
    .AxiAddrWidth    (S01_AXI_ADDR_WIDTH),
    /// The width of the data.
    .AxiDataWidth    (S01_AXI_DATA_WIDTH),
    /// The width of the id.
    .AxiIdWidth      (S01_AXI_ID_WIDTH_SLAVE),
    /// The width of the user signal.
    .AxiUserWidth    (S01_AXI_USER_WIDTH),
    /// The data width of the Reg bus
    .RegDataWidth    (32'd32),

    .axi_req_t       (axi_slv_req_t),
    .axi_rsp_t       (axi_slv_rsp_t),
    /// Regbus request struct type.
    .reg_req_t       (reg_req_t),
    /// Regbus response struct type.
    .reg_rsp_t       (reg_rsp_t)
) axi_to_reg_v2_i(
    .clk_i,
    .rst_ni,
    .axi_req_i(axi_S01_req_i),
    .axi_rsp_o(axi_S01_rsp_o),
    .reg_req_o(axi_reg_master_req),
    .reg_rsp_i(axi_reg_master_rsp),
    .reg_id_o(),
    .busy_o(axi_S01_busy_o)
);

//////////////////////////////////////////////
// AXI64 -> AXI32 -> AXI_LITE -> APB -> OBI //
//////////////////////////////////////////////

    AXI_BUS #(
    .AXI_ADDR_WIDTH(S00_AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(32'd32),
    .AXI_ID_WIDTH(S00_AXI_ID_WIDTH_SLAVE),
    .AXI_USER_WIDTH(S00_AXI_USER_WIDTH)
    ) axi_32master();
  
    AXI_BUS #(
    .AXI_ADDR_WIDTH(S00_AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(S00_AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(S00_AXI_ID_WIDTH_SLAVE),
    .AXI_USER_WIDTH(S00_AXI_USER_WIDTH)
    ) axi_xxmaster();

  AXI_LITE #(
    .AXI_ADDR_WIDTH(S00_AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(S00_AXI_DATA_WIDTH)
  ) axi_lite_slave();

    // Connect buses using AXI macros
    `AXI_ASSIGN_FROM_REQ(axi_xxmaster, axi_S00_req_i)
    `AXI_ASSIGN_TO_RESP(axi_S00_rsp_o, axi_xxmaster)
  
  //  `AXI_ASSIGN_TO_REQ(axi_S00_req_i, axi_slave)
  //  `AXI_ASSIGN_FROM_RESP(axi_slave, axi_S00_rsp_o)

  axi_dw_converter_intf #(
    .AXI_MAX_READS          (4                    ),
    .AXI_ADDR_WIDTH         (S00_AXI_ADDR_WIDTH   ),
    .AXI_ID_WIDTH           (S00_AXI_ID_WIDTH_SLAVE),
    .AXI_SLV_PORT_DATA_WIDTH(S00_AXI_DATA_WIDTH   ),
    .AXI_MST_PORT_DATA_WIDTH(32'd32               ),
    .AXI_USER_WIDTH         (S00_AXI_USER_WIDTH   )
  ) i_dw_converter (
    .clk_i,
    .rst_ni,
    .slv      (axi_xxmaster),
    .mst      (axi_32master)
  );

  axi_to_axi_lite_intf #(
    .AXI_ID_WIDTH       (S00_AXI_ID_WIDTH_SLAVE),
    .AXI_ADDR_WIDTH     (S00_AXI_ADDR_WIDTH    ),
    .AXI_DATA_WIDTH     ( 32'd32               ),
    .AXI_USER_WIDTH     (S00_AXI_USER_WIDTH),
    .AXI_MAX_WRITE_TXNS ( 32'd10  ),
    .AXI_MAX_READ_TXNS  ( 32'd10  ),
    .FALL_THROUGH       ( 1'b1    )
) axi_to_axi_lite_intf_i (
    .clk_i,
    .rst_ni,
    .testmode_i ( 1'b0     ),
    .slv        ( axi_32master),
    .mst        ( axi_lite_slave )
);
    // Dut parameters
    localparam int unsigned NoApbSlaves = 1;    // How many APB Slaves  there are
    localparam int unsigned NoAddrRules = 1;    // How many address rules for the APB slaves
    // Type widths
    localparam int unsigned AxiAddrWidth = 32;
    localparam int unsigned AxiDataWidth = 32;
    localparam int unsigned AxiStrbWidth = AxiDataWidth/8;

    typedef logic [AxiAddrWidth-1:0]      addr_t;
    typedef axi_pkg::xbar_rule_32_t       rule_t; // Has to be the same width as axi addr
    typedef logic [AxiDataWidth-1:0]      data_t;
    typedef logic [AxiStrbWidth-1:0]      strb_t;

    typedef struct packed {
    addr_t          paddr;
    axi_pkg::prot_t pprot;   // same as AXI, this is allowed
    logic           psel;    // onehot
    logic           penable;
    logic           pwrite;
    data_t          pwdata;
    strb_t          pstrb;
    } apb_req_t;

    typedef struct packed {
    logic  pready;
    data_t prdata;
    logic  pslverr;
    } apb_resp_t;

    //Single APB Slave -> All OBI Addr
    localparam rule_t [0:0] AddrMap = '{
        '{idx: 32'd0, start_addr: eros_pkg::GLOBAL_BASE_ADDRESS, end_addr: eros_pkg::GLOBAL_END_ADDRESS}};

    // Define AXI-LITE
    `AXI_LITE_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t)
    `AXI_LITE_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t)
    `AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_t)

    `AXI_LITE_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t)
    `AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_t, data_t)

    `AXI_LITE_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
    `AXI_LITE_TYPEDEF_RESP_T(axi_resp_t, b_chan_t, r_chan_t)

    // master axi-lite
    axi_req_t  axi_lite_req;
    axi_resp_t axi_lite_resp;

    // slave
    apb_req_t  apb_req;
    apb_resp_t apb_resp;

  `AXI_LITE_ASSIGN_TO_REQ(axi_lite_req, axi_lite_slave)
  `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_slave, axi_lite_resp)

//    `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_slave, axi_lite_req)
//    `AXI_LITE_ASSIGN_TO_RESP(axi_lite_resp, axi_lite_slave)

  axi_lite_to_apb #(
    .NoApbSlaves      ( NoApbSlaves         ),
    .NoRules          ( NoAddrRules         ),
    .AddrWidth        ( S00_AXI_ADDR_WIDTH  ),
    .DataWidth        ( 32'd32              ),
    .PipelineRequest  ( '0                  ), //TODO:check change to 0
    .PipelineResponse ( '0                  ), //TODO:check change to 0
    .axi_lite_req_t   ( axi_req_t           ),
    .axi_lite_resp_t  ( axi_resp_t          ),
    .apb_req_t        ( apb_req_t           ),
    .apb_resp_t       ( apb_resp_t          ),
    .rule_t           ( rule_t              )
  ) i_axi_lite_to_apb_dut (
    .clk_i ,
    .rst_ni,
    .axi_lite_req_i  ( axi_lite_req      ),
    .axi_lite_resp_o ( axi_lite_resp     ),
    .apb_req_o       ( apb_req      ),
    .apb_resp_i      ( apb_resp    ),
    .addr_map_i      ( AddrMap      )
  );


apb_to_obi_wrapper #(
    .apb_req_t (apb_req_t),
    .apb_rsp_t (apb_resp_t),
    .obi_req_t (obi_req_t),
    .obi_rsp_t (obi_resp_t)
) apb_to_obi_wrapper_i (
    .clk_i,
    .rst_ni,
  // Subordinate APB port.
    .apb_req_i(apb_req),
    .apb_rsp_o(apb_resp),
  // Manager OBI port.
    .obi_req_o(axi_obi_master_req),
    .obi_rsp_i(axi_obi_master_resp)
);

//////////////////////////////////////////////
//                  EROS                    //
//////////////////////////////////////////////




  logic clk_cg;

  eros_clock_gate eros_clock_gate_i (
      .clk_i    (clk_i),
      .test_en_i(1'b0),
      .en_i     (en_i),
      .clk_o    (clk_cg)
  );


  eros_top #(
    .obi_req_t            (obi_req_t  ),
    .obi_resp_t           (obi_resp_t )
  ) eros_top_i (
      .clk_i(clk_cg),
      .rst_ni,
      .ext_master_req_i(axi_obi_master_req),
      .ext_master_resp_o(axi_obi_master_resp),
      .ext_slave_req_o,
      .ext_slave_resp_i,
      .csr_reg_req_i(axi_reg_master_req),
      .csr_reg_resp_o(axi_reg_master_rsp),
      .debug_req_i,
      .pwrgate_ni,
      .pwrgate_ack_no,
      .set_retentive_ni,
      .sleep_o,
      .interrupt_o
  );
  
endmodule

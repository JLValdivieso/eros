// Copyright 2026 CEIMM UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Jonathan Valdivieso (jonathan.lvaldivieso@upm.es)

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "obi/typedef.svh"

module eros_top_wrapper_axi_v2
  import reg_pkg::*;
  import eros_pkg::*;
  import obi_pkg::*;
#(
    parameter NHARTS  = 3,
    parameter N_BANKS = 2,

    parameter S00_AXI_ADDR_WIDTH        = 32,
    parameter S00_AXI_DATA_WIDTH        = 32,
    parameter S00_AXI_ID_WIDTH_SLAVE    = 32,
    parameter S00_AXI_USER_WIDTH        = 32,
    parameter int unsigned MaxTrans     = 4,

    parameter type axi_slv_req_t        = logic,
    parameter type axi_slv_rsp_t        = logic,
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    // For PULP SoCs
    parameter type reg_req_t            = logic, 
    parameter type reg_rsp_t            = logic
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
    // Control and Status Register for PULP SoCs
    // ----------------------------------------------
    input  reg_req_t    reg_req_i,
    output reg_rsp_t    reg_rsp_o,

    // output logic            axi_S01_busy_o,

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


////////////////////
// AXI64 -> OBI32 //
////////////////////

`OBI_TYPEDEF_DEFAULT_ALL(pulp_obi, obi_pkg::ObiDefaultConfig)

pulp_obi_req_t axi2obi_req;
pulp_obi_rsp_t axi2obi_rsp;

axi_to_obi #(
    .ObiCfg       (obi_pkg::ObiDefaultConfig),
    .AxiAddrWidth (S00_AXI_ADDR_WIDTH),
    .AxiDataWidth (S00_AXI_DATA_WIDTH),
    .AxiIdWidth   (S00_AXI_ID_WIDTH_SLAVE),
    .AxiUserWidth (S00_AXI_USER_WIDTH),
    .MaxTrans      (MaxTrans),

    .axi_req_t    (axi_slv_req_t),
    .axi_rsp_t    (axi_slv_rsp_t),

    .obi_req_t    (pulp_obi_req_t),
    .obi_rsp_t    (pulp_obi_rsp_t),
    .obi_a_chan_t (pulp_obi_a_chan_t),
    .obi_r_chan_t (pulp_obi_r_chan_t)
) i_axi_to_obi (

    .clk_i                    (clk_i),
    .rst_ni                   (rst_ni),
    .testmode_i               (1'b0),

    .axi_req_i                (axi_S00_req_i),
    .axi_rsp_o                (axi_S00_rsp_o),

    .obi_req_o                (axi2obi_req),
    .obi_rsp_i                (axi2obi_rsp),

    .req_aw_id_o              ( ),
    .req_aw_user_o            ( ),
    .req_w_user_o             ( ),

    .req_write_aid_i          ('0),
    .req_write_auser_i        ('0),
    .req_write_wuser_i        ('0),

    .req_ar_id_o              ( ),
    .req_ar_user_o            ( ),

    .req_read_aid_i           ('0),
    .req_read_auser_i         ('0),

    .rsp_write_aw_user_o      ( ),
    .rsp_write_w_user_o       ( ),
    .rsp_write_bank_strb_o    ( ),
    .rsp_write_rid_o          ( ),
    .rsp_write_ruser_o        ( ),
    .rsp_write_last_o         ( ),
    .rsp_write_hs_o           ( ),

    .rsp_b_user_i             ('0),

    .rsp_read_ar_user_o       ( ),
    .rsp_read_size_enable_o   ( ),
    .rsp_read_rid_o           ( ),
    .rsp_read_ruser_o         ( ),

    .rsp_r_user_i             ('0)
);

// -----------------------------------------------------------------------------
// OBI v1.6 -> EROS OBI adapter
// -----------------------------------------------------------------------------

assign axi_obi_master_req.req   = axi2obi_req.req;
assign axi_obi_master_req.addr  = axi2obi_req.a.addr;
assign axi_obi_master_req.we    = axi2obi_req.a.we;
assign axi_obi_master_req.be    = axi2obi_req.a.be;
assign axi_obi_master_req.wdata = axi2obi_req.a.wdata;

assign axi2obi_rsp.gnt             = axi_obi_master_resp.gnt;
assign axi2obi_rsp.rvalid          = axi_obi_master_resp.rvalid;
assign axi2obi_rsp.r.rdata         = axi_obi_master_resp.rdata;
assign axi2obi_rsp.r.rid           = '0;
assign axi2obi_rsp.r.err           = 1'b0;
assign axi2obi_rsp.r.r_optional    = '0;

// -----------------------------------------------------------------------------
// Register Interface adapter
// -----------------------------------------------------------------------------
reg_pkg::reg_req_t eros_reg_req;
reg_pkg::reg_rsp_t eros_reg_rsp;

assign eros_reg_req.valid = reg_req_i.valid;
assign eros_reg_req.write = reg_req_i.write;
assign eros_reg_req.wstrb = reg_req_i.wstrb;
assign eros_reg_req.addr  = reg_req_i.addr[31:0];
assign eros_reg_req.wdata = reg_req_i.wdata[31:0];

assign reg_rsp_o.ready = eros_reg_rsp.ready;
assign reg_rsp_o.error = eros_reg_rsp.error;
assign reg_rsp_o.rdata = eros_reg_rsp.rdata;


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
      .csr_reg_req_i(eros_reg_req),
      .csr_reg_resp_o(eros_reg_rsp),
      .debug_req_i,
      .pwrgate_ni,
      .pwrgate_ack_no,
      .set_retentive_ni,
      .sleep_o,
      .interrupt_o
  );
  
endmodule

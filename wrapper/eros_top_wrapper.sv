// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module eros_top_wrapper
//  import eros_obi_pkg::*;
  import reg_pkg::*;
  import eros_pkg::*;
#(
    parameter NHARTS  = 3,
    parameter N_BANKS = 2,
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Top level clock gating unit enable
    input logic en_i,


    //Bus External Master
    input  obi_req_t  ext_master_req_i,
    output obi_resp_t ext_master_resp_o,

    //Bus External Slave
    output obi_req_t  ext_slave_req_o,
    input  obi_resp_t ext_slave_resp_i,

    //CSR
    input  reg_req_t csr_reg_req_i,
    output reg_rsp_t csr_reg_resp_o,

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
      .ext_master_req_i,
      .ext_master_resp_o,
      .ext_slave_req_o,
      .ext_slave_resp_i,
      .csr_reg_req_i,
      .csr_reg_resp_o,
      .debug_req_i,
      .pwrgate_ni,
      .pwrgate_ack_no,
      .set_retentive_ni,
      .sleep_o,
      .interrupt_o
  );

endmodule

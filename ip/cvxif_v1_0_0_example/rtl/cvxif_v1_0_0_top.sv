// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module  cvxif_v1_0_0_top #(

  parameter type obi_req_t            = logic,
  parameter type obi_resp_t           = logic,
  // CVXIF Types
  parameter  int unsigned NrRgprPorts         = 2,
  parameter  int unsigned XLEN                = 32,
  parameter  type         readregflags_t      = logic,
  parameter  type         writeregflags_t     = logic,
  parameter  type         id_t                = logic,
  parameter  type         hartid_t            = logic,
  parameter  type         x_issue_req_t       = logic,
  parameter  type         x_issue_resp_t      = logic,
  parameter  type         x_register_t        = logic,
  parameter  type         x_commit_t          = logic,
  parameter  type         x_result_t          = logic,
  localparam type         registers_t         = logic [NrRgprPorts-1:0][XLEN-1:0],
  parameter  type cvxif_req_t          = logic,
  parameter  type cvxif_resp_t         = logic
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // OBI
    output  obi_req_t  obi_req_o,
    input   obi_resp_t obi_resp_i,

    //CV-X-IF
    input  cvxif_req_t  cvxif_req_i,
    output cvxif_resp_t cvxif_resp_o
);

  logic obi_start;
  logic obi_we;
  logic obi_done;
  logic [31:0] obi_addr;
  logic [31:0] obi_wdata;
  logic [31:0] obi_read_data;

  cvxif_v1_0_0_csr #(
    .NrRgprPorts(NrRgprPorts),
    .XLEN(XLEN),
    .readregflags_t(readregflags_t),
    .writeregflags_t(writeregflags_t),
    .id_t(id_t),
    .hartid_t(hartid_t),
    .x_issue_req_t(x_issue_req_t),
    .x_issue_resp_t(x_issue_resp_t),
    .x_register_t(x_register_t),
    .x_commit_t(x_commit_t),
    .x_result_t(x_result_t),
    .cvxif_req_t(cvxif_req_t),
    .cvxif_resp_t(cvxif_resp_t)
  ) cvxif_v1_0_0_csr_i (
    .clk_i,
    .rst_ni,

    .obi_start_o(obi_start),
    .obi_we_o(obi_we),
    .obi_done_i(obi_done),

    .obi_addr_o(obi_addr),
    .obi_write_data_o(obi_wdata),
    .obi_read_data_i(obi_read_data),

    // CV-X-IF
    .cvxif_req_i,
    .cvxif_resp_o
  );

////////////////////////
//    ___  ____ ___   //
//   / _ \| __ )_ _|  //
//  | | | |  _ \| |   //
//  | |_| | |_) | |   //
//   \___/|____/___|  //
//                    //
////////////////////////

  // cvxif_v1_0_0_obi_fsm #(
  //   .obi_req_t  (obi_req_t),
  //   .obi_resp_t (obi_resp_t)
  // ) cvxif_v1_0_0_obi_fsm_i
  // (
  //   // Clock and Reset
  //   .clk_i,
  //   .rst_ni,

  //   .obi_start_i(obi_start),
  //   .obi_we_i(obi_we),
  //   .obi_done_o(obi_done),

  //   .obi_addr_i(obi_addr),
  //   .obi_write_data_i(obi_write_data),
  //   .obi_read_data_o(obi_read_data),

  //   // OBI
  //   .obi_req_o,
  //   .obi_resp_i
  // );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      obi_done <= '0;
      obi_req_o.req <= '0;
      obi_req_o.addr <= '0;
      obi_req_o.be <= '0;
      obi_req_o.we <= '0;
      obi_req_o.wdata <= '0;
      obi_read_data <= '0;
    end else begin
        obi_done <= '0;
      if (obi_start) begin
        obi_done <= '0;
        obi_req_o.req <= '1;
        obi_req_o.addr <= obi_addr;
        obi_req_o.be <= '1;
        obi_req_o.we <= obi_we;
        obi_req_o.wdata <= obi_wdata;
      end

      if (obi_resp_i.gnt) begin
        obi_req_o.req <= '0;
        obi_req_o.addr <= '0;
        obi_req_o.be <= '1;
        obi_req_o.we <= '0;
        obi_req_o.wdata <= '0;
      end

      if (obi_resp_i.rvalid)
        obi_done <= '1;
        obi_read_data <= obi_resp_i.rdata;
    end
  end
endmodule
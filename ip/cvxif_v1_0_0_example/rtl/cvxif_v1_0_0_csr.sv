// Copyright 2024 Thales DIS France SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Original Author: Guillaume Chauvon
// 2025
// Modified Author: Iñigo Diez, Luis Waucquez

module cvxif_v1_0_0_csr
  import cvxif_v1_0_0_instr_pkg::*;
#(
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
    parameter  type         cvxif_req_t         = logic,
    parameter  type         cvxif_resp_t        = logic,
    localparam type         registers_t         = logic [NrRgprPorts-1:0][XLEN-1:0]
) (
    input  logic        clk_i,        // Clock
    input  logic        rst_ni,       // Asynchronous reset active low

    // CSR
    output logic obi_start_o,
    output logic obi_we_o,
    input logic obi_done_i,

    output logic [31:0] obi_addr_o,
    output logic [31:0] obi_write_data_o,
    input logic [31:0] obi_read_data_i,

    input  cvxif_req_t  cvxif_req_i,
    output cvxif_resp_t cvxif_resp_o
);

  // Issue interface signals
  x_issue_req_t  issue_req;
  x_issue_resp_t issue_resp;
  logic issue_valid, issue_ready;

  // Register interface signals
  x_register_t register;
  logic register_valid;

  // Decoder and controller signals
  registers_t registers;
  opcode_t opcode;
  hartid_t issue_hartid, hartid;
  id_t issue_id, id;
  logic [4:0] issue_rd, rd;
  logic [XLEN-1:0] result;
  logic            we;

  // Issue and Register interface
  // Mandatory when X_ISSUE_REGISTER_SPLIT = 0
  assign cvxif_resp_o.issue_ready      = issue_ready;
  assign cvxif_resp_o.issue_resp       = issue_resp;
  assign cvxif_resp_o.register_ready   = cvxif_resp_o.issue_ready;

  assign issue_req                     = cvxif_req_i.issue_req;
  assign issue_valid                   = cvxif_req_i.issue_valid;
  assign register                      = cvxif_req_i.register;
  assign register_valid                = cvxif_req_i.register_valid;


  cvxif_v1_0_0_instr_decoder #(
      .copro_issue_resp_t (cvxif_v1_0_0_instr_pkg::copro_issue_resp_t),
      .opcode_t (cvxif_v1_0_0_instr_pkg::opcode_t),
      .NbInstr   (cvxif_v1_0_0_instr_pkg::NbInstr),
      .CoproInstr(cvxif_v1_0_0_instr_pkg::CoproInstr),
      .NrRgprPorts(NrRgprPorts),
      .hartid_t (hartid_t),
      .id_t (id_t),
      .x_issue_req_t (x_issue_req_t),
      .x_issue_resp_t (x_issue_resp_t),
      .x_register_t (x_register_t),
      .registers_t (registers_t)
  ) cvxif_v1_0_0_instr_decoder_i (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .issue_valid_i   (issue_valid),
      .issue_req_i     (issue_req),
      .issue_ready_o   (issue_ready),
      .issue_resp_o    (issue_resp),
      .register_valid_i(register_valid),
      .register_i      (register),
      .registers_o     (registers),
      .opcode_o        (opcode),
      .hartid_o        (issue_hartid),
      .id_o            (issue_id),
      .rd_o            (issue_rd)
  );

  logic controller_valid;
  // Result interface
  cvxif_v1_0_0_controller #(
      .NrRgprPorts(NrRgprPorts),
      .XLEN(XLEN),
      .hartid_t(hartid_t),
      .id_t(id_t),
      .registers_t(registers_t)
  ) cvxif_v1_0_0_controller_i (
      .clk_i,
      .rst_ni ,
      .registers_i(registers),
      .opcode_i   (opcode),
      .hartid_i   (issue_hartid),
      .id_i       (issue_id),
      .rd_i       (issue_rd),
      .hartid_o   (hartid),
      .id_o       (id),
      .result_o   (result),
      .valid_o    (controller_valid),
      .rd_o       (rd),
      .we_o       (we),
      // CSR
      .obi_start_o,
      .obi_we_o,
      .obi_done_i,

      .obi_addr_o,
      .obi_write_data_o,
      .obi_read_data_i
  );


  always_comb begin
    cvxif_resp_o.result_valid  = controller_valid;  //TODO Should wait for ready from CPU
    cvxif_resp_o.result.hartid = hartid;
    cvxif_resp_o.result.id     = id;
    cvxif_resp_o.result.data   = result;
    cvxif_resp_o.result.rd     = rd;
    cvxif_resp_o.result.we     = we;
  end

endmodule

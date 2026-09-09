// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module cvxif_v1_0_0_controller
  import cvxif_v1_0_0_instr_pkg::*;
#(
    parameter int unsigned NrRgprPorts = 2,
    parameter int unsigned XLEN = 32,
    parameter type hartid_t = logic,
    parameter type id_t = logic,
    parameter type registers_t = logic

) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  registers_t            registers_i,
  input  opcode_t               opcode_i,
  input  hartid_t               hartid_i,
  input  id_t                   id_i,
  input  logic       [     4:0] rd_i,
  output logic       [XLEN-1:0] result_o,
  output hartid_t               hartid_o,
  output id_t                   id_o,
  output logic       [     4:0] rd_o,
  output logic                  valid_o,
  output logic                  we_o,

  output logic obi_start_o,
  output logic obi_we_o,
  input logic obi_done_i,

  output logic [31:0] obi_addr_o,
  output logic [31:0] obi_write_data_o,
  input logic [31:0] obi_read_data_i

);


  logic [XLEN-1:0] result_n, result_q;
  hartid_t hartid_n, hartid_q;
  id_t id_n, id_q;
  logic valid_n, valid_q;
  logic [4:0] rd_n, rd_q;
  logic we_n, we_q;

  assign result_o = result_q;
  assign hartid_o = hartid_q;
  assign id_o     = id_q;
  assign valid_o  = valid_q;
  assign rd_o     = rd_q;
  assign we_o     = we_q;


  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      obi_start_o <= '0;
      obi_we_o <= '0;
      obi_addr_o <= '0;
      obi_write_data_o <= '0;
    end else begin
      obi_start_o <= '0;
      if (opcode_i == cvxif_v1_0_0_instr_pkg::LOAD) begin
        obi_addr_o <= registers_i[0];
        obi_start_o <= 1'b1;
        obi_we_o <= 1'b0;
      end else if(opcode_i == cvxif_v1_0_0_instr_pkg::STORE) begin
        obi_addr_o <= registers_i[1];
        obi_write_data_o <= registers_i[0];
        obi_start_o <= 1'b1;
        obi_we_o <= 1'b1;
      end
    end
  end

  logic flag;
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      result_q <= '0;
      hartid_q <= '0;
      id_q     <= '0;
      valid_q  <= '0;
      rd_q     <= '0;
      we_q     <= '0;
      flag     <= '0;
    end else begin
      valid_q  <= '0;
      we_q     <= '0;
      if (obi_done_i & ~flag) begin
        result_q  <= obi_read_data_i;
        valid_q   <= 1'b1;
        we_q      <= 1'b1;
        flag      <= 1'b1;
      end else begin
        if (opcode_i == cvxif_v1_0_0_instr_pkg::LOAD || opcode_i == cvxif_v1_0_0_instr_pkg::STORE) begin
          hartid_q  <= hartid_i;
          id_q      <= id_i;
          rd_q      <= rd_i;
        end
          if (~obi_done_i) begin
            flag      <= 1'b0;
          end
      end
    end
  end


endmodule

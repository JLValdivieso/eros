// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module obi_pipelined_delay #(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter NDELAY = 2
) (
    input logic clk_i,
    input logic rst_ni,
    input logic clear_pipeline,

    input obi_req_t core_instr_req_i,
    output obi_req_t core_instr_req_o,
    input logic core_instr_resp_gnt_i,
    output logic core_instr_resp_gnt_o
);

  obi_req_t [NDELAY-2:0] core_instr_req_s;
  logic     [NDELAY-2:0] core_instr_resp_gnt_s;

  for (genvar i = 0; i < NDELAY; i++) begin
    if (i == 0) begin
      obi_sngreg obi_sngreg_i (
          .clk_i,
          .rst_ni,
          .clear_pipeline,
          .core_instr_req_i(core_instr_req_i),
          .core_instr_req_o(core_instr_req_s[i]),
          .core_instr_resp_gnt_i(core_instr_resp_gnt_s[i]),
          .core_instr_resp_gnt_o(core_instr_resp_gnt_o)
      );
    end else if (i == NDELAY - 1) begin
      obi_sngreg obi_sngreg_i (
          .clk_i,
          .rst_ni,
          .clear_pipeline,
          .core_instr_req_i(core_instr_req_s[i-1]),
          .core_instr_req_o(core_instr_req_o),
          .core_instr_resp_gnt_i(core_instr_resp_gnt_i),
          .core_instr_resp_gnt_o(core_instr_resp_gnt_s[i-1])
      );
    end else begin
      obi_sngreg obi_sngreg_i (
          .clk_i,
          .rst_ni,
          .clear_pipeline,
          .core_instr_req_i(core_instr_req_s[i-1]),
          .core_instr_req_o(core_instr_req_s[i]),
          .core_instr_resp_gnt_i(core_instr_resp_gnt_s[i]),
          .core_instr_resp_gnt_o(core_instr_resp_gnt_s[i-1])
      );
    end
  end

endmodule

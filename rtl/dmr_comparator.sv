// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)
/*
 *
 *
 *
 */

module dmr_comparator #(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter NHARTS = 2
) (
    // Instruction Bus
    input obi_req_t [NHARTS-1 : 0] core_instr_req_i,
    output obi_req_t compared_core_instr_req_o,

    // Data Bus
    input obi_req_t [NHARTS-1 : 0] core_data_req_i,
    output obi_req_t compared_core_data_req_o,

    output logic error_o
);

  logic [1:0] error_s;

  //Checker

  always_comb begin
    error_s = '0;
    //Instruction
    // Check only wdata if a addr request it s ordered
    if (((core_instr_req_i[0].addr != core_instr_req_i[1].addr) & core_instr_req_i[0].req & core_instr_req_i[1].req) ||
        // Check only wdata if a write request it s ordered
        ((core_instr_req_i[0].wdata != core_instr_req_i[1].wdata) & core_instr_req_i[0].we & core_instr_req_i[1].we) ||
            (core_instr_req_i[0].be != core_instr_req_i[1].be) ||
            (core_instr_req_i[0].we != core_instr_req_i[1].we) ||
            (core_instr_req_i[0].req != core_instr_req_i[1].req)) begin
      error_s[0] = 1'b1;
    end
    //Data
    // Check only wdata if a addr request it s ordered
    if (((core_data_req_i[0].addr != core_data_req_i[1].addr & core_data_req_i[0].req & core_data_req_i[1].req)) ||
        // Check only wdata if a write request it s ordered
        ((core_data_req_i[0].wdata != core_data_req_i[1].wdata) & core_data_req_i[0].we & core_data_req_i[1].we) ||
            (core_data_req_i[0].be != core_data_req_i[1].be) ||
            (core_data_req_i[0].we != core_data_req_i[1].we) ||
            (core_data_req_i[0].req != core_data_req_i[1].req)) begin
      error_s[1] = 1'b1;
    end
  end

  //Gated-Output
  //Output is gated to ensure that an error does not propagate to the rest of the circuit.
  always_comb begin
    if (error_s[0] || error_s[1]) begin
      compared_core_instr_req_o = '0;
      compared_core_data_req_o  = '0;
    end else begin
      compared_core_instr_req_o = core_instr_req_i[0];
      compared_core_data_req_o  = core_data_req_i[0];
    end
  end

  assign error_o = error_s[0] | error_s[1];


endmodule



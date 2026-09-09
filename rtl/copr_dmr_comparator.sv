// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)
/*
 *
 *
 *
 */

module copr_dmr_comparator #(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter NHARTS = 2
) (
    input obi_req_t [NHARTS-1 : 0] obi_req_i,
    output obi_req_t compared_obi_req_o,

    output logic error_o
);

  logic error_s;

  //Checker

  always_comb begin
    error_s = '0;
    //Instruction
    // Check only if a transaction is requested
    if (obi_req_i[0].req || obi_req_i[1].req) begin
      if ((obi_req_i[0].addr != obi_req_i[1].addr) ||
          // Check only wdata if a write request it s ordered
          (obi_req_i[0].wdata != obi_req_i[1].wdata) ||
              (obi_req_i[0].be != obi_req_i[1].be) ||
              (obi_req_i[0].we != obi_req_i[1].we) ||
              (obi_req_i[0].req != obi_req_i[1].req)) begin
          error_s = 1'b1;
      end
    end
  end

  //Gated-Output
  //Output is gated to ensure that an error does not propagate to the rest of the circuit.
  always_comb begin
    if (error_s) begin
      compared_obi_req_o = '0;
    end else begin
      compared_obi_req_o = obi_req_i;
    end
  end

  assign error_o = error_s;


endmodule



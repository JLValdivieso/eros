// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)
/*
 *
 *
 *
 */

module copr_tmr_voter
  import eros_pkg::*;
#(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter NHARTS = 3
) (
    input obi_req_t [NHARTS-1 : 0] obi_req_i,
    output obi_req_t voted_obi_req_o,

    input logic enable_i,

    output logic error_o,
    output [NHARTS-1:0] error_id_o
);

  logic [NHARTS-1:0] error_s;

  obi_req_t voted_obi_req_s;

  // Classic Implementation Voter

  assign  voted_obi_req_s.addr = ((obi_req_i[0].addr & obi_req_i[1].addr) |
                                 (obi_req_i[1].addr & obi_req_i[2].addr) |
                                 (obi_req_i[0].addr & obi_req_i[2].addr));

  assign  voted_obi_req_s.wdata = (obi_req_i[0].wdata & obi_req_i[1].wdata) |
                                    (obi_req_i[1].wdata & obi_req_i[2].wdata) |
                                    (obi_req_i[0].wdata & obi_req_i[2].wdata);

  assign  voted_obi_req_s.we = (obi_req_i[0].we & obi_req_i[1].we) |
                                (obi_req_i[1].we & obi_req_i[2].we) |
                                (obi_req_i[0].we & obi_req_i[2].we);

  assign  voted_obi_req_s.be = (obi_req_i[0].be & obi_req_i[1].be) |
                                (obi_req_i[1].be & obi_req_i[2].be) |
                                (obi_req_i[0].be & obi_req_i[2].be);

  assign  voted_obi_req_s.req = (obi_req_i[0].req & obi_req_i[1].req) |
                                (obi_req_i[1].req & obi_req_i[2].req) |
                                (obi_req_i[0].req & obi_req_i[2].req);

  // Checker
  always_comb begin
    error_s = '0;

    //Instruction
    //Added check for req addr or wdata
    for (int i = 0; i < NHARTS; i++) begin : instr_bus_checker
      if ((((voted_obi_req_s.addr != obi_req_i[i].addr) & obi_req_i[i].req) ||
            ((voted_obi_req_s.wdata != obi_req_i[i].wdata) & obi_req_i[i].we) ||
            (voted_obi_req_s.be != obi_req_i[i].be) ||
            (voted_obi_req_s.we != obi_req_i[i].we) ||
            (voted_obi_req_s.req != obi_req_i[i].req)) && enable_i) begin
        error_s[i] = 1'b1;
      end
    end
  end


  assign error_id_o = error_s;
  //Error is issued only under request
  assign error_o = ((error_s[0] | error_s[1] | error_s[2]) & voted_obi_req_s.req);

  assign voted_obi_req_o = voted_obi_req_s;

endmodule



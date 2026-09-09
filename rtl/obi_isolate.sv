// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module obi_isolate
  import reg_pkg::*;
#(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter ISOLATE_VAL               = 32'h0
) (
    input logic clk_i,
    input logic rst_ni,
    input logic dcls_wfi_i,

    input obi_req_t obi_req_i,
    input obi_resp_t obi_resp_i,
    output obi_resp_t obi_isolate_o


);

  logic isolate_valid_q;
  logic expected_rvalid;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        isolate_valid_q <= '0;
        expected_rvalid <= '0;
      end else begin
        if (dcls_wfi_i == 1'b0) begin  //clear
          isolate_valid_q <= '0;
          //if req & gnt before wfi halt, it needs a rvalid ack otherwise could stall waiting that read/write request.
          expected_rvalid <= (obi_req_i.req & obi_resp_i.gnt) | (expected_rvalid & ~obi_resp_i.rvalid);
        end else begin
          isolate_valid_q <= obi_isolate_o.gnt;
          expected_rvalid <= '0;
        end
      end
    end

    assign obi_isolate_o.gnt = obi_req_i.req;
    assign obi_isolate_o.rvalid = isolate_valid_q | expected_rvalid;
    assign obi_isolate_o.rdata = ISOLATE_VAL;  //wfi instruction

endmodule  // obi_pipelined

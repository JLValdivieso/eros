// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module cvxif_v1_0_0_obi_fsm #(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    input logic obi_start_i,
    input logic obi_we_i,
    output logic obi_done_o,

    input logic [31:0] obi_addr_i,
    input logic [31:0] obi_write_data_i,
    output logic [31:0] obi_read_data_o,

    // OBI
    output  obi_req_t  obi_req_o,
    input   obi_resp_t obi_resp_i

);

  // FSM state encoding
  typedef enum logic [2:0] {
    IDLE,
    READ_WRITE,
    WAIT,
    FINISH
  } obi_fsm_e;

  obi_fsm_e obi_fsm_cs, obi_fsm_ns;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      obi_fsm_cs <= IDLE;
    end else begin
      obi_fsm_cs <= obi_fsm_ns;
    end
  end

  always_comb begin
    obi_fsm_ns = obi_fsm_cs;
    case (obi_fsm_cs)
      IDLE: begin
        if (obi_start_i) obi_fsm_ns = READ_WRITE;
        else obi_fsm_ns = IDLE;
      end
      READ_WRITE: begin
        if (obi_resp_i.gnt) obi_fsm_ns = WAIT;
        else obi_fsm_ns = READ_WRITE;
      end
      WAIT: begin
        if (obi_resp_i.rvalid) obi_fsm_ns = FINISH;
        else obi_fsm_ns = WAIT;
      end
      FINISH: begin
        obi_fsm_ns = IDLE;
      end
      default: begin end
    endcase
  end

  logic [31:0] obi_addr_q;
  logic [31:0] obi_wdata_q;
  logic [31:0] obi_rdata_q;
  logic obi_we_q;

  assign obi_req_o.req = (obi_fsm_cs == READ_WRITE);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        obi_req_o.addr <= obi_addr_i;
        obi_req_o.be <= '1;
        obi_req_o.we <= obi_we_i;
        obi_req_o.wdata <= obi_write_data_i;
    end else begin
        obi_done_o <= '1;
      if (obi_fsm_cs == IDLE) begin
        obi_req_o.addr <= obi_addr_i;
        obi_req_o.be <= '1;
        obi_req_o.we <= obi_we_i;
        obi_req_o.wdata <= obi_write_data_i;
      end
      if (obi_resp_i.rvalid)
        obi_read_data_o <= obi_resp_i.rdata;
        obi_done_o <= '1;
    end
  end

endmodule
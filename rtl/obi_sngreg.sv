// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module obi_sngreg
  import reg_pkg::*;
#(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic  
) (
    input logic clk_i,
    input logic rst_ni,
    input logic clear_pipeline,

    input obi_req_t core_instr_req_i,
    output obi_req_t core_instr_req_o,
    input logic core_instr_resp_gnt_i,
    output logic core_instr_resp_gnt_o
);


  obi_req_t core_instr_req_ff;

  logic clear;
  logic load;

  // Accept req while N req not 0 or req are accepeted while another one is pending
  assign core_instr_resp_gnt_o = (core_instr_req_i.req && core_instr_req_ff.req == 1'b0) ||
                               (core_instr_resp_gnt_i && core_instr_req_i.req);

  assign core_instr_req_o = core_instr_req_ff;

  assign clear = (core_instr_req_i.req == 1'b0 & core_instr_resp_gnt_i == 1'b1)  |
               (core_instr_req_i.req == 1'b0 & core_instr_req_ff.req == 1'b0)  |
               clear_pipeline; //injects '0' //Todo remove core_instr_resp_rvalid

  always_comb begin
    if ((core_instr_req_i.req & core_instr_req_ff.req == 1'b0) |
        (core_instr_req_i.req & core_instr_resp_gnt_i))
      load = 1'b1;
    else load = 1'b0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : pipelined_req
    if (~rst_ni) begin
      core_instr_req_ff.req <= '0;
    end else begin
      if (load) begin
        core_instr_req_ff.req <= core_instr_req_i.req;
      end
      if (clear) begin
        core_instr_req_ff.req <= '0;
      end else begin
        if (clear_pipeline) core_instr_req_ff.req <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : pipelined_addr
    if (~rst_ni) begin
      core_instr_req_ff.addr <= '0;
    end else begin
      if (load) begin
        core_instr_req_ff.addr <= core_instr_req_i.addr;
      end
      if (clear) begin
        core_instr_req_ff.addr <= core_instr_req_i.addr;
      end else begin
        if (clear_pipeline) core_instr_req_ff.addr <= core_instr_req_i.addr;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : pipelined_we
    if (~rst_ni) begin
      core_instr_req_ff.we <= '0;
    end else begin
      if (load) begin
        core_instr_req_ff.we <= core_instr_req_i.we;
      end
      if (clear) begin
        core_instr_req_ff.we <= '0;
      end else begin
        if (clear_pipeline) core_instr_req_ff.we <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : pipelined_wdata
    if (~rst_ni) begin
      core_instr_req_ff.wdata <= '0;
    end else begin
      if (load) begin
        core_instr_req_ff.wdata <= core_instr_req_i.wdata;
      end
      if (clear) begin
        core_instr_req_ff.wdata <= core_instr_req_i.wdata;
      end else begin
        if (clear_pipeline) core_instr_req_ff.wdata <= core_instr_req_i.wdata;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : pipelined_be
    if (~rst_ni) begin
      core_instr_req_ff.be <= '0;
    end else begin
      if (load) begin
        core_instr_req_ff.be <= core_instr_req_i.be;
      end
      if (clear) begin
        core_instr_req_ff.be <= core_instr_req_i.be;
      end else begin
        if (clear_pipeline) core_instr_req_ff.be <= core_instr_req_i.be;
      end
    end
  end

endmodule  // obi_pipelined

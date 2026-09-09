// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module copr_lockstep_reg #(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter NCYCLES = 2
) (
    input logic clk_i,
    input logic rst_ni,
    input logic enable_i,

    input  obi_req_t [1:0] obi_req_i,
    output obi_req_t [1:0] obi_req_o,

    input  obi_resp_t obi_resp_i,
    output obi_resp_t [1:0] obi_resp_o
);

  logic                         pipe_gnt;
  logic                         enable_ff;
  //TODO: remove gnt that is not used for returned resp delayed
  obi_req_t                     req_ff;
  logic     [NCYCLES-1:0]       resp_ff_rvalid;
  logic     [NCYCLES-1:0][31:0] resp_ff_rdata;

  for (genvar i = 0; i < 2; i++) begin : Nharts_delayed_mux

    if (i == 0) begin
      if (NCYCLES == 1) begin
        // Instruction
        obi_sngreg #(
            .obi_req_t            (obi_req_t  ),
            .obi_resp_t           (obi_resp_t )
        )obi_sngreg0_i (
            .clk_i,
            .rst_ni,
            .clear_pipeline       (~enable_i),
            .core_instr_req_i     (obi_req_i[0]),
            .core_instr_req_o     (req_ff),
            .core_instr_resp_gnt_i(obi_resp_i.gnt),
            .core_instr_resp_gnt_o(pipe_gnt)
        );

      end else begin
        obi_pipelined_delay #(
            .obi_req_t            (obi_req_t  ),
            .obi_resp_t           (obi_resp_t ),
            .NDELAY(NCYCLES)
        ) obi_pipelined_delay0_i (
            .clk_i,
            .rst_ni,
            .clear_pipeline       (~enable_i),
            .core_instr_req_i     (obi_req_i[0]),
            .core_instr_req_o     (req_ff),
            .core_instr_resp_gnt_i(obi_resp_i.gnt),
            .core_instr_resp_gnt_o(pipe_gnt)
        );
      end
    end

    //Signal assignment
    if (i == 0) begin
      assign obi_req_o[0]         = req_ff;
      assign obi_resp_o[0].rdata  = obi_resp_i.rdata;
      assign obi_resp_o[0].rvalid = obi_resp_i.rvalid;
      assign obi_resp_o[0].gnt    = pipe_gnt;
    end else begin
      assign obi_req_o[1].addr = obi_req_i[1].addr;
      assign obi_req_o[1].req = obi_req_i[1].req;
      assign obi_req_o[1].be = obi_req_i[1].be;
      assign obi_req_o[1].wdata = obi_req_i[1].wdata;
      // when the buffered [0] req is granted the we is put to '0' in the output, while the output of [1] still one
      assign obi_req_o[1].we = obi_req_i[1].we & obi_req_i[1].req;

      assign obi_resp_o[1].rdata = resp_ff_rdata[NCYCLES-1];
      assign obi_resp_o[1].rvalid = resp_ff_rvalid[NCYCLES-1];
      assign obi_resp_o[1].gnt = obi_resp_i.gnt;
    end
  end

  assign enable_ff = enable_i;

  for (genvar j = 0; j < NCYCLES; j++) begin : N_Cycles_ff
    if (j == 0) begin : gen_first
      always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ndelay
        if (~rst_ni) begin
          resp_ff_rvalid[0] <= '0;
          resp_ff_rdata[0]  <= '0;
        end else if (enable_ff) begin
          resp_ff_rvalid[0] <= obi_resp_i.rvalid;
          resp_ff_rdata[0]  <= obi_resp_i.rdata;
        end
      end
    end else begin : gen_rest
      always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ndelay
        if (~rst_ni) begin
          resp_ff_rvalid[j] <= '0;
          resp_ff_rdata[j]  <= '0;
        end else if (enable_ff) begin
          resp_ff_rvalid[j] <= resp_ff_rvalid[j-1];
          resp_ff_rdata[j]  <= resp_ff_rdata[j-1];
        end
      end
    end
  end
endmodule  // lockstep_reg

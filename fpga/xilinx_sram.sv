// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module sram_wrapper #(
    parameter int unsigned NumWords = 32'd1024,  // Number of Words in data array
    parameter int unsigned DataWidth = 32'd32,  // Data signal width
    // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
    parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1
) (
    input logic clk_i,
    input logic rst_ni,
    // input ports
    input logic req_i,
    input logic we_i,
    input logic [AddrWidth-1:0] addr_i,
    input logic [DataWidth-1:0] wdata_i,
    input logic [DataWidth/8-1:0] be_i,
    // power manager signals that goes to the ASIC macros
    input logic pwrgate_ni,
    output logic pwrgate_ack_no,
    input logic set_retentive_ni,
    // output ports
    output logic [DataWidth-1:0] rdata_o
);

  assign pwrgate_ack_no = pwrgate_ni;
//   xilinx_mem_gen_8192 tc_ram_i (
//       .clka (clk_i),
//       .ena  (req_i),
//       .wea  ({4{req_i & we_i}} & be_i),
//       .addra(addr_i),
//       .dina (wdata_i),
//       // output ports
//       .douta(rdata_o)
//   );

  (* ram_style = "block" *) //Yo can use "distributed", "block" or "ultra" for UltraRAMs
  logic [DataWidth-1:0] ram_memory_contents [NumWords-1:0];

  logic [AddrWidth-1:0] addr_q;

  always_ff @(posedge clk_i) begin

    if (req_i) begin

      if (!we_i) begin
        addr_q <= addr_i;
      end 
      else begin
        integer i;
        for (i = 0; i < DataWidth/8; i++) begin
          if (be_i[i])
            ram_memory_contents[addr_i][8*i +: 8] <= wdata_i[8*i +: 8];
        end

      end
    end

  end

  assign rdata_o = (addr_q < NumWords) ? ram_memory_contents[addr_q] : '0;

endmodule

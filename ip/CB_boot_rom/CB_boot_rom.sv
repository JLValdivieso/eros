/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File: $filename.v
 *
 * Description: Auto-generated bootrom
 */

// Auto-generated code
module CB_boot_rom
  import reg_pkg::*;
(
  input  reg_req_t     reg_req_i,
  output reg_rsp_t     reg_rsp_o
);
  import eros_pkg::*;

  localparam int unsigned RomSize = 128;

  logic [RomSize-1:0][31:0] mem;
  assign mem = {
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h00000013,
    32'h00000013,
    32'hf3dff06f,
    32'h018f2103,
    32'h00000013,
    32'h00000013,
    32'hfedff06f,
    32'h00410113,
    32'h00438393,
    32'h00610c63,
    32'h01d12023,
    32'h0003ae83,
    32'h094f0393,
    32'hf66104e3,
    32'h0ff0000f,
    32'h0382a303,
    32'hf25ff06f,
    32'h00000013,
    32'h00000013,
    32'h00000013,
    32'h00000013,
    32'h7b200073,
    32'h088f2f03,
    32'h08cf2f83,
    32'h7b1f9073,
    32'h0ff0000f,
    32'h090f2f83,
    32'h084f2e83,
    32'h080f2e03,
    32'h07cf2d83,
    32'h078f2d03,
    32'h074f2c83,
    32'h070f2c03,
    32'h06cf2b83,
    32'h068f2b03,
    32'h064f2a83,
    32'h060f2a03,
    32'h05cf2983,
    32'h058f2903,
    32'h054f2883,
    32'h050f2803,
    32'h04cf2783,
    32'h048f2703,
    32'h044f2683,
    32'h040f2603,
    32'h03cf2583,
    32'h038f2503,
    32'h034f2483,
    32'h030f2403,
    32'h02cf2383,
    32'h028f2303,
    32'h024f2283,
    32'h08031a63,
    32'h0ff0000f,
    32'h0342a303,
    32'h200002b7,
    32'h020f2203,
    32'h01cf2183,
    32'h018f2103,
    32'h014f2083,
    32'h343f9073,
    32'h010f2f83,
    32'h341f9073,
    32'h00cf2f83,
    32'h305f9073,
    32'h008f2f83,
    32'h304f9073,
    32'h004f2f83,
    32'h300f9073,
    32'h000f2f83,
    32'h028f2f03,
    32'h20000f37,
    32'h00000013,
    32'h00040067,
    32'h83040413,
    32'h10001437,
    32'h10000537,
    32'h0ff0000f,
    32'hfb5ff06f,
    32'h00051463,
    32'h00254513,
    32'h02050463,
    32'h01852503,
    32'h20000537,
    32'h7b241073,
    32'h7b351073,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h13000000,
    32'h7b200073,
    32'h7b151073,
    32'h02452503,
    32'h20000537,
    32'h00000013,
    32'h00000013,
    32'hff5ff06f,
    32'h10500073,
    32'h00000013,
    32'h00000013,
    32'h00000013,
    32'h00000013
  };

  logic [$clog2(eros_pkg::DEBUG_BOOTROM_SIZE)-1-2:0] word_addr;
  logic [$clog2(RomSize)-1:0] rom_addr;

  assign word_addr = reg_req_i.addr[$clog2(eros_pkg::DEBUG_BOOTROM_SIZE)-1:2];
  assign rom_addr  = word_addr[$clog2(RomSize)-1:0];

  assign reg_rsp_o.error = 1'b0;
  assign reg_rsp_o.ready = 1'b1;

  always_comb begin
    if (word_addr > (RomSize-1)) begin
      reg_rsp_o.rdata = '0;
    end else begin
      reg_rsp_o.rdata = mem[rom_addr];
    end
  end

endmodule

// Copyright 2023 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Simone Machetti - simone.machetti@epfl.ch

module axi2obi #(
  // RISC-V interface parameters
  parameter int WordSize = 32,
  parameter int AddrSize = 32,

  // Parameters of Axi Slave Bus Interface S00_AXI
  parameter int C_S00_AXI_DATA_WIDTH = 32,
  parameter int C_S00_AXI_ADDR_WIDTH = 32
)(
  // ----------------------------
  // RISC-V interface ports
  // ----------------------------
  input  logic                         gnt_i,
  input  logic                         rvalid_i,
  output logic                         we_o,
  output logic [3:0]                   be_o,
  output logic [AddrSize-1:0]         addr_o,
  output logic [WordSize-1:0]         wdata_o,
  input  logic [WordSize-1:0]         rdata_i,
  output logic                         req_o,

  // ----------------------------------------------
  // Ports of Axi Slave Bus Interface S00_AXI
  // ----------------------------------------------

  // Clk and rst signals
  input  logic                         s00_axi_aclk,
  input  logic                         s00_axi_aresetn,

  // Read address channel signals
  input  logic [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_araddr,
  input  logic                         s00_axi_arvalid,
  output logic                         s00_axi_arready,
  input  logic [2:0]                   s00_axi_arprot, // not used

  // Read data channel signals
  output logic [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_rdata,
  output logic [1:0]                   s00_axi_rresp,
  output logic                         s00_axi_rvalid,
  input  logic                         s00_axi_rready,

  // Write address channel signals
  input  logic [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_awaddr,
  input  logic                         s00_axi_awvalid,
  output logic                         s00_axi_awready,
  input  logic [2:0]                   s00_axi_awprot, // not used

  // Write data channel signals
  input  logic [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_wdata,
  input  logic                         s00_axi_wvalid,
  output logic                         s00_axi_wready,
  input  logic [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb, // not used

  // Write response channel signals
  output logic [1:0]                   s00_axi_bresp,
  output logic                         s00_axi_bvalid,
  input  logic                         s00_axi_bready
);

  typedef enum logic [2:0] {
    IDLE, READ1, READ2, READ3, WRITE1, WRITE2, WRITE3
  } state_t;

  state_t currstate, nextstate;
  logic [31:0] curr_addr, next_addr;
  logic [31:0] curr_wdata, next_wdata;
  logic [31:0] curr_rdata, next_rdata;

  assign s00_axi_rresp = 2'b00; // "OKAY"
  assign s00_axi_bresp = 2'b00; // "OKAY"

  // State register
  always_ff @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
    if (!s00_axi_aresetn)
      currstate <= IDLE;
    else
      currstate <= nextstate;
  end

  // Data registers
  always_ff @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
    if (!s00_axi_aresetn) begin
      curr_addr  <= '0;
      curr_wdata <= '0;
      curr_rdata <= '0;
    end else begin
      curr_addr  <= next_addr;
      curr_wdata <= next_wdata;
      curr_rdata <= next_rdata;
    end
  end

  assign addr_o     = curr_addr;
  assign wdata_o    = curr_wdata;
  assign s00_axi_rdata = curr_rdata;

  // FSM logic
  always_comb begin
    nextstate  = currstate;
    next_addr  = curr_addr;
    next_wdata = curr_wdata;
    next_rdata = curr_rdata;

    we_o  = 0;
    be_o  = 4'b0000;
    req_o = 0;

    s00_axi_arready = 0;
    s00_axi_rvalid  = 0;
    s00_axi_awready = 0;
    s00_axi_wready  = 0;
    s00_axi_bvalid  = 0;

    case (currstate)

      IDLE: begin
        if (s00_axi_arvalid) begin
          nextstate       = READ1;
          next_addr       = s00_axi_araddr;
          s00_axi_arready = 1;
        end else if (s00_axi_awvalid && s00_axi_wvalid) begin
          nextstate       = WRITE1;
          next_addr       = s00_axi_awaddr;
          next_wdata      = s00_axi_wdata;
          s00_axi_awready = 1;
          s00_axi_wready  = 1;
        end
      end

      READ1: begin
        req_o = 1;
        we_o  = 0;
        be_o  = 4'b1111;
        if (gnt_i)
          nextstate = READ2;
      end

      READ2: begin
        req_o = 0;
        we_o  = 0;
        be_o  = 4'b1111;
        if (rvalid_i) begin
          next_rdata = rdata_i;
          nextstate  = READ3;
        end
      end

      READ3: begin
        s00_axi_rvalid = 1;
        if (s00_axi_rready)
          nextstate = IDLE;
      end

      WRITE1: begin
        req_o = 1;
        we_o  = 1;
        be_o  = 4'b1111;
        if (gnt_i)
          nextstate = WRITE2;
      end

      WRITE2: begin
        req_o = 0;
        we_o  = 1;
        be_o  = 4'b1111;
        if (rvalid_i)
          nextstate = WRITE3;
      end

      WRITE3: begin
        s00_axi_bvalid = 1;
        if (s00_axi_bready)
          nextstate = IDLE;
      end

      default: nextstate = IDLE;

    endcase
  end

endmodule

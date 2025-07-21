// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module eros_top
  import reg_pkg::*;
  import eros_pkg::*;
#(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter NHARTS  = 3,
    parameter N_BANKS = 2
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    //Bus External Master
    input  obi_req_t  ext_master_req_i,
    output obi_resp_t ext_master_resp_o,

    //Bus External Slave
    output obi_req_t  ext_slave_req_o,
    input  obi_resp_t ext_slave_resp_i,

    //CSR
    input  reg_req_t csr_reg_req_i,
    output reg_rsp_t csr_reg_resp_o,

    // Debug Interface
    input  logic              debug_req_i,
    output logic [NHARTS-1:0] sleep_o,

    // power manager signals that goes to the ASIC macros
    input  logic [N_BANKS-1:0] pwrgate_ni,
    output logic [N_BANKS-1:0] pwrgate_ack_no,
    input  logic [N_BANKS-1:0] set_retentive_ni,

    // Interrupt Interface
    output logic interrupt_o
);



  //Signals

  // Internal master ports
  obi_req_t [NHARTS-1 : 0] core_instr_req;
  obi_resp_t [NHARTS-1 : 0] core_instr_resp;

  obi_req_t [NHARTS-1 : 0] core_data_req;
  obi_resp_t [NHARTS-1 : 0] core_data_resp;

  // Safe Wrapper Control/Status Register
  reg_req_t wrapper_csr_req;
  reg_rsp_t wrapper_csr_resp;

  // Internal slave ports
  obi_req_t peripheral_slave_req;
  obi_resp_t peripheral_slave_resp;

  // RAM memory ports
  obi_req_t [N_BANKS-1:0] ram_req;
  obi_resp_t [N_BANKS-1:0] ram_resp;


  //CPU_System
  safe_cpu_wrapper #(
      .obi_req_t            (obi_req_t  ),
      .obi_resp_t           (obi_resp_t )
      ) safe_cpu_wrapper_i (
      .clk_i,
      .rst_ni,

      // Instruction memory interface
      .core_instr_req_o (core_instr_req),
      .core_instr_resp_i(core_instr_resp),

      // Data memory interface
      .core_data_req_o (core_data_req),
      .core_data_resp_i(core_data_resp),

      // Wrapper Control & Status Rgister
      .wrapper_csr_req_i (wrapper_csr_req),
      .wrapper_csr_resp_o(wrapper_csr_resp),

      // Debug Interface
      .debug_req_i,
      .sleep_o,
      // Interrupt Interface
      .interrupt_o
  );

  //Peripheral System
  periph_system #(
      .obi_req_t            (obi_req_t  ),
      .obi_resp_t           (obi_resp_t )
      )periph_system_i (
      .clk_i,
      .rst_ni,
      .slave_req_i (peripheral_slave_req),
      .slave_resp_o(peripheral_slave_resp)
  );

  memory_sys #(
      .obi_req_t            (obi_req_t  ),
      .obi_resp_t           (obi_resp_t )
    ) memory_sys_i (
      .clk_i,
      .rst_ni,

      .ram_req_i (ram_req),
      .ram_resp_o(ram_resp),
      // power manager signals that goes to the ASIC macros
      .pwrgate_ni,
      .pwrgate_ack_no,
      .set_retentive_ni
  );

  //Bus System
  bus_system #(
      .obi_req_t            (obi_req_t  ),
      .obi_resp_t           (obi_resp_t ),
      .NHARTS(NHARTS)
  ) bus_system_i (
      .clk_i,
      .rst_ni,

      // Internal master ports
      .core_instr_req_i (core_instr_req),
      .core_instr_resp_o(core_instr_resp),

      .core_data_req_i (core_data_req),
      .core_data_resp_o(core_data_resp),

      .ext_master_req_i,
      .ext_master_resp_o,
      .ext_slave_req_o,
      .ext_slave_resp_i,

      .ext_csr_reg_req_i (csr_reg_req_i),
      .ext_csr_reg_resp_o(csr_reg_resp_o),

      // Internal slave ports
      .peripheral_slave_req_o (peripheral_slave_req),
      .peripheral_slave_resp_i(peripheral_slave_resp),

      .ram_req_o (ram_req),
      .ram_resp_i(ram_resp),

      // Control Status Register Output
      .wrapper_csr_req_o(wrapper_csr_req),
      .wrapper_csr_rsp_i(wrapper_csr_resp)
  );

endmodule

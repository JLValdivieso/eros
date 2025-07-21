// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module cpu_system
  import eros_pkg::*;
//  import fpu_ss_pkg::*;
#(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter BOOT_ADDR = eros_pkg::DEBUG_BOOTROM_START_ADDRESS,
    parameter NHARTS = 3,
    parameter HARTID = 32'h01,
    parameter eros_pkg::cpu_type_e CPU = eros_pkg::CPU_type,
    parameter COPROCESSOR = 0,
    parameter DM_HALTADDRESS = eros_pkg::DEBUG_BOOTROM_START_ADDRESS + 32'h50
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,
    // Instruction memory interface
    output obi_req_t [NHARTS-1 : 0] core_instr_req_o,
    input obi_resp_t [NHARTS-1 : 0] core_instr_resp_i,

    // Data memory interface
    output obi_req_t  [NHARTS-1 : 0] core_data_req_o,
    input  obi_resp_t [NHARTS-1 : 0] core_data_resp_i,

    // Interrupt
    //Core 0
    input logic [31:0] intc_core0,
    //Core 1
    input logic [31:0] intc_core1,
    //Core 2
    input logic [31:0] intc_core2,

    output logic [NHARTS-1:0] sleep_o,

    // Debug Interface
    input  logic [NHARTS-1 : 0] debug_req_i,
    output logic [NHARTS-1 : 0] debug_mode_o
);

  logic fetch_enable;
  // CPU Control Signals


  assign fetch_enable = 1'b1;

  //Core 0
  assign core_instr_req_o[0].wdata = '0;
  assign core_instr_req_o[0].we    = '0;
  assign core_instr_req_o[0].be    = 4'b1111;

  // Core 1
  assign core_instr_req_o[1].wdata = '0;
  assign core_instr_req_o[1].we    = '0;
  assign core_instr_req_o[1].be    = 4'b1111;

  // Core 2
  assign core_instr_req_o[2].wdata = '0;
  assign core_instr_req_o[2].we    = '0;
  assign core_instr_req_o[2].be    = 4'b1111;
/*
  if (CPU == CV32E40P) begin : gen_eros_cv32e40p
    cv32e40p_top #(
        .COREV_PULP      (0),
        .COREV_CLUSTER   (0),
        .FPU             (0),
        .ZFINX           (0),
        .NUM_MHPMCOUNTERS(1)
    ) cv32e40p_core0_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b1),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (32'h0),
        .dm_halt_addr_i     (DM_HALTADDRESS),
        .hart_id_i          (HARTID),
        .dm_exception_addr_i(32'h0),

        .instr_addr_o  (core_instr_req_o[0].addr),
        .instr_req_o   (core_instr_req_o[0].req),
        .instr_rdata_i (core_instr_resp_i[0].rdata),
        .instr_gnt_i   (core_instr_resp_i[0].gnt),
        .instr_rvalid_i(core_instr_resp_i[0].rvalid),

        .data_addr_o  (core_data_req_o[0].addr),
        .data_wdata_o (core_data_req_o[0].wdata),
        .data_we_o    (core_data_req_o[0].we),
        .data_req_o   (core_data_req_o[0].req),
        .data_be_o    (core_data_req_o[0].be),
        .data_rdata_i (core_data_resp_i[0].rdata),
        .data_gnt_i   (core_data_resp_i[0].gnt),
        .data_rvalid_i(core_data_resp_i[0].rvalid),

        .irq_i    (intc_core0),
        .irq_ack_o(),
        .irq_id_o (),

        .debug_req_i      (debug_req_i[0]),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (debug_mode_o[0]),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[0])
    );

    cv32e40p_top #(
        .COREV_PULP      (0),
        .COREV_CLUSTER   (0),
        .FPU             (0),
        .ZFINX           (0),
        .NUM_MHPMCOUNTERS(1)
    ) cv32e40p_core1_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b1),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (32'h0),
        .dm_halt_addr_i     (DM_HALTADDRESS),
        .hart_id_i          (HARTID),
        .dm_exception_addr_i(32'h0),

        .instr_addr_o  (core_instr_req_o[1].addr),
        .instr_req_o   (core_instr_req_o[1].req),
        .instr_rdata_i (core_instr_resp_i[1].rdata),
        .instr_gnt_i   (core_instr_resp_i[1].gnt),
        .instr_rvalid_i(core_instr_resp_i[1].rvalid),

        .data_addr_o  (core_data_req_o[1].addr),
        .data_wdata_o (core_data_req_o[1].wdata),
        .data_we_o    (core_data_req_o[1].we),
        .data_req_o   (core_data_req_o[1].req),
        .data_be_o    (core_data_req_o[1].be),
        .data_rdata_i (core_data_resp_i[1].rdata),
        .data_gnt_i   (core_data_resp_i[1].gnt),
        .data_rvalid_i(core_data_resp_i[1].rvalid),

        .irq_i    (intc_core1),
        .irq_ack_o(),
        .irq_id_o (),

        .debug_req_i      (debug_req_i[1]),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (debug_mode_o[1]),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[1])
    );

    cv32e40p_top #(
        .COREV_PULP      (0),
        .COREV_CLUSTER   (0),
        .FPU             (0),
        .ZFINX           (0),
        .NUM_MHPMCOUNTERS(1)
    ) cv32e40p_core2_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b1),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (32'h0),
        .dm_halt_addr_i     (DM_HALTADDRESS),
        .hart_id_i          (HARTID),
        .dm_exception_addr_i(32'h0),

        .instr_addr_o  (core_instr_req_o[2].addr),
        .instr_req_o   (core_instr_req_o[2].req),
        .instr_rdata_i (core_instr_resp_i[2].rdata),
        .instr_gnt_i   (core_instr_resp_i[2].gnt),
        .instr_rvalid_i(core_instr_resp_i[2].rvalid),

        .data_addr_o  (core_data_req_o[2].addr),
        .data_wdata_o (core_data_req_o[2].wdata),
        .data_we_o    (core_data_req_o[2].we),
        .data_req_o   (core_data_req_o[2].req),
        .data_be_o    (core_data_req_o[2].be),
        .data_rdata_i (core_data_resp_i[2].rdata),
        .data_gnt_i   (core_data_resp_i[2].gnt),
        .data_rvalid_i(core_data_resp_i[2].rvalid),

        .irq_i    (intc_core2),
        .irq_ack_o(),
        .irq_id_o (),

        .debug_req_i      (debug_req_i[2]),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (debug_mode_o[2]),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[2])
    );
/*
  end else if (CPU == CV32E40PX) begin : gen_eros_cv32e40px

    //    import cv32e40px_core_v_xif_pkg::*;
    localparam ZFINX = 0;
    // instantiate the core 0
    cv32e40px_top #(
        .COREV_X_IF      (1),
        .COREV_PULP      (0),
        .COREV_CLUSTER   (0),
        .FPU             (0),
        .ZFINX           (0),
        .NUM_MHPMCOUNTERS(1)
    ) cv32e40px_core0_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b1),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (32'h0),
        .dm_halt_addr_i     (DM_HALTADDRESS),
        .hart_id_i          (HARTID),
        .dm_exception_addr_i(32'h0),

        .instr_addr_o  (core_instr_req_o[0].addr),
        .instr_req_o   (core_instr_req_o[0].req),
        .instr_rdata_i (core_instr_resp_i[0].rdata),
        .instr_gnt_i   (core_instr_resp_i[0].gnt),
        .instr_rvalid_i(core_instr_resp_i[0].rvalid),

        .data_addr_o  (core_data_req_o[0].addr),
        .data_wdata_o (core_data_req_o[0].wdata),
        .data_we_o    (core_data_req_o[0].we),
        .data_req_o   (core_data_req_o[0].req),
        .data_be_o    (core_data_req_o[0].be),
        .data_rdata_i (core_data_resp_i[0].rdata),
        .data_gnt_i   (core_data_resp_i[0].gnt),
        .data_rvalid_i(core_data_resp_i[0].rvalid),

        // CORE-V-XIF
        // Compressed interface
        .x_compressed_valid_o(ext_if_core0.compressed_valid),
        .x_compressed_ready_i(ext_if_core0.compressed_ready),
        .x_compressed_req_o  (ext_if_core0.compressed_req),
        .x_compressed_resp_i (ext_if_core0.compressed_resp),

        // Issue Interface
        .x_issue_valid_o(ext_if_core0.issue_valid),
        .x_issue_ready_i(ext_if_core0.issue_ready),
        .x_issue_req_o  (ext_if_core0.issue_req),
        .x_issue_resp_i (ext_if_core0.issue_resp),

        // Commit Interface
        .x_commit_valid_o(ext_if_core0.commit_valid),
        .x_commit_o(ext_if_core0.commit),

        // Memory Request/Response Interface
        .x_mem_valid_i(ext_if_core0.mem_valid),
        .x_mem_ready_o(ext_if_core0.mem_ready),
        .x_mem_req_i  (ext_if_core0.mem_req),
        .x_mem_resp_o (ext_if_core0.mem_resp),

        // Memory Result Interface
        .x_mem_result_valid_o(ext_if_core0.mem_result_valid),
        .x_mem_result_o(ext_if_core0.mem_result),

        // Result Interface
        .x_result_valid_i(ext_if_core0.result_valid),
        .x_result_ready_o(ext_if_core0.result_ready),
        .x_result_i(ext_if_core0.result),

        .irq_i    (intc_core0),
        .irq_ack_o(),
        .irq_id_o (),

        .debug_req_i      (debug_req_i[0]),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (debug_mode_o[0]),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[0])
    );

    // eXtension Interface
    if_xif #(
        .X_NUM_RS(fpu_ss_pkg::X_NUM_RS),
        .X_ID_WIDTH(fpu_ss_pkg::X_ID_WIDTH),
        .X_MEM_WIDTH(fpu_ss_pkg::X_MEM_WIDTH),
        .X_RFR_WIDTH(fpu_ss_pkg::X_RFR_WIDTH),
        .X_RFW_WIDTH(fpu_ss_pkg::X_RFW_WIDTH),
        .X_MISA(fpu_ss_pkg::X_MISA)
    ) ext_if_core0 ();

    if (COPROCESSOR == 1) begin
      /*** Put here coprocessor ***/ /*
      fpu_ss_wrapper #(
          .PULP_ZFINX(ZFINX),
          .INPUT_BUFFER_DEPTH(1),
          .OUT_OF_ORDER(0),
          .FORWARDING(1),
          .FPU_FEATURES(fpu_ss_pkg::FPU_FEATURES),
          .FPU_IMPLEMENTATION(fpu_ss_pkg::FPU_IMPLEMENTATION)
      ) fpu_ss_wrapper_core0_i (
          // Clock and reset
          .clk_i,
          .rst_ni,
          // eXtension Interface
          .xif_compressed_if(ext_if_core0),
          .xif_issue_if(ext_if_core0),
          .xif_commit_if(ext_if_core0),
          .xif_mem_if(ext_if_core0),
          .xif_mem_result_if(ext_if_core0),
          .xif_result_if(ext_if_core0)
      );
      /****************************/ /*
    end else begin

      // CORE-V-XIF
      // Compressed interface
      assign ext_if_core0.compressed_ready = '0;
      assign ext_if_core0.compressed_resp = '0;

      // Issue Interface
      assign ext_if_core0.issue_ready = '0;
      assign ext_if_core0.issue_resp = '0;

      // Commit Interface

      // Memory Request/Response Interface
      assign ext_if_core0.mem_valid = '0;
      assign ext_if_core0.mem_req = '0;

      // Memory Result Interface

      // Result Interface
      assign ext_if_core0.result_valid = '0;
      assign ext_if_core0.result = '0;

    end


    // instantiate the core 1
    cv32e40px_top #(
        .COREV_X_IF      (1),
        .COREV_PULP      (0),
        .COREV_CLUSTER   (0),
        .FPU             (0),
        .ZFINX           (0),
        .NUM_MHPMCOUNTERS(1)
    ) cv32e40px_core1_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b1),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (32'h0),
        .dm_halt_addr_i     (DM_HALTADDRESS),
        .hart_id_i          (HARTID),
        .dm_exception_addr_i(32'h0),

        .instr_addr_o  (core_instr_req_o[1].addr),
        .instr_req_o   (core_instr_req_o[1].req),
        .instr_rdata_i (core_instr_resp_i[1].rdata),
        .instr_gnt_i   (core_instr_resp_i[1].gnt),
        .instr_rvalid_i(core_instr_resp_i[1].rvalid),

        .data_addr_o  (core_data_req_o[1].addr),
        .data_wdata_o (core_data_req_o[1].wdata),
        .data_we_o    (core_data_req_o[1].we),
        .data_req_o   (core_data_req_o[1].req),
        .data_be_o    (core_data_req_o[1].be),
        .data_rdata_i (core_data_resp_i[1].rdata),
        .data_gnt_i   (core_data_resp_i[1].gnt),
        .data_rvalid_i(core_data_resp_i[1].rvalid),

        // CORE-V-XIF
        // Compressed interface
        .x_compressed_valid_o(ext_if_core1.compressed_valid),
        .x_compressed_ready_i(ext_if_core1.compressed_ready),
        .x_compressed_req_o  (ext_if_core1.compressed_req),
        .x_compressed_resp_i (ext_if_core1.compressed_resp),

        // Issue Interface
        .x_issue_valid_o(ext_if_core1.issue_valid),
        .x_issue_ready_i(ext_if_core1.issue_ready),
        .x_issue_req_o  (ext_if_core1.issue_req),
        .x_issue_resp_i (ext_if_core1.issue_resp),

        // Commit Interface
        .x_commit_valid_o(ext_if_core1.commit_valid),
        .x_commit_o(ext_if_core1.commit),

        // Memory Request/Response Interface
        .x_mem_valid_i(ext_if_core1.mem_valid),
        .x_mem_ready_o(ext_if_core1.mem_ready),
        .x_mem_req_i  (ext_if_core1.mem_req),
        .x_mem_resp_o (ext_if_core1.mem_resp),

        // Memory Result Interface
        .x_mem_result_valid_o(ext_if_core1.mem_result_valid),
        .x_mem_result_o(ext_if_core1.mem_result),

        // Result Interface
        .x_result_valid_i(ext_if_core1.result_valid),
        .x_result_ready_o(ext_if_core1.result_ready),
        .x_result_i(ext_if_core1.result),

        .irq_i    (intc_core1),
        .irq_ack_o(),
        .irq_id_o (),

        .debug_req_i      (debug_req_i[1]),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (debug_mode_o[1]),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[1])
    );

    // eXtension Interface
    if_xif #(
        .X_NUM_RS(fpu_ss_pkg::X_NUM_RS),
        .X_ID_WIDTH(fpu_ss_pkg::X_ID_WIDTH),
        .X_MEM_WIDTH(fpu_ss_pkg::X_MEM_WIDTH),
        .X_RFR_WIDTH(fpu_ss_pkg::X_RFR_WIDTH),
        .X_RFW_WIDTH(fpu_ss_pkg::X_RFW_WIDTH),
        .X_MISA(fpu_ss_pkg::X_MISA)
    ) ext_if_core1 ();

    if (COPROCESSOR == 1) begin
      /*** Put here coprocessor ***/ /*
      fpu_ss_wrapper #(
          .PULP_ZFINX(ZFINX),
          .INPUT_BUFFER_DEPTH(1),
          .OUT_OF_ORDER(0),
          .FORWARDING(1),
          .FPU_FEATURES(fpu_ss_pkg::FPU_FEATURES),
          .FPU_IMPLEMENTATION(fpu_ss_pkg::FPU_IMPLEMENTATION)
      ) fpu_ss_wrapper_core1_i (
          // Clock and reset
          .clk_i,
          .rst_ni,
          // eXtension Interface
          .xif_compressed_if(ext_if_core1),
          .xif_issue_if(ext_if_core1),
          .xif_commit_if(ext_if_core1),
          .xif_mem_if(ext_if_core1),
          .xif_mem_result_if(ext_if_core1),
          .xif_result_if(ext_if_core1)
      );
      /****************************/ /*
    end else begin

      // CORE-V-XIF
      // Compressed interface
      assign ext_if_core1.compressed_ready = '0;
      assign ext_if_core1.compressed_resp = '0;

      // Issue Interface
      assign ext_if_core1.issue_ready = '0;
      assign ext_if_core1.issue_resp = '0;

      // Commit Interface

      // Memory Request/Response Interface
      assign ext_if_core1.mem_valid = '0;
      assign ext_if_core1.mem_req = '0;

      // Memory Result Interface

      // Result Interface
      assign ext_if_core1.result_valid = '0;
      assign ext_if_core1.result = '0;

    end

    // instantiate the core 2
    cv32e40px_top #(
        .COREV_X_IF      (1),
        .COREV_PULP      (0),
        .COREV_CLUSTER   (0),
        .FPU             (0),
        .ZFINX           (0),
        .NUM_MHPMCOUNTERS(1)
    ) cv32e40px_core2_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b1),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (32'h0),
        .dm_halt_addr_i     (DM_HALTADDRESS),
        .hart_id_i          (HARTID),
        .dm_exception_addr_i(32'h0),

        .instr_addr_o  (core_instr_req_o[2].addr),
        .instr_req_o   (core_instr_req_o[2].req),
        .instr_rdata_i (core_instr_resp_i[2].rdata),
        .instr_gnt_i   (core_instr_resp_i[2].gnt),
        .instr_rvalid_i(core_instr_resp_i[2].rvalid),

        .data_addr_o  (core_data_req_o[2].addr),
        .data_wdata_o (core_data_req_o[2].wdata),
        .data_we_o    (core_data_req_o[2].we),
        .data_req_o   (core_data_req_o[2].req),
        .data_be_o    (core_data_req_o[2].be),
        .data_rdata_i (core_data_resp_i[2].rdata),
        .data_gnt_i   (core_data_resp_i[2].gnt),
        .data_rvalid_i(core_data_resp_i[2].rvalid),

        // CORE-V-XIF
        // Compressed interface
        .x_compressed_valid_o(ext_if_core2.compressed_valid),
        .x_compressed_ready_i(ext_if_core2.compressed_ready),
        .x_compressed_req_o  (ext_if_core2.compressed_req),
        .x_compressed_resp_i (ext_if_core2.compressed_resp),

        // Issue Interface
        .x_issue_valid_o(ext_if_core2.issue_valid),
        .x_issue_ready_i(ext_if_core2.issue_ready),
        .x_issue_req_o  (ext_if_core2.issue_req),
        .x_issue_resp_i (ext_if_core2.issue_resp),

        // Commit Interface
        .x_commit_valid_o(ext_if_core2.commit_valid),
        .x_commit_o(ext_if_core2.commit),

        // Memory Request/Response Interface
        .x_mem_valid_i(ext_if_core2.mem_valid),
        .x_mem_ready_o(ext_if_core2.mem_ready),
        .x_mem_req_i  (ext_if_core2.mem_req),
        .x_mem_resp_o (ext_if_core2.mem_resp),

        // Memory Result Interface
        .x_mem_result_valid_o(ext_if_core2.mem_result_valid),
        .x_mem_result_o(ext_if_core2.mem_result),

        // Result Interface
        .x_result_valid_i(ext_if_core2.result_valid),
        .x_result_ready_o(ext_if_core2.result_ready),
        .x_result_i(ext_if_core2.result),

        .irq_i    (intc_core2),
        .irq_ack_o(),
        .irq_id_o (),

        .debug_req_i      (debug_req_i[2]),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (debug_mode_o[2]),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[2])
    );

    // eXtension Interface
    if_xif #(
        .X_NUM_RS(fpu_ss_pkg::X_NUM_RS),
        .X_ID_WIDTH(fpu_ss_pkg::X_ID_WIDTH),
        .X_MEM_WIDTH(fpu_ss_pkg::X_MEM_WIDTH),
        .X_RFR_WIDTH(fpu_ss_pkg::X_RFR_WIDTH),
        .X_RFW_WIDTH(fpu_ss_pkg::X_RFW_WIDTH),
        .X_MISA(fpu_ss_pkg::X_MISA)
    ) ext_if_core2 ();

    if (COPROCESSOR == 1) begin
      /*** Put here coprocessor ***/ /*
      fpu_ss_wrapper #(
          .PULP_ZFINX(ZFINX),
          .INPUT_BUFFER_DEPTH(1),
          .OUT_OF_ORDER(0),
          .FORWARDING(1),
          .FPU_FEATURES(fpu_ss_pkg::FPU_FEATURES),
          .FPU_IMPLEMENTATION(fpu_ss_pkg::FPU_IMPLEMENTATION)
      ) fpu_ss_wrapper_core2_i (
          // Clock and reset
          .clk_i,
          .rst_ni,
          // eXtension Interface
          .xif_compressed_if(ext_if_core2),
          .xif_issue_if(ext_if_core2),
          .xif_commit_if(ext_if_core2),
          .xif_mem_if(ext_if_core2),
          .xif_mem_result_if(ext_if_core2),
          .xif_result_if(ext_if_core2)
      );
      /****************************/ /*
    end else begin

      // CORE-V-XIF
      // Compressed interface
      assign ext_if_core2.compressed_ready = '0;
      assign ext_if_core2.compressed_resp = '0;

      // Issue Interface
      assign ext_if_core2.issue_ready = '0;
      assign ext_if_core2.issue_resp = '0;

      // Commit Interface

      // Memory Request/Response Interface
      assign ext_if_core2.mem_valid = '0;
      assign ext_if_core2.mem_req = '0;

      // Memory Result Interface

      // Result Interface
      assign ext_if_core2.result_valid = '0;
      assign ext_if_core2.result = '0;

    end
*/
/*
  end else begin : gen_eros_cv32e20
*/
    // instantiate the core 0
    cve2_top #() cv32e20_core0 (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .test_en_i(1'b0),
        .ram_cfg_i('0),

        .hart_id_i  (HARTID),
        .boot_addr_i(BOOT_ADDR),

        .instr_addr_o  (core_instr_req_o[0].addr),
        .instr_req_o   (core_instr_req_o[0].req),
        .instr_rdata_i (core_instr_resp_i[0].rdata),
        .instr_gnt_i   (core_instr_resp_i[0].gnt),
        .instr_rvalid_i(core_instr_resp_i[0].rvalid),
        .instr_err_i   (1'b0),

        .data_addr_o  (core_data_req_o[0].addr),
        .data_wdata_o (core_data_req_o[0].wdata),
        .data_we_o    (core_data_req_o[0].we),
        .data_req_o   (core_data_req_o[0].req),
        .data_be_o    (core_data_req_o[0].be),
        .data_rdata_i (core_data_resp_i[0].rdata),
        .data_gnt_i   (core_data_resp_i[0].gnt),
        .data_rvalid_i(core_data_resp_i[0].rvalid),
        .data_err_i   (1'b0),

        .irq_software_i('0),
        .irq_timer_i   ('0),
        .irq_external_i('0),
        .irq_fast_i    (intc_core0[31:16]),
        .irq_nm_i      (1'b0),

        .debug_req_i(debug_req_i[0]),
        .crash_dump_o(),
        .debug_halted_o(debug_mode_o[0]),
        .dm_halt_addr_i(DM_HALTADDRESS),
        .dm_exception_addr_i('0),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[0])
    );


    // instantiate the core 1
    cve2_top #() cv32e20_core1 (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .test_en_i(1'b0),
        .ram_cfg_i('0),

        .hart_id_i  (HARTID),
        .boot_addr_i(BOOT_ADDR),

        .instr_addr_o  (core_instr_req_o[1].addr),
        .instr_req_o   (core_instr_req_o[1].req),
        .instr_rdata_i (core_instr_resp_i[1].rdata),
        .instr_gnt_i   (core_instr_resp_i[1].gnt),
        .instr_rvalid_i(core_instr_resp_i[1].rvalid),
        .instr_err_i   (1'b0),

        .data_addr_o  (core_data_req_o[1].addr),
        .data_wdata_o (core_data_req_o[1].wdata),
        .data_we_o    (core_data_req_o[1].we),
        .data_req_o   (core_data_req_o[1].req),
        .data_be_o    (core_data_req_o[1].be),
        .data_rdata_i (core_data_resp_i[1].rdata),
        .data_gnt_i   (core_data_resp_i[1].gnt),
        .data_rvalid_i(core_data_resp_i[1].rvalid),
        .data_err_i   (1'b0),

        .irq_software_i('0),
        .irq_timer_i   ('0),
        .irq_external_i('0),
        .irq_fast_i    (intc_core1[31:16]),
        .irq_nm_i      (1'b0),

        .debug_req_i(debug_req_i[1]),
        .crash_dump_o(),
        .debug_halted_o(debug_mode_o[1]),
        .dm_halt_addr_i(DM_HALTADDRESS),
        .dm_exception_addr_i('0),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[1])
    );

    // instantiate the core 2
    cve2_top #() cv32e20_core2 (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .test_en_i(1'b0),
        .ram_cfg_i('0),

        .hart_id_i  (HARTID),
        .boot_addr_i(BOOT_ADDR),

        .instr_addr_o  (core_instr_req_o[2].addr),
        .instr_req_o   (core_instr_req_o[2].req),
        .instr_rdata_i (core_instr_resp_i[2].rdata),
        .instr_gnt_i   (core_instr_resp_i[2].gnt),
        .instr_rvalid_i(core_instr_resp_i[2].rvalid),
        .instr_err_i   (1'b0),

        .data_addr_o  (core_data_req_o[2].addr),
        .data_wdata_o (core_data_req_o[2].wdata),
        .data_we_o    (core_data_req_o[2].we),
        .data_req_o   (core_data_req_o[2].req),
        .data_be_o    (core_data_req_o[2].be),
        .data_rdata_i (core_data_resp_i[2].rdata),
        .data_gnt_i   (core_data_resp_i[2].gnt),
        .data_rvalid_i(core_data_resp_i[2].rvalid),
        .data_err_i   (1'b0),

        .irq_software_i('0),
        .irq_timer_i   ('0),
        .irq_external_i('0),
        .irq_fast_i    (intc_core2[31:16]),
        .irq_nm_i      (1'b0),

        .debug_req_i(debug_req_i[2]),
        .crash_dump_o(),
        .debug_halted_o(debug_mode_o[2]),
        .dm_halt_addr_i(DM_HALTADDRESS),
        .dm_exception_addr_i('0),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o  (sleep_o[2])
    );
//  end
endmodule

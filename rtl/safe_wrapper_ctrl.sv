// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

`include "common_cells/assertions.svh"

module safe_wrapper_ctrl #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
    parameter NHARTS = 3
    //    parameter eros_pkg::interrupt_type_e INTC_TYPE = eros_pkg::Intc_Iype
) (
    input logic clk_i,
    input logic rst_ni,

    // Bus Interface
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // Safe wrapper Signal -> Internal FSM
    output logic [2:0] master_core_o,
    output logic [2:0] safe_mode_o,
    output logic [1:0] safe_configuration_o,
    output logic critical_section_o,
    output logic Initial_Sync_Master_o,
    output logic Start_o,
    output logic End_sw_routine_o,

    input logic Start_Boot_i,
    input logic en_ext_debug_i,
    input logic DMR_Rec_i,
    input logic [NHARTS-1 : 0] debug_mode_i,
    input logic [NHARTS-1 : 0] sleep_i,

    output logic interrupt_o
);

  import safe_wrapper_ctrl_reg_pkg::*;


  safe_wrapper_ctrl_reg2hw_t reg2hw;
  safe_wrapper_ctrl_hw2reg_t hw2reg;


  safe_wrapper_ctrl_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) safe_wrapper_ctrl_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg_req_i,
      .reg_rsp_o,
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );

  logic Start_Flag, Startff;
  logic en_sw_routineff;
  logic enable_endSW;

  assign master_core_o = reg2hw.master_core.q;
  assign safe_mode_o = reg2hw.dmr_mask.q;
  assign safe_configuration_o = reg2hw.safe_configuration.q;
  assign critical_section_o = reg2hw.critical_section.q;
  assign End_sw_routine_o = reg2hw.end_sw_routine.q;

  //Start
  assign hw2reg.start.d = 1'b0;
  assign hw2reg.start.de = enable_endSW;
  assign Start_o = reg2hw.start.q;
  //End_SW
  assign hw2reg.end_sw_routine.d = 1'b0;
  assign hw2reg.end_sw_routine.de = Start_Flag;

  //Initial_Sync
  assign Initial_Sync_Master_o = reg2hw.initial_sync_master.q;

  //Debug_Req
  assign hw2reg.external_debug_req.d = {Start_Boot_i, en_ext_debug_i};
  assign hw2reg.external_debug_req.de = 1'b1;

  //Status Reg
  assign hw2reg.cb_heep_status.cores_sleep.d = sleep_i;
  assign hw2reg.cb_heep_status.cores_sleep.de = 1'b1;

  assign hw2reg.cb_heep_status.cores_debug_mode.d = debug_mode_i;
  assign hw2reg.cb_heep_status.cores_debug_mode.de = 1'b1;

  //DMR_Recov
  assign hw2reg.dmr_rec.d = DMR_Rec_i;
  assign hw2reg.dmr_rec.de = 1'b1;

  //Generate Flip-Flop Bi-Stable
  // When pos edge End_Program switch off start. When start switch off positive En_Program
  logic enable, clear;

  //synopsys sync_set_reset "enable"
  assign enable = !Startff && reg2hw.start.q;
  //synopsys sync_set_reset "clear"
  assign clear  = !enable;
  //synopsys sync_set_reset "enable"
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      Startff <= 1'b0;
      Start_Flag <= 1'b0;
    end else begin
      Startff <= reg2hw.start.q;
      if (clear) Start_Flag <= 1'b0;
      else if (enable) Start_Flag <= 1'b1;
    end
  end

  // When pos edge End_Program switch off start. When start switch off positive En_Program
  //, clear_endSW;

  assign enable_endSW = !en_sw_routineff & reg2hw.end_sw_routine.q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      en_sw_routineff <= 1'b0;
    end else begin
      en_sw_routineff <= reg2hw.end_sw_routine.q;
    end
  end


  logic enable_interrupt;

  //Interrupt
  assign hw2reg.interrupt_controler.status_interrupt.d = '1;
  assign hw2reg.interrupt_controler.status_interrupt.de = enable_endSW;
  assign enable_interrupt = reg2hw.interrupt_controler.enable_interrupt.q;


  logic status_interrupt;
  logic load_intc, clear_intc;
  logic flag_intc;

  assign status_interrupt = reg2hw.interrupt_controler.status_interrupt.q;
  //synopsys sync_set_reset "load_intc"
  assign load_intc = enable_interrupt & status_interrupt & sleep_i[0] & sleep_i[1] & sleep_i[2] & en_sw_routineff & ~flag_intc ;
  //synopsys sync_set_reset "clear_intc"
  assign clear_intc = ~status_interrupt;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      interrupt_o <= 1'b0;
      flag_intc   <= 1'b0;
    end else begin
      interrupt_o <= 1'b0;
      if (clear_intc) begin
        interrupt_o <= 1'b0;
        flag_intc   <= 1'b0;
      end else if (load_intc) begin
        interrupt_o <= 1'b1;
        flag_intc   <= 1'b1;
      end
    end
  end
endmodule : safe_wrapper_ctrl

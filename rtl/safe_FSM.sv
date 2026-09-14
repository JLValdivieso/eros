// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)
/*
 *
 *
 *
 */

module safe_FSM #(
    parameter NHARTS = 3
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    input logic [2:0] DMR_Mask_i,
    input logic tmr_critical_section_i,
    input logic [1:0] Safe_configuration_i,
    input logic Initial_Sync_Master_i,
    input logic [NHARTS-1:0] Halt_ack_i,
    input logic [NHARTS-1:0] Hart_wfi_i,
    input logic [NHARTS-1:0] Hart_intc_ack_i,
    input logic [NHARTS-1:0] Master_Core_i,
    input logic Preemptive_Trigger_i,
    output logic Preemptive_Ready_o,
    input logic Preemptive_Continue_i,
    output logic [NHARTS-1:0] Interrupt_Preemptive_o,
    output logic [NHARTS-1:0] Interrupt_Sync_o,
    output logic [NHARTS-1:0] Interrupt_swResync_o,
    output logic [NHARTS-1:0] Interrupt_Host_Sync_o,
    output logic [NHARTS-1:0] Interrupt_Host_Desync_o,
    output logic [NHARTS-1:0] Interrupt_Halt_o,
    output logic Single_Bus_o,
    output logic [NHARTS-1:0] Dmr_config_o,
    output logic Delayed_o,
    output logic Tmr_voter_enable_o,
    output logic Dmr_comparator_enable_o,
    output logic [NHARTS-1:0] wfi_dmr_o,
    input logic [NHARTS-1:0] voter_id_error,
    input logic tmr_error_i,
    input logic [NHARTS-1:0] dmr_error_i,
    input logic Start_i,
    output logic Start_Boot_o,
    input logic End_sw_routine_i,
    output logic DMR_Rec_o,
    output logic en_ext_debug_req_o
);
  // FSM state encoding
  typedef enum logic [3:0] {
    RESET,
    BOOT,
    IDLE,
    SINGLE_MODE,
    TMR_MODE,
    DMR_MODE
  } ctrl_safe_fsm_e;

  typedef enum logic [3:0] {
    SINGLE_RESET,
    SINGLE_IDLE,
    SINGLE_START,
    SINGLE_BOOT,
    SINGLE_CONTEXT_BOOT,
    SINGLE_RUN,
    SINGLE_TO_TMR,
    SINGLE_TO_DMR,
    SINGLE_SYNC_OFF,
    SINGLE_SWITCH_INTC,
    SINGLE_SAVE_CONTEXT,
    SINGLE_SWITCH_WFI
  } ctrl_single_fsm_e;

  typedef enum logic [4:0] {
    TMR_RESET,
    TMR_IDLE,
    TMR_START,
    TMR_BOOT,
    TMR_CONTEXT_BOOT,
    TMR_SH_HALT,
    TMR_WAIT_SH,
    TMR_MS_INTRSYNC,
    TMR_SYNC,
    TMR_END_SYNC,
    TMR_END,
    TMR_TO_SINGLE,
    TMR_SYNCINTC,
    TMR_SWSYNC,
    TMR_SWITCH_INTC,
    TMR_SAVE_CONTEXT,
    TMR_SWITCH_WFI
  } ctrl_tmr_fsm_e;

  typedef enum logic [4:0] {
    DMR_RESET,
    DMR_IDLE,
    DMR_START,
    DMR_BOOT,
    DMR_CONTEXT_BOOT,
    DMR_SH_HALT,
    DMR_WAIT_SH,
    DMR_MS_INTRSYNC,
    DMR_SYNC,
    DMR_END_SYNC,
    DMR_END,
    DMR_TO_SINGLE,
    DMR_STOP,
    DMR_INTC_RECOVERY,
    DMR_RECOVERY,
    DMR_SWITCH_INTC,
    DMR_SAVE_CONTEXT,
    DMR_SWITCH_WFI
  } ctrl_dmr_fsm_e;

  ctrl_safe_fsm_e ctrl_safe_fsm_cs, ctrl_safe_fsm_ns;
  ctrl_single_fsm_e ctrl_single_fsm_cs, ctrl_single_fsm_ns;

  ctrl_tmr_fsm_e [NHARTS-1:0] ctrl_tmr_fsm_cs;
  ctrl_tmr_fsm_e [NHARTS-1:0] ctrl_tmr_fsm_ns;

  ctrl_dmr_fsm_e [NHARTS-1:0] ctrl_dmr_fsm_cs;
  ctrl_dmr_fsm_e [NHARTS-1:0] ctrl_dmr_fsm_ns;

  logic [NHARTS-1:0] Switch_SingletoTMR_s;
  logic [NHARTS-1:0] Switch_TMRtoSingle_s;
  logic [NHARTS-1:0] Switch_hostTMRtoSingle_s;
  logic Enable_Switch_s;


  logic halt_req_s;
  logic Single_Boot_s;
  logic Single_Preemptive_Ready_s;
  logic [NHARTS-1:0] Single_Preemptive_intc_s;
  logic General_boot_s;
  logic [NHARTS-1:0] TMR_Boot_s;
  logic [NHARTS-1:0] TMR_Preemptive_Ready_s;
  logic [NHARTS-1:0] TMR_Preemptive_intc_s;
  logic en_safe_ext_debug_req_s, en_single_ext_debug_req_s;
  logic [NHARTS-1:0] dbg_halt_req_s;
  logic [NHARTS-1:0] dbg_halt_req_general_s;
  logic [NHARTS-1:0] Single_Halt_request_s;
  logic [NHARTS-1:0] single_bus_s;
  logic [NHARTS-1:0] tmr_voter_enable_s;
  logic [NHARTS-1:0] Interrupt_Sync_TMR_s;
  logic [NHARTS-1:0] Interrupt_sw_TMR_Resync_s;
  logic [NHARTS-1:0] Interrupt_swResync_s;

  //DMR SIGNALS
  logic [NHARTS-1:0] DMR_Boot_s;
  logic [NHARTS-1:0] DMR_Preemptive_Ready_s;
  logic [NHARTS-1:0] DMR_Preemptive_intc_s;
  logic [NHARTS-1:0] DMR_Single_s;
  logic [NHARTS-1:0] DMR_dbg_halt_req_s;
  logic [NHARTS-1:0] DMR_dbg_halt_req_general_s;
  logic [NHARTS-1:0] Switch_SingletoDMR_s;
  logic [NHARTS-1:0] Switch_DMRtoSingle_s;
  logic [NHARTS-1:0] Switch_hostDMRtoSingle_s;
  logic [NHARTS-1:0] dual_mode_dmr_s;
  logic [NHARTS-1:0] dmr_dmr_config_s;
  logic [NHARTS-1:0] Interrupt_Sync_DMR_s;
  logic [NHARTS-1:0] dbg_halt_dmr_recovery;
  logic dmr_error_s;
  logic [NHARTS-1:0] dmr_delayed_s;
  logic [NHARTS-1:0] DMR_Rec_s;

  logic [1:0] tmr_error_ff;
  logic tmr_error_s;



  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ctrl_safe_fsm_cs <= RESET;
    end else begin
      ctrl_safe_fsm_cs <= ctrl_safe_fsm_ns;
    end
  end

  ////////////////////////////////////////////////////////////////////////////////
  //    _____ ______ _   _ ______ _____            _       ______ _____ __  __  //
  //   / ____|  ____| \ | |  ____|  __ \     /\   | |     |  ____/ ____|  \/  | //
  //  | |  __| |__  |  \| | |__  | |__) |   /  \  | |     | |__ | (___ | \  / | //
  //  | | |_ |  __| | . ` |  __| |  _  /   / /\ \ | |     |  __| \___ \| |\/| | //
  //  | |__| | |____| |\  | |____| | \ \  / ____ \| |____ | |    ____) | |  | | //
  //   \_____|______|_| \_|______|_|  \_\/_/    \_\______||_|   |_____/|_|  |_| //
  //                                                                            //
  ////////////////////////////////////////////////////////////////////////////////
  always_comb begin

    ctrl_safe_fsm_ns = ctrl_safe_fsm_cs;

    unique case (ctrl_safe_fsm_cs)

      RESET:  //todo: momentaneous solution for power-on sequence
      begin
        ctrl_safe_fsm_ns = BOOT;
      end

      BOOT: begin
        if (Hart_wfi_i == 3'b111) ctrl_safe_fsm_ns = IDLE;
        else ctrl_safe_fsm_ns = BOOT;
      end
      IDLE: begin
        if (Safe_configuration_i == 2'b01 && Start_i == 1'b1 && Preemptive_Ready_o == 1'b0 && Preemptive_Trigger_i == 1'b0) ctrl_safe_fsm_ns = TMR_MODE;
        else if ((Safe_configuration_i == 2'b10 | Safe_configuration_i == 2'b11) && Start_i == 1'b1 && Preemptive_Ready_o == 1'b0 && Preemptive_Trigger_i == 1'b0)
          ctrl_safe_fsm_ns = DMR_MODE;
        else if (Safe_configuration_i == 2'b00 && Start_i == 1'b1 && Preemptive_Ready_o == 1'b0 && Preemptive_Trigger_i == 1'b0) ctrl_safe_fsm_ns = SINGLE_MODE;
        else ctrl_safe_fsm_ns = IDLE;
      end
      SINGLE_MODE: begin
        if ((Start_i == 1'b0 && ctrl_single_fsm_cs == SINGLE_IDLE) || (Preemptive_Ready_o == 1'b1 && Preemptive_Trigger_i == 1'b1)) ctrl_safe_fsm_ns = IDLE;
        else if (Start_i == 1'b1 && Safe_configuration_i == 2'b01) ctrl_safe_fsm_ns = TMR_MODE;
        else if (Start_i == 1'b1 && (Safe_configuration_i == 2'b10 | Safe_configuration_i == 2'b11))
          ctrl_safe_fsm_ns = DMR_MODE;
        else ctrl_safe_fsm_ns = SINGLE_MODE;
      end
      TMR_MODE: begin
        if((ctrl_tmr_fsm_cs[0] == TMR_IDLE
                && ctrl_tmr_fsm_cs[1] == TMR_IDLE && ctrl_tmr_fsm_cs[2] == TMR_IDLE && Start_i == 1'b0) ||
                (Preemptive_Ready_o == 1'b1 && Preemptive_Trigger_i == 1'b1))
          ctrl_safe_fsm_ns = IDLE;
        else if (Switch_TMRtoSingle_s[0] == 1'b1 || Switch_TMRtoSingle_s[1] == 1'b1 || Switch_TMRtoSingle_s[2] == 1'b1)
          ctrl_safe_fsm_ns = SINGLE_MODE;
        else ctrl_safe_fsm_ns = TMR_MODE;
      end
      DMR_MODE: begin
        if((ctrl_dmr_fsm_cs[0] == DMR_IDLE
                && ctrl_dmr_fsm_cs[1] == DMR_IDLE && ctrl_dmr_fsm_cs[2] == DMR_IDLE && Start_i == 1'b0) ||
                (Preemptive_Ready_o == 1'b1 && Preemptive_Trigger_i == 1'b1))
          ctrl_safe_fsm_ns = IDLE;
        //Todo
        else if (Switch_DMRtoSingle_s[0] == 1'b1 || Switch_DMRtoSingle_s[1] == 1'b1 || Switch_DMRtoSingle_s[2] == 1'b1)
          ctrl_safe_fsm_ns = SINGLE_MODE;
        else ctrl_safe_fsm_ns = DMR_MODE;
      end

      default: begin
        ctrl_safe_fsm_ns = IDLE;
      end
    endcase
  end

  always_comb begin

    en_safe_ext_debug_req_s = 1'b0;
    General_boot_s = 1'b0;
    unique case (ctrl_safe_fsm_cs)
      IDLE: begin
        en_safe_ext_debug_req_s = 1'b1;
      end
      BOOT: begin
        General_boot_s = 1'b1;
      end
      default: begin
        en_safe_ext_debug_req_s = 1'b0;
      end
    endcase
  end

  ////////////////////////////////////////////////////////////////////////
  //    _____ _____ _   _  _____ _      ______   ______ _____ __  __    //
  //   / ____|_   _| \ | |/ ____| |    |  ____| |  ____/ ____|  \/  |   //
  //  | (___   | | |  \| | |  __| |    | |__    | |__ | (___ | \  / |   //
  //   \___ \  | | | . ` | | |_ | |    |  __|   |  __| \___ \| |\/| |   //
  //   ____) |_| |_| |\  | |__| | |____| |____  | |    ____) | |  | |   //
  //  |_____/|_____|_| \_|\_____|______|______| |_|   |_____/|_|  |_|   //
  //                                                                    //
  ////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ctrl_single_fsm_cs <= SINGLE_RESET;
    end else begin
      ctrl_single_fsm_cs <= ctrl_single_fsm_ns;
    end
  end

  always_comb begin

    ctrl_single_fsm_ns = ctrl_single_fsm_cs;

    unique case (ctrl_single_fsm_cs)

      SINGLE_RESET: begin
        ctrl_single_fsm_ns = SINGLE_IDLE;
      end
      SINGLE_IDLE: begin
        if(ctrl_safe_fsm_cs == SINGLE_MODE && Start_i == 1'b1 && End_sw_routine_i == 1'b0
              && (Switch_TMRtoSingle_s[0] == 1'b0 && Switch_TMRtoSingle_s[1] == 1'b0 && Switch_TMRtoSingle_s[2] == 1'b0)
              && (Switch_DMRtoSingle_s[0] == 1'b0 && Switch_DMRtoSingle_s[1] == 1'b0 && Switch_DMRtoSingle_s[2] == 1'b0))
          ctrl_single_fsm_ns = SINGLE_START;
        else if (ctrl_safe_fsm_cs == SINGLE_MODE && Start_i == 1'b1 && End_sw_routine_i == 1'b0 && (Switch_TMRtoSingle_s[0] == 1'b1
              || Switch_TMRtoSingle_s[1] == 1'b1 || Switch_TMRtoSingle_s[2] == 1'b1))
          ctrl_single_fsm_ns = SINGLE_RUN;
        else if (ctrl_safe_fsm_cs == SINGLE_MODE && Start_i == 1'b1 && End_sw_routine_i == 1'b0 && (Switch_DMRtoSingle_s[0] == 1'b1
              || Switch_DMRtoSingle_s[1] == 1'b1 || Switch_DMRtoSingle_s[2] == 1'b1))
          ctrl_single_fsm_ns = SINGLE_RUN;
        else ctrl_single_fsm_ns = SINGLE_IDLE;
      end
      SINGLE_START: begin
        if (Halt_ack_i == Master_Core_i && ~Preemptive_Continue_i) ctrl_single_fsm_ns = SINGLE_BOOT;
        else if (Halt_ack_i == Master_Core_i && Preemptive_Continue_i) ctrl_single_fsm_ns = SINGLE_CONTEXT_BOOT;
        else ctrl_single_fsm_ns = SINGLE_START;
      end

      SINGLE_BOOT: begin
        if (Halt_ack_i == 3'b000) ctrl_single_fsm_ns = SINGLE_RUN;
        else ctrl_single_fsm_ns = SINGLE_BOOT;
      end

      SINGLE_CONTEXT_BOOT: begin
        if (Halt_ack_i == 3'b000)  ctrl_single_fsm_ns = SINGLE_RUN;
        else ctrl_single_fsm_ns = SINGLE_CONTEXT_BOOT;
      end

      SINGLE_RUN: begin
        if (End_sw_routine_i == 1'b1 && Hart_wfi_i == 3'b111)  //SW STOP
          ctrl_single_fsm_ns = SINGLE_IDLE;
        else if (Preemptive_Trigger_i == 1'b1)
            ctrl_single_fsm_ns = SINGLE_SWITCH_INTC;
        else if (Start_i == 1'b0 && Halt_ack_i == 3'b000 && End_sw_routine_i == 1'b0) //External STOP
          ctrl_single_fsm_ns = SINGLE_SYNC_OFF;
        else if (Halt_ack_i == 3'b000 && Safe_configuration_i == 2'b01)  //Switch to others mode TMR
          ctrl_single_fsm_ns = SINGLE_TO_TMR;
        else if(Halt_ack_i == 3'b000 && (Safe_configuration_i==2'b10 | Safe_configuration_i==2'b11)) //Switch to others mode DMR
          ctrl_single_fsm_ns = SINGLE_TO_DMR;
        else ctrl_single_fsm_ns = SINGLE_RUN;
      end
      SINGLE_TO_TMR: begin
        if (Switch_SingletoTMR_s[0] && Switch_SingletoTMR_s[1] && Switch_SingletoTMR_s[2])
          ctrl_single_fsm_ns = SINGLE_IDLE;
        else ctrl_single_fsm_ns = SINGLE_TO_TMR;
      end
      SINGLE_TO_DMR: begin
        if ((Switch_SingletoDMR_s[0]==1'b1 && Switch_SingletoDMR_s[1]==1'b1 && Switch_SingletoDMR_s[2]==1'b0) ||
                (Switch_SingletoDMR_s[0]==1'b1 && Switch_SingletoDMR_s[1]==1'b0 && Switch_SingletoDMR_s[2]==1'b1) ||
                (Switch_SingletoDMR_s[0]==1'b0 && Switch_SingletoDMR_s[1]==1'b1 && Switch_SingletoDMR_s[2]==1'b1))
          ctrl_single_fsm_ns = SINGLE_IDLE;
        else ctrl_single_fsm_ns = SINGLE_TO_DMR;
      end
      SINGLE_SYNC_OFF: begin
        if (Hart_wfi_i == 3'b000) ctrl_single_fsm_ns = SINGLE_IDLE;
        else ctrl_single_fsm_ns = SINGLE_SYNC_OFF;
      end

        //****Preemptive*****//
      SINGLE_SWITCH_INTC: begin
        if (Hart_intc_ack_i == Master_Core_i) ctrl_single_fsm_ns = SINGLE_SAVE_CONTEXT;
        else ctrl_single_fsm_ns = SINGLE_SWITCH_INTC;
      end
      SINGLE_SAVE_CONTEXT: begin
        if (Hart_wfi_i == 3'b111) ctrl_single_fsm_ns = SINGLE_SWITCH_WFI;
        else ctrl_single_fsm_ns = SINGLE_SAVE_CONTEXT;
      end
      SINGLE_SWITCH_WFI: begin
        if (~Preemptive_Trigger_i) ctrl_single_fsm_ns = SINGLE_IDLE;
        else ctrl_single_fsm_ns = SINGLE_SWITCH_WFI;
      end
        //******************//
      default: begin
        ctrl_single_fsm_ns = SINGLE_IDLE;
      end
    endcase
  end


  //Outputs Todo: Outputs for outside stops operation
  always_comb begin
    Single_Halt_request_s = 3'b000;
    en_single_ext_debug_req_s = 1'b0;
    Enable_Switch_s = 1'b0;
    Single_Boot_s = 1'b0;
    Single_Preemptive_intc_s = 3'b000;
    Single_Preemptive_Ready_s = 1'b0;
    unique case (ctrl_single_fsm_cs)
      SINGLE_START: begin
        Single_Halt_request_s = Master_Core_i;
        Single_Boot_s = 1'b1;
      end
      SINGLE_BOOT: begin
        Single_Boot_s = 1'b1;
      end
      SINGLE_CONTEXT_BOOT: begin
        Single_Boot_s = 1'b0;
      end
      SINGLE_RUN: begin
        en_single_ext_debug_req_s = 1'b0;
      end
      SINGLE_TO_TMR: begin
        Enable_Switch_s = 1'b1;
      end
      SINGLE_TO_DMR: begin
        Enable_Switch_s = 1'b1;
      end

      SINGLE_SWITCH_INTC: begin
        Single_Preemptive_intc_s = Master_Core_i;
      end
      SINGLE_SAVE_CONTEXT: begin
        Single_Preemptive_intc_s = 3'b000;
      end
      SINGLE_SWITCH_WFI: begin
        Single_Preemptive_Ready_s = 1'b1;
        Single_Preemptive_intc_s = 3'b000;
      end

      default: begin
        Single_Halt_request_s = 3'b000;
        en_single_ext_debug_req_s = 1'b0;
        Enable_Switch_s = 1'b0;
      end
    endcase
  end


  //////////////////////////////////////////////////////
  //   _______ __  __ _____     ______ _____ __  __   //
  //  |__   __|  \/  |  __ \   |  ____/ ____|  \/  |  //
  //     | |  | \  / | |__) |  | |__ | (___ | \  / |  //
  //     | |  | |\/| |  _  /   |  __| \___ \| |\/| |  //
  //     | |  | |  | | | \ \   | |    ____) | |  | |  //
  //     |_|  |_|  |_|_|  \_\  |_|   |_____/|_|  |_|  //
  //                                                  //
  //////////////////////////////////////////////////////
  // Mealy FSM depending on Master Core selection for different outputs behavior

  for (genvar i = 0; i < NHARTS; i++) begin : TMR_FSM_NormalBehaviour

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        ctrl_tmr_fsm_cs[i] <= TMR_RESET;
      end else begin
        ctrl_tmr_fsm_cs[i] <= ctrl_tmr_fsm_ns[i];
      end
    end

    always_comb begin

      ctrl_tmr_fsm_ns[i] = ctrl_tmr_fsm_cs[i];

      unique case (ctrl_tmr_fsm_cs[i])

        TMR_RESET: begin
          ctrl_tmr_fsm_ns[i] = TMR_IDLE;
        end

        TMR_IDLE: begin
          if (ctrl_safe_fsm_cs == TMR_MODE && Start_i == 1'b1 && Enable_Switch_s == 1'b0)
            ctrl_tmr_fsm_ns[i] = TMR_START;
          else if (ctrl_safe_fsm_cs == TMR_MODE && Start_i == 1'b1 && Enable_Switch_s == 1'b1) begin
            if (Master_Core_i[i] == 1'b1 && Hart_wfi_i[i] == 1'b1 && Initial_Sync_Master_i == 1'b1 && Start_i == 1'b1)
              ctrl_tmr_fsm_ns[i] = TMR_SH_HALT;
            else if (Master_Core_i[i] == 1'b0 && (halt_req_s) == 1'b1 && Start_i == 1'b1)
              ctrl_tmr_fsm_ns[i] = TMR_SH_HALT;
            else ctrl_tmr_fsm_ns[i] = TMR_IDLE;
          end else begin
            ctrl_tmr_fsm_ns[i] = TMR_IDLE;
          end
        end

        TMR_START: begin
          if (Halt_ack_i[i] == 1'b1 && ~Preemptive_Continue_i) ctrl_tmr_fsm_ns[i] = TMR_BOOT;
          else if (Halt_ack_i[i] == 1'b1 && Preemptive_Continue_i) ctrl_tmr_fsm_ns[i] = TMR_CONTEXT_BOOT;
          else ctrl_tmr_fsm_ns[i] = TMR_START;
        end

        TMR_BOOT: begin
          if (Halt_ack_i[i] == 1'b0) ctrl_tmr_fsm_ns[i] = TMR_SYNC;
          else ctrl_tmr_fsm_ns[i] = TMR_BOOT;
        end

        TMR_CONTEXT_BOOT: begin
          if (Halt_ack_i[i] == 1'b0) ctrl_tmr_fsm_ns[i] = TMR_SYNC;
          else ctrl_tmr_fsm_ns[i] = TMR_CONTEXT_BOOT;
        end

        TMR_SH_HALT: begin
          if (Master_Core_i[i] == 1'b1 && ((Halt_ack_i[0] && Halt_ack_i[1]) || (Halt_ack_i[1] && Halt_ack_i[2])
                || (Halt_ack_i[0] && Halt_ack_i[2])) == 1'b1)
            ctrl_tmr_fsm_ns[i] = TMR_WAIT_SH;
          else if (Master_Core_i[i] == 1'b0 && Halt_ack_i[i] == 1'b1)
            ctrl_tmr_fsm_ns[i] = TMR_WAIT_SH;
          else ctrl_tmr_fsm_ns[i] = TMR_SH_HALT;
        end

        TMR_WAIT_SH: begin
          if (Hart_wfi_i[0] == 1'b1 && Hart_wfi_i[1] == 1'b1 && Hart_wfi_i[2] == 1'b1)
            ctrl_tmr_fsm_ns[i] = TMR_MS_INTRSYNC;
          else ctrl_tmr_fsm_ns[i] = TMR_WAIT_SH;
        end

        TMR_MS_INTRSYNC: begin
          if ((Hart_intc_ack_i[0] && Hart_intc_ack_i[1] && Hart_intc_ack_i[2]) == 1'b1)
            ctrl_tmr_fsm_ns[i] = TMR_SYNC;
          else ctrl_tmr_fsm_ns[i] = TMR_MS_INTRSYNC;
        end

        TMR_SYNC: begin
          if (((Hart_wfi_i[0] == 1'b1 && Hart_wfi_i[1] == 1'b1 && Hart_wfi_i[2])) && End_sw_routine_i ==1'b1)
            ctrl_tmr_fsm_ns[i] = TMR_IDLE;
          else if (Safe_configuration_i!=2'b01)
            ctrl_tmr_fsm_ns[i] = TMR_END_SYNC;
          else if (Preemptive_Trigger_i == 1'b1)
            ctrl_tmr_fsm_ns[i] = TMR_SWITCH_INTC;
          else if (tmr_error_s == 1'b1) ctrl_tmr_fsm_ns[i] = TMR_SYNCINTC;
          else ctrl_tmr_fsm_ns[i] = TMR_SYNC;
        end

        TMR_END_SYNC: begin
          if (Hart_wfi_i[0] == 1'b1 && Hart_wfi_i[1] == 1'b1 && Hart_wfi_i[2]) ctrl_tmr_fsm_ns[i] = TMR_END;
          else ctrl_tmr_fsm_ns[i] = TMR_END_SYNC;
        end

        TMR_END: begin
          if (Hart_intc_ack_i[i] == 1'b1 && Master_Core_i[i] == 1'b1)  //Master
            ctrl_tmr_fsm_ns[i] = TMR_IDLE;
          else if (Hart_wfi_i[i] == 1'b1 && Master_Core_i[i] == 1'b0)  //Non Masters
            ctrl_tmr_fsm_ns[i] = TMR_IDLE;
          else ctrl_tmr_fsm_ns[i] = TMR_END;
        end

        //***SW TMR Recovery***//
        TMR_SYNCINTC: begin
          if (Hart_intc_ack_i[0] && Hart_intc_ack_i[1] && Hart_intc_ack_i[2])
            ctrl_tmr_fsm_ns[i] = TMR_SWSYNC;
          else ctrl_tmr_fsm_ns[i] = TMR_SYNCINTC;
        end
        TMR_SWSYNC: begin
          if(~Hart_intc_ack_i[0] && ~Hart_intc_ack_i[1] && ~Hart_intc_ack_i[2] /*&& tmr_error == 1'b0*/)
            ctrl_tmr_fsm_ns[i] = TMR_SYNC;
          else ctrl_tmr_fsm_ns[i] = TMR_SWSYNC;
        end
        //*********************//
        TMR_SYNCINTC: begin

        end
        //****Preemptive*****//
        TMR_SWITCH_INTC: begin
          if (Hart_intc_ack_i[0] && Hart_intc_ack_i[1] && Hart_intc_ack_i[2]) ctrl_tmr_fsm_ns[i] = TMR_SAVE_CONTEXT;
          else ctrl_tmr_fsm_ns[i] = TMR_SWITCH_INTC;
        end
        TMR_SAVE_CONTEXT: begin
          if (Hart_wfi_i[0] == 1'b1 && Hart_wfi_i[1] == 1'b1 && Hart_wfi_i[2]) ctrl_tmr_fsm_ns[i] = TMR_SWITCH_WFI;
          else ctrl_tmr_fsm_ns[i] = TMR_SAVE_CONTEXT;
        end
        TMR_SWITCH_WFI: begin
          if (~Preemptive_Trigger_i) ctrl_tmr_fsm_ns[i] = TMR_IDLE;
          else ctrl_tmr_fsm_ns[i] = TMR_SWITCH_WFI;
        end
        //******************//
        default: begin
          ctrl_tmr_fsm_ns[i] = TMR_IDLE;
        end
      endcase
    end


    always_comb begin
      dbg_halt_req_general_s[i]    = 1'b0;
      //        enable_interrupt_halt_s[i] = 1'b0;
      Interrupt_Sync_TMR_s[i]      = 1'b0;
      single_bus_s[i]              = 1'b0;
      dbg_halt_req_s[i]            = 1'b0;
      tmr_voter_enable_s[i]        = 1'b0;
      TMR_Boot_s[i]                = 1'b0;
      Switch_SingletoTMR_s[i]      = 1'b0;
      Switch_TMRtoSingle_s[i]      = 1'b0;
      Interrupt_sw_TMR_Resync_s[i] = 1'b0;
      Switch_hostTMRtoSingle_s[i] = 1'b0;
      TMR_Preemptive_intc_s[i] = 1'b0;
      TMR_Preemptive_Ready_s[i] = 1'b0;

      unique case (ctrl_tmr_fsm_cs[i])

        TMR_START: begin
          dbg_halt_req_general_s[i] = 1'b1;
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
          if (Preemptive_Continue_i) TMR_Boot_s[i] = 1'b0;
          else TMR_Boot_s[i] = 1'b1;
        end

        TMR_BOOT: begin
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
          TMR_Boot_s[i] = 1'b1;
        end

        TMR_CONTEXT_BOOT: begin
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
        end

        TMR_SH_HALT: begin
          Switch_SingletoTMR_s[i] = 1'b1;
          //Temporal solution TMR lecture from both slaves: Todo solve irregular response from de OBI BUS
          //when 2 different masters ask for gnt
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
          if (Master_Core_i[i] == 1'b1) begin
            dbg_halt_req_s[i] = 1'b1;
            dbg_halt_req_general_s[i] = 1'b0;
          end else dbg_halt_req_general_s[i] = 1'b1;
        end

        //Temporal solution: Todo solve irregular response from de OBI BUS
        //when 2 different masters ask for gnt
        TMR_WAIT_SH: begin
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
        end

        TMR_MS_INTRSYNC: begin
          Interrupt_Sync_TMR_s[i] = 1'b1;
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
        end

        TMR_SYNC: begin
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
        end

        TMR_END_SYNC: begin
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
          Switch_hostTMRtoSingle_s[i] = 1'b1;
        end

        TMR_END: begin
          if (Master_Core_i[i] == 1'b1) begin
            Interrupt_Sync_TMR_s[i] = 1'b1;
            Switch_TMRtoSingle_s[i] = 1'b1;
          end
        end

        //Software Recovery Routine
        TMR_SYNCINTC: begin
          Interrupt_sw_TMR_Resync_s[i] = 1'b1;
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
        end

        TMR_SWSYNC: begin
          Interrupt_sw_TMR_Resync_s[i] = 1'b1;
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
        end

        TMR_SWITCH_INTC: begin
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
          TMR_Preemptive_intc_s[i] = 1'b1;
        end
        TMR_SAVE_CONTEXT: begin
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
          TMR_Preemptive_intc_s[i] = 1'b0;
        end
        TMR_SWITCH_WFI: begin
          single_bus_s[i] = 1'b1;
          tmr_voter_enable_s[i] = 1'b1;
          TMR_Preemptive_intc_s[i] = 1'b0;
          TMR_Preemptive_Ready_s[i] = 1'b1;
        end

        default: begin
        end

      endcase
    end

  end

  ////////////////////////////////////////////////////
  //   _____  __  __ _____     ______ _____ __  __  //
  //  |  __ \|  \/  |  __ \   |  ____/ ____|  \/  | //
  //  | |  | | \  / | |__)    | |__ | (___ | \  / | //
  //  | |  | | |\/| |  _  /   |  __| \___ \| |\/| | //
  //  | |__| | |  | | | \ \   | |    ____) | |  | | //
  //  |_____/|_|  |_|_|  \_\  |_|   |_____/|_|  |_| //
  //                                                //
  ////////////////////////////////////////////////////

  for (genvar i = 0; i < NHARTS; i++) begin : DMR_FSM

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        ctrl_dmr_fsm_cs[i] <= DMR_RESET;
      end else begin
        ctrl_dmr_fsm_cs[i] <= ctrl_dmr_fsm_ns[i];
      end
    end

    always_comb begin

      ctrl_dmr_fsm_ns[i] = ctrl_dmr_fsm_cs[i];

      unique case (ctrl_dmr_fsm_cs[i])

        DMR_RESET: begin
          ctrl_dmr_fsm_ns[i] = DMR_IDLE;
        end

        DMR_IDLE: begin
          if (ctrl_safe_fsm_cs == DMR_MODE && Start_i == 1'b1 && Enable_Switch_s == 1'b0 && DMR_Mask_i[i] == 1'b1)
            ctrl_dmr_fsm_ns[i] = DMR_START;
          else if (ctrl_safe_fsm_cs == DMR_MODE && Start_i == 1'b1 && Enable_Switch_s == 1'b1 && DMR_Mask_i[i] == 1'b1) begin
            if (Master_Core_i[i] == 1'b1 && Hart_wfi_i[i] == 1'b1 && Initial_Sync_Master_i == 1'b1 && Start_i == 1'b1)
              ctrl_dmr_fsm_ns[i] = DMR_SH_HALT;
            else if (Master_Core_i[i] == 1'b0 && (halt_req_s) == 1'b1 && Start_i == 1'b1)
              ctrl_dmr_fsm_ns[i] = DMR_SH_HALT;
            else ctrl_dmr_fsm_ns[i] = DMR_IDLE;
          end else begin
            ctrl_dmr_fsm_ns[i] = DMR_IDLE;
          end
        end

        DMR_START: begin
          if (Halt_ack_i[i] == 1'b1 && ~Preemptive_Continue_i) ctrl_dmr_fsm_ns[i] = DMR_BOOT;
          else if (Halt_ack_i[i] == 1'b1 && Preemptive_Continue_i) ctrl_dmr_fsm_ns[i] = DMR_CONTEXT_BOOT;
          else ctrl_dmr_fsm_ns[i] = DMR_START;
        end

        DMR_BOOT: begin
          if (Halt_ack_i[i] == 1'b0) ctrl_dmr_fsm_ns[i] = DMR_SYNC;
          else ctrl_dmr_fsm_ns[i] = DMR_BOOT;
        end

        DMR_CONTEXT_BOOT: begin
          if (Halt_ack_i[i] == 1'b0) ctrl_dmr_fsm_ns[i] = DMR_SYNC;
          else ctrl_dmr_fsm_ns[i] = DMR_CONTEXT_BOOT;
        end

        DMR_SH_HALT: begin
          if (Master_Core_i[i] == 1'b1 && (Halt_ack_i == (DMR_Mask_i ^ Master_Core_i)))
            ctrl_dmr_fsm_ns[i] = DMR_WAIT_SH;
          else if (Master_Core_i[i] == 1'b0 && Halt_ack_i[i] == 1'b1)
            ctrl_dmr_fsm_ns[i] = DMR_WAIT_SH;
          else ctrl_dmr_fsm_ns[i] = DMR_SH_HALT;
        end

        DMR_WAIT_SH: begin
          if (Hart_wfi_i[0] == 1'b1 && Hart_wfi_i[1] == 1'b1 && Hart_wfi_i[2] == 1'b1)
            ctrl_dmr_fsm_ns[i] = DMR_MS_INTRSYNC;
          else ctrl_dmr_fsm_ns[i] = DMR_WAIT_SH;
        end

        DMR_MS_INTRSYNC: begin  //todo carefull wich type selected
          if ((Hart_intc_ack_i[i] == 1'b1)) ctrl_dmr_fsm_ns[i] = DMR_SYNC;
          else ctrl_dmr_fsm_ns[i] = DMR_MS_INTRSYNC;
        end

        DMR_SYNC: begin
          if (((Hart_wfi_i[0] == 1'b1 && Hart_wfi_i[1] == 1'b1 && Hart_wfi_i[2]== 1'b1)) && End_sw_routine_i ==1'b1)
            ctrl_dmr_fsm_ns[i] = DMR_IDLE;
          else if (Safe_configuration_i!=2'b10 & Safe_configuration_i!=2'b11)
            ctrl_dmr_fsm_ns[i] = DMR_END_SYNC;
          else if (Preemptive_Trigger_i == 1'b1)
            ctrl_dmr_fsm_ns[i] = DMR_SWITCH_INTC;
          else if (dmr_error_s == 1'b1) ctrl_dmr_fsm_ns[i] = DMR_STOP;
          else ctrl_dmr_fsm_ns[i] = DMR_SYNC;
        end

        DMR_STOP: begin
          if (Hart_wfi_i == 3'b111) ctrl_dmr_fsm_ns[i] = DMR_INTC_RECOVERY;
          else ctrl_dmr_fsm_ns[i] = DMR_STOP;
        end
        DMR_INTC_RECOVERY: begin
          if (Halt_ack_i[i] == 1'b1) ctrl_dmr_fsm_ns[i] = DMR_RECOVERY;
          else ctrl_dmr_fsm_ns[i] = DMR_INTC_RECOVERY;

        end

        DMR_RECOVERY: begin
          if (Halt_ack_i[i] == 1'b0) ctrl_dmr_fsm_ns[i] = DMR_SYNC;
          else ctrl_dmr_fsm_ns[i] = DMR_RECOVERY;
        end

        DMR_END_SYNC: begin
          if (Hart_wfi_i[0] == 1'b1 && Hart_wfi_i[1] == 1'b1 && Hart_wfi_i[2] == 1'b1) ctrl_dmr_fsm_ns[i] = DMR_END;
          else ctrl_dmr_fsm_ns[i] = DMR_END_SYNC;
        end

        DMR_END: begin
          if (Hart_intc_ack_i[i] == 1'b1 && Master_Core_i[i] == 1'b1)  //Master
            ctrl_dmr_fsm_ns[i] = DMR_IDLE;
          else if (Hart_wfi_i[i] == 1'b1 && Master_Core_i[i] == 1'b0)  //Non Masters
            ctrl_dmr_fsm_ns[i] = DMR_IDLE;
          else ctrl_dmr_fsm_ns[i] = DMR_END;
        end

        //****Preemptive*****//
        DMR_SWITCH_INTC: begin
          if (Hart_intc_ack_i == DMR_Mask_i) ctrl_dmr_fsm_ns[i] = DMR_SAVE_CONTEXT;
          else ctrl_dmr_fsm_ns[i] = DMR_SWITCH_INTC;
        end
        DMR_SAVE_CONTEXT: begin
          if (Hart_wfi_i[0] == 1'b1 && Hart_wfi_i[1] == 1'b1 && Hart_wfi_i[2]) ctrl_dmr_fsm_ns[i] = DMR_SWITCH_WFI;
          else ctrl_dmr_fsm_ns[i] = DMR_SAVE_CONTEXT;
        end
        DMR_SWITCH_WFI: begin
          if (~Preemptive_Trigger_i) ctrl_dmr_fsm_ns[i] = DMR_IDLE;
          else ctrl_dmr_fsm_ns[i] = DMR_SWITCH_WFI;
        end
        //******************//
        default: begin
          ctrl_dmr_fsm_ns[i] = DMR_IDLE;
        end
      endcase
    end

    always_comb begin
      DMR_dbg_halt_req_general_s[i] = 1'b0;
      DMR_Single_s[i] = 1'b0;
      DMR_dbg_halt_req_s[i] = 1'b0;
      DMR_Boot_s[i] = 1'b0;
      dual_mode_dmr_s[i] = 1'b0;
      dmr_dmr_config_s[i] = 1'b1;
      Switch_SingletoDMR_s[i] = 1'b0;
      Switch_DMRtoSingle_s[i] = 1'b0;
      Interrupt_Sync_DMR_s[i] = 1'b0;
      wfi_dmr_o[i] = 1'b0;
      dbg_halt_dmr_recovery[i] = 1'b0;
      dmr_delayed_s[i] = 1'b0;
      DMR_Rec_s[i] = 1'b0;
      Switch_hostDMRtoSingle_s[i]= 1'b0;
      DMR_Preemptive_intc_s[i] = 1'b0;
      DMR_Preemptive_Ready_s[i] = 1'b0;
      unique case (ctrl_dmr_fsm_cs[i])

        DMR_IDLE: begin
          dmr_dmr_config_s[i] = 1'b0;
        end

        DMR_START: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_dbg_halt_req_general_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          if (Preemptive_Continue_i) DMR_Boot_s[i] = 1'b0;
          else DMR_Boot_s[i] = 1'b1;

          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;

        end

        DMR_BOOT: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          DMR_Boot_s[i] = 1'b1;

          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;

        end

        DMR_CONTEXT_BOOT: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;

          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;

        end

        DMR_SH_HALT: begin
          Switch_SingletoDMR_s[i] = 1'b1;
          if (Master_Core_i[i] == 1'b1) begin
            DMR_dbg_halt_req_s[i] = 1'b1;
            DMR_dbg_halt_req_general_s[i] = 1'b0;
          end else DMR_dbg_halt_req_general_s[i] = 1'b1;
        end

        DMR_MS_INTRSYNC: begin
          Interrupt_Sync_DMR_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          dual_mode_dmr_s[i] = 1'b1;
          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;

        end

        DMR_SYNC: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;

        end

        DMR_END_SYNC: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          Switch_hostDMRtoSingle_s[i] = 1'b1;
        end

        DMR_END: begin
          if (Master_Core_i[i] == 1'b1) begin
            Interrupt_Sync_DMR_s[i] = 1'b1;
            Switch_DMRtoSingle_s[i] = 1'b1;
          end
        end

        DMR_STOP: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          wfi_dmr_o[i] = 1'b1;
        end

        DMR_INTC_RECOVERY: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          dbg_halt_dmr_recovery[i] = 1'b1;
          DMR_Rec_s[i] = 1'b1;
          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;

        end
        DMR_RECOVERY: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          DMR_Rec_s[i] = 1'b1;
          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;

        end

        DMR_SWITCH_INTC: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          DMR_Preemptive_intc_s[i] = 1'b1;
          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;
        end
        DMR_SAVE_CONTEXT: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          DMR_Preemptive_intc_s[i] = 1'b0;
          if (Safe_configuration_i == 2'b11) dmr_delayed_s[i] = 1'b1;
        end
        DMR_SWITCH_WFI: begin
          dual_mode_dmr_s[i] = 1'b1;
          DMR_Single_s[i] = 1'b1;
          DMR_Preemptive_intc_s[i] = 1'b0;
          DMR_Preemptive_Ready_s[i] = 1'b1;
        end
        default: begin
        end

      endcase
    end
  end


  // Inter-FSM Signals operation
  assign halt_req_s = dbg_halt_req_s[0] || dbg_halt_req_s[1] || dbg_halt_req_s[2] ||
                    DMR_dbg_halt_req_s[0] || DMR_dbg_halt_req_s[1] || DMR_dbg_halt_req_s[2];

  // In-Out FSM Signals operation Todo: Can be found a more elegant solution
  assign Single_Bus_o = (single_bus_s[0] | single_bus_s[1] | single_bus_s[2] | DMR_Single_s[0] | DMR_Single_s[1] | DMR_Single_s[2]) ||
                       General_boot_s;
  assign Tmr_voter_enable_o = (tmr_voter_enable_s[0] || tmr_voter_enable_s[1] || tmr_voter_enable_s[2]) | General_boot_s;
  assign Dmr_comparator_enable_o = (dual_mode_dmr_s[0] || dual_mode_dmr_s[1] || dual_mode_dmr_s[2]);


  //FF for lockstep active
  logic set;
  assign set = dmr_delayed_s[0] | dmr_delayed_s[1] | dmr_delayed_s[2];

  logic clear;
  assign clear = (Hart_wfi_i[0] & Hart_wfi_i[1] & Hart_wfi_i[2]) & (~Safe_configuration_i[0] | ~Safe_configuration_i[1]); //Locsktep == '11'

  logic delay_ff;
  assign Delayed_o = delay_ff | dmr_delayed_s[0] | dmr_delayed_s[1] | dmr_delayed_s[2];
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      delay_ff <= 1'b0;
    end else begin
      if (clear == 1'b1) delay_ff <= 1'b0;
      else if (set == 1'b1) delay_ff <= 1'b1;
    end
  end

  always_comb begin
    dmr_error_s = '0;
    if (Master_Core_i == 3'b001) dmr_error_s = dmr_error_i[0];
    else if (Master_Core_i == 3'b010) dmr_error_s = dmr_error_i[1];
    else dmr_error_s = dmr_error_i[2];
  end

  assign Interrupt_Halt_o = dbg_halt_req_general_s | Single_Halt_request_s | DMR_dbg_halt_req_general_s | dbg_halt_dmr_recovery;

  assign Interrupt_Sync_o = Interrupt_Sync_TMR_s | Interrupt_Sync_DMR_s;

  assign en_ext_debug_req_o = en_safe_ext_debug_req_s | en_single_ext_debug_req_s;

  assign Start_Boot_o = Single_Boot_s | TMR_Boot_s[0] | TMR_Boot_s[1] | TMR_Boot_s[2] |
                      DMR_Boot_s[0] | DMR_Boot_s[1] | DMR_Boot_s[2];

  assign Dmr_config_o = dmr_dmr_config_s;
  assign DMR_Rec_o = DMR_Rec_s[0] | DMR_Rec_s[1] | DMR_Rec_s[2];

  assign Interrupt_swResync_o = Interrupt_sw_TMR_Resync_s;



  //###Critical Section###//

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      tmr_error_ff <= '0;
    end else begin
      tmr_error_ff[0] <= tmr_error_i;
      if ((ctrl_tmr_fsm_cs[0] == TMR_SYNC || ctrl_tmr_fsm_cs[1] == TMR_SYNC || ctrl_tmr_fsm_cs[2] == TMR_SYNC)&&
                                      (tmr_error_i) && (~tmr_error_ff[0]))
        tmr_error_ff[1] <= ~tmr_error_ff[1];
      else if (ctrl_tmr_fsm_cs[0] != TMR_SYNC || ctrl_tmr_fsm_cs[1] != TMR_SYNC || ctrl_tmr_fsm_cs[2] != TMR_SYNC)
        tmr_error_ff <= '0;
    end
  end

  assign tmr_error_s = (~tmr_critical_section_i & (tmr_error_i | tmr_error_ff[1])) | (tmr_critical_section_i &
                                                                    (~tmr_error_ff[0]) & tmr_error_ff[1] & tmr_error_i);
  //#######################//

  //###Host Sync/Desync###//
  always_comb begin
    if (Enable_Switch_s) begin
      if (Master_Core_i == 3'b001) begin
        Interrupt_Host_Sync_o = 3'b001;
      end else if (Master_Core_i == 3'b010) begin
        Interrupt_Host_Sync_o = 3'b010;
      end else  begin
        Interrupt_Host_Sync_o = 3'b100;
      end
    end else begin
        Interrupt_Host_Sync_o = 3'b000;
    end
  end

  assign Interrupt_Host_Desync_o = Switch_hostDMRtoSingle_s | Switch_hostTMRtoSingle_s;
  //######################//

  assign Preemptive_Ready_o = (Single_Preemptive_Ready_s) | (|TMR_Preemptive_Ready_s) | (|DMR_Preemptive_Ready_s);
  assign Interrupt_Preemptive_o = Single_Preemptive_intc_s | TMR_Preemptive_intc_s | DMR_Preemptive_intc_s;

endmodule



// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

module safe_cpu_wrapper
  import reg_pkg::*;
  import eros_pkg::*;
#(
    parameter type obi_req_t            = logic,
    parameter type obi_resp_t           = logic,
    parameter NHARTS  = 3,
    parameter NMASTER_COPROC_RND = eros_pkg::NMASTER_COPROC == 0 ? 1 : eros_pkg::NMASTER_COPROC,
    parameter NCYCLES = eros_pkg::NCYCLES
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Instruction memory interface
    output obi_req_t  [NHARTS-1 : 0] core_instr_req_o,
    input  obi_resp_t [NHARTS-1 : 0] core_instr_resp_i,

    // Data memory interface
    output obi_req_t  [NHARTS-1 : 0] core_data_req_o,
    input  obi_resp_t [NHARTS-1 : 0] core_data_resp_i,

    // Coprocessor Signals
    output obi_req_t [NMASTER_COPROC_RND-1:0] copr_req_o,
    input obi_resp_t [NMASTER_COPROC_RND-1:0] copr_resp_i,

    // OBI -> Memory mapped register control Safe CPU
    input  reg_req_t wrapper_csr_req_i,
    output reg_rsp_t wrapper_csr_resp_o,

    // Debug Interface
    input  logic              debug_req_i,
    output logic [NHARTS-1:0] sleep_o,

    //External Interrupt
    output logic interrupt_o
);
  //TODO: Future template 2 or 3 HARTS
  localparam NRCOMPARATORS = NHARTS == 3 ? 3 : 1;

  //Signals//

  logic bus_config_s;

  logic [NHARTS-1:0][31:0] intr;
  logic [NHARTS-1:0][31:0] delayed_intr_i;
  logic [NHARTS-1:0][31:0] delayed_intr_o;
  logic [NHARTS-1:0][31:0] core_intr_i;

  logic [NHARTS-1:0] debug_req;
  logic [NHARTS-1:0] delayed_debug_req_i;
  logic [NHARTS-1:0] delayed_debug_req_o;
  logic [NHARTS-1:0] core_debug_req_i;

  logic en_ext_debug_s;
  logic Initial_Sync_Master_s;
  logic [NHARTS-1:0] Hart_ack_s;
  logic [NHARTS-1:0] Hart_wfi_s;
  logic [NHARTS-1:0] Hart_intc_ack_s;
  logic [NHARTS-1:0] Interrupt_swResync_s;
  logic [NHARTS-1:0] Interrupt_DMSH_Sync_s;
  logic [NHARTS-1:0] master_core_s;
  logic [NHARTS-1:0] master_core_ff_s;
  logic [2:0] safe_mode_s;
  logic [1:0] safe_configuration_s;
  logic critical_section_s;
  logic [NHARTS-1:0] intc_sync_s;
  logic [NHARTS-1:0] host_sync_s;
  logic [NHARTS-1:0] host_desync_s;
  logic [NHARTS-1:0] intc_halt_s;
  logic [NHARTS-1:0] sleep_s;
  logic [NHARTS-1:0] sleep_ff_s;
  logic [NHARTS-1:0] debug_mode_s;
  logic End_sw_routine_s;
  logic Start_s;
  logic Start_Boot_s;
  logic DMR_Rec_s;

  // CPU ports
  obi_req_t [NHARTS-1 : 0] core_instr_req;
  obi_resp_t [NHARTS-1 : 0] core_instr_resp;

  obi_req_t [NHARTS-1 : 0] core_data_req;
  obi_resp_t [NHARTS-1 : 0] core_data_resp;

  // Muxed Input CPU ports
  obi_req_t [NHARTS-1 : 0] mux_core_data_req_i;

  // Muxed Output CPU ports
  obi_resp_t [NHARTS-1 : 0] mux_core_data_resp_o;

  // XBAR_CPU Slaves Signals
  obi_req_t [NHARTS-1 : 0][1:0] xbar_core_data_req;
  obi_resp_t [NHARTS-1 : 0][1:0] xbar_core_data_resp;

  // Voted_CPU Signals
  obi_req_t [NHARTS-1 : 0] voted_core_instr_req_o;
  obi_req_t [NHARTS-1 : 0] voted_core_data_req_o;
  logic tmr_error_s;
  logic [NHARTS-1:0] dmr_error_s;
  logic [NHARTS-1:0] tmr_errorid_s;
  logic tmr_voter_enable_s;
  logic [2:0] dmr_config_s;
  logic dual_mode_s;
  logic delayed_s;
  logic [NHARTS-1:0] dmr_wfi_s;

  // Compared CPU Signals
  obi_req_t [NRCOMPARATORS-1:0] compared_core_instr_req_o;
  obi_req_t [NRCOMPARATORS-1:0] compared_core_data_req_o;

  // CPU Private Regs
  reg_pkg::reg_req_t [NHARTS-1 : 0] cpu_reg_req;
  reg_pkg::reg_rsp_t [NHARTS-1 : 0] cpu_reg_rsp;

  // Safe CPU reg port
  reg_pkg::reg_req_t safe_cpu_wrapper_reg_req;
  reg_pkg::reg_rsp_t safe_cpu_wrapper_reg_rsp;


  // Configuration IDs Cores

  logic [2:0][NHARTS-1:0] Core_ID;
  assign Core_ID[0] = {3'b001};
  assign Core_ID[1] = {3'b010};
  assign Core_ID[2] = {3'b100};

  //Isolate val bus
  // Instruction memory interface
  obi_resp_t [NHARTS-1 : 0] isolate_core_instr_resp;

  // Data memory interface
  obi_resp_t [NHARTS-1 : 0] isolate_core_data_resp;

  // Coprocessors Signals
  obi_req_t [NHARTS-1 : 0][NMASTER_COPROC_RND-1:0] copr_req_s;
  obi_resp_t [NHARTS-1 : 0][NMASTER_COPROC_RND-1:0] copr_resp_s;

  obi_req_t [1:0] copr_dcls_master_req_s;
  obi_resp_t [1:0] copr_dcls_master_resp_s;

  obi_req_t [1:0] copr_dcls_slave_req_s;
  obi_resp_t [1:0] copr_dcls_slave_resp_s;

  obi_req_t   [1:0] voted_copr_req_s;
  obi_resp_t  [1:0] voted_copr_resp_s;

  obi_req_t   [1:0] compared_copr_req_s;
  obi_resp_t  [1:0] compared_copr_resp_s;

  obi_req_t   [1:0] master_copr_req_s;
  obi_resp_t  [1:0] master_copr_resp_s;

  obi_req_t   [1:0] slave_copr_req_s;
  obi_resp_t  [1:0] slave_copr_resp_s;

  obi_req_t   [1:0] master_copr_req_ff_s;
  obi_resp_t  [1:0] master_copr_resp_ff_s;

  obi_req_t   [1:0] slave_copr_req_ff_s;
  obi_resp_t  [1:0] slave_copr_resp_ff_s;

  obi_req_t  [NHARTS-1 : 0] core_data_interconnect_req;
  obi_resp_t [NHARTS-1 : 0] core_data_interconnect_resp;

  //***Cores System***//

  cpu_system #(
    .obi_req_t            (obi_req_t  ),
    .obi_resp_t           (obi_resp_t )
    ) cpu_system_i (
    .clk_i,
    .rst_ni,
    // Instruction memory interface
    .core_instr_req_o (core_instr_req),
    .core_instr_resp_i(core_instr_resp),

    .copr_req_o(copr_req_s),
    .copr_resp_i(copr_resp_s),

    // Data memory interface
    .core_data_req_o (core_data_req),
    .core_data_resp_i(core_data_resp),

    // Interrupt
    //Core 0
    .intc_core0(core_intr_i[0]),
    //Core 1
    .intc_core1(core_intr_i[1]),

    //Core 2
    .intc_core2(core_intr_i[2]),


    .sleep_o(sleep_s),

    // Debug Interface
    .debug_req_i (core_debug_req_i),
    .debug_mode_o(debug_mode_s)
  );

  assign sleep_o = sleep_ff_s;

  //Added FF for output isolation
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sleep_ff_s <= '0;
    end else begin
      sleep_ff_s <= sleep_s;
    end
  end

  safe_wrapper_ctrl #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) safe_wrapper_ctrl_i (
      .clk_i,
      .rst_ni,

      // Bus Interface
      .reg_req_i(wrapper_csr_req_i),
      .reg_rsp_o(wrapper_csr_resp_o),

      .master_core_o(master_core_s),
      .safe_mode_o(safe_mode_s),
      .safe_configuration_o(safe_configuration_s),
      .critical_section_o(critical_section_s),
      .Initial_Sync_Master_o(Initial_Sync_Master_s),
      .Start_o(Start_s),
      .End_sw_routine_o(End_sw_routine_s),
      .interrupt_o(interrupt_o),
      .debug_mode_i(debug_mode_s),
      .sleep_i(sleep_s),
      .Start_Boot_i(Start_Boot_s),
      .DMR_Rec_i(DMR_Rec_s),
      //.Debug_ext_req_i(debug_req_i), //Check if debug_req comes from FSM or external debug Todo: change to 1 the extenal req
      .en_ext_debug_i(en_ext_debug_s)  //Todo: other more elegant solution for debugging
  );


  //***Safe FSM***//

  safe_FSM safe_FSM_i (
      // Clock and Reset
      .clk_i,
      .rst_ni,
      .tmr_critical_section_i(critical_section_s),
      .DMR_Mask_i(safe_mode_s),
      .Safe_configuration_i(safe_configuration_s),
      .Initial_Sync_Master_i(Initial_Sync_Master_s),
      .Halt_ack_i(debug_mode_s),
      .Hart_wfi_i(sleep_s),
      .Hart_intc_ack_i(Hart_intc_ack_s),
      .Master_Core_i(master_core_s),
      .Interrupt_Sync_o(intc_sync_s),
      .Interrupt_swResync_o(Interrupt_swResync_s),
      .Interrupt_Host_Sync_o(host_sync_s),
      .Interrupt_Host_Desync_o(host_desync_s),
      .Interrupt_Halt_o(intc_halt_s),
      .tmr_error_i(tmr_error_s),
      .voter_id_error(tmr_errorid_s),
      .Single_Bus_o(bus_config_s),
      .Tmr_voter_enable_o(tmr_voter_enable_s),
      .Dmr_comparator_enable_o(dual_mode_s),
      .Dmr_config_o(dmr_config_s),
      .dmr_error_i(dmr_error_s),
      .wfi_dmr_o(dmr_wfi_s),
      .Delayed_o(delayed_s),
      .Start_Boot_o(Start_Boot_s),
      .Start_i(Start_s),
      .End_sw_routine_i(End_sw_routine_s),
      .DMR_Rec_o(DMR_Rec_s),
      .en_ext_debug_req_o(en_ext_debug_s)
  );
  assign intr[0] = {12'b0, host_desync_s[0], host_sync_s[0], intc_sync_s[0], Interrupt_swResync_s[0], 16'b0};
  assign intr[1] = {12'b0, host_desync_s[1], host_sync_s[1], intc_sync_s[1], Interrupt_swResync_s[1], 16'b0};
  assign intr[2] = {12'b0, host_desync_s[2], host_sync_s[2], intc_sync_s[2], Interrupt_swResync_s[2], 16'b0};

  //Todo: future posibility to debug during TMR_SYNC or DMR_SYNC
  assign debug_req[0] = (debug_req_i && en_ext_debug_s && master_core_s[0]) || intc_halt_s[0];
  assign debug_req[1] = (debug_req_i && en_ext_debug_s && master_core_s[1]) || intc_halt_s[1];
  assign debug_req[2] = (debug_req_i && en_ext_debug_s && master_core_s[2]) || intc_halt_s[2];

  //***Safe Interconnection***//
  safe_interconnection #(
    .obi_req_t            (obi_req_t  ),
    .obi_resp_t           (obi_resp_t ),
    .NCYCLES(NCYCLES)
  )safe_interconnection (
    // Clock and Reset
    .clk_i,
    .rst_ni,

    // Instruction memory interface

    // Input
    .core_instr_req_i(core_instr_req),
    .core_instr_resp_o(core_instr_resp),

    // Output
    .core_instr_req_o(core_instr_req_o),
    .core_instr_resp_i(core_instr_resp_i),

    // Data memory interface

    // Input
    .core_data_req_i(core_data_interconnect_req),
    .core_data_resp_o(core_data_interconnect_resp),

    // Output
    .core_data_req_o(core_data_req_o),
    .core_data_resp_i(core_data_resp_i),


    // Coproc interface

    // // Input
    .coproc_req_i(copr_req_s),
    .coproc_resp_o(copr_resp_s),

    // // Output
    .coproc_req_o(copr_req_o),
    .coproc_resp_i(copr_resp_i),

    // Control & Status interface
    .dcls_mode_i(dual_mode_s),
    .staggered_mode_i(delayed_s),
    .dcls_config_i(dmr_config_s),
    .dcls_wfi_i(dmr_wfi_s),
    .comparator_error_o(dmr_error_s),

    .tcls_mode_i(tmr_voter_enable_s),
    .voter_error_o(tmr_error_s),
    .voter_id_error_o(tmr_errorid_s),

    .master_core_i(master_core_ff_s)
  );






  /**************************Upper-Demux-Req**********************************/
  // //upper
  // obi_req_t [NHARTS-1:0][NHARTS-1:0] upper_mux_core_instr_req_i;
  // obi_req_t [NHARTS-1:0][NHARTS-1:0] upper_mux_core_data_req_i;

  // obi_resp_t [NHARTS-1:0][1:0] upper_delayed_core_instr_resp_i;
  // obi_resp_t [NHARTS-1:0][1:0] upper_delayed_core_data_resp_i;

  // //lower
  // obi_resp_t [NHARTS-1:0][1:0] lower_mux_core_instr_resp_i;
  // obi_resp_t [NHARTS-1:0][1:0] lower_mux_core_data_resp_i;

  // for (genvar i = 0; i < NHARTS; i++) begin : eros_upper_demux
  //   always_comb begin
  //     if (master_core_ff_s[2] && (dual_mode_s || tmr_voter_enable_s)) begin
  //       upper_mux_core_instr_req_i[i][0] = '0;
  //       upper_mux_core_instr_req_i[i][1] = '0;
  //       upper_mux_core_instr_req_i[i][2] = core_instr_req[i];

  //       upper_mux_core_data_req_i[i][0]  = '0;
  //       upper_mux_core_data_req_i[i][1]  = '0;
  //       upper_mux_core_data_req_i[i][2]  = mux_core_data_req_i[i];
  //     end else if (master_core_ff_s[1] && (dual_mode_s || tmr_voter_enable_s)) begin
  //       upper_mux_core_instr_req_i[i][0] = '0;
  //       upper_mux_core_instr_req_i[i][1] = core_instr_req[i];
  //       upper_mux_core_instr_req_i[i][2] = '0;

  //       upper_mux_core_data_req_i[i][0]  = '0;
  //       upper_mux_core_data_req_i[i][1]  = mux_core_data_req_i[i];
  //       upper_mux_core_data_req_i[i][2]  = '0;
  //     end else if (master_core_ff_s[0] && (dual_mode_s || tmr_voter_enable_s)) begin
  //       upper_mux_core_instr_req_i[i][0] = core_instr_req[i];
  //       upper_mux_core_instr_req_i[i][1] = '0;
  //       upper_mux_core_instr_req_i[i][2] = '0;

  //       upper_mux_core_data_req_i[i][0]  = mux_core_data_req_i[i];
  //       upper_mux_core_data_req_i[i][1]  = '0;
  //       upper_mux_core_data_req_i[i][2]  = '0;
  //     end else begin  // default case when not a master and the core has to use its bus
  //       if (i == 0) begin
  //         upper_mux_core_instr_req_i[i][0] = core_instr_req[i];
  //         upper_mux_core_instr_req_i[i][1] = '0;
  //         upper_mux_core_instr_req_i[i][2] = '0;

  //         upper_mux_core_data_req_i[i][0]  = mux_core_data_req_i[i];
  //         upper_mux_core_data_req_i[i][1]  = '0;
  //         upper_mux_core_data_req_i[i][2]  = '0;
  //       end else if (i == 1) begin
  //         upper_mux_core_instr_req_i[i][0] = '0;
  //         upper_mux_core_instr_req_i[i][1] = core_instr_req[i];
  //         upper_mux_core_instr_req_i[i][2] = '0;

  //         upper_mux_core_data_req_i[i][0]  = '0;
  //         upper_mux_core_data_req_i[i][1]  = mux_core_data_req_i[i];
  //         upper_mux_core_data_req_i[i][2]  = '0;
  //       end else begin
  //         upper_mux_core_instr_req_i[i][0] = '0;
  //         upper_mux_core_instr_req_i[i][1] = '0;
  //         upper_mux_core_instr_req_i[i][2] = core_instr_req[i];

  //         upper_mux_core_data_req_i[i][0]  = '0;
  //         upper_mux_core_data_req_i[i][1]  = '0;
  //         upper_mux_core_data_req_i[i][2]  = mux_core_data_req_i[i];
  //       end
  //     end
  //   end
  // end

  // /**************************************************************************/

  // /**************************Lower-Mux-Req**********************************/
  // for (genvar i = 0; i < NHARTS; i++) begin : eros_lower_mux_obi_req

  //   always_comb begin
  //     //TODO: Reduce de mux configurations inputs ports, implies modification in the Safe_FSM
  //     if (master_core_ff_s[i] && tmr_voter_enable_s && !dual_mode_s) begin
  //       core_instr_req_o[i] = voted_core_instr_req_o[i];
  //       core_data_req_o[i]  = voted_core_data_req_o[i];
  //     end else if (master_core_ff_s[i] && !tmr_voter_enable_s && dual_mode_s) begin
  //       core_instr_req_o[i] = compared_core_instr_req_o[i];
  //       core_data_req_o[i]  = compared_core_data_req_o[i];
  //     end else begin //Todo: Put here in the future the posibility to wake up the third core in case of a hang in DCLS mode.
  //       core_instr_req_o[i] = upper_mux_core_instr_req_i[i][i];
  //       core_data_req_o[i]  = upper_mux_core_data_req_i[i][i];
  //     end
  //   end
  // end

  // /**************************************************************************/
  // /**************************Lower-Demux-Resp********************************/
  // for (genvar i = 0; i < NHARTS; i++) begin : eros_lower_mux_obi_resp
  //   always_comb begin
  //     if (delayed_s & dual_mode_s) begin  //TODO: should not be necesary use de dual_mode_s
  //       lower_mux_core_instr_resp_i[i][0] = '0;
  //       lower_mux_core_instr_resp_i[i][1] = core_instr_resp_i[i];

  //       lower_mux_core_data_resp_i[i][0]  = '0;
  //       lower_mux_core_data_resp_i[i][1]  = core_data_resp_i[i];
  //     end else begin
  //       lower_mux_core_instr_resp_i[i][0] = core_instr_resp_i[i];
  //       lower_mux_core_instr_resp_i[i][1] = '0;

  //       lower_mux_core_data_resp_i[i][0]  = core_data_resp_i[i];
  //       lower_mux_core_data_resp_i[i][1]  = '0;
  //     end
  //   end
  // end

  // /*********************************************************************/
  // /**************************Upper-Mux-Resp********************************/
  // //upper_mux_core_instr_req_i;
  // //upper_mux_core_data_req_i;
  // for (genvar i = 0; i < NHARTS; i++) begin : eros_upper_mux_obi_resp
  //   always_comb begin
  //     if (dmr_wfi_s[i] == '1) begin
  //       core_instr_resp[i] = isolate_core_instr_resp[i];
  //       mux_core_data_resp_o[i] = isolate_core_data_resp[i];
  //     end else if (master_core_ff_s[0] && !delayed_s && (tmr_voter_enable_s || (dual_mode_s && dmr_config_s[i]))) begin
  //       core_instr_resp[i] = lower_mux_core_instr_resp_i[0][0];
  //       mux_core_data_resp_o[i] = lower_mux_core_data_resp_i[0][0];
  //     end else if (master_core_ff_s[1] && !delayed_s && (tmr_voter_enable_s || (dual_mode_s && dmr_config_s[i]))) begin
  //       core_instr_resp[i] = lower_mux_core_instr_resp_i[1][0];
  //       mux_core_data_resp_o[i] = lower_mux_core_data_resp_i[1][0];
  //     end else if (master_core_ff_s[2] && !delayed_s && (tmr_voter_enable_s || (dual_mode_s && dmr_config_s[i]))) begin
  //       core_instr_resp[i] = lower_mux_core_instr_resp_i[2][0];
  //       mux_core_data_resp_o[i] = lower_mux_core_data_resp_i[2][0];
  //       //delayed
  //     end else if (master_core_ff_s[i] && dual_mode_s && delayed_s) begin //if master of DCLS connect to the second core
  //       core_instr_resp[i] = upper_delayed_core_instr_resp_i[i][0];
  //       mux_core_data_resp_o[i] = upper_delayed_core_data_resp_i[i][0];
  //     end else if (!master_core_ff_s[i] && dual_mode_s && delayed_s && dmr_config_s[i])  begin //if not master of DCLS connect to the second core
  //       if (master_core_ff_s[0]) begin
  //         core_instr_resp[i] = upper_delayed_core_instr_resp_i[0][1];
  //         mux_core_data_resp_o[i] = upper_delayed_core_data_resp_i[0][1];
  //       end else if (master_core_ff_s[1]) begin
  //         core_instr_resp[i] = upper_delayed_core_instr_resp_i[1][1];
  //         mux_core_data_resp_o[i] = upper_delayed_core_data_resp_i[1][1];
  //       end else begin
  //         core_instr_resp[i] = upper_delayed_core_instr_resp_i[2][1];
  //         mux_core_data_resp_o[i] = upper_delayed_core_data_resp_i[2][1];
  //       end
  //       //default
  //     end else begin
  //       core_instr_resp[i] = lower_mux_core_instr_resp_i[i][0];
  //       mux_core_data_resp_o[i] = lower_mux_core_data_resp_i[i][0];
  //     end
  //   end
  // end
  // /*********************************************************************/
  // /*********************************************************************/



  // assign mux_core_data_req_i[0] = xbar_core_data_req[0][0];
  // assign mux_core_data_req_i[1] = xbar_core_data_req[1][0];
  // assign mux_core_data_req_i[2] = xbar_core_data_req[2][0];
  // assign xbar_core_data_resp[0][0] = mux_core_data_resp_o[0];
  // assign xbar_core_data_resp[1][0] = mux_core_data_resp_o[1];
  // assign xbar_core_data_resp[2][0] = mux_core_data_resp_o[2];

  assign core_data_interconnect_req[0] = xbar_core_data_req[0][0];
  assign core_data_interconnect_req[1] = xbar_core_data_req[1][0];
  assign core_data_interconnect_req[2] = xbar_core_data_req[2][0];
  assign xbar_core_data_resp[0][0] = core_data_interconnect_resp[0];
  assign xbar_core_data_resp[1][0] = core_data_interconnect_resp[1];
  assign xbar_core_data_resp[2][0] = core_data_interconnect_resp[2];

  // /************************Isolate BUS***************************/
  // logic [NHARTS-1:0] instr_isolate_valid_q;
  // logic [NHARTS-1:0] instr_expected_rvalid;
  // for (genvar i = 0; i < NHARTS; i++) begin : isolate_obi_bus_instr

  //   always_ff @(posedge clk_i or negedge rst_ni) begin
  //     if (!rst_ni) begin
  //       instr_isolate_valid_q[i] <= '0;
  //       instr_expected_rvalid[i] <= '0;
  //     end else begin
  //       if (dmr_wfi_s[i] == 1'b0) begin  //clear
  //         instr_isolate_valid_q[i] <= '0;
  //         //if req & gnt before wfi halt, it needs a rvalid ack otherwise could stall waiting that read/write request.
  //         instr_expected_rvalid[i] <= (core_instr_req[i].req & core_instr_resp[i].gnt) | (instr_expected_rvalid[i] & ~core_instr_resp[i].rvalid);
  //       end else begin
  //         instr_isolate_valid_q[i] <= isolate_core_instr_resp[i].gnt;
  //         instr_expected_rvalid[i] <= '0;
  //       end
  //     end
  //   end
  //   assign isolate_core_instr_resp[i].gnt = core_instr_req[i].req;
  //   assign isolate_core_instr_resp[i].rvalid = instr_isolate_valid_q[i] | instr_expected_rvalid[i];
  //   assign isolate_core_instr_resp[i].rdata = 32'h10500073;  //wfi instruction
  // end

  // logic [NHARTS-1:0] data_isolate_valid_q;
  // logic [NHARTS-1:0] data_expected_rvalid;
  // for (genvar i = 0; i < NHARTS; i++) begin : isolate_obi_bus_data

  //   always_ff @(posedge clk_i or negedge rst_ni) begin
  //     if (!rst_ni) begin
  //       data_isolate_valid_q[i] <= '0;
  //       data_expected_rvalid[i] <= '0;
  //     end else begin
  //       if (dmr_wfi_s[i] == 1'b0) begin  //clear
  //         data_isolate_valid_q[i] <= '0;
  //         //if req & gnt before wfi halt, it needs a rvalid ack otherwise could stall waiting that read/write request.
  //         data_expected_rvalid[i] <= core_data_req[i].req & mux_core_data_resp_o[i].gnt | (data_expected_rvalid[i] & ~mux_core_data_resp_o[i].rvalid);
  //       end else begin
  //         data_isolate_valid_q[i] <= isolate_core_data_resp[i].gnt;
  //         data_expected_rvalid[i] <= '0;
  //       end
  //     end
  //   end
  //   assign isolate_core_data_resp[i].gnt = core_data_req[i].req;
  //   assign isolate_core_data_resp[i].rvalid = data_isolate_valid_q[i] | data_expected_rvalid[i];
  //   assign isolate_core_data_resp[i].rdata = 32'h0;  //0 data val
  // end


  // /*********************************************************/
  // //*********************Safety Voter***********************//
  // obi_req_t [NHARTS-1:0] tmr0_core_instr_req_i;
  // obi_req_t [NHARTS-1:0] tmr1_core_instr_req_i;
  // obi_req_t [NHARTS-1:0] tmr2_core_instr_req_i;
  // assign tmr0_core_instr_req_i = {
  //   upper_mux_core_instr_req_i[2][0],
  //   upper_mux_core_instr_req_i[1][0],
  //   upper_mux_core_instr_req_i[0][0]
  // };
  // assign tmr1_core_instr_req_i = {
  //   upper_mux_core_instr_req_i[2][1],
  //   upper_mux_core_instr_req_i[1][1],
  //   upper_mux_core_instr_req_i[0][1]
  // };
  // assign tmr2_core_instr_req_i = {
  //   upper_mux_core_instr_req_i[2][2],
  //   upper_mux_core_instr_req_i[1][2],
  //   upper_mux_core_instr_req_i[0][2]
  // };

  // obi_req_t [NHARTS-1:0] tmr0_core_data_req_i;
  // obi_req_t [NHARTS-1:0] tmr1_core_data_req_i;
  // obi_req_t [NHARTS-1:0] tmr2_core_data_req_i;
  // assign tmr0_core_data_req_i = {
  //   upper_mux_core_data_req_i[2][0],
  //   upper_mux_core_data_req_i[1][0],
  //   upper_mux_core_data_req_i[0][0]
  // };
  // assign tmr1_core_data_req_i = {
  //   upper_mux_core_data_req_i[2][1],
  //   upper_mux_core_data_req_i[1][1],
  //   upper_mux_core_data_req_i[0][1]
  // };
  // assign tmr2_core_data_req_i = {
  //   upper_mux_core_data_req_i[2][2],
  //   upper_mux_core_data_req_i[1][2],
  //   upper_mux_core_data_req_i[0][2]
  // };

  //TODO: **Temporal** Gated outpout to avoid changing master until switch to single mode
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      master_core_ff_s <= 3'b001;  //default master
    end else begin
      if (sleep_s == 3'b111) master_core_ff_s <= master_core_s;
    end
  end

  // tmr_voter #(
  //     .obi_req_t            (obi_req_t  ),
  //     .obi_resp_t           (obi_resp_t )
  //     ) tmr_voter0_i (
  //     // Instruction Bus
  //     .core_instr_req_i(tmr0_core_instr_req_i),
  //     .voted_core_instr_req_o(voted_core_instr_req_o[0]),
  //     .enable_i(tmr_voter_enable_s && master_core_ff_s[0]),
  //     // Data Bus
  //     .core_data_req_i(tmr0_core_data_req_i),
  //     .voted_core_data_req_o(voted_core_data_req_o[0]),

  //     .error_o(tmr_error_s[0]),
  //     .error_id_o(tmr_errorid_s[0])
  // );
  // tmr_voter #(
  //     .obi_req_t            (obi_req_t  ),
  //     .obi_resp_t           (obi_resp_t )
  //     ) tmr_voter1_i (
  //     // Instruction Bus
  //     .core_instr_req_i(tmr1_core_instr_req_i),
  //     .voted_core_instr_req_o(voted_core_instr_req_o[1]),
  //     .enable_i(tmr_voter_enable_s && master_core_ff_s[1]),
  //     // Data Bus
  //     .core_data_req_i(tmr1_core_data_req_i),
  //     .voted_core_data_req_o(voted_core_data_req_o[1]),

  //     .error_o(tmr_error_s[1]),
  //     .error_id_o(tmr_errorid_s[1])
  // );
  // tmr_voter #(
  //     .obi_req_t            (obi_req_t  ),
  //     .obi_resp_t           (obi_resp_t )
  //     ) tmr_voter2_i (
  //     // Instruction Bus
  //     .core_instr_req_i(tmr2_core_instr_req_i),
  //     .voted_core_instr_req_o(voted_core_instr_req_o[2]),
  //     .enable_i(tmr_voter_enable_s && master_core_ff_s[2]),
  //     // Data Bus
  //     .core_data_req_i(tmr2_core_data_req_i),
  //     .voted_core_data_req_o(voted_core_data_req_o[2]),

  //     .error_o(tmr_error_s[2]),
  //     .error_id_o(tmr_errorid_s[2])
  // );

  // //******************Safety Comparator********************//
  // obi_req_t [NHARTS-1:0][1:0] dmr_core_instr_req_i;
  // obi_req_t [NHARTS-1:0][1:0] dmr_core_data_req_i;

  // obi_req_t [NHARTS-1:0][1:0] lockstep_mux_core_instr_req_i;
  // obi_req_t [NHARTS-1:0][1:0] lockstep_mux_core_data_req_i;

  // obi_req_t [NHARTS-1:0][1:0] lockstep_delayed_core_instr_req_i;
  // obi_req_t [NHARTS-1:0][1:0] lockstep_delayed_core_data_req_i;

  // always_comb begin
  //   //Masters
  //   //Comparador 0
  //   dmr_core_instr_req_i[0][0] = upper_mux_core_instr_req_i[0][0];
  //   dmr_core_data_req_i[0][0]  = upper_mux_core_data_req_i[0][0];
  //   //Comparador 1
  //   dmr_core_instr_req_i[1][0] = upper_mux_core_instr_req_i[1][1];
  //   dmr_core_data_req_i[1][0]  = upper_mux_core_data_req_i[1][1];
  //   //Comparador 2
  //   dmr_core_instr_req_i[2][0] = upper_mux_core_instr_req_i[2][2];
  //   dmr_core_data_req_i[2][0]  = upper_mux_core_data_req_i[2][2];

  //   //Slaves Mux
  //   if (dmr_config_s[1] == 1'b1) begin  //Mux Comparador 0 Mask 110
  //     dmr_core_instr_req_i[0][1] = upper_mux_core_instr_req_i[1][0];
  //     dmr_core_data_req_i[0][1]  = upper_mux_core_data_req_i[1][0];
  //   end else begin  //Mux Comparador 0 Mask 101
  //     dmr_core_instr_req_i[0][1] = upper_mux_core_instr_req_i[2][0];
  //     dmr_core_data_req_i[0][1]  = upper_mux_core_data_req_i[2][0];
  //   end

  //   if (dmr_config_s[0] == 1'b1) begin  //Mux Comparador 1 Mask 110
  //     dmr_core_instr_req_i[1][1] = upper_mux_core_instr_req_i[0][1];
  //     dmr_core_data_req_i[1][1]  = upper_mux_core_data_req_i[0][1];
  //   end else begin  //Mux Comparador 0 Mask 011
  //     dmr_core_instr_req_i[1][1] = upper_mux_core_instr_req_i[2][1];
  //     dmr_core_data_req_i[1][1]  = upper_mux_core_data_req_i[2][1];
  //   end

  //   if (dmr_config_s[1] == 1'b1) begin  //Mux Comparador 2 Mask 011
  //     dmr_core_instr_req_i[2][1] = upper_mux_core_instr_req_i[1][2];
  //     dmr_core_data_req_i[2][1]  = upper_mux_core_data_req_i[1][2];
  //   end else begin  //Mux Comparador 0 Mask 101
  //     dmr_core_instr_req_i[2][1] = upper_mux_core_instr_req_i[0][2];
  //     dmr_core_data_req_i[2][1]  = upper_mux_core_data_req_i[0][2];
  //   end
  // end

  // for (genvar i = 0; i < NHARTS; i++) begin : eros_lockstep_mux_reg
  //   always_comb begin
  //     if (delayed_s && dual_mode_s) begin
  //       lockstep_mux_core_instr_req_i[i] = lockstep_delayed_core_instr_req_i[i];
  //       lockstep_mux_core_data_req_i[i]  = lockstep_delayed_core_data_req_i[i];
  //     end else if (dual_mode_s) begin
  //       lockstep_mux_core_instr_req_i[i] = dmr_core_instr_req_i[i];
  //       lockstep_mux_core_data_req_i[i]  = dmr_core_data_req_i[i];
  //     end else begin
  //       lockstep_mux_core_instr_req_i[i] = '0;
  //       lockstep_mux_core_data_req_i[i]  = '0;
  //     end
  //   end
  // end


  for (genvar i = 0; i < NHARTS; i++) begin : eros_signals_mux_reg
    always_comb begin
      if (delayed_s && dual_mode_s) begin  // only if delayed mode
        if (master_core_ff_s[i]) begin
          core_intr_i[i] = intr[i];
          core_debug_req_i[i] = debug_req[i];
        end else if (dmr_config_s[i] && master_core_ff_s[0]) begin
          core_intr_i[i] = delayed_intr_o;
          core_debug_req_i[i] = delayed_debug_req_o;
        end else if (dmr_config_s[i] && master_core_ff_s[1]) begin
          core_intr_i[i] = delayed_intr_o;
          core_debug_req_i[i] = delayed_debug_req_o;
        end else if (dmr_config_s[i] && master_core_ff_s[2]) begin
          core_intr_i[i] = delayed_intr_o;
          core_debug_req_i[i] = delayed_debug_req_o;
        end else begin  //default nothing
          core_intr_i[i] = intr[i];
          core_debug_req_i[i] = debug_req[i];
        end
      end else begin  //Others modes
        core_intr_i[i] = intr[i];
        core_debug_req_i[i] = debug_req[i];
      end
    end
  end

  always_comb begin : eros_lockstep_input_signals_mux_reg
    if (delayed_s && dual_mode_s) begin  // only if delayed mode
      if (!master_core_ff_s[0] && dmr_config_s[0]) begin
        delayed_intr_i = intr[0];
        delayed_debug_req_i = debug_req[0];
      end else if (!master_core_ff_s[1] && dmr_config_s[1]) begin
        delayed_intr_i = intr[1];
        delayed_debug_req_i = debug_req[1];
      end else begin
        delayed_intr_i = intr[2];
        delayed_debug_req_i = debug_req[2];
      end
    end else begin
      delayed_intr_i = '0;
      delayed_debug_req_i = '0;
    end
  end


  // for (genvar i = 0; i < NRCOMPARATORS; i++) begin : eros_dmr_lockstep_
  //   lockstep_reg #(
  //       .obi_req_t            (obi_req_t  ),
  //       .obi_resp_t           (obi_resp_t ),
  //       .NCYCLES(NCYCLES)
  //   ) lockstep_reg_i (
  //       .clk_i,
  //       .rst_ni,
  //       .core_instr_req_i(dmr_core_instr_req_i[i]),
  //       .core_instr_req_o(lockstep_delayed_core_instr_req_i[i]),
  //       .core_instr_resp_i(lower_mux_core_instr_resp_i[i][1]),
  //       .core_instr_resp_o(upper_delayed_core_instr_resp_i[i]),
  //       .core_data_req_i(dmr_core_data_req_i[i]),
  //       .core_data_req_o(lockstep_delayed_core_data_req_i[i]),
  //       .core_data_resp_i(lower_mux_core_data_resp_i[i][1]),
  //       .core_data_resp_o(upper_delayed_core_data_resp_i[i]),
  //       .enable_i(delayed_s && dual_mode_s && ~dmr_wfi_s[i])
  //   );
  // end

  logic [NCYCLES-1:0]       debug_req_ff;
  logic [NCYCLES-1:0][31:0] intr_ff;
  logic                     enable_ff;

  assign delayed_intr_o = intr_ff[NCYCLES-1];
  assign delayed_debug_req_o = debug_req_ff[NCYCLES-1];
  assign enable_ff = delayed_s && dual_mode_s;

  for (genvar j = 0; j < NCYCLES; j++) begin : N_Cycles_ff
    if (j == 0) begin : gen_first

      always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ndelay
        if (~rst_ni) begin
          intr_ff[0]      <= '0;
          debug_req_ff[0] <= '0;
        end else if (enable_ff) begin
          intr_ff[0]      <= delayed_intr_i;
          debug_req_ff[0] <= delayed_debug_req_i;
        end
      end
    end else begin : gen_rest

      always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ndelay
        if (~rst_ni) begin
          intr_ff[j]      <= '0;
          debug_req_ff[j] <= '0;
        end else if (enable_ff) begin
          intr_ff[j]      <= intr_ff[j-1];
          debug_req_ff[j] <= debug_req_ff[j-1];
        end
      end
    end
  end

  // for (genvar i = 0; i < NRCOMPARATORS; i++) begin : eros_dmr_comparator

  //   dmr_comparator #(
  //       .obi_req_t            (obi_req_t  ),
  //       .obi_resp_t           (obi_resp_t )
  //   ) dmr_comparator_i (
  //       .core_instr_req_i(lockstep_mux_core_instr_req_i[i]),
  //       .compared_core_instr_req_o(compared_core_instr_req_o[i]),
  //       .core_data_req_i(lockstep_mux_core_data_req_i[i]),
  //       .compared_core_data_req_o(compared_core_data_req_o[i]),
  //       .error_o(dmr_error_s[i])
  //   );
  // end

  //*******************************************************//

  //***Private CPU Register***//

  for (genvar i = 0; i < NHARTS; i++) begin : priv_reg
    // ARCHITECTURE
    // ------------
    //                ,---- SLAVE[0] (System Bus)
    // CPUx <--> XBARx
    //                `---- SLAVE[1] (Private Register)
    //

    //***CPU xbar***//
    eros_xbar_varlat_one_to_n #(
        .obi_req_t            (obi_req_t  ),
        .obi_resp_t           (obi_resp_t ),
        .XBAR_NSLAVE  (32'd2),
        .NUM_RULES    (32'd1),
        .AGGREGATE_GNT(32'd1)                              // Not previous aggregate masters
    ) eros_xbar_varlat_one_to_n_i (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .addr_map_i(eros_pkg::CPU_XBAR_ADDR_RULES),
        .default_idx_i(1'b0),                   //in case of not known decoded address it's forwarded down to system bus
        .master_req_i(core_data_req[i]),
        .master_resp_o(core_data_resp[i]),
        .slave_req_o(xbar_core_data_req[i]),
        .slave_resp_i(xbar_core_data_resp[i])
    );

    //***OBI Slave[1] -> Private Address CPU Register***//
    periph_to_reg #(
        .req_t(reg_pkg::reg_req_t),
        .rsp_t(reg_pkg::reg_rsp_t),
        .IW(1)
    ) cpu_periph_to_reg_i (
        .clk_i,
        .rst_ni,
        .req_i(xbar_core_data_req[i][1].req),
        .add_i(xbar_core_data_req[i][1].addr),
        .wen_i(~xbar_core_data_req[i][1].we),
        .wdata_i(xbar_core_data_req[i][1].wdata),
        .be_i(xbar_core_data_req[i][1].be),
        .id_i('0),
        .gnt_o(xbar_core_data_resp[i][1].gnt),
        .r_rdata_o(xbar_core_data_resp[i][1].rdata),
        .r_opc_o(),
        .r_id_o(),
        .r_valid_o(xbar_core_data_resp[i][1].rvalid),
        .reg_req_o(cpu_reg_req[i]),
        .reg_rsp_i(cpu_reg_rsp[i])
    );

    //***CPU Private Register***//

    cpu_private_reg #(
        .reg_req_t(reg_pkg::reg_req_t),
        .reg_rsp_t(reg_pkg::reg_rsp_t)
    ) cpu_private_reg_i (
        .clk_i,
        .rst_ni,

        // Bus Interface
        .reg_req_i(cpu_reg_req[i]),
        .reg_rsp_o(cpu_reg_rsp[i]),

        .Core_id_i(Core_ID[i]),
        .Hart_intc_ack_o(Hart_intc_ack_s[i])
    );
  end
    //***Coprocessor Interconnect***//
  // if(eros_pkg::XInterface && eros_pkg::NMASTER_COPROC != 0) begin

    // //VOTER
    // tmr_voter #(
    //   .obi_req_t            (obi_req_t  ),
    //   .obi_resp_t           (obi_resp_t )
    // ) tmr_coproc_i (
    //     // Instruction Bus
    //   .core_instr_req_i({copr_req_s[0][0],copr_req_s[1][0],copr_req_s[2][0]}),
    //   .voted_core_instr_req_o(voted_copr_req_s[0]),
    //   .enable_i(tmr_voter_enable_s),
    //   // Data Bus
    //   .core_data_req_i({copr_req_s[0][1],copr_req_s[1][1],copr_req_s[2][1]}),
    //   .voted_core_data_req_o(voted_copr_req_s[1]),

    //   .error_o(),
    //   .error_id_o()
    // );
    // logic pipe0_gnt, pipe1_gnt;
    // obi_req_t   [1:0] inter_compared_copr_req_s;
    // obi_resp_t  [1:0] inter_compared_copr_resp_s;

    // //DCLS Lockstep
    // lockstep_reg #(
    //     .obi_req_t            (obi_req_t  ),
    //     .obi_resp_t           (obi_resp_t ),
    //     .NCYCLES(NCYCLES)
    // ) lockstep_accm_reg_i (
    //     .clk_i,
    //     .rst_ni,
    //     .core_instr_req_i({slave_copr_req_s[0],master_copr_req_s[0]}),
    //     .core_instr_req_o({slave_copr_req_ff_s[0],master_copr_req_ff_s[0]}),
    //     .core_instr_resp_i(inter_compared_copr_resp_s[0]),
    //     .core_instr_resp_o({slave_copr_resp_ff_s[0],master_copr_resp_ff_s[0]}),
    //     .core_data_req_i({slave_copr_req_s[1],master_copr_req_s[1]}),
    //     .core_data_req_o({slave_copr_req_ff_s[1],master_copr_req_ff_s[1]}),
    //     .core_data_resp_i(inter_compared_copr_resp_s[1]),
    //     .core_data_resp_o({slave_copr_resp_ff_s[1],master_copr_resp_ff_s[1]}),
    //     .enable_i(delayed_s && dual_mode_s)
    // );

    // assign inter_compared_copr_resp_s[0].gnt = pipe0_gnt;
    // assign inter_compared_copr_resp_s[0].rvalid = copr_resp_i[0].rvalid;
    // assign inter_compared_copr_resp_s[0].rdata = copr_resp_i[0].rdata;

    // assign inter_compared_copr_resp_s[1].gnt = pipe1_gnt;
    // assign inter_compared_copr_resp_s[1].rvalid = copr_resp_i[1].rvalid;
    // assign inter_compared_copr_resp_s[1].rdata = copr_resp_i[1].rdata;


    // obi_sngreg #(
    //     .obi_req_t            (obi_req_t  ),
    //     .obi_resp_t           (obi_resp_t )
    // )obi_sngreg0_copr_i (
    //     .clk_i,
    //     .rst_ni,
    //     .clear_pipeline       (~(delayed_s && dual_mode_s)),
    //     .core_instr_req_i     (inter_compared_copr_req_s[0]),
    //     .core_instr_req_o     (compared_copr_req_s[0]),
    //     .core_instr_resp_gnt_i(copr_resp_i[0].gnt),
    //     .core_instr_resp_gnt_o(pipe0_gnt)
    // );

    // obi_sngreg #(
    //     .obi_req_t            (obi_req_t  ),
    //     .obi_resp_t           (obi_resp_t )
    // )obi_sngreg1_copr_i (
    //     .clk_i,
    //     .rst_ni,
    //     .clear_pipeline       (~(delayed_s && dual_mode_s)),
    //     .core_instr_req_i     (inter_compared_copr_req_s[1]),
    //     .core_instr_req_o     (compared_copr_req_s[1]),
    //     .core_instr_resp_gnt_i(copr_resp_i[1].gnt),
    //     .core_instr_resp_gnt_o(pipe1_gnt)
    // );

    // //Slave
    // dmr_comparator #(
    //     .obi_req_t            (obi_req_t  ),
    //     .obi_resp_t           (obi_resp_t )
    // ) dmr_comparator_i (
    //     .core_instr_req_i({copr_dcls_master_req_s[0],copr_dcls_slave_req_s[0]}),
    //     .compared_core_instr_req_o(inter_compared_copr_req_s[0]),
    //     .core_data_req_i({copr_dcls_master_req_s[1],copr_dcls_slave_req_s[1]}),
    //     .compared_core_data_req_o(inter_compared_copr_req_s[1]),
    //     .error_o()
    // );

    // //DCLS Simple or Staggered upper
    // always_comb begin
    //   if (delayed_s && dual_mode_s) begin
    //     copr_dcls_master_req_s = master_copr_req_ff_s;
    //     copr_dcls_slave_req_s = slave_copr_req_ff_s;
    //   end else begin
    //     copr_dcls_master_req_s = master_copr_req_s;
    //     copr_dcls_slave_req_s =  slave_copr_req_s;
    //   end
    // end
    // //Shadow Selection upper
    // always_comb begin
    //   if(!master_core_ff_s[0] && dmr_config_s[0]) begin
    //     slave_copr_req_s[0] = copr_req_s[0][0];
    //     slave_copr_req_s[1] = copr_req_s[0][1];
    //   end else if(!master_core_ff_s[1]&& dmr_config_s[1]) begin
    //     slave_copr_req_s[0] = copr_req_s[1][0];
    //     slave_copr_req_s[1] = copr_req_s[1][1];
    //   end else if(!master_core_ff_s[2]&& dmr_config_s[2]) begin
    //     slave_copr_req_s[0] = copr_req_s[2][0];
    //     slave_copr_req_s[1] = copr_req_s[2][1];
    //   end else begin
    //     slave_copr_req_s[0] = copr_req_s[2][0];
    //     slave_copr_req_s[1] = copr_req_s[2][1];
    //   end
    // end
    // //Single Master upper
    // always_comb begin
    //   if(master_core_ff_s[0]) begin
    //     master_copr_req_s[0] = copr_req_s[0][0];
    //     master_copr_req_s[1] = copr_req_s[0][1];
    //   end else if(master_core_ff_s[1]) begin
    //     master_copr_req_s[0] = copr_req_s[1][0];
    //     master_copr_req_s[1] = copr_req_s[1][1];
    //   end else if(master_core_ff_s[2]) begin
    //     master_copr_req_s[0] = copr_req_s[2][0];
    //     master_copr_req_s[1] = copr_req_s[2][1];
    //   end else begin
    //     master_copr_req_s[0] = copr_req_s[2][0];
    //     master_copr_req_s[1] = copr_req_s[2][1];
    //   end
    // end

    // // Final Mux Selection
    // always_comb begin
    //   if (tmr_voter_enable_s && !dual_mode_s) begin
    //     copr_req_o = voted_copr_req_s;
    //   end else if (!tmr_voter_enable_s && dual_mode_s) begin
    //     copr_req_o = compared_copr_req_s;
    //   end else begin
    //     copr_req_o = master_copr_req_s;
    //   end
    // end

    // //Resp Mux
    // always_comb begin
    //   if (dual_mode_s) begin
    //     if (delayed_s) begin
    //       if(master_core_ff_s[0]) begin
    //         copr_resp_s[0] = master_copr_resp_ff_s;

    //           if ((!master_core_ff_s[1]&& dmr_config_s[1])) begin
    //             copr_resp_s[1] = slave_copr_resp_ff_s;
    //             copr_resp_s[2] = '0;
    //           end else begin
    //             copr_resp_s[1] = '0;
    //             copr_resp_s[2] = slave_copr_resp_ff_s;
    //           end;
    //       end else if(master_core_ff_s[1]) begin
    //         copr_resp_s[1] = master_copr_resp_ff_s;
    //           if ((!master_core_ff_s[0]&& dmr_config_s[0])) begin
    //             copr_resp_s[0] = slave_copr_resp_ff_s;
    //             copr_resp_s[2] = '0;
    //           end else begin
    //             copr_resp_s[0] = '0;
    //             copr_resp_s[2] = slave_copr_resp_ff_s;
    //           end;
    //       end else if(master_core_ff_s[2]) begin
    //         copr_resp_s[2] = master_copr_resp_ff_s;
    //           if ((!master_core_ff_s[0]&& dmr_config_s[0])) begin
    //             copr_resp_s[0] = slave_copr_resp_ff_s;
    //             copr_resp_s[1] = '0;
    //           end else begin
    //             copr_resp_s[0] = '0;
    //             copr_resp_s[1] = slave_copr_resp_ff_s;
    //           end;
    //       end else begin
    //         copr_resp_s[2] = master_copr_resp_ff_s;
    //           if ((!master_core_ff_s[0]&& dmr_config_s[0])) begin
    //             copr_resp_s[0] = slave_copr_resp_ff_s;
    //             copr_resp_s[1] = '0;
    //           end else begin
    //             copr_resp_s[0] = '0;
    //             copr_resp_s[1] = slave_copr_resp_ff_s;
    //           end;
    //       end
    //     end else begin
    //       if(master_core_ff_s[0]) begin
    //         copr_resp_s[0] = copr_resp_i;
    //           if ((!master_core_ff_s[1]&& dmr_config_s[1])) begin
    //             copr_resp_s[1] = copr_resp_i;
    //             copr_resp_s[2] = '0;
    //           end else begin
    //             copr_resp_s[1] = '0;
    //             copr_resp_s[2] = copr_resp_i;
    //           end;
    //       end else if(master_core_ff_s[1]) begin
    //         copr_resp_s[1] = copr_resp_i;
    //           if ((!master_core_ff_s[0]&& dmr_config_s[0])) begin
    //             copr_resp_s[0] = copr_resp_i;
    //             copr_resp_s[2] = '0;
    //           end else begin
    //             copr_resp_s[0] = '0;
    //             copr_resp_s[2] = copr_resp_i;
    //           end;
    //       end else if(master_core_ff_s[2]) begin
    //         copr_resp_s[2] = copr_resp_i;
    //           if ((!master_core_ff_s[0]&& dmr_config_s[0])) begin
    //             copr_resp_s[0] = copr_resp_i;
    //             copr_resp_s[1] = '0;
    //           end else begin
    //             copr_resp_s[0] = '0;
    //             copr_resp_s[1] = copr_resp_i;
    //           end;
    //       end else begin
    //         copr_resp_s[2] = copr_resp_i;
    //           if ((!master_core_ff_s[0]&& dmr_config_s[0])) begin
    //             copr_resp_s[0] = copr_resp_i;
    //             copr_resp_s[1] = '0;
    //           end else begin
    //             copr_resp_s[0] = '0;
    //             copr_resp_s[1] = copr_resp_i;
    //           end;
    //       end
    //     end
    //   end else if (tmr_voter_enable_s && !dual_mode_s) begin
    //     copr_resp_s[0] = copr_resp_i;
    //     copr_resp_s[1] = copr_resp_i;
    //     copr_resp_s[2] = copr_resp_i;
    //   end else begin
    //     if ((master_core_ff_s[0])) begin
    //     copr_resp_s[0] = copr_resp_i;
    //     copr_resp_s[1] = '0;
    //     copr_resp_s[2] = '0;
    //     end else if ((master_core_ff_s[1])) begin
    //     copr_resp_s[0] = '0;
    //     copr_resp_s[1] = copr_resp_i;
    //     copr_resp_s[2] = '0;
    //     end else if ((master_core_ff_s[2])) begin
    //     copr_resp_s[0] = '0;
    //     copr_resp_s[1] = '0;
    //     copr_resp_s[2] = copr_resp_i;
    //     end else begin
    //     copr_resp_s[0] = copr_resp_i;
    //     copr_resp_s[1] = '0;
    //     copr_resp_s[2] = '0;
    //     end
    //     end
    // end
  //   assign copr_req_o
  //   assign
  // end else begin
  //   assign copr_req_o = '0;
  //   assign copr_resp_s = '0;

  // end

endmodule

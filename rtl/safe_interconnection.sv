module safe_interconnection
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

    // Input
    input   obi_req_t  [NHARTS-1 : 0] core_instr_req_i,
    output  obi_resp_t [NHARTS-1 : 0] core_instr_resp_o,

    // Output
    output obi_req_t  [NHARTS-1 : 0] core_instr_req_o,
    input  obi_resp_t [NHARTS-1 : 0] core_instr_resp_i,

    // Data memory interface

    // Input
    input obi_req_t    [NHARTS-1 : 0] core_data_req_i,
    output  obi_resp_t [NHARTS-1 : 0] core_data_resp_o,

    // Output
    output obi_req_t  [NHARTS-1 : 0] core_data_req_o,
    input  obi_resp_t [NHARTS-1 : 0] core_data_resp_i,

    // Coproc Interface

    // Input
    input   obi_req_t    [NHARTS-1:0][NMASTER_COPROC_RND-1 : 0] coproc_req_i,
    output  obi_resp_t [NHARTS-1:0][NMASTER_COPROC_RND-1 : 0] coproc_resp_o,

    // // Output
    output obi_req_t  [NMASTER_COPROC_RND-1 : 0] coproc_req_o,
    input  obi_resp_t [NMASTER_COPROC_RND-1 : 0] coproc_resp_i,

    // Control Status Signals

    input logic dcls_mode_i,
    input logic staggered_mode_i,
    input logic [NHARTS-1 : 0] dcls_config_i,
    input logic [NHARTS-1 : 0] dcls_wfi_i,
    output logic [NHARTS-1 : 0] comparator_error_o,

    input logic tcls_mode_i,
    output logic voter_error_o,
    output logic [NHARTS-1:0] voter_id_error_o,
    input logic [NHARTS-1 : 0] master_core_i
);

  //TODO: Future template 2 or 3 HARTS
  localparam NRCOMPARATORS = NHARTS == 3 ? 3 : 1;

  // Voted_CPU Signals
  obi_req_t [NHARTS-1:0] voted_core_instr_req;
  obi_req_t [NHARTS-1:0] voted_core_data_req;

  // Voter Signals
  logic [NHARTS-1:0] voter_error_s;
  logic [NHARTS-1:0] [NHARTS-1:0] voter_id_error_s;
  logic copr_voter_error_s;
  logic [NHARTS-1:0] copr_voter_id_error_s;

  // Compared CPU Signals
  obi_req_t [NHARTS-1:0] compared_core_instr_req;
  obi_req_t [NHARTS-1:0] compared_core_data_req;

  // Comparator Signals
  logic [NHARTS-1:0] comparator_error_s;
  logic copr_comparator_error_s;


  //Isolate Bus
  obi_resp_t [NHARTS-1 : 0] isolate_core_instr_resp;
  obi_resp_t [NHARTS-1 : 0] isolate_core_data_resp;



  /**************************Upper-Demux-Req**********************************/
  //upper
  obi_req_t [NHARTS-1:0][NHARTS-1:0] upper_mux_core_instr_req_i;
  obi_req_t [NHARTS-1:0][NHARTS-1:0] upper_mux_core_data_req_i;

  obi_resp_t [NHARTS-1:0][1:0] upper_delayed_core_instr_resp_i;
  obi_resp_t [NHARTS-1:0][1:0] upper_delayed_core_data_resp_i;

  //lower
  obi_resp_t [NHARTS-1:0][1:0] lower_mux_core_instr_resp_i;
  obi_resp_t [NHARTS-1:0][1:0] lower_mux_core_data_resp_i;

  for (genvar i = 0; i < NHARTS; i++) begin : eros_upper_demux
    always_comb begin
      if (master_core_i[2] && (dcls_mode_i || tcls_mode_i)) begin
        upper_mux_core_instr_req_i[i][0] = '0;
        upper_mux_core_instr_req_i[i][1] = '0;
        upper_mux_core_instr_req_i[i][2] = core_instr_req_i[i];

        upper_mux_core_data_req_i[i][0]  = '0;
        upper_mux_core_data_req_i[i][1]  = '0;
        upper_mux_core_data_req_i[i][2]  = core_data_req_i[i];
      end else if (master_core_i[1] && (dcls_mode_i || tcls_mode_i)) begin
        upper_mux_core_instr_req_i[i][0] = '0;
        upper_mux_core_instr_req_i[i][1] = core_instr_req_i[i];
        upper_mux_core_instr_req_i[i][2] = '0;

        upper_mux_core_data_req_i[i][0]  = '0;
        upper_mux_core_data_req_i[i][1]  = core_data_req_i[i];
        upper_mux_core_data_req_i[i][2]  = '0;
      end else if (master_core_i[0] && (dcls_mode_i || tcls_mode_i)) begin
        upper_mux_core_instr_req_i[i][0] = core_instr_req_i[i];
        upper_mux_core_instr_req_i[i][1] = '0;
        upper_mux_core_instr_req_i[i][2] = '0;

        upper_mux_core_data_req_i[i][0]  = core_data_req_i[i];
        upper_mux_core_data_req_i[i][1]  = '0;
        upper_mux_core_data_req_i[i][2]  = '0;
      end else begin  // default case when not a master and the core has to use its bus
        if (i == 0) begin
          upper_mux_core_instr_req_i[i][0] = core_instr_req_i[i];
          upper_mux_core_instr_req_i[i][1] = '0;
          upper_mux_core_instr_req_i[i][2] = '0;

          upper_mux_core_data_req_i[i][0]  = core_data_req_i[i];
          upper_mux_core_data_req_i[i][1]  = '0;
          upper_mux_core_data_req_i[i][2]  = '0;
        end else if (i == 1) begin
          upper_mux_core_instr_req_i[i][0] = '0;
          upper_mux_core_instr_req_i[i][1] = core_instr_req_i[i];
          upper_mux_core_instr_req_i[i][2] = '0;

          upper_mux_core_data_req_i[i][0]  = '0;
          upper_mux_core_data_req_i[i][1]  = core_data_req_i[i];
          upper_mux_core_data_req_i[i][2]  = '0;
        end else begin
          upper_mux_core_instr_req_i[i][0] = '0;
          upper_mux_core_instr_req_i[i][1] = '0;
          upper_mux_core_instr_req_i[i][2] = core_instr_req_i[i];

          upper_mux_core_data_req_i[i][0]  = '0;
          upper_mux_core_data_req_i[i][1]  = '0;
          upper_mux_core_data_req_i[i][2]  = core_data_req_i[i];
        end
      end
    end
  end

  /**************************************************************************/

  /**************************Lower-Mux-Req**********************************/
  for (genvar i = 0; i < NHARTS; i++) begin : eros_lower_mux_obi_req

    always_comb begin
      //TODO: Reduce de mux configurations inputs ports, implies modification in the Safe_FSM
      if (master_core_i[i] && tcls_mode_i && !dcls_mode_i) begin
        core_instr_req_o[i] = voted_core_instr_req[i];
        core_data_req_o[i]  = voted_core_data_req[i];
      end else if (master_core_i[i] && !tcls_mode_i && dcls_mode_i) begin
        core_instr_req_o[i] = compared_core_instr_req[i];
        core_data_req_o[i]  = compared_core_data_req[i];
      end else begin //Todo: Put here in the future the posibility to wake up the third core in case of a hang in DCLS mode.
        core_instr_req_o[i] = upper_mux_core_instr_req_i[i][i];
        core_data_req_o[i]  = upper_mux_core_data_req_i[i][i];
      end
    end
  end

  /**************************************************************************/
  /**************************Lower-Demux-Resp********************************/
  for (genvar i = 0; i < NHARTS; i++) begin : eros_lower_mux_obi_resp
    always_comb begin
      if (staggered_mode_i & dcls_mode_i) begin  //TODO: should not be necesary use de dcls_mode_i
        lower_mux_core_instr_resp_i[i][0] = '0;
        lower_mux_core_instr_resp_i[i][1] = core_instr_resp_i[i];

        lower_mux_core_data_resp_i[i][0]  = '0;
        lower_mux_core_data_resp_i[i][1]  = core_data_resp_i[i];
      end else begin
        lower_mux_core_instr_resp_i[i][0] = core_instr_resp_i[i];
        lower_mux_core_instr_resp_i[i][1] = '0;

        lower_mux_core_data_resp_i[i][0]  = core_data_resp_i[i];
        lower_mux_core_data_resp_i[i][1]  = '0;
      end
    end
  end

  /************************************************************************/
  /**************************Upper-Mux-Resp********************************/
  for (genvar i = 0; i < NHARTS; i++) begin : eros_upper_mux_obi_resp
    always_comb begin
      if (dcls_wfi_i[i] == '1) begin
        core_instr_resp_o[i] = isolate_core_instr_resp[i];
        core_data_resp_o[i] = isolate_core_data_resp[i];
      end else if (master_core_i[0] && !staggered_mode_i && (tcls_mode_i || (dcls_mode_i && dcls_config_i[i]))) begin
        core_instr_resp_o[i] = lower_mux_core_instr_resp_i[0][0];
        core_data_resp_o[i] = lower_mux_core_data_resp_i[0][0];
      end else if (master_core_i[1] && !staggered_mode_i && (tcls_mode_i || (dcls_mode_i && dcls_config_i[i]))) begin
        core_instr_resp_o[i] = lower_mux_core_instr_resp_i[1][0];
        core_data_resp_o[i] = lower_mux_core_data_resp_i[1][0];
      end else if (master_core_i[2] && !staggered_mode_i && (tcls_mode_i || (dcls_mode_i && dcls_config_i[i]))) begin
        core_instr_resp_o[i] = lower_mux_core_instr_resp_i[2][0];
        core_data_resp_o[i] = lower_mux_core_data_resp_i[2][0];
        //delayed
      end else if (master_core_i[i] && dcls_mode_i && staggered_mode_i) begin //if master of DCLS connect to the second core
        core_instr_resp_o[i] = upper_delayed_core_instr_resp_i[i][0];
        core_data_resp_o[i] = upper_delayed_core_data_resp_i[i][0];
      end else if (!master_core_i[i] && dcls_mode_i && staggered_mode_i && dcls_config_i[i])  begin //if not master of DCLS connect to the second core
        if (master_core_i[0]) begin
          core_instr_resp_o[i] = upper_delayed_core_instr_resp_i[0][1];
          core_data_resp_o[i] = upper_delayed_core_data_resp_i[0][1];
        end else if (master_core_i[1]) begin
          core_instr_resp_o[i] = upper_delayed_core_instr_resp_i[1][1];
          core_data_resp_o[i] = upper_delayed_core_data_resp_i[1][1];
        end else begin
          core_instr_resp_o[i] = upper_delayed_core_instr_resp_i[2][1];
          core_data_resp_o[i] = upper_delayed_core_data_resp_i[2][1];
        end
        //default
      end else begin
        core_instr_resp_o[i] = lower_mux_core_instr_resp_i[i][0];
        core_data_resp_o[i] = lower_mux_core_data_resp_i[i][0];
      end
    end
  end
  /*********************************************************************/
  /*********************************************************************/

  /************************Isolate BUS**********************************/
  // logic [NHARTS-1:0] instr_isolate_valid_q;
  // logic [NHARTS-1:0] instr_expected_rvalid;
  // for (genvar i = 0; i < NHARTS; i++) begin : isolate_obi_bus_instr

  //   always_ff @(posedge clk_i or negedge rst_ni) begin
  //     if (!rst_ni) begin
  //       instr_isolate_valid_q[i] <= '0;
  //       instr_expected_rvalid[i] <= '0;
  //     end else begin
  //       if (dcls_wfi_i[i] == 1'b0) begin  //clear
  //         instr_isolate_valid_q[i] <= '0;
  //         //if req & gnt before wfi halt, it needs a rvalid ack otherwise could stall waiting that read/write request.
  //         instr_expected_rvalid[i] <= (core_instr_req_i[i].req & core_instr_resp_o[i].gnt) | (instr_expected_rvalid[i] & ~core_instr_resp_o[i].rvalid);
  //       end else begin
  //         instr_isolate_valid_q[i] <= isolate_core_instr_resp[i].gnt;
  //         instr_expected_rvalid[i] <= '0;
  //       end
  //     end
  //   end
  //   assign isolate_core_instr_resp[i].gnt = core_instr_req_i[i].req;
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
  //       if (dcls_wfi_i[i] == 1'b0) begin  //clear
  //         data_isolate_valid_q[i] <= '0;
  //         //if req & gnt before wfi halt, it needs a rvalid ack otherwise could stall waiting that read/write request.
  //         data_expected_rvalid[i] <= core_data_req_i[i].req & core_data_resp_o[i].gnt | (data_expected_rvalid[i] & ~core_data_resp_o[i].rvalid);
  //       end else begin
  //         data_isolate_valid_q[i] <= isolate_core_data_resp[i].gnt;
  //         data_expected_rvalid[i] <= '0;
  //       end
  //     end
  //   end
  //   assign isolate_core_data_resp[i].gnt = core_data_req_i[i].req;
  //   assign isolate_core_data_resp[i].rvalid = data_isolate_valid_q[i] | data_expected_rvalid[i];
  //   assign isolate_core_data_resp[i].rdata = 32'h0;  //0 data val
  // end

  /************************Isolate Bus**********************************/
  for (genvar i = 0; i < NHARTS; i++) begin : isolate_obi_bus_instr
    obi_isolate #(
        .obi_req_t            (obi_req_t  ),
        .obi_resp_t           (obi_resp_t ),
        .ISOLATE_VAL          (32'h10500073)
    ) obi_isolate (
      .clk_i,
      .rst_ni,
      .dcls_wfi_i(dcls_wfi_i[i]),

      .obi_req_i(core_instr_req_i[i]),
      .obi_resp_i(core_instr_resp_o[i]),
      .obi_isolate_o(isolate_core_instr_resp[i])
    );
  end

  for (genvar i = 0; i < NHARTS; i++) begin : isolate_obi_bus_data
    obi_isolate #(
        .obi_req_t            (obi_req_t  ),
        .obi_resp_t           (obi_resp_t ),
        .ISOLATE_VAL          (32'h0)
    ) obi_isolate (
      .clk_i,
      .rst_ni,
      .dcls_wfi_i(dcls_wfi_i[i]),

      .obi_req_i(core_data_req_i[i]),
      .obi_resp_i(core_data_resp_o[i]),
      .obi_isolate_o(isolate_core_data_resp[i])
    );
  end


  /*********************************************************/
  //*********************Safety Voter***********************//
  obi_req_t [NHARTS-1:0] tmr0_core_instr_req_i;
  obi_req_t [NHARTS-1:0] tmr1_core_instr_req_i;
  obi_req_t [NHARTS-1:0] tmr2_core_instr_req_i;

  assign tmr0_core_instr_req_i = {
    upper_mux_core_instr_req_i[2][0],
    upper_mux_core_instr_req_i[1][0],
    upper_mux_core_instr_req_i[0][0]
  };
  assign tmr1_core_instr_req_i = {
    upper_mux_core_instr_req_i[2][1],
    upper_mux_core_instr_req_i[1][1],
    upper_mux_core_instr_req_i[0][1]
  };
  assign tmr2_core_instr_req_i = {
    upper_mux_core_instr_req_i[2][2],
    upper_mux_core_instr_req_i[1][2],
    upper_mux_core_instr_req_i[0][2]
  };

  obi_req_t [NHARTS-1:0] tmr0_core_data_req_i;
  obi_req_t [NHARTS-1:0] tmr1_core_data_req_i;
  obi_req_t [NHARTS-1:0] tmr2_core_data_req_i;

  assign tmr0_core_data_req_i = {
    upper_mux_core_data_req_i[2][0],
    upper_mux_core_data_req_i[1][0],
    upper_mux_core_data_req_i[0][0]
  };
  assign tmr1_core_data_req_i = {
    upper_mux_core_data_req_i[2][1],
    upper_mux_core_data_req_i[1][1],
    upper_mux_core_data_req_i[0][1]
  };
  assign tmr2_core_data_req_i = {
    upper_mux_core_data_req_i[2][2],
    upper_mux_core_data_req_i[1][2],
    upper_mux_core_data_req_i[0][2]
  };

  tmr_voter #(
      .obi_req_t            (obi_req_t  ),
      .obi_resp_t           (obi_resp_t )
      ) tmr_voter0_i (
      // Instruction Bus
      .core_instr_req_i(tmr0_core_instr_req_i),
      .voted_core_instr_req_o(voted_core_instr_req[0]),
      .enable_i(tcls_mode_i && master_core_i[0]),
      // Data Bus
      .core_data_req_i(tmr0_core_data_req_i),
      .voted_core_data_req_o(voted_core_data_req[0]),

      .error_o(voter_error_s[0]),
      .error_id_o(voter_id_error_s[0])
  );
  tmr_voter #(
      .obi_req_t            (obi_req_t  ),
      .obi_resp_t           (obi_resp_t )
      ) tmr_voter1_i (
      // Instruction Bus
      .core_instr_req_i(tmr1_core_instr_req_i),
      .voted_core_instr_req_o(voted_core_instr_req[1]),
      .enable_i(tcls_mode_i && master_core_i[1]),
      // Data Bus
      .core_data_req_i(tmr1_core_data_req_i),
      .voted_core_data_req_o(voted_core_data_req[1]),

      .error_o(voter_error_s[1]),
      .error_id_o(voter_id_error_s[1])
  );
  tmr_voter #(
      .obi_req_t            (obi_req_t  ),
      .obi_resp_t           (obi_resp_t )
      ) tmr_voter2_i (
      // Instruction Bus
      .core_instr_req_i(tmr2_core_instr_req_i),
      .voted_core_instr_req_o(voted_core_instr_req[2]),
      .enable_i(tcls_mode_i && master_core_i[2]),
      // Data Bus
      .core_data_req_i(tmr2_core_data_req_i),
      .voted_core_data_req_o(voted_core_data_req[2]),

      .error_o(voter_error_s[2]),
      .error_id_o(voter_id_error_s[2])
  );

  assign voter_error_o = voter_error_s[0] | voter_error_s[1] | voter_error_s[2] | copr_voter_error_s;
  assign voter_id_error_o = voter_id_error_s[0] | voter_id_error_s[1] | voter_id_error_s[2] | copr_voter_id_error_s;

  /*********************************************************/
  //******************Safety Comparator********************//
  obi_req_t [NHARTS-1:0][1:0] dmr_core_instr_req_i;
  obi_req_t [NHARTS-1:0][1:0] dmr_core_data_req_i;

  obi_req_t [NHARTS-1:0][1:0] lockstep_mux_core_instr_req_i;
  obi_req_t [NHARTS-1:0][1:0] lockstep_mux_core_data_req_i;

  obi_req_t [NHARTS-1:0][1:0] lockstep_delayed_core_instr_req_i;
  obi_req_t [NHARTS-1:0][1:0] lockstep_delayed_core_data_req_i;

  always_comb begin
    //Masters
    //Comparador 0
    dmr_core_instr_req_i[0][0] = upper_mux_core_instr_req_i[0][0];
    dmr_core_data_req_i[0][0]  = upper_mux_core_data_req_i[0][0];
    //Comparador 1
    dmr_core_instr_req_i[1][0] = upper_mux_core_instr_req_i[1][1];
    dmr_core_data_req_i[1][0]  = upper_mux_core_data_req_i[1][1];
    //Comparador 2
    dmr_core_instr_req_i[2][0] = upper_mux_core_instr_req_i[2][2];
    dmr_core_data_req_i[2][0]  = upper_mux_core_data_req_i[2][2];

    //Slaves Mux
    if (dcls_config_i[1] == 1'b1) begin  //Mux Comparador 0 Mask 110
      dmr_core_instr_req_i[0][1] = upper_mux_core_instr_req_i[1][0];
      dmr_core_data_req_i[0][1]  = upper_mux_core_data_req_i[1][0];
    end else begin  //Mux Comparador 0 Mask 101
      dmr_core_instr_req_i[0][1] = upper_mux_core_instr_req_i[2][0];
      dmr_core_data_req_i[0][1]  = upper_mux_core_data_req_i[2][0];
    end

    if (dcls_config_i[0] == 1'b1) begin  //Mux Comparador 1 Mask 110
      dmr_core_instr_req_i[1][1] = upper_mux_core_instr_req_i[0][1];
      dmr_core_data_req_i[1][1]  = upper_mux_core_data_req_i[0][1];
    end else begin  //Mux Comparador 0 Mask 011
      dmr_core_instr_req_i[1][1] = upper_mux_core_instr_req_i[2][1];
      dmr_core_data_req_i[1][1]  = upper_mux_core_data_req_i[2][1];
    end

    if (dcls_config_i[1] == 1'b1) begin  //Mux Comparador 2 Mask 011
      dmr_core_instr_req_i[2][1] = upper_mux_core_instr_req_i[1][2];
      dmr_core_data_req_i[2][1]  = upper_mux_core_data_req_i[1][2];
    end else begin  //Mux Comparador 0 Mask 101
      dmr_core_instr_req_i[2][1] = upper_mux_core_instr_req_i[0][2];
      dmr_core_data_req_i[2][1]  = upper_mux_core_data_req_i[0][2];
    end
  end

  for (genvar i = 0; i < NHARTS; i++) begin : eros_lockstep_mux_reg
    always_comb begin
      if (staggered_mode_i && dcls_mode_i) begin
        lockstep_mux_core_instr_req_i[i] = lockstep_delayed_core_instr_req_i[i];
        lockstep_mux_core_data_req_i[i]  = lockstep_delayed_core_data_req_i[i];
      end else if (dcls_mode_i) begin
        lockstep_mux_core_instr_req_i[i] = dmr_core_instr_req_i[i];
        lockstep_mux_core_data_req_i[i]  = dmr_core_data_req_i[i];
      end else begin
        lockstep_mux_core_instr_req_i[i] = '0;
        lockstep_mux_core_data_req_i[i]  = '0;
      end
    end
  end

  for (genvar i = 0; i < NRCOMPARATORS; i++) begin : eros_dmr_lockstep_
    lockstep_reg #(
        .obi_req_t            (obi_req_t  ),
        .obi_resp_t           (obi_resp_t ),
        .NCYCLES(NCYCLES)
    ) lockstep_reg_i (
        .clk_i,
        .rst_ni,
        .core_instr_req_i(dmr_core_instr_req_i[i]),
        .core_instr_req_o(lockstep_delayed_core_instr_req_i[i]),
        .core_instr_resp_i(lower_mux_core_instr_resp_i[i][1]),
        .core_instr_resp_o(upper_delayed_core_instr_resp_i[i]),
        .core_data_req_i(dmr_core_data_req_i[i]),
        .core_data_req_o(lockstep_delayed_core_data_req_i[i]),
        .core_data_resp_i(lower_mux_core_data_resp_i[i][1]),
        .core_data_resp_o(upper_delayed_core_data_resp_i[i]),
        .enable_i(staggered_mode_i && dcls_mode_i && ~dcls_wfi_i[i])
    );
  end

  for (genvar i = 0; i < NRCOMPARATORS; i++) begin : eros_dmr_comparator

    dmr_comparator #(
        .obi_req_t            (obi_req_t  ),
        .obi_resp_t           (obi_resp_t )
    ) dmr_comparator_i (
        .core_instr_req_i(lockstep_mux_core_instr_req_i[i]),
        .compared_core_instr_req_o(compared_core_instr_req[i]),
        .core_data_req_i(lockstep_mux_core_data_req_i[i]),
        .compared_core_data_req_o(compared_core_data_req[i]),
        .error_o(comparator_error_s[i])
    );
  end

  assign comparator_error_o = comparator_error_s | copr_comparator_error_s;

  //********************************************************//
  //**********************Coprocessor***********************//
  //**********************Interconnect**********************//
  if(eros_pkg::XInterface && eros_pkg::NMASTER_COPROC != 0) begin : eros_copr_interconnect_gen


    obi_req_t [NMASTER_COPROC_RND-1:0] copr_dcls_master_req_s;
    obi_resp_t [NMASTER_COPROC_RND-1:0] copr_dcls_master_resp_s;

    obi_req_t [NMASTER_COPROC_RND-1:0] copr_dcls_slave_req_s;
    obi_resp_t [NMASTER_COPROC_RND-1:0] copr_dcls_slave_resp_s;

    obi_req_t   [NMASTER_COPROC_RND-1:0] voted_copr_req_s;
    obi_resp_t  [NMASTER_COPROC_RND-1:0] voted_copr_resp_s;

    obi_req_t   [NMASTER_COPROC_RND-1:0] compared_copr_req_s;
    obi_resp_t  [NMASTER_COPROC_RND-1:0] compared_copr_resp_s;

    obi_req_t   [NMASTER_COPROC_RND-1:0] master_copr_req_s;
    obi_resp_t  [NMASTER_COPROC_RND-1:0] master_copr_resp_s;

    obi_req_t   [NMASTER_COPROC_RND-1:0] slave_copr_req_s;
    obi_resp_t  [NMASTER_COPROC_RND-1:0] slave_copr_resp_s;

    obi_req_t   [NMASTER_COPROC_RND-1:0] master_copr_req_ff_s;
    obi_resp_t  [NMASTER_COPROC_RND-1:0] master_copr_resp_ff_s;

    obi_req_t   [NMASTER_COPROC_RND-1:0] slave_copr_req_ff_s;
    obi_resp_t  [NMASTER_COPROC_RND-1:0] slave_copr_resp_ff_s;

    obi_req_t  [NHARTS-1 : 0] core_data_interconnect_req;
    obi_resp_t [NHARTS-1 : 0] core_data_interconnect_resp;

    logic [NMASTER_COPROC_RND-1:0] copr_voter_error;
    logic [NMASTER_COPROC_RND-1:0] [NHARTS-1:0] copr_voter_id_error;
    logic [NMASTER_COPROC_RND-1:0] copr_comparator_error;

    obi_resp_t [NMASTER_COPROC_RND-1 : 0] isolate_coproc_resp;

    logic dcls_wfi_coproc;

    assign dcls_wfi_coproc = | dcls_wfi_i;

    //Master selection upper
    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : eros_copr_master_upper
      always_comb begin
        if(master_core_i[0]) begin
          master_copr_req_s[i] = coproc_req_i[0][i];
        end else if(master_core_i[1]) begin
          master_copr_req_s[i] = coproc_req_i[1][i];
        end else if(master_core_i[2]) begin
          master_copr_req_s[i] = coproc_req_i[2][i];
        end else begin
          master_copr_req_s[i] = coproc_req_i[2][i];
        end
      end
    end

    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : eros_copr_shadow_upper
      always_comb begin
        if(!master_core_i[0] && dcls_config_i[0]) begin
          slave_copr_req_s[i] = coproc_req_i[0][i];
        end else if(!master_core_i[1] && dcls_config_i[1]) begin
          slave_copr_req_s[i] = coproc_req_i[1][i];
        end else if(!master_core_i[2] && dcls_config_i[2]) begin
          slave_copr_req_s[i] = coproc_req_i[2][i];
        end else begin
          slave_copr_req_s[i] = coproc_req_i[2][i];
        end
      end
    end

    // DCLS or Staggered selection
    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : eros_copr_dcls_selection_upper
      always_comb begin
        if (staggered_mode_i && dcls_mode_i) begin
          copr_dcls_master_req_s[i] = master_copr_req_ff_s[i];
          copr_dcls_slave_req_s[i] = slave_copr_req_ff_s[i];
        end else begin
          copr_dcls_master_req_s[i] = master_copr_req_s[i];
          copr_dcls_slave_req_s[i] =  slave_copr_req_s[i];
        end
      end
    end

    // Final Mux Selection
    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : eros_copr_mux_selection
      always_comb begin
        if (tcls_mode_i && !dcls_mode_i) begin
          coproc_req_o[i] = voted_copr_req_s[i];
        end else if (!tcls_mode_i && dcls_mode_i) begin
          coproc_req_o[i] = compared_copr_req_s[i];
        end else begin
          coproc_req_o[i] = master_copr_req_s[i];
        end
      end
    end

    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : eros_copr_resp_selection
      always_comb begin
        if (dcls_mode_i) begin
          if (dcls_wfi_coproc) begin
            coproc_resp_o[0][i] = isolate_coproc_resp[i];
            coproc_resp_o[1][i] = isolate_coproc_resp[i];
            coproc_resp_o[2][i] = isolate_coproc_resp[i];
          end else if (staggered_mode_i) begin // DCLS Staggered
            if(master_core_i[0]) begin
              coproc_resp_o[0][i] = master_copr_resp_ff_s[i];

                if ((!master_core_i[1] && dcls_config_i[1])) begin
                  coproc_resp_o[1][i] = slave_copr_resp_ff_s[i];
                  coproc_resp_o[2][i] = '0;
                end else begin
                  coproc_resp_o[1][i] = '0;
                  coproc_resp_o[2][i] = slave_copr_resp_ff_s[i];
                end;
            end else if(master_core_i[1]) begin
              coproc_resp_o[1][i] = master_copr_resp_ff_s[i];
                if ((!master_core_i[0] && dcls_config_i[0])) begin
                  coproc_resp_o[0][i] = slave_copr_resp_ff_s[i];
                  coproc_resp_o[2][i] = '0;
                end else begin
                  coproc_resp_o[0][i] = '0;
                  coproc_resp_o[2][i] = slave_copr_resp_ff_s[i];
                end;
            end else if(master_core_i[2]) begin
              coproc_resp_o[2][i] = master_copr_resp_ff_s[i];
                if ((!master_core_i[0] && dcls_config_i[0])) begin
                  coproc_resp_o[0][i] = slave_copr_resp_ff_s[i];
                  coproc_resp_o[1][i] = '0;
                end else begin
                  coproc_resp_o[0][i] = '0;
                  coproc_resp_o[1][i] = slave_copr_resp_ff_s[i];
                end;
            end else begin
              coproc_resp_o[2][i] = master_copr_resp_ff_s[i];
                if ((!master_core_i[0] && dcls_config_i[0])) begin
                  coproc_resp_o[0][i] = slave_copr_resp_ff_s[i];
                  coproc_resp_o[1][i] = '0;
                end else begin
                  coproc_resp_o[0][i] = '0;
                  coproc_resp_o[1][i] = slave_copr_resp_ff_s[i];
                end;
            end
          end else begin  // DCLS
            if(master_core_i[0]) begin
              coproc_resp_o[0][i] = coproc_resp_i[i];
                if ((!master_core_i[1] && dcls_config_i[1])) begin
                  coproc_resp_o[1][i] = coproc_resp_i[i];
                  coproc_resp_o[2][i] = '0;
                end else begin
                  coproc_resp_o[1][i] = '0;
                  coproc_resp_o[2][i] = coproc_resp_i[i];
                end;
            end else if(master_core_i[1]) begin
              coproc_resp_o[1][i] = coproc_resp_i[i];
                if ((!master_core_i[0] && dcls_config_i[0])) begin
                  coproc_resp_o[0][i] = coproc_resp_i[i];
                  coproc_resp_o[2][i] = '0;
                end else begin
                  coproc_resp_o[0][i] = '0;
                  coproc_resp_o[2][i] = coproc_resp_i[i];
                end;
            end else if(master_core_i[2]) begin
              coproc_resp_o[2][i] = coproc_resp_i[i];
                if ((!master_core_i[0] && dcls_config_i[0])) begin
                  coproc_resp_o[0][i] = coproc_resp_i[i];
                  coproc_resp_o[1][i] = '0;
                end else begin
                  coproc_resp_o[0][i] = '0;
                  coproc_resp_o[1][i] = coproc_resp_i[i];
                end;
            end else begin
              coproc_resp_o[2][i] = coproc_resp_i[i];
                if ((!master_core_i[0] && dcls_config_i[0])) begin
                  coproc_resp_o[0][i] = coproc_resp_i[i];
                  coproc_resp_o[1][i] = '0;
                end else begin
                  coproc_resp_o[0][i] = '0;
                  coproc_resp_o[1][i] = coproc_resp_i[i];
                end;
            end
          end
        end else if (tcls_mode_i && !dcls_mode_i) begin // TCLS
          coproc_resp_o[0][i] = coproc_resp_i[i];
          coproc_resp_o[1][i] = coproc_resp_i[i];
          coproc_resp_o[2][i] = coproc_resp_i[i];
        end else begin  // SINGLE
          if ((master_core_i[0])) begin
          coproc_resp_o[0][i] = coproc_resp_i[i];
          coproc_resp_o[1][i] = '0;
          coproc_resp_o[2][i] = '0;
          end else if ((master_core_i[1])) begin
          coproc_resp_o[0][i] = '0;
          coproc_resp_o[1][i] = coproc_resp_i[i];
          coproc_resp_o[2][i] = '0;
          end else if ((master_core_i[2])) begin
          coproc_resp_o[0][i] = '0;
          coproc_resp_o[1][i] = '0;
          coproc_resp_o[2][i] = coproc_resp_i[i];
          end else begin
          coproc_resp_o[0][i] = coproc_resp_i[i];
          coproc_resp_o[1][i] = '0;
          coproc_resp_o[2][i] = '0;
          end
          end
      end
    end
    //Isolate Bus Coprocessor
    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : isolate_obi_bus_coprocessor
      obi_isolate #(
          .obi_req_t            (obi_req_t  ),
          .obi_resp_t           (obi_resp_t ),
          .ISOLATE_VAL          (32'h0)
      ) obi_isolate (
        .clk_i,
        .rst_ni,
        .dcls_wfi_i(dcls_wfi_coproc),

        .obi_req_i(coproc_req_i[i]),
        .obi_resp_i(coproc_resp_o[i]),
        .obi_isolate_o(isolate_coproc_resp[i])
      );
    end

    //DCLS Staggered
    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : eros_copr_staggered
      copr_lockstep_reg #(
          .obi_req_t            (obi_req_t  ),
          .obi_resp_t           (obi_resp_t ),
          .NCYCLES(NCYCLES)
      ) copr_lockstep_reg_i (
          .clk_i,
          .rst_ni,
          .obi_req_i({slave_copr_req_s[i],master_copr_req_s[i]}),
          .obi_req_o({slave_copr_req_ff_s[i],master_copr_req_ff_s[i]}),
          .obi_resp_i(coproc_resp_i[i]),
          .obi_resp_o({slave_copr_resp_ff_s[i],master_copr_resp_ff_s[i]}),
          .enable_i(staggered_mode_i && dcls_mode_i && ~dcls_wfi_coproc)
      );
    end

    // Voter
    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : eros_copr_voter
      copr_tmr_voter #(
        .obi_req_t            (obi_req_t  ),
        .obi_resp_t           (obi_resp_t )
      ) copr_tmr_i (
        .obi_req_i({coproc_req_i[0][i],coproc_req_i[1][i],coproc_req_i[2][i]}),
        .voted_obi_req_o(voted_copr_req_s[i]),
        .enable_i(tcls_mode_i),
        .error_o(copr_voter_error[i]),
        .error_id_o(copr_voter_id_error[i])
      );
    end

    // Comparator
    for (genvar i = 0; i < NMASTER_COPROC_RND; i++) begin : eros_copr_comparator
      copr_dmr_comparator #(
        .obi_req_t            (obi_req_t  ),
        .obi_resp_t           (obi_resp_t )
      ) copr_dmr_comparator_i (
        .obi_req_i({copr_dcls_master_req_s[i],copr_dcls_slave_req_s[i]}),
        .compared_obi_req_o(compared_copr_req_s[i]),
        .error_o(copr_comparator_error[i])
      );
    end

    assign copr_voter_error_s =|copr_voter_error;
    always_comb begin
      copr_voter_id_error_s = '0;
      for (int i = 0; i < NMASTER_COPROC_RND; i++) begin
          copr_voter_id_error_s |= copr_voter_id_error[i];
      end
    end
    assign copr_comparator_error_s = |copr_comparator_error;

  end else begin
    assign coproc_req_o = '0;
    assign coproc_resp_o = '0;
    assign copr_voter_error_s ='0;
    assign copr_voter_id_error_s = '0;
    assign copr_comparator_error_s = '0;
  end
endmodule
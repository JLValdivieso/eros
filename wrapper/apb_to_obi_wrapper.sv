`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

`include "obi/assign.svh"
`include "obi/typedef.svh"

/// An APB to OBI adapter.
module apb_to_obi_wrapper
  import obi_pkg::*;
 #(
  /// The configuration of the manager port (output port).
  parameter      obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  /// The APB request struct for the subordinate port (input port).
  parameter type apb_req_t = logic, // APB request struct
  /// The APB response struct for the subordinate port (input port).
  parameter type apb_rsp_t = logic, // APB response struct
  /// The OBI request struct for the manager port (output port).
  parameter type obi_req_t = logic,
  /// The OBI response struct for the manager port (output port).
  parameter type obi_rsp_t = logic
) (
  input  logic clk_i,
  input  logic rst_ni,
  // Subordinate APB port.
  input  apb_req_t apb_req_i,
  output apb_rsp_t apb_rsp_o,
  // Manager OBI port.
  output obi_req_t obi_req_o,
  input  obi_rsp_t obi_rsp_i
);


`OBI_TYPEDEF_ALL(obi_master, obi_pkg::ObiDefaultConfig)

    obi_master_req_t apb_obi_master_req;
    obi_master_rsp_t apb_obi_master_resp;


apb_to_obi #(
    .apb_req_t (apb_req_t),
    .apb_rsp_t (apb_rsp_t),
    .obi_req_t (obi_master_req_t),
    .obi_rsp_t (obi_master_rsp_t)
) apb_to_obi_i (
    .clk_i,
    .rst_ni,
  // Subordinate APB port.
    .apb_req_i(apb_req_i),
    .apb_rsp_o(apb_rsp_o),
  // Manager OBI port.
    .obi_req_o(apb_obi_master_req),
    .obi_rsp_i(apb_obi_master_resp)
);

//Assign different format of OBI bus, OBI X-HEEP format <-> OBI Standart git format

assign obi_req_o.req = apb_obi_master_req.req;
assign obi_req_o.we = apb_obi_master_req.a.we;
assign obi_req_o.be = apb_obi_master_req.a.be;
assign obi_req_o.addr = apb_obi_master_req.a.addr;
assign obi_req_o.wdata = apb_obi_master_req.a.wdata;


assign apb_obi_master_resp.gnt = obi_rsp_i.gnt;
assign apb_obi_master_resp.rvalid = obi_rsp_i.rvalid;
assign apb_obi_master_resp.r.rdata = obi_rsp_i.rdata;

endmodule

// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)
/*
 *
 *
 * Description: Contains common system definitions.
 *
 *
 */

package eros_pkg;

  import addr_map_rule_pkg::*;

  //INTC TYPE
  typedef enum logic {
    EDGE,
    LEVEL
  } interrupt_type_e;

  localparam interrupt_type_e Intc_Iype = EDGE;

  //CPU TYPE
  typedef enum logic [1:0] {
    CV32E20,
    CV32E40P,
    CV32E40PX
  } cpu_type_e;

  localparam cpu_type_e CPU_type = CV32E20;
  localparam NCYCLES = 1;

  //System Bus
  typedef enum logic {
    NtoM
    //  onetoM //Not implemented
  } bus_type_e;

  localparam bus_type_e BusType = NtoM;

  //master idx
  localparam logic [31:0] CORE0_INSTR_IDX = 0;
  localparam logic [31:0] CORE0_DATA_IDX = 1;
  localparam logic [31:0] CORE1_INSTR_IDX = 2;
  localparam logic [31:0] CORE1_DATA_IDX = 3;
  localparam logic [31:0] CORE2_INSTR_IDX = 4;
  localparam logic [31:0] CORE2_DATA_IDX = 5;
  localparam logic [31:0] EXTERNAL_MASTER_IDX = 6;

  localparam SYSTEM_XBAR_NMASTER = 7;
  localparam SYSTEM_XBAR_NSLAVE = 5; /*1 ERROR / 2 INTERNAL_PERIPH / 3 EXTERNAL_PERIPH* / 4 RAM0 / 5 RAM1 */

  localparam GLOBAL_BASE_ADDRESS = 32'h${SystemBus.BaseAddress};
  localparam SAFE_CSR_BASE_ADDRESS = 32'h${CSR.BaseAddress}; /*core_v_mini_mcu_pkg::EXT_PERIPHERAL_START_ADDRESS;*/


  localparam int unsigned MEM_SIZE = 32'h00010000;
  localparam int unsigned NUM_BANKS = 2;


  // Internal BUS-REGISTER slave address map
  // ---------------------------------------
  localparam logic [31:0] SAFE_CPU_REGISTER_START_ADDRESS = SAFE_CSR_BASE_ADDRESS + 32'h0;
  localparam logic [31:0] SAFE_CPU_REGISTER_SIZE = 32'h0000100;
  localparam logic [31:0] SAFE_CPU_REGISTER_END_ADDRESS = SAFE_CPU_REGISTER_START_ADDRESS + SAFE_CPU_REGISTER_SIZE;

  // Forward crossbars address map and index
  // ---------------------------------------
  // These crossbar connect each muster to the internal crossbar and to the
  // corresponding external master port.
  localparam logic [31:0] DEMUX_INT_XBAR_IDX = 32'd0;
  localparam logic [31:0] DEMUX_SAFE_CPU_REGISTER_IDX = 32'd1;

  // Address map
  // NOTE: the internal address space is chosen by default by the system bus,
  // so it is not defined here.
  localparam addr_map_rule_t [0:0] DEMUX_INT_SAFE_REG_ADDR_RULES = '{
      '{
          idx: DEMUX_SAFE_CPU_REGISTER_IDX,
          start_addr: SAFE_CPU_REGISTER_START_ADDRESS,
          end_addr: SAFE_CPU_REGISTER_END_ADDRESS
      }
  };

  //Internal Memory Map and Index
  //--------------------
  localparam int unsigned LOG_SYSTEM_XBAR_NMASTER = SYSTEM_XBAR_NMASTER > 1 ? $clog2(
      SYSTEM_XBAR_NMASTER
  ) : 32'd1;
  localparam int unsigned LOG_SYSTEM_XBAR_NSLAVE = SYSTEM_XBAR_NSLAVE > 1 ? $clog2(
      SYSTEM_XBAR_NSLAVE
  ) : 32'd1;

  localparam logic [31:0] ERROR_START_ADDRESS = 32'hBADACCE5;
  localparam logic [31:0] ERROR_SIZE = 32'h00000001;
  localparam logic [31:0] ERROR_END_ADDRESS = ERROR_START_ADDRESS + ERROR_SIZE;
  localparam logic [31:0] ERROR_IDX = 32'd0;

  localparam logic [31:0] PERIPHERAL_START_ADDRESS = GLOBAL_BASE_ADDRESS + 32'h00010000;
  localparam logic [31:0] PERIPHERAL_SIZE = 32'h00002000;
  localparam logic [31:0] PERIPHERAL_END_ADDRESS = PERIPHERAL_START_ADDRESS + PERIPHERAL_SIZE;
  localparam logic [31:0] PERIPHERAL_IDX = 32'd1;

  localparam logic [31:0] EXTERNAL_PERIPHERAL_START_ADDRESS = 32'h${MMAcceleratorOrExternalBus.BaseAddress};/*X-HEEP VERSION32'h00000000;*/
  localparam logic [31:0] EXTERNAL_PERIPHERAL_SIZE = 32'h${MMAcceleratorOrExternalBus.Size};/*X-HEEP VERSION32'h41000000;*/
  localparam logic [31:0] EXTERNAL_PERIPHERAL_END_ADDRESS = EXTERNAL_PERIPHERAL_START_ADDRESS + EXTERNAL_PERIPHERAL_SIZE;
  localparam logic [31:0] EXTERNAL_PERIPHERAL_IDX = 32'd2;

  localparam logic [31:0] MEMORY_RAM0_START_ADDRESS = GLOBAL_BASE_ADDRESS + 32'h00020000;
  localparam logic [31:0] MEMORY_RAM0_SIZE = 32'h00008000;
  localparam logic [31:0] MEMORY_RAM0_END_ADDRESS = MEMORY_RAM0_START_ADDRESS + MEMORY_RAM0_SIZE;
  localparam logic [31:0] MEMORY_RAM0_IDX = 32'd3;

  localparam logic [31:0] MEMORY_RAM1_START_ADDRESS = GLOBAL_BASE_ADDRESS + 32'h00028000;
  localparam logic [31:0] MEMORY_RAM1_SIZE = 32'h00008000;
  localparam logic [31:0] MEMORY_RAM1_END_ADDRESS = MEMORY_RAM1_START_ADDRESS + MEMORY_RAM1_SIZE;
  localparam logic [31:0] MEMORY_RAM1_IDX = 32'd4;

//  localparam logic [31:0] SAFE_CPU_REGISTER_START_ADDRESS = GLOBAL_BASE_ADDRESS + 32'h00012000;
//  localparam logic [31:0] SAFE_CPU_REGISTER_SIZE = 32'h0000100;
//  localparam logic [31:0] SAFE_CPU_REGISTER_END_ADDRESS = SAFE_CPU_REGISTER_START_ADDRESS + SAFE_CPU_REGISTER_SIZE;
//  localparam logic [31:0] SAFE_CPU_REGISTER_IDX = 32'd5;

  localparam GLOBAL_END_ADDRESS = GLOBAL_BASE_ADDRESS + MEMORY_RAM1_END_ADDRESS;

  localparam addr_map_rule_t [SYSTEM_XBAR_NSLAVE-1:0] XBAR_ADDR_RULES = '{
      '{idx: ERROR_IDX, start_addr: ERROR_START_ADDRESS, end_addr: ERROR_END_ADDRESS},
      '{
          idx: PERIPHERAL_IDX,
          start_addr: PERIPHERAL_START_ADDRESS,
          end_addr: PERIPHERAL_END_ADDRESS
      },
      '{
          idx: EXTERNAL_PERIPHERAL_IDX,
          start_addr: EXTERNAL_PERIPHERAL_START_ADDRESS,
          end_addr: EXTERNAL_PERIPHERAL_END_ADDRESS
      },
      '{
          idx: MEMORY_RAM0_IDX,
          start_addr: MEMORY_RAM0_START_ADDRESS,
          end_addr: MEMORY_RAM0_END_ADDRESS
      },
      '{
          idx: MEMORY_RAM1_IDX,
          start_addr: MEMORY_RAM1_START_ADDRESS,
          end_addr: MEMORY_RAM1_END_ADDRESS
      }//,
/*      '{
          idx: SAFE_CPU_REGISTER_IDX,
          start_addr: SAFE_CPU_REGISTER_START_ADDRESS,
          end_addr: SAFE_CPU_REGISTER_END_ADDRESS
      }*/
  };

  //Peripherals
  //-----------

  localparam PERIPHERALS = 1;

  localparam logic [31:0] DEBUG_BOOTROM_START_ADDRESS = PERIPHERAL_START_ADDRESS + 32'h00000000;
  localparam logic [31:0] DEBUG_BOOTROM_SIZE = 32'h00001000;
  localparam logic [31:0] DEBUG_BOOTROM_END_ADDRESS = DEBUG_BOOTROM_START_ADDRESS + DEBUG_BOOTROM_SIZE;
  localparam logic [31:0] DEBUG_BOOTROM_IDX = 32'd0;

  localparam addr_map_rule_t [PERIPHERALS-1:0] PERIPHERALS_ADDR_RULES = '{
      '{
          idx: DEBUG_BOOTROM_IDX,
          start_addr: DEBUG_BOOTROM_START_ADDRESS,
          end_addr: DEBUG_BOOTROM_END_ADDRESS
      }
  };

  localparam int unsigned PERIPHERALS_PORT_SEL_WIDTH = PERIPHERALS > 1 ? $clog2(
      PERIPHERALS
  ) : 32'd1;


  //Private Memory CPU
  localparam CPU_XBAR_SLAVE = 2;
  localparam CPU_XBAR_NRULES = 3;  //Depending on the external address.

  localparam logic [31:0] BUS_SYSTEM_START_ADDRESS = PERIPHERAL_START_ADDRESS;
  localparam logic [31:0] BUS_SYSTEM_SIZE = 32'h00FEFFFF;
  localparam logic [31:0] BUS_SYSTEM_END_ADDRESS = BUS_SYSTEM_START_ADDRESS + BUS_SYSTEM_SIZE;
  localparam logic [31:0] BUS_SYSTEM_IDX = 32'd0;

  localparam logic [31:0] EXT_BUS_SYSTEM_START_ADDRESS = 32'h00000000;
  localparam logic [31:0] EXT_BUS_SYSTEM_SIZE = 32'h41000000;
  localparam logic [31:0] EXT_BUS_SYSTEM_END_ADDRESS = EXT_BUS_SYSTEM_START_ADDRESS + EXT_BUS_SYSTEM_SIZE;
  localparam logic [31:0] EXT_BUS_SYSTEM_IDX = 32'd0;

  localparam logic [31:0] CPU_REG_START_ADDRESS = GLOBAL_BASE_ADDRESS; //Todo modificar la reg privada
  localparam logic [31:0] CPU_REG_SIZE = 32'h00010000;
  localparam logic [31:0] CPU_REG_END_ADDRESS = CPU_REG_START_ADDRESS + CPU_REG_SIZE;
  localparam logic [31:0] CPU_REG_IDX = 32'd1;



  localparam addr_map_rule_t [CPU_XBAR_NRULES-1:0] CPU_XBAR_ADDR_RULES = '{
      '{
          idx: BUS_SYSTEM_IDX,
          start_addr: BUS_SYSTEM_START_ADDRESS,
          end_addr: BUS_SYSTEM_END_ADDRESS
      },
      '{
          idx: EXT_BUS_SYSTEM_IDX,
          start_addr: EXT_BUS_SYSTEM_START_ADDRESS,
          end_addr: EXT_BUS_SYSTEM_END_ADDRESS
      },
      '{idx: CPU_REG_IDX, start_addr: CPU_REG_START_ADDRESS, end_addr: CPU_REG_END_ADDRESS}
  };

  //External Peripherals MM Base Address

  //DEBUG SYSTEM
  localparam int unsigned DEBUG_SYSTEM_START_START_ADDRESS = 32'h10000000;

endpackage

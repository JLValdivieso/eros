# EROS: Extensible Reliable Offloading Solution

This platform provides an efficient offloading computing system for safety-critical applications. The proposed solution takes the form of a memory-mapped accelerator, tailoring run-time reconfigurable
mechanisms to support adaptive fault-tolerant execution. The accelerator platform is fully built with open source IPs from the PULP and X-HEEP ecosystems. Furthermore, it has been enhanced with non-intrusive hardware-based configuration and control modules.

The block diagram below shows the EROS Safe Accelerator Platform.


![](https://github.com/LuisDonatien/READEM_Template/blob/main/images/General_Platform.svg)

# Repository folder structure

    .
    ├── .github/workflows
    ├── data
    ├── fpga   
    ├── images    
    ├── ip
    ├── rtl
    │   └── include   
    |        
    ├── scripts
    │   ├── sim
    │   └── synthesis
    ├── sw
    |   |── CBdevice/lib
    |   |   |── cb_register
    |   |   |── crt
    |   |   └── safety
    |   |
    │   ├── applications
    │   ├── cmake
    │   ├── linker
    |   └── device ->
    │    
    ├── util
    ├── Makefile
    └── README.md


compilation cheshire:
make app-cbcore     PROJECT=hello_world     RISCV=/opt/riscv/eros     COMPILER_PREFIX=riscv64-unknown-     ARCH=rv32imc_zicsr 
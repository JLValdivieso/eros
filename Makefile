# Copyright 2024 Luis Waucquez
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Luis Waucquez <luis.waucquez.jimenez@alumnos.upm.es>
# Description: CEI-Backpack top-level makefile

MAKE = make
.PHONY: test

PROJECT  ?= hello_world

# Linker options are 'on_chip' (default),'flash_load','flash_exec','freertos'
LINKER   ?= on_chip

# Compiler options are 'gcc' (default) and 'clang'
COMPILER ?= gcc

# Compiler prefix options are 'riscv32-unknown-' (default)
COMPILER_PREFIX ?= riscv32-unknown-

# Target options are 'sim' (default) and 'pynq-z2'
TARGET   	?= sim

# Arch options are any RISC-V ISA string supported by the CPU. Default 'rv32imc'
ARCH     ?= rv32imfc

# Default FPGA
FPGA_BOARD 	?= pynq-z2

# EROS CONFIGS PATH
EROS_CONFIG ?= config.hjson

## HW
#Generate EROS

eros-gen:
	python3 ./util/eros_gen.py --addr_config configs/$(EROS_CONFIG)
	$(MAKE) -C ip/CB_boot_rom all

eros-verible:
	util/format-verible;

## SW
eros-app: eros-app-restore
	$(MAKE) -C sw PROJECT=$(PROJECT) TARGET=$(TARGET) LINKER=$(LINKER) COMPILER=$(COMPILER) COMPILER_PREFIX=$(COMPILER_PREFIX) ARCH=$(ARCH)

# Clean the CMake build folder
eros-app-restore:
	rm -rf sw/build

## Clean the CMake build folder
eros-app-clean:
	if [ -f "sw/build/Makefile" ]; then\
		$(MAKE) -C sw/build clean;\
	else\
		$(MAKE) app-restore;\
	fi

eros-vendor: ./vendor/openhwgroup_cve2.vendor.hjson
	python3 ./util/vendor.py --update ./vendor/openhwgroup_cve2.vendor.hjson


eros-clean:
	rm -rf build

help:
	@echo "[WIP] See the Makefile for options"
# See LICENSE.SiFive for license details

CB_boot_rom = CB_boot_rom.sv

GCC?=/opt/riscv/eros/bin/riscv64-unknown-elf-gcc
OBJCOPY?=/opt/riscv/eros/bin/riscv64-unknown-elf-objcopy
OBJDUMP?=/opt/riscv/eros/bin/riscv64-unknown-elf-objdump
PYTHON?=python

INC_FOLDERS                 = ../../sw/CB_device/lib/base_address
INC_FOLDERS                += ../../sw/CB_device/lib/cb_register

INC_FOLDERS_GCC             = $(addprefix -I ,$(INC_FOLDERS))

print-inc-folders:
	@echo "Directorios de inclusión:"
	@echo $(INC_FOLDERS_GCC)

all: $(CB_boot_rom) CB_boot_rom.dump

%.sv: %.img
	$(PYTHON) gen_rom.py $<

%.img: %.bin
	dd if=$< of=$@ bs=2048 count=1

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.elf: $(findstring CB_boot_rom, $(CB_boot_rom)).S link.ld
	$(GCC) $(INC_FOLDERS_GCC) -Tlink.ld $< -nostdlib -fPIC -static -Wl,--no-gc-sections -o $@

%.dump: %.elf
	$(OBJDUMP) -d $< --disassemble-all --disassemble-zeroes  --section=.text --section=.debug > $@

clean:
	rm -f *.img *.bin *.sv .*dump

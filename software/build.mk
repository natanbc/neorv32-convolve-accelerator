ifeq ($(NEORV32_HOME),)
    $(error Please set NEORV32_HOME to the path of your NEORV32 copy)
endif

TOOLCHAIN_ROOT:=$(dir $(lastword $(MAKEFILE_LIST)))
include $(TOOLCHAIN_ROOT)detect.mk
STUBS_DIR:=$(TOOLCHAIN_ROOT)include_stubs

CFLAGS=-target riscv32-unknown-elf -march=rv32imcb                                      \
	   -Os -g -ffreestanding -fno-builtin -fno-stack-protector -mno-relax -fno-pic      \
	   -ffunction-sections -fdata-sections                                              \
	   -falign-functions=4 -falign-loops=4                                              \
	   -Wall -Wextra -Werror -Wno-unused-function                                       \
	   -Wno-unused-command-line-argument                                                \
	   -nostdlib -nostdinc -I . -I $(NEORV32_HOME)/sw/lib/include -I $(STUBS_DIR)       \
	   -MMD -MP                                                                         \
	   $(EXTRA_CFLAGS)
LDFLAGS=--gc-sections -g

.build/%.bin: .build/%.elf
	@mkdir -p $(@D)
	$(OBJCOPY) -I elf32-little -j .text   -O binary $< $@.text
	$(OBJCOPY) -I elf32-little -j .rodata -O binary $< $@.rodata
	$(OBJCOPY) -I elf32-little -j .data   -O binary $< $@.data
	cat $@.text $@.rodata $@.data > $@
	rm -f $@.text $@.rodata $@.data

.build/%.flash: .build/%.bin .build/image_gen
	.build/image_gen -app_bin $< $@ $(shell basename -- $(CURDIR))

.build/image_gen: $(NEORV32_HOME)/sw/image_gen/image_gen.c
	$(HOSTCC) -O2 -g -o $@ $<

define __build_rule
$(1): $(2)
	@mkdir -p $$(@D)
	$$(CC) $$(CFLAGS) -c -o $$@ $$<
endef

$(eval $(call __build_rule,.build/neorv32/%.S.o,$(NEORV32_HOME)/%.S))
$(eval $(call __build_rule,.build/neorv32/%.s.o,$(NEORV32_HOME)/%.s))
$(eval $(call __build_rule,.build/neorv32/%.c.o,$(NEORV32_HOME)/%.c))

$(eval $(call __build_rule,.build/%.S.o,%.S))
$(eval $(call __build_rule,.build/%.s.o,%.s))
$(eval $(call __build_rule,.build/%.c.o,%.c))

NEORV_SRC=$(wildcard $(NEORV32_HOME)/sw/lib/source/*.c)
NEORV_SRC+=$(NEORV32_HOME)/sw/common/crt0.S
NEORV_SRC:=$(filter-out $(NEORV32_HOME)/sw/lib/source/syscalls.c,$(NEORV_SRC))
NEORV_REL_SRC=$(NEORV_SRC:$(NEORV32_HOME)/%=%)
NEORV_OBJ=$(addprefix .build/neorv32/,$(NEORV_REL_SRC:=.o))

NEORV_LD_SCRIPT=$(TOOLCHAIN_ROOT)neorv32.ld

define neorv_objs
	$(strip $(NEORV_OBJ) $(addprefix .build/,$(1:=.o)))
endef


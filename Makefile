#!/usr/bin/env nix-shell
#! nix-shell --pure -i make
CONVOLVE_SOURCES=convolve.vhd convolve_parallel.vhd convolve_serial.vhd isqrt.vhd

CXXRTL_CXX_FLAGS=-g -O3 -std=c++14 -I $(shell yosys-config --datdir)/include

GHDL ?= ghdl
GHDL_FLAGS += --std=08
GHDL_PLUGIN ?= ghdl

YOSYS ?= yosys
YOSYS_FLAGS += -m $(GHDL_PLUGIN)

REV=cpu
TOP=cpu

all: $(SOURCES)
	quartus_map -c $(REV) $(TOP)
	quartus_fit -c $(REV) $(TOP)
	quartus_asm -c $(REV) $(TOP)
	quartus_sta $(REV)

clean:
	rm -rf build db incremental_db output_files

build/parallel/work-obj08.cf: $(CONVOLVE_SOURCES)
	mkdir -p $(@D)
	ghdl -a $(GHDL_FLAGS) --workdir=$(@D) -P$(@D) --work=work $(CONVOLVE_SOURCES)
build/serial/work-obj08.cf: $(CONVOLVE_SOURCES)
	mkdir -p $(@D)
	ghdl -a $(GHDL_FLAGS) --workdir=$(@D) -P$(@D) --work=work $(CONVOLVE_SOURCES)

build/parallel/top.cpp: build/parallel/work-obj08.cf
	$(YOSYS) $(YOSYS_FLAGS)                                                             \
		-p                                                                              \
		"ghdl $(GHDL_FLAGS) --workdir=$(@D) -P$(@D) --no-formal convolve_parallel;      \
		write_cxxrtl $@"
build/serial/top.cpp: build/serial/work-obj08.cf
	$(YOSYS) $(YOSYS_FLAGS)                                                             \
		-p                                                                              \
		"ghdl $(GHDL_FLAGS) --workdir=$(@D) -P$(@D) --no-formal convolve_serial;        \
		write_cxxrtl $@"

#build/testbench_parallel: build/parallel/top.cpp testbench/parallel.cpp
#	$(CXX) $(CXXRTL_CXX_FLAGS) -I build/parallel testbench/parallel.cpp -o $@
#build/testbench_serial: build/serial/top.cpp testbench/syngle_cycle.cpp
#	$(CXX) $(CXXRTL_CXX_FLAGS) -I build/serial testbench/serial.cpp -o $@
build/testbench_parallel: build/parallel/top.cpp testbench/main.cpp
	$(CXX) $(CXXRTL_CXX_FLAGS) -I build/parallel -DTOP=p_convolve__parallel testbench/main.cpp -o $@
build/testbench_serial: build/serial/top.cpp testbench/main.cpp
	$(CXX) $(CXXRTL_CXX_FLAGS) -I build/serial -DTOP=p_convolve__serial testbench/main.cpp -o $@

build/testbench-ffi-parallel.so: build/parallel/top.cpp testbench/ffi.cpp
	$(CXX) $(CXXRTL_CXX_FLAGS) -shared -fPIC -I build/parallel -DTOP=p_convolve__parallel testbench/ffi.cpp -o $@
build/testbench-ffi-serial.so: build/serial/top.cpp testbench/ffi.cpp
	$(CXX) $(CXXRTL_CXX_FLAGS) -shared -fPIC -I build/serial -DTOP=p_convolve__serial testbench/ffi.cpp -o $@

testbench-parallel: build/testbench_parallel
	build/testbench_parallel
testbench-serial: build/testbench_serial
	build/testbench_serial
testbench: testbench-parallel testbench-serial
.PHONY: testbench-parallel testbench-serial

define __image_test_variant
build/$(1)-$(2)-reference.png: testbench/image.py testbench/$(1).png
	mkdir -p $$(@D)
	python3 testbench/image.py $(1) reference $(2)
build/$(1)-$(2)-cxxrtl-serial.png: testbench/image.py testbench/$(1).png build/testbench-ffi-serial.so
	python3 testbench/image.py $(1) cxxrtl-serial $(2)
build/$(1)-$(2)-cxxrtl-parallel.png: testbench/image.py testbench/$(1).png build/testbench-ffi-parallel.so
	python3 testbench/image.py $(1) cxxrtl-parallel $(2)

testbench-$(1)-$(2)-check: build/$(1)-$(2)-reference.png build/$(1)-$(2)-cxxrtl-serial.png build/$(1)-$(2)-cxxrtl-parallel.png
	python3 testbench/image.py $(1) check $(2)

testbench-$(1)-check: testbench-$(1)-$(2)-check
.PHONY: testbench-$(1)-$(2)-check
endef

define __image_test
$$(eval $$(call __image_test_variant,$(1),sqrt))
$$(eval $$(call __image_test_variant,$(1),bor))
$$(eval $$(call __image_test_variant,$(1),avg))

testbench: testbench-$(1)-check
.PHONY: testbench-$(1)-check
endef

$(eval $(call __image_test,possum))
$(eval $(call __image_test,mel))

testbench:
	@echo All tests OK

.PHONY: all clean testbench

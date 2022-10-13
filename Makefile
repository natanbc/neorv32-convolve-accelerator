CONVOLVE_SOURCES=convolve.vhd $(wildcard convolve_*.vhd)

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

build/pipelined/work-obj08.cf: $(CONVOLVE_SOURCES)
	mkdir -p $(@D)
	ghdl -a $(GHDL_FLAGS) --workdir=$(@D) -P$(@D) --work=work $(CONVOLVE_SOURCES)
build/single_cycle/work-obj08.cf: $(CONVOLVE_SOURCES)
	mkdir -p $(@D)
	ghdl -a $(GHDL_FLAGS) --workdir=$(@D) -P$(@D) --work=work $(CONVOLVE_SOURCES)

build/pipelined/top.cpp: build/pipelined/work-obj08.cf
	$(YOSYS) $(YOSYS_FLAGS)                                                             \
		-p                                                                              \
		"ghdl $(GHDL_FLAGS) --workdir=$(@D) -P$(@D) --no-formal convolve_pipelined;     \
		write_cxxrtl $@"
build/single_cycle/top.cpp: build/single_cycle/work-obj08.cf
	$(YOSYS) $(YOSYS_FLAGS)                                                             \
		-p                                                                              \
		"ghdl $(GHDL_FLAGS) --workdir=$(@D) -P$(@D) --no-formal convolve_single_cycle;  \
		write_cxxrtl $@"

#build/testbench_pipelined: build/pipelined/top.cpp testbench/pipelined.cpp
#	$(CXX) $(CXXRTL_CXX_FLAGS) -I build/pipelined testbench/pipelined.cpp -o $@
#build/testbench_single_cycle: build/single_cycle/top.cpp testbench/syngle_cycle.cpp
#	$(CXX) $(CXXRTL_CXX_FLAGS) -I build/single_cycle testbench/single_cycle.cpp -o $@
build/testbench_pipelined: build/pipelined/top.cpp testbench/main.cpp
	$(CXX) $(CXXRTL_CXX_FLAGS) -I build/pipelined -DTOP=p_convolve__pipelined testbench/main.cpp -o $@
build/testbench_single_cycle: build/single_cycle/top.cpp testbench/main.cpp
	$(CXX) $(CXXRTL_CXX_FLAGS) -I build/single_cycle -DTOP=p_convolve__single__cycle testbench/main.cpp -o $@

build/testbench-ffi-pipelined.so: build/pipelined/top.cpp testbench/ffi.cpp
	$(CXX) $(CXXRTL_CXX_FLAGS) -shared -fPIC -I build/pipelined -DTOP=p_convolve__pipelined testbench/ffi.cpp -o $@
build/testbench-ffi-single_cycle.so: build/single_cycle/top.cpp testbench/ffi.cpp
	$(CXX) $(CXXRTL_CXX_FLAGS) -shared -fPIC -I build/single_cycle -DTOP=p_convolve__single__cycle testbench/ffi.cpp -o $@

testbench-pipelined: build/testbench_pipelined
	build/testbench_pipelined
testbench-single-cycle: build/testbench_single_cycle
	build/testbench_single_cycle

define __image_test
build/$(1)-reference.png: testbench/image.py testbench/$(1).png
	mkdir -p $$(@D)
	python3 testbench/image.py $(1) reference
build/$(1)-cxxrtl-single_cycle.png: testbench/image.py testbench/$(1).png build/testbench-ffi-single_cycle.so
	python3 testbench/image.py $(1) cxxrtl-single
build/$(1)-cxxrtl-pipelined.png: testbench/image.py testbench/$(1).png build/testbench-ffi-pipelined.so
	python3 testbench/image.py $(1) cxxrtl-pipelined

testbench-$(1)-check: build/$(1)-reference.png build/$(1)-cxxrtl-single_cycle.png build/$(1)-cxxrtl-pipelined.png
	python3 testbench/image.py $(1) check

testbench: testbench-$(1)-check
endef

$(eval $(call __image_test,possum))
$(eval $(call __image_test,mel))

testbench: testbench-pipelined testbench-single-cycle

.PHONY: all clean testbench testbench-pipelined testbench-single-cycle testbench-possum-check

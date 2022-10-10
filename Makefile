SOURCES=$(wildcard neorv32/rtl/core/*.vhd neorv32/rtl/core/mem/*.default.vhd) cpu_top.vhd

REV=cpu
TOP=cpu

all: $(SOURCES)
	quartus_map -c $(REV) $(TOP)
	quartus_fit -c $(REV) $(TOP)
	quartus_asm -c $(REV) $(TOP)
	quartus_sta $(REV)

clean:
	rm -rf db incremental_db output_files
.PHONY: all clean

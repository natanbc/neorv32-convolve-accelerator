all: .build/blinky.flash

include ../../build.mk

obj=$(call neorv_objs,$(wildcard *.c))
dep=$(obj:.o=.d)

.build/blinky.elf: $(obj)
	$(LD) $(LDFLAGS) -T $(NEORV_LD_SCRIPT) -o $@ $(obj)

clean:
	rm -rf .build

.PHONY: all clean

-include $(dep)

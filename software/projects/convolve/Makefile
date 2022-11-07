all: .build/convolve.flash

include ../../build.mk

emulator:
	$(MAKE) -C emulator

obj=$(call neorv_objs,$(wildcard *.c))
dep=$(obj:.o=.d)

.build/convolve.elf: $(obj)
	$(LD) $(LDFLAGS) -T $(NEORV_LD_SCRIPT) -o $@ $(obj)

clean:
	rm -rf .build

.PHONY: all clean emulator

-include $(dep)

all: emulator
	./emulator

debug: emulator.dbg
	./emulator.dbg

trace: emulator.trace
	./emulator.trace

srcs=$(wildcard *.c ../*.c)
hdrs=$(wildcard *.h ../*.h)

emulator: $(srcs) $(hdrs) xed/kits/build/lib/libxed.a
	$(CC) -fno-omit-frame-pointer -DEMULATOR -g -Og -Wall -Wextra -Werror -Wno-unused-function \
		-I. -I.. -I xed/kits/build/include $(srcs) -lm xed/kits/build/lib/libxed.a -o $@
emulator.dbg: $(srcs) $(hdrs) xed/kits/build/lib/libxed.a
	$(CC) -fno-omit-frame-pointer -DEMULATOR -DEMULATOR_DEBUG -g -Og -Wall -Wextra -Werror -Wno-unused-function \
		-I. -I.. -I xed/kits/build/include $(srcs) -lm xed/kits/build/lib/libxed.a -o $@
emulator.trace: $(srcs) $(hdrs) xed/kits/build/lib/libxed.a
	$(CC) -fno-omit-frame-pointer -DEMULATOR -DEMULATOR_DEBUG -DEMULATOR_TRACE_MMIO -g -Og -Wall -Wextra -Werror -Wno-unused-function \
	-I. -I.. -I xed/kits/build/include $(srcs) -lm xed/kits/build/lib/libxed.a -o $@

clean:
	rm -f emulator emulator.dbg emulator.trace

xed/.git:
	git clone --depth=1 https://github.com/intelxed/xed.git xed

mbuild/.git:
	git clone --depth=1 https://github.com/intelxed/mbuild.git mbuild

xed/kits/build/lib/libxed.a: xed/.git mbuild/.git
	cd xed && ./mfile.py install --install-dir=kits/build


#pragma once
#include <stdint.h>

typedef struct {
    uint32_t instructions;
    uint32_t cycles;
} ctr_vals;

static ctr_vals read_ctrs() {
#ifdef EMULATOR
    return (ctr_vals) { 0, 0 };
#else
    uint32_t i, c;
    asm volatile("rdinstret %0" : "=r"(i));
    asm volatile("rdcycle   %0" : "=r"(c));
    return (ctr_vals) {
        .instructions = i,
        .cycles = c,
    };
#endif
}


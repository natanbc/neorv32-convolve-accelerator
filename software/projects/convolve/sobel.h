#pragma once
#include "ctr.h"

// Writes to a scratch buffer in DMEM before flushing to output, which improves speed if
// output is in external memory.
//
// Output *MUST* be 4-byte aligned, width *MUST* be a multiple of 4.
ctr_vals sobel_scratchbuf_u8(uint8_t* output, const uint8_t* image, uint32_t width, uint32_t height);
//Identical to unrolled_i32 but with extra memcpy steps
//ctr_vals sobel_scratchbuf_i32(int32_t* output, const uint8_t* image, uint32_t width, uint32_t height);

// Splits first and last rows into specialized loops, improving performance at the cost of code size.
ctr_vals sobel_unrolled_u8(uint8_t* output, const uint8_t* image, uint32_t width, uint32_t height);
ctr_vals sobel_unrolled_i32(int32_t* output, const uint8_t* image, uint32_t width, uint32_t height);

// Simplest, slowest implementation
ctr_vals sobel_slow_u8(uint8_t* output, const uint8_t* image, uint32_t width, uint32_t height);
ctr_vals sobel_slow_i32(int32_t* output, const uint8_t* image, uint32_t width, uint32_t height);


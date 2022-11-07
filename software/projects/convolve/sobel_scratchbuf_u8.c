#include "sobel.h"
#include "accel.h"

#ifndef SCRATCH_SIZE
  #define SCRATCH_SIZE (512)
#endif
_Static_assert(SCRATCH_SIZE % 4 == 0, "Scratch size must be a multiple of word size");

static const int8_t sobel_vertical[9] = {
     1,  0, -1,
     2,  0, -2,
     1,  0, -1
};
static const int8_t sobel_horizontal[9] = {
    -1, -2, -1,
     0,  0,  0,
     1,  2,  1
};

#define SCRATCH_ENTRIES (SCRATCH_SIZE / sizeof(uint8_t))

static union {
   uint8_t u8[SCRATCH_ENTRIES];
   uint32_t u32[SCRATCH_SIZE / sizeof(uint32_t)];
} scratch;

static uint32_t scratch_limit(uint32_t start, uint32_t end) {
    uint32_t limit = start + SCRATCH_ENTRIES;
    return limit < end ? limit : end;
}

static void scratch_flush(uint8_t* sram_out, uint32_t end) {
    sram_out = __builtin_assume_aligned(sram_out, 4);
    uint32_t* sram_words = (uint32_t*)sram_out;

    uint32_t endw = end & ~3; // word end address
    uint32_t offset = 0;
    uint32_t word = 0;
    for(; offset < endw; offset += 4) {
        sram_words[word] = scratch.u32[word];
        word++;
    }
    for(; offset < end; offset++) {
        sram_out[offset] = scratch.u8[offset];
    }
}

static void sobel_iter_row_first(uint8_t* output_row, const uint8_t* curr_row, uint32_t width) {
    const uint8_t* next_row = &curr_row[width];
    accel_shift_pixel(ACCEL_ROW2, *curr_row++);
    accel_shift_pixel(ACCEL_ROW3, *next_row++);

    for(uint32_t x = 0; x < width - 1; x += SCRATCH_ENTRIES) {
        uint32_t lim = scratch_limit(x, width - 1);
        for(uint32_t i = 0; i < lim; i++) {
            accel_shift_pixel(ACCEL_ROW2, *curr_row++);
            accel_shift_pixel(ACCEL_ROW3, *next_row++);
            accel_run();
            scratch.u8[i] = accel_output() >> 2;
        }
        scratch_flush(output_row, lim);
        output_row += lim;
    }
    accel_shift_pixel(ACCEL_ROW2, 0);
    accel_shift_pixel(ACCEL_ROW3, 0);
    accel_run();
    *output_row = accel_output() >> 2;
}

static void sobel_iter_row(uint8_t* output_row, const uint8_t* curr_row, uint32_t width) {
    const uint8_t* prev_row = &curr_row[-(int32_t)width];
    const uint8_t* next_row = &curr_row[width];
    accel_shift_pixel(ACCEL_ROW1, *prev_row++);
    accel_shift_pixel(ACCEL_ROW2, *curr_row++);
    accel_shift_pixel(ACCEL_ROW3, *next_row++);

    for(uint32_t x = 0; x < width - 1; x += SCRATCH_ENTRIES) {
        uint32_t lim = scratch_limit(x, width - 1);
        for(uint32_t i = 0; i < lim; i++) {
            accel_shift_pixel(ACCEL_ROW1, *prev_row++);
            accel_shift_pixel(ACCEL_ROW2, *curr_row++);
            accel_shift_pixel(ACCEL_ROW3, *next_row++);
            accel_run();
            scratch.u8[i] = accel_output() >> 2;
        }
        scratch_flush(output_row, lim);
        output_row += lim;
    }
    accel_shift_pixel(ACCEL_ROW1, 0);
    accel_shift_pixel(ACCEL_ROW2, 0);
    accel_shift_pixel(ACCEL_ROW3, 0);
    accel_run();
    *output_row = accel_output() >> 2;
}

static void sobel_iter_row_last(uint8_t* output_row, const uint8_t* curr_row, uint32_t width) {
    const uint8_t* prev_row = &curr_row[-(int32_t)width];
    accel_shift_pixel(ACCEL_ROW1, *prev_row++);
    accel_shift_pixel(ACCEL_ROW2, *curr_row++);

    for(uint32_t x = 0; x < width - 1; x += SCRATCH_ENTRIES) {
        uint32_t lim = scratch_limit(x, width - 1);
        for(uint32_t i = 0; i < lim; i++) {
            accel_shift_pixel(ACCEL_ROW1, *prev_row++);
            accel_shift_pixel(ACCEL_ROW2, *curr_row++);
            accel_run();
            scratch.u8[i] = accel_output() >> 2;
        }
        scratch_flush(output_row, lim);
        output_row += lim;
    }
    accel_shift_pixel(ACCEL_ROW1, 0);
    accel_shift_pixel(ACCEL_ROW2, 0);
    accel_run();
    *output_row = accel_output() >> 2;
}

ctr_vals sobel_scratchbuf_u8(uint8_t* output, const uint8_t* image, uint32_t width, uint32_t height) {
    ctr_vals start = read_ctrs();
    accel_load_matrix1(sobel_vertical);
    accel_load_matrix2(sobel_horizontal);

    const uint8_t zeros[9] = {0};

    accel_load_pixels(zeros);
    sobel_iter_row_first(output, image, width);

    for(uint32_t y = 1; y < height - 1; y++) {
        accel_load_pixels(zeros);
        uint8_t* output_row = &output[width*y];
        const uint8_t* curr_row = &image[width*y];
        sobel_iter_row(output_row, curr_row, width);
    }
    
    accel_load_pixels(zeros);
    sobel_iter_row_last(&output[width*(height - 1)], &image[width * (height - 1)], width);

    ctr_vals end = read_ctrs();
    return (ctr_vals) {
        .instructions = end.instructions - start.instructions,
        .cycles = end.cycles - start.cycles,
    };
}


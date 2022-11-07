#include "sobel.h"
#include "accel.h"

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

ctr_vals sobel_slow_i32(int32_t* output, const uint8_t* image, uint32_t width, uint32_t height) {
    ctr_vals start = read_ctrs();
    accel_load_matrix1(sobel_vertical);
    accel_load_matrix2(sobel_horizontal);

    const uint8_t zeros[9] = {0};
    for(uint32_t y = 0; y < height; y++) {
        accel_load_pixels(zeros);
        int32_t* output_row = &output[width*y];
        const uint8_t* curr_row = &image[width*y];
        const uint8_t* prev_row = y == 0 ? 0 : &curr_row[-(int32_t)width];
        const uint8_t* next_row = y == height - 1 ? 0 : &curr_row[width];

        if(prev_row) accel_shift_pixel(ACCEL_ROW1, *prev_row++);
        accel_shift_pixel(ACCEL_ROW2, *curr_row++);
        if(next_row) accel_shift_pixel(ACCEL_ROW3, *next_row++);
        for(uint32_t x = 0; x < width - 1; x++) {
            if(prev_row) accel_shift_pixel(ACCEL_ROW1, *prev_row++);
            accel_shift_pixel(ACCEL_ROW2, *curr_row++);
            if(next_row) accel_shift_pixel(ACCEL_ROW3, *next_row++);
            accel_run();
            *output_row++ = accel_output() >> 2;
        }
        accel_shift_pixel(ACCEL_ROW1, 0);
        accel_shift_pixel(ACCEL_ROW2, 0);
        accel_shift_pixel(ACCEL_ROW3, 0);
        accel_run();
        *output_row = accel_output() >> 2;
    }
    
    ctr_vals end = read_ctrs();
    return (ctr_vals) {
        .instructions = end.instructions - start.instructions,
        .cycles = end.cycles - start.cycles,
    };
}


#pragma once

#include "neorv32_emusupport.h"

/* in */
static const uint32_t ACCEL_CONTROL_REG = 0;
static const uint32_t ACCEL_BASE_PIXEL_LOAD_REG = 1;
static const uint32_t ACCEL_BASE_PIXEL_SHIFT_REG = 4;
static const uint32_t ACCEL_BASE_MATRIX1_LOAD_REG = 7;
static const uint32_t ACCEL_BASE_MATRIX2_LOAD_REG = 10;

typedef enum {
    ACCEL_MERGE_SUM_ABS             = 0x0,
    ACCEL_MERGE_SQRT_SUM_OF_SQUARES = 0x1,
    ACCEL_MERGE_BITWISE_OR          = 0x2,
    ACCEL_MERGE_AVERAGE             = 0x3,
} accel_merge_mode;

static const uint32_t ACCEL_CONTROL_FLAG_START = 0x00000001;
static const uint32_t ACCEL_CONTROL_FLAG_SET_MODE = 0x00000008;

/* out */
static const uint32_t ACCEL_STATUS_REG = 0;
static const uint32_t ACCEL_OUTPUT_REG = 1;
static const uint32_t ACCEL_CONV1_REG = 2;
static const uint32_t ACCEL_CONV2_REG = 3;

typedef enum {
    ACCEL_PIXELS = 1, //ACCEL_BASE_PIXEL_LOAD_REG,
    ACCEL_MATRIX1 = 7, //ACCEL_BASE_MATRIX1_LOAD_REG,
    ACCEL_MATRIX2 = 10, //ACCEL_BASE_MATRIX2_LOAD_REG,
} accel_input;

typedef enum {
    ACCEL_ROW1 = 0,
    ACCEL_ROW2 = 1,
    ACCEL_ROW3 = 2,
} accel_row;

#define ACCEL_SHIFT(v, n) ((uint32_t)((v) & 0xFF) << (n))
static inline void accel_load_row_u(accel_input inp, accel_row row, const uint8_t data[3]) {
    const uint32_t val = ACCEL_SHIFT(data[0], 0) | ACCEL_SHIFT(data[1], 8) | ACCEL_SHIFT(data[2], 16);
    NEORV32_CFS.REG[inp + row] = val;
}

static inline void accel_load_row_s(accel_input inp, accel_row row, const int8_t data[3]) {
    const uint32_t val = ACCEL_SHIFT(data[0], 0) | ACCEL_SHIFT(data[1], 8) | ACCEL_SHIFT(data[2], 16);
    NEORV32_CFS.REG[inp + row] = val;
}
#undef ACCEL_SHIFT

static inline void accel_load_u(accel_input inp, const uint8_t data[9]) {
    accel_load_row_u(inp, ACCEL_ROW1, &data[0]);
    accel_load_row_u(inp, ACCEL_ROW2, &data[3]);
    accel_load_row_u(inp, ACCEL_ROW3, &data[6]);
}

static inline void accel_load_s(accel_input inp, const int8_t data[9]) {
    accel_load_row_s(inp, ACCEL_ROW1, &data[0]);
    accel_load_row_s(inp, ACCEL_ROW2, &data[3]);
    accel_load_row_s(inp, ACCEL_ROW3, &data[6]);
}

static inline void accel_load_pixels(const uint8_t data[9]) {
    accel_load_u(ACCEL_PIXELS, data);
}

static inline void accel_load_matrix1(const int8_t data[9]) {
    accel_load_s(ACCEL_MATRIX1, data);
}

static inline void accel_load_matrix2(const int8_t data[9]) {
    accel_load_s(ACCEL_MATRIX2, data);
}

static inline void accel_shift_pixel(accel_row row, uint8_t val) {
    NEORV32_CFS.REG[ACCEL_BASE_PIXEL_SHIFT_REG + row] = val;
}

static inline void accel_set_mode(accel_merge_mode mode) {
    NEORV32_CFS.REG[ACCEL_CONTROL_REG] = ACCEL_CONTROL_FLAG_SET_MODE | ((uint32_t)mode << 1);
}

static inline void accel_start() {
    NEORV32_CFS.REG[ACCEL_CONTROL_REG] = ACCEL_CONTROL_FLAG_START;
}

static inline _Bool accel_done() {
    return NEORV32_CFS.REG[ACCEL_STATUS_REG] & 0x1;
}

static inline int32_t accel_output() {
    union {
        int32_t i;
        uint32_t u;
    } pun = { .u = NEORV32_CFS.REG[ACCEL_OUTPUT_REG] };
    return pun.i;
}

static inline int32_t accel_conv1() {
    union {
        int32_t i;
        uint32_t u;
    } pun = { .u = NEORV32_CFS.REG[ACCEL_CONV1_REG] };
    return pun.i;
}

static inline int32_t accel_conv2() {
    union {
        int32_t i;
        uint32_t u;
    } pun = { .u = NEORV32_CFS.REG[ACCEL_CONV2_REG] };
    return pun.i;
}

static inline void accel_run() {
    accel_start();
    while(!accel_done()) {}
}


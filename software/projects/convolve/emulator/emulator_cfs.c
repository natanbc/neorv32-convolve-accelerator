#include "emulator_cfs.h"
#include <math.h>
#include <stdlib.h>
#include <stdio.h>

static int8_t matrix1[9];
static int8_t matrix2[9];
static uint8_t pixels[9];
static uint8_t mode;

static int32_t conv1;
static int32_t conv2;
static int32_t pixel;

static void print_matrix(void* v) {
    unsigned char* c = v;
    for(int i = 0; i < 3; i++) {
        for(int j = 0; j < 3; j++) {
            printf("0x%02x ", c[3*i+j]);
        }
        printf("\n");
    }
}

static int32_t conv(const uint8_t pixels[9], const int8_t matrix[9]) {
    int32_t res = 0;
    for(int i = 0; i < 9; i++) {
        res += pixels[i] * matrix[i];
    }
    return res;
}

static void cfs_run() {
    conv1 = conv(pixels, matrix1);
    conv2 = conv(pixels, matrix2);
    switch(mode) {
        case 0:
            pixel = abs(conv1) + abs(conv2);
            break;
        case 1:
            pixel = sqrt(conv1*conv1 + conv2*conv2);
            break;
        case 2:
            pixel = (int32_t)((uint32_t)conv1 | (uint32_t)conv2);
            break;
        case 3:
            pixel = (conv1 + conv2) / 2;
            break;
        default: //unreachable
            asm volatile("int3");
            break;
    }
}

uint32_t emulator_cfs_read(uint32_t reg) {
    switch(reg) {
        case 0: return 1;
        case 1: return pixel;
        case 2: return conv1;
        case 3: return conv2;
        default: return 0;
    }
}

void emulator_cfs_write(uint32_t reg, uint32_t val) {
#ifdef EMULATOR_TRACE_MMIO
    printf("CFS WRITE : %d=0x%08x (%d)\n", reg, val, val);
#endif
    switch(reg) {
        case 0: //ctrl
#ifdef EMULATOR_TRACE_MMIO
            printf("CTRL REG WRITE: %x (mode set=%d, mode=%d, start=%d)\n", val, (val >> 3) & 1, (val >> 1) & 3, val & 1);
#endif
            if(val & 0x8) mode = (val >> 1) & 0x3;
            if(val & 0x1) {
                cfs_run();
#ifdef EMULATOR_TRACE_MMIO
                printf("CFS RUN:\n");
                printf("matrix1:\n");
                print_matrix(matrix1);
                printf("matrix2:\n");
                print_matrix(matrix2);
                printf("pixels:\n");
                print_matrix(pixels);
                printf("res: conv1=%08x, conv2=%08x, pixel=%08x\n", (uint32_t)conv1, (uint32_t)conv2, (uint32_t)pixel);
#endif
            }
            break;
        case 1:
        case 2:
        case 3:
            {
                uint8_t* ptr = &pixels[(reg - 1) * 3];
                ptr[0] = val;
                ptr[1] = val >> 8;
                ptr[2] = val >> 16;
            }
            break;
        case 4:
        case 5:
        case 6:
            {
                uint8_t* ptr = &pixels[(reg - 4) * 3];
                ptr[0] = ptr[1];
                ptr[1] = ptr[2];
                ptr[2] = val;
            }
            break;
        case 7:
        case 8:
        case 9:
            {
                int8_t* ptr = &matrix1[(reg - 7) * 3];
                ptr[0] = (int8_t)(val & 0xFF);
                ptr[1] = (int8_t)((val >> 8) & 0xFF);
                ptr[2] = (int8_t)((val >> 16) & 0xFF);
            }
            break;
        case 10:
        case 11:
        case 12:
            {
                int8_t* ptr = &matrix2[(reg - 10) * 3];
                ptr[0] = (int8_t)(val & 0xFF);
                ptr[1] = (int8_t)((val >> 8) & 0xFF);
                ptr[2] = (int8_t)((val >> 16) & 0xFF);
            }
            break;
        default:
            break;
    }
}


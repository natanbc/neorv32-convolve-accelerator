#include "neorv32_emusupport.h"

#include "accel.h"
#include "sobel.h"
#include "hw_defs.h"
#include "image.h"

#define IM_HEIGHT   TEST_IMAGE_HEIGHT
#define IM_WIDTH    TEST_IMAGE_WIDTH
#define pixel_data  test_image

static uint16_t fletcher16(uint8_t* data, uint32_t count) {
    uint16_t sum1 = 0;
    uint16_t sum2 = 0;
    for(uint32_t i = 0; i < count; i++) {
        sum1 = (sum1 + data[i]) & 0xFF;
        sum2 = (sum2 + sum1) & 0xFF;
    }

    return (sum2 << 8) | sum1;
}

#define RUN_TEST(_FN,_TP,_MODE)                                                             \
    do {                                                                                    \
        neorv32_uart0_printf("Testing " #_FN " in mode " #_MODE "...");                     \
        accel_set_mode(_MODE);                                                              \
        _Static_assert(IM_WIDTH*IM_HEIGHT*sizeof(_TP) <= RAM_SIZE, "image too big");        \
        ctr_vals __elapsed = (_FN)((_TP*)RAM_ADDR, pixel_data, IM_WIDTH, IM_HEIGHT);        \
        neorv32_uart0_printf(" done\n");                                                    \
        uint16_t __cksum = fletcher16((uint8_t*)RAM_ADDR, IM_WIDTH*IM_HEIGHT*sizeof(_TP));  \
        neorv32_uart0_printf(                                                               \
            "checksum: %x, took %d instructions, %d cycles\n",                              \
            __cksum, __elapsed.instructions, __elapsed.cycles                               \
        );                                                                                  \
    } while(0)

#define RUN_TESTS(_MODE)                                                                    \
    do {                                                                                    \
        RUN_TEST(sobel_slow_u8,        uint8_t, _MODE);                                     \
        RUN_TEST(sobel_unrolled_u8,    uint8_t, _MODE);                                     \
        RUN_TEST(sobel_scratchbuf_u8,  uint8_t, _MODE);                                     \
        RUN_TEST(sobel_slow_i32,       int32_t, _MODE);                                     \
        RUN_TEST(sobel_unrolled_i32,   int32_t, _MODE);                                     \
        neorv32_uart0_printf("\n\n\n");                                                     \
    } while(0)


int main() {
    neorv32_rte_setup();
    neorv32_uart0_setup(19200, PARITY_NONE, FLOW_CONTROL_NONE);
    neorv32_rte_check_isa(0);

    RUN_TESTS(ACCEL_MERGE_SUM_ABS);
    RUN_TESTS(ACCEL_MERGE_SQRT_SUM_OF_SQUARES);
    RUN_TESTS(ACCEL_MERGE_BITWISE_OR);
    RUN_TESTS(ACCEL_MERGE_AVERAGE);

    return 0;
}


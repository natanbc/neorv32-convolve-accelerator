#pragma once
#include <stdint.h>

uint32_t emulator_cfs_read(uint32_t reg);

void emulator_cfs_write(uint32_t reg, uint32_t val);


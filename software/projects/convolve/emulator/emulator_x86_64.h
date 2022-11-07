#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef enum {
    OP_READ,
    OP_WRITE,
} mem_op;

typedef enum {
    TYPE_REGISTER,
    TYPE_IMMEDIATE,
} operand_type;

typedef struct {
    uint32_t val; // register number or imm
    mem_op op;
    operand_type type;
    uint8_t instruction_length;
} x86_64_access_op;

bool emulator_x86_64_decode(uintptr_t rip, x86_64_access_op* out, const char** err);


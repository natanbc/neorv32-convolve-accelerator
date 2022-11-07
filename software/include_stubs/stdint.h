#pragma once
#include <helper_static_assert.h>

typedef signed   char int8_t;
typedef unsigned char uint8_t;

static_assert(sizeof(int8_t) == 1,  "int8 should be 1 byte");
static_assert(sizeof(uint8_t) == 1, "uint8 should be 1 byte");

typedef signed   short int16_t;
typedef unsigned short uint16_t;

static_assert(sizeof(int16_t) == 2,  "int16 should be 2 bytes");
static_assert(sizeof(uint16_t) == 2, "uint16 should be 2 bytes");

typedef signed   int int32_t;
typedef unsigned int uint32_t;

static_assert(sizeof(int32_t) == 4,  "int32 should be 4 bytes");
static_assert(sizeof(uint32_t) == 4, "uint32 should be 4 bytes");

typedef signed   long long int64_t;
typedef unsigned long long uint64_t;

static_assert(sizeof(int64_t) == 8,  "int64 should be 8 bytes");
static_assert(sizeof(uint64_t) == 8, "uint64 should be 8 bytes");

static_assert(sizeof(void*) == 4, "pointers should be 4 bytes");

typedef int32_t  intptr_t;
typedef uint32_t uintptr_t;
typedef intptr_t ptrdiff_t;

typedef uint32_t size_t;


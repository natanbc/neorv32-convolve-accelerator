#define _GNU_SOURCE
#define __USE_GNU

#include "hw_defs.h"

#define CFS_BASE (0xfffffe00)

#include <sys/mman.h>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <ucontext.h>

#include "emulator_cfs.h"
#include "emulator_x86_64.h"

static __attribute__((noreturn)) void die(const char* msg) {
    fprintf(stderr, "%s\n", msg);
    fflush(stderr);
    _Exit(1);
}

static struct sigaction orig_act;

static void mmio_emu(int sig, siginfo_t* info, void* arg) {
    (void)sig;
    ucontext_t* uc = arg;
    mcontext_t* mc = &uc->uc_mcontext;

    uintptr_t rip = (uintptr_t)mc->gregs[REG_RIP];

    //wrong type of fault, let process get killed
    if(info->si_code != SEGV_ACCERR) {
#ifdef EMULATOR_DEBUG
        asm volatile("int3");
#else
        fprintf(stderr, "Unexpected SIGSEGV type %d at address %p, IP=%p, rethrowing\n", info->si_code, (void*)info->si_addr, (void*)rip);
        fflush(stderr);
        sigaction(SIGSEGV, &orig_act, 0);
#endif
        return;
    }

    uintptr_t addr = (uintptr_t)info->si_addr;
    //address not in an MMIO range we care about
    if(addr < CFS_BASE || addr > CFS_BASE + 32 * sizeof(uint32_t)) {
#ifdef EMULATOR_DEBUG
        asm volatile("int3");
#else
        fprintf(stderr, "Unexpected SIGSEGV fault address %p, IP=%p, rethrowing\n", (void*)addr, (void*)rip);
        fflush(stderr);
        sigaction(SIGSEGV, &orig_act, 0);
#endif
        return;
    }

    uint32_t cfs_reg = (addr - CFS_BASE) / sizeof(uint32_t);

    x86_64_access_op op;
    const char* decode_err;
    if(!emulator_x86_64_decode(rip, &op, &decode_err)) {
        fprintf(stderr, "Unsupported instruction for emulation at 0x%zx: %s\n", rip, decode_err);
        fprintf(stderr, "  bytes: ");
        for(uint8_t i = 0; i < 15; i++) {
            fprintf(stderr, "%02x", ((unsigned char*)rip)[i]);
        }
        fprintf(stderr, "\n");
        fflush(stderr);
#ifdef EMULATOR_DEBUG
        asm volatile("int3");
#endif
        _Exit(1);
    }

    if(op.op == OP_READ) {
        if(op.type != TYPE_REGISTER) {
            fprintf(stderr, "Got read op with non-register target at 0x%zu\n", rip);
            fprintf(stderr, "  bytes: ");
            for(uint8_t i = 0; i < op.instruction_length; i++) {
                fprintf(stderr, "%02x", ((unsigned char*)rip)[i]);
            }
            fprintf(stderr, "\n");
            fflush(stderr);
            _Exit(1);
        }
#ifdef EMULATOR_TRACE_MMIO
        printf("cfs[%u] read,  type: reg, val: %08x, inst len: %d\n", cfs_reg, op.val, op.instruction_length);
#endif
        mc->gregs[op.val] = emulator_cfs_read(cfs_reg);
    } else {
#ifdef EMULATOR_TRACE_MMIO
        printf("cfs[%u] write, type: %s, val: %08x, inst len: %d\n", cfs_reg, op.type == TYPE_REGISTER ? "reg" : "imm", op.val, op.instruction_length);
#endif
        emulator_cfs_write(cfs_reg, op.type == TYPE_REGISTER ? mc->gregs[op.val] : op.val);
    }

    //skip over it, we'd just fault forever on the same instruction otherwise
    mc->gregs[REG_RIP] += op.instruction_length;
}

__attribute__((constructor)) static void emulator_init() {
    if(mmap((void*)RAM_ADDR, RAM_SIZE, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED_NOREPLACE, -1, 0) == MAP_FAILED) {
        die("Unable to map SRAM");
    }
    if(mmap((void*)(CFS_BASE & ~0xfff), 4096, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED_NOREPLACE, -1, 0) == MAP_FAILED) {
        die("Unable to map MMIO region");
    }

    size_t stack_size = 65536;
    void* stack = mmap(0, stack_size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
    if(stack == MAP_FAILED) {
        die("Unable to allocate signal altstack");
    }

    stack_t s = {
        .ss_sp = stack,
        .ss_size = stack_size,
    };
    sigaltstack(&s, 0);

    struct sigaction act = {
        .sa_sigaction = mmio_emu,
        .sa_flags = SA_SIGINFO | SA_ONSTACK,
    };
    sigaction(SIGSEGV, &act, &orig_act);
}


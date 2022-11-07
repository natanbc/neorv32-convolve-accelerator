#define _GNU_SOURCE
#define __USE_GNU
#include <ucontext.h>


#include "emulator_x86_64.h"
#include "xed/xed-interface.h"
#include <stdio.h>

__attribute__((constructor)) static void init() {
    xed_tables_init();
}

static const char* set_imm(x86_64_access_op* out, unsigned int operand, const xed_decoded_inst_t* xedd) {
    //immediates are always writes
    out->op = OP_WRITE;
    out->type = TYPE_IMMEDIATE;

    const xed_inst_t* xi = xed_decoded_inst_inst(xedd);
    const xed_operand_t* op = xed_inst_operand(xi, operand);

    xed_operand_enum_t op_name = xed_operand_name(op);

    if(op_name == XED_OPERAND_IMM0) {
        xed_uint_t ibits = xed_decoded_inst_get_immediate_width_bits(xedd);
        if(ibits > 32) {
            return "IMM0 greater than 32 bits";
        }

        if(xed_decoded_inst_get_immediate_is_signed(xedd)) {
            out->val = (uint32_t)xed_decoded_inst_get_signed_immediate(xedd);
        } else {
            out->val = xed_decoded_inst_get_unsigned_immediate(xedd);
        }
    } else if(op_name == XED_OPERAND_IMM1) {
        out->val = xed_decoded_inst_get_second_immediate(xedd);
    } else {
        return "Operand is not an immediate";
    }
    return 0;
}

static const char* set_reg(x86_64_access_op* out, unsigned int operand, const xed_decoded_inst_t* xedd) {
    out->type = TYPE_REGISTER;
    
    const xed_inst_t* xi = xed_decoded_inst_inst(xedd);
    const xed_operand_t* op = xed_inst_operand(xi, operand);

    xed_operand_enum_t op_name = xed_operand_name(op);

    switch(op_name) {
        case XED_OPERAND_REG0:
        case XED_OPERAND_REG1:
        case XED_OPERAND_REG2:
        case XED_OPERAND_REG3:
        case XED_OPERAND_REG4:
        case XED_OPERAND_REG5:
        case XED_OPERAND_REG6:
        case XED_OPERAND_REG7:
        case XED_OPERAND_REG8:
        case XED_OPERAND_BASE0:
        case XED_OPERAND_BASE1:
            xed_reg_enum_t r = xed_decoded_inst_get_reg(xedd, op_name);
            switch(r) {
#define REG_CASE(A,B) \
                case XED_REG_ ##A: out->val = REG_##B; break

                REG_CASE(EAX,RAX);
                REG_CASE(ECX,RCX);
                REG_CASE(EDX,RDX);
                REG_CASE(EBX,RBX);
                REG_CASE(ESP,RSP);
                REG_CASE(EBP,RBP);
                REG_CASE(ESI,RSI);
                REG_CASE(EDI,RDI);

                REG_CASE(R8D,R8);
                REG_CASE(R9D,R9);
                REG_CASE(R10D,R10);
                REG_CASE(R11D,R11);
                REG_CASE(R12D,R12);
                REG_CASE(R13D,R13);
                REG_CASE(R14D,R14);
                REG_CASE(R15D,R15);
                default:
                    return "Not a 32 bit GPR";
#undef REG_CASE
            }
            return 0;
        default:
            return "Operand is not a register";
    }
}

static const char* set_reg_r(x86_64_access_op* out, unsigned int operand, const xed_decoded_inst_t* xedd) {
    out->op = OP_READ;
    return set_reg(out, operand, xedd);
}

static const char* set_reg_w(x86_64_access_op* out, unsigned int operand, const xed_decoded_inst_t* xedd) {
    out->op = OP_WRITE;
    return set_reg(out, operand, xedd);
}

bool emulator_x86_64_decode(uintptr_t rip, x86_64_access_op* out, const char** err) {
    xed_state_t dstate;
    xed_state_zero(&dstate);
    dstate.mmode = XED_MACHINE_MODE_LONG_64;
    dstate.stack_addr_width = XED_ADDRESS_WIDTH_32b;

    xed_decoded_inst_t xedd;
    xed_decoded_inst_zero_set_mode(&xedd, &dstate);
    xed3_operand_set_mpxmode(&xedd, 0);
    xed3_operand_set_cet(&xedd, 0);
    //xed_decoded_inst_zero(&xedd);
    //xed_decoded_inst_set_mode(&xedd, XED_MACHINE_MODE_LONG_64, XED_ADDRESS_WIDTH_64b);
    //xed_decoded_inst_set_mode(&xedd, XED_MACHINE_MODE_LONG_64, XED_ADDRESS_WIDTH_32b);


    xed_error_enum_t xed_error = xed_decode(
        &xedd,
        XED_STATIC_CAST(const xed_uint8_t*, rip),
        XED_MAX_INSTRUCTION_BYTES
    );
    if(xed_error != XED_ERROR_NONE) {
        *err = xed_error_enum_t2str(xed_error);
        return false;
    }

    if(xed_decoded_inst_get_operand_width(&xedd) != 32) {
        *err = "Operand width is not 32 bits";
        return false;
    }
    out->instruction_length = xed_decoded_inst_get_length(&xedd);

    xed_iform_enum_t iform = xed_decoded_inst_get_iform_enum(&xedd);

    switch(iform) {
        // mov [mem], imm
        case XED_IFORM_MOV_MEMv_IMMz:
            return !(*err = set_imm(out, 1, &xedd));
        case XED_IFORM_MOV_MEMv_OrAX: // mov ds:[addr], gpr
        case XED_IFORM_MOV_MEMv_GPRv: // mov [addr], gpr
            return !(*err = set_reg_w(out, 1, &xedd));
        case XED_IFORM_MOV_OrAX_MEMv: // movabs gpr, ds:[addr]
        case XED_IFORM_MOV_GPRv_MEMv: // mov gpr, [addr]
            return !(*err = set_reg_r(out, 0, &xedd));
        default:
            break;
    }


    printf("unhandled instruction\n");
    printf("bytes: ");
    for(uint8_t i = 0; i < out->instruction_length; i++) {
        printf("%02x", ((unsigned char*)rip)[i]);
    }
    printf("\n");
    printf("iform: %s\n", xed_iform_enum_t2str(iform));


    *err = "Unimplemented";
    return false;
}


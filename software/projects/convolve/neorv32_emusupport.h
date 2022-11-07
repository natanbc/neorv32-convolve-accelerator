#pragma once

#ifdef EMULATOR

#include <stdio.h>
#define neorv32_uart0_printf(...) do { printf(__VA_ARGS__); fflush(stdout); } while(0)
#define neorv32_rte_setup(...)
#define neorv32_uart0_setup(...)
#define neorv32_rte_check_isa(...)

//--------------------------------- copied from neorv32.h for emulator support --------------------------------
#include <stdint.h>
/**********************************************************************//**
 * @name IO Device: Custom Functions Subsystem (CFS)
 **************************************************************************/
/**@{*/
/** CFS module prototype */
typedef struct __attribute__((packed,aligned(4))) {
  uint32_t REG[32]; /**< offset 4*0..4*31: CFS register 0..31, user-defined */
} neorv32_cfs_t;

/** CFS base address */
#define NEORV32_CFS_BASE (0xFFFFFE00U)

/** CFS module hardware access (#neorv32_cfs_t) */
#define NEORV32_CFS (*((volatile neorv32_cfs_t*) (NEORV32_CFS_BASE)))
/**@}*/
//--------------------------------- copied from neorv32.h for emulator support --------------------------------

#else

#include <neorv32.h>

#endif


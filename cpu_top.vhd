library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity cpu is
  generic (
    -- adapt these for your setup --
    CLOCK_FREQUENCY   : natural := 50000000;  -- clock frequency of clk_i in Hz
    MEM_INT_IMEM_SIZE : natural := 32*1024;   -- size of processor-internal instruction memory in bytes
    MEM_INT_DMEM_SIZE : natural := 32*1024     -- size of processor-internal data memory in bytes
  );
  port (
    -- Global control --
    clk_i       : in  std_ulogic; -- global clock, rising edge
    rstn_i      : in  std_ulogic; -- global reset, low-active, async
    -- GPIO --
    gpio_o      : out std_ulogic_vector(7 downto 0); -- parallel output
    -- UART0 --
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in  std_ulogic  -- UART0 receive data
  );
end entity;

architecture cpu_rtl of cpu is

  signal con_gpio_o : std_ulogic_vector(63 downto 0);

begin

  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => CLOCK_FREQUENCY,
    INT_BOOTLOADER_EN            => true,
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_C        => true,
    CPU_EXTENSION_RISCV_M        => true,
    CPU_EXTENSION_RISCV_Zicsr    => true,
    CPU_EXTENSION_RISCV_Zicntr   => true,
     
    FAST_MUL_EN                  => true,
    FAST_SHIFT_EN                => true,
    -- Internal Instruction memory --
    MEM_INT_IMEM_EN              => true,
    MEM_INT_IMEM_SIZE            => MEM_INT_IMEM_SIZE,
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => true,
    MEM_INT_DMEM_SIZE            => MEM_INT_DMEM_SIZE,
    -- Processor peripherals --
    IO_CFS_EN                    => true, -- convolution operation
    IO_GPIO_EN                   => true,
    IO_MTIME_EN                  => true,
    IO_UART0_EN                  => true
  )
  port map (
    -- Global control --
    clk_i       => clk_i,       -- global clock, rising edge
    rstn_i      => rstn_i,      -- global reset, low-active, async
    -- GPIO (available if IO_GPIO_EN = true) --
    gpio_o      => con_gpio_o,  -- parallel output
    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o, -- UART0 send data
    uart0_rxd_i => uart0_rxd_i  -- UART0 receive data
  );

  -- GPIO output --
  gpio_o <= con_gpio_o(7 downto 0);


end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity cpu is
  generic (
    -- adapt these for your setup --
    CLOCK_FREQUENCY   : natural := 95000000;   -- clock frequency of clk_i in Hz
    MEM_INT_IMEM_SIZE : natural := 32*1024;    -- size of processor-internal instruction memory in bytes
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
    uart0_rxd_i : in  std_ulogic; -- UART0 receive data

    sram_addr : out std_ulogic_vector(19 downto 0);
    sram_dq   : inout std_ulogic_vector(15 downto 0);
    sram_oe_n : out std_ulogic;
    sram_we_n : out std_ulogic;
    sram_ce_n : out std_ulogic;
    sram_lb_n : out std_ulogic;
    sram_hb_n : out std_ulogic
  );
end entity;

architecture cpu_rtl of cpu is

  signal pll_out : std_ulogic;
  signal pll_out_dram : std_ulogic;
  signal pll_locked : std_ulogic;
  signal con_gpio_o : std_ulogic_vector(63 downto 0);

  signal wb_adr       : std_ulogic_vector(31 downto 0);
  signal wb_dat_read  : std_ulogic_vector(31 downto 0);
  signal wb_dat_write : std_ulogic_vector(31 downto 0);
  signal wb_we        : std_ulogic;
  signal wb_sel       : std_ulogic_vector(3 downto 0);
  signal wb_stb       : std_ulogic;
  signal wb_cyc       : std_ulogic;
  signal wb_ack       : std_ulogic;
  signal wb_err       : std_ulogic;

  signal wb_sram_enable : std_ulogic;
  -- TO sram
  signal wb_sram_addr   : std_ulogic_vector(20 downto 0);
  signal wb_sram_out    : std_ulogic_vector(31 downto 0);
  signal wb_sram_we     : std_ulogic;
  signal wb_sram_stb    : std_ulogic;
  signal wb_sram_cyc    : std_ulogic;
  -- FROM sram
  signal wb_sram_in     : std_ulogic_vector(31 downto 0);
  signal wb_sram_ack    : std_ulogic;

  component pll is
    port (
      inclk0 : in std_logic;
      c0     : out std_logic;
      c1     : out std_logic;
      locked : out std_logic
    );
  end component pll;

  component sram_controller is
    port (
      clk    : in std_ulogic;
      rst    : in std_ulogic;
      -- Wishbone in
      addr_i : in std_ulogic_vector(20 downto 0);
      sel_i  : in std_ulogic_vector(3 downto 0);
      data_i : in std_ulogic_vector(31 downto 0);
      stb_i  : in std_ulogic;
      cyc_i  : in std_ulogic;
      we_i   : in std_ulogic;

      -- Wishbone out
      data_o : out std_ulogic_vector(31 downto 0);
      ack_o  : out std_ulogic;

      -- SRAM IO
      sram_addr : out std_ulogic_vector(19 downto 0);
      sram_dq   : inout std_ulogic_vector(15 downto 0);
      sram_oe_n : out std_ulogic;
      sram_we_n : out std_ulogic;
      sram_ce_n : out std_ulogic;
      sram_lb_n : out std_ulogic;
      sram_hb_n : out std_ulogic
    );
  end component sram_controller;

begin

  pll_inst : pll
  port map (
    inclk0 => clk_i,
    c0     => pll_out,
    c1     => pll_out_dram,
    locked => pll_locked
  );

  sram_inst : sram_controller
  port map(
    clk => pll_out,
    rst => rstn_i,

    addr_i => wb_sram_addr,
    sel_i  => wb_sel,
    data_i => wb_sram_out,
    stb_i  => wb_sram_stb,
    cyc_i  => wb_sram_cyc,
    we_i   => wb_sram_we,

    data_o => wb_sram_in,
    ack_o  => wb_sram_ack,

    sram_addr => sram_addr,
    sram_dq   => sram_dq,
    sram_oe_n => sram_oe_n,
    sram_we_n => sram_we_n,
    sram_ce_n => sram_ce_n,
    sram_lb_n => sram_lb_n,
    sram_hb_n => sram_hb_n
  );

  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => CLOCK_FREQUENCY,
    INT_BOOTLOADER_EN            => true,
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_B        => true,
    CPU_EXTENSION_RISCV_C        => true,
    CPU_EXTENSION_RISCV_M        => true,
    CPU_EXTENSION_RISCV_Zicsr    => true,
    CPU_EXTENSION_RISCV_Zicntr   => true,

    FAST_MUL_EN                  => true,
    FAST_SHIFT_EN                => true,

    ICACHE_EN                    => true,
    ICACHE_NUM_BLOCKS            => 8,
    ICACHE_BLOCK_SIZE            => 32,
    ICACHE_ASSOCIATIVITY         => 2,

    CPU_IPB_ENTRIES              => 4,

    -- Internal Instruction memory --
    MEM_INT_IMEM_EN              => true,
    MEM_INT_IMEM_SIZE            => MEM_INT_IMEM_SIZE,
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => true,
    MEM_INT_DMEM_SIZE            => MEM_INT_DMEM_SIZE,
    -- External Memory --
    MEM_EXT_EN                   => true,
    MEM_EXT_TIMEOUT              => 32,
    MEM_EXT_PIPE_MODE            => false,
    MEM_EXT_ASYNC_RX             => false,
    MEM_EXT_ASYNC_TX             => false,
    -- Processor peripherals --
    IO_CFS_EN                    => true, -- convolution operation
    IO_GPIO_EN                   => true,
    IO_UART0_EN                  => true
  )
  port map (
    -- Global control --
    clk_i       => pll_out,     -- global clock, rising edge
    rstn_i      => rstn_i,      -- global reset, low-active, async
    -- GPIO (available if IO_GPIO_EN = true) --
    gpio_o      => con_gpio_o,  -- parallel output
    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o, -- UART0 send data
    uart0_rxd_i => uart0_rxd_i, -- UART0 receive data
    -- Wishbone --
    wb_tag_o    => open,
    wb_adr_o    => wb_adr,
    wb_dat_i    => wb_dat_read,
    wb_dat_o    => wb_dat_write,
    wb_we_o     => wb_we,
    wb_sel_o    => wb_sel,
    wb_stb_o    => wb_stb,
    wb_cyc_o    => wb_cyc,
    wb_ack_i    => wb_ack,
    wb_err_i    => wb_err
  );

  -- GPIO output --
  gpio_o <= con_gpio_o(7 downto 0);

  -- Wishbone SDRAM interconnect --
  -- TO dram
  wb_sram_enable <= '1' when (wb_adr(31 downto 28) = x"9") and (wb_adr(27 downto 21) = "0000000") else '0';
  wb_err         <= wb_stb and not wb_sram_enable;

  wb_sram_addr   <= wb_adr(20 downto 0);
  wb_sram_out    <= wb_dat_write;
  wb_sram_we     <= wb_we;
  wb_sram_stb    <= wb_sram_enable and wb_stb;
  wb_sram_cyc    <= wb_cyc;

  -- FROM dram
  wb_dat_read    <= wb_sram_in when (wb_sram_enable = '1') else (others => '0');
  wb_ack         <= wb_sram_ack;

end architecture;

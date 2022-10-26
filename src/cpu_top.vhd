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

    dram_addr   : out std_logic_vector(12 downto 0);
    dram_bank   : out std_logic_vector(1 downto 0);
    dram_cas_n  : out std_logic;
    dram_ras_n  : out std_logic;
    dram_cke    : out std_logic;
    dram_clk    : out std_logic;
    dram_cs_n   : out std_logic;
    dram_dq     : inout std_logic_vector(31 downto 0);
    dram_dqm    : out std_logic_vector(3 downto 0);
    dram_we_n   : out std_logic
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

  signal wb_dram_enable : std_logic;
  signal wb_dram_addr   : std_logic_vector(22 downto 0);
  -- TO dram
  signal wb_dram_out    : std_logic_vector(31 downto 0);
  -- FROM dram
  signal wb_dram_in     : std_logic_vector(31 downto 0);
  signal wb_dram_we     : std_logic;
  signal wb_dram_ack    : std_logic;
  signal wb_dram_stb    : std_logic;
  signal wb_dram_cyc    : std_logic;

  component pll is
    port (
      inclk0 : in std_logic;
      c0     : out std_logic;
      c1     : out std_logic;
      locked : out std_logic
    );
  end component pll;

  component sdram_controller is
  port (
    clk        : in std_logic;
    clk_dram   : in std_logic;
    rst        : in std_logic;
    dll_locked : in std_logic;
    -- DRAM signals
    dram_addr  : out std_logic_vector(12 downto 0);
    dram_bank  : out std_logic_vector(1 downto 0);
    dram_cas_n : out std_logic;
    dram_ras_n : out std_logic;
    dram_cke   : out std_logic;
    dram_clk   : out std_logic;
    dram_cs_n  : out std_logic;
    dram_dq    : inout std_logic_vector(31 downto 0);
    dram_dqm   : out std_logic_vector(3 downto 0);
    dram_we_n  : out std_logic;
    --wishbone
    addr_i     : in std_logic_vector(22 downto 0);
    dat_i      : in std_logic_vector(31 downto 0);
    dat_o      : out std_logic_vector(31 downto 0);
    we_i       : in std_logic;
    ack_o      : out std_logic;
    stb_i      : in std_logic;
    cyc_i      : in std_logic);
  end component sdram_controller;

begin

  pll_inst : pll
  port map (
    inclk0 => clk_i,
    c0     => pll_out,
    c1     => pll_out_dram,
    locked => pll_locked
  );

  sdram_inst : sdram_controller
  port map (
    clk        => pll_out,
    clk_dram   => pll_out_dram,
    rst        => rstn_i,
    dll_locked => pll_locked,

    dram_addr  => dram_addr,
    dram_bank  => dram_bank,
    dram_cas_n => dram_cas_n,
    dram_ras_n => dram_ras_n,
    dram_cke   => dram_cke,
    dram_clk   => dram_clk,
    dram_cs_n  => dram_cs_n,
    dram_dq    => dram_dq,
    dram_dqm   => dram_dqm,
    dram_we_n  => dram_we_n,

    addr_i     => wb_dram_addr,
    dat_i      => wb_dram_out,  -- wb_dram_out is TO dram
    dat_o      => wb_dram_in,   -- wb_dram_in is FROM dram
    we_i       => wb_dram_we,
    ack_o      => wb_dram_ack,
    stb_i      => wb_dram_stb,
    cyc_i      => wb_dram_cyc
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

    -- Internal Instruction memory --
    MEM_INT_IMEM_EN              => true,
    MEM_INT_IMEM_SIZE            => MEM_INT_IMEM_SIZE,
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => true,
    MEM_INT_DMEM_SIZE            => MEM_INT_DMEM_SIZE,
    -- External Memory --
    MEM_EXT_EN                   => true,
    MEM_EXT_TIMEOUT              => 1000,
    MEM_EXT_PIPE_MODE            => true,
    MEM_EXT_ASYNC_RX             => true,
    MEM_EXT_ASYNC_TX             => true,
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
    wb_err_i    => '0'
  );

  -- GPIO output --
  gpio_o <= con_gpio_o(7 downto 0);

  -- Wishbone SDRAM interconnect --
  -- TO dram
  wb_dram_enable <= '1' when (wb_adr(31 downto 23) = x"900000") else '0';
  wb_dram_addr   <= std_logic_vector(wb_adr(22 downto 0));
  wb_dram_out    <= std_logic_vector(wb_dat_write);
  wb_dram_we     <= wb_we;
  wb_dram_stb    <= wb_dram_enable and wb_stb;
  wb_dram_cyc    <= wb_cyc;

  -- FROM dram
  wb_dat_read    <= std_ulogic_vector(wb_dram_in) when (wb_dram_enable = '1') else (others => '0');
  wb_ack         <= wb_dram_ack;

end architecture;

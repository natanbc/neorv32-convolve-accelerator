library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_cfs is
  generic (
    PARALLEL     : boolean := true;
    CFS_CONFIG   : std_ulogic_vector(31 downto 0);
    CFS_IN_SIZE  : positive;
    CFS_OUT_SIZE : positive
  );
  port (
    -- host access --
    clk_i       : in  std_ulogic;
    rstn_i      : in  std_ulogic;
    priv_i      : in  std_ulogic;
    addr_i      : in  std_ulogic_vector(31 downto 0);
    rden_i      : in  std_ulogic;
    wren_i      : in  std_ulogic;
    data_i      : in  std_ulogic_vector(31 downto 0);
    data_o      : out std_ulogic_vector(31 downto 0);
    ack_o       : out std_ulogic;
    err_o       : out std_ulogic;
    -- clock generator --
    clkgen_en_o : out std_ulogic;
    clkgen_i    : in  std_ulogic_vector(07 downto 0);
    -- interrupt --
    irq_o       : out std_ulogic;
    -- custom io (conduits) --
    cfs_in_i    : in  std_ulogic_vector(CFS_IN_SIZE-1 downto 0);
    cfs_out_o   : out std_ulogic_vector(CFS_OUT_SIZE-1 downto 0)
  );
end neorv32_cfs;

architecture neorv32_cfs_rtl of neorv32_cfs is

  -- IO space: module base address --
  -- WARNING: Do not modify the CFS base address or the CFS' occupied address
  -- space as this might cause access collisions with other processor modules.
  constant hi_abb_c : natural := index_size_f(io_size_c)-1; -- high address boundary bit
  constant lo_abb_c : natural := index_size_f(cfs_size_c); -- low address boundary bit

  -- access control --
  signal acc_en : std_ulogic; -- module access enable
  signal addr   : std_ulogic_vector(31 downto 0); -- access address
  signal wren   : std_ulogic; -- word write enable
  signal rden   : std_ulogic; -- read enable

  type pixel_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
  type matrix_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
  type conv_merge_mode_t is range 0 to 3;
  
  signal input_start   : std_ulogic;
  signal input_pixels  : pixel_regs_t;
  signal input_matrix1 : matrix_regs_t;
  signal input_matrix2 : matrix_regs_t;
  signal input_mode    : conv_merge_mode_t;
  signal output_conv1  : std_ulogic_vector(31 downto 0);
  signal output_conv2  : std_ulogic_vector(31 downto 0);
  signal output_pixel  : std_ulogic_vector(31 downto 0);
  signal output_done   : std_ulogic;

  component convolve_parallel is
    port (
      clk           : in std_ulogic;
      rst           : in std_ulogic;
      input_start   : in std_ulogic;
      input_pixels  : in pixel_regs_t;
      input_matrix1 : in matrix_regs_t;
      input_matrix2 : in matrix_regs_t;
      input_mode    : in conv_merge_mode_t;
      output_conv1  : out std_ulogic_vector(31 downto 0);
      output_conv2  : out std_ulogic_vector(31 downto 0);
      output_pixel  : out std_ulogic_vector(31 downto 0);
      output_done   : out std_ulogic
    );
  end component convolve_parallel;

  component convolve_serial is
    port (
      clk           : in std_ulogic;
      rst           : in std_ulogic;
      input_start   : in std_ulogic;
      input_pixels  : in pixel_regs_t;
      input_matrix1 : in matrix_regs_t;
      input_matrix2 : in matrix_regs_t;
      input_mode    : in conv_merge_mode_t;
      output_conv1  : out std_ulogic_vector(31 downto 0);
      output_conv2  : out std_ulogic_vector(31 downto 0);
      output_pixel  : out std_ulogic_vector(31 downto 0);
      output_done   : out std_ulogic
    );
  end component convolve_serial;
begin

  -- Access Control -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- This logic is required to handle the CPU accesses - DO NOT MODIFY!
  acc_en <= '1' when (addr_i(hi_abb_c downto lo_abb_c) = cfs_base_c(hi_abb_c downto lo_abb_c)) else '0';
  addr   <= cfs_base_c(31 downto lo_abb_c) & addr_i(lo_abb_c-1 downto 2) & "00"; -- word aligned
  wren   <= acc_en and wren_i; -- only full-word write accesses are supported
  rden   <= acc_en and rden_i; -- read accesses always return a full 32-bit word
  -- -------------------------------------------------------------------------------------------

  cfs_out_o <= (others => '0'); -- outside IO not used

  clkgen_en_o <= '0'; -- custom clock not used

  irq_o <= '0'; -- IRQs not used

  err_o <= '0'; -- no errors possible
  
  convolve_parallel_true: if (PARALLEL = true) generate
    convolve_impl: convolve_parallel
    port map (
      clk           => clk_i,
      rst           => rstn_i,
      input_start   => input_start,
      input_pixels  => input_pixels,
      input_matrix1 => input_matrix1,
      input_matrix2 => input_matrix2,
      input_mode    => input_mode,
      output_conv1  => output_conv1,
      output_conv2  => output_conv2,
      output_pixel  => output_pixel,
      output_done   => output_done
    );
  end generate;
  
  convolve_parallel_false: if (PARALLEL = false) generate
    convolve_impl: convolve_serial
    port map (
      clk           => clk_i,
      rst           => rstn_i,
      input_start   => input_start,
      input_pixels  => input_pixels,
      input_matrix1 => input_matrix1,
      input_matrix2 => input_matrix2,
      input_mode    => input_mode,
      output_conv1  => output_conv1,
      output_conv2  => output_conv2,
      output_pixel  => output_pixel,
      output_done   => output_done
    );
  end generate;

  host_access: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      input_pixels  <= (others => (others => '0'));
      input_matrix1 <= (others => (others => '0'));
      input_matrix2 <= (others => (others => '0'));
      --
      ack_o  <= '-'; -- no actual reset required
      data_o <= (others => '-'); -- no actual reset required
    elsif rising_edge(clk_i) then -- synchronous interface for read and write accesses
      -- transfer/access acknowledge --
      -- default: required for the CPU to check the CFS is answering a bus read OR write request;
      -- all read and write accesses (to any cfs_reg, even if there is no according physical register implemented) will succeed.
      ack_o <= rden or wren;

      input_start <= '0';
      -- write access --
      if (wren = '1') then
        -- control register
        if (addr = cfs_reg0_addr_c) then
          input_start <= data_i(0);
          case data_i(2 downto 1) is
            when "00" =>
              input_mode <= 0;
            when "01" =>
              input_mode <= 1;
            when "10" =>
              input_mode <= 2;
            when "11" =>
              input_mode <= 3;
          end case;
        end if;
        -- pixel load registers
        if (addr = cfs_reg1_addr_c) then
          input_pixels(0) <= data_i(7 downto 0);
          input_pixels(1) <= data_i(15 downto 8);
          input_pixels(2) <= data_i(23 downto 16);
        end if;
        if (addr = cfs_reg2_addr_c) then
          input_pixels(3) <= data_i(7 downto 0);
          input_pixels(4) <= data_i(15 downto 8);
          input_pixels(5) <= data_i(23 downto 16);
        end if;
        if (addr = cfs_reg3_addr_c) then
          input_pixels(6) <= data_i(7 downto 0);
          input_pixels(7) <= data_i(15 downto 8);
          input_pixels(8) <= data_i(23 downto 16);
        end if;
        -- pixel shift registers
        if (addr = cfs_reg4_addr_c) then
          input_pixels(0) <= input_pixels(1);
          input_pixels(1) <= input_pixels(2);
          input_pixels(2) <= data_i(7 downto 0);
        end if;
        if (addr = cfs_reg5_addr_c) then
          input_pixels(3) <= input_pixels(4);
          input_pixels(4) <= input_pixels(5);
          input_pixels(5) <= data_i(7 downto 0);
        end if;
        if (addr = cfs_reg6_addr_c) then
          input_pixels(6) <= input_pixels(7);
          input_pixels(7) <= input_pixels(8);
          input_pixels(8) <= data_i(7 downto 0);
        end if;
        -- matrix load registers
        if (addr = cfs_reg7_addr_c) then
          input_matrix1(0) <= data_i(7 downto 0);
          input_matrix1(1) <= data_i(15 downto 8);
          input_matrix1(2) <= data_i(23 downto 16);
        end if;
        if (addr = cfs_reg8_addr_c) then
          input_matrix1(3) <= data_i(7 downto 0);
          input_matrix1(4) <= data_i(15 downto 8);
          input_matrix1(5) <= data_i(23 downto 16);
        end if;
        if (addr = cfs_reg9_addr_c) then
          input_matrix1(6) <= data_i(7 downto 0);
          input_matrix1(7) <= data_i(15 downto 8);
          input_matrix1(8) <= data_i(23 downto 16);
        end if;
        if (addr = cfs_reg10_addr_c) then
          input_matrix2(0) <= data_i(7 downto 0);
          input_matrix2(1) <= data_i(15 downto 8);
          input_matrix2(2) <= data_i(23 downto 16);
        end if;
        if (addr = cfs_reg11_addr_c) then
          input_matrix2(3) <= data_i(7 downto 0);
          input_matrix2(4) <= data_i(15 downto 8);
          input_matrix2(5) <= data_i(23 downto 16);
        end if;
        if (addr = cfs_reg12_addr_c) then
          input_matrix2(6) <= data_i(7 downto 0);
          input_matrix2(7) <= data_i(15 downto 8);
          input_matrix2(8) <= data_i(23 downto 16);
        end if;
      end if;

      -- read access --
      data_o <= (others => '0');
      if (rden = '1') then
        case addr is
          -- status register
          when cfs_reg0_addr_c => data_o(0) <= output_done;
          -- output registers
          when cfs_reg1_addr_c => data_o <= output_pixel;
          when cfs_reg2_addr_c => data_o <= output_conv1;
          when cfs_reg3_addr_c => data_o <= output_conv2;
          when others          => data_o <= (others => '0');
        end case;
      end if;
    end if;
  end process host_access;

end neorv32_cfs_rtl;

library ieee;
use ieee.std_logic_1164.all;

package convolve_pkg is
  type pixel_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
  type matrix_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.convolve_pkg.all;

entity convolve is
  generic (
    PIPELINED : boolean
  );
  port (
    clk          : in std_ulogic;
    rst          : in std_ulogic;
    input_start  : in std_ulogic;
    input_pixels : in pixel_regs_t;
    input_matrix : in matrix_regs_t;
    output_pixel : out std_ulogic_vector(31 downto 0);
    output_done  : out std_ulogic
  );
end convolve;

architecture convolve_rtl of convolve is
  component convolve_single_cycle is
  port (
    clk          : in std_ulogic;
    rst          : in std_ulogic;
    input_start  : in std_ulogic;
    input_pixels : in pixel_regs_t;
    input_matrix : in matrix_regs_t;
    output_pixel : out std_ulogic_vector(31 downto 0);
    output_done  : out std_ulogic
  );
  end component convolve_single_cycle;
  
  component convolve_pipelined is
  port (
    clk          : in std_ulogic;
    rst          : in std_ulogic;
    input_start  : in std_ulogic;
    input_pixels : in pixel_regs_t;
    input_matrix : in matrix_regs_t;
    output_pixel : out std_ulogic_vector(31 downto 0);
    output_done  : out std_ulogic
  );
  end component convolve_pipelined;
begin
  convolve_pipelined_true:
  if (PIPELINED = true) generate
    convolve_impl: convolve_pipelined
    port map (
      clk          => clk,
      rst          => rst,
      input_start  => input_start,
      input_pixels => input_pixels,
      input_matrix => input_matrix,
      output_pixel => output_pixel,
      output_done  => output_done
    );
  end generate;
  
  convolve_pipelined_false:
  if (PIPELINED = false) generate
    convolve_impl: convolve_single_cycle
    port map (
      clk          => clk,
      rst          => rst,
      input_start  => input_start,
      input_pixels => input_pixels,
      input_matrix => input_matrix,
      output_pixel => output_pixel,
      output_done  => output_done
    );
  end generate;
end convolve_rtl;

library ieee;
use ieee.std_logic_1164.all;

package convolve_pkg is
  type pixel_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
  type matrix_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
  type conv_merge_mode_t is range 0 to 3;

  constant conv_merge_none                : conv_merge_mode_t := 0;
  constant conv_merge_sqrt_sum_of_squares : conv_merge_mode_t := 1;
  constant conv_merge_or                  : conv_merge_mode_t := 2;
  constant conv_merge_avg                 : conv_merge_mode_t := 3;
end package;


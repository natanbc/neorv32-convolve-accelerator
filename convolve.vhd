library ieee;
use ieee.std_logic_1164.all;

package convolve_pkg is
  type pixel_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
  type matrix_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
end package;


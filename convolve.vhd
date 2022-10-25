library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package convolve_pkg is
  type pixel_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
  type matrix_regs_t is array (0 to 8) of std_ulogic_vector(7 downto 0);
  type conv_merge_mode_t is range 0 to 3;

  constant conv_merge_sum_abs             : conv_merge_mode_t := 0;
  constant conv_merge_sqrt_sum_of_squares : conv_merge_mode_t := 1;
  constant conv_merge_or                  : conv_merge_mode_t := 2;
  constant conv_merge_avg                 : conv_merge_mode_t := 3;

  pure function conv_abs(v : integer) return integer;
end package;

package body convolve_pkg is
  -- work around abs() yiellding 'error: unhandled monadic: IIR_PREDEFINED_INTEGER_ABSOLUTE'
  pure function conv_abs(v : integer) return integer is
    variable res : integer;
  begin
    if (v < 0) then
      res := -v;
    else
      res := v;
    end if;
    return res;
  end function conv_abs;
end convolve_pkg;


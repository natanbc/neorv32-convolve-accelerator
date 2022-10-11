library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.convolve_pkg.all;

entity convolve_single_cycle is
  port (
    clk          : in std_ulogic;
    rst          : in std_ulogic;
    input_start  : in std_ulogic;
    input_pixels : in pixel_regs_t;
    input_matrix : in matrix_regs_t;
    output_pixel : out std_ulogic_vector(31 downto 0);
    output_done  : out std_ulogic
  );
end convolve_single_cycle;

architecture convolve_single_cycle_rtl of convolve_single_cycle is
begin
  process(clk)
    type mult_acc_t is array (0 to 8) of integer;
    variable stage1 : mult_acc_t;
    variable stage2 : integer;
  begin
    if rising_edge(clk) then
      for i in 0 to 8 loop
        stage1(i) := to_integer(unsigned(input_pixels(i))) * to_integer(signed(input_matrix(i)));
      end loop;
      stage2 := stage1(0) + stage1(1) + stage1(2) + stage1(3) + stage1(4) +
                stage1(5) + stage1(6) + stage1(7) + stage1(8);
      output_pixel <= std_ulogic_vector(to_signed(stage2, 32));
      output_done <= '1';
    end if;
  end process; 
end convolve_single_cycle_rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.convolve_pkg.all;

entity convolve_pipelined is
  port (
    clk          : in std_ulogic;
    rst          : in std_ulogic;
    input_start  : in std_ulogic;
    input_pixels : in pixel_regs_t;
    input_matrix : in matrix_regs_t;
    output_pixel : out std_ulogic_vector(31 downto 0);
    output_done  : out std_ulogic
  );
end convolve_pipelined;

architecture convolve_pipelined_rtl of convolve_pipelined is
  type mult_acc_t is array (0 to 8) of integer;
  signal stage1 : mult_acc_t;
  signal stage2 : integer;
  -- 0: "idle"
  -- 1: multiply
  -- 2: adds
  -- 3: write
  signal step : integer range 0 to 3;
begin
  process(clk)
    
  begin
    if (rst = '0') then
      stage1 <= (others => 0);
      stage2 <= 0;
      step   <= 0;
    elsif rising_edge(clk) then
      if (input_start = '1') then
        step <= 1;
      elsif (step < 3) then
        step <= step + 1;
      end if;
      output_pixel <= std_ulogic_vector(to_signed(stage2, 32));
      stage2 <= stage1(0) + stage1(1) + stage1(2) + stage1(3) + stage1(4) +
                stage1(5) + stage1(6) + stage1(7) + stage1(8);
      for i in 0 to 8 loop
        stage1(i) <= to_integer(unsigned(input_pixels(i))) * to_integer(signed(input_matrix(i)));
      end loop;

      if (step = 3) then
        output_done <= '1';
      end if;
    end if;
  end process; 
end convolve_pipelined_rtl;

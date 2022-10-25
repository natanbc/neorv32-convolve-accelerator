library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.convolve_pkg.all;

entity convolve_parallel is
  generic (
    sqrt_in_bits : natural := 22
  );
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
end convolve_parallel;

architecture convolve_parallel_rtl of convolve_parallel is
  constant sqrt_out_bits : natural := sqrt_in_bits / 2;

  type state is (idle, multiply, reduce1, reduce2, square, sqrt, sqrt_wait0, sqrt_wait, calc_abs, done);
  signal step : state;

  signal saved_mode : conv_merge_mode_t;

  type multiply_result is array (0 to 8) of integer;
  signal multiply_res_1 : multiply_result;
  signal multiply_res_2 : multiply_result;

  type reduce1_result is array (0 to 1) of integer;
  signal reduce1_res_1 : reduce1_result;
  signal reduce1_res_2 : reduce1_result;

  signal reduce2_res_1 : integer;
  signal reduce2_res_2 : integer;

  signal square_res_1 : integer;
  signal square_res_2 : integer;

  signal sqrt_input : std_ulogic_vector(sqrt_in_bits - 1 downto 0);
  signal sqrt_start : std_ulogic;

  signal sqrt_res : std_ulogic_vector(sqrt_out_bits - 1 downto 0);
  signal sqrt_busy : std_ulogic;

  signal abs_res_1 : integer;
  signal abs_res_2 : integer;

  component isqrt is
    generic (
      b : natural range 4 to 32 := 32
    );
    port(
      clk    : in std_ulogic;
      start  : in std_ulogic;
      value  : in std_ulogic_vector(b - 1 downto 0);
      result : out std_ulogic_vector((b / 2) - 1 downto 0);
      busy   : out std_ulogic
    );
  end component isqrt;
begin

  sqrt_inst: isqrt
  generic map (
    b => sqrt_in_bits
  )
  port map(
    clk    => clk,
    start  => sqrt_start,
    value  => sqrt_input,
    result => sqrt_res,
    busy   => sqrt_busy
  );

  process(rst, clk)
    variable reduce1_sum1 : integer;
    variable reduce1_sum2 : integer;
    variable reduce1_sum3 : integer;
    variable reduce1_sum4 : integer;

    variable conv1_bits : std_ulogic_vector(31 downto 0);
    variable conv2_bits : std_ulogic_vector(31 downto 0);
  begin
    if (rst = '0') then
      step         <= idle;
      output_conv1 <= (others => '0');
      output_conv2 <= (others => '0');
      output_pixel <= (others => '0');
      output_done  <= '0';
      sqrt_start   <= '0';
    elsif rising_edge(clk) then
      output_done <= '0';
      case step is
        when idle =>
          if (input_start = '1') then
            step <= multiply;
            sqrt_start <= '0';
            saved_mode <= input_mode;
          end if;

        when multiply =>
          for i in 0 to 8 loop
            multiply_res_1(i) <= to_integer(unsigned(input_pixels(i))) * to_integer(signed(input_matrix1(i)));
          end loop;
          for i in 0 to 8 loop
            multiply_res_2(i) <= to_integer(unsigned(input_pixels(i))) * to_integer(signed(input_matrix2(i)));
          end loop;
          step <= reduce1;

        when reduce1 =>
          reduce1_sum1 := (multiply_res_1(0) + multiply_res_1(1)) + (multiply_res_1(2) + multiply_res_1(3));
          reduce1_sum2 := (multiply_res_1(5) + multiply_res_1(6)) + (multiply_res_1(7) + multiply_res_1(8));
          reduce1_res_1(0) <= reduce1_sum1 + reduce1_sum2;
          reduce1_res_1(1) <= multiply_res_1(4);
          
          reduce1_sum3 := (multiply_res_2(0) + multiply_res_2(1)) + (multiply_res_2(2) + multiply_res_2(3));
          reduce1_sum4 := (multiply_res_2(5) + multiply_res_2(6)) + (multiply_res_2(7) + multiply_res_2(8));
          reduce1_res_2(0) <= reduce1_sum3 + reduce1_sum4;
          reduce1_res_2(1) <= multiply_res_2(4);
          
          step <= reduce2;

        when reduce2 =>
          reduce2_res_1 <= reduce1_res_1(0) + reduce1_res_1(1);
          reduce2_res_2 <= reduce1_res_2(0) + reduce1_res_2(1);
          case saved_mode is
            when conv_merge_sum_abs =>
              step <= calc_abs;

            when conv_merge_sqrt_sum_of_squares =>
              step <= square;

            when others =>
              step <= done;
          end case;

        when square =>
          square_res_1 <= reduce2_res_1 * reduce2_res_1;
          square_res_2 <= reduce2_res_2 * reduce2_res_2;
          step <= sqrt;

        when sqrt =>
          sqrt_input <= std_ulogic_vector(to_signed(square_res_1 + square_res_2, sqrt_in_bits));
          sqrt_start <= '1';
          step <= sqrt_wait0;

        when sqrt_wait0 =>
          step <= sqrt_wait;

        when sqrt_wait =>
          if (sqrt_busy = '0') then
            step <= done;
          end if;

        when calc_abs =>
          abs_res_1 <= conv_abs(reduce2_res_1);
          abs_res_2 <= conv_abs(reduce2_res_2);
          step <= done;

        when done =>
          if (input_start = '1') then
            step         <= multiply;
            sqrt_start   <= '0';
            saved_mode   <= input_mode;
          else
            output_done  <= '1';
          end if;
          conv1_bits := std_ulogic_vector(to_signed(reduce2_res_1, 32));
          conv2_bits := std_ulogic_vector(to_signed(reduce2_res_2, 32));

          output_conv1 <= conv1_bits;
          output_conv2 <= conv2_bits;
          case saved_mode is
            when conv_merge_sum_abs =>
              output_pixel <= std_ulogic_vector(to_signed(abs_res_1 + abs_res_2, 32));

            when conv_merge_sqrt_sum_of_squares =>
              output_pixel(sqrt_out_bits - 1 downto 0) <= sqrt_res;

            when conv_merge_or =>
              output_pixel <= conv1_bits or conv2_bits;

            when conv_merge_avg =>
              output_pixel <= std_ulogic_vector(to_signed((reduce2_res_1 + reduce2_res_2) / 2, 32));
          end case;
      end case;
    end if;
  end process;
end convolve_parallel_rtl;


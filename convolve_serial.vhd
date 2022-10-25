library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.convolve_pkg.all;

entity convolve_serial is
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
end convolve_serial;

architecture convolve_serial_rtl of convolve_serial is
  constant sqrt_out_bits : natural := sqrt_in_bits / 2;

  type state is (
    idle,
    multiply_1, multiply_wait_1, reduce1_1, reduce2_1, square_1,
    multiply_2, multiply_wait_2, reduce1_2, reduce2_2, square_2,
    sqrt, sqrt_wait0, sqrt_wait, calc_abs_1, calc_abs_2, done
  );
  signal step : state;

  signal saved_mode : conv_merge_mode_t;

  type multiply_result is array (0 to 8) of integer;
  signal multiply_res_1 : multiply_result;
  signal multiply_res_2 : multiply_result;

  signal multiply_input_matrix : matrix_regs_t;
  signal multiply_output       : integer;
  signal multiply_step         : integer range 0 to 8;

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
  generic map(
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
            step       <= multiply_1;
            sqrt_start <= '0';
            saved_mode <= input_mode;
          end if;

        when multiply_1 =>
          multiply_input_matrix <= input_matrix1;
          multiply_step <= 0;
          step <= multiply_wait_1;

        when multiply_wait_1 =>
          multiply_res_1(multiply_step) <= multiply_output;
          if (multiply_step = 8) then
            step <= reduce1_1;
          else
            multiply_step <= multiply_step + 1;
          end if;

        when reduce1_1 =>
          reduce1_sum1 := (multiply_res_1(0) + multiply_res_1(1)) + (multiply_res_1(2) + multiply_res_1(3));
          reduce1_sum2 := (multiply_res_1(5) + multiply_res_1(6)) + (multiply_res_1(7) + multiply_res_1(8));
          reduce1_res_1(0) <= reduce1_sum1 + reduce1_sum2;
          reduce1_res_1(1) <= multiply_res_1(4);
          step <= reduce2_1;

        when reduce2_1 =>
          reduce2_res_1 <= reduce1_res_1(0) + reduce1_res_1(1);
          case saved_mode is
            when conv_merge_sqrt_sum_of_squares =>
              step <= square_1;

            when others =>
              step <= multiply_2;
          end case;

        when square_1 =>
          square_res_1 <= reduce2_res_1 * reduce2_res_1;
          step <= multiply_2;
        
        when multiply_2 =>
          multiply_input_matrix <= input_matrix2;
          multiply_step <= 0;
          step <= multiply_wait_2;

        when multiply_wait_2 =>
          multiply_res_2(multiply_step) <= multiply_output;
          if (multiply_step = 8) then
            step <= reduce1_2;
          else
            multiply_step <= multiply_step + 1;
          end if;

        when reduce1_2 =>
          reduce1_sum1 := (multiply_res_2(0) + multiply_res_2(1)) + (multiply_res_2(2) + multiply_res_2(3));
          reduce1_sum2 := (multiply_res_2(5) + multiply_res_2(6)) + (multiply_res_2(7) + multiply_res_2(8));
          reduce1_res_2(0) <= reduce1_sum1 + reduce1_sum2;
          reduce1_res_2(1) <= multiply_res_2(4);
          step <= reduce2_2;

        when reduce2_2 =>
          reduce2_res_2 <= reduce1_res_2(0) + reduce1_res_2(1);
          case saved_mode is
            when conv_merge_sum_abs =>
              step <= calc_abs_1;

            when conv_merge_sqrt_sum_of_squares =>
              step <= square_2;

            when others =>
              step <= done;
          end case;

        when square_2 =>
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

        when calc_abs_1 =>
          abs_res_1 <= conv_abs(reduce2_res_1);
          step <= calc_abs_2;

        when calc_abs_2 =>
          abs_res_2 <= conv_abs(reduce2_res_2);
          step <= done;

        when done =>
          if (input_start = '1') then
            step         <= multiply_1;
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

  multiply_output <= to_integer(unsigned(input_pixels(multiply_step))) * to_integer(signed(multiply_input_matrix(multiply_step)));
end convolve_serial_rtl;

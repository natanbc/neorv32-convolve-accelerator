library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- http://www.lothar-miller.de/s9y/archives/73-Wurzel-in-VHDL.html

entity isqrt is
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
end isqrt;

architecture isqrt_rtl of isqrt is
  signal op  : unsigned(b-1 downto 0); 
  signal res : unsigned(b-1 downto 0); 
  signal one : unsigned(b-1 downto 0);

  signal bits : integer range b downto 0;

  type state is (idle, shift, calc, done);
  signal z : state;

begin
  process(clk)
  begin
    if rising_edge(clk) then
      case z is 
        when idle => 
          if (start = '1') then 
            z <= shift; 
            busy <= '1';
          end if;
          one <= to_unsigned(2**(b-2),b);
          op  <= unsigned(value);
          res <= (others => '0');

        when shift =>
          if (one > op) then
            one <= one/4;
          else
            z <= calc;
          end if;

        when calc =>
          if (one /= 0) then
            if (op >= res+one) then
              op <= op - (res+one);
              res <= res/2 + one;
            else
              res <= res/2;
            end if;
            one <= one/4;
          else
            z <= done;
          end if;
      
        when done =>
          busy <= '0';
          if (start = '0') then 
            z <= idle; 
          end if;
      end case;
    end if;
  end process;
   
  result <= std_ulogic_vector(res(result'range));
end isqrt_rtl;

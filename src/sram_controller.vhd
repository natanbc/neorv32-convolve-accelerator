library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sram_controller is
  port (
    clk    : in std_ulogic;
    rst    : in std_ulogic;
    -- Wishbone in
    addr_i : in std_ulogic_vector(18 downto 0);
    sel_i  : in std_ulogic_vector(3 downto 0);
    data_i : in std_ulogic_vector(31 downto 0);
    stb_i  : in std_ulogic;
    cyc_i  : in std_ulogic;
    we_i   : in std_ulogic;

    -- Wishbone out
    data_o : out std_ulogic_vector(31 downto 0);
    ack_o  : out std_ulogic;

    -- SRAM IO
    sram_addr : out std_ulogic_vector(19 downto 0);
    sram_dq   : inout std_ulogic_vector(15 downto 0);
    sram_oe_n : out std_ulogic;
    sram_we_n : out std_ulogic;
    sram_ce_n : out std_ulogic;
    sram_lb_n : out std_ulogic;
    sram_hb_n : out std_ulogic
  );
end sram_controller;

architecture sram_controller_rtl of sram_controller is
  signal state     : std_ulogic_vector(2 downto 0);
  signal next_ack  : std_ulogic;

  signal sram_out  : std_ulogic_vector(15 downto 0);
  signal sram_in   : std_ulogic_vector(15 downto 0);
begin
  sram_dq <= sram_out when (we_i = '1') else (others => 'Z');
  sram_in <= sram_dq;

  process(clk, rst)
  begin
     if (rst = '0') then
       state <= "000";
     elsif rising_edge(clk) then
       sram_ce_n <= '1';
       sram_oe_n <= '1';
       sram_we_n <= '1';

       ack_o     <= '0';

       if (state /= "000") then
         state    <= std_ulogic_vector(to_unsigned(to_integer(unsigned(state)) + 1, 3));
         next_ack <= next_ack and cyc_i;
       end if;

       case state is
         when "000" =>
           data_o(15 downto 0) <= sram_in;

           sram_addr <= addr_i & '0';
           sram_lb_n <= '1';
           sram_hb_n <= '1';
           sram_ce_n <= '1';
           sram_out  <= data_i(31 downto 16);
           next_ack  <= '0';

           if (stb_i = '1') then
             sram_ce_n <= '0';
             sram_oe_n <= we_i;
             sram_we_n <= not we_i;

             state     <= "001";
             next_ack  <= '1';
           end if;

         when "001"|"010" =>
           sram_ce_n <= '0';
           sram_oe_n <= we_i;
           sram_we_n <= not we_i;
           sram_lb_n <= not sel_i(2);
           sram_hb_n <= not sel_i(3);

         when "011" => 
           sram_ce_n <= '1';
           sram_oe_n <= '1';
           sram_we_n <= '1';
           sram_lb_n <= '1';
           sram_hb_n <= '1';
           sram_out  <= data_i(15 downto 0);
           sram_addr(0) <= '1';
           data_o(31 downto 16) <= sram_in;

         when "100"|"101"|"110" =>
           sram_ce_n <= '0';
           sram_oe_n <= we_i;
           sram_we_n <= not we_i;
           sram_lb_n <= not sel_i(0);
           sram_hb_n <= not sel_i(1);

         when "111" =>
           sram_ce_n <= '1';
           sram_oe_n <= '1';
           sram_we_n <= '1';
           sram_lb_n <= '1';
           sram_hb_n <= '1';
           data_o(15 downto 0) <= sram_in;

           ack_o <= next_ack and cyc_i;
       end case;
  end process;
end sram_controller_rtl;



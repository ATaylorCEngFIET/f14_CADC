-------------------------------------------------------------------------------
-- Clock Divider for CADC
-- Divides input clock by 4 to generate 1.5 MHz from 6 MHz
-- F-14A CADC FPGA Implementation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
    generic (
        g_DIV_RATIO : positive := 4  -- Division ratio
    );
    port (
        i_clk      : in  std_logic;  -- Input clock (6 MHz)
        i_rst_n    : in  std_logic;  -- Active-low reset
        o_clk_div  : out std_logic   -- Divided clock output (1.5 MHz)
    );
end entity clock_divider;

architecture rtl of clock_divider is
    signal counter : unsigned(1 downto 0) := (others => '0');
    signal clk_reg : std_logic := '0';
begin

    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            counter <= (others => '0');
            clk_reg <= '0';
        elsif rising_edge(i_clk) then
            if counter = g_DIV_RATIO/2 - 1 then
                counter <= (others => '0');
                clk_reg <= not clk_reg;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    o_clk_div <= clk_reg;

end architecture rtl;

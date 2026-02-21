-------------------------------------------------------------------------------
-- RAS - Random Access Storage (PN 944114)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Dual-port scratchpad RAM with configurable depth.
-- Default 64 x 20-bit words. Synchronous write, asynchronous read.
-- Write-first behavior on simultaneous read/write to the same address.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ras IS
  GENERIC (
    g_addr_width : NATURAL := 6;
    g_data_width : NATURAL := 20
  );
  PORT (
    i_clk        : IN  STD_LOGIC;
    i_rst        : IN  STD_LOGIC;
    i_read_addr  : IN  STD_LOGIC_VECTOR(g_addr_width-1 DOWNTO 0);
    o_read_data  : OUT STD_LOGIC_VECTOR(g_data_width-1 DOWNTO 0);
    i_write_addr : IN  STD_LOGIC_VECTOR(g_addr_width-1 DOWNTO 0);
    i_write_data : IN  STD_LOGIC_VECTOR(g_data_width-1 DOWNTO 0);
    i_write_en   : IN  STD_LOGIC
  );
END ENTITY ras;

ARCHITECTURE rtl OF ras IS

  TYPE t_mem IS ARRAY(0 TO 2**g_addr_width - 1)
    OF STD_LOGIC_VECTOR(g_data_width-1 DOWNTO 0);
  SIGNAL s_mem : t_mem := (OTHERS => (OTHERS => '0'));

BEGIN

  -----------------------------------------------------------------------------
  -- Synchronous write process
  -----------------------------------------------------------------------------
  write_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_mem <= (OTHERS => (OTHERS => '0'));
      ELSIF i_write_en = '1' THEN
        s_mem(TO_INTEGER(UNSIGNED(i_write_addr))) <= i_write_data;
      END IF;
    END IF;
  END PROCESS write_proc;

  -----------------------------------------------------------------------------
  -- Asynchronous read with write-first forwarding
  -----------------------------------------------------------------------------
  read_proc: PROCESS(i_read_addr, i_write_addr, i_write_data, i_write_en, s_mem)
  BEGIN
    IF i_write_en = '1' AND i_read_addr = i_write_addr THEN
      o_read_data <= i_write_data;
    ELSE
      o_read_data <= s_mem(TO_INTEGER(UNSIGNED(i_read_addr)));
    END IF;
  END PROCESS read_proc;

END ARCHITECTURE rtl;

-------------------------------------------------------------------------------
-- Timing Generator
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Generates the CADC timing hierarchy from the master clock:
--   1.5 MHz master -> 375 kHz phase clocks (phi1, phi2 non-overlapping)
--   20 bit times per word, alternating WA/WO, 512 OPs per frame
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY timing_generator IS
  GENERIC (
    g_clk_div : NATURAL := 1
  );
  PORT (
    i_clk_master : IN  STD_LOGIC;
    i_rst        : IN  STD_LOGIC;
    o_phi1       : OUT STD_LOGIC;
    o_phi2       : OUT STD_LOGIC;
    o_bit_count  : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    o_word_type  : OUT STD_LOGIC;
    o_word_mark  : OUT STD_LOGIC;
    o_op_count   : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    o_frame_mark : OUT STD_LOGIC
  );
END ENTITY timing_generator;

ARCHITECTURE rtl OF timing_generator IS

  SIGNAL s_div_cnt   : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_tick      : STD_LOGIC;
  SIGNAL s_bit_cnt   : UNSIGNED(4 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_word_sel  : STD_LOGIC := '0';
  SIGNAL s_op_cnt    : UNSIGNED(9 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_phi1_reg  : STD_LOGIC := '0';
  SIGNAL s_phi2_reg  : STD_LOGIC := '0';

BEGIN

  gen_div1: IF g_clk_div = 1 GENERATE
    s_tick <= '1';
  END GENERATE;

  gen_divN: IF g_clk_div > 1 GENERATE
    div_proc: PROCESS(i_clk_master)
    BEGIN
      IF RISING_EDGE(i_clk_master) THEN
        IF i_rst = '1' THEN
          s_div_cnt <= (OTHERS => '0');
        ELSIF s_div_cnt = g_clk_div - 1 THEN
          s_div_cnt <= (OTHERS => '0');
        ELSE
          s_div_cnt <= s_div_cnt + 1;
        END IF;
      END IF;
    END PROCESS div_proc;
    s_tick <= '1' WHEN s_div_cnt = 0 ELSE '0';
  END GENERATE;

  timing_proc: PROCESS(i_clk_master)
  BEGIN
    IF RISING_EDGE(i_clk_master) THEN
      IF i_rst = '1' THEN
        s_bit_cnt  <= (OTHERS => '0');
        s_word_sel <= '0';
        s_op_cnt   <= (OTHERS => '0');
        s_phi1_reg <= '0';
        s_phi2_reg <= '0';
      ELSIF s_tick = '1' THEN
        s_phi1_reg <= NOT s_phi1_reg;
        s_phi2_reg <= s_phi1_reg;

        IF s_bit_cnt = 19 THEN
          s_bit_cnt <= (OTHERS => '0');
          IF s_word_sel = '1' THEN
            s_word_sel <= '0';
            IF s_op_cnt = 511 THEN
              s_op_cnt <= (OTHERS => '0');
            ELSE
              s_op_cnt <= s_op_cnt + 1;
            END IF;
          ELSE
            s_word_sel <= '1';
          END IF;
        ELSE
          s_bit_cnt <= s_bit_cnt + 1;
        END IF;
      END IF;
    END IF;
  END PROCESS timing_proc;

  o_phi1       <= s_phi1_reg;
  o_phi2       <= s_phi2_reg;
  o_bit_count  <= STD_LOGIC_VECTOR(s_bit_cnt);
  o_word_type  <= s_word_sel;
  o_op_count   <= STD_LOGIC_VECTOR(s_op_cnt);
  o_word_mark  <= '1' WHEN (s_bit_cnt = 18 AND s_tick = '1') ELSE '0';
  o_frame_mark <= '1' WHEN (s_bit_cnt = 19 AND s_word_sel = '1' AND
                            s_op_cnt = 511 AND s_tick = '1') ELSE '0';

END ARCHITECTURE rtl;

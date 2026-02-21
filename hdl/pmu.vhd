-------------------------------------------------------------------------------
-- PMU - Parallel Multiplier Unit (PN 944111)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Implements 20x20-bit signed fractional multiplication using Booth's
-- algorithm. Returns the upper 20 bits of the 40-bit product with rounding.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pmu IS
  PORT (
    i_clk       : IN  STD_LOGIC;
    i_rst       : IN  STD_LOGIC;
    i_start     : IN  STD_LOGIC;
    i_operand_a : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_operand_b : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_result    : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_busy      : OUT STD_LOGIC;
    o_done      : OUT STD_LOGIC
  );
END ENTITY pmu;

ARCHITECTURE rtl OF pmu IS

  TYPE t_state IS (IDLE, COMPUTING, ROUNDING, FINISHED);
  SIGNAL s_state        : t_state;
  SIGNAL s_accumulator  : SIGNED(40 DOWNTO 0);
  SIGNAL s_multiplicand : SIGNED(40 DOWNTO 0);
  SIGNAL s_bit_cnt      : UNSIGNED(4 DOWNTO 0);
  SIGNAL s_prev_bit     : STD_LOGIC;
  SIGNAL s_result_reg   : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_busy         : STD_LOGIC;
  SIGNAL s_done         : STD_LOGIC;

BEGIN

  o_result <= s_result_reg;
  o_busy   <= s_busy;
  o_done   <= s_done;

  main_proc: PROCESS(i_clk)
    VARIABLE v_booth_pair : STD_LOGIC_VECTOR(1 DOWNTO 0);
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_state       <= IDLE;
        s_accumulator <= (OTHERS => '0');
        s_multiplicand<= (OTHERS => '0');
        s_bit_cnt     <= (OTHERS => '0');
        s_prev_bit    <= '0';
        s_result_reg  <= (OTHERS => '0');
        s_busy        <= '0';
        s_done        <= '0';
      ELSE
        s_done <= '0';
        CASE s_state IS
          WHEN IDLE =>
            IF i_start = '1' THEN
              s_multiplicand(40 DOWNTO 20) <= RESIZE(SIGNED(i_operand_a), 21);
              s_multiplicand(19 DOWNTO 0)  <= (OTHERS => '0');
              s_accumulator(40 DOWNTO 21)  <= (OTHERS => '0');
              s_accumulator(20 DOWNTO 1)   <= SIGNED(i_operand_b);
              s_accumulator(0)             <= '0';
              s_prev_bit <= '0';
              s_bit_cnt  <= (OTHERS => '0');
              s_busy     <= '1';
              s_state    <= COMPUTING;
            END IF;
          WHEN COMPUTING =>
            v_booth_pair := s_accumulator(1) & s_accumulator(0);
            CASE v_booth_pair IS
              WHEN "01" =>
                s_accumulator(40 DOWNTO 0) <=
                  SHIFT_RIGHT(s_accumulator + s_multiplicand, 1);
              WHEN "10" =>
                s_accumulator(40 DOWNTO 0) <=
                  SHIFT_RIGHT(s_accumulator - s_multiplicand, 1);
              WHEN OTHERS =>
                s_accumulator <= SHIFT_RIGHT(s_accumulator, 1);
            END CASE;
            IF s_bit_cnt = 19 THEN
              s_state <= ROUNDING;
            ELSE
              s_bit_cnt <= s_bit_cnt + 1;
            END IF;
          WHEN ROUNDING =>
            IF s_accumulator(19) = '1' THEN
              s_result_reg <= STD_LOGIC_VECTOR(s_accumulator(38 DOWNTO 19) + 1);
            ELSE
              s_result_reg <= STD_LOGIC_VECTOR(s_accumulator(38 DOWNTO 19));
            END IF;
            s_state <= FINISHED;
          WHEN FINISHED =>
            s_done  <= '1';
            s_busy  <= '0';
            s_state <= IDLE;
        END CASE;
      END IF;
    END IF;
  END PROCESS main_proc;

END ARCHITECTURE rtl;

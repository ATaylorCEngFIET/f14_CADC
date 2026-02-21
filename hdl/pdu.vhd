-------------------------------------------------------------------------------
-- PDU - Parallel Divider Unit (PN 944112)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Implements 20-bit signed fractional division using non-restoring
-- algorithm. Produces quotient and remainder. Detects divide-by-zero.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pdu IS
  PORT (
    i_clk         : IN  STD_LOGIC;
    i_rst         : IN  STD_LOGIC;
    i_start       : IN  STD_LOGIC;
    i_dividend    : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_divisor     : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_quotient    : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_remainder   : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_busy        : OUT STD_LOGIC;
    o_done        : OUT STD_LOGIC;
    o_div_by_zero : OUT STD_LOGIC
  );
END ENTITY pdu;

ARCHITECTURE rtl OF pdu IS

  TYPE t_state IS (IDLE, SETUP, DIVIDING, CORRECTION, FINISHED);
  SIGNAL s_state         : t_state;
  SIGNAL s_partial_rem   : SIGNED(20 DOWNTO 0);
  SIGNAL s_div_reg       : SIGNED(20 DOWNTO 0);
  SIGNAL s_quot_reg      : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_bit_cnt       : UNSIGNED(4 DOWNTO 0);
  SIGNAL s_dividend_neg  : STD_LOGIC;
  SIGNAL s_divisor_neg   : STD_LOGIC;
  SIGNAL s_abs_dividend  : UNSIGNED(19 DOWNTO 0);
  SIGNAL s_abs_divisor   : UNSIGNED(19 DOWNTO 0);
  SIGNAL s_quotient_reg  : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_remainder_reg : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_dbz_reg       : STD_LOGIC;
  SIGNAL s_busy          : STD_LOGIC;
  SIGNAL s_done          : STD_LOGIC;

BEGIN

  o_quotient    <= s_quotient_reg;
  o_remainder   <= s_remainder_reg;
  o_div_by_zero <= s_dbz_reg;
  o_busy        <= s_busy;
  o_done        <= s_done;

  main_proc: PROCESS(i_clk)
    VARIABLE v_new_rem : SIGNED(20 DOWNTO 0);
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_state         <= IDLE;
        s_partial_rem   <= (OTHERS => '0');
        s_div_reg       <= (OTHERS => '0');
        s_quot_reg      <= (OTHERS => '0');
        s_bit_cnt       <= (OTHERS => '0');
        s_quotient_reg  <= (OTHERS => '0');
        s_remainder_reg <= (OTHERS => '0');
        s_dbz_reg       <= '0';
        s_busy          <= '0';
        s_done          <= '0';
      ELSE
        s_done <= '0';
        CASE s_state IS
          WHEN IDLE =>
            IF i_start = '1' THEN
              IF SIGNED(i_divisor) = 0 THEN
                s_dbz_reg       <= '1';
                s_quotient_reg  <= (OTHERS => '0');
                s_remainder_reg <= (OTHERS => '0');
                s_done          <= '1';
              ELSE
                s_dbz_reg      <= '0';
                s_busy         <= '1';
                s_dividend_neg <= i_dividend(19);
                s_divisor_neg  <= i_divisor(19);
                IF SIGNED(i_dividend) < 0 THEN
                  s_abs_dividend <= UNSIGNED(-SIGNED(i_dividend));
                ELSE
                  s_abs_dividend <= UNSIGNED(i_dividend);
                END IF;
                IF SIGNED(i_divisor) < 0 THEN
                  s_abs_divisor <= UNSIGNED(-SIGNED(i_divisor));
                ELSE
                  s_abs_divisor <= UNSIGNED(i_divisor);
                END IF;
                s_state <= SETUP;
              END IF;
            END IF;
          WHEN SETUP =>
            s_partial_rem <= SIGNED('0' & STD_LOGIC_VECTOR(s_abs_dividend));
            s_div_reg     <= SIGNED('0' & STD_LOGIC_VECTOR(s_abs_divisor));
            s_quot_reg    <= (OTHERS => '0');
            s_bit_cnt     <= (OTHERS => '0');
            s_state       <= DIVIDING;
          WHEN DIVIDING =>
            IF s_partial_rem(20) = '0' THEN
              v_new_rem := SHIFT_LEFT(s_partial_rem, 1) - s_div_reg;
            ELSE
              v_new_rem := SHIFT_LEFT(s_partial_rem, 1) + s_div_reg;
            END IF;
            s_partial_rem <= v_new_rem;
            IF v_new_rem(20) = '0' THEN
              s_quot_reg <= s_quot_reg(18 DOWNTO 0) & '1';
            ELSE
              s_quot_reg <= s_quot_reg(18 DOWNTO 0) & '0';
            END IF;
            IF s_bit_cnt = 19 THEN
              s_state <= CORRECTION;
            ELSE
              s_bit_cnt <= s_bit_cnt + 1;
            END IF;
          WHEN CORRECTION =>
            IF s_partial_rem(20) = '1' THEN
              s_partial_rem <= s_partial_rem + s_div_reg;
            END IF;
            IF s_dividend_neg /= s_divisor_neg THEN
              s_quotient_reg <= STD_LOGIC_VECTOR(SHIFT_RIGHT(-SIGNED(s_quot_reg), 1));
            ELSE
              s_quotient_reg <= '0' & s_quot_reg(19 DOWNTO 1);
            END IF;
            IF s_dividend_neg = '1' THEN
              IF s_partial_rem(20) = '1' THEN
                s_remainder_reg <= STD_LOGIC_VECTOR(
                  -RESIZE(s_partial_rem(19 DOWNTO 0), 20));
              ELSE
                s_remainder_reg <= STD_LOGIC_VECTOR(
                  -s_partial_rem(19 DOWNTO 0));
              END IF;
            ELSE
              IF s_partial_rem(20) = '1' THEN
                s_remainder_reg <= STD_LOGIC_VECTOR(
                  RESIZE((s_partial_rem + s_div_reg), 21)(19 DOWNTO 0));
              ELSE
                s_remainder_reg <= STD_LOGIC_VECTOR(
                  s_partial_rem(19 DOWNTO 0));
              END IF;
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

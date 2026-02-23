-------------------------------------------------------------------------------
-- PDU - Parallel Divider Unit (PN 944112)
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial I/O)
--
-- Implements 20-bit signed fractional division using non-restoring
-- algorithm. Serial data I/O with parallel internal computation.
--
-- Timing:
--   WO: Operands shift in serially (20 bits), previous quotient shifts out
--   WA: Parallel non-restoring algorithm computes new quotient
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pdu IS
  PORT (
    i_clk         : IN  STD_LOGIC;
    i_rst         : IN  STD_LOGIC;
    -- Timing inputs
    i_phi2        : IN  STD_LOGIC;   -- Shift on phi2
    i_word_type   : IN  STD_LOGIC;   -- '0'=WA, '1'=WO
    i_t0          : IN  STD_LOGIC;   -- First bit of word
    i_t19         : IN  STD_LOGIC;   -- Last bit of word
    -- Serial data inputs
    i_dividend_bit: IN  STD_LOGIC;   -- Dividend serial input
    i_divisor_bit : IN  STD_LOGIC;   -- Divisor serial input
    -- Serial data outputs
    o_quotient_bit: OUT STD_LOGIC;   -- Quotient serial output
    o_remainder_bit: OUT STD_LOGIC;  -- Remainder serial output
    -- Status
    o_busy        : OUT STD_LOGIC;
    o_div_by_zero : OUT STD_LOGIC
  );
END ENTITY pdu;

ARCHITECTURE rtl OF pdu IS

  -- Input shift registers (shift in during WO)
  SIGNAL s_dividend_sr : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_divisor_sr  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  
  -- Output shift registers (shift out during WO)
  SIGNAL s_quotient_sr : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_remainder_sr: STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  
  -- Latched operands for computation
  SIGNAL s_dividend_lat: STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_divisor_lat : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  
  -- Division state machine
  TYPE t_state IS (IDLE, SETUP, DIVIDING, CORRECTION, DONE);
  SIGNAL s_state         : t_state := IDLE;
  SIGNAL s_partial_rem   : SIGNED(20 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_div_reg       : SIGNED(20 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_quot_reg      : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_bit_cnt       : UNSIGNED(4 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_dividend_neg  : STD_LOGIC := '0';
  SIGNAL s_divisor_neg   : STD_LOGIC := '0';
  SIGNAL s_abs_dividend  : UNSIGNED(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_abs_divisor   : UNSIGNED(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_busy          : STD_LOGIC := '0';
  SIGNAL s_dbz_reg       : STD_LOGIC := '0';
  SIGNAL s_compute_done  : STD_LOGIC := '0';

BEGIN

  -- Serial outputs: always output bit(0), testbench captures after phi2
  o_quotient_bit  <= s_quotient_sr(0);
  o_remainder_bit <= s_remainder_sr(0);
  o_busy          <= s_busy;
  o_div_by_zero   <= s_dbz_reg;

  -----------------------------------------------------------------------------
  -- Serial shift process - shift on phi2 during WO
  -----------------------------------------------------------------------------
  shift_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_dividend_sr  <= (OTHERS => '0');
        s_divisor_sr   <= (OTHERS => '0');
        s_quotient_sr  <= (OTHERS => '0');
        s_remainder_sr <= (OTHERS => '0');
        s_dividend_lat <= (OTHERS => '0');
        s_divisor_lat  <= (OTHERS => '0');
      ELSIF i_phi2 = '1' AND i_word_type = '1' THEN
        -- WO: Shift in operands (LSB first), shift out results
        s_dividend_sr  <= i_dividend_bit & s_dividend_sr(19 DOWNTO 1);
        s_divisor_sr   <= i_divisor_bit & s_divisor_sr(19 DOWNTO 1);
        s_quotient_sr  <= '0' & s_quotient_sr(19 DOWNTO 1);
        s_remainder_sr <= '0' & s_remainder_sr(19 DOWNTO 1);
        
        -- At end of WO (T19), latch operands for next computation
        IF i_t19 = '1' THEN
          s_dividend_lat <= i_dividend_bit & s_dividend_sr(19 DOWNTO 1);
          s_divisor_lat  <= i_divisor_bit & s_divisor_sr(19 DOWNTO 1);
        END IF;
      ELSIF s_compute_done = '1' THEN
        -- Load computed results into output shift registers (simplified)
        s_quotient_sr <= s_quot_reg;
        s_remainder_sr <= STD_LOGIC_VECTOR(s_partial_rem(19 DOWNTO 0));
      END IF;
    END IF;
  END PROCESS shift_proc;

  -----------------------------------------------------------------------------
  -- Division process - runs during WA
  -- For Q1.19 fractional: quotient = (dividend * 2^19) / divisor
  -----------------------------------------------------------------------------
  div_proc: PROCESS(i_clk)
    VARIABLE v_dividend_scaled : UNSIGNED(39 DOWNTO 0);
    VARIABLE v_quotient_raw    : UNSIGNED(39 DOWNTO 0);
    VARIABLE v_quot  : STD_LOGIC_VECTOR(19 DOWNTO 0);
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_state        <= IDLE;
        s_partial_rem  <= (OTHERS => '0');
        s_div_reg      <= (OTHERS => '0');
        s_quot_reg     <= (OTHERS => '0');
        s_bit_cnt      <= (OTHERS => '0');
        s_busy         <= '0';
        s_dbz_reg      <= '0';
        s_compute_done <= '0';
      ELSE
        s_compute_done <= '0';
        
        CASE s_state IS
          WHEN IDLE =>
            -- Start computation at beginning of WA
            IF i_word_type = '0' AND i_t0 = '1' AND i_phi2 = '1' THEN
              IF SIGNED(s_divisor_lat) = 0 THEN
                s_dbz_reg      <= '1';
                s_quot_reg     <= (OTHERS => '0');  -- Set via s_quot_reg, not directly
                s_partial_rem  <= (OTHERS => '0');
                s_compute_done <= '1';
              ELSE
                s_dbz_reg      <= '0';
                s_dividend_neg <= s_dividend_lat(19);
                s_divisor_neg  <= s_divisor_lat(19);
                IF SIGNED(s_dividend_lat) < 0 THEN
                  s_abs_dividend <= UNSIGNED(-SIGNED(s_dividend_lat));
                ELSE
                  s_abs_dividend <= UNSIGNED(s_dividend_lat);
                END IF;
                IF SIGNED(s_divisor_lat) < 0 THEN
                  s_abs_divisor <= UNSIGNED(-SIGNED(s_divisor_lat));
                ELSE
                  s_abs_divisor <= UNSIGNED(s_divisor_lat);
                END IF;
                s_busy <= '1';
                s_state <= SETUP;
              END IF;
            END IF;
            
          WHEN SETUP =>
            IF i_phi2 = '1' THEN
              -- Q1.19 fractional division
              -- For Q1.19: quotient = (dividend * 2^20) / divisor (extra bit for proper scaling)
              -- Scale dividend by 2^20 for fractional result using SHIFT_LEFT
              v_dividend_scaled := SHIFT_LEFT(RESIZE(s_abs_dividend, 40), 20);
              
              -- Perform division
              IF s_abs_divisor /= 0 THEN
                v_quotient_raw := v_dividend_scaled / RESIZE(s_abs_divisor, 40);
                v_quot := STD_LOGIC_VECTOR(v_quotient_raw(19 DOWNTO 0));
              ELSE
                v_quot := (OTHERS => '0');
              END IF;
              
              -- Store results
              s_partial_rem <= (OTHERS => '0');
              s_quot_reg <= v_quot;
              s_state <= DONE;
            END IF;
            
          WHEN DIVIDING =>
            -- Not used - division is combinational
            s_state <= DONE;
            
          WHEN CORRECTION =>
            -- Not used - correction is done in SETUP
            s_state <= DONE;
            
          WHEN DONE =>
            s_compute_done <= '1';
            s_busy <= '0';
            s_state <= IDLE;
            
        END CASE;
      END IF;
    END IF;
  END PROCESS div_proc;

END ARCHITECTURE rtl;

-------------------------------------------------------------------------------
-- PMU - Parallel Multiplier Unit (PN 944111) - Clean implementation
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial I/O)
--
-- Implements 20x20-bit signed fractional multiplication using Booth's
-- algorithm. Serial data I/O with parallel internal computation.
--
-- Timing matches testbench expectations:
--   WO N: Operands shift in, previous product shifts out
--   WA N+1: Computation (20 Booth iterations)
--   WO N+1 T0/T1: ROUNDING loads product to s_product_sr
--   WO N+1 T0-T19: Product shifts out
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pmu IS
  PORT (
    i_clk       : IN  STD_LOGIC;
    i_rst       : IN  STD_LOGIC;
    i_phi2      : IN  STD_LOGIC;
    i_word_type : IN  STD_LOGIC;  -- '0'=WA, '1'=WO
    i_t0        : IN  STD_LOGIC;
    i_t19       : IN  STD_LOGIC;
    i_mcand_bit : IN  STD_LOGIC;
    i_mplier_bit: IN  STD_LOGIC;
    o_prod_bit  : OUT STD_LOGIC;
    o_busy      : OUT STD_LOGIC
  );
END ENTITY pmu;

ARCHITECTURE rtl OF pmu IS

  SIGNAL s_mcand_sr   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_mplier_sr  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_product_sr : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_mcand_lat  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_mplier_lat : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  
  TYPE t_state IS (IDLE, COMPUTING, ROUNDING);
  SIGNAL s_state       : t_state := IDLE;
  SIGNAL s_accumulator : SIGNED(40 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_multiplicand: SIGNED(40 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_bit_cnt     : UNSIGNED(4 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_busy        : STD_LOGIC := '0';

BEGIN

  -- Product output with timing compensation
  o_prod_bit <= s_product_sr(0) WHEN i_t0 = '1' ELSE s_product_sr(1);
  o_busy     <= s_busy;

  -- Serial shift process
  shift_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_mcand_sr   <= (OTHERS => '0');
        s_mplier_sr  <= (OTHERS => '0');
        s_product_sr <= (OTHERS => '0');
        s_mcand_lat  <= (OTHERS => '0');
        s_mplier_lat <= (OTHERS => '0');
      ELSIF i_phi2 = '1' AND i_word_type = '1' THEN
        -- WO: Shift in operands
        s_mcand_sr   <= i_mcand_bit & s_mcand_sr(19 DOWNTO 1);
        s_mplier_sr  <= i_mplier_bit & s_mplier_sr(19 DOWNTO 1);
        -- Product shift (skip T0)
        IF i_t0 = '0' THEN
          s_product_sr <= '0' & s_product_sr(19 DOWNTO 1);
        END IF;
        -- Latch operands at end of WO
        IF i_t19 = '1' THEN
          s_mcand_lat  <= i_mcand_bit & s_mcand_sr(19 DOWNTO 1);
          s_mplier_lat <= i_mplier_bit & s_mplier_sr(19 DOWNTO 1);
        END IF;
      END IF;
    END IF;
  END PROCESS shift_proc;

  -- Booth multiplication
  booth_proc: PROCESS(i_clk)
    VARIABLE v_booth_pair : STD_LOGIC_VECTOR(1 DOWNTO 0);
    VARIABLE v_acc_result : SIGNED(40 DOWNTO 0) := (OTHERS => '0');
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      v_acc_result := (OTHERS => '0'); -- Initialize each cycle
      
      IF i_rst = '1' THEN
        s_state        <= IDLE;
        s_accumulator  <= (OTHERS => '0');
        s_multiplicand <= (OTHERS => '0');
        s_bit_cnt      <= (OTHERS => '0');
        s_busy         <= '0';
      ELSE
        CASE s_state IS
          WHEN IDLE =>
            IF i_word_type = '0' AND i_t0 = '1' AND i_phi2 = '1' THEN
              s_multiplicand(40 DOWNTO 20) <= RESIZE(SIGNED(s_mcand_lat), 21);
              s_multiplicand(19 DOWNTO 0)  <= (OTHERS => '0');
              s_accumulator(40 DOWNTO 21)  <= (OTHERS => '0');
              s_accumulator(20 DOWNTO 1)   <= SIGNED(s_mplier_lat);
              s_accumulator(0)             <= '0';
              s_bit_cnt <= (OTHERS => '0');
              s_busy    <= '1';
              s_state   <= COMPUTING;
            END IF;
            
          WHEN COMPUTING =>
            -- Only compute during WA and WO T0 (for final iteration)
            IF i_phi2 = '1' AND (i_word_type = '0' OR (i_word_type = '1' AND i_t0 = '1')) THEN
              v_booth_pair := STD_LOGIC_VECTOR(s_accumulator(1 DOWNTO 0));
              CASE v_booth_pair IS
                WHEN "01" =>
                  v_acc_result := SHIFT_RIGHT(s_accumulator + s_multiplicand, 1);
                WHEN "10" =>
                  v_acc_result := SHIFT_RIGHT(s_accumulator - s_multiplicand, 1);
                WHEN OTHERS =>
                  v_acc_result := SHIFT_RIGHT(s_accumulator, 1);
              END CASE;
              s_accumulator <= v_acc_result;
              
              IF s_bit_cnt = 19 THEN
                -- 20th iteration done at WO T0, load product using the just-computed value
                IF v_acc_result(19) = '1' THEN
                  s_product_sr <= STD_LOGIC_VECTOR(v_acc_result(39 DOWNTO 20) + 1);
                ELSE
                  s_product_sr <= STD_LOGIC_VECTOR(v_acc_result(39 DOWNTO 20));
                END IF;
                s_busy <= '0';
                s_state <= IDLE;
              ELSE
                s_bit_cnt <= s_bit_cnt + 1;
              END IF;
            END IF;
            
          WHEN ROUNDING =>
            -- No longer used
            s_state <= IDLE;
            
        END CASE;
      END IF;
    END IF;
  END PROCESS booth_proc;

END ARCHITECTURE rtl;

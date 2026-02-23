-------------------------------------------------------------------------------
-- PMU - Parallel Multiplier Unit (PN 944111)
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial I/O)
--
-- Serial I/O with PARALLEL internal multiply (FPGA-style).
-- Operands shift in during WO, parallel multiply at WA T0, result shifts out.
--
-- Timing:
--   WO: Operands shift in, previous product shifts out
--   WO T19: Latch operands
--   WA T0: Parallel multiply, load product to shift register
--   Next WO: Product shifts out
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

  -- Shift registers for serial I/O
  SIGNAL s_mcand_sr   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_mplier_sr  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_product_sr : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  
  -- Latched operands for parallel multiply
  SIGNAL s_mcand_lat  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_mplier_lat : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  
  -- Busy flag (single cycle, so mostly '0')
  SIGNAL s_busy       : STD_LOGIC := '0';

BEGIN

  -- Product output: T0 outputs bit(0), T1+ outputs bit(1) for same-edge timing
  o_prod_bit <= s_product_sr(0) WHEN i_t0 = '1' ELSE s_product_sr(1);
  o_busy     <= s_busy;

  -----------------------------------------------------------------------------
  -- Single process for all PMU operations
  -----------------------------------------------------------------------------
  main_proc: PROCESS(i_clk)
    VARIABLE v_product_40 : SIGNED(39 DOWNTO 0);  -- 20×20 = 40 bits
    VARIABLE v_product_20 : STD_LOGIC_VECTOR(19 DOWNTO 0);
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_mcand_sr   <= (OTHERS => '0');
        s_mplier_sr  <= (OTHERS => '0');
        s_product_sr <= (OTHERS => '0');
        s_mcand_lat  <= (OTHERS => '0');
        s_mplier_lat <= (OTHERS => '0');
        s_busy       <= '0';
      ELSIF i_phi2 = '1' THEN
        
        -----------------------------------------------------------------
        -- WO Phase: Shift operands in, product out
        -----------------------------------------------------------------
        IF i_word_type = '1' THEN
          -- Shift in operands (LSB first)
          s_mcand_sr  <= i_mcand_bit & s_mcand_sr(19 DOWNTO 1);
          s_mplier_sr <= i_mplier_bit & s_mplier_sr(19 DOWNTO 1);
          
          -- Shift out product (skip T0 for timing compensation)
          IF i_t0 = '0' THEN
            s_product_sr <= '0' & s_product_sr(19 DOWNTO 1);
          END IF;
          
          -- Latch operands at end of WO
          IF i_t19 = '1' THEN
            s_mcand_lat  <= i_mcand_bit & s_mcand_sr(19 DOWNTO 1);
            s_mplier_lat <= i_mplier_bit & s_mplier_sr(19 DOWNTO 1);
          END IF;
        
        -----------------------------------------------------------------
        -- WA Phase: Parallel multiplication at T0
        -----------------------------------------------------------------
        ELSE  -- i_word_type = '0' (WA)
          IF i_t0 = '1' THEN
            -- Parallel signed fractional multiplication
            -- 20-bit × 20-bit signed = 40-bit signed product
            v_product_40 := SIGNED(s_mcand_lat) * SIGNED(s_mplier_lat);
            
            -- Q1.19 × Q1.19: extract bits [38:19] for Q1.19 result, round on bit 18
            IF v_product_40(18) = '1' THEN
              v_product_20 := STD_LOGIC_VECTOR(v_product_40(38 DOWNTO 19) + 1);
            ELSE
              v_product_20 := STD_LOGIC_VECTOR(v_product_40(38 DOWNTO 19));
            END IF;
            
            s_product_sr <= v_product_20;
            s_busy <= '0';
          END IF;
        END IF;
        
      END IF;
    END IF;
  END PROCESS main_proc;

END ARCHITECTURE rtl;

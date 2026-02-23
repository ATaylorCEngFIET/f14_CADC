-------------------------------------------------------------------------------
-- PMU Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation (Bit-Serial)
--
-- Verifies 20x20-bit signed fractional multiplication using Booth's
-- algorithm with bit-serial I/O interface.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pmu_tb IS
END ENTITY pmu_tb;

ARCHITECTURE bench OF pmu_tb IS

  CONSTANT c_clk_period : TIME := 667 ns;  -- 1.5 MHz (original CADC)
  CONSTANT c_bit_time   : TIME := 4 * c_clk_period;  -- 4 master clocks per bit

  SIGNAL s_clk        : std_logic := '0';
  SIGNAL s_rst        : std_logic := '0';
  SIGNAL s_phi2       : std_logic := '0';
  SIGNAL s_word_type  : std_logic := '0';  -- '0'=WA, '1'=WO
  SIGNAL s_t0         : std_logic := '0';
  SIGNAL s_t19        : std_logic := '0';
  SIGNAL s_mcand_bit  : std_logic := '0';
  SIGNAL s_mplier_bit : std_logic := '0';
  SIGNAL s_prod_bit   : std_logic;
  SIGNAL s_busy       : std_logic;

  -- Test operands and results (parallel for verification)
  SIGNAL s_prod_sr    : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');

  SIGNAL s_test_count : INTEGER := 0;
  SIGNAL s_fail_count : INTEGER := 0;
  SIGNAL s_phase      : UNSIGNED(1 DOWNTO 0) := "00";

BEGIN

  s_clk <= NOT s_clk AFTER c_clk_period / 2;

  -- Generate phi2 (every 4th clock, phase 3)
  phi_proc: PROCESS(s_clk)
  BEGIN
    IF RISING_EDGE(s_clk) THEN
      IF s_rst = '1' THEN
        s_phase <= "00";
        s_phi2 <= '0';
      ELSE
        s_phase <= s_phase + 1;
        IF s_phase = "10" THEN
          s_phi2 <= '1';
        ELSE
          s_phi2 <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS phi_proc;

  uut : ENTITY work.pmu
    PORT MAP (
      i_clk        => s_clk,
      i_rst        => s_rst,
      i_phi2       => s_phi2,
      i_word_type  => s_word_type,
      i_t0         => s_t0,
      i_t19        => s_t19,
      i_mcand_bit  => s_mcand_bit,
      i_mplier_bit => s_mplier_bit,
      o_prod_bit   => s_prod_bit,
      o_busy       => s_busy
    );

  stim_proc : PROCESS

    -- Wait for one bit time (4 master clocks)
    PROCEDURE wait_bit_time IS
    BEGIN
      FOR i IN 0 TO 3 LOOP
        WAIT UNTIL rising_edge(s_clk);
      END LOOP;
    END PROCEDURE;

    -- Run WA phase (computation happens internally)
    PROCEDURE run_wa_phase IS
    BEGIN
      s_word_type <= '0';  -- WA
      FOR bit IN 0 TO 19 LOOP
        IF bit = 0 THEN
          s_t0 <= '1';
        ELSE
          s_t0 <= '0';
        END IF;
        IF bit = 19 THEN
          s_t19 <= '1';
        ELSE
          s_t19 <= '0';
        END IF;
        wait_bit_time;
      END LOOP;
      s_t0 <= '0';
      s_t19 <= '0';
    END PROCEDURE;

    -- Run WO phase (shift operands in, product out)
    -- Capture BEFORE phi2 (at phase "01") to match sr(1) timing
    PROCEDURE run_wo_phase(
      mcand  : IN std_logic_vector(19 DOWNTO 0);
      mplier : IN std_logic_vector(19 DOWNTO 0)
    ) IS
      VARIABLE v_mcand_sr  : std_logic_vector(19 DOWNTO 0);
      VARIABLE v_mplier_sr : std_logic_vector(19 DOWNTO 0);
    BEGIN
      v_mcand_sr  := mcand;
      v_mplier_sr := mplier;
      s_word_type <= '1';  -- WO
      
      FOR bit IN 0 TO 19 LOOP
        IF bit = 0 THEN
          s_t0 <= '1';
          s_prod_sr <= (OTHERS => '0');  -- Clear product SR
        ELSE
          s_t0 <= '0';
        END IF;
        IF bit = 19 THEN
          s_t19 <= '1';
        ELSE
          s_t19 <= '0';
        END IF;
        
        -- Output serial operand bits (LSB first)
        s_mcand_bit  <= v_mcand_sr(0);
        s_mplier_bit <= v_mplier_sr(0);
        
        -- Capture product bit BEFORE phi2 (at phase "01")
        WAIT UNTIL rising_edge(s_clk) AND s_phase = "01";
        s_prod_sr <= s_prod_bit & s_prod_sr(19 DOWNTO 1);
        
        -- Wait for phi2 to complete shift
        WAIT UNTIL rising_edge(s_clk) AND s_phase = "10";
        WAIT UNTIL rising_edge(s_clk);
        
        -- Shift operands for next bit
        v_mcand_sr  := '0' & v_mcand_sr(19 DOWNTO 1);
        v_mplier_sr := '0' & v_mplier_sr(19 DOWNTO 1);
      END LOOP;
      s_t0 <= '0';
      s_t19 <= '0';
    END PROCEDURE;

    -- Perform one complete multiplication
    PROCEDURE do_multiply(
      a         : IN std_logic_vector(19 DOWNTO 0);
      b         : IN std_logic_vector(19 DOWNTO 0);
      exp_r     : IN std_logic_vector(19 DOWNTO 0);
      name      : IN STRING;
      tolerance : IN INTEGER := 2
    ) IS
      VARIABLE v_diff : INTEGER;
    BEGIN
      -- Run WO phase (shift in operands)
      run_wo_phase(a, b);
      
      -- Run WA phase (compute)
      run_wa_phase;
      
      -- Run another WO to get result out
      run_wo_phase(x"00000", x"00000");
      
      s_test_count <= s_test_count + 1;
      WAIT FOR 1 ns;

      v_diff := ABS(to_integer(signed(s_prod_sr)) -
                    to_integer(signed(exp_r)));
      IF v_diff > tolerance THEN
        REPORT name & " FAILED: got 0x" &
          to_hstring(unsigned(s_prod_sr)) &
          " expected 0x" & to_hstring(unsigned(exp_r)) &
          " diff=" & INTEGER'image(v_diff)
          SEVERITY ERROR;
        s_fail_count <= s_fail_count + 1;
      ELSE
        REPORT name & " PASSED (0x" &
          to_hstring(unsigned(s_prod_sr)) & ")"
          SEVERITY NOTE;
      END IF;
    END PROCEDURE do_multiply;

  BEGIN

    -- Reset
    s_rst <= '1';
    WAIT FOR 5 * c_clk_period;
    s_rst <= '0';
    WAIT FOR c_clk_period;
    -- Wait for phase sync
    WAIT UNTIL s_phase = "00" AND rising_edge(s_clk);

    -- PMU-T-001: 0 x 0 = 0
    do_multiply(x"00000", x"00000", x"00000", "PMU-T-001: 0 x 0");

    -- PMU-T-002: positive x 0 = 0
    do_multiply(x"40000", x"00000", x"00000", "PMU-T-002: 0.5 x 0");

    -- PMU-T-003: 0.5 x 0.5 = 0.25
    do_multiply(x"40000", x"40000", x"20000", "PMU-T-003: 0.5 x 0.5");

    -- PMU-T-004: 0.5 x (-0.5) = -0.25
    do_multiply(x"40000", x"C0000", x"E0000", "PMU-T-004: 0.5 x (-0.5)");

    -- PMU-T-005: (-0.5) x (-0.5) = +0.25
    do_multiply(x"C0000", x"C0000", x"20000", "PMU-T-005: (-0.5) x (-0.5)");

    -- PMU-T-006: 0.5 x 0.25 = 0.125
    do_multiply(x"40000", x"20000", x"10000", "PMU-T-006: 0.5 x 0.25");

    -- PMU-T-010: Reset during operation
    REPORT "PMU-T-010: Reset during operation..." SEVERITY NOTE;
    run_wo_phase(x"40000", x"40000");
    WAIT FOR 5 * c_clk_period;
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_rst <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT s_busy = '0'
      REPORT "PMU-T-010 FAILED: busy not cleared on reset" SEVERITY ERROR;
    REPORT "PMU-T-010: Reset during operation PASSED" SEVERITY NOTE;

    WAIT FOR 5 * c_clk_period;

    -- Summary
    REPORT "======================================" SEVERITY NOTE;
    REPORT "PMU Testbench Complete (Bit-Serial)" SEVERITY NOTE;
    REPORT "Tests run: " & INTEGER'image(s_test_count) SEVERITY NOTE;
    REPORT "Failures:  " & INTEGER'image(s_fail_count) SEVERITY NOTE;
    REPORT "======================================" SEVERITY NOTE;

    REPORT "sim complete" SEVERITY FAILURE;
  END PROCESS stim_proc;

END ARCHITECTURE bench;

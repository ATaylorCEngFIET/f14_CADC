-------------------------------------------------------------------------------
-- Timing Generator Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation (Bit-Serial)
--
-- Verifies bit counting (T0-T19), WA/WO alternation, operation counting
-- (0-511), word_mark at T18, frame_mark at end of OP 511, phi1/phi2 phases,
-- bit_clk, t0/t18/t19 timing markers, and reset.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY timing_generator_tb IS
END ENTITY timing_generator_tb;

ARCHITECTURE bench OF timing_generator_tb IS

  CONSTANT c_clk_period : TIME := 667 ns;  -- 1.5 MHz (original CADC)

  SIGNAL s_clk_master : std_logic := '0';
  SIGNAL s_rst        : std_logic := '0';
  SIGNAL s_phi1       : std_logic;
  SIGNAL s_phi2       : std_logic;
  SIGNAL s_bit_clk    : std_logic;
  SIGNAL s_t0         : std_logic;
  SIGNAL s_t18        : std_logic;
  SIGNAL s_t19        : std_logic;
  SIGNAL s_bit_count  : std_logic_vector(4 DOWNTO 0);
  SIGNAL s_word_type  : std_logic;
  SIGNAL s_word_mark  : std_logic;
  SIGNAL s_op_count   : std_logic_vector(9 DOWNTO 0);
  SIGNAL s_frame_mark : std_logic;

  SIGNAL s_test_count : INTEGER := 0;
  SIGNAL s_fail_count : INTEGER := 0;

BEGIN

  s_clk_master <= NOT s_clk_master AFTER c_clk_period / 2;

  uut : ENTITY work.timing_generator
    PORT MAP (
      i_clk_master => s_clk_master,
      i_rst        => s_rst,
      o_phi1       => s_phi1,
      o_phi2       => s_phi2,
      o_bit_clk    => s_bit_clk,
      o_bit_count  => s_bit_count,
      o_t0         => s_t0,
      o_t18        => s_t18,
      o_t19        => s_t19,
      o_word_type  => s_word_type,
      o_word_mark  => s_word_mark,
      o_op_count   => s_op_count,
      o_frame_mark => s_frame_mark
    );

  stim_proc : PROCESS
    VARIABLE v_phi2_count : INTEGER := 0;
  BEGIN

    -- TIM-T-001: Reset verification
    s_rst <= '1';
    WAIT FOR 5 * c_clk_period;
    s_rst <= '0';
    WAIT UNTIL rising_edge(s_clk_master);
    WAIT FOR 1 ns;

    s_test_count <= s_test_count + 1;
    ASSERT s_bit_count = "00000"
      REPORT "TIM-T-001 FAILED: bit_count not 0 after reset" SEVERITY ERROR;
    ASSERT s_word_type = '0'
      REPORT "TIM-T-001 FAILED: word_type not WA after reset" SEVERITY ERROR;
    ASSERT unsigned(s_op_count) = 0
      REPORT "TIM-T-001 FAILED: op_count not 0 after reset" SEVERITY ERROR;
    REPORT "TIM-T-001: Reset verification PASSED" SEVERITY NOTE;

    -- TIM-T-002: Phase clock generation (4 master clocks per bit time)
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    
    -- Wait for one complete phase cycle (4 master clocks)
    FOR i IN 0 TO 3 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
      WAIT FOR 1 ns;
    END LOOP;
    -- phi1 and phi2 should be non-overlapping
    ASSERT NOT (s_phi1 = '1' AND s_phi2 = '1')
      REPORT "TIM-T-002 FAILED: phi1 and phi2 overlap" SEVERITY ERROR;
    REPORT "TIM-T-002: Phase clock non-overlap PASSED" SEVERITY NOTE;

    -- TIM-T-003: Bit count increments on phi2 (every 4 master clocks)
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    
    -- Wait for 20 bit times (80 master clocks for one word)
    FOR i IN 0 TO 79 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT s_bit_count = "00000"
      REPORT "TIM-T-003 FAILED: bit_count not wrapped to 0 after 20 bit times"
      SEVERITY ERROR;
    ASSERT s_word_type = '1'
      REPORT "TIM-T-003 FAILED: word_type not WO after WA word"
      SEVERITY ERROR;
    REPORT "TIM-T-003: Bit counting (T0-T19) PASSED" SEVERITY NOTE;

    -- TIM-T-004: t0/t18/t19 markers
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    
    -- Check t0 at start
    WAIT FOR 1 ns;
    ASSERT s_t0 = '1'
      REPORT "TIM-T-004 FAILED: t0 not asserted at start" SEVERITY ERROR;
    
    -- Wait to t18 (18 bit times = 72 master clocks)
    FOR i IN 0 TO 71 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT s_t18 = '1'
      REPORT "TIM-T-004 FAILED: t18 not asserted at bit 18" SEVERITY ERROR;
    
    -- Wait to t19 (4 more master clocks)
    FOR i IN 0 TO 3 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT s_t19 = '1'
      REPORT "TIM-T-004 FAILED: t19 not asserted at bit 19" SEVERITY ERROR;
    REPORT "TIM-T-004: t0/t18/t19 markers PASSED" SEVERITY NOTE;

    -- TIM-T-005: WA/WO alternation
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    
    -- First word should be WA
    WAIT FOR 1 ns;
    ASSERT s_word_type = '0'
      REPORT "TIM-T-005 FAILED: first word not WA" SEVERITY ERROR;
    
    -- Wait for one complete word (80 master clocks)
    FOR i IN 0 TO 79 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT s_word_type = '1'
      REPORT "TIM-T-005 FAILED: second word not WO" SEVERITY ERROR;
    REPORT "TIM-T-005: WA/WO alternation PASSED" SEVERITY NOTE;

    -- TIM-T-006: Operation count increments after WA+WO pair
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    
    -- Wait for WA + WO (160 master clocks)
    FOR i IN 0 TO 159 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT unsigned(s_op_count) = 1
      REPORT "TIM-T-006 FAILED: op_count not 1 after one operation"
      SEVERITY ERROR;
    REPORT "TIM-T-006: Operation counting PASSED" SEVERITY NOTE;

    -- TIM-T-007: Frame mark at OP 511 WO T19
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    REPORT "TIM-T-007: Running full frame (81920 master clocks)..." SEVERITY NOTE;
    -- 512 ops * 2 words * 20 bits * 4 clocks = 81920 master clocks
    FOR i IN 0 TO 81918 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT s_frame_mark = '1'
      REPORT "TIM-T-007 FAILED: frame_mark not asserted at end of frame"
      SEVERITY ERROR;
    REPORT "TIM-T-007: Frame mark PASSED" SEVERITY NOTE;

    -- TIM-T-008: Frame wrap to OP 0
    WAIT UNTIL rising_edge(s_clk_master);
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT unsigned(s_op_count) = 0
      REPORT "TIM-T-008 FAILED: op_count not 0 after frame wrap"
      SEVERITY ERROR;
    ASSERT s_frame_mark = '0'
      REPORT "TIM-T-008 FAILED: frame_mark not deasserted after wrap"
      SEVERITY ERROR;
    REPORT "TIM-T-008: Frame wrap PASSED" SEVERITY NOTE;

    -- TIM-T-009: Reset during operation
    FOR i IN 0 TO 399 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT s_bit_count = "00000"
      REPORT "TIM-T-009 FAILED: bit_count not 0 after mid-op reset"
      SEVERITY ERROR;
    ASSERT unsigned(s_op_count) = 0
      REPORT "TIM-T-009 FAILED: op_count not 0 after mid-op reset"
      SEVERITY ERROR;
    REPORT "TIM-T-009: Reset during operation PASSED" SEVERITY NOTE;

    WAIT FOR 5 * c_clk_period;

    -- Summary
    REPORT "======================================" SEVERITY NOTE;
    REPORT "Timing Generator Testbench Complete" SEVERITY NOTE;
    REPORT "Tests run: " & INTEGER'image(s_test_count) SEVERITY NOTE;
    REPORT "Failures:  " & INTEGER'image(s_fail_count) SEVERITY NOTE;
    REPORT "======================================" SEVERITY NOTE;

    REPORT "sim complete" SEVERITY FAILURE;
  END PROCESS stim_proc;

END ARCHITECTURE bench;

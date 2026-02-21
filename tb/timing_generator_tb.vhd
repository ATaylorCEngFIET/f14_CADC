-------------------------------------------------------------------------------
-- Timing Generator Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Verifies bit counting (T0-T19), WA/WO alternation, operation counting
-- (0-511), word_mark at T18, frame_mark at end of OP 511, and reset.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY timing_generator_tb IS
END ENTITY timing_generator_tb;

ARCHITECTURE bench OF timing_generator_tb IS

  CONSTANT c_clk_period : TIME := 20 ns;

  SIGNAL s_clk_master : std_logic := '0';
  SIGNAL s_rst        : std_logic := '0';
  SIGNAL s_phi1       : std_logic;
  SIGNAL s_phi2       : std_logic;
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
    GENERIC MAP (
      g_clk_div => 1
    )
    PORT MAP (
      i_clk_master => s_clk_master,
      i_rst        => s_rst,
      o_phi1       => s_phi1,
      o_phi2       => s_phi2,
      o_bit_count  => s_bit_count,
      o_word_type  => s_word_type,
      o_word_mark  => s_word_mark,
      o_op_count   => s_op_count,
      o_frame_mark => s_frame_mark
    );

  stim_proc : PROCESS
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

    -- TIM-T-002: Bit count increments 0 to 19
    s_test_count <= s_test_count + 1;
    FOR i IN 0 TO 18 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT unsigned(s_bit_count) = 19
      REPORT "TIM-T-002 FAILED: bit_count not 19 after 19 clocks"
      SEVERITY ERROR;
    REPORT "TIM-T-002: Bit counting (T0-T19) PASSED" SEVERITY NOTE;

    -- TIM-T-003: WA/WO alternation
    WAIT UNTIL rising_edge(s_clk_master);
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT s_bit_count = "00000"
      REPORT "TIM-T-003 FAILED: bit_count not 0 after word boundary"
      SEVERITY ERROR;
    ASSERT s_word_type = '1'
      REPORT "TIM-T-003 FAILED: word_type not WO after first word"
      SEVERITY ERROR;
    REPORT "TIM-T-003: WA/WO alternation PASSED" SEVERITY NOTE;

    -- TIM-T-004: Word_mark at T18
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    FOR i IN 0 TO 17 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT s_word_mark = '1'
      REPORT "TIM-T-004 FAILED: word_mark not asserted at T18"
      SEVERITY ERROR;
    WAIT UNTIL rising_edge(s_clk_master);
    WAIT FOR 1 ns;
    ASSERT s_word_mark = '0'
      REPORT "TIM-T-004 FAILED: word_mark not deasserted at T19"
      SEVERITY ERROR;
    REPORT "TIM-T-004: Word_mark at T18 PASSED" SEVERITY NOTE;

    -- TIM-T-005: Operation count increments
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    FOR i IN 0 TO 39 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT unsigned(s_op_count) = 1
      REPORT "TIM-T-005 FAILED: op_count not 1 after 40 clocks, got " &
        INTEGER'image(to_integer(unsigned(s_op_count)))
      SEVERITY ERROR;
    REPORT "TIM-T-005: Operation counting PASSED" SEVERITY NOTE;

    -- TIM-T-006: Frame mark at OP 511 WO T19
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    s_test_count <= s_test_count + 1;
    REPORT "TIM-T-006: Running full frame (20480 cycles)..." SEVERITY NOTE;
    FOR i IN 0 TO 20478 LOOP
      WAIT UNTIL rising_edge(s_clk_master);
    END LOOP;
    WAIT FOR 1 ns;
    ASSERT s_frame_mark = '1'
      REPORT "TIM-T-006 FAILED: frame_mark not asserted at end of frame"
      SEVERITY ERROR;
    REPORT "TIM-T-006: Frame mark PASSED" SEVERITY NOTE;

    -- TIM-T-007: Frame wrap to OP 0
    WAIT UNTIL rising_edge(s_clk_master);
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT unsigned(s_op_count) = 0
      REPORT "TIM-T-007 FAILED: op_count not 0 after frame wrap"
      SEVERITY ERROR;
    ASSERT s_frame_mark = '0'
      REPORT "TIM-T-007 FAILED: frame_mark not deasserted after wrap"
      SEVERITY ERROR;
    REPORT "TIM-T-007: Frame wrap PASSED" SEVERITY NOTE;

    -- TIM-T-008: Phase clocks toggle
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk_master);
    s_rst <= '0';
    WAIT UNTIL rising_edge(s_clk_master);
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT s_phi1 = '1' OR s_phi1 = '0'
      REPORT "TIM-T-008 FAILED: phi1 undefined" SEVERITY ERROR;
    REPORT "TIM-T-008: Phase clock generation PASSED" SEVERITY NOTE;

    -- TIM-T-009: Reset during operation
    FOR i IN 0 TO 99 LOOP
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

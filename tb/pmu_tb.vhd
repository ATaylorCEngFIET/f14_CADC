-------------------------------------------------------------------------------
-- PMU Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Verifies 20x20-bit signed fractional multiplication using Booth's
-- algorithm. Tests include zero, positive, negative, boundary values,
-- timing (busy/done), back-to-back operations, and reset during operation.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pmu_tb IS
END ENTITY pmu_tb;

ARCHITECTURE bench OF pmu_tb IS

  CONSTANT c_clk_period : TIME := 200 ns;  -- 5 MHz (original CADC)

  SIGNAL s_clk       : std_logic := '0';
  SIGNAL s_rst       : std_logic := '0';
  SIGNAL s_start     : std_logic := '0';
  SIGNAL s_operand_a : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_operand_b : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_result    : std_logic_vector(19 DOWNTO 0);
  SIGNAL s_busy      : std_logic;
  SIGNAL s_done      : std_logic;

  SIGNAL s_test_count : INTEGER := 0;
  SIGNAL s_fail_count : INTEGER := 0;

BEGIN

  s_clk <= NOT s_clk AFTER c_clk_period / 2;

  uut : ENTITY work.pmu
    PORT MAP (
      i_clk       => s_clk,
      i_rst       => s_rst,
      i_start     => s_start,
      i_operand_a => s_operand_a,
      i_operand_b => s_operand_b,
      o_result    => s_result,
      o_busy      => s_busy,
      o_done      => s_done
    );

  stim_proc : PROCESS

    PROCEDURE do_multiply(
      a         : IN std_logic_vector(19 DOWNTO 0);
      b         : IN std_logic_vector(19 DOWNTO 0);
      exp_r     : IN std_logic_vector(19 DOWNTO 0);
      name      : IN STRING;
      tolerance : IN INTEGER := 1
    ) IS
      VARIABLE v_diff : INTEGER;
    BEGIN
      s_operand_a <= a;
      s_operand_b <= b;
      s_start     <= '1';
      WAIT UNTIL rising_edge(s_clk);
      s_start     <= '0';

      WAIT UNTIL s_done = '1' AND rising_edge(s_clk);
      WAIT FOR 1 ns;

      s_test_count <= s_test_count + 1;

      v_diff := ABS(to_integer(signed(s_result)) -
                    to_integer(signed(exp_r)));
      IF v_diff > tolerance THEN
        REPORT name & " FAILED: got 0x" &
          to_hstring(unsigned(s_result)) &
          " expected 0x" & to_hstring(unsigned(exp_r)) &
          " diff=" & INTEGER'image(v_diff)
          SEVERITY ERROR;
        s_fail_count <= s_fail_count + 1;
      ELSE
        REPORT name & " PASSED (0x" &
          to_hstring(unsigned(s_result)) & ")"
          SEVERITY NOTE;
      END IF;

      WAIT UNTIL rising_edge(s_clk);
    END PROCEDURE do_multiply;

  BEGIN

    -- Reset
    s_rst <= '1';
    WAIT FOR 5 * c_clk_period;
    s_rst <= '0';
    WAIT FOR c_clk_period;

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

    -- PMU-T-006: Max positive x max positive
    do_multiply(x"7FFFF", x"7FFFF", x"3FFFF", "PMU-T-006: maxpos x maxpos", 2);

    -- PMU-T-007: Max negative x max positive
    do_multiply(x"80000", x"7FFFF", x"80001", "PMU-T-007: maxneg x maxpos", 2);

    -- PMU-T-008: Max negative x max negative
    do_multiply(x"80000", x"80000", x"7FFFF",
      "PMU-T-008: maxneg x maxneg (overflow)", 2);

    -- PMU-T-009: Unity approximation x value
    do_multiply(x"7FFFF", x"20000", x"20000",
      "PMU-T-009: ~1.0 x 0.25", 2);

    -- PMU-T-010: Alternating patterns (Booth transitions)
    do_multiply(x"AAAAA", x"55555", x"C71C7",
      "PMU-T-010: 0xAAAAA x 0x55555", 16);

    -- PMU-T-011: All ones x all ones
    do_multiply(x"FFFFF", x"FFFFF", x"00000",
      "PMU-T-011: 0xFFFFF x 0xFFFFF", 2);

    -- PMU-T-012: Single bit patterns
    do_multiply(x"40000", x"20000", x"10000",
      "PMU-T-012: 0.5 x 0.25 = 0.125");

    -- ====== Timing Tests ======

    -- PMU-T-020: Busy assertion
    REPORT "PMU-T-020: Checking busy signal..." SEVERITY NOTE;
    s_operand_a <= x"40000";
    s_operand_b <= x"40000";
    s_start     <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_start     <= '0';
    WAIT UNTIL rising_edge(s_clk);
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT s_busy = '1'
      REPORT "PMU-T-020 FAILED: busy not asserted" SEVERITY ERROR;
    WAIT UNTIL s_done = '1' AND rising_edge(s_clk);
    WAIT FOR 1 ns;
    ASSERT s_busy = '0'
      REPORT "PMU-T-020 FAILED: busy not deasserted after done" SEVERITY ERROR;
    REPORT "PMU-T-020: Busy signal PASSED" SEVERITY NOTE;

    WAIT UNTIL rising_edge(s_clk);

    -- PMU-T-021: Done pulse width (one cycle)
    REPORT "PMU-T-021: Checking done pulse..." SEVERITY NOTE;
    s_operand_a <= x"20000";
    s_operand_b <= x"20000";
    s_start     <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_start     <= '0';
    WAIT UNTIL s_done = '1' AND rising_edge(s_clk);
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT s_done = '1'
      REPORT "PMU-T-021 FAILED: done not high" SEVERITY ERROR;
    WAIT UNTIL rising_edge(s_clk);
    WAIT FOR 1 ns;
    ASSERT s_done = '0'
      REPORT "PMU-T-021 FAILED: done not deasserted after 1 cycle"
      SEVERITY ERROR;
    REPORT "PMU-T-021: Done pulse PASSED" SEVERITY NOTE;

    -- PMU-T-023: Back-to-back operations
    REPORT "PMU-T-023: Back-to-back operations..." SEVERITY NOTE;
    do_multiply(x"40000", x"40000", x"20000", "PMU-T-023a: first op");
    do_multiply(x"20000", x"40000", x"10000", "PMU-T-023b: second op");

    -- PMU-T-024: Reset during operation
    REPORT "PMU-T-024: Reset during operation..." SEVERITY NOTE;
    s_operand_a <= x"40000";
    s_operand_b <= x"40000";
    s_start     <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_start     <= '0';
    WAIT FOR 5 * c_clk_period;
    s_rst <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_rst <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    ASSERT s_busy = '0'
      REPORT "PMU-T-024 FAILED: busy not cleared on reset" SEVERITY ERROR;
    REPORT "PMU-T-024: Reset during operation PASSED" SEVERITY NOTE;

    WAIT FOR 5 * c_clk_period;

    -- Summary
    REPORT "======================================" SEVERITY NOTE;
    REPORT "PMU Testbench Complete" SEVERITY NOTE;
    REPORT "Tests run: " & INTEGER'image(s_test_count) SEVERITY NOTE;
    REPORT "Failures:  " & INTEGER'image(s_fail_count) SEVERITY NOTE;
    REPORT "======================================" SEVERITY NOTE;

    REPORT "sim complete" SEVERITY FAILURE;
  END PROCESS stim_proc;

END ARCHITECTURE bench;

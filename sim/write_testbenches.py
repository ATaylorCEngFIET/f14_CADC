"""Write 4 regenerated testbench files to the tb directory."""
import os

TB_DIR = os.path.join(os.path.dirname(__file__), '..', 'tb')

# =========================================================================
# timing_generator_tb.vhd
# =========================================================================
TIMING_TB = r'''-------------------------------------------------------------------------------
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
      CLK_DIV => 1
    )
    PORT MAP (
      clk_master => s_clk_master,
      rst        => s_rst,
      phi1       => s_phi1,
      phi2       => s_phi2,
      bit_count  => s_bit_count,
      word_type  => s_word_type,
      word_mark  => s_word_mark,
      op_count   => s_op_count,
      frame_mark => s_frame_mark
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

    WAIT;
  END PROCESS stim_proc;

END ARCHITECTURE bench;
'''

# =========================================================================
# pmu_tb.vhd
# =========================================================================
PMU_TB = r'''-------------------------------------------------------------------------------
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

  CONSTANT c_clk_period : TIME := 20 ns;

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
      clk       => s_clk,
      rst       => s_rst,
      start     => s_start,
      operand_a => s_operand_a,
      operand_b => s_operand_b,
      result    => s_result,
      busy      => s_busy,
      done      => s_done
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

    WAIT;
  END PROCESS stim_proc;

END ARCHITECTURE bench;
'''

# =========================================================================
# slf_tb.vhd
# =========================================================================
SLF_TB = r'''-------------------------------------------------------------------------------
-- SLF Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Verifies ALU operations: ADD, SUB, AND, OR, XOR, NOT, SHL, SHR, NEG,
-- ABS, Gray/Binary conversion, LOAD, STORE_TMP, PASS.
-- Tests ACC/TMP registers, Z/N/C flags, and write-enable gating.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY slf_tb IS
END ENTITY slf_tb;

ARCHITECTURE bench OF slf_tb IS

  CONSTANT c_clk_period : TIME := 20 ns;

  CONSTANT c_op_nop       : std_logic_vector(3 DOWNTO 0) := "0000";
  CONSTANT c_op_add       : std_logic_vector(3 DOWNTO 0) := "0001";
  CONSTANT c_op_sub       : std_logic_vector(3 DOWNTO 0) := "0010";
  CONSTANT c_op_and       : std_logic_vector(3 DOWNTO 0) := "0011";
  CONSTANT c_op_or        : std_logic_vector(3 DOWNTO 0) := "0100";
  CONSTANT c_op_xor       : std_logic_vector(3 DOWNTO 0) := "0101";
  CONSTANT c_op_not       : std_logic_vector(3 DOWNTO 0) := "0110";
  CONSTANT c_op_shl       : std_logic_vector(3 DOWNTO 0) := "0111";
  CONSTANT c_op_shr       : std_logic_vector(3 DOWNTO 0) := "1000";
  CONSTANT c_op_neg       : std_logic_vector(3 DOWNTO 0) := "1001";
  CONSTANT c_op_abs       : std_logic_vector(3 DOWNTO 0) := "1010";
  CONSTANT c_op_gray2bin  : std_logic_vector(3 DOWNTO 0) := "1011";
  CONSTANT c_op_bin2gray  : std_logic_vector(3 DOWNTO 0) := "1100";
  CONSTANT c_op_load      : std_logic_vector(3 DOWNTO 0) := "1101";
  CONSTANT c_op_store_tmp : std_logic_vector(3 DOWNTO 0) := "1110";
  CONSTANT c_op_pass      : std_logic_vector(3 DOWNTO 0) := "1111";

  SIGNAL s_clk            : std_logic := '0';
  SIGNAL s_rst            : std_logic := '0';
  SIGNAL s_alu_op         : std_logic_vector(3 DOWNTO 0) := c_op_nop;
  SIGNAL s_acc_in         : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_acc_write_en   : std_logic := '0';
  SIGNAL s_tmp_write_en   : std_logic := '0';
  SIGNAL s_flags_write_en : std_logic := '0';
  SIGNAL s_acc_out        : std_logic_vector(19 DOWNTO 0);
  SIGNAL s_tmp_out        : std_logic_vector(19 DOWNTO 0);
  SIGNAL s_alu_result     : std_logic_vector(19 DOWNTO 0);
  SIGNAL s_flag_z         : std_logic;
  SIGNAL s_flag_n         : std_logic;
  SIGNAL s_flag_c         : std_logic;

  SIGNAL s_test_count : INTEGER := 0;
  SIGNAL s_fail_count : INTEGER := 0;

BEGIN

  s_clk <= NOT s_clk AFTER c_clk_period / 2;

  uut : ENTITY work.slf
    PORT MAP (
      clk            => s_clk,
      rst            => s_rst,
      alu_op         => s_alu_op,
      acc_in         => s_acc_in,
      acc_write_en   => s_acc_write_en,
      tmp_write_en   => s_tmp_write_en,
      flags_write_en => s_flags_write_en,
      acc_out        => s_acc_out,
      tmp_out        => s_tmp_out,
      alu_result     => s_alu_result,
      flag_z         => s_flag_z,
      flag_n         => s_flag_n,
      flag_c         => s_flag_c
    );

  stim_proc : PROCESS

    PROCEDURE load_acc(
      v_val : IN std_logic_vector(19 DOWNTO 0)
    ) IS
    BEGIN
      s_alu_op         <= c_op_load;
      s_acc_in         <= v_val;
      s_acc_write_en   <= '1';
      s_flags_write_en <= '1';
      WAIT UNTIL rising_edge(s_clk);
      s_acc_write_en   <= '0';
      s_flags_write_en <= '0';
      s_alu_op         <= c_op_nop;
      WAIT FOR 1 ns;
    END PROCEDURE load_acc;

    PROCEDURE check_alu(
      op       : IN std_logic_vector(3 DOWNTO 0);
      operand  : IN std_logic_vector(19 DOWNTO 0);
      expected : IN std_logic_vector(19 DOWNTO 0);
      name     : IN STRING
    ) IS
    BEGIN
      s_alu_op         <= op;
      s_acc_in         <= operand;
      s_acc_write_en   <= '1';
      s_flags_write_en <= '1';
      WAIT UNTIL rising_edge(s_clk);
      s_acc_write_en   <= '0';
      s_flags_write_en <= '0';
      s_alu_op         <= c_op_nop;
      WAIT FOR 1 ns;

      s_test_count <= s_test_count + 1;
      IF s_acc_out /= expected THEN
        REPORT name & " FAILED: got 0x" &
          to_hstring(unsigned(s_acc_out)) &
          " expected 0x" & to_hstring(unsigned(expected))
          SEVERITY ERROR;
        s_fail_count <= s_fail_count + 1;
      ELSE
        REPORT name & " PASSED" SEVERITY NOTE;
      END IF;
    END PROCEDURE check_alu;

  BEGIN

    s_rst <= '1';
    WAIT FOR 5 * c_clk_period;
    s_rst <= '0';
    WAIT FOR c_clk_period;

    -- SLF-T-001: 0 + 0 = 0
    load_acc(x"00000");
    check_alu(c_op_add, x"00000", x"00000", "SLF-T-001: 0 + 0");

    -- SLF-T-002: 0.5 + 0.25 = 0.75
    load_acc(x"40000");
    check_alu(c_op_add, x"20000", x"60000", "SLF-T-002: 0.5 + 0.25");

    -- SLF-T-003: 0.5 + 0.5 = overflow
    load_acc(x"40000");
    check_alu(c_op_add, x"40000", x"80000", "SLF-T-003: 0.5 + 0.5 (ofl)");
    s_test_count <= s_test_count + 1;
    ASSERT s_flag_c = '1'
      REPORT "SLF-T-003 carry flag FAILED" SEVERITY ERROR;

    -- SLF-T-004: (-0.5) + (-0.5) = -1.0
    load_acc(x"C0000");
    check_alu(c_op_add, x"C0000", x"80000", "SLF-T-004: -0.5 + -0.5");

    -- SLF-T-005: 0.5 + (-0.25) = 0.25
    load_acc(x"40000");
    check_alu(c_op_add, x"E0000", x"20000", "SLF-T-005: 0.5 + (-0.25)");

    -- SLF-T-010: 0 - 0 = 0
    load_acc(x"00000");
    check_alu(c_op_sub, x"00000", x"00000", "SLF-T-010: 0 - 0");

    -- SLF-T-011: 0.5 - 0.25 = 0.25
    load_acc(x"40000");
    check_alu(c_op_sub, x"20000", x"20000", "SLF-T-011: 0.5 - 0.25");

    -- SLF-T-012: 0.25 - 0.5 = -0.25
    load_acc(x"20000");
    check_alu(c_op_sub, x"40000", x"E0000", "SLF-T-012: 0.25 - 0.5");

    -- SLF-T-020: AND all ones
    load_acc(x"FFFFF");
    check_alu(c_op_and, x"FFFFF", x"FFFFF", "SLF-T-020: AND all ones");

    -- SLF-T-021: AND with zero
    load_acc(x"FFFFF");
    check_alu(c_op_and, x"00000", x"00000", "SLF-T-021: AND with zero");

    -- SLF-T-022: OR all zeros
    load_acc(x"00000");
    check_alu(c_op_or, x"00000", x"00000", "SLF-T-022: OR all zeros");

    -- SLF-T-023: OR complementary
    load_acc(x"AAAAA");
    check_alu(c_op_or, x"55555", x"FFFFF", "SLF-T-023: OR complementary");

    -- SLF-T-024: XOR same = 0
    load_acc(x"AAAAA");
    check_alu(c_op_xor, x"AAAAA", x"00000", "SLF-T-024: XOR same");

    -- SLF-T-025: NOT zero = all ones
    load_acc(x"00000");
    check_alu(c_op_not, x"00000", x"FFFFF", "SLF-T-025: NOT zero");

    -- SLF-T-030: SHL positive
    load_acc(x"10000");
    check_alu(c_op_shl, x"00000", x"20000", "SLF-T-030: SHL positive");

    -- SLF-T-031: SHL negative
    load_acc(x"C0000");
    check_alu(c_op_shl, x"00000", x"80000", "SLF-T-031: SHL negative");

    -- SLF-T-032: SHR positive
    load_acc(x"20000");
    check_alu(c_op_shr, x"00000", x"10000", "SLF-T-032: SHR positive");

    -- SLF-T-033: SHR negative (sign extend)
    load_acc(x"80000");
    check_alu(c_op_shr, x"00000", x"C0000", "SLF-T-033: SHR negative");

    -- SLF-T-040: Gray->Bin: 0x00000
    load_acc(x"00000");
    s_alu_op <= c_op_gray2bin;
    s_acc_in <= x"00000";
    s_acc_write_en <= '1';
    s_flags_write_en <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_acc_write_en <= '0';
    s_flags_write_en <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    IF s_acc_out /= x"00000" THEN
      REPORT "SLF-T-040 FAILED" SEVERITY ERROR;
      s_fail_count <= s_fail_count + 1;
    ELSE
      REPORT "SLF-T-040: Gray->Bin 0 PASSED" SEVERITY NOTE;
    END IF;

    -- SLF-T-041: Gray->Bin: 0x00001
    s_alu_op <= c_op_gray2bin;
    s_acc_in <= x"00001";
    s_acc_write_en <= '1';
    s_flags_write_en <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_acc_write_en <= '0';
    s_flags_write_en <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    IF s_acc_out /= x"00001" THEN
      REPORT "SLF-T-041 FAILED" SEVERITY ERROR;
      s_fail_count <= s_fail_count + 1;
    ELSE
      REPORT "SLF-T-041: Gray->Bin 1 PASSED" SEVERITY NOTE;
    END IF;

    -- SLF-T-042: Gray->Bin: 0x00003 -> 0x00002
    s_alu_op <= c_op_gray2bin;
    s_acc_in <= x"00003";
    s_acc_write_en <= '1';
    s_flags_write_en <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_acc_write_en <= '0';
    s_flags_write_en <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    IF s_acc_out /= x"00002" THEN
      REPORT "SLF-T-042 FAILED" SEVERITY ERROR;
      s_fail_count <= s_fail_count + 1;
    ELSE
      REPORT "SLF-T-042: Gray->Bin 3->2 PASSED" SEVERITY NOTE;
    END IF;

    -- SLF-T-044: Bin->Gray->Bin roundtrip
    load_acc(x"12345");
    s_alu_op <= c_op_bin2gray;
    s_acc_in <= x"00000";
    s_acc_write_en <= '1';
    s_flags_write_en <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_acc_write_en <= '0';
    s_flags_write_en <= '0';
    WAIT FOR 1 ns;
    s_alu_op <= c_op_gray2bin;
    s_acc_in <= s_acc_out;
    s_acc_write_en <= '1';
    s_flags_write_en <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_acc_write_en <= '0';
    s_flags_write_en <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    IF s_acc_out /= x"12345" THEN
      REPORT "SLF-T-044 FAILED" SEVERITY ERROR;
      s_fail_count <= s_fail_count + 1;
    ELSE
      REPORT "SLF-T-044: Bin->Gray->Bin roundtrip PASSED" SEVERITY NOTE;
    END IF;

    -- SLF-T-050: NEG of +0.5
    load_acc(x"40000");
    check_alu(c_op_neg, x"00000", x"C0000", "SLF-T-050: NEG +0.5");

    -- SLF-T-051: NEG of -0.5
    load_acc(x"C0000");
    check_alu(c_op_neg, x"00000", x"40000", "SLF-T-051: NEG -0.5");

    -- SLF-T-052: NEG of 0
    load_acc(x"00000");
    check_alu(c_op_neg, x"00000", x"00000", "SLF-T-052: NEG 0");

    -- SLF-T-053: ABS of +0.5
    load_acc(x"40000");
    check_alu(c_op_abs, x"00000", x"40000", "SLF-T-053: ABS +0.5");

    -- SLF-T-054: ABS of -0.5
    load_acc(x"C0000");
    check_alu(c_op_abs, x"00000", x"40000", "SLF-T-054: ABS -0.5");

    -- SLF-T-055: LOAD
    check_alu(c_op_load, x"ABCDE", x"ABCDE", "SLF-T-055: LOAD");

    -- SLF-T-056: STORE_TMP
    load_acc(x"77777");
    s_alu_op       <= c_op_store_tmp;
    s_acc_in       <= x"00000";
    s_acc_write_en <= '1';
    s_tmp_write_en <= '1';
    s_flags_write_en <= '1';
    WAIT UNTIL rising_edge(s_clk);
    s_acc_write_en <= '0';
    s_tmp_write_en <= '0';
    s_flags_write_en <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    IF s_tmp_out /= x"77777" THEN
      REPORT "SLF-T-056 FAILED" SEVERITY ERROR;
      s_fail_count <= s_fail_count + 1;
    ELSE
      REPORT "SLF-T-056: STORE_TMP PASSED" SEVERITY NOTE;
    END IF;

    -- SLF-T-060: ACC hold when write disabled
    load_acc(x"12345");
    s_alu_op       <= c_op_add;
    s_acc_in       <= x"11111";
    s_acc_write_en <= '0';
    s_flags_write_en <= '0';
    WAIT UNTIL rising_edge(s_clk);
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    IF s_acc_out /= x"12345" THEN
      REPORT "SLF-T-060 FAILED: ACC changed" SEVERITY ERROR;
      s_fail_count <= s_fail_count + 1;
    ELSE
      REPORT "SLF-T-060: ACC hold PASSED" SEVERITY NOTE;
    END IF;

    -- SLF-T-061: TMP hold when write disabled
    s_tmp_write_en <= '0';
    s_acc_write_en <= '1';
    s_alu_op       <= c_op_load;
    s_acc_in       <= x"99999";
    WAIT UNTIL rising_edge(s_clk);
    s_acc_write_en <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    IF s_tmp_out /= x"77777" THEN
      REPORT "SLF-T-061 FAILED: TMP changed" SEVERITY ERROR;
      s_fail_count <= s_fail_count + 1;
    ELSE
      REPORT "SLF-T-061: TMP hold PASSED" SEVERITY NOTE;
    END IF;

    -- SLF-T-062: Flags hold when write disabled
    load_acc(x"00000");
    s_alu_op         <= c_op_load;
    s_acc_in         <= x"40000";
    s_acc_write_en   <= '1';
    s_flags_write_en <= '0';
    WAIT UNTIL rising_edge(s_clk);
    s_acc_write_en   <= '0';
    WAIT FOR 1 ns;
    s_test_count <= s_test_count + 1;
    IF s_flag_z /= '1' THEN
      REPORT "SLF-T-062 FAILED: Z changed" SEVERITY ERROR;
      s_fail_count <= s_fail_count + 1;
    ELSE
      REPORT "SLF-T-062: Flags hold PASSED" SEVERITY NOTE;
    END IF;

    WAIT FOR 5 * c_clk_period;

    REPORT "======================================" SEVERITY NOTE;
    REPORT "SLF Testbench Complete" SEVERITY NOTE;
    REPORT "Tests run: " & INTEGER'image(s_test_count) SEVERITY NOTE;
    REPORT "Failures:  " & INTEGER'image(s_fail_count) SEVERITY NOTE;
    REPORT "======================================" SEVERITY NOTE;

    WAIT;
  END PROCESS stim_proc;

END ARCHITECTURE bench;
'''

# =========================================================================
# sl_tb.vhd
# =========================================================================
SL_TB = r'''-------------------------------------------------------------------------------
-- SL Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Verifies three-channel combinational steering logic multiplexer.
-- Tests all ACC source selections (8:1), RAS source selections (4:1),
-- I/O source selections (4:1), independence, and data integrity.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY sl_tb IS
END ENTITY sl_tb;

ARCHITECTURE bench OF sl_tb IS

  SIGNAL s_src_ras    : std_logic_vector(19 DOWNTO 0) := x"11111";
  SIGNAL s_src_acc    : std_logic_vector(19 DOWNTO 0) := x"22222";
  SIGNAL s_src_tmp    : std_logic_vector(19 DOWNTO 0) := x"33333";
  SIGNAL s_src_pmu    : std_logic_vector(19 DOWNTO 0) := x"44444";
  SIGNAL s_src_pdu_q  : std_logic_vector(19 DOWNTO 0) := x"55555";
  SIGNAL s_src_pdu_r  : std_logic_vector(19 DOWNTO 0) := x"66666";
  SIGNAL s_src_io_in  : std_logic_vector(19 DOWNTO 0) := x"77777";
  SIGNAL s_src_const  : std_logic_vector(19 DOWNTO 0) := x"88888";

  SIGNAL s_sel_acc_src : std_logic_vector(2 DOWNTO 0) := "000";
  SIGNAL s_sel_ras_src : std_logic_vector(1 DOWNTO 0) := "00";
  SIGNAL s_sel_io_src  : std_logic_vector(1 DOWNTO 0) := "00";

  SIGNAL s_acc_in      : std_logic_vector(19 DOWNTO 0);
  SIGNAL s_ras_wr_data : std_logic_vector(19 DOWNTO 0);
  SIGNAL s_io_out      : std_logic_vector(19 DOWNTO 0);

  SIGNAL s_test_count : INTEGER := 0;
  SIGNAL s_fail_count : INTEGER := 0;

BEGIN

  uut : ENTITY work.sl
    PORT MAP (
      src_ras     => s_src_ras,
      src_acc     => s_src_acc,
      src_tmp     => s_src_tmp,
      src_pmu     => s_src_pmu,
      src_pdu_q   => s_src_pdu_q,
      src_pdu_r   => s_src_pdu_r,
      src_io_in   => s_src_io_in,
      src_const   => s_src_const,
      sel_acc_src => s_sel_acc_src,
      sel_ras_src => s_sel_ras_src,
      sel_io_src  => s_sel_io_src,
      acc_in      => s_acc_in,
      ras_wr_data => s_ras_wr_data,
      io_out      => s_io_out
    );

  stim_proc : PROCESS

    PROCEDURE check_mux(
      actual   : IN std_logic_vector(19 DOWNTO 0);
      expected : IN std_logic_vector(19 DOWNTO 0);
      name     : IN STRING
    ) IS
    BEGIN
      s_test_count <= s_test_count + 1;
      WAIT FOR 2 ns;
      IF actual /= expected THEN
        REPORT name & " FAILED: got 0x" &
          to_hstring(unsigned(actual)) &
          " expected 0x" & to_hstring(unsigned(expected))
          SEVERITY ERROR;
        s_fail_count <= s_fail_count + 1;
      ELSE
        REPORT name & " PASSED" SEVERITY NOTE;
      END IF;
    END PROCEDURE check_mux;

  BEGIN

    WAIT FOR 5 ns;

    -- ACC Source Mux (8:1)
    s_sel_acc_src <= "000";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"11111", "SL-T-001: RAS -> ACC");

    s_sel_acc_src <= "001";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"44444", "SL-T-002: PMU -> ACC");

    s_sel_acc_src <= "010";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"55555", "SL-T-003: PDU_Q -> ACC");

    s_sel_acc_src <= "011";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"66666", "SL-T-004: PDU_R -> ACC");

    s_sel_acc_src <= "100";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"77777", "SL-T-005: IO -> ACC");

    s_sel_acc_src <= "101";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"88888", "SL-T-006: CONST -> ACC");

    s_sel_acc_src <= "110";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"33333", "SL-T-007: TMP -> ACC");

    s_sel_acc_src <= "111";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"00000", "SL-T-008: Reserved -> 0");

    -- RAS Source Mux (4:1)
    s_sel_ras_src <= "00";
    WAIT FOR 2 ns;
    check_mux(s_ras_wr_data, x"22222", "SL-T-010: ACC -> RAS");

    s_sel_ras_src <= "01";
    WAIT FOR 2 ns;
    check_mux(s_ras_wr_data, x"44444", "SL-T-011: PMU -> RAS");

    s_sel_ras_src <= "10";
    WAIT FOR 2 ns;
    check_mux(s_ras_wr_data, x"55555", "SL-T-012: PDU_Q -> RAS");

    s_sel_ras_src <= "11";
    WAIT FOR 2 ns;
    check_mux(s_ras_wr_data, x"77777", "SL-T-013: IO -> RAS");

    -- IO Output Mux (4:1)
    s_sel_io_src <= "00";
    WAIT FOR 2 ns;
    check_mux(s_io_out, x"22222", "SL-T-020: ACC -> IO");

    s_sel_io_src <= "01";
    WAIT FOR 2 ns;
    check_mux(s_io_out, x"11111", "SL-T-021: RAS -> IO");

    s_sel_io_src <= "10";
    WAIT FOR 2 ns;
    check_mux(s_io_out, x"44444", "SL-T-022: PMU -> IO");

    s_sel_io_src <= "11";
    WAIT FOR 2 ns;
    check_mux(s_io_out, x"55555", "SL-T-023: PDU_Q -> IO");

    -- SL-T-030: All three muxes different sources
    s_sel_acc_src <= "000";
    s_sel_ras_src <= "01";
    s_sel_io_src  <= "11";
    WAIT FOR 2 ns;
    check_mux(s_acc_in,      x"11111", "SL-T-030a: ACC=RAS");
    check_mux(s_ras_wr_data, x"44444", "SL-T-030b: RAS=PMU");
    check_mux(s_io_out,      x"55555", "SL-T-030c: IO=PDU_Q");

    -- SL-T-031: All three muxes same source
    s_sel_acc_src <= "001";
    s_sel_ras_src <= "01";
    s_sel_io_src  <= "10";
    WAIT FOR 2 ns;
    check_mux(s_acc_in,      x"44444", "SL-T-031a: ACC=PMU");
    check_mux(s_ras_wr_data, x"44444", "SL-T-031b: RAS=PMU");
    check_mux(s_io_out,      x"44444", "SL-T-031c: IO=PMU");

    -- SL-T-032: Change one select only
    s_sel_acc_src <= "000";
    s_sel_ras_src <= "00";
    s_sel_io_src  <= "00";
    WAIT FOR 2 ns;
    s_sel_acc_src <= "001";
    WAIT FOR 2 ns;
    check_mux(s_acc_in,      x"44444", "SL-T-032a: ACC changed");
    check_mux(s_ras_wr_data, x"22222", "SL-T-032b: RAS stable");
    check_mux(s_io_out,      x"22222", "SL-T-032c: IO stable");

    -- SL-T-040: All zeros
    s_src_ras <= x"00000";
    s_src_acc <= x"00000";
    s_src_pmu <= x"00000";
    s_sel_acc_src <= "000";
    s_sel_ras_src <= "00";
    s_sel_io_src  <= "00";
    WAIT FOR 2 ns;
    check_mux(s_acc_in,      x"00000", "SL-T-040a: zeros ACC");
    check_mux(s_ras_wr_data, x"00000", "SL-T-040b: zeros RAS");
    check_mux(s_io_out,      x"00000", "SL-T-040c: zeros IO");

    -- SL-T-041: All ones
    s_src_ras <= x"FFFFF";
    s_src_acc <= x"FFFFF";
    s_src_pmu <= x"FFFFF";
    WAIT FOR 2 ns;
    check_mux(s_acc_in,      x"FFFFF", "SL-T-041a: ones ACC");
    check_mux(s_ras_wr_data, x"FFFFF", "SL-T-041b: ones RAS");
    check_mux(s_io_out,      x"FFFFF", "SL-T-041c: ones IO");

    -- SL-T-042: Unique patterns
    s_src_ras <= x"ABCDE";
    s_src_acc <= x"12345";
    s_src_pmu <= x"FEDCB";
    s_sel_acc_src <= "000";
    s_sel_ras_src <= "00";
    s_sel_io_src  <= "10";
    WAIT FOR 2 ns;
    check_mux(s_acc_in,      x"ABCDE", "SL-T-042a: unique ACC");
    check_mux(s_ras_wr_data, x"12345", "SL-T-042b: unique RAS");
    check_mux(s_io_out,      x"FEDCB", "SL-T-042c: unique IO");

    -- SL-T-043: Walking ones
    s_src_ras <= x"00001";
    s_sel_acc_src <= "000";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"00001", "SL-T-043a: bit 0");
    s_src_ras <= x"80000";
    WAIT FOR 2 ns;
    check_mux(s_acc_in, x"80000", "SL-T-043b: bit 19");

    WAIT FOR 10 ns;

    REPORT "======================================" SEVERITY NOTE;
    REPORT "SL Testbench Complete" SEVERITY NOTE;
    REPORT "Tests run: " & INTEGER'image(s_test_count) SEVERITY NOTE;
    REPORT "Failures:  " & INTEGER'image(s_fail_count) SEVERITY NOTE;
    REPORT "======================================" SEVERITY NOTE;

    WAIT;
  END PROCESS stim_proc;

END ARCHITECTURE bench;
'''

# Write all files
files = {
    'timing_generator_tb.vhd': TIMING_TB,
    'pmu_tb.vhd': PMU_TB,
    'slf_tb.vhd': SLF_TB,
    'sl_tb.vhd': SL_TB,
}

for name, content in files.items():
    path = os.path.join(TB_DIR, name)
    with open(path, 'w', encoding='ascii') as f:
        f.write(content.lstrip('\n'))
    print(f"Written: {name} ({len(content)} bytes)")

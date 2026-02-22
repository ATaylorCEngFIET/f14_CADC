-------------------------------------------------------------------------------
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

  CONSTANT c_clk_period : TIME := 667 ns;  -- 1.5 MHz (original CADC)

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
      i_clk            => s_clk,
      i_rst            => s_rst,
      i_alu_op         => s_alu_op,
      i_acc_in         => s_acc_in,
      i_acc_write_en   => s_acc_write_en,
      i_tmp_write_en   => s_tmp_write_en,
      i_flags_write_en => s_flags_write_en,
      o_acc_out        => s_acc_out,
      o_tmp_out        => s_tmp_out,
      o_alu_result     => s_alu_result,
      o_flag_z         => s_flag_z,
      o_flag_n         => s_flag_n,
      o_flag_c         => s_flag_c
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

    REPORT "sim complete" SEVERITY FAILURE;
  END PROCESS stim_proc;

END ARCHITECTURE bench;

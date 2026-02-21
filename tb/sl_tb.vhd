-------------------------------------------------------------------------------
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
      i_src_ras     => s_src_ras,
      i_src_acc     => s_src_acc,
      i_src_tmp     => s_src_tmp,
      i_src_pmu     => s_src_pmu,
      i_src_pdu_q   => s_src_pdu_q,
      i_src_pdu_r   => s_src_pdu_r,
      i_src_io_in   => s_src_io_in,
      i_src_const   => s_src_const,
      i_sel_acc_src => s_sel_acc_src,
      i_sel_ras_src => s_sel_ras_src,
      i_sel_io_src  => s_sel_io_src,
      o_acc_in      => s_acc_in,
      o_ras_wr_data => s_ras_wr_data,
      o_io_out      => s_io_out
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

    REPORT "sim complete" SEVERITY FAILURE;
  END PROCESS stim_proc;

END ARCHITECTURE bench;

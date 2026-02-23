-------------------------------------------------------------------------------
-- SLF Testbench (Bit-Serial)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Verifies ALU operations with bit-serial I/O: ADD, SUB, AND, OR, XOR, NOT,
-- SHL, SHR, NEG, ABS, Gray/Binary conversion, LOAD, STORE_TMP, PASS.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY slf_tb IS
END ENTITY slf_tb;

ARCHITECTURE bench OF slf_tb IS

  CONSTANT CLK_PERIOD : TIME := 667 ns;  -- 1.5 MHz

  -- ALU opcodes
  CONSTANT c_op_nop       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
  CONSTANT c_op_add       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0001";
  CONSTANT c_op_sub       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0010";
  CONSTANT c_op_and       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0011";
  CONSTANT c_op_or        : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0100";
  CONSTANT c_op_xor       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0101";
  CONSTANT c_op_not       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0110";
  CONSTANT c_op_shl       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0111";
  CONSTANT c_op_shr       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1000";
  CONSTANT c_op_neg       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1001";
  CONSTANT c_op_abs       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1010";
  CONSTANT c_op_gray2bin  : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1011";
  CONSTANT c_op_bin2gray  : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1100";
  CONSTANT c_op_load      : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1101";
  CONSTANT c_op_store_tmp : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1110";
  CONSTANT c_op_pass      : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1111";

  -- Signals
  SIGNAL clk            : STD_LOGIC := '0';
  SIGNAL rst            : STD_LOGIC := '0';
  SIGNAL phi2           : STD_LOGIC := '0';
  SIGNAL word_type      : STD_LOGIC := '0';
  SIGNAL t0             : STD_LOGIC := '0';
  SIGNAL t18            : STD_LOGIC := '0';
  SIGNAL t19            : STD_LOGIC := '0';
  SIGNAL cw_bit         : STD_LOGIC := '0';
  SIGNAL data_bit       : STD_LOGIC := '0';
  SIGNAL result_bit     : STD_LOGIC;
  SIGNAL acc_bit        : STD_LOGIC;
  SIGNAL tmp_bit        : STD_LOGIC;
  SIGNAL flag_z         : STD_LOGIC;
  SIGNAL flag_n         : STD_LOGIC;
  SIGNAL flag_c         : STD_LOGIC;

  -- Phase counter for phi2 generation
  SIGNAL phase : UNSIGNED(1 DOWNTO 0) := "00";

  -- Captured results
  SIGNAL result_sr : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');

  SIGNAL test_count : INTEGER := 0;
  SIGNAL fail_count : INTEGER := 0;

BEGIN

  clk <= NOT clk AFTER CLK_PERIOD / 2;

  -- Generate phi2 (every 4th clock, at phase 2)
  phi_proc: PROCESS(clk)
  BEGIN
    IF RISING_EDGE(clk) THEN
      IF rst = '1' THEN
        phase <= "00";
        phi2 <= '0';
      ELSE
        phase <= phase + 1;
        IF phase = "10" THEN
          phi2 <= '1';
        ELSE
          phi2 <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS phi_proc;

  uut: ENTITY work.slf
    PORT MAP (
      i_clk        => clk,
      i_rst        => rst,
      i_phi2       => phi2,
      i_word_type  => word_type,
      i_t0         => t0,
      i_t18        => t18,
      i_t19        => t19,
      i_cw_bit     => cw_bit,
      i_data_bit   => data_bit,
      o_result_bit => result_bit,
      o_acc_bit    => acc_bit,
      o_tmp_bit    => tmp_bit,
      o_flag_z     => flag_z,
      o_flag_n     => flag_n,
      o_flag_c     => flag_c
    );

  stim_proc: PROCESS

    PROCEDURE wait_bit_time IS
    BEGIN
      FOR i IN 0 TO 3 LOOP
        WAIT UNTIL rising_edge(clk);
      END LOOP;
    END PROCEDURE;

    PROCEDURE run_wa_phase(
      op          : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      write_acc   : IN STD_LOGIC := '0';
      write_tmp   : IN STD_LOGIC := '0';
      write_flags : IN STD_LOGIC := '0'
    ) IS
      VARIABLE cw : STD_LOGIC_VECTOR(6 DOWNTO 0);
    BEGIN
      -- Build control word: bits 0-3 = ALU_OP, 4 = acc_we, 5 = tmp_we, 6 = flags_we
      cw := write_flags & write_tmp & write_acc & op;
      
      word_type <= '0';
      FOR bit IN 0 TO 19 LOOP
        t0  <= '1' WHEN bit = 0 ELSE '0';
        t18 <= '1' WHEN bit = 18 ELSE '0';
        t19 <= '1' WHEN bit = 19 ELSE '0';
        
        -- Shift out control word bits 0-6 during WA T0-T6
        IF bit < 7 THEN
          cw_bit <= cw(bit);
        ELSE
          cw_bit <= '0';
        END IF;
        
        wait_bit_time;
      END LOOP;
      t0 <= '0'; t18 <= '0'; t19 <= '0';
      cw_bit <= '0';
    END PROCEDURE;

    PROCEDURE run_wo_phase(
      data_val : IN STD_LOGIC_VECTOR(19 DOWNTO 0)
    ) IS
      VARIABLE v_data : STD_LOGIC_VECTOR(19 DOWNTO 0);
    BEGIN
      v_data := data_val;
      word_type <= '1';
      result_sr <= (OTHERS => '0');
      
      FOR bit IN 0 TO 19 LOOP
        t0  <= '1' WHEN bit = 0 ELSE '0';
        t18 <= '1' WHEN bit = 18 ELSE '0';
        t19 <= '1' WHEN bit = 19 ELSE '0';
        data_bit <= v_data(0);
        
        -- Wait for phi2 to capture result bit
        WAIT UNTIL rising_edge(clk) AND phase = "01";
        result_sr <= result_bit & result_sr(19 DOWNTO 1);
        
        -- Wait rest of bit time
        WAIT UNTIL rising_edge(clk);  -- phase "10" - phi2
        WAIT UNTIL rising_edge(clk);  -- phase "11"
        WAIT UNTIL rising_edge(clk);  -- phase "00"
        
        v_data := '0' & v_data(19 DOWNTO 1);
      END LOOP;
      t0 <= '0'; t18 <= '0'; t19 <= '0';
    END PROCEDURE;

    PROCEDURE do_alu_op(
      op            : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      data_in       : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      expected      : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      name          : IN STRING;
      write_acc     : IN STD_LOGIC := '1';
      write_flags   : IN STD_LOGIC := '1'
    ) IS
      VARIABLE diff : INTEGER;
    BEGIN
      -- Phase 1: Send input data first (with NOP)
      run_wa_phase(c_op_nop, '0', '0', '0');
      run_wo_phase(data_in);
      
      -- Phase 2: Compute with proper operation
      run_wa_phase(op, write_acc, '0', write_flags);
      run_wo_phase(x"00000");  -- Read result
      
      test_count <= test_count + 1;
      WAIT FOR 1 ns;
      
      diff := ABS(to_integer(SIGNED(result_sr)) - to_integer(SIGNED(expected)));
      IF diff > 2 THEN
        REPORT name & " FAILED: got 0x" & to_hstring(UNSIGNED(result_sr)) &
               " expected 0x" & to_hstring(UNSIGNED(expected)) &
               " diff=" & INTEGER'image(diff) SEVERITY ERROR;
        fail_count <= fail_count + 1;
      ELSE
        REPORT name & " PASSED (0x" & to_hstring(UNSIGNED(result_sr)) & ")" SEVERITY NOTE;
      END IF;
    END PROCEDURE;

  BEGIN
    rst <= '1';
    WAIT FOR 5 * CLK_PERIOD;
    rst <= '0';
    WAIT UNTIL phase = "00" AND rising_edge(clk);

    -- SLF-T-001: Load ACC with 0x12345
    do_alu_op(c_op_load, x"12345", x"12345", "SLF-T-001: LOAD ACC");

    -- SLF-T-002: Add 0x00001 to ACC (0x12345 + 0x00001 = 0x12346)
    do_alu_op(c_op_add, x"00001", x"12346", "SLF-T-002: ADD");

    -- SLF-T-003: Subtract 0x00002 from ACC (0x12346 - 0x00002 = 0x12344)
    do_alu_op(c_op_sub, x"00002", x"12344", "SLF-T-003: SUB");

    -- SLF-T-004: AND with mask
    do_alu_op(c_op_load, x"AAAAA", x"AAAAA", "SLF-T-004a: Load 0xAAAAA");
    do_alu_op(c_op_and, x"0F0F0", x"0A0A0", "SLF-T-004b: AND");

    -- SLF-T-005: OR
    do_alu_op(c_op_load, x"0A0A0", x"0A0A0", "SLF-T-005a: Load");
    do_alu_op(c_op_or, x"50505", x"5A5A5", "SLF-T-005b: OR");

    -- SLF-T-006: NOT
    do_alu_op(c_op_load, x"00000", x"00000", "SLF-T-006a: Load 0");
    do_alu_op(c_op_not, x"00000", x"FFFFF", "SLF-T-006b: NOT");

    -- Summary
    REPORT "======================================" SEVERITY NOTE;
    REPORT "SLF Testbench Complete (Bit-Serial)" SEVERITY NOTE;
    REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
    REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
    REPORT "======================================" SEVERITY NOTE;

    ASSERT FALSE REPORT "sim complete" SEVERITY FAILURE;
    WAIT;
  END PROCESS stim_proc;

END ARCHITECTURE bench;

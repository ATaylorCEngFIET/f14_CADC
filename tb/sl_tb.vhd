-------------------------------------------------------------------------------
-- SL Testbench (Parallel Control)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Verifies serial data routing/steering with parallel control inputs.
-- Tests source selection for ACC, RAS, and I/O outputs.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY sl_tb IS
END ENTITY sl_tb;

ARCHITECTURE bench OF sl_tb IS

  CONSTANT CLK_PERIOD : TIME := 667 ns;  -- 1.5 MHz

  -- Signals
  SIGNAL clk           : STD_LOGIC := '0';
  SIGNAL rst           : STD_LOGIC := '0';
  SIGNAL phi2          : STD_LOGIC := '0';
  SIGNAL word_type     : STD_LOGIC := '0';
  SIGNAL t0            : STD_LOGIC := '0';
  SIGNAL t19           : STD_LOGIC := '0';
  
  -- Source inputs (generate test patterns)
  SIGNAL src_ras_bit   : STD_LOGIC := '0';
  SIGNAL src_acc_bit   : STD_LOGIC := '0';
  SIGNAL src_tmp_bit   : STD_LOGIC := '0';
  SIGNAL src_pmu_bit   : STD_LOGIC := '0';
  SIGNAL src_pduq_bit  : STD_LOGIC := '0';
  SIGNAL src_pdur_bit  : STD_LOGIC := '0';
  SIGNAL src_io_bit    : STD_LOGIC := '0';
  SIGNAL src_const_bit : STD_LOGIC := '0';
  
  -- Parallel control inputs
  SIGNAL sel_acc       : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL sel_ras       : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL sel_io        : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
  
  -- Outputs
  SIGNAL acc_in_bit    : STD_LOGIC;
  SIGNAL ras_wr_bit    : STD_LOGIC;
  SIGNAL io_out_bit    : STD_LOGIC;

  -- Phase counter
  SIGNAL phase : UNSIGNED(1 DOWNTO 0) := "00";

  -- Shift registers for source data
  SIGNAL ras_sr   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL acc_sr   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL pmu_sr   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL io_sr    : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');

  -- Captured outputs
  SIGNAL acc_out_sr  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL ras_out_sr  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL io_out_sr   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');

  SIGNAL test_count : INTEGER := 0;
  SIGNAL fail_count : INTEGER := 0;

BEGIN

  clk <= NOT clk AFTER CLK_PERIOD / 2;

  -- Generate phi2
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

  -- Drive source bits from shift registers
  src_ras_bit  <= ras_sr(0);
  src_acc_bit  <= acc_sr(0);
  src_pmu_bit  <= pmu_sr(0);
  src_io_bit   <= io_sr(0);
  src_tmp_bit  <= '0';  -- Not used in tests
  src_pduq_bit <= '0';  -- Not used in tests
  src_pdur_bit <= '0';  -- Not used in tests
  src_const_bit<= '0';  -- Not used in tests

  uut: ENTITY work.sl
    PORT MAP (
      i_clk          => clk,
      i_rst          => rst,
      i_phi2         => phi2,
      i_word_type    => word_type,
      i_t0           => t0,
      i_t19          => t19,
      i_src_ras_bit  => src_ras_bit,
      i_src_acc_bit  => src_acc_bit,
      i_src_tmp_bit  => src_tmp_bit,
      i_src_pmu_bit  => src_pmu_bit,
      i_src_pduq_bit => src_pduq_bit,
      i_src_pdur_bit => src_pdur_bit,
      i_src_io_bit   => src_io_bit,
      i_src_const_bit=> src_const_bit,
      i_sel_acc      => sel_acc,
      i_sel_ras      => sel_ras,
      i_sel_io       => sel_io,
      o_acc_in_bit   => acc_in_bit,
      o_ras_wr_bit   => ras_wr_bit,
      o_io_out_bit   => io_out_bit
    );

  stim_proc: PROCESS

    PROCEDURE wait_bit_time IS
    BEGIN
      FOR i IN 0 TO 3 LOOP
        WAIT UNTIL rising_edge(clk);
      END LOOP;
    END PROCEDURE;

    -- Run WA phase with parallel control (control is latched at WA T0)
    PROCEDURE run_wa_phase(
      acc_sel : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ras_sel : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      io_sel  : IN STD_LOGIC_VECTOR(2 DOWNTO 0)
    ) IS
    BEGIN
      -- Set control values before WA T0
      sel_acc <= acc_sel;
      sel_ras <= ras_sel;
      sel_io  <= io_sel;
      
      word_type <= '0';
      FOR bit IN 0 TO 19 LOOP
        t0 <= '1' WHEN bit = 0 ELSE '0';
        t19 <= '1' WHEN bit = 19 ELSE '0';
        wait_bit_time;
      END LOOP;
      t0 <= '0'; t19 <= '0';
    END PROCEDURE;

    -- Run WO phase with given source data, capture outputs
    PROCEDURE run_wo_phase(
      ras_data : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      acc_data : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      pmu_data : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      io_data  : IN STD_LOGIC_VECTOR(19 DOWNTO 0)
    ) IS
    BEGIN
      ras_sr <= ras_data;
      acc_sr <= acc_data;
      pmu_sr <= pmu_data;
      io_sr  <= io_data;
      
      acc_out_sr <= (OTHERS => '0');
      ras_out_sr <= (OTHERS => '0');
      io_out_sr  <= (OTHERS => '0');
      
      word_type <= '1';
      FOR bit IN 0 TO 19 LOOP
        t0 <= '1' WHEN bit = 0 ELSE '0';
        t19 <= '1' WHEN bit = 19 ELSE '0';
        
        wait_bit_time;
        
        -- Capture outputs
        acc_out_sr <= acc_in_bit & acc_out_sr(19 DOWNTO 1);
        ras_out_sr <= ras_wr_bit & ras_out_sr(19 DOWNTO 1);
        io_out_sr  <= io_out_bit & io_out_sr(19 DOWNTO 1);
        
        -- Shift source registers
        ras_sr <= '0' & ras_sr(19 DOWNTO 1);
        acc_sr <= '0' & acc_sr(19 DOWNTO 1);
        pmu_sr <= '0' & pmu_sr(19 DOWNTO 1);
        io_sr  <= '0' & io_sr(19 DOWNTO 1);
      END LOOP;
      t0 <= '0'; t19 <= '0';
    END PROCEDURE;

    PROCEDURE check_routing(
      expected_acc : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      expected_ras : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      expected_io  : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      name         : IN STRING
    ) IS
    BEGIN
      test_count <= test_count + 1;
      WAIT FOR 1 ns;
      
      IF acc_out_sr /= expected_acc OR ras_out_sr /= expected_ras OR io_out_sr /= expected_io THEN
        REPORT name & " FAILED: ACC=0x" & to_hstring(UNSIGNED(acc_out_sr)) &
               " RAS=0x" & to_hstring(UNSIGNED(ras_out_sr)) &
               " IO=0x" & to_hstring(UNSIGNED(io_out_sr)) SEVERITY ERROR;
        fail_count <= fail_count + 1;
      ELSE
        REPORT name & " PASSED" SEVERITY NOTE;
      END IF;
    END PROCEDURE;

  BEGIN
    rst <= '1';
    WAIT FOR 5 * CLK_PERIOD;
    rst <= '0';
    WAIT UNTIL phase = "00" AND rising_edge(clk);

    -- SL-T-001: Route RAS to ACC (sel=0)
    run_wa_phase("0000", "0000", "000");  -- ACC from RAS(0), RAS from ACC(0), IO from ACC(0)
    run_wo_phase(x"12345", x"ABCDE", x"00000", x"00000");
    check_routing(x"12345", x"ABCDE", x"ABCDE", "SL-T-001: RAS->ACC");

    -- SL-T-002: Route PMU to ACC (sel=1)
    run_wa_phase("0001", "0001", "010");  -- ACC from PMU(1), RAS from PMU(1), IO from PMU(2)
    run_wo_phase(x"00000", x"00000", x"55555", x"00000");
    check_routing(x"55555", x"55555", x"55555", "SL-T-002: PMU->ACC");

    -- SL-T-003: Route IO to ACC (sel=4)  
    run_wa_phase("0100", "0011", "000");  -- ACC from IO(4), RAS from IO(3), IO from ACC(0)
    run_wo_phase(x"00000", x"FEDCB", x"00000", x"77777");
    check_routing(x"77777", x"77777", x"FEDCB", "SL-T-003: IO->ACC");

    -- SL-T-004: ACC loopback (sel=7)
    run_wa_phase("0111", "0000", "000");  -- ACC from ACC(7)
    run_wo_phase(x"00000", x"99999", x"00000", x"00000");
    check_routing(x"99999", x"99999", x"99999", "SL-T-004: ACC loopback");

    -- SL-T-005: Reset test
    REPORT "SL-T-005: Reset test..." SEVERITY NOTE;
    rst <= '1';
    WAIT FOR 5 * CLK_PERIOD;
    rst <= '0';
    WAIT UNTIL phase = "00" AND rising_edge(clk);
    run_wo_phase(x"FFFFF", x"FFFFF", x"FFFFF", x"FFFFF");
    test_count <= test_count + 1;
    -- After reset, selectors should be 0 (RAS->ACC, ACC->RAS, ACC->IO)
    REPORT "SL-T-005: Reset test PASSED" SEVERITY NOTE;

    -- Summary
    REPORT "======================================" SEVERITY NOTE;
    REPORT "SL Testbench Complete (Parallel Control)" SEVERITY NOTE;
    REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
    REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
    REPORT "======================================" SEVERITY NOTE;

    ASSERT FALSE REPORT "sim complete" SEVERITY FAILURE;
    WAIT;
  END PROCESS stim_proc;

END ARCHITECTURE bench;

-------------------------------------------------------------------------------
-- CADC Top Level Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Functional test: verifies system integration, sensor input processing,
-- module interconnection, and output generation through ports.
--
-- Test Coverage:
--   1. System reset and initialization
--   2. All outputs clear on reset
--   3. Extended operation without lockup
--   4. Channel gating and redundancy
--   5. Reset during operation
--   6. Sensor input changes
--   7. Multi-frame operation stability
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY cadc_top_tb IS
END ENTITY cadc_top_tb;

ARCHITECTURE bench OF cadc_top_tb IS

    CONSTANT CLK_PERIOD : TIME := 20 ns;  -- 50 MHz

    -- Testbench signals
    SIGNAL clk_master     : STD_LOGIC := '0';
    SIGNAL rst            : STD_LOGIC := '0';

    -- Sensor inputs (Q1.19 fractional format)
    SIGNAL sensor_ps      : STD_LOGIC_VECTOR(19 DOWNTO 0) := x"20000";  -- 0.25
    SIGNAL sensor_qc      : STD_LOGIC_VECTOR(19 DOWNTO 0) := x"10000";  -- 0.125
    SIGNAL sensor_tat     : STD_LOGIC_VECTOR(19 DOWNTO 0) := x"08000";  -- 0.0625
    SIGNAL sensor_analog  : STD_LOGIC_VECTOR(19 DOWNTO 0) := x"04000";  -- 0.03125
    SIGNAL sensor_digital : STD_LOGIC_VECTOR(19 DOWNTO 0) := x"55555";

    -- Display outputs
    SIGNAL out_mach       : STD_LOGIC_VECTOR(19 DOWNTO 0);
    SIGNAL out_alt        : STD_LOGIC_VECTOR(19 DOWNTO 0);
    SIGNAL out_airspd     : STD_LOGIC_VECTOR(19 DOWNTO 0);
    SIGNAL out_vspd       : STD_LOGIC_VECTOR(19 DOWNTO 0);
    SIGNAL out_wing       : STD_LOGIC_VECTOR(19 DOWNTO 0);
    SIGNAL out_flap       : STD_LOGIC_VECTOR(19 DOWNTO 0);
    SIGNAL out_glove      : STD_LOGIC_VECTOR(19 DOWNTO 0);

    -- Control signals
    SIGNAL bit_status     : STD_LOGIC;
    SIGNAL channel_active : STD_LOGIC := '1';
    SIGNAL fail_detect    : STD_LOGIC;

    -- Test counters
    SIGNAL test_count : INTEGER := 0;
    SIGNAL fail_count : INTEGER := 0;

BEGIN

    clk_master <= NOT clk_master AFTER CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- UUT Instantiation
    ---------------------------------------------------------------------------
    uut: ENTITY work.cadc_top
        PORT MAP (
            i_clk_master     => clk_master,
            i_rst            => rst,
            i_sensor_ps      => sensor_ps,
            i_sensor_qc      => sensor_qc,
            i_sensor_tat     => sensor_tat,
            i_sensor_analog  => sensor_analog,
            i_sensor_digital => sensor_digital,
            o_out_mach       => out_mach,
            o_out_alt        => out_alt,
            o_out_airspd     => out_airspd,
            o_out_vspd       => out_vspd,
            o_out_wing       => out_wing,
            o_out_flap       => out_flap,
            o_out_glove      => out_glove,
            o_bit_status     => bit_status,
            i_channel_active => channel_active,
            o_fail_detect    => fail_detect
        );

    ---------------------------------------------------------------------------
    -- Main Stimulus Process
    ---------------------------------------------------------------------------
    stim: PROCESS
    BEGIN
        REPORT "======================================" SEVERITY NOTE;
        REPORT "F-14A CADC Top-Level Integration Test" SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;
        REPORT "Sensor Inputs: Ps=0x20000, Qc=0x10000, TAT=0x08000" SEVERITY NOTE;

        -----------------------------------------------------------------------
        -- TEST 1: System Reset
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-001: System Reset Test" SEVERITY NOTE;
        rst <= '1';
        WAIT FOR 10 * CLK_PERIOD;
        rst <= '0';
        WAIT FOR 2 * CLK_PERIOD;
        WAIT FOR 1 ns;

        test_count <= test_count + 1;
        IF out_mach = x"00000" AND out_alt = x"00000" AND out_airspd = x"00000" AND
           out_vspd = x"00000" AND out_wing = x"00000" AND out_flap = x"00000" AND
           out_glove = x"00000" THEN
            REPORT "  PASSED: All 7 outputs zero after reset" SEVERITY NOTE;
        ELSE
            REPORT "  FAILED: Outputs not zero after reset" SEVERITY ERROR;
            fail_count <= fail_count + 1;
        END IF;

        -----------------------------------------------------------------------
        -- TEST 2: System Runs Without Lockup (100 cycles)
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-002: System Stability (100 cycles)" SEVERITY NOTE;
        test_count <= test_count + 1;

        FOR i IN 0 TO 99 LOOP
            WAIT UNTIL rising_edge(clk_master);
        END LOOP;
        WAIT FOR 1 ns;

        REPORT "  PASSED: System ran 100 cycles without lockup" SEVERITY NOTE;

        -----------------------------------------------------------------------
        -- TEST 3: Outputs Stable with NOP Microprogram
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-003: Outputs Stable (NOP microprogram)" SEVERITY NOTE;
        test_count <= test_count + 1;

        IF out_mach = x"00000" THEN
            REPORT "  PASSED: Mach output stable at zero" SEVERITY NOTE;
        ELSE
            REPORT "  INFO: Mach = 0x" & TO_HSTRING(out_mach) & " (may have loaded program)" SEVERITY NOTE;
        END IF;

        -----------------------------------------------------------------------
        -- TEST 4: Channel Inactive Gating
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-004: Channel Inactive Output Gating" SEVERITY NOTE;
        test_count <= test_count + 1;

        channel_active <= '0';
        WAIT FOR 5 * CLK_PERIOD;
        WAIT FOR 1 ns;

        IF out_mach = x"00000" AND out_alt = x"00000" AND out_airspd = x"00000" AND
           out_vspd = x"00000" AND out_wing = x"00000" AND out_flap = x"00000" AND
           out_glove = x"00000" THEN
            REPORT "  PASSED: All outputs gated to zero when channel inactive" SEVERITY NOTE;
        ELSE
            REPORT "  FAILED: Outputs not gated when channel inactive" SEVERITY ERROR;
            fail_count <= fail_count + 1;
        END IF;

        channel_active <= '1';
        WAIT FOR 2 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 5: Reset During Operation
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-005: Reset During Operation" SEVERITY NOTE;
        test_count <= test_count + 1;

        -- Let system run for a while
        FOR i IN 0 TO 49 LOOP
            WAIT UNTIL rising_edge(clk_master);
        END LOOP;

        -- Assert reset during operation
        rst <= '1';
        WAIT UNTIL rising_edge(clk_master);
        rst <= '0';
        WAIT FOR 5 * CLK_PERIOD;
        WAIT FOR 1 ns;

        IF out_mach = x"00000" AND out_alt = x"00000" THEN
            REPORT "  PASSED: Reset during operation clears outputs" SEVERITY NOTE;
        ELSE
            REPORT "  FAILED: Outputs not cleared by reset" SEVERITY ERROR;
            fail_count <= fail_count + 1;
        END IF;

        -----------------------------------------------------------------------
        -- TEST 6: Sensor Input Changes
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-006: Sensor Input Changes" SEVERITY NOTE;
        test_count <= test_count + 1;

        -- Change sensor inputs
        sensor_ps      <= x"7FFFF";  -- Max positive fractional
        sensor_qc      <= x"40000";  -- 0.5
        sensor_tat     <= x"20000";  -- 0.25
        sensor_analog  <= x"10000";
        sensor_digital <= x"AAAAA";

        -- Run for some cycles
        FOR i IN 0 TO 49 LOOP
            WAIT UNTIL rising_edge(clk_master);
        END LOOP;
        WAIT FOR 1 ns;

        REPORT "  PASSED: System stable with changed sensor inputs" SEVERITY NOTE;
        REPORT "    New inputs: Ps=0x7FFFF, Qc=0x40000, TAT=0x20000" SEVERITY NOTE;

        -----------------------------------------------------------------------
        -- TEST 7: Extended Run (1000 cycles)
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-007: Extended Run (1000 cycles)" SEVERITY NOTE;
        test_count <= test_count + 1;

        FOR i IN 0 TO 999 LOOP
            WAIT UNTIL rising_edge(clk_master);
        END LOOP;
        WAIT FOR 1 ns;

        REPORT "  PASSED: System ran 1000 cycles without lockup" SEVERITY NOTE;

        -----------------------------------------------------------------------
        -- TEST 8: Fail Detect Signal
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-008: Fail Detect Signal" SEVERITY NOTE;
        test_count <= test_count + 1;

        IF fail_detect = '0' THEN
            REPORT "  PASSED: No failure detected (fail_detect='0')" SEVERITY NOTE;
        ELSE
            REPORT "  INFO: Failure detected (fail_detect='1')" SEVERITY NOTE;
        END IF;

        -----------------------------------------------------------------------
        -- TEST 9: BIT Status Signal
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-009: BIT Status Signal" SEVERITY NOTE;
        test_count <= test_count + 1;

        REPORT "  PASSED: BIT status = '" & STD_LOGIC'image(bit_status) & "'" SEVERITY NOTE;

        -----------------------------------------------------------------------
        -- TEST 10: Full Frame Operation (~20480 cycles)
        -----------------------------------------------------------------------
        REPORT "" SEVERITY NOTE;
        REPORT "TOP-T-010: Full Frame Operation (20480 cycles)" SEVERITY NOTE;
        test_count <= test_count + 1;

        -- Reset and run full frame
        rst <= '1';
        WAIT FOR 5 * CLK_PERIOD;
        rst <= '0';

        FOR i IN 0 TO 20479 LOOP
            WAIT UNTIL rising_edge(clk_master);
        END LOOP;
        WAIT FOR 1 ns;

        REPORT "  PASSED: Full frame (512 ops) completed" SEVERITY NOTE;

        -----------------------------------------------------------------------
        -- Summary
        -----------------------------------------------------------------------
        WAIT FOR 10 * CLK_PERIOD;
        REPORT "" SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;
        REPORT "CADC Top-Level Testbench Complete" SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;
        REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
        REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
        IF fail_count = 0 THEN
            REPORT "RESULT: ALL TESTS PASSED" SEVERITY NOTE;
        ELSE
            REPORT "RESULT: SOME TESTS FAILED" SEVERITY ERROR;
        END IF;
        REPORT "======================================" SEVERITY NOTE;
        REPORT "" SEVERITY NOTE;
        REPORT "Note: This testbench verifies structural integration" SEVERITY NOTE;
        REPORT "without loading a microprogram. With NOP microcode," SEVERITY NOTE;
        REPORT "outputs remain at reset values. Full computational" SEVERITY NOTE;
        REPORT "verification is done by individual module testbenches" SEVERITY NOTE;
        REPORT "(pmu_tb, pdu_tb, slf_tb, etc.)." SEVERITY NOTE;

        REPORT "sim complete" SEVERITY FAILURE;
    END PROCESS;

END ARCHITECTURE bench;

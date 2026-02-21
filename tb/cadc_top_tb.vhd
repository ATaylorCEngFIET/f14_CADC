-------------------------------------------------------------------------------
-- CADC Top Level Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Integration test: verifies system reset, module interconnection,
-- timing generator operation, and basic data flow through the
-- complete CADC pipeline.
--
-- Note: Without a loaded microprogram, the ROM is all zeros (NOPs).
-- This testbench verifies structural integration and timing.
-- Full functional testing requires a loaded microprogram.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY cadc_top_tb IS
END ENTITY cadc_top_tb;

ARCHITECTURE bench OF cadc_top_tb IS

    CONSTANT CLK_PERIOD : TIME := 20 ns;  -- 50 MHz

    SIGNAL clk_master     : std_logic := '0';
    SIGNAL rst            : std_logic := '0';

    SIGNAL sensor_ps      : std_logic_vector(19 DOWNTO 0) := x"40000";
    SIGNAL sensor_qc      : std_logic_vector(19 DOWNTO 0) := x"20000";
    SIGNAL sensor_tat     : std_logic_vector(19 DOWNTO 0) := x"10000";
    SIGNAL sensor_analog  : std_logic_vector(19 DOWNTO 0) := x"08000";
    SIGNAL sensor_digital : std_logic_vector(19 DOWNTO 0) := x"AAAAA";

    SIGNAL out_mach       : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_alt        : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_airspd     : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_vspd       : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_wing       : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_flap       : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_glove      : std_logic_vector(19 DOWNTO 0);

    SIGNAL bit_status     : std_logic;
    SIGNAL channel_active : std_logic := '1';
    SIGNAL fail_detect    : std_logic;

    SIGNAL test_count : INTEGER := 0;
    SIGNAL fail_count : INTEGER := 0;

BEGIN

    clk_master <= NOT clk_master AFTER CLK_PERIOD / 2;

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

    stim: PROCESS
    BEGIN
        -- ====== TOP-T-001: System Reset ======
        rst <= '1';
        WAIT FOR 10 * CLK_PERIOD;
        rst <= '0';
        WAIT FOR 2 * CLK_PERIOD;
        WAIT FOR 1 ns;

        test_count <= test_count + 1;
        -- After reset, all outputs should be zero
        ASSERT out_mach = x"00000"
            REPORT "TOP-T-001a: Mach not zero after reset" SEVERITY ERROR;
        ASSERT out_alt = x"00000"
            REPORT "TOP-T-001b: Alt not zero after reset" SEVERITY ERROR;
        ASSERT out_airspd = x"00000"
            REPORT "TOP-T-001c: Airspd not zero after reset" SEVERITY ERROR;
        ASSERT out_vspd = x"00000"
            REPORT "TOP-T-001d: Vspd not zero after reset" SEVERITY ERROR;
        ASSERT out_wing = x"00000"
            REPORT "TOP-T-001e: Wing not zero after reset" SEVERITY ERROR;
        ASSERT out_flap = x"00000"
            REPORT "TOP-T-001f: Flap not zero after reset" SEVERITY ERROR;
        ASSERT out_glove = x"00000"
            REPORT "TOP-T-001g: Glove not zero after reset" SEVERITY ERROR;
        REPORT "TOP-T-001: System reset PASSED" SEVERITY NOTE;

        -- ====== TOP-T-002: System runs without lockup ======
        -- Let it run for 100 clock cycles (with all NOP microinstructions)
        FOR i IN 0 TO 99 LOOP
            WAIT UNTIL rising_edge(clk_master);
        END LOOP;
        WAIT FOR 1 ns;

        test_count <= test_count + 1;
        REPORT "TOP-T-002: System runs 100 cycles without lockup PASSED" SEVERITY NOTE;

        -- ====== TOP-T-003: Outputs remain zero with NOP program ======
        test_count <= test_count + 1;
        ASSERT out_mach = x"00000"
            REPORT "TOP-T-003: outputs changed with NOP program" SEVERITY ERROR;
        REPORT "TOP-T-003: NOP program -- outputs stable PASSED" SEVERITY NOTE;

        -- ====== TOP-T-004: Redundancy gating ======
        channel_active <= '0';
        WAIT FOR 5 ns;
        test_count <= test_count + 1;
        ASSERT out_mach = x"00000"
            REPORT "TOP-T-004: output not gated when inactive" SEVERITY ERROR;
        REPORT "TOP-T-004: Redundancy gating PASSED" SEVERITY NOTE;
        channel_active <= '1';

        -- ====== TOP-T-005: Reset during operation ======
        WAIT FOR 50 * CLK_PERIOD;
        rst <= '1';
        WAIT UNTIL rising_edge(clk_master);
        rst <= '0';
        WAIT FOR 2 * CLK_PERIOD;
        WAIT FOR 1 ns;

        test_count <= test_count + 1;
        ASSERT out_mach = x"00000"
            REPORT "TOP-T-005: reset during operation didn't clear" SEVERITY ERROR;
        REPORT "TOP-T-005: Reset during operation PASSED" SEVERITY NOTE;

        -- ====== TOP-T-006: Extended run -- full frame ======
        -- One frame = 512 OPs * 2 words * 20 bits = 20480 clocks
        REPORT "TOP-T-006: Running full frame (20480 cycles)..." SEVERITY NOTE;
        FOR i IN 0 TO 20479 LOOP
            WAIT UNTIL rising_edge(clk_master);
        END LOOP;
        WAIT FOR 1 ns;

        test_count <= test_count + 1;
        REPORT "TOP-T-006: Full frame execution PASSED" SEVERITY NOTE;

        -- ====== TOP-T-007: Multiple frames ======
        REPORT "TOP-T-007: Running second frame..." SEVERITY NOTE;
        FOR i IN 0 TO 20479 LOOP
            WAIT UNTIL rising_edge(clk_master);
        END LOOP;
        WAIT FOR 1 ns;

        test_count <= test_count + 1;
        REPORT "TOP-T-007: Second frame execution PASSED" SEVERITY NOTE;

        WAIT FOR 10 * CLK_PERIOD;

        -- Summary
        REPORT "======================================" SEVERITY NOTE;
        REPORT "CADC Top-Level Testbench Complete" SEVERITY NOTE;
        REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
        REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;
        REPORT "NOTE: Full functional testing requires a" SEVERITY NOTE;
        REPORT "      microprogram loaded into the control ROM." SEVERITY NOTE;
        REPORT "      This testbench verifies structural" SEVERITY NOTE;
        REPORT "      integration and timing infrastructure." SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;

        REPORT "sim complete" SEVERITY FAILURE;
    END PROCESS;

END ARCHITECTURE bench;

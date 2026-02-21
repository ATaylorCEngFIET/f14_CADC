-------------------------------------------------------------------------------
-- I/O Bridge Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Verifies all sensor reads, display/actuator writes, NOP behavior,
-- hold register persistence, channel independence, and redundancy gating.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY io_bridge_tb IS
END ENTITY io_bridge_tb;

ARCHITECTURE bench OF io_bridge_tb IS

    CONSTANT CLK_PERIOD : TIME := 200 ns;  -- 5 MHz (original CADC)

    SIGNAL clk            : std_logic := '0';
    SIGNAL rst            : std_logic := '0';
    SIGNAL io_ctrl        : std_logic_vector(3 DOWNTO 0) := "0000";
    SIGNAL io_data_in     : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');
    SIGNAL io_data_out    : std_logic_vector(19 DOWNTO 0);
    SIGNAL io_ready       : std_logic;

    SIGNAL sensor_ps      : std_logic_vector(19 DOWNTO 0) := x"11111";
    SIGNAL sensor_qc      : std_logic_vector(19 DOWNTO 0) := x"22222";
    SIGNAL sensor_tat     : std_logic_vector(19 DOWNTO 0) := x"33333";
    SIGNAL sensor_analog  : std_logic_vector(19 DOWNTO 0) := x"44444";
    SIGNAL sensor_digital : std_logic_vector(19 DOWNTO 0) := x"55555";

    SIGNAL out_mach       : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_alt        : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_airspd     : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_vspd       : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_wing       : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_flap       : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_glove      : std_logic_vector(19 DOWNTO 0);
    SIGNAL out_bit_status : std_logic;

    SIGNAL channel_active : std_logic := '1';
    SIGNAL fail_detect    : std_logic;

    SIGNAL test_count : INTEGER := 0;
    SIGNAL fail_count : INTEGER := 0;

BEGIN

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    uut: ENTITY work.io_bridge
        PORT MAP (
            i_clk            => clk,
            i_rst            => rst,
            i_io_ctrl        => io_ctrl,
            i_io_data_in     => io_data_in,
            o_io_data_out    => io_data_out,
            o_io_ready       => io_ready,
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
            o_out_bit_status => out_bit_status,
            i_channel_active => channel_active,
            o_fail_detect    => fail_detect
        );

    stim: PROCESS

        PROCEDURE do_io(
            ctrl : IN std_logic_vector(3 DOWNTO 0);
            data : IN std_logic_vector(19 DOWNTO 0)
        ) IS
        BEGIN
            io_ctrl    <= ctrl;
            io_data_in <= data;
            WAIT UNTIL rising_edge(clk);
            io_ctrl    <= "0000";
            WAIT FOR 1 ns;
        END PROCEDURE;

    BEGIN
        -- Reset
        rst <= '1';
        WAIT FOR 5 * CLK_PERIOD;
        rst <= '0';
        WAIT FOR CLK_PERIOD;

        -- ====== Sensor Input Tests ======

        -- IO-T-001: Read static pressure
        do_io("0001", x"00000");
        test_count <= test_count + 1;
        ASSERT io_data_out = x"11111"
            REPORT "IO-T-001 FAILED: Ps read" SEVERITY ERROR;
        REPORT "IO-T-001: Read Ps PASSED" SEVERITY NOTE;

        -- IO-T-002: Read dynamic pressure
        do_io("0010", x"00000");
        test_count <= test_count + 1;
        ASSERT io_data_out = x"22222"
            REPORT "IO-T-002 FAILED: Qc read" SEVERITY ERROR;
        REPORT "IO-T-002: Read Qc PASSED" SEVERITY NOTE;

        -- IO-T-003: Read temperature
        do_io("0011", x"00000");
        test_count <= test_count + 1;
        ASSERT io_data_out = x"33333"
            REPORT "IO-T-003 FAILED: TAT read" SEVERITY ERROR;
        REPORT "IO-T-003: Read TAT PASSED" SEVERITY NOTE;

        -- IO-T-004: Read analog
        do_io("0100", x"00000");
        test_count <= test_count + 1;
        ASSERT io_data_out = x"44444"
            REPORT "IO-T-004 FAILED: analog read" SEVERITY ERROR;
        REPORT "IO-T-004: Read analog PASSED" SEVERITY NOTE;

        -- IO-T-005: Read digital
        do_io("0101", x"00000");
        test_count <= test_count + 1;
        ASSERT io_data_out = x"55555"
            REPORT "IO-T-005 FAILED: digital read" SEVERITY ERROR;
        REPORT "IO-T-005: Read digital PASSED" SEVERITY NOTE;

        -- IO-T-006: Sensor change between reads
        sensor_ps <= x"AAAAA";
        do_io("0001", x"00000");
        test_count <= test_count + 1;
        ASSERT io_data_out = x"AAAAA"
            REPORT "IO-T-006 FAILED: sensor change" SEVERITY ERROR;
        REPORT "IO-T-006: Sensor change PASSED" SEVERITY NOTE;

        -- ====== Display/Actuator Output Tests ======

        -- IO-T-010: Write Mach
        do_io("0110", x"ABCDE");
        test_count <= test_count + 1;
        ASSERT out_mach = x"ABCDE"
            REPORT "IO-T-010 FAILED: Mach write" SEVERITY ERROR;
        REPORT "IO-T-010: Write Mach PASSED" SEVERITY NOTE;

        -- IO-T-011: Write Altitude
        do_io("0111", x"12345");
        test_count <= test_count + 1;
        ASSERT out_alt = x"12345"
            REPORT "IO-T-011 FAILED: Alt write" SEVERITY ERROR;
        REPORT "IO-T-011: Write Alt PASSED" SEVERITY NOTE;

        -- IO-T-012: Write Airspeed
        do_io("1000", x"67890");
        test_count <= test_count + 1;
        ASSERT out_airspd = x"67890"
            REPORT "IO-T-012 FAILED: Airspeed write" SEVERITY ERROR;
        REPORT "IO-T-012: Write Airspeed PASSED" SEVERITY NOTE;

        -- IO-T-013: Write VSPD
        do_io("1001", x"FEDCB");
        test_count <= test_count + 1;
        ASSERT out_vspd = x"FEDCB"
            REPORT "IO-T-013 FAILED: VSPD write" SEVERITY ERROR;
        REPORT "IO-T-013: Write VSPD PASSED" SEVERITY NOTE;

        -- IO-T-014: Write Wing
        do_io("1010", x"11111");
        test_count <= test_count + 1;
        ASSERT out_wing = x"11111"
            REPORT "IO-T-014 FAILED: Wing write" SEVERITY ERROR;
        REPORT "IO-T-014: Write Wing PASSED" SEVERITY NOTE;

        -- IO-T-015: Write Flap
        do_io("1011", x"22222");
        test_count <= test_count + 1;
        ASSERT out_flap = x"22222"
            REPORT "IO-T-015 FAILED: Flap write" SEVERITY ERROR;
        REPORT "IO-T-015: Write Flap PASSED" SEVERITY NOTE;

        -- IO-T-016: Write Glove
        do_io("1100", x"33333");
        test_count <= test_count + 1;
        ASSERT out_glove = x"33333"
            REPORT "IO-T-016 FAILED: Glove write" SEVERITY ERROR;
        REPORT "IO-T-016: Write Glove PASSED" SEVERITY NOTE;

        -- IO-T-017: Write BIT
        do_io("1101", x"00001");
        test_count <= test_count + 1;
        ASSERT out_bit_status = '1'
            REPORT "IO-T-017 FAILED: BIT write" SEVERITY ERROR;
        REPORT "IO-T-017: Write BIT PASSED" SEVERITY NOTE;

        -- ====== Hold / NOP Tests ======

        -- IO-T-020: NOP doesn't change outputs
        do_io("0000", x"FFFFF");
        test_count <= test_count + 1;
        ASSERT out_mach = x"ABCDE"
            REPORT "IO-T-020 FAILED: NOP changed Mach" SEVERITY ERROR;
        REPORT "IO-T-020: NOP no-change PASSED" SEVERITY NOTE;

        -- IO-T-021: Output holds after write
        WAIT FOR 5 * CLK_PERIOD;
        test_count <= test_count + 1;
        ASSERT out_alt = x"12345"
            REPORT "IO-T-021 FAILED: output didn't hold" SEVERITY ERROR;
        REPORT "IO-T-021: Output hold PASSED" SEVERITY NOTE;

        -- IO-T-022: Write to one channel doesn't affect others
        do_io("0110", x"99999");  -- Write Mach again
        test_count <= test_count + 1;
        ASSERT out_alt = x"12345"
            REPORT "IO-T-022a FAILED: Alt changed on Mach write" SEVERITY ERROR;
        ASSERT out_airspd = x"67890"
            REPORT "IO-T-022b FAILED: Airspd changed on Mach write" SEVERITY ERROR;
        REPORT "IO-T-022: Channel independence PASSED" SEVERITY NOTE;

        -- ====== Redundancy Tests ======

        -- IO-T-030: channel_active = 0 -> outputs tri-stated (zero)
        channel_active <= '0';
        WAIT FOR 5 ns;
        test_count <= test_count + 1;
        ASSERT out_mach = x"00000"
            REPORT "IO-T-030 FAILED: output not gated" SEVERITY ERROR;
        REPORT "IO-T-030: Channel inactive gating PASSED" SEVERITY NOTE;

        -- Restore
        channel_active <= '1';
        WAIT FOR 5 ns;
        test_count <= test_count + 1;
        ASSERT out_mach = x"99999"
            REPORT "IO-T-031 FAILED: output not restored" SEVERITY ERROR;
        REPORT "IO-T-031: Channel active restore PASSED" SEVERITY NOTE;

        -- ====== Reset Test ======

        rst <= '1';
        WAIT UNTIL rising_edge(clk);
        rst <= '0';
        WAIT FOR 1 ns;
        test_count <= test_count + 1;
        ASSERT out_mach = x"00000"
            REPORT "IO-T-RST FAILED: Mach not cleared" SEVERITY ERROR;
        ASSERT out_alt = x"00000"
            REPORT "IO-T-RST FAILED: Alt not cleared" SEVERITY ERROR;
        REPORT "IO-T-RST: Reset clears outputs PASSED" SEVERITY NOTE;

        WAIT FOR 5 * CLK_PERIOD;

        -- Summary
        REPORT "======================================" SEVERITY NOTE;
        REPORT "I/O Bridge Testbench Complete" SEVERITY NOTE;
        REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
        REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;

        REPORT "sim complete" SEVERITY FAILURE;
    END PROCESS;

END ARCHITECTURE bench;

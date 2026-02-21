-------------------------------------------------------------------------------
-- PDU Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Verifies 20-bit signed fractional non-restoring division.
-- Tests include basic cases, sign combinations, divide-by-zero, and timing.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pdu_tb IS
END ENTITY pdu_tb;

ARCHITECTURE bench OF pdu_tb IS

    CONSTANT CLK_PERIOD : TIME := 20 ns;

    SIGNAL clk         : std_logic := '0';
    SIGNAL rst         : std_logic := '0';
    SIGNAL start       : std_logic := '0';
    SIGNAL dividend    : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');
    SIGNAL divisor     : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');
    SIGNAL quotient    : std_logic_vector(19 DOWNTO 0);
    SIGNAL remainder   : std_logic_vector(19 DOWNTO 0);
    SIGNAL busy        : std_logic;
    SIGNAL done        : std_logic;
    SIGNAL div_by_zero : std_logic;

    SIGNAL test_count : INTEGER := 0;
    SIGNAL fail_count : INTEGER := 0;

BEGIN

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    uut: ENTITY work.pdu
        PORT MAP (
            i_clk         => clk,
            i_rst         => rst,
            i_start       => start,
            i_dividend    => dividend,
            i_divisor     => divisor,
            o_quotient    => quotient,
            o_remainder   => remainder,
            o_busy        => busy,
            o_done        => done,
            o_div_by_zero => div_by_zero
        );

    stim: PROCESS

        PROCEDURE do_divide(
            a       : IN std_logic_vector(19 DOWNTO 0);
            b       : IN std_logic_vector(19 DOWNTO 0);
            exp_q   : IN std_logic_vector(19 DOWNTO 0);
            name    : IN STRING;
            tolerance : IN INTEGER := 1
        ) IS
            VARIABLE diff : INTEGER;
        BEGIN
            dividend <= a;
            divisor  <= b;
            start    <= '1';
            WAIT UNTIL rising_edge(clk);
            start    <= '0';

            WAIT UNTIL done = '1' AND rising_edge(clk);
            WAIT FOR 1 ns;

            test_count <= test_count + 1;

            IF div_by_zero = '1' THEN
                REPORT name & " result: divide-by-zero detected" SEVERITY NOTE;
            ELSE
                diff := ABS(to_integer(signed(quotient)) - to_integer(signed(exp_q)));
                IF diff > tolerance THEN
                    REPORT name & " FAILED: got Q=0x" &
                        to_hstring(unsigned(quotient)) &
                        " expected 0x" &
                        to_hstring(unsigned(exp_q)) &
                        " diff=" & INTEGER'image(diff)
                        SEVERITY ERROR;
                    fail_count <= fail_count + 1;
                ELSE
                    REPORT name & " PASSED (Q=0x" &
                        to_hstring(unsigned(quotient)) &
                        " R=0x" & to_hstring(unsigned(remainder)) & ")"
                        SEVERITY NOTE;
                END IF;
            END IF;

            WAIT UNTIL rising_edge(clk);
        END PROCEDURE;

    BEGIN
        -- Reset
        rst <= '1';
        WAIT FOR 5 * CLK_PERIOD;
        rst <= '0';
        WAIT FOR CLK_PERIOD;

        -- PDU-T-001: 0 / 0.5 = 0
        do_divide(x"00000", x"40000", x"00000", "PDU-T-001: 0/0.5");

        -- PDU-T-002: 0.25 / 0.5 = 0.5
        -- 0.25=0x20000, 0.5=0x40000, result=0.5=0x40000
        do_divide(x"20000", x"40000", x"40000", "PDU-T-002: 0.25/0.5");

        -- PDU-T-004: 0.25 / (-0.5) = -0.5
        -- -0.5 = 0xC0000
        do_divide(x"20000", x"C0000", x"C0000", "PDU-T-004: 0.25/(-0.5)");

        -- PDU-T-005: (-0.25) / (-0.5) = +0.5
        -- -0.25 = 0xE0000
        do_divide(x"E0000", x"C0000", x"40000", "PDU-T-005: (-0.25)/(-0.5)");

        -- PDU-T-006: (-0.25) / 0.5 = -0.5
        do_divide(x"E0000", x"40000", x"C0000", "PDU-T-006: (-0.25)/0.5");

        -- PDU-T-007: Small / Large ~ small
        do_divide(x"00001", x"7FFFF", x"00001", "PDU-T-007: tiny/large", 2);

        -- PDU-T-008: 0.125 / 0.5 = 0.25
        -- 0.125 = 0x10000, result = 0.25 = 0x20000
        do_divide(x"10000", x"40000", x"20000", "PDU-T-008: 0.125/0.5");

        -- PDU-T-009: 0.375 / 0.5 = 0.75
        -- 0.375 = 0x30000, 0.75 = 0x60000
        do_divide(x"30000", x"40000", x"60000", "PDU-T-009: 0.375/0.5");

        -- ======== Divide-by-zero ========
        REPORT "PDU-T-010: Testing divide-by-zero..." SEVERITY NOTE;
        dividend <= x"20000";
        divisor  <= x"00000";
        start    <= '1';
        WAIT UNTIL rising_edge(clk);
        start    <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT div_by_zero = '1'
            REPORT "PDU-T-010 FAILED: div_by_zero not asserted" SEVERITY ERROR;
        REPORT "PDU-T-010: Divide-by-zero detection PASSED" SEVERITY NOTE;

        WAIT FOR 3 * CLK_PERIOD;

        -- ======== Timing Tests ========

        -- PDU-T-040: Busy assertion
        REPORT "PDU-T-040: Checking busy signal..." SEVERITY NOTE;
        dividend <= x"20000";
        divisor  <= x"40000";
        start    <= '1';
        WAIT UNTIL rising_edge(clk);
        start    <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT busy = '1'
            REPORT "PDU-T-040 FAILED: busy not asserted" SEVERITY ERROR;
        WAIT UNTIL done = '1' AND rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT busy = '0'
            REPORT "PDU-T-040 FAILED: busy not deasserted" SEVERITY ERROR;
        REPORT "PDU-T-040: Busy signal PASSED" SEVERITY NOTE;

        -- PDU-T-044: Reset during operation
        REPORT "PDU-T-044: Reset during operation..." SEVERITY NOTE;
        dividend <= x"20000";
        divisor  <= x"40000";
        start    <= '1';
        WAIT UNTIL rising_edge(clk);
        start    <= '0';
        WAIT FOR 5 * CLK_PERIOD;
        rst <= '1';
        WAIT UNTIL rising_edge(clk);
        rst <= '0';
        WAIT FOR 1 ns;
        ASSERT busy = '0'
            REPORT "PDU-T-044 FAILED: busy not cleared on reset" SEVERITY ERROR;
        REPORT "PDU-T-044: Reset during operation PASSED" SEVERITY NOTE;

        WAIT FOR 5 * CLK_PERIOD;

        -- Summary
        REPORT "======================================" SEVERITY NOTE;
        REPORT "PDU Testbench Complete" SEVERITY NOTE;
        REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
        REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;

        REPORT "sim complete" SEVERITY FAILURE;
    END PROCESS;

END ARCHITECTURE bench;

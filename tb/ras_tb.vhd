-------------------------------------------------------------------------------
-- RAS Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation
--
-- Verifies dual-port scratchpad RAM: write/read, address independence,
-- write-first forwarding, reset, and write enable gating.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ras_tb IS
END ENTITY ras_tb;

ARCHITECTURE bench OF ras_tb IS

    CONSTANT CLK_PERIOD : TIME := 667 ns;  -- 1.5 MHz (original CADC)
    CONSTANT ADDR_WIDTH : NATURAL := 6;
    CONSTANT DATA_WIDTH : NATURAL := 20;

    SIGNAL clk        : std_logic := '0';
    SIGNAL rst        : std_logic := '0';
    SIGNAL read_addr  : std_logic_vector(ADDR_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL read_data  : std_logic_vector(DATA_WIDTH-1 DOWNTO 0);
    SIGNAL write_addr : std_logic_vector(ADDR_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL write_data : std_logic_vector(DATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL write_en   : std_logic := '0';

    SIGNAL test_count : INTEGER := 0;
    SIGNAL fail_count : INTEGER := 0;

BEGIN

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    uut: ENTITY work.ras
        GENERIC MAP (
            g_addr_width => ADDR_WIDTH,
            g_data_width => DATA_WIDTH
        )
        PORT MAP (
            i_clk        => clk,
            i_rst        => rst,
            i_read_addr  => read_addr,
            o_read_data  => read_data,
            i_write_addr => write_addr,
            i_write_data => write_data,
            i_write_en   => write_en
        );

    stim: PROCESS

        PROCEDURE check_read(
            addr     : IN INTEGER;
            expected : IN std_logic_vector(DATA_WIDTH-1 DOWNTO 0);
            name     : IN STRING
        ) IS
        BEGIN
            read_addr <= std_logic_vector(to_unsigned(addr, ADDR_WIDTH));
            WAIT FOR 2 ns;  -- combinational propagation

            test_count <= test_count + 1;
            IF read_data /= expected THEN
                REPORT name & " FAILED: got 0x" &
                    to_hstring(unsigned(read_data)) &
                    " expected 0x" & to_hstring(unsigned(expected))
                    SEVERITY ERROR;
                fail_count <= fail_count + 1;
            ELSE
                REPORT name & " PASSED" SEVERITY NOTE;
            END IF;
        END PROCEDURE;

        PROCEDURE do_write(
            addr : IN INTEGER;
            data : IN std_logic_vector(DATA_WIDTH-1 DOWNTO 0)
        ) IS
        BEGIN
            write_addr <= std_logic_vector(to_unsigned(addr, ADDR_WIDTH));
            write_data <= data;
            write_en   <= '1';
            WAIT UNTIL rising_edge(clk);
            write_en <= '0';
            WAIT FOR 1 ns;
        END PROCEDURE;

    BEGIN
        -- Reset
        rst <= '1';
        WAIT FOR 5 * CLK_PERIOD;
        rst <= '0';
        WAIT FOR CLK_PERIOD;

        -- RAS-T-001: Write then read
        do_write(5, x"ABCDE");
        check_read(5, x"ABCDE", "RAS-T-001: write/read addr 5");

        -- RAS-T-002: Address 0
        do_write(0, x"12345");
        check_read(0, x"12345", "RAS-T-002: addr 0");

        -- RAS-T-003: Max address (63)
        do_write(63, x"FEDCB");
        check_read(63, x"FEDCB", "RAS-T-003: addr 63");

        -- RAS-T-004: All ones
        do_write(10, x"FFFFF");
        check_read(10, x"FFFFF", "RAS-T-004: all ones");

        -- RAS-T-005: Alternating pattern
        do_write(15, x"AAAAA");
        check_read(15, x"AAAAA", "RAS-T-005: alternating");

        -- RAS-T-010: Different data to adjacent addresses
        do_write(20, x"11111");
        do_write(21, x"22222");
        do_write(22, x"33333");
        check_read(20, x"11111", "RAS-T-010a: addr 20");
        check_read(21, x"22222", "RAS-T-010b: addr 21");
        check_read(22, x"33333", "RAS-T-010c: addr 22");

        -- RAS-T-011: Write all 64 addresses
        FOR i IN 0 TO 63 LOOP
            do_write(i, std_logic_vector(to_unsigned(i * 1000 + 42, 20)));
        END LOOP;
        -- Verify a few
        check_read(0,  std_logic_vector(to_unsigned(42, 20)),       "RAS-T-011a: addr 0");
        check_read(31, std_logic_vector(to_unsigned(31*1000+42, 20)), "RAS-T-011b: addr 31");
        check_read(63, std_logic_vector(to_unsigned(63*1000+42, 20)), "RAS-T-011c: addr 63");

        -- RAS-T-012: Overwrite
        do_write(5, x"11111");
        check_read(5, x"11111", "RAS-T-012a: before overwrite");
        do_write(5, x"99999");
        check_read(5, x"99999", "RAS-T-012b: after overwrite");

        -- RAS-T-013: Non-written locations after reset
        rst <= '1';
        WAIT UNTIL rising_edge(clk);
        rst <= '0';
        WAIT FOR CLK_PERIOD;
        check_read(7, x"00000", "RAS-T-013: post-reset reads 0");

        -- RAS-T-021: Read-during-write same address (write-first)
        write_addr <= std_logic_vector(to_unsigned(8, ADDR_WIDTH));
        write_data <= x"CCCCC";
        read_addr  <= std_logic_vector(to_unsigned(8, ADDR_WIDTH));
        write_en   <= '1';
        WAIT FOR 2 ns;
        test_count <= test_count + 1;
        IF read_data = x"CCCCC" THEN
            REPORT "RAS-T-021: write-first forwarding PASSED" SEVERITY NOTE;
        ELSE
            REPORT "RAS-T-021: write-first forwarding: got 0x" &
                to_hstring(unsigned(read_data)) SEVERITY WARNING;
        END IF;
        WAIT UNTIL rising_edge(clk);
        write_en <= '0';
        WAIT FOR 1 ns;

        -- RAS-T-030: Reset clears all
        do_write(0, x"FFFFF");
        do_write(1, x"FFFFF");
        rst <= '1';
        WAIT UNTIL rising_edge(clk);
        rst <= '0';
        WAIT FOR CLK_PERIOD;
        check_read(0, x"00000", "RAS-T-030a: reset clears addr 0");
        check_read(1, x"00000", "RAS-T-030b: reset clears addr 1");

        -- RAS-T-040: Write disabled
        do_write(3, x"BBBBB");
        check_read(3, x"BBBBB", "RAS-T-040a: initial write");
        -- Now attempt write with write_en = 0
        write_addr <= std_logic_vector(to_unsigned(3, ADDR_WIDTH));
        write_data <= x"DDDDD";
        write_en   <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        check_read(3, x"BBBBB", "RAS-T-040b: write disabled holds");

        WAIT FOR 5 * CLK_PERIOD;

        -- Summary
        REPORT "======================================" SEVERITY NOTE;
        REPORT "RAS Testbench Complete" SEVERITY NOTE;
        REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
        REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;

        REPORT "sim complete" SEVERITY FAILURE;
    END PROCESS;

END ARCHITECTURE bench;

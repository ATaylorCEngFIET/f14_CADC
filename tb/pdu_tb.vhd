-------------------------------------------------------------------------------
-- PDU Testbench
-- F-14A Central Air Data Computer -- FPGA Implementation (Bit-Serial)
--
-- Verifies 20-bit signed fractional non-restoring division with bit-serial I/O.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pdu_tb IS
END ENTITY pdu_tb;

ARCHITECTURE bench OF pdu_tb IS

    CONSTANT CLK_PERIOD : TIME := 667 ns;  -- 1.5 MHz (original CADC)

    SIGNAL clk          : std_logic := '0';
    SIGNAL rst          : std_logic := '0';
    SIGNAL phi2         : std_logic := '0';
    SIGNAL word_type    : std_logic := '0';
    SIGNAL t0           : std_logic := '0';
    SIGNAL t19          : std_logic := '0';
    SIGNAL dividend_bit : std_logic := '0';
    SIGNAL divisor_bit  : std_logic := '0';
    SIGNAL quotient_bit : std_logic;
    SIGNAL remainder_bit: std_logic;
    SIGNAL busy         : std_logic;
    SIGNAL div_by_zero  : std_logic;

    -- Captured serial results
    SIGNAL quotient_sr  : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');
    SIGNAL remainder_sr : std_logic_vector(19 DOWNTO 0) := (OTHERS => '0');

    SIGNAL test_count : INTEGER := 0;
    SIGNAL fail_count : INTEGER := 0;
    SIGNAL phase      : UNSIGNED(1 DOWNTO 0) := "00";

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

    uut: ENTITY work.pdu
        PORT MAP (
            i_clk          => clk,
            i_rst          => rst,
            i_phi2         => phi2,
            i_word_type    => word_type,
            i_t0           => t0,
            i_t19          => t19,
            i_dividend_bit => dividend_bit,
            i_divisor_bit  => divisor_bit,
            o_quotient_bit => quotient_bit,
            o_remainder_bit=> remainder_bit,
            o_busy         => busy,
            o_div_by_zero  => div_by_zero
        );

    stim: PROCESS

        PROCEDURE wait_bit_time IS
        BEGIN
          FOR i IN 0 TO 3 LOOP
            WAIT UNTIL rising_edge(clk);
          END LOOP;
        END PROCEDURE;

        PROCEDURE run_wa_phase IS
        BEGIN
          word_type <= '0';
          FOR bit IN 0 TO 19 LOOP
            t0 <= '1' WHEN bit = 0 ELSE '0';
            t19 <= '1' WHEN bit = 19 ELSE '0';
            wait_bit_time;
          END LOOP;
          t0 <= '0'; t19 <= '0';
        END PROCEDURE;

        PROCEDURE run_wo_phase(
            dividend_val : IN std_logic_vector(19 DOWNTO 0);
            divisor_val  : IN std_logic_vector(19 DOWNTO 0)
        ) IS
            VARIABLE v_dividend : std_logic_vector(19 DOWNTO 0);
            VARIABLE v_divisor  : std_logic_vector(19 DOWNTO 0);
        BEGIN
          v_dividend := dividend_val;
          v_divisor  := divisor_val;
          word_type <= '1';
          
          FOR bit IN 0 TO 19 LOOP
            t0 <= '1' WHEN bit = 0 ELSE '0';
            t19 <= '1' WHEN bit = 19 ELSE '0';
            
            IF bit = 0 THEN
              quotient_sr <= (OTHERS => '0');
              remainder_sr <= (OTHERS => '0');
            END IF;
            
            dividend_bit <= v_dividend(0);
            divisor_bit  <= v_divisor(0);
            
            wait_bit_time;
            
            quotient_sr  <= quotient_bit & quotient_sr(19 DOWNTO 1);
            remainder_sr <= remainder_bit & remainder_sr(19 DOWNTO 1);
            
            v_dividend := '0' & v_dividend(19 DOWNTO 1);
            v_divisor  := '0' & v_divisor(19 DOWNTO 1);
          END LOOP;
          t0 <= '0'; t19 <= '0';
        END PROCEDURE;

        PROCEDURE do_divide(
            a       : IN std_logic_vector(19 DOWNTO 0);
            b       : IN std_logic_vector(19 DOWNTO 0);
            exp_q   : IN std_logic_vector(19 DOWNTO 0);
            name    : IN STRING;
            tolerance : IN INTEGER := 2
        ) IS
            VARIABLE diff : INTEGER;
        BEGIN
            run_wa_phase;
            run_wo_phase(a, b);
            -- Run extra cycles for computation
            run_wa_phase;
            run_wo_phase(x"00000", x"00000");
            
            test_count <= test_count + 1;
            WAIT FOR 1 ns;

            diff := ABS(to_integer(signed(quotient_sr)) - to_integer(signed(exp_q)));
            IF diff > tolerance THEN
                REPORT name & " FAILED: got Q=0x" &
                    to_hstring(unsigned(quotient_sr)) &
                    " expected 0x" & to_hstring(unsigned(exp_q)) &
                    " diff=" & INTEGER'image(diff)
                    SEVERITY ERROR;
                fail_count <= fail_count + 1;
            ELSE
                REPORT name & " PASSED (Q=0x" &
                    to_hstring(unsigned(quotient_sr)) & ")"
                    SEVERITY NOTE;
            END IF;
        END PROCEDURE;

    BEGIN
        rst <= '1';
        WAIT FOR 5 * CLK_PERIOD;
        rst <= '0';
        WAIT UNTIL phase = "00" AND rising_edge(clk);

        -- PDU-T-001: 0 / 0.5 = 0
        do_divide(x"00000", x"40000", x"00000", "PDU-T-001: 0/0.5");

        -- PDU-T-002: 0.25 / 0.5 = 0.5
        do_divide(x"20000", x"40000", x"40000", "PDU-T-002: 0.25/0.5");

        -- PDU-T-003: 0.125 / 0.5 = 0.25
        do_divide(x"10000", x"40000", x"20000", "PDU-T-003: 0.125/0.5");

        -- PDU-T-004: Reset during operation
        REPORT "PDU-T-004: Reset during operation..." SEVERITY NOTE;
        run_wa_phase;
        WAIT FOR 5 * CLK_PERIOD;
        rst <= '1';
        WAIT UNTIL rising_edge(clk);
        rst <= '0';
        WAIT FOR 1 ns;
        test_count <= test_count + 1;
        ASSERT busy = '0'
            REPORT "PDU-T-004 FAILED: busy not cleared" SEVERITY ERROR;
        REPORT "PDU-T-004: Reset during operation PASSED" SEVERITY NOTE;

        WAIT FOR 5 * CLK_PERIOD;

        REPORT "======================================" SEVERITY NOTE;
        REPORT "PDU Testbench Complete (Bit-Serial)" SEVERITY NOTE;
        REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
        REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
        REPORT "======================================" SEVERITY NOTE;

        REPORT "sim complete" SEVERITY FAILURE;
    END PROCESS;

END ARCHITECTURE bench;

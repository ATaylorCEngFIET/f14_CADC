-------------------------------------------------------------------------------
-- RAS Testbench (Parallel Addresses)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Verifies Serial RAM with parallel addresses and bit-serial data.
-- Tests read/write operations, address decoding, and reset behavior.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ras_tb IS
END ENTITY ras_tb;

ARCHITECTURE bench OF ras_tb IS

  CONSTANT CLK_PERIOD  : TIME := 667 ns;  -- 1.5 MHz
  CONSTANT ADDR_WIDTH  : NATURAL := 6;
  CONSTANT DATA_WIDTH  : NATURAL := 20;

  -- Signals
  SIGNAL clk         : STD_LOGIC := '0';
  SIGNAL rst         : STD_LOGIC := '0';
  SIGNAL phi2        : STD_LOGIC := '0';
  SIGNAL word_type   : STD_LOGIC := '0';
  SIGNAL t0          : STD_LOGIC := '0';
  SIGNAL t19         : STD_LOGIC := '0';
  SIGNAL rd_addr     : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0');
  SIGNAL wr_addr     : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0');
  SIGNAL write_en    : STD_LOGIC := '0';
  SIGNAL wr_data_bit : STD_LOGIC := '0';
  SIGNAL rd_data_bit : STD_LOGIC;

  -- Phase counter
  SIGNAL phase : UNSIGNED(1 DOWNTO 0) := "00";

  -- Captured results
  SIGNAL rd_data_sr : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');

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

  uut: ENTITY work.ras
    GENERIC MAP (
      g_addr_width => ADDR_WIDTH,
      g_data_width => DATA_WIDTH
    )
    PORT MAP (
      i_clk         => clk,
      i_rst         => rst,
      i_phi2        => phi2,
      i_word_type   => word_type,
      i_t0          => t0,
      i_t19         => t19,
      i_rd_addr     => rd_addr,
      i_wr_addr     => wr_addr,
      i_write_en    => write_en,
      i_wr_data_bit => wr_data_bit,
      o_rd_data_bit => rd_data_bit
    );

  stim_proc: PROCESS

    PROCEDURE wait_bit_time IS
    BEGIN
      FOR i IN 0 TO 3 LOOP
        WAIT UNTIL rising_edge(clk);
      END LOOP;
    END PROCEDURE;
    
    -- Wait until just before phi2 (phase = "01")
    PROCEDURE wait_pre_phi2 IS
    BEGIN
      WAIT UNTIL rising_edge(clk) AND phase = "01";
    END PROCEDURE;

    -- Run WA phase with parallel addresses (latched at T0)
    PROCEDURE run_wa_phase(
      r_addr : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
      w_addr : IN STD_LOGIC_VECTOR(5 DOWNTO 0)
    ) IS
    BEGIN
      -- Set addresses before WA phase
      rd_addr <= r_addr;
      wr_addr <= w_addr;
      
      word_type <= '0';
      FOR bit IN 0 TO 19 LOOP
        t0 <= '1' WHEN bit = 0 ELSE '0';
        t19 <= '1' WHEN bit = 19 ELSE '0';
        wait_bit_time;
      END LOOP;
      t0 <= '0'; t19 <= '0';
    END PROCEDURE;

    -- Run WO phase, shifting data in/out
    PROCEDURE run_wo_phase(
      wr_data : IN STD_LOGIC_VECTOR(19 DOWNTO 0)
    ) IS
      VARIABLE v_wr : STD_LOGIC_VECTOR(19 DOWNTO 0);
      VARIABLE v_rd_data : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
    BEGIN
      v_wr := wr_data;
      
      -- Set up WO signals
      word_type <= '1';
      v_rd_data := (OTHERS => '0');
      
      FOR bit IN 0 TO 19 LOOP
        IF bit = 0 THEN
          t0 <= '1';
        ELSE
          t0 <= '0';
        END IF;
        IF bit = 19 THEN
          t19 <= '1';
        ELSE
          t19 <= '0';
        END IF;
        wr_data_bit <= v_wr(0);
        
        wait_bit_time;
        
        -- Capture output after bit time 
        v_rd_data := rd_data_bit & v_rd_data(19 DOWNTO 1);
        
        v_wr := '0' & v_wr(19 DOWNTO 1);
      END LOOP;
      
      rd_data_sr <= v_rd_data;
      t0 <= '0'; t19 <= '0';
    END PROCEDURE;

    PROCEDURE write_mem(
      addr : IN INTEGER;
      data : IN STD_LOGIC_VECTOR(19 DOWNTO 0)
    ) IS
    BEGIN
      write_en <= '1';
      run_wa_phase("000000", STD_LOGIC_VECTOR(TO_UNSIGNED(addr, 6)));
      run_wo_phase(data);
      write_en <= '0';
    END PROCEDURE;

    PROCEDURE read_mem(
      addr     : IN INTEGER;
      expected : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      name     : IN STRING
    ) IS
      VARIABLE diff : INTEGER;
    BEGIN
      write_en <= '0';
      run_wa_phase(STD_LOGIC_VECTOR(TO_UNSIGNED(addr, 6)), "000000");
      run_wo_phase(x"00000");
      
      test_count <= test_count + 1;
      WAIT FOR 1 ns;
      
      diff := ABS(to_integer(SIGNED(rd_data_sr)) - to_integer(SIGNED(expected)));
      IF diff > 0 THEN
        REPORT name & " FAILED: got 0x" & to_hstring(UNSIGNED(rd_data_sr)) &
               " expected 0x" & to_hstring(UNSIGNED(expected)) SEVERITY ERROR;
        fail_count <= fail_count + 1;
      ELSE
        REPORT name & " PASSED (0x" & to_hstring(UNSIGNED(rd_data_sr)) & ")" SEVERITY NOTE;
      END IF;
    END PROCEDURE;

  BEGIN
    rst <= '1';
    WAIT FOR 5 * CLK_PERIOD;
    rst <= '0';
    WAIT UNTIL phase = "00" AND rising_edge(clk);

    -- RAS-T-001: Write and read address 0
    write_mem(0, x"12345");
    read_mem(0, x"12345", "RAS-T-001: Addr 0 write/read");

    -- RAS-T-002: Write and read address 63 (max)
    write_mem(63, x"FEDCB");
    read_mem(63, x"FEDCB", "RAS-T-002: Addr 63 write/read");

    -- RAS-T-003: Multiple locations
    write_mem(10, x"AAAAA");
    write_mem(20, x"55555");
    write_mem(30, x"0F0F0");
    read_mem(10, x"AAAAA", "RAS-T-003a: Addr 10");
    read_mem(20, x"55555", "RAS-T-003b: Addr 20");
    read_mem(30, x"0F0F0", "RAS-T-003c: Addr 30");

    -- RAS-T-004: Overwrite
    write_mem(5, x"11111");
    write_mem(5, x"22222");
    read_mem(5, x"22222", "RAS-T-004: Overwrite");

    -- RAS-T-005: Read doesn't modify
    read_mem(5, x"22222", "RAS-T-005: Read again");

    -- RAS-T-006: Reset clears RAM
    REPORT "RAS-T-006: Reset test..." SEVERITY NOTE;
    rst <= '1';
    WAIT FOR 5 * CLK_PERIOD;
    rst <= '0';
    WAIT UNTIL phase = "00" AND rising_edge(clk);
    read_mem(5, x"00000", "RAS-T-006: After reset");

    -- Summary
    REPORT "======================================" SEVERITY NOTE;
    REPORT "RAS Testbench Complete (Parallel Addresses)" SEVERITY NOTE;
    REPORT "Tests run: " & INTEGER'image(test_count) SEVERITY NOTE;
    REPORT "Failures:  " & INTEGER'image(fail_count) SEVERITY NOTE;
    REPORT "======================================" SEVERITY NOTE;

    ASSERT FALSE REPORT "sim complete" SEVERITY FAILURE;
    WAIT;
  END PROCESS stim_proc;

END ARCHITECTURE bench;

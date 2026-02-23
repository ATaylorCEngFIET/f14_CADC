-------------------------------------------------------------------------------
-- RAS - Random Access Storage (PN 944114)
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial)
--
-- Scratchpad RAM with serial data interface and parallel addresses.
-- Addresses come from parallel microword (bits 24-29 read, 30-35 write).
-- Data shifts in/out during WO phase.
--
-- Timing:
--   WA T0: Latch read/write addresses from parallel microword
--   WO T0: Fetch read data to shift register
--   WO T0-T19: Shift out read data, shift in write data
--   WO T19: Write data to RAM if write enabled
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ras IS
  GENERIC (
    g_addr_width : NATURAL := 6;
    g_data_width : NATURAL := 20
  );
  PORT (
    i_clk        : IN  STD_LOGIC;
    i_rst        : IN  STD_LOGIC;
    -- Timing inputs
    i_phi2       : IN  STD_LOGIC;   -- Shift on phi2
    i_word_type  : IN  STD_LOGIC;   -- '0'=WA, '1'=WO
    i_t0         : IN  STD_LOGIC;   -- First bit of word
    i_t19        : IN  STD_LOGIC;   -- Last bit of word
    -- Parallel address inputs (from microword)
    i_rd_addr    : IN  STD_LOGIC_VECTOR(g_addr_width-1 DOWNTO 0);
    i_wr_addr    : IN  STD_LOGIC_VECTOR(g_addr_width-1 DOWNTO 0);
    i_write_en   : IN  STD_LOGIC;   -- Write enable (from control)
    -- Serial data interface
    i_wr_data_bit: IN  STD_LOGIC;   -- Serial write data input (during WO)
    o_rd_data_bit: OUT STD_LOGIC    -- Serial read data output (during WO)
  );
END ENTITY ras;

ARCHITECTURE rtl OF ras IS

  TYPE t_mem IS ARRAY(0 TO 2**g_addr_width - 1)
    OF STD_LOGIC_VECTOR(g_data_width-1 DOWNTO 0);
  SIGNAL s_mem : t_mem := (OTHERS => (OTHERS => '0'));

  -- Latched addresses
  SIGNAL s_rd_addr  : STD_LOGIC_VECTOR(g_addr_width-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_wr_addr  : STD_LOGIC_VECTOR(g_addr_width-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_wr_en_lat: STD_LOGIC := '0';
  
  -- Data shift registers
  SIGNAL s_rd_sr    : STD_LOGIC_VECTOR(g_data_width-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_wr_sr    : STD_LOGIC_VECTOR(g_data_width-1 DOWNTO 0) := (OTHERS => '0');
  
  -- Write pending flag - complete write one phi2 after T19
  SIGNAL s_wr_pending : STD_LOGIC := '0';
  
  -- Output shift register (loaded at end of WA, shifted during WO)
  SIGNAL s_out_sr   : STD_LOGIC_VECTOR(g_data_width-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_out_ready: STD_LOGIC := '0';  -- Flag: output data is ready

BEGIN

  -- Serial output: always output bit 0 (testbench captures after phi2)
  -- Note: For module-to-module timing, may need "sr(0) WHEN t0='1' ELSE sr(1)"
  o_rd_data_bit <= s_out_sr(0);

  -----------------------------------------------------------------------------
  -- Address latch and output shift process
  -- Use phi2 edge for direct timing
  -----------------------------------------------------------------------------
  addr_latch_proc: PROCESS(i_phi2, i_rst)
  BEGIN
    IF i_rst = '1' THEN
      s_rd_addr    <= (OTHERS => '0');
      s_wr_addr    <= (OTHERS => '0');
      s_wr_en_lat  <= '0';
      s_out_sr     <= (OTHERS => '0');
      s_out_ready  <= '0';
    ELSIF RISING_EDGE(i_phi2) THEN
      IF i_word_type = '0' THEN
        -- WA: Latch addresses at T0 (microword is stable)
        IF i_t0 = '1' THEN
          s_rd_addr   <= i_rd_addr;
          s_wr_addr   <= i_wr_addr;
          s_out_ready <= '0';
        END IF;
        
        -- At end of WA (T19), pre-fetch read data and latch write enable
        IF i_t19 = '1' THEN
          s_wr_en_lat <= i_write_en;
          s_out_sr    <= s_mem(TO_INTEGER(UNSIGNED(s_rd_addr)));
          s_out_ready <= '1';
        END IF;
      ELSIF i_word_type = '1' AND s_out_ready = '1' THEN
        -- WO: Shift out data, skip shift at T0 to maintain alignment
        IF i_t0 = '0' THEN
          s_out_sr <= '0' & s_out_sr(g_data_width-1 DOWNTO 1);
        END IF;
      END IF;
    END IF;
  END PROCESS addr_latch_proc;

  -----------------------------------------------------------------------------
  -- Data transfer process - read fetch and shift during WO
  -----------------------------------------------------------------------------
  data_proc: PROCESS(i_phi2, i_rst)
  BEGIN
    IF i_rst = '1' THEN
      s_rd_sr <= (OTHERS => '0');
      s_wr_sr <= (OTHERS => '0');
    ELSIF RISING_EDGE(i_phi2) THEN
      IF i_word_type = '1' THEN
        IF i_t0 = '1' THEN
          -- WO T0: Fetch read data from RAM to shift register
          s_rd_sr <= s_mem(TO_INTEGER(UNSIGNED(s_rd_addr)));
          -- Start shifting in write data
          s_wr_sr <= i_wr_data_bit & s_wr_sr(g_data_width-1 DOWNTO 1);
        ELSE
          -- WO T1-T19: Continue shifting
          s_rd_sr <= '0' & s_rd_sr(g_data_width-1 DOWNTO 1);
          s_wr_sr <= i_wr_data_bit & s_wr_sr(g_data_width-1 DOWNTO 1);
        END IF;
      END IF;
    END IF;
  END PROCESS data_proc;

  -----------------------------------------------------------------------------
  -- RAM write process - delayed write to capture all 20 bits
  -- At T19, the last bit is being shifted in, so we set pending flag.
  -- The write completes at the NEXT phi2 (when s_wr_sr has all 20 bits).
  -----------------------------------------------------------------------------
  write_proc: PROCESS(i_phi2, i_rst)
  BEGIN
    IF i_rst = '1' THEN
      s_mem <= (OTHERS => (OTHERS => '0'));
      s_wr_pending <= '0';
    ELSIF RISING_EDGE(i_phi2) THEN
      -- Complete pending write (s_wr_sr now has all 20 bits from T19 shift)
      IF s_wr_pending = '1' THEN
        s_mem(TO_INTEGER(UNSIGNED(s_wr_addr))) <= s_wr_sr;
        s_wr_pending <= '0';
      END IF;
      
      -- At T19, mark write as pending (will complete next phi2)
      IF i_word_type = '1' AND i_t19 = '1' AND s_wr_en_lat = '1' THEN
        s_wr_pending <= '1';
      END IF;
    END IF;
  END PROCESS write_proc;

END ARCHITECTURE rtl;

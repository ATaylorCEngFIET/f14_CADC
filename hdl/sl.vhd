-------------------------------------------------------------------------------
-- SL - Steering Logic (PN 944118)
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial)
--
-- Three-channel bit-serial data routing multiplexer.
-- Routes serial data bits from multiple sources to 3 destinations.
--
-- Control comes from PARALLEL microword bits (not serial CW):
--   bits 7-10:  ACC source select (4 bits)
--   bits 11-14: RAS write source select (4 bits)
--   bits 15-21: IO output source select (7 bits)
-- This avoids conflicts with SLF (serial bits 0-6) and RAS (serial bits 7-18).
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY sl IS
  PORT (
    i_clk         : IN  STD_LOGIC;
    i_rst         : IN  STD_LOGIC;
    -- Timing inputs 
    i_phi2        : IN  STD_LOGIC;   -- Shift on phi2
    i_word_type   : IN  STD_LOGIC;   -- '0'=WA, '1'=WO
    i_t0          : IN  STD_LOGIC;   -- First bit of word
    i_t19         : IN  STD_LOGIC;   -- Last bit of word
    -- Serial data source inputs (active during WO)
    i_src_ras_bit : IN  STD_LOGIC;   -- RAS read data
    i_src_acc_bit : IN  STD_LOGIC;   -- ACC output
    i_src_tmp_bit : IN  STD_LOGIC;   -- TMP output
    i_src_pmu_bit : IN  STD_LOGIC;   -- PMU product
    i_src_pduq_bit: IN  STD_LOGIC;   -- PDU quotient
    i_src_pdur_bit: IN  STD_LOGIC;   -- PDU remainder
    i_src_io_bit  : IN  STD_LOGIC;   -- I/O input
    i_src_const_bit: IN STD_LOGIC;   -- Data ROM constant
    -- Parallel control (from microword)
    i_sel_acc     : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- ACC source
    i_sel_ras     : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- RAS write source
    i_sel_io      : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);  -- IO output source
    -- Serial data outputs (active during WO)
    o_acc_in_bit  : OUT STD_LOGIC;   -- To SLF ACC input
    o_ras_wr_bit  : OUT STD_LOGIC;   -- To RAS write data
    o_io_out_bit  : OUT STD_LOGIC    -- To I/O output
  );
END ENTITY sl;

ARCHITECTURE rtl OF sl IS

  -- Latched control word fields (latched at WA T0)
  SIGNAL s_sel_out1 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  -- ACC source
  SIGNAL s_sel_out2 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  -- RAS source
  SIGNAL s_sel_out3 : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');  -- IO source
  
  -- Selected bit values
  SIGNAL s_acc_in   : STD_LOGIC;
  SIGNAL s_ras_wr   : STD_LOGIC;
  SIGNAL s_io_out   : STD_LOGIC;

BEGIN

  o_acc_in_bit <= s_acc_in;
  o_ras_wr_bit <= s_ras_wr;
  o_io_out_bit <= s_io_out;

  -----------------------------------------------------------------------------
  -- Control latch process - latch parallel control at WA T0
  -----------------------------------------------------------------------------
  ctrl_latch_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_sel_out1 <= (OTHERS => '0');
        s_sel_out2 <= (OTHERS => '0');
        s_sel_out3 <= (OTHERS => '0');
      ELSIF i_phi2 = '1' AND i_word_type = '0' AND i_t0 = '1' THEN
        -- Latch control at start of WA (microword is stable)
        s_sel_out1 <= i_sel_acc;
        s_sel_out2 <= i_sel_ras;
        s_sel_out3 <= i_sel_io;
      END IF;
    END IF;
  END PROCESS ctrl_latch_proc;

  -----------------------------------------------------------------------------
  -- Output 1 (ACC input) multiplexer - 8 sources
  -----------------------------------------------------------------------------
  acc_mux_proc: PROCESS(s_sel_out1, i_src_ras_bit, i_src_pmu_bit, i_src_pduq_bit,
                        i_src_pdur_bit, i_src_io_bit, i_src_const_bit, 
                        i_src_tmp_bit, i_src_acc_bit)
  BEGIN
    CASE s_sel_out1(2 DOWNTO 0) IS
      WHEN "000"  => s_acc_in <= i_src_ras_bit;    -- RAS read data
      WHEN "001"  => s_acc_in <= i_src_pmu_bit;    -- PMU result
      WHEN "010"  => s_acc_in <= i_src_pduq_bit;   -- PDU quotient
      WHEN "011"  => s_acc_in <= i_src_pdur_bit;   -- PDU remainder
      WHEN "100"  => s_acc_in <= i_src_io_bit;     -- I/O input data
      WHEN "101"  => s_acc_in <= i_src_const_bit;  -- Data ROM constant
      WHEN "110"  => s_acc_in <= i_src_tmp_bit;    -- TMP register
      WHEN "111"  => s_acc_in <= i_src_acc_bit;    -- ACC (loopback)
      WHEN OTHERS => s_acc_in <= '0';
    END CASE;
  END PROCESS acc_mux_proc;

  -----------------------------------------------------------------------------
  -- Output 2 (RAS write data) multiplexer - 4 sources
  -----------------------------------------------------------------------------
  ras_mux_proc: PROCESS(s_sel_out2, i_src_acc_bit, i_src_pmu_bit, 
                        i_src_pduq_bit, i_src_io_bit)
  BEGIN
    CASE s_sel_out2(1 DOWNTO 0) IS
      WHEN "00"   => s_ras_wr <= i_src_acc_bit;
      WHEN "01"   => s_ras_wr <= i_src_pmu_bit;
      WHEN "10"   => s_ras_wr <= i_src_pduq_bit;
      WHEN "11"   => s_ras_wr <= i_src_io_bit;
      WHEN OTHERS => s_ras_wr <= '0';
    END CASE;
  END PROCESS ras_mux_proc;

  -----------------------------------------------------------------------------
  -- Output 3 (I/O output) multiplexer - 4 sources
  -----------------------------------------------------------------------------
  io_mux_proc: PROCESS(s_sel_out3, i_src_acc_bit, i_src_ras_bit,
                       i_src_pmu_bit, i_src_pduq_bit)
  BEGIN
    CASE s_sel_out3(1 DOWNTO 0) IS
      WHEN "00"   => s_io_out <= i_src_acc_bit;
      WHEN "01"   => s_io_out <= i_src_ras_bit;
      WHEN "10"   => s_io_out <= i_src_pmu_bit;
      WHEN "11"   => s_io_out <= i_src_pduq_bit;
      WHEN OTHERS => s_io_out <= '0';
    END CASE;
  END PROCESS io_mux_proc;

END ARCHITECTURE rtl;

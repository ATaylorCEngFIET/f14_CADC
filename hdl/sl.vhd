-------------------------------------------------------------------------------
-- SL - Steering Logic (PN 944118)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Three-channel combinational data routing multiplexer.
-- Routes data from 8 sources (RAS, ACC, TMP, PMU, PDU_Q, PDU_R, IO, CONST)
-- to 3 destinations (ACC input, RAS write data, I/O output).
-- Purely combinational - no clock, no registers.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY sl IS
  PORT (
    -- Data sources (20-bit each)
    i_src_ras     : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_src_acc     : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_src_tmp     : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_src_pmu     : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_src_pdu_q   : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_src_pdu_r   : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_src_io_in   : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_src_const   : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    -- Select controls
    i_sel_acc_src : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
    i_sel_ras_src : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
    i_sel_io_src  : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
    -- Routed outputs
    o_acc_in      : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_ras_wr_data : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_io_out      : OUT STD_LOGIC_VECTOR(19 DOWNTO 0)
  );
END ENTITY sl;

ARCHITECTURE rtl OF sl IS
BEGIN

  -----------------------------------------------------------------------------
  -- ACC input source mux (8:1)
  -----------------------------------------------------------------------------
  acc_mux_proc: PROCESS(i_sel_acc_src, i_src_ras, i_src_pmu, i_src_pdu_q,
                        i_src_pdu_r, i_src_io_in, i_src_const, i_src_tmp)
  BEGIN
    CASE i_sel_acc_src IS
      WHEN "000"  => o_acc_in <= i_src_ras;
      WHEN "001"  => o_acc_in <= i_src_pmu;
      WHEN "010"  => o_acc_in <= i_src_pdu_q;
      WHEN "011"  => o_acc_in <= i_src_pdu_r;
      WHEN "100"  => o_acc_in <= i_src_io_in;
      WHEN "101"  => o_acc_in <= i_src_const;
      WHEN "110"  => o_acc_in <= i_src_tmp;
      WHEN "111"  => o_acc_in <= (OTHERS => '0');
      WHEN OTHERS => o_acc_in <= (OTHERS => '0');
    END CASE;
  END PROCESS acc_mux_proc;

  -----------------------------------------------------------------------------
  -- RAS write data source mux (4:1)
  -----------------------------------------------------------------------------
  ras_mux_proc: PROCESS(i_sel_ras_src, i_src_acc, i_src_pmu, i_src_pdu_q,
                        i_src_io_in)
  BEGIN
    CASE i_sel_ras_src IS
      WHEN "00"   => o_ras_wr_data <= i_src_acc;
      WHEN "01"   => o_ras_wr_data <= i_src_pmu;
      WHEN "10"   => o_ras_wr_data <= i_src_pdu_q;
      WHEN "11"   => o_ras_wr_data <= i_src_io_in;
      WHEN OTHERS => o_ras_wr_data <= (OTHERS => '0');
    END CASE;
  END PROCESS ras_mux_proc;

  -----------------------------------------------------------------------------
  -- I/O output source mux (4:1)
  -----------------------------------------------------------------------------
  io_mux_proc: PROCESS(i_sel_io_src, i_src_acc, i_src_ras, i_src_pmu,
                       i_src_pdu_q)
  BEGIN
    CASE i_sel_io_src IS
      WHEN "00"   => o_io_out <= i_src_acc;
      WHEN "01"   => o_io_out <= i_src_ras;
      WHEN "10"   => o_io_out <= i_src_pmu;
      WHEN "11"   => o_io_out <= i_src_pdu_q;
      WHEN OTHERS => o_io_out <= (OTHERS => '0');
    END CASE;
  END PROCESS io_mux_proc;

END ARCHITECTURE rtl;

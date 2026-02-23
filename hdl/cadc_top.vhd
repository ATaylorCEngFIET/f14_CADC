-------------------------------------------------------------------------------
-- CADC Top Level
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial)
--
-- Bit-serial architecture with WA/WO timing.
-- Serial control word flows during WA, serial data flows during WO.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY cadc_top IS
  PORT (
    i_clk_master     : IN  STD_LOGIC;
    i_rst            : IN  STD_LOGIC;
    -- Parallel I/O still needed for external interfaces
    i_sensor_ps      : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_sensor_qc      : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_sensor_tat     : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_sensor_analog  : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_sensor_digital : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_mach       : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_alt        : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_airspd     : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_vspd       : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_wing       : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_flap       : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_glove      : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_bit_status     : OUT STD_LOGIC;
    i_channel_active : IN  STD_LOGIC;
    o_fail_detect    : OUT STD_LOGIC
  );
END ENTITY cadc_top;

ARCHITECTURE structural OF cadc_top IS

  -- Timing signals
  SIGNAL s_phi1           : STD_LOGIC;
  SIGNAL s_phi2           : STD_LOGIC;
  SIGNAL s_bit_clk        : STD_LOGIC;
  SIGNAL s_t0             : STD_LOGIC;
  SIGNAL s_t18            : STD_LOGIC;
  SIGNAL s_t19            : STD_LOGIC;
  SIGNAL s_bit_count      : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL s_word_type      : STD_LOGIC;
  SIGNAL s_word_mark      : STD_LOGIC;
  SIGNAL s_op_count       : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL s_frame_mark     : STD_LOGIC;

  -- Serial control word from sequencer
  SIGNAL s_cw_bit         : STD_LOGIC;
  SIGNAL s_const_bit      : STD_LOGIC;  -- Data ROM constant serial output
  
  -- Debug/monitoring
  SIGNAL s_micro_addr     : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL s_micro_word     : STD_LOGIC_VECTOR(47 DOWNTO 0);

  -- Flags from SLF
  SIGNAL s_flag_z         : STD_LOGIC;
  SIGNAL s_flag_n         : STD_LOGIC;
  SIGNAL s_flag_c         : STD_LOGIC;

  -- Busy signals
  SIGNAL s_pmu_busy       : STD_LOGIC;
  SIGNAL s_pdu_busy       : STD_LOGIC;

  -- Serial data streams between modules
  SIGNAL s_ras_rd_bit     : STD_LOGIC;  -- RAS read data
  SIGNAL s_ras_wr_bit     : STD_LOGIC;  -- RAS write data (from SL)
  SIGNAL s_acc_bit        : STD_LOGIC;  -- ACC output
  SIGNAL s_tmp_bit        : STD_LOGIC;  -- TMP output
  SIGNAL s_slf_result_bit : STD_LOGIC;  -- SLF result
  SIGNAL s_pmu_prod_bit   : STD_LOGIC;  -- PMU product
  SIGNAL s_pdu_quot_bit   : STD_LOGIC;  -- PDU quotient
  SIGNAL s_pdu_rem_bit    : STD_LOGIC;  -- PDU remainder
  SIGNAL s_io_in_bit      : STD_LOGIC;  -- I/O input
  SIGNAL s_io_out_bit     : STD_LOGIC;  -- I/O output (from SL)
  SIGNAL s_acc_in_bit     : STD_LOGIC;  -- To SLF ACC (from SL)

  -- I/O bridge parallel interfaces (external still parallel)
  SIGNAL s_io_data_in_par : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_io_data_out_par: STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_io_ctrl        : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL s_io_ready       : STD_LOGIC;
  
  -- Shift register for I/O serialization
  SIGNAL s_io_in_sr       : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_io_out_sr      : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');

  -- RAS write enable (extracted from control word)
  SIGNAL s_ras_write_en   : STD_LOGIC;

BEGIN

  -----------------------------------------------------------------------------
  -- Timing Generator
  -----------------------------------------------------------------------------
  u_timing: ENTITY work.timing_generator
    PORT MAP (
      i_clk_master => i_clk_master,
      i_rst        => i_rst,
      o_phi1       => s_phi1,
      o_phi2       => s_phi2,
      o_bit_clk    => s_bit_clk,
      o_t0         => s_t0,
      o_t18        => s_t18,
      o_t19        => s_t19,
      o_bit_count  => s_bit_count,
      o_word_type  => s_word_type,
      o_word_mark  => s_word_mark,
      o_op_count   => s_op_count,
      o_frame_mark => s_frame_mark
    );

  -----------------------------------------------------------------------------
  -- Control ROM Sequencer - outputs serial control word
  -----------------------------------------------------------------------------
  u_sequencer: ENTITY work.control_rom_sequencer
    GENERIC MAP (
      g_ctrl_rom_depth => 1024,
      g_data_rom_depth => 512,
      g_uword_width    => 48
    )
    PORT MAP (
      i_clk            => i_clk_master,
      i_rst            => i_rst,
      i_phi2           => s_phi2,
      i_word_type      => s_word_type,
      i_t0             => s_t0,
      i_t19            => s_t19,
      i_flag_z         => s_flag_z,
      i_flag_n         => s_flag_n,
      i_flag_c         => s_flag_c,
      i_pmu_busy       => s_pmu_busy,
      i_pdu_busy       => s_pdu_busy,
      i_frame_mark     => s_frame_mark,
      o_cw_bit         => s_cw_bit,
      o_const_bit      => s_const_bit,
      o_micro_addr     => s_micro_addr,
      o_micro_word     => s_micro_word
    );

  -----------------------------------------------------------------------------
  -- SLF - Special Logic Function / ALU (bit-serial I/O)
  -----------------------------------------------------------------------------
  u_slf: ENTITY work.slf
    PORT MAP (
      i_clk            => i_clk_master,
      i_rst            => i_rst,
      i_phi2           => s_phi2,
      i_word_type      => s_word_type,
      i_t0             => s_t0,
      i_t18            => s_t18,
      i_t19            => s_t19,
      i_cw_bit         => s_cw_bit,
      i_data_bit       => s_acc_in_bit,
      o_result_bit     => s_slf_result_bit,
      o_acc_bit        => s_acc_bit,
      o_tmp_bit        => s_tmp_bit,
      o_flag_z         => s_flag_z,
      o_flag_n         => s_flag_n,
      o_flag_c         => s_flag_c
    );

  -----------------------------------------------------------------------------
  -- PMU - Parallel Multiplier Unit (bit-serial I/O)
  -----------------------------------------------------------------------------
  u_pmu: ENTITY work.pmu
    PORT MAP (
      i_clk        => i_clk_master,
      i_rst        => i_rst,
      i_phi2       => s_phi2,
      i_word_type  => s_word_type,
      i_t0         => s_t0,
      i_t19        => s_t19,
      i_mcand_bit  => s_acc_bit,      -- Multiplicand from ACC
      i_mplier_bit => s_tmp_bit,      -- Multiplier from TMP
      o_prod_bit   => s_pmu_prod_bit,
      o_busy       => s_pmu_busy
    );

  -----------------------------------------------------------------------------
  -- PDU - Parallel Divider Unit (bit-serial I/O)
  -----------------------------------------------------------------------------
  u_pdu: ENTITY work.pdu
    PORT MAP (
      i_clk          => i_clk_master,
      i_rst          => i_rst,
      i_phi2         => s_phi2,
      i_word_type    => s_word_type,
      i_t0           => s_t0,
      i_t19          => s_t19,
      i_dividend_bit => s_acc_bit,    -- Dividend from ACC
      i_divisor_bit  => s_tmp_bit,    -- Divisor from TMP
      o_quotient_bit => s_pdu_quot_bit,
      o_remainder_bit=> s_pdu_rem_bit,
      o_busy         => s_pdu_busy
    );

  -----------------------------------------------------------------------------
  -- RAS - Random Access Storage (bit-serial data, parallel addresses)
  -- Addresses from parallel microword to avoid serial CW conflicts
  -----------------------------------------------------------------------------
  u_ras: ENTITY work.ras
    GENERIC MAP (
      g_addr_width => 6,
      g_data_width => 20
    )
    PORT MAP (
      i_clk        => i_clk_master,
      i_rst        => i_rst,
      i_phi2       => s_phi2,
      i_word_type  => s_word_type,
      i_t0         => s_t0,
      i_t19        => s_t19,
      i_rd_addr    => s_micro_word(23 DOWNTO 18),  -- RAS read address
      i_wr_addr    => s_micro_word(29 DOWNTO 24),  -- RAS write address
      i_write_en   => s_ras_write_en,
      i_wr_data_bit=> s_ras_wr_bit,
      o_rd_data_bit=> s_ras_rd_bit
    );

  -- RAS write enable from control word (bit 30)
  s_ras_write_en <= s_micro_word(30);

  -----------------------------------------------------------------------------
  -- SL - Steering Logic (bit-serial routing, parallel control)
  -- Control bits from parallel microword to avoid serial CW conflicts
  -----------------------------------------------------------------------------
  u_sl: ENTITY work.sl
    PORT MAP (
      i_clk         => i_clk_master,
      i_rst         => i_rst,
      i_phi2        => s_phi2,
      i_word_type   => s_word_type,
      i_t0          => s_t0,
      i_t19         => s_t19,
      i_src_ras_bit => s_ras_rd_bit,
      i_src_acc_bit => s_acc_bit,
      i_src_tmp_bit => s_tmp_bit,
      i_src_pmu_bit => s_pmu_prod_bit,
      i_src_pduq_bit=> s_pdu_quot_bit,
      i_src_pdur_bit=> s_pdu_rem_bit,
      i_src_io_bit  => s_io_in_bit,
      i_src_const_bit=> s_const_bit,
      i_sel_acc     => s_micro_word(10 DOWNTO 7),   -- ACC source select
      i_sel_ras     => s_micro_word(14 DOWNTO 11),  -- RAS source select
      i_sel_io      => s_micro_word(17 DOWNTO 15),  -- IO output select
      o_acc_in_bit  => s_acc_in_bit,
      o_ras_wr_bit  => s_ras_wr_bit,
      o_io_out_bit  => s_io_out_bit
    );

  -----------------------------------------------------------------------------
  -- I/O Bridge - Parallel external interface with serial internal
  -- External sensors/outputs are parallel, internal data is serial
  -----------------------------------------------------------------------------
  u_io: ENTITY work.io_bridge
    PORT MAP (
      i_clk            => i_clk_master,
      i_rst            => i_rst,
      i_io_ctrl        => s_io_ctrl,
      i_io_data_in     => s_io_data_in_par,
      o_io_data_out    => s_io_data_out_par,
      o_io_ready       => s_io_ready,
      i_sensor_ps      => i_sensor_ps,
      i_sensor_qc      => i_sensor_qc,
      i_sensor_tat     => i_sensor_tat,
      i_sensor_analog  => i_sensor_analog,
      i_sensor_digital => i_sensor_digital,
      o_out_mach       => o_out_mach,
      o_out_alt        => o_out_alt,
      o_out_airspd     => o_out_airspd,
      o_out_vspd       => o_out_vspd,
      o_out_wing       => o_out_wing,
      o_out_flap       => o_out_flap,
      o_out_glove      => o_out_glove,
      o_out_bit_status => o_bit_status,
      i_channel_active => i_channel_active,
      o_fail_detect    => o_fail_detect
    );

  -- I/O control from parallel microword (gate with WA to avoid WO corruption)
  s_io_ctrl <= s_micro_word(3 DOWNTO 0) WHEN s_word_type = '0' ELSE "0000";

  -----------------------------------------------------------------------------
  -- I/O Serialization - Convert between parallel I/O and serial streams
  -----------------------------------------------------------------------------
  io_serial_proc: PROCESS(i_clk_master)
  BEGIN
    IF RISING_EDGE(i_clk_master) THEN
      IF i_rst = '1' THEN
        s_io_in_sr  <= (OTHERS => '0');
        s_io_out_sr <= (OTHERS => '0');
      ELSIF s_phi2 = '1' AND s_word_type = '1' THEN
        IF s_t0 = '1' THEN
          -- Load parallel input at start of WO
          s_io_in_sr <= s_io_data_out_par;
          -- Start collecting output (don't shift yet)
          s_io_out_sr <= s_io_out_bit & s_io_out_sr(19 DOWNTO 1);
        ELSE
          -- Shift during WO T1-T19
          s_io_in_sr  <= '0' & s_io_in_sr(19 DOWNTO 1);
          s_io_out_sr <= s_io_out_bit & s_io_out_sr(19 DOWNTO 1);
        END IF;
      END IF;
    END IF;
  END PROCESS io_serial_proc;

  -- Serial I/O output: T0 outputs bit(0), T1+ outputs bit(1) for same-edge timing
  s_io_in_bit      <= s_io_in_sr(0) WHEN s_t0 = '1' ELSE s_io_in_sr(1);
  s_io_data_in_par <= s_io_out_sr;     -- Parallel output to bridge

END ARCHITECTURE structural;

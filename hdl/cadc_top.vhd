-------------------------------------------------------------------------------
-- CADC Top Level
-- F-14A Central Air Data Computer - FPGA Implementation
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY cadc_top IS
  PORT (
    i_clk_master     : IN  STD_LOGIC;
    i_rst            : IN  STD_LOGIC;
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

  SIGNAL s_phi1           : STD_LOGIC;
  SIGNAL s_phi2           : STD_LOGIC;
  SIGNAL s_bit_count      : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL s_word_type      : STD_LOGIC;
  SIGNAL s_word_mark      : STD_LOGIC;
  SIGNAL s_op_count       : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL s_frame_mark     : STD_LOGIC;
  SIGNAL s_micro_addr     : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL s_micro_word     : STD_LOGIC_VECTOR(47 DOWNTO 0);
  SIGNAL s_alu_op         : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL s_acc_write_en   : STD_LOGIC;
  SIGNAL s_tmp_write_en   : STD_LOGIC;
  SIGNAL s_flags_write_en : STD_LOGIC;
  SIGNAL s_ras_write_en   : STD_LOGIC;
  SIGNAL s_ras_read_addr  : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL s_ras_write_addr : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL s_sel_acc_src    : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL s_sel_ras_src    : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL s_sel_io_src     : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL s_pmu_start      : STD_LOGIC;
  SIGNAL s_pdu_start      : STD_LOGIC;
  SIGNAL s_io_ctrl        : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL s_data_rom_addr  : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL s_slf_acc_in     : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_slf_acc_out    : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_slf_tmp_out    : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_slf_alu_result : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_flag_z         : STD_LOGIC;
  SIGNAL s_flag_n         : STD_LOGIC;
  SIGNAL s_flag_c         : STD_LOGIC;
  SIGNAL s_pmu_operand_a  : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_pmu_operand_b  : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_pmu_result     : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_pmu_busy       : STD_LOGIC;
  SIGNAL s_pmu_done       : STD_LOGIC;
  SIGNAL s_pdu_dividend   : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_pdu_divisor    : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_pdu_quotient   : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_pdu_remainder  : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_pdu_busy       : STD_LOGIC;
  SIGNAL s_pdu_done       : STD_LOGIC;
  SIGNAL s_pdu_div_by_zero: STD_LOGIC;
  SIGNAL s_ras_read_data  : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_ras_write_data : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_io_data_in     : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_io_data_out    : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_io_ready       : STD_LOGIC;
  SIGNAL s_data_rom_data  : STD_LOGIC_VECTOR(19 DOWNTO 0);

  ---------------------------------------------------------------------------
  -- Data ROM: Stores polynomial coefficients and constants
  -- Format: Q1.19 signed fractional (-1.0 to +0.999998)
  --
  -- Polynomial: E = a3*X^3 + a2*X^2 + a1*X + a0
  -- Example coefficients (from Section 2 documentation):
  --   Addr 0: a3 = 0.125  = 0x10000
  --   Addr 1: a2 = 0.25   = 0x20000
  --   Addr 2: a1 = 0.375  = 0x30000
  --   Addr 3: a0 = 0.0625 = 0x08000
  ---------------------------------------------------------------------------
  TYPE t_data_rom IS ARRAY(0 TO 511) OF STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_data_rom : t_data_rom := (
    0      => x"10000",  -- a3 = 0.125
    1      => x"20000",  -- a2 = 0.25
    2      => x"30000",  -- a1 = 0.375
    3      => x"08000",  -- a0 = 0.0625
    OTHERS => (OTHERS => '0')
  );

BEGIN

  s_data_rom_data <= s_data_rom(TO_INTEGER(UNSIGNED(s_data_rom_addr(8 DOWNTO 0))));
  s_pmu_operand_a <= s_slf_acc_out;
  s_pmu_operand_b <= s_slf_tmp_out;
  s_pdu_dividend  <= s_slf_acc_out;
  s_pdu_divisor   <= s_slf_tmp_out;

  u_timing: ENTITY work.timing_generator
    GENERIC MAP (g_clk_div => 1)
    PORT MAP (
      i_clk_master => i_clk_master,
      i_rst        => i_rst,
      o_phi1       => s_phi1,
      o_phi2       => s_phi2,
      o_bit_count  => s_bit_count,
      o_word_type  => s_word_type,
      o_word_mark  => s_word_mark,
      o_op_count   => s_op_count,
      o_frame_mark => s_frame_mark
    );

  u_sequencer: ENTITY work.control_rom_sequencer
    GENERIC MAP (
      g_ctrl_rom_depth => 1024,
      g_data_rom_depth => 512,
      g_uword_width    => 48
    )
    PORT MAP (
      i_clk            => i_clk_master,
      i_rst            => i_rst,
      i_flag_z         => s_flag_z,
      i_flag_n         => s_flag_n,
      i_flag_c         => s_flag_c,
      i_pmu_busy       => s_pmu_busy,
      i_pdu_busy       => s_pdu_busy,
      i_frame_mark     => s_frame_mark,
      o_micro_addr     => s_micro_addr,
      o_micro_word     => s_micro_word,
      o_alu_op         => s_alu_op,
      o_acc_write_en   => s_acc_write_en,
      o_tmp_write_en   => s_tmp_write_en,
      o_flags_write_en => s_flags_write_en,
      o_ras_write_en   => s_ras_write_en,
      o_ras_read_addr  => s_ras_read_addr,
      o_ras_write_addr => s_ras_write_addr,
      o_sel_acc_src    => s_sel_acc_src,
      o_sel_ras_src    => s_sel_ras_src,
      o_sel_io_src     => s_sel_io_src,
      o_pmu_start      => s_pmu_start,
      o_pdu_start      => s_pdu_start,
      o_io_ctrl        => s_io_ctrl,
      o_data_rom_addr  => s_data_rom_addr,
      i_data_rom_data  => s_data_rom_data
    );

  u_slf: ENTITY work.slf
    PORT MAP (
      i_clk            => i_clk_master,
      i_rst            => i_rst,
      i_alu_op         => s_alu_op,
      i_acc_in         => s_slf_acc_in,
      i_acc_write_en   => s_acc_write_en,
      i_tmp_write_en   => s_tmp_write_en,
      i_flags_write_en => s_flags_write_en,
      o_acc_out        => s_slf_acc_out,
      o_tmp_out        => s_slf_tmp_out,
      o_alu_result     => s_slf_alu_result,
      o_flag_z         => s_flag_z,
      o_flag_n         => s_flag_n,
      o_flag_c         => s_flag_c
    );

  u_pmu: ENTITY work.pmu
    PORT MAP (
      i_clk       => i_clk_master,
      i_rst       => i_rst,
      i_start     => s_pmu_start,
      i_operand_a => s_pmu_operand_a,
      i_operand_b => s_pmu_operand_b,
      o_result    => s_pmu_result,
      o_busy      => s_pmu_busy,
      o_done      => s_pmu_done
    );

  u_pdu: ENTITY work.pdu
    PORT MAP (
      i_clk         => i_clk_master,
      i_rst         => i_rst,
      i_start       => s_pdu_start,
      i_dividend    => s_pdu_dividend,
      i_divisor     => s_pdu_divisor,
      o_quotient    => s_pdu_quotient,
      o_remainder   => s_pdu_remainder,
      o_busy        => s_pdu_busy,
      o_done        => s_pdu_done,
      o_div_by_zero => s_pdu_div_by_zero
    );

  u_ras: ENTITY work.ras
    GENERIC MAP (
      g_addr_width => 6,
      g_data_width => 20
    )
    PORT MAP (
      i_clk        => i_clk_master,
      i_rst        => i_rst,
      i_read_addr  => s_ras_read_addr,
      o_read_data  => s_ras_read_data,
      i_write_addr => s_ras_write_addr,
      i_write_data => s_ras_write_data,
      i_write_en   => s_ras_write_en
    );

  u_sl: ENTITY work.sl
    PORT MAP (
      i_src_ras     => s_ras_read_data,
      i_src_acc     => s_slf_acc_out,
      i_src_tmp     => s_slf_tmp_out,
      i_src_pmu     => s_pmu_result,
      i_src_pdu_q   => s_pdu_quotient,
      i_src_pdu_r   => s_pdu_remainder,
      i_src_io_in   => s_io_data_out,
      i_src_const   => s_data_rom_data,
      i_sel_acc_src => s_sel_acc_src,
      i_sel_ras_src => s_sel_ras_src,
      i_sel_io_src  => s_sel_io_src,
      o_acc_in      => s_slf_acc_in,
      o_ras_wr_data => s_ras_write_data,
      o_io_out      => s_io_data_in
    );

  u_io: ENTITY work.io_bridge
    PORT MAP (
      i_clk            => i_clk_master,
      i_rst            => i_rst,
      i_io_ctrl        => s_io_ctrl,
      i_io_data_in     => s_io_data_in,
      o_io_data_out    => s_io_data_out,
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

END ARCHITECTURE structural;

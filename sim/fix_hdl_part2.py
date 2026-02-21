#!/usr/bin/env python3
"""Fix HDL files - Part 2."""

def fix_control_rom_sequencer():
    path = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\hdl\control_rom_sequencer.vhd"
    content = '''-------------------------------------------------------------------------------
-- Control ROM + Sequencer
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Micro-programmed sequencer with 1024-deep control ROM.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY control_rom_sequencer IS
  GENERIC (
    g_ctrl_rom_depth : NATURAL := 1024;
    g_data_rom_depth : NATURAL := 512;
    g_uword_width    : NATURAL := 48
  );
  PORT (
    i_clk            : IN  STD_LOGIC;
    i_rst            : IN  STD_LOGIC;
    i_flag_z         : IN  STD_LOGIC;
    i_flag_n         : IN  STD_LOGIC;
    i_flag_c         : IN  STD_LOGIC;
    i_pmu_busy       : IN  STD_LOGIC;
    i_pdu_busy       : IN  STD_LOGIC;
    i_frame_mark     : IN  STD_LOGIC;
    o_micro_addr     : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    o_micro_word     : OUT STD_LOGIC_VECTOR(g_uword_width-1 DOWNTO 0);
    o_alu_op         : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_acc_write_en   : OUT STD_LOGIC;
    o_tmp_write_en   : OUT STD_LOGIC;
    o_flags_write_en : OUT STD_LOGIC;
    o_ras_write_en   : OUT STD_LOGIC;
    o_ras_read_addr  : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    o_ras_write_addr : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    o_sel_acc_src    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    o_sel_ras_src    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    o_sel_io_src     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    o_pmu_start      : OUT STD_LOGIC;
    o_pdu_start      : OUT STD_LOGIC;
    o_io_ctrl        : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_data_rom_addr  : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    i_data_rom_data  : IN  STD_LOGIC_VECTOR(19 DOWNTO 0)
  );
END ENTITY control_rom_sequencer;

ARCHITECTURE rtl OF control_rom_sequencer IS

  CONSTANT c_nc_seq      : UNSIGNED(7 DOWNTO 0) := x"00";
  CONSTANT c_nc_jump     : UNSIGNED(7 DOWNTO 0) := x"01";
  CONSTANT c_nc_brz      : UNSIGNED(7 DOWNTO 0) := x"02";
  CONSTANT c_nc_brn      : UNSIGNED(7 DOWNTO 0) := x"03";
  CONSTANT c_nc_brc      : UNSIGNED(7 DOWNTO 0) := x"04";
  CONSTANT c_nc_br_pmub  : UNSIGNED(7 DOWNTO 0) := x"05";
  CONSTANT c_nc_br_pdub  : UNSIGNED(7 DOWNTO 0) := x"06";
  CONSTANT c_nc_wait_pmu : UNSIGNED(7 DOWNTO 0) := x"07";
  CONSTANT c_nc_wait_pdu : UNSIGNED(7 DOWNTO 0) := x"08";
  CONSTANT c_nc_call     : UNSIGNED(7 DOWNTO 0) := x"09";
  CONSTANT c_nc_ret      : UNSIGNED(7 DOWNTO 0) := x"0A";

  TYPE t_ctrl_rom IS ARRAY(0 TO g_ctrl_rom_depth-1)
    OF STD_LOGIC_VECTOR(g_uword_width-1 DOWNTO 0);
  SIGNAL s_ctrl_rom : t_ctrl_rom := (OTHERS => (OTHERS => '0'));

  SIGNAL s_micro_pc : UNSIGNED(9 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_next_pc  : UNSIGNED(9 DOWNTO 0);

  TYPE t_stack IS ARRAY(0 TO 3) OF UNSIGNED(9 DOWNTO 0);
  SIGNAL s_ret_stack : t_stack := (OTHERS => (OTHERS => '0'));
  SIGNAL s_stack_ptr : UNSIGNED(1 DOWNTO 0) := (OTHERS => '0');

  SIGNAL s_current_uword : STD_LOGIC_VECTOR(g_uword_width-1 DOWNTO 0);
  SIGNAL s_nextctl_field : UNSIGNED(7 DOWNTO 0);
  SIGNAL s_nextadr_field : UNSIGNED(7 DOWNTO 0);
  SIGNAL s_ras_addr_3bit : STD_LOGIC_VECTOR(2 DOWNTO 0);

BEGIN

  s_current_uword <= s_ctrl_rom(TO_INTEGER(s_micro_pc));
  o_micro_word    <= s_current_uword;
  o_micro_addr    <= STD_LOGIC_VECTOR(s_micro_pc);

  s_nextctl_field <= UNSIGNED(s_current_uword(47 DOWNTO 40));
  s_nextadr_field <= UNSIGNED(s_current_uword(39 DOWNTO 32));

  o_alu_op         <= s_current_uword(31 DOWNTO 28);
  o_acc_write_en   <= s_current_uword(27);
  o_tmp_write_en   <= s_current_uword(26);
  o_flags_write_en <= s_current_uword(25);
  o_ras_write_en   <= s_current_uword(23);
  s_ras_addr_3bit  <= s_current_uword(22 DOWNTO 20);
  o_ras_read_addr  <= "000" & s_ras_addr_3bit;
  o_ras_write_addr <= "000" & s_ras_addr_3bit;
  o_sel_acc_src    <= s_current_uword(18 DOWNTO 16);
  o_sel_ras_src    <= s_current_uword(15 DOWNTO 14);
  o_sel_io_src     <= s_current_uword(13 DOWNTO 12);
  o_pmu_start      <= s_current_uword(11);
  o_pdu_start      <= s_current_uword(7);
  o_io_ctrl        <= s_current_uword(3 DOWNTO 0);
  o_data_rom_addr  <= "00" & STD_LOGIC_VECTOR(s_nextadr_field);

  next_pc_proc: PROCESS(s_micro_pc, s_nextctl_field, s_nextadr_field,
                        i_flag_z, i_flag_n, i_flag_c, i_pmu_busy, i_pdu_busy,
                        i_frame_mark, s_ret_stack, s_stack_ptr)
  BEGIN
    s_next_pc <= s_micro_pc + 1;
    IF i_frame_mark = '1' THEN
      s_next_pc <= (OTHERS => '0');
    ELSE
      CASE s_nextctl_field IS
        WHEN c_nc_seq =>
          s_next_pc <= s_micro_pc + 1;
        WHEN c_nc_jump =>
          s_next_pc <= RESIZE(s_nextadr_field, 10);
        WHEN c_nc_brz =>
          IF i_flag_z = '1' THEN
            s_next_pc <= RESIZE(s_nextadr_field, 10);
          ELSE
            s_next_pc <= s_micro_pc + 1;
          END IF;
        WHEN c_nc_brn =>
          IF i_flag_n = '1' THEN
            s_next_pc <= RESIZE(s_nextadr_field, 10);
          ELSE
            s_next_pc <= s_micro_pc + 1;
          END IF;
        WHEN c_nc_brc =>
          IF i_flag_c = '1' THEN
            s_next_pc <= RESIZE(s_nextadr_field, 10);
          ELSE
            s_next_pc <= s_micro_pc + 1;
          END IF;
        WHEN c_nc_br_pmub =>
          IF i_pmu_busy = '1' THEN
            s_next_pc <= RESIZE(s_nextadr_field, 10);
          ELSE
            s_next_pc <= s_micro_pc + 1;
          END IF;
        WHEN c_nc_br_pdub =>
          IF i_pdu_busy = '1' THEN
            s_next_pc <= RESIZE(s_nextadr_field, 10);
          ELSE
            s_next_pc <= s_micro_pc + 1;
          END IF;
        WHEN c_nc_wait_pmu =>
          IF i_pmu_busy = '1' THEN
            s_next_pc <= s_micro_pc;
          ELSE
            s_next_pc <= s_micro_pc + 1;
          END IF;
        WHEN c_nc_wait_pdu =>
          IF i_pdu_busy = '1' THEN
            s_next_pc <= s_micro_pc;
          ELSE
            s_next_pc <= s_micro_pc + 1;
          END IF;
        WHEN c_nc_call =>
          s_next_pc <= RESIZE(s_nextadr_field, 10);
        WHEN c_nc_ret =>
          IF s_stack_ptr > 0 THEN
            s_next_pc <= s_ret_stack(TO_INTEGER(s_stack_ptr - 1));
          ELSE
            s_next_pc <= s_micro_pc + 1;
          END IF;
        WHEN OTHERS =>
          s_next_pc <= s_micro_pc + 1;
      END CASE;
    END IF;
  END PROCESS next_pc_proc;

  pc_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_micro_pc  <= (OTHERS => '0');
        s_stack_ptr <= (OTHERS => '0');
        s_ret_stack <= (OTHERS => (OTHERS => '0'));
      ELSE
        s_micro_pc <= s_next_pc;
        IF i_frame_mark = '0' THEN
          IF s_nextctl_field = c_nc_call THEN
            s_ret_stack(TO_INTEGER(s_stack_ptr)) <= s_micro_pc + 1;
            s_stack_ptr <= s_stack_ptr + 1;
          ELSIF s_nextctl_field = c_nc_ret THEN
            IF s_stack_ptr > 0 THEN
              s_stack_ptr <= s_stack_ptr - 1;
            END IF;
          END IF;
        END IF;
      END IF;
    END IF;
  END PROCESS pc_proc;

END ARCHITECTURE rtl;
'''
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_io_bridge():
    path = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\hdl\io_bridge.vhd"
    content = '''-------------------------------------------------------------------------------
-- I/O Bridge Module
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Interfaces CADC core to external sensors and display/actuator outputs.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY io_bridge IS
  PORT (
    i_clk            : IN  STD_LOGIC;
    i_rst            : IN  STD_LOGIC;
    i_io_ctrl        : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_io_data_in     : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_io_data_out    : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_io_ready       : OUT STD_LOGIC;
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
    o_out_bit_status : OUT STD_LOGIC;
    i_channel_active : IN  STD_LOGIC;
    o_fail_detect    : OUT STD_LOGIC
  );
END ENTITY io_bridge;

ARCHITECTURE rtl OF io_bridge IS

  CONSTANT c_io_nop          : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
  CONSTANT c_io_read_ps      : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0001";
  CONSTANT c_io_read_qc      : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0010";
  CONSTANT c_io_read_tat     : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0011";
  CONSTANT c_io_read_analog  : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0100";
  CONSTANT c_io_read_digital : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0101";
  CONSTANT c_io_write_mach   : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0110";
  CONSTANT c_io_write_alt    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0111";
  CONSTANT c_io_write_airspd : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1000";
  CONSTANT c_io_write_vspd   : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1001";
  CONSTANT c_io_write_wing   : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1010";
  CONSTANT c_io_write_flap   : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1011";
  CONSTANT c_io_write_glove  : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1100";
  CONSTANT c_io_write_bit    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1101";

  SIGNAL s_reg_mach     : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_reg_alt      : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_reg_airspd   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_reg_vspd     : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_reg_wing     : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_reg_flap     : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_reg_glove    : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_reg_bit      : STD_LOGIC := '0';
  SIGNAL s_latched_data : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_ready_reg    : STD_LOGIC := '0';

BEGIN

  o_out_mach   <= s_reg_mach   WHEN i_channel_active = '1' ELSE (OTHERS => '0');
  o_out_alt    <= s_reg_alt    WHEN i_channel_active = '1' ELSE (OTHERS => '0');
  o_out_airspd <= s_reg_airspd WHEN i_channel_active = '1' ELSE (OTHERS => '0');
  o_out_vspd   <= s_reg_vspd   WHEN i_channel_active = '1' ELSE (OTHERS => '0');
  o_out_wing   <= s_reg_wing   WHEN i_channel_active = '1' ELSE (OTHERS => '0');
  o_out_flap   <= s_reg_flap   WHEN i_channel_active = '1' ELSE (OTHERS => '0');
  o_out_glove  <= s_reg_glove  WHEN i_channel_active = '1' ELSE (OTHERS => '0');
  o_out_bit_status <= s_reg_bit WHEN i_channel_active = '1' ELSE '0';

  o_io_data_out <= s_latched_data;
  o_io_ready    <= s_ready_reg;
  o_fail_detect <= '0';

  main_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_reg_mach     <= (OTHERS => '0');
        s_reg_alt      <= (OTHERS => '0');
        s_reg_airspd   <= (OTHERS => '0');
        s_reg_vspd     <= (OTHERS => '0');
        s_reg_wing     <= (OTHERS => '0');
        s_reg_flap     <= (OTHERS => '0');
        s_reg_glove    <= (OTHERS => '0');
        s_reg_bit      <= '0';
        s_latched_data <= (OTHERS => '0');
        s_ready_reg    <= '0';
      ELSE
        s_ready_reg <= '0';
        CASE i_io_ctrl IS
          WHEN c_io_nop =>
            NULL;
          WHEN c_io_read_ps =>
            s_latched_data <= i_sensor_ps;
            s_ready_reg    <= '1';
          WHEN c_io_read_qc =>
            s_latched_data <= i_sensor_qc;
            s_ready_reg    <= '1';
          WHEN c_io_read_tat =>
            s_latched_data <= i_sensor_tat;
            s_ready_reg    <= '1';
          WHEN c_io_read_analog =>
            s_latched_data <= i_sensor_analog;
            s_ready_reg    <= '1';
          WHEN c_io_read_digital =>
            s_latched_data <= i_sensor_digital;
            s_ready_reg    <= '1';
          WHEN c_io_write_mach =>
            s_reg_mach  <= i_io_data_in;
            s_ready_reg <= '1';
          WHEN c_io_write_alt =>
            s_reg_alt   <= i_io_data_in;
            s_ready_reg <= '1';
          WHEN c_io_write_airspd =>
            s_reg_airspd <= i_io_data_in;
            s_ready_reg  <= '1';
          WHEN c_io_write_vspd =>
            s_reg_vspd  <= i_io_data_in;
            s_ready_reg <= '1';
          WHEN c_io_write_wing =>
            s_reg_wing  <= i_io_data_in;
            s_ready_reg <= '1';
          WHEN c_io_write_flap =>
            s_reg_flap  <= i_io_data_in;
            s_ready_reg <= '1';
          WHEN c_io_write_glove =>
            s_reg_glove <= i_io_data_in;
            s_ready_reg <= '1';
          WHEN c_io_write_bit =>
            s_reg_bit   <= i_io_data_in(0);
            s_ready_reg <= '1';
          WHEN OTHERS =>
            NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS main_proc;

END ARCHITECTURE rtl;
'''
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_cadc_top():
    path = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\hdl\cadc_top.vhd"
    content = '''-------------------------------------------------------------------------------
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

  TYPE t_data_rom IS ARRAY(0 TO 511) OF STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_data_rom : t_data_rom := (OTHERS => (OTHERS => '0'));

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
'''
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print(f"Fixed: {path}")

if __name__ == "__main__":
    fix_control_rom_sequencer()
    fix_io_bridge()
    fix_cadc_top()
    print("Done with second batch!")

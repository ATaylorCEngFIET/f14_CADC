-------------------------------------------------------------------------------
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

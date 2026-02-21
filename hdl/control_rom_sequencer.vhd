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

  ---------------------------------------------------------------------------
  -- Polynomial Microprogram: E = a3*X^3 + a2*X^2 + a1*X + a0
  -- Implements Horner's method: E = ((a3*X + a2)*X + a1)*X + a0
  -- Using sensor_ps as input X, writing result to MACH output
  --
  -- Microword format (48 bits):
  --   [47:40] NEXTCTL  - Next address control (00=SEQ, 01=JMP, 07=WAIT_PMU)
  --   [39:32] NEXTADR  - Branch target / Data ROM address
  --   [31:28] ALU_OP   - ALU operation (D=LOAD, E=STORE_TMP, 1=ADD)
  --   [27]    acc_wr   - Accumulator write enable
  --   [26]    tmp_wr   - TMP register write enable
  --   [25]    flags_wr - Flags write enable
  --   [23]    ras_wr   - RAS write enable
  --   [22:20] ras_addr - RAS address (3 bits)
  --   [18:16] sel_acc  - ACC source (0=RAS,1=PMU,2=PDU_Q,4=IO,5=CONST,6=TMP,7=ACC)
  --   [15:14] sel_ras  - RAS source (0=ACC, 1=PMU, 2=PDU_Q, 3=IO)
  --   [13:12] sel_io   - IO source (0=ACC, 1=RAS, 2=PMU, 3=PDU_Q)
  --   [11]    pmu_start- Start PMU multiplication
  --   [7]     pdu_start- Start PDU division
  --   [3:0]   io_ctrl  - I/O control (1=READ_PS, 6=WRITE_MACH)
  --
  -- Data ROM addresses:
  --   0: a3 coefficient (0x10000 = 0.125)
  --   1: a2 coefficient (0x20000 = 0.25)
  --   2: a1 coefficient (0x30000 = 0.375)
  --   3: a0 constant    (0x08000 = 0.0625)
  ---------------------------------------------------------------------------
  SIGNAL s_ctrl_rom : t_ctrl_rom := (
    -- Addr 0: Issue IO read for sensor Ps (latch data)
    --         io_ctrl=1(READ_PS), no ACC write yet
    0  => x"000000000001",

    -- Addr 1: Load latched IO data (X) into ACC
    --         sel_acc=4(IO), ALU=D(LOAD), acc_wr=1, io_ctrl=0(NOP)
    1  => x"0000D8040000",

    -- Addr 2: Copy ACC (X) to TMP for PMU operand B
    --         sel_acc=7(ACC), ALU=E(STORE_TMP), tmp_wr=1
    --         Bits: ALU=E, tmp_wr=1 -> [31:24]=E4, sel_acc=7 -> [18:16]=111
    2  => x"0000E4070000",

    -- Addr 3: Store X in RAS[0] for later use
    --         ras_addr=0, ras_wr=1, sel_ras=0(ACC)
    3  => x"000000800000",

    -- Addr 4: Load a3 coefficient from Data ROM[0] into ACC
    --         NEXTADR=0 (data addr), sel_acc=5(CONST), ALU=D(LOAD), acc_wr=1
    4  => x"0000D8050000",

    -- Addr 5: Start PMU: a3 * X (ACC * TMP)
    --         pmu_start=1
    5  => x"000000000800",

    -- Addr 6: Wait for PMU completion
    --         NEXTCTL=07(WAIT_PMU)
    6  => x"070000000000",

    -- Addr 7: Load PMU result (a3*X) into ACC
    --         sel_acc=1(PMU), ALU=D(LOAD), acc_wr=1
    7  => x"0000D8010000",

    -- Addr 8: Load a2 from Data ROM[1], store to TMP
    --         NEXTADR=1, sel_acc=5(CONST), ALU=E(STORE_TMP), tmp_wr=1
    8  => x"0001E4050000",

    -- Addr 9: Add: ACC = (a3*X) + a2
    --         sel_acc=6(TMP), ALU=1(ADD), acc_wr=1
    9  => x"000018060000",

    -- Addr 10: Copy X from RAS[0] to TMP for next multiply
    --          sel_acc=0(RAS), ALU=E(STORE_TMP), tmp_wr=1, ras_addr=0
    10 => x"0000E4000000",

    -- Addr 11: Start PMU: (a3*X + a2) * X
    --          pmu_start=1
    11 => x"000000000800",

    -- Addr 12: Wait for PMU
    --          NEXTCTL=07(WAIT_PMU)
    12 => x"070000000000",

    -- Addr 13: Load PMU result into ACC
    --          sel_acc=1(PMU), ALU=D(LOAD), acc_wr=1
    13 => x"0000D8010000",

    -- Addr 14: Load a1 from Data ROM[2], store to TMP
    --          NEXTADR=2, sel_acc=5(CONST), ALU=E(STORE_TMP), tmp_wr=1
    14 => x"0002E4050000",

    -- Addr 15: Add: ACC = ((a3*X + a2)*X) + a1
    --          sel_acc=6(TMP), ALU=1(ADD), acc_wr=1
    15 => x"000018060000",

    -- Addr 16: Copy X from RAS[0] to TMP for next multiply
    --          sel_acc=0(RAS), ALU=E(STORE_TMP), tmp_wr=1, ras_addr=0
    16 => x"0000E4000000",

    -- Addr 17: Start PMU: ((a3*X + a2)*X + a1) * X
    --          pmu_start=1
    17 => x"000000000800",

    -- Addr 18: Wait for PMU
    --          NEXTCTL=07(WAIT_PMU)
    18 => x"070000000000",

    -- Addr 19: Load PMU result into ACC
    --          sel_acc=1(PMU), ALU=D(LOAD), acc_wr=1
    19 => x"0000D8010000",

    -- Addr 20: Load a0 from Data ROM[3], store to TMP
    --          NEXTADR=3, sel_acc=5(CONST), ALU=E(STORE_TMP), tmp_wr=1
    20 => x"0003E4050000",

    -- Addr 21: Add: ACC = (((a3*X + a2)*X + a1)*X) + a0 = Final result E
    --          sel_acc=6(TMP), ALU=1(ADD), acc_wr=1
    21 => x"000018060000",

    -- Addr 22: Store result in RAS[1] for reference
    --          ras_addr=1, ras_wr=1, sel_ras=0(ACC)
    22 => x"000000900000",

    -- Addr 23: Write result to MACH output
    --          io_ctrl=6(WRITE_MACH), sel_io=0(ACC)
    23 => x"000000000006",

    -- Addr 24: Halt (jump to self)
    --          NEXTCTL=01(JUMP), NEXTADR=24
    24 => x"011800000000",

    -- Remaining addresses: NOP
    OTHERS => (OTHERS => '0')
  );

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

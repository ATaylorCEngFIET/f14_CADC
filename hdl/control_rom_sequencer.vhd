-------------------------------------------------------------------------------
-- Control ROM + Sequencer
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial)
--
-- Micro-programmed sequencer with 1024-deep control ROM.
-- Outputs serial control word during WA phase for all modules.
-- PC advances at start of each operation (WA T0).
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
    -- Timing inputs
    i_phi2           : IN  STD_LOGIC;
    i_word_type      : IN  STD_LOGIC;  -- '0'=WA, '1'=WO
    i_t0             : IN  STD_LOGIC;
    i_t19            : IN  STD_LOGIC;
    -- Flag inputs
    i_flag_z         : IN  STD_LOGIC;
    i_flag_n         : IN  STD_LOGIC;
    i_flag_c         : IN  STD_LOGIC;
    i_pmu_busy       : IN  STD_LOGIC;
    i_pdu_busy       : IN  STD_LOGIC;
    i_frame_mark     : IN  STD_LOGIC;
    -- Serial control word output (during WA)
    o_cw_bit         : OUT STD_LOGIC;   -- Serial control word 
    -- Data ROM interface
    o_const_bit      : OUT STD_LOGIC;   -- Serial constant output (during WO)
    -- Debug outputs
    o_micro_addr     : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    o_micro_word     : OUT STD_LOGIC_VECTOR(g_uword_width-1 DOWNTO 0)
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
  -- Polynomial Microprogram for E = a3*X^3 + a2*X^2 + a1*X + a0
  -- Using Horner's method: E = ((a3*X + a2)*X + a1)*X + a0
  --
  -- Microword Bit Layout:
  --   bits 0-3:   SLF ALU_OP (serial) / IO control (parallel) - SHARED!
  --   bit 4:      acc_we (serial)
  --   bit 5:      tmp_we (serial)
  --   bit 6:      flags_we (serial)
  --   bits 7-10:  SL ACC source (parallel)
  --   bits 11-14: SL RAS source (parallel)
  --   bits 15-17: SL IO source (parallel)
  --   bits 18-23: RAS read address (parallel)
  --   bits 24-29: RAS write address (parallel)
  --   bit 30:     RAS write enable (parallel)
  --   bits 32-35: Data ROM address (parallel)
  --   bits 40-47: Sequencer nextctl (parallel)
  --
  -- ALU_OP: 0=NOP,1=ADD,2=SUB,0xD=LOAD,0xE=STORE_TMP,0xF=PASS
  -- ACC_SRC (bits 10-7): 0=RAS,1=PMU,2=PDUQ,3=PDUR,4=IO,5=CONST,6=TMP,7=ACC
  -- IO_CTRL: 0=NOP,1=read_ps,2=read_qc,6=write_mach,...
  --
  -- PIPELINE NOTE: ACC_SRC routes data during WO_N, ALU uses it during WA_(N+1)
  -- So to "LOAD source to ACC": inst N sets ACC_SRC=source, inst N+1 does LOAD+acc_we
  ---------------------------------------------------------------------------
  SIGNAL s_ctrl_rom : t_ctrl_rom := (
    -- Inst 0: Route IO to SLF, setup I/O read
    -- ACC_SRC=IO(4)=0100 → bits 10-7: 0x200, io_ctrl=1 (read_ps)
    0  => x"000000000201",  -- ACC_SRC=IO, io_ctrl=read_ps
    
    -- Inst 1: LOAD (uses IO from WO0), route doesn't matter for next
    -- ALU=LOAD(D), acc_we=1 → 0x1D
    1  => x"00000000001D",  -- LOAD IO to ACC, ACC = X
    
    -- Inst 2: Copy ACC to TMP via tmp_we
    -- ALU=PASS(F), tmp_we=1, acc_we=0 → PASS doesn't write ACC when acc_we=1
    -- Actually just tmp_we=1, ALU=NOP → bit5=1 = 0x20
    2  => x"000000000020",  -- tmp_we=1, TMP = X
    
    -- Inst 3: Route CONST[0]=a3 to SLF for inst 4
    -- ACC_SRC=CONST(5)=0101 → bits 10-7: 0x280, data_addr=0
    3  => x"000000000280",  -- ACC_SRC=CONST, data_addr=0
    
    -- Inst 4: LOAD (uses a3 from WO3), ACC=a3
    -- After WA4 T18: ACC=a3, s_acc_out_sr=a3, s_tmp_out_sr=X
    -- During WO4: PMU receives (a3, X)
    -- At WO4 T19: PMU latches, then starts computing at WA5 T0
    4  => x"00000000001D",  -- LOAD to ACC, ACC = a3
    
    -- Inst 5: Route PMU to SLF (for inst 6), wait for PMU result
    -- ACC_SRC=PMU(1)=0001 → bits 10-7: 0x80, nextctl=WAIT_PMU(07)
    5  => x"070000000080",  -- ACC_SRC=PMU, WAIT_PMU
    
    -- Inst 6: LOAD PMU (uses a3*X from WO5), route CONST[1]=a2 for inst 7
    -- ACC_SRC=CONST(5), data_addr=1, ALU=LOAD, acc_we=1
    6  => x"00010000029D",  -- LOAD PMU to ACC (=a3*X), route a2
    
    -- Inst 7: ADD (uses a2 from WO6), ACC = a3*X + a2
    -- After WA7: ACC = a3*X + a2
    -- During WO7: PMU receives (a3*X+a2, X)
    7  => x"000000000011",  -- ADD, acc_we=1, ACC = a3*X + a2
    
    -- Inst 8: Route PMU, wait for PMU
    8  => x"070000000080",  -- ACC_SRC=PMU, WAIT_PMU
    
    -- Inst 9: LOAD PMU, route CONST[2]=a1
    -- ACC = (a3*X + a2)*X
    9  => x"00020000029D",  -- LOAD PMU, route a1
    
    -- Inst 10: ADD a1
    -- ACC = (a3*X + a2)*X + a1
    10 => x"000000000011",  -- ADD, acc_we=1
    
    -- Inst 11: Route PMU, wait
    11 => x"070000000080",  -- ACC_SRC=PMU, WAIT_PMU
    
    -- Inst 12: LOAD PMU, route CONST[3]=a0
    -- ACC = ((a3*X + a2)*X + a1)*X
    12 => x"00030000029D",  -- LOAD PMU, route a0
    
    -- Inst 13: ADD a0, final result
    -- ACC = E = ((a3*X + a2)*X + a1)*X + a0
    13 => x"000000000011",  -- ADD, acc_we=1, ACC = E
    
    -- Inst 14: NOP - ACC data shifts out, io_sel=0 routes ACC in io_mux
    14 => x"000000000000",  -- NOP, io_sel=0=ACC
    
    -- Inst 15: NOP - keep ACC routing for one more cycle  
    15 => x"000000000000",  -- NOP, io_sel=0=ACC
    
    -- Inst 16: Output to MACH - captures data from WO15
    -- io_sel=0=ACC for this WO, io_ctrl=write_mach triggers capture
    16 => x"000000000006",  -- io_sel=0=ACC, io_ctrl=write_mach
    
    -- Inst 17: Halt
    17 => x"011100000000",  -- JUMP to 17
    
    OTHERS => (OTHERS => '0')
  );

  -- Data ROM for constants (20-bit values)
  TYPE t_data_rom IS ARRAY(0 TO 15) OF STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_data_rom : t_data_rom := (
    0 => x"10000",  -- a3 = 0.125
    1 => x"20000",  -- a2 = 0.25
    2 => x"30000",  -- a1 = 0.375
    3 => x"08000",  -- a0 = 0.0625
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

  -- Shift registers for serial output
  SIGNAL s_cw_sr    : STD_LOGIC_VECTOR(g_uword_width-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_const_sr : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_data_addr: UNSIGNED(3 DOWNTO 0) := (OTHERS => '0');

BEGIN

  s_current_uword <= s_ctrl_rom(TO_INTEGER(s_micro_pc));
  o_micro_word    <= s_current_uword;
  o_micro_addr    <= STD_LOGIC_VECTOR(s_micro_pc);

  s_nextctl_field <= UNSIGNED(s_current_uword(47 DOWNTO 40));
  s_nextadr_field <= UNSIGNED(s_current_uword(39 DOWNTO 32));

  -- CW output: T0 outputs bit 0, T1+ outputs bit 1 for same-edge timing
  o_cw_bit    <= s_cw_sr(0) WHEN i_t0 = '1' ELSE s_cw_sr(1);
  -- Constant output: same timing compensation
  o_const_bit <= s_const_sr(0) WHEN i_t0 = '1' ELSE s_const_sr(1);

  -----------------------------------------------------------------------------
  -- Control word shift process
  -- Pre-load CW at end of WO (T19) so it's ready for next WA T0
  -- This avoids timing race where SLF samples before CW is loaded
  -----------------------------------------------------------------------------
  cw_shift_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_cw_sr    <= s_ctrl_rom(0);  -- Pre-load first instruction
        s_const_sr <= (OTHERS => '0');
        s_data_addr<= (OTHERS => '0');
      ELSIF i_phi2 = '1' THEN
        IF i_word_type = '0' THEN
          -- WA phase: shift out (CW was pre-loaded at previous WO T19)
          IF i_t0 = '1' THEN
            -- Latch data address for constant output
            s_data_addr <= UNSIGNED(s_current_uword(35 DOWNTO 32));
          ELSIF i_t19 = '1' THEN
            -- Pre-load constant at end of WA (ready for WO T0)
            s_const_sr <= s_data_rom(TO_INTEGER(UNSIGNED(s_current_uword(35 DOWNTO 32))));
          ELSE
            -- Shift out during WA
            s_cw_sr <= '0' & s_cw_sr(g_uword_width-1 DOWNTO 1);
          END IF;
        ELSE
          -- WO phase
          IF i_t0 = '0' AND i_t19 = '0' THEN
            -- Shift out constant during WO T1-T18
            s_const_sr <= '0' & s_const_sr(19 DOWNTO 1);
          ELSIF i_t19 = '1' THEN
            -- Pre-load NEXT instruction's CW at end of WO
            -- (PC will update to s_next_pc on this same edge)
            s_cw_sr <= s_ctrl_rom(TO_INTEGER(s_next_pc));
          END IF;
        END IF;
      END IF;
    END IF;
  END PROCESS cw_shift_proc;

  -----------------------------------------------------------------------------
  -- Next PC computation
  -----------------------------------------------------------------------------
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

  -----------------------------------------------------------------------------
  -- PC update process - advance at end of WO (completion of operation)
  -----------------------------------------------------------------------------
  pc_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_micro_pc  <= (OTHERS => '0');
        s_stack_ptr <= (OTHERS => '0');
        s_ret_stack <= (OTHERS => (OTHERS => '0'));
      ELSIF i_phi2 = '1' AND i_word_type = '1' AND i_t19 = '1' THEN
        -- Advance PC at end of WO
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

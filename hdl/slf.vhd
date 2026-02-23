-------------------------------------------------------------------------------
-- SLF - Special Logic Function / ALU Core (PN 944113)
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial I/O)
--
-- Main ALU with 16 operations. Serial data I/O with parallel internal computation.
-- Timing:
--   WO: Data shifts in serially (20 bits), result shifts out
--   WA T0-T6: Control word bits received
--   WA T8: ALU computes using latched control
--   WA T18: Registers updated, result loaded to output SR
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY slf IS
  PORT (
    i_clk            : IN  STD_LOGIC;
    i_rst            : IN  STD_LOGIC;
    i_phi2           : IN  STD_LOGIC;
    i_word_type      : IN  STD_LOGIC;
    i_t0             : IN  STD_LOGIC;
    i_t18            : IN  STD_LOGIC;
    i_t19            : IN  STD_LOGIC;
    i_cw_bit         : IN  STD_LOGIC;
    i_data_bit       : IN  STD_LOGIC;
    o_result_bit     : OUT STD_LOGIC;
    o_acc_bit        : OUT STD_LOGIC;
    o_tmp_bit        : OUT STD_LOGIC;
    o_flag_z         : OUT STD_LOGIC;
    o_flag_n         : OUT STD_LOGIC;
    o_flag_c         : OUT STD_LOGIC
  );
END ENTITY slf;

ARCHITECTURE rtl OF slf IS

  CONSTANT c_op_nop       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
  CONSTANT c_op_add       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0001";
  CONSTANT c_op_sub       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0010";
  CONSTANT c_op_and       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0011";
  CONSTANT c_op_or        : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0100";
  CONSTANT c_op_xor       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0101";
  CONSTANT c_op_not       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0110";
  CONSTANT c_op_shl       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0111";
  CONSTANT c_op_shr       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1000";
  CONSTANT c_op_neg       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1001";
  CONSTANT c_op_abs       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1010";
  CONSTANT c_op_gray2bin  : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1011";
  CONSTANT c_op_bin2gray  : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1100";
  CONSTANT c_op_load      : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1101";
  CONSTANT c_op_store_tmp : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1110";
  CONSTANT c_op_pass      : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1111";

  SIGNAL s_input_sr    : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_acc_reg     : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_tmp_reg     : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_result_sr   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_acc_out_sr  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_tmp_out_sr  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');  -- TMP serial output
  SIGNAL s_input_lat   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_cw_sr       : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_alu_op_lat  : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_acc_we_lat  : STD_LOGIC := '0';
  SIGNAL s_tmp_we_lat  : STD_LOGIC := '0';
  SIGNAL s_flags_we_lat: STD_LOGIC := '0';
  SIGNAL s_cw_bit_cnt  : UNSIGNED(4 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_alu_result  : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_carry_out   : STD_LOGIC := '0';
  SIGNAL s_z_reg       : STD_LOGIC := '0';
  SIGNAL s_n_reg       : STD_LOGIC := '0';
  SIGNAL s_c_reg       : STD_LOGIC := '0';
  SIGNAL s_compute_done: STD_LOGIC := '0';

BEGIN

  -- Serial outputs: T0 outputs bit(0), T1+ outputs bit(1) for same-edge timing
  o_result_bit <= s_result_sr(0) WHEN i_t0 = '1' ELSE s_result_sr(1);
  o_acc_bit    <= s_acc_out_sr(0) WHEN i_t0 = '1' ELSE s_acc_out_sr(1);
  o_tmp_bit    <= s_tmp_out_sr(0) WHEN i_t0 = '1' ELSE s_tmp_out_sr(1);
  o_flag_z     <= s_z_reg;
  o_flag_n     <= s_n_reg;
  o_flag_c     <= s_c_reg;

  -----------------------------------------------------------------------------
  -- Control word reception - receive 7 bits during WA T0-T6
  -- Format: bit 0-3 = ALU_OP, bit 4 = acc_we, bit 5 = tmp_we, bit 6 = flags_we
  -- Bits arrive LSB first, so bit 0 arrives at T0, bit 6 at T6
  -- Use bit_cnt directly to index where to store each received bit
  -----------------------------------------------------------------------------
  cw_proc: PROCESS(i_clk)
    VARIABLE v_cnt : INTEGER RANGE 0 TO 19;
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_cw_sr <= (OTHERS => '0');
        s_alu_op_lat <= (OTHERS => '0');
        s_acc_we_lat <= '0';
        s_tmp_we_lat <= '0';
        s_flags_we_lat <= '0';
        s_cw_bit_cnt <= (OTHERS => '0');
      ELSIF i_phi2 = '1' AND i_word_type = '0' THEN
        -- Use variable for immediate reset
        IF i_t0 = '1' THEN
          v_cnt := 0;
          s_cw_sr <= (OTHERS => '0');
        ELSE
          v_cnt := TO_INTEGER(s_cw_bit_cnt);
        END IF;
        
        -- Capture CW bits at their index positions
        IF v_cnt < 7 THEN
          CASE v_cnt IS
            WHEN 0 => s_cw_sr(0) <= i_cw_bit;
            WHEN 1 => s_cw_sr(1) <= i_cw_bit;
            WHEN 2 => s_cw_sr(2) <= i_cw_bit;
            WHEN 3 => s_cw_sr(3) <= i_cw_bit;
            WHEN 4 => s_cw_sr(4) <= i_cw_bit;
            WHEN 5 => s_cw_sr(5) <= i_cw_bit;
            WHEN 6 => s_cw_sr(6) <= i_cw_bit;
            WHEN OTHERS => NULL;
          END CASE;
        END IF;
        
        -- At T7 (v_cnt+1 = 7 means v_cnt = 6 but then incremented, so check after increment)
        -- Actually latch when v_cnt=6 just before it becomes 7
        -- Or better: latch at v_cnt=7 which is T7 entry
        -- Since we SET v_cnt at T0 to 0, at T7 we have v_cnt=7
        IF v_cnt = 7 THEN
          s_alu_op_lat   <= s_cw_sr(3 DOWNTO 0);
          s_acc_we_lat   <= s_cw_sr(4);
          s_tmp_we_lat   <= s_cw_sr(5);
          s_flags_we_lat <= s_cw_sr(6);
        END IF;
        
        -- Update signal for next cycle
        IF v_cnt < 19 THEN
          s_cw_bit_cnt <= TO_UNSIGNED(v_cnt + 1, 5);
        ELSE
          s_cw_bit_cnt <= TO_UNSIGNED(v_cnt, 5);
        END IF;
      END IF;
    END IF;
  END PROCESS cw_proc;

  -----------------------------------------------------------------------------
  -- Serial shift process - shift on phi2 during WO (following PMU pattern)
  -----------------------------------------------------------------------------
  shift_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_input_sr   <= (OTHERS => '0');
        s_result_sr  <= (OTHERS => '0');
        s_acc_out_sr <= (OTHERS => '0');
        s_tmp_out_sr <= (OTHERS => '0');
        s_input_lat  <= (OTHERS => '0');
      ELSIF i_phi2 = '1' AND i_word_type = '1' THEN
        -- WO: Shift in data (LSB first)
        s_input_sr   <= i_data_bit & s_input_sr(19 DOWNTO 1);
        -- Output shift registers: skip shift at T0 to maintain alignment
        IF i_t0 = '0' THEN
          s_result_sr  <= '0' & s_result_sr(19 DOWNTO 1);
          s_acc_out_sr <= '0' & s_acc_out_sr(19 DOWNTO 1);
          s_tmp_out_sr <= '0' & s_tmp_out_sr(19 DOWNTO 1);
        END IF;
        -- At end of WO (T19), latch input for next computation
        IF i_t19 = '1' THEN
          s_input_lat <= i_data_bit & s_input_sr(19 DOWNTO 1);
        END IF;
      ELSIF s_compute_done = '1' THEN
        -- Load computed result into output shift registers
        s_result_sr  <= s_alu_result;
        s_acc_out_sr <= s_acc_reg;
        s_tmp_out_sr <= s_tmp_reg;  -- Load TMP for serial output
      END IF;
    END IF;
  END PROCESS shift_proc;

  -----------------------------------------------------------------------------
  -- ALU computation - compute at T8 (after CW latched), update regs at T18
  -----------------------------------------------------------------------------
  alu_proc: PROCESS(i_clk)
    VARIABLE v_sum     : UNSIGNED(20 DOWNTO 0);
    VARIABLE v_gray2b  : STD_LOGIC_VECTOR(19 DOWNTO 0);
    VARIABLE v_bin2g   : STD_LOGIC_VECTOR(19 DOWNTO 0);
    VARIABLE v_neg_val : SIGNED(19 DOWNTO 0);
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_acc_reg      <= (OTHERS => '0');
        s_tmp_reg      <= (OTHERS => '0');
        s_alu_result   <= (OTHERS => '0');
        s_carry_out    <= '0';
        s_z_reg        <= '0';
        s_n_reg        <= '0';
        s_c_reg        <= '0';
        s_compute_done <= '0';
      ELSE
        s_compute_done <= '0';
        -- Compute at T8 (after CW bits 0-6 received and latched at T7)
        IF i_word_type = '0' AND s_cw_bit_cnt = 8 AND i_phi2 = '1' THEN
          s_carry_out <= '0';
          CASE s_alu_op_lat IS
            WHEN c_op_nop =>
              s_alu_result <= s_acc_reg;
            WHEN c_op_add =>
              v_sum := ('0' & UNSIGNED(s_acc_reg)) + ('0' & UNSIGNED(s_input_lat));
              s_alu_result <= STD_LOGIC_VECTOR(v_sum(19 DOWNTO 0));
              s_carry_out  <= v_sum(20);
            WHEN c_op_sub =>
              v_sum := ('0' & UNSIGNED(s_acc_reg)) - ('0' & UNSIGNED(s_input_lat));
              s_alu_result <= STD_LOGIC_VECTOR(v_sum(19 DOWNTO 0));
              s_carry_out  <= v_sum(20);
            WHEN c_op_and =>
              s_alu_result <= s_acc_reg AND s_input_lat;
            WHEN c_op_or =>
              s_alu_result <= s_acc_reg OR s_input_lat;
            WHEN c_op_xor =>
              s_alu_result <= s_acc_reg XOR s_input_lat;
            WHEN c_op_not =>
              s_alu_result <= NOT s_acc_reg;
            WHEN c_op_shl =>
              s_alu_result <= s_acc_reg(19) & s_acc_reg(17 DOWNTO 0) & '0';
            WHEN c_op_shr =>
              s_alu_result <= s_acc_reg(19) & s_acc_reg(19 DOWNTO 1);
            WHEN c_op_neg =>
              v_neg_val := -SIGNED(s_acc_reg);
              s_alu_result <= STD_LOGIC_VECTOR(v_neg_val);
            WHEN c_op_abs =>
              IF SIGNED(s_acc_reg) < 0 THEN
                IF s_acc_reg = x"80000" THEN
                  s_alu_result <= x"7FFFF";
                ELSE
                  s_alu_result <= STD_LOGIC_VECTOR(-SIGNED(s_acc_reg));
                END IF;
              ELSE
                s_alu_result <= s_acc_reg;
              END IF;
            WHEN c_op_gray2bin =>
              v_gray2b(19) := s_input_lat(19);
              FOR i IN 18 DOWNTO 0 LOOP
                v_gray2b(i) := v_gray2b(i+1) XOR s_input_lat(i);
              END LOOP;
              s_alu_result <= v_gray2b;
            WHEN c_op_bin2gray =>
              v_bin2g(19) := s_acc_reg(19);
              FOR i IN 18 DOWNTO 0 LOOP
                v_bin2g(i) := s_acc_reg(i+1) XOR s_acc_reg(i);
              END LOOP;
              s_alu_result <= v_bin2g;
            WHEN c_op_load =>
              s_alu_result <= s_input_lat;
            WHEN c_op_store_tmp =>
              s_alu_result <= s_acc_reg;
            WHEN c_op_pass =>
              s_alu_result <= s_input_lat;
            WHEN OTHERS =>
              s_alu_result <= s_acc_reg;
          END CASE;
        END IF;
        -- At T18, update registers and signal compute done
        IF i_word_type = '0' AND i_t18 = '1' AND i_phi2 = '1' THEN
          IF s_acc_we_lat = '1' AND s_alu_op_lat /= c_op_pass THEN
            s_acc_reg <= s_alu_result;
          END IF;
          IF s_tmp_we_lat = '1' THEN
            s_tmp_reg <= s_acc_reg;
          END IF;
          IF s_flags_we_lat = '1' THEN
            IF s_alu_result = x"00000" THEN
              s_z_reg <= '1';
            ELSE
              s_z_reg <= '0';
            END IF;
            s_n_reg <= s_alu_result(19);
            s_c_reg <= s_carry_out;
          END IF;
          s_compute_done <= '1';
        END IF;
      END IF;
    END IF;
  END PROCESS alu_proc;

END ARCHITECTURE rtl;

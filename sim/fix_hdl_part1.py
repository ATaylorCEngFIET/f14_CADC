#!/usr/bin/env python3
"""Fix HDL files to comply with coding standards."""

import os

def fix_timing_generator():
    path = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\hdl\timing_generator.vhd"
    content = '''-------------------------------------------------------------------------------
-- Timing Generator
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Generates the CADC timing hierarchy from the master clock:
--   5 MHz master -> 375 kHz phase clocks (phi1, phi2 non-overlapping)
--   20 bit times per word, alternating WA/WO, 512 OPs per frame
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY timing_generator IS
  GENERIC (
    g_clk_div : NATURAL := 1
  );
  PORT (
    i_clk_master : IN  STD_LOGIC;
    i_rst        : IN  STD_LOGIC;
    o_phi1       : OUT STD_LOGIC;
    o_phi2       : OUT STD_LOGIC;
    o_bit_count  : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    o_word_type  : OUT STD_LOGIC;
    o_word_mark  : OUT STD_LOGIC;
    o_op_count   : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    o_frame_mark : OUT STD_LOGIC
  );
END ENTITY timing_generator;

ARCHITECTURE rtl OF timing_generator IS

  SIGNAL s_div_cnt   : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_tick      : STD_LOGIC;
  SIGNAL s_bit_cnt   : UNSIGNED(4 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_word_sel  : STD_LOGIC := '0';
  SIGNAL s_op_cnt    : UNSIGNED(9 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_phi1_reg  : STD_LOGIC := '0';
  SIGNAL s_phi2_reg  : STD_LOGIC := '0';

BEGIN

  gen_div1: IF g_clk_div = 1 GENERATE
    s_tick <= '1';
  END GENERATE;

  gen_divN: IF g_clk_div > 1 GENERATE
    div_proc: PROCESS(i_clk_master)
    BEGIN
      IF RISING_EDGE(i_clk_master) THEN
        IF i_rst = '1' THEN
          s_div_cnt <= (OTHERS => '0');
        ELSIF s_div_cnt = g_clk_div - 1 THEN
          s_div_cnt <= (OTHERS => '0');
        ELSE
          s_div_cnt <= s_div_cnt + 1;
        END IF;
      END IF;
    END PROCESS div_proc;
    s_tick <= '1' WHEN s_div_cnt = 0 ELSE '0';
  END GENERATE;

  timing_proc: PROCESS(i_clk_master)
  BEGIN
    IF RISING_EDGE(i_clk_master) THEN
      IF i_rst = '1' THEN
        s_bit_cnt  <= (OTHERS => '0');
        s_word_sel <= '0';
        s_op_cnt   <= (OTHERS => '0');
        s_phi1_reg <= '0';
        s_phi2_reg <= '0';
      ELSIF s_tick = '1' THEN
        s_phi1_reg <= NOT s_phi1_reg;
        s_phi2_reg <= s_phi1_reg;

        IF s_bit_cnt = 19 THEN
          s_bit_cnt <= (OTHERS => '0');
          IF s_word_sel = '1' THEN
            s_word_sel <= '0';
            IF s_op_cnt = 511 THEN
              s_op_cnt <= (OTHERS => '0');
            ELSE
              s_op_cnt <= s_op_cnt + 1;
            END IF;
          ELSE
            s_word_sel <= '1';
          END IF;
        ELSE
          s_bit_cnt <= s_bit_cnt + 1;
        END IF;
      END IF;
    END IF;
  END PROCESS timing_proc;

  o_phi1       <= s_phi1_reg;
  o_phi2       <= s_phi2_reg;
  o_bit_count  <= STD_LOGIC_VECTOR(s_bit_cnt);
  o_word_type  <= s_word_sel;
  o_op_count   <= STD_LOGIC_VECTOR(s_op_cnt);
  o_word_mark  <= '1' WHEN (s_bit_cnt = 18 AND s_tick = '1') ELSE '0';
  o_frame_mark <= '1' WHEN (s_bit_cnt = 19 AND s_word_sel = '1' AND
                            s_op_cnt = 511 AND s_tick = '1') ELSE '0';

END ARCHITECTURE rtl;
'''
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_pmu():
    path = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\hdl\pmu.vhd"
    content = '''-------------------------------------------------------------------------------
-- PMU - Parallel Multiplier Unit (PN 944111)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Implements 20x20-bit signed fractional multiplication using Booth's
-- algorithm. Returns the upper 20 bits of the 40-bit product with rounding.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pmu IS
  PORT (
    i_clk       : IN  STD_LOGIC;
    i_rst       : IN  STD_LOGIC;
    i_start     : IN  STD_LOGIC;
    i_operand_a : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_operand_b : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_result    : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_busy      : OUT STD_LOGIC;
    o_done      : OUT STD_LOGIC
  );
END ENTITY pmu;

ARCHITECTURE rtl OF pmu IS

  TYPE t_state IS (IDLE, COMPUTING, ROUNDING, FINISHED);
  SIGNAL s_state        : t_state;
  SIGNAL s_accumulator  : SIGNED(40 DOWNTO 0);
  SIGNAL s_multiplicand : SIGNED(40 DOWNTO 0);
  SIGNAL s_bit_cnt      : UNSIGNED(4 DOWNTO 0);
  SIGNAL s_prev_bit     : STD_LOGIC;
  SIGNAL s_result_reg   : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_busy         : STD_LOGIC;
  SIGNAL s_done         : STD_LOGIC;

BEGIN

  o_result <= s_result_reg;
  o_busy   <= s_busy;
  o_done   <= s_done;

  main_proc: PROCESS(i_clk)
    VARIABLE v_booth_pair : STD_LOGIC_VECTOR(1 DOWNTO 0);
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_state       <= IDLE;
        s_accumulator <= (OTHERS => '0');
        s_multiplicand<= (OTHERS => '0');
        s_bit_cnt     <= (OTHERS => '0');
        s_prev_bit    <= '0';
        s_result_reg  <= (OTHERS => '0');
        s_busy        <= '0';
        s_done        <= '0';
      ELSE
        s_done <= '0';
        CASE s_state IS
          WHEN IDLE =>
            IF i_start = '1' THEN
              s_multiplicand(40 DOWNTO 20) <= RESIZE(SIGNED(i_operand_a), 21);
              s_multiplicand(19 DOWNTO 0)  <= (OTHERS => '0');
              s_accumulator(40 DOWNTO 21)  <= (OTHERS => '0');
              s_accumulator(20 DOWNTO 1)   <= SIGNED(i_operand_b);
              s_accumulator(0)             <= '0';
              s_prev_bit <= '0';
              s_bit_cnt  <= (OTHERS => '0');
              s_busy     <= '1';
              s_state    <= COMPUTING;
            END IF;
          WHEN COMPUTING =>
            v_booth_pair := s_accumulator(1) & s_accumulator(0);
            CASE v_booth_pair IS
              WHEN "01" =>
                s_accumulator(40 DOWNTO 0) <=
                  SHIFT_RIGHT(s_accumulator + s_multiplicand, 1);
              WHEN "10" =>
                s_accumulator(40 DOWNTO 0) <=
                  SHIFT_RIGHT(s_accumulator - s_multiplicand, 1);
              WHEN OTHERS =>
                s_accumulator <= SHIFT_RIGHT(s_accumulator, 1);
            END CASE;
            IF s_bit_cnt = 19 THEN
              s_state <= ROUNDING;
            ELSE
              s_bit_cnt <= s_bit_cnt + 1;
            END IF;
          WHEN ROUNDING =>
            IF s_accumulator(20) = '1' THEN
              s_result_reg <= STD_LOGIC_VECTOR(s_accumulator(39 DOWNTO 20) + 1);
            ELSE
              s_result_reg <= STD_LOGIC_VECTOR(s_accumulator(39 DOWNTO 20));
            END IF;
            s_state <= FINISHED;
          WHEN FINISHED =>
            s_done  <= '1';
            s_busy  <= '0';
            s_state <= IDLE;
        END CASE;
      END IF;
    END IF;
  END PROCESS main_proc;

END ARCHITECTURE rtl;
'''
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_pdu():
    path = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\hdl\pdu.vhd"
    content = '''-------------------------------------------------------------------------------
-- PDU - Parallel Divider Unit (PN 944112)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Implements 20-bit signed fractional division using non-restoring
-- algorithm. Produces quotient and remainder. Detects divide-by-zero.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pdu IS
  PORT (
    i_clk         : IN  STD_LOGIC;
    i_rst         : IN  STD_LOGIC;
    i_start       : IN  STD_LOGIC;
    i_dividend    : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_divisor     : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_quotient    : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_remainder   : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_busy        : OUT STD_LOGIC;
    o_done        : OUT STD_LOGIC;
    o_div_by_zero : OUT STD_LOGIC
  );
END ENTITY pdu;

ARCHITECTURE rtl OF pdu IS

  TYPE t_state IS (IDLE, SETUP, DIVIDING, CORRECTION, FINISHED);
  SIGNAL s_state         : t_state;
  SIGNAL s_partial_rem   : SIGNED(20 DOWNTO 0);
  SIGNAL s_div_reg       : SIGNED(20 DOWNTO 0);
  SIGNAL s_quot_reg      : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_bit_cnt       : UNSIGNED(4 DOWNTO 0);
  SIGNAL s_dividend_neg  : STD_LOGIC;
  SIGNAL s_divisor_neg   : STD_LOGIC;
  SIGNAL s_abs_dividend  : UNSIGNED(19 DOWNTO 0);
  SIGNAL s_abs_divisor   : UNSIGNED(19 DOWNTO 0);
  SIGNAL s_quotient_reg  : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_remainder_reg : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_dbz_reg       : STD_LOGIC;
  SIGNAL s_busy          : STD_LOGIC;
  SIGNAL s_done          : STD_LOGIC;

BEGIN

  o_quotient    <= s_quotient_reg;
  o_remainder   <= s_remainder_reg;
  o_div_by_zero <= s_dbz_reg;
  o_busy        <= s_busy;
  o_done        <= s_done;

  main_proc: PROCESS(i_clk)
    VARIABLE v_new_rem : SIGNED(20 DOWNTO 0);
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_state         <= IDLE;
        s_partial_rem   <= (OTHERS => '0');
        s_div_reg       <= (OTHERS => '0');
        s_quot_reg      <= (OTHERS => '0');
        s_bit_cnt       <= (OTHERS => '0');
        s_quotient_reg  <= (OTHERS => '0');
        s_remainder_reg <= (OTHERS => '0');
        s_dbz_reg       <= '0';
        s_busy          <= '0';
        s_done          <= '0';
      ELSE
        s_done <= '0';
        CASE s_state IS
          WHEN IDLE =>
            IF i_start = '1' THEN
              IF SIGNED(i_divisor) = 0 THEN
                s_dbz_reg       <= '1';
                s_quotient_reg  <= (OTHERS => '0');
                s_remainder_reg <= (OTHERS => '0');
                s_done          <= '1';
              ELSE
                s_dbz_reg      <= '0';
                s_busy         <= '1';
                s_dividend_neg <= i_dividend(19);
                s_divisor_neg  <= i_divisor(19);
                IF SIGNED(i_dividend) < 0 THEN
                  s_abs_dividend <= UNSIGNED(-SIGNED(i_dividend));
                ELSE
                  s_abs_dividend <= UNSIGNED(i_dividend);
                END IF;
                IF SIGNED(i_divisor) < 0 THEN
                  s_abs_divisor <= UNSIGNED(-SIGNED(i_divisor));
                ELSE
                  s_abs_divisor <= UNSIGNED(i_divisor);
                END IF;
                s_state <= SETUP;
              END IF;
            END IF;
          WHEN SETUP =>
            s_partial_rem <= SIGNED('0' & STD_LOGIC_VECTOR(s_abs_dividend));
            s_div_reg     <= SIGNED('0' & STD_LOGIC_VECTOR(s_abs_divisor));
            s_quot_reg    <= (OTHERS => '0');
            s_bit_cnt     <= (OTHERS => '0');
            s_state       <= DIVIDING;
          WHEN DIVIDING =>
            IF s_partial_rem(20) = '0' THEN
              v_new_rem := SHIFT_LEFT(s_partial_rem, 1) - s_div_reg;
            ELSE
              v_new_rem := SHIFT_LEFT(s_partial_rem, 1) + s_div_reg;
            END IF;
            s_partial_rem <= v_new_rem;
            IF v_new_rem(20) = '0' THEN
              s_quot_reg <= s_quot_reg(18 DOWNTO 0) & '1';
            ELSE
              s_quot_reg <= s_quot_reg(18 DOWNTO 0) & '0';
            END IF;
            IF s_bit_cnt = 19 THEN
              s_state <= CORRECTION;
            ELSE
              s_bit_cnt <= s_bit_cnt + 1;
            END IF;
          WHEN CORRECTION =>
            IF s_partial_rem(20) = '1' THEN
              s_partial_rem <= s_partial_rem + s_div_reg;
            END IF;
            IF s_dividend_neg /= s_divisor_neg THEN
              s_quotient_reg <= STD_LOGIC_VECTOR(-SIGNED(s_quot_reg));
            ELSE
              s_quotient_reg <= s_quot_reg;
            END IF;
            IF s_dividend_neg = '1' THEN
              IF s_partial_rem(20) = '1' THEN
                s_remainder_reg <= STD_LOGIC_VECTOR(
                  -RESIZE(s_partial_rem(19 DOWNTO 0), 20));
              ELSE
                s_remainder_reg <= STD_LOGIC_VECTOR(
                  -s_partial_rem(19 DOWNTO 0));
              END IF;
            ELSE
              IF s_partial_rem(20) = '1' THEN
                s_remainder_reg <= STD_LOGIC_VECTOR(
                  RESIZE((s_partial_rem + s_div_reg), 21)(19 DOWNTO 0));
              ELSE
                s_remainder_reg <= STD_LOGIC_VECTOR(
                  s_partial_rem(19 DOWNTO 0));
              END IF;
            END IF;
            s_state <= FINISHED;
          WHEN FINISHED =>
            s_done  <= '1';
            s_busy  <= '0';
            s_state <= IDLE;
        END CASE;
      END IF;
    END IF;
  END PROCESS main_proc;

END ARCHITECTURE rtl;
'''
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_slf():
    path = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\hdl\slf.vhd"
    content = '''-------------------------------------------------------------------------------
-- SLF - Special Logic Function / ALU Core (PN 944113)
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- Main ALU with 16 operations including add, subtract, logic, shift,
-- negate, absolute value, Gray/Binary code conversion, and data movement.
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY slf IS
  PORT (
    i_clk            : IN  STD_LOGIC;
    i_rst            : IN  STD_LOGIC;
    i_alu_op         : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_acc_in         : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_acc_write_en   : IN  STD_LOGIC;
    i_tmp_write_en   : IN  STD_LOGIC;
    i_flags_write_en : IN  STD_LOGIC;
    o_acc_out        : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_tmp_out        : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_alu_result     : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
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

  SIGNAL s_acc_reg   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_tmp_reg   : STD_LOGIC_VECTOR(19 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_z_reg     : STD_LOGIC := '0';
  SIGNAL s_n_reg     : STD_LOGIC := '0';
  SIGNAL s_c_reg     : STD_LOGIC := '0';
  SIGNAL s_alu_out   : STD_LOGIC_VECTOR(19 DOWNTO 0);
  SIGNAL s_carry_out : STD_LOGIC;

BEGIN

  o_acc_out <= s_acc_reg;
  o_tmp_out <= s_tmp_reg;
  o_flag_z  <= s_z_reg;
  o_flag_n  <= s_n_reg;
  o_flag_c  <= s_c_reg;

  alu_comb_proc: PROCESS(i_alu_op, s_acc_reg, i_acc_in)
    VARIABLE v_sum     : UNSIGNED(20 DOWNTO 0);
    VARIABLE v_gray2b  : STD_LOGIC_VECTOR(19 DOWNTO 0);
    VARIABLE v_bin2g   : STD_LOGIC_VECTOR(19 DOWNTO 0);
    VARIABLE v_neg_val : SIGNED(19 DOWNTO 0);
  BEGIN
    s_alu_out   <= s_acc_reg;
    s_carry_out <= '0';
    CASE i_alu_op IS
      WHEN c_op_nop =>
        s_alu_out <= s_acc_reg;
      WHEN c_op_add =>
        v_sum := ('0' & UNSIGNED(s_acc_reg)) + ('0' & UNSIGNED(i_acc_in));
        s_alu_out   <= STD_LOGIC_VECTOR(v_sum(19 DOWNTO 0));
        s_carry_out <= v_sum(20);
      WHEN c_op_sub =>
        v_sum := ('0' & UNSIGNED(s_acc_reg)) - ('0' & UNSIGNED(i_acc_in));
        s_alu_out   <= STD_LOGIC_VECTOR(v_sum(19 DOWNTO 0));
        s_carry_out <= v_sum(20);
      WHEN c_op_and =>
        s_alu_out <= s_acc_reg AND i_acc_in;
      WHEN c_op_or =>
        s_alu_out <= s_acc_reg OR i_acc_in;
      WHEN c_op_xor =>
        s_alu_out <= s_acc_reg XOR i_acc_in;
      WHEN c_op_not =>
        s_alu_out <= NOT s_acc_reg;
      WHEN c_op_shl =>
        s_alu_out <= s_acc_reg(19) & s_acc_reg(17 DOWNTO 0) & '0';
      WHEN c_op_shr =>
        s_alu_out <= s_acc_reg(19) & s_acc_reg(19 DOWNTO 1);
      WHEN c_op_neg =>
        v_neg_val := -SIGNED(s_acc_reg);
        s_alu_out <= STD_LOGIC_VECTOR(v_neg_val);
      WHEN c_op_abs =>
        IF SIGNED(s_acc_reg) < 0 THEN
          IF s_acc_reg = x"80000" THEN
            s_alu_out <= x"7FFFF";
          ELSE
            s_alu_out <= STD_LOGIC_VECTOR(-SIGNED(s_acc_reg));
          END IF;
        ELSE
          s_alu_out <= s_acc_reg;
        END IF;
      WHEN c_op_gray2bin =>
        v_gray2b(19) := i_acc_in(19);
        FOR i IN 18 DOWNTO 0 LOOP
          v_gray2b(i) := v_gray2b(i+1) XOR i_acc_in(i);
        END LOOP;
        s_alu_out <= v_gray2b;
      WHEN c_op_bin2gray =>
        v_bin2g(19) := s_acc_reg(19);
        FOR i IN 18 DOWNTO 0 LOOP
          v_bin2g(i) := s_acc_reg(i+1) XOR s_acc_reg(i);
        END LOOP;
        s_alu_out <= v_bin2g;
      WHEN c_op_load =>
        s_alu_out <= i_acc_in;
      WHEN c_op_store_tmp =>
        s_alu_out <= s_acc_reg;
      WHEN c_op_pass =>
        s_alu_out <= i_acc_in;
      WHEN OTHERS =>
        s_alu_out <= s_acc_reg;
    END CASE;
  END PROCESS alu_comb_proc;

  o_alu_result <= s_alu_out;

  reg_proc: PROCESS(i_clk)
  BEGIN
    IF RISING_EDGE(i_clk) THEN
      IF i_rst = '1' THEN
        s_acc_reg <= (OTHERS => '0');
        s_tmp_reg <= (OTHERS => '0');
        s_z_reg   <= '0';
        s_n_reg   <= '0';
        s_c_reg   <= '0';
      ELSE
        IF i_acc_write_en = '1' THEN
          IF i_alu_op /= c_op_pass THEN
            s_acc_reg <= s_alu_out;
          END IF;
        END IF;
        IF i_tmp_write_en = '1' THEN
          s_tmp_reg <= s_acc_reg;
        END IF;
        IF i_flags_write_en = '1' THEN
          IF s_alu_out = x"00000" THEN
            s_z_reg <= '1';
          ELSE
            s_z_reg <= '0';
          END IF;
          s_n_reg <= s_alu_out(19);
          s_c_reg <= s_carry_out;
        END IF;
      END IF;
    END IF;
  END PROCESS reg_proc;

END ARCHITECTURE rtl;
'''
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print(f"Fixed: {path}")

if __name__ == "__main__":
    fix_timing_generator()
    fix_pmu()
    fix_pdu()
    fix_slf()
    print("Done with first batch!")

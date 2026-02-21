-------------------------------------------------------------------------------
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

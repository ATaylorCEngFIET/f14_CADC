-------------------------------------------------------------------------------
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

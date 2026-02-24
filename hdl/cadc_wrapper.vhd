-------------------------------------------------------------------------------
-- CADC Wrapper for IP Integrator
-- F-14A Central Air Data Computer - FPGA Implementation
--
-- This wrapper provides VHDL-93 compatible interface for IP Integrator
-- since IP Integrator does not support VHDL-2008
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity cadc_wrapper is
    port (
        i_clk_master     : in  std_logic;
        i_rst            : in  std_logic;
        -- Sensor inputs (20-bit parallel)
        i_sensor_ps      : in  std_logic_vector(19 downto 0);
        i_sensor_qc      : in  std_logic_vector(19 downto 0);
        i_sensor_tat     : in  std_logic_vector(19 downto 0);
        i_sensor_analog  : in  std_logic_vector(19 downto 0);
        i_sensor_digital : in  std_logic_vector(19 downto 0);
        -- Computed outputs (20-bit parallel)
        o_out_mach       : out std_logic_vector(19 downto 0);
        o_out_alt        : out std_logic_vector(19 downto 0);
        o_out_airspd     : out std_logic_vector(19 downto 0);
        o_out_vspd       : out std_logic_vector(19 downto 0);
        o_out_wing       : out std_logic_vector(19 downto 0);
        o_out_flap       : out std_logic_vector(19 downto 0);
        o_out_glove      : out std_logic_vector(19 downto 0);
        -- Status
        o_bit_status     : out std_logic;
        i_channel_active : in  std_logic;
        o_fail_detect    : out std_logic
    );
end entity cadc_wrapper;

architecture rtl of cadc_wrapper is

    component cadc_top is
        port (
            i_clk_master     : in  std_logic;
            i_rst            : in  std_logic;
            i_sensor_ps      : in  std_logic_vector(19 downto 0);
            i_sensor_qc      : in  std_logic_vector(19 downto 0);
            i_sensor_tat     : in  std_logic_vector(19 downto 0);
            i_sensor_analog  : in  std_logic_vector(19 downto 0);
            i_sensor_digital : in  std_logic_vector(19 downto 0);
            o_out_mach       : out std_logic_vector(19 downto 0);
            o_out_alt        : out std_logic_vector(19 downto 0);
            o_out_airspd     : out std_logic_vector(19 downto 0);
            o_out_vspd       : out std_logic_vector(19 downto 0);
            o_out_wing       : out std_logic_vector(19 downto 0);
            o_out_flap       : out std_logic_vector(19 downto 0);
            o_out_glove      : out std_logic_vector(19 downto 0);
            o_bit_status     : out std_logic;
            i_channel_active : in  std_logic;
            o_fail_detect    : out std_logic
        );
    end component cadc_top;

begin

    u_cadc_top : cadc_top
        port map (
            i_clk_master     => i_clk_master,
            i_rst            => i_rst,
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
            o_bit_status     => o_bit_status,
            i_channel_active => i_channel_active,
            o_fail_detect    => o_fail_detect
        );

end architecture rtl;

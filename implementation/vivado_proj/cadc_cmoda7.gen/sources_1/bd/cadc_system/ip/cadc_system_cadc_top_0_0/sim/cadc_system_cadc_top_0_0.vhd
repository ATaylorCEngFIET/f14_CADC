-- (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:module_ref:cadc_top:1.0
-- IP Revision: 1

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY cadc_system_cadc_top_0_0 IS
  PORT (
    i_clk_master : IN STD_LOGIC;
    i_rst : IN STD_LOGIC;
    i_sensor_ps : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_sensor_qc : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_sensor_tat : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_sensor_analog : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
    i_sensor_digital : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_mach : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_alt : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_airspd : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_vspd : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_wing : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_flap : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_out_glove : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
    o_bit_status : OUT STD_LOGIC;
    i_channel_active : IN STD_LOGIC;
    o_fail_detect : OUT STD_LOGIC
  );
END cadc_system_cadc_top_0_0;

ARCHITECTURE cadc_system_cadc_top_0_0_arch OF cadc_system_cadc_top_0_0 IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF cadc_system_cadc_top_0_0_arch: ARCHITECTURE IS "yes";
  COMPONENT cadc_top IS
    PORT (
      i_clk_master : IN STD_LOGIC;
      i_rst : IN STD_LOGIC;
      i_sensor_ps : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      i_sensor_qc : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      i_sensor_tat : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      i_sensor_analog : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      i_sensor_digital : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      o_out_mach : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      o_out_alt : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      o_out_airspd : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      o_out_vspd : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      o_out_wing : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      o_out_flap : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      o_out_glove : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      o_bit_status : OUT STD_LOGIC;
      i_channel_active : IN STD_LOGIC;
      o_fail_detect : OUT STD_LOGIC
    );
  END COMPONENT cadc_top;
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_MODE : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF i_rst: SIGNAL IS "xilinx.com:signal:reset:1.0 i_rst RST";
  ATTRIBUTE X_INTERFACE_MODE OF i_rst: SIGNAL IS "slave i_rst";
  ATTRIBUTE X_INTERFACE_PARAMETER OF i_rst: SIGNAL IS "XIL_INTERFACENAME i_rst, POLARITY ACTIVE_HIGH, INSERT_VIP 0";
BEGIN
  U0 : cadc_top
    PORT MAP (
      i_clk_master => i_clk_master,
      i_rst => i_rst,
      i_sensor_ps => i_sensor_ps,
      i_sensor_qc => i_sensor_qc,
      i_sensor_tat => i_sensor_tat,
      i_sensor_analog => i_sensor_analog,
      i_sensor_digital => i_sensor_digital,
      o_out_mach => o_out_mach,
      o_out_alt => o_out_alt,
      o_out_airspd => o_out_airspd,
      o_out_vspd => o_out_vspd,
      o_out_wing => o_out_wing,
      o_out_flap => o_out_flap,
      o_out_glove => o_out_glove,
      o_bit_status => o_bit_status,
      i_channel_active => i_channel_active,
      o_fail_detect => o_fail_detect
    );
END cadc_system_cadc_top_0_0_arch;

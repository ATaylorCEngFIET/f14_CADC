--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
--Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2025.1 (win64) Build 6140274 Thu May 22 00:12:29 MDT 2025
--Date        : Sun Feb 22 20:57:40 2026
--Host        : Adiuvo_Adam running 64-bit major release  (build 9200)
--Command     : generate_target cadc_system_wrapper.bd
--Design      : cadc_system_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity cadc_system_wrapper is
  port (
    sys_clk : in STD_LOGIC;
    sys_rst_n : in STD_LOGIC
  );
end cadc_system_wrapper;

architecture STRUCTURE of cadc_system_wrapper is
  component cadc_system is
  port (
    sys_clk : in STD_LOGIC;
    sys_rst_n : in STD_LOGIC
  );
  end component cadc_system;
begin
cadc_system_i: component cadc_system
     port map (
      sys_clk => sys_clk,
      sys_rst_n => sys_rst_n
    );
end STRUCTURE;

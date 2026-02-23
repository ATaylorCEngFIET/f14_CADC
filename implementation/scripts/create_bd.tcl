#-------------------------------------------------------------------------------
# F-14A CADC Block Design Creation Script
# Creates IP Integrator design with:
#   - JTAG-to-AXI Master for register access
#   - 5x AXI GPIO for sensor inputs (20-bit each)
#   - Clocking Wizard for 1.5 MHz CADC clock
#   - CADC Top Level as RTL module
#   - ILA for output monitoring
#-------------------------------------------------------------------------------

# Create block design
create_bd_design "cadc_system"

# Create clock port (12 MHz from Cmod A7)
create_bd_port -dir I -type clk -freq_hz 12000000 sys_clk
set_property CONFIG.FREQ_HZ 12000000 [get_bd_ports sys_clk]

# Create reset port (directly from button)
create_bd_port -dir I -type rst sys_rst_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports sys_rst_n]

#-------------------------------------------------------------------------------
# Add Clocking Wizard
# Generate 100MHz for AXI logic and 1.5MHz for CADC
#-------------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {12.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {1.500} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.CLKIN1_JITTER_PS {833.33} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {62.500} \
    CONFIG.MMCM_CLKIN1_PERIOD {83.333} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {7.500} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {500} \
    CONFIG.NUM_OUT_CLKS {2} \
    CONFIG.CLKOUT1_JITTER {181.828} \
    CONFIG.CLKOUT1_PHASE_ERROR {168.059} \
    CONFIG.CLKOUT2_JITTER {374.718} \
    CONFIG.CLKOUT2_PHASE_ERROR {168.059} \
] [get_bd_cells clk_wiz_0]

#-------------------------------------------------------------------------------
# Add Processor System Reset (for AXI domain)
#-------------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

#-------------------------------------------------------------------------------
# Add JTAG-to-AXI Master
#-------------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag_axi_0
set_property -dict [list \
    CONFIG.PROTOCOL {2} \
] [get_bd_cells jtag_axi_0]

#-------------------------------------------------------------------------------
# Add AXI Interconnect (1 master, 5 slaves for GPIOs)
#-------------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list \
    CONFIG.NUM_MI {5} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells axi_interconnect_0]

#-------------------------------------------------------------------------------
# Add 5x AXI GPIO for sensor inputs
# Each GPIO is 20-bit wide for sensor data
#-------------------------------------------------------------------------------

# GPIO 0: Static Pressure (Ps)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_ps
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {20} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000000} \
] [get_bd_cells axi_gpio_ps]

# GPIO 1: Impact Pressure (Qc)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_qc
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {20} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000000} \
] [get_bd_cells axi_gpio_qc]

# GPIO 2: Total Air Temperature (TAT)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_tat
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {20} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000000} \
] [get_bd_cells axi_gpio_tat]

# GPIO 3: Analog Input
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_analog
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {20} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000000} \
] [get_bd_cells axi_gpio_analog]

# GPIO 4: Digital Input + Channel Active
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_digital
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {20} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO2_WIDTH {1} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_ALL_OUTPUTS_2 {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000000} \
    CONFIG.C_DOUT_DEFAULT_2 {0x00000001} \
] [get_bd_cells axi_gpio_digital]

#-------------------------------------------------------------------------------
# Add CADC Top Level as RTL module
#-------------------------------------------------------------------------------
create_bd_cell -type module -reference cadc_top cadc_top_0

#-------------------------------------------------------------------------------
# Add ILA for output monitoring (142 bits total for all outputs)
# 7x 20-bit outputs + 2-bit status
#-------------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_0
set_property -dict [list \
    CONFIG.C_PROBE0_WIDTH {20} \
    CONFIG.C_PROBE1_WIDTH {20} \
    CONFIG.C_PROBE2_WIDTH {20} \
    CONFIG.C_PROBE3_WIDTH {20} \
    CONFIG.C_PROBE4_WIDTH {20} \
    CONFIG.C_PROBE5_WIDTH {20} \
    CONFIG.C_PROBE6_WIDTH {20} \
    CONFIG.C_PROBE7_WIDTH {1} \
    CONFIG.C_PROBE8_WIDTH {1} \
    CONFIG.C_NUM_OF_PROBES {9} \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_EN_STRG_QUAL {1} \
    CONFIG.C_TRIGIN_EN {false} \
    CONFIG.C_TRIGOUT_EN {false} \
] [get_bd_cells ila_0]

#-------------------------------------------------------------------------------
# Connect Clocks and Resets
#-------------------------------------------------------------------------------

# Clock wizard input
connect_bd_net [get_bd_ports sys_clk] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_ports sys_rst_n] [get_bd_pins clk_wiz_0/resetn]

# Processor system reset
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]
connect_bd_net [get_bd_ports sys_rst_n] [get_bd_pins proc_sys_reset_0/ext_reset_in]

# 100MHz clock to AXI components
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins jtag_axi_0/aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_interconnect_0/M00_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_interconnect_0/M01_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_interconnect_0/M02_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_interconnect_0/M03_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_interconnect_0/M04_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_gpio_ps/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_gpio_qc/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_gpio_tat/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_gpio_analog/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_gpio_digital/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins ila_0/clk]

# 1.5MHz clock to CADC
connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins cadc_top_0/i_clk_master]

# Resets
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins jtag_axi_0/aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/M00_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/M01_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/M02_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/M03_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/M04_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_gpio_ps/s_axi_aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_gpio_qc/s_axi_aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_gpio_tat/s_axi_aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_gpio_analog/s_axi_aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_gpio_digital/s_axi_aresetn]

# CADC reset (active high, invert from active low peripheral reset)
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0
set_property -dict [list \
    CONFIG.C_SIZE {1} \
    CONFIG.C_OPERATION {not} \
] [get_bd_cells util_vector_logic_0]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins util_vector_logic_0/Op1]
connect_bd_net [get_bd_pins util_vector_logic_0/Res] [get_bd_pins cadc_top_0/i_rst]

#-------------------------------------------------------------------------------
# Connect AXI Interfaces
#-------------------------------------------------------------------------------

# JTAG to Interconnect
connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# Interconnect to GPIOs
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins axi_gpio_ps/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_gpio_qc/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M02_AXI] [get_bd_intf_pins axi_gpio_tat/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M03_AXI] [get_bd_intf_pins axi_gpio_analog/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M04_AXI] [get_bd_intf_pins axi_gpio_digital/S_AXI]

#-------------------------------------------------------------------------------
# Connect GPIO outputs to CADC inputs
#-------------------------------------------------------------------------------

connect_bd_net [get_bd_pins axi_gpio_ps/gpio_io_o] [get_bd_pins cadc_top_0/i_sensor_ps]
connect_bd_net [get_bd_pins axi_gpio_qc/gpio_io_o] [get_bd_pins cadc_top_0/i_sensor_qc]
connect_bd_net [get_bd_pins axi_gpio_tat/gpio_io_o] [get_bd_pins cadc_top_0/i_sensor_tat]
connect_bd_net [get_bd_pins axi_gpio_analog/gpio_io_o] [get_bd_pins cadc_top_0/i_sensor_analog]
connect_bd_net [get_bd_pins axi_gpio_digital/gpio_io_o] [get_bd_pins cadc_top_0/i_sensor_digital]
connect_bd_net [get_bd_pins axi_gpio_digital/gpio2_io_o] [get_bd_pins cadc_top_0/i_channel_active]

#-------------------------------------------------------------------------------
# Connect CADC outputs to ILA
#-------------------------------------------------------------------------------

connect_bd_net [get_bd_pins cadc_top_0/o_out_mach] [get_bd_pins ila_0/probe0]
connect_bd_net [get_bd_pins cadc_top_0/o_out_alt] [get_bd_pins ila_0/probe1]
connect_bd_net [get_bd_pins cadc_top_0/o_out_airspd] [get_bd_pins ila_0/probe2]
connect_bd_net [get_bd_pins cadc_top_0/o_out_vspd] [get_bd_pins ila_0/probe3]
connect_bd_net [get_bd_pins cadc_top_0/o_out_wing] [get_bd_pins ila_0/probe4]
connect_bd_net [get_bd_pins cadc_top_0/o_out_flap] [get_bd_pins ila_0/probe5]
connect_bd_net [get_bd_pins cadc_top_0/o_out_glove] [get_bd_pins ila_0/probe6]
connect_bd_net [get_bd_pins cadc_top_0/o_bit_status] [get_bd_pins ila_0/probe7]
connect_bd_net [get_bd_pins cadc_top_0/o_fail_detect] [get_bd_pins ila_0/probe8]

#-------------------------------------------------------------------------------
# Assign Addresses
#-------------------------------------------------------------------------------

assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_gpio_ps/S_AXI/Reg] -force
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_gpio_qc/S_AXI/Reg] -force
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_gpio_tat/S_AXI/Reg] -force
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_gpio_analog/S_AXI/Reg] -force
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_gpio_digital/S_AXI/Reg] -force

# Set specific addresses for easy reference
set_property offset 0x40000000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_ps_Reg}]
set_property offset 0x40010000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_qc_Reg}]
set_property offset 0x40020000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_tat_Reg}]
set_property offset 0x40030000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_analog_Reg}]
set_property offset 0x40040000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_digital_Reg}]

#-------------------------------------------------------------------------------
# Validate and Save
#-------------------------------------------------------------------------------

regenerate_bd_layout
validate_bd_design
save_bd_design

puts "=========================================="
puts "Block design created successfully!"
puts ""
puts "AXI GPIO Address Map:"
puts "  GPIO_PS      (i_sensor_ps)      : 0x40000000"
puts "  GPIO_QC      (i_sensor_qc)      : 0x40010000"
puts "  GPIO_TAT     (i_sensor_tat)     : 0x40020000"
puts "  GPIO_ANALOG  (i_sensor_analog)  : 0x40030000"
puts "  GPIO_DIGITAL (i_sensor_digital) : 0x40040000"
puts "    Channel 1: sensor_digital[19:0]"
puts "    Channel 2: channel_active[0]"
puts ""
puts "ILA Probes:"
puts "  probe0: o_out_mach[19:0]"
puts "  probe1: o_out_alt[19:0]"
puts "  probe2: o_out_airspd[19:0]"
puts "  probe3: o_out_vspd[19:0]"
puts "  probe4: o_out_wing[19:0]"
puts "  probe5: o_out_flap[19:0]"
puts "  probe6: o_out_glove[19:0]"
puts "  probe7: o_bit_status"
puts "  probe8: o_fail_detect"
puts "=========================================="

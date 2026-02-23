## F-14A CADC Constraints for Digilent Cmod A7
## Target: xc7a35tcpg236-1
##
## This design uses JTAG-to-AXI and ILA for debug - no physical I/O required

## 12 MHz Clock Signal from Cmod A7
set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports { sys_clk }]
create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.666} [get_ports {sys_clk}]

## Reset Button (directly to button 0)
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { sys_rst_n }]

## LEDs for status indication (active-high of reset)
#set_property -dict { PACKAGE_PIN A17   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
#set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]

#-------------------------------------------------------------------------------
# Clock Domain Crossing Constraints
# The design has three clock domains:
#   - 100 MHz AXI clock (clk_out1 from clk_wiz)
#   - 6 MHz intermediate clock (clk_out2 from clk_wiz)
#   - 1.5 MHz CADC clock (from clock_divider)
#-------------------------------------------------------------------------------

# The clocking wizard generates 100 MHz and 6 MHz - they are related (same MMCM)
# The 1.5 MHz is generated from 6 MHz by the clock divider module
# Create generated clock for 1.5 MHz
create_generated_clock -name clk_cadc_1p5mhz \
    -source [get_pins cadc_system_i/clk_wiz_0/clk_out2] \
    -divide_by 4 \
    [get_pins cadc_system_i/clock_divider_0/inst/clk_reg_reg/Q]

# False path for reset synchronizer (proc_sys_reset handles this)
# set_false_path -from [get_pins proc_sys_reset_0/*/rst_reg/C] -to [all_registers]

#-------------------------------------------------------------------------------
# Bitstream Configuration
#-------------------------------------------------------------------------------

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------

# Keep hierarchy for debug visibility
set_property KEEP_HIERARCHY TRUE [get_cells -hierarchical cadc_top_0]

#-------------------------------------------------------------------------------
# Timing Exceptions
#-------------------------------------------------------------------------------

# GPIO outputs are registered and go through CDC - but within related clocks
# If timing fails on GPIO to CADC path, uncomment:
# set_max_delay -datapath_only -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks clk_out2_clk_wiz_0] 10.0


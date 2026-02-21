# CADC Polynomial Computation Waveform Setup
# F-14A Central Air Data Computer - FPGA Implementation
# Shows key signals for debugging E = a3*X^3 + a2*X^2 + a1*X + a0

onerror {resume}
quietly WaveActivateNextPane {} 0

# Clear existing waves
delete wave *

# ============================================================================
# Clock and Reset
# ============================================================================
add wave -noupdate -divider {Clock & Reset}
add wave -noupdate -label "CLK" /cadc_top_tb/clk_master
add wave -noupdate -label "RST" /cadc_top_tb/rst

# ============================================================================
# Polynomial Input/Output (Key Signals)
# ============================================================================
add wave -noupdate -divider {Polynomial I/O}
add wave -noupdate -label "X Input (sensor_ps)" -radix hexadecimal /cadc_top_tb/sensor_ps
add wave -noupdate -label "E Output (out_mach)" -radix hexadecimal /cadc_top_tb/out_mach
add wave -noupdate -label "Channel Active" /cadc_top_tb/channel_active

# ============================================================================
# Microprogram Execution
# ============================================================================
add wave -noupdate -divider {Microprogram Control}
add wave -noupdate -label "Micro PC" -radix unsigned /cadc_top_tb/uut/s_micro_addr
add wave -noupdate -label "Microword" -radix hexadecimal /cadc_top_tb/uut/s_micro_word
add wave -noupdate -label "ALU Op" -radix hexadecimal /cadc_top_tb/uut/s_alu_op
add wave -noupdate -label "ACC Write En" /cadc_top_tb/uut/s_acc_write_en
add wave -noupdate -label "TMP Write En" /cadc_top_tb/uut/s_tmp_write_en

# ============================================================================
# Data ROM (Coefficients)
# ============================================================================
add wave -noupdate -divider {Data ROM}
add wave -noupdate -label "ROM Addr" -radix unsigned /cadc_top_tb/uut/s_data_rom_addr
add wave -noupdate -label "ROM Data" -radix hexadecimal /cadc_top_tb/uut/s_data_rom_data
add wave -noupdate -label "Sel ACC Src" -radix unsigned /cadc_top_tb/uut/s_sel_acc_src

# ============================================================================
# SLF (ALU) Registers
# ============================================================================
add wave -noupdate -divider {SLF Registers}
add wave -noupdate -label "ACC" -radix hexadecimal /cadc_top_tb/uut/u_slf/s_acc_reg
add wave -noupdate -label "TMP" -radix hexadecimal /cadc_top_tb/uut/u_slf/s_tmp_reg
add wave -noupdate -label "ALU Result" -radix hexadecimal /cadc_top_tb/uut/u_slf/s_alu_out
add wave -noupdate -label "ACC Input" -radix hexadecimal /cadc_top_tb/uut/s_slf_acc_in

# ============================================================================
# PMU (Multiplier)
# ============================================================================
add wave -noupdate -divider {PMU Multiplier}
add wave -noupdate -label "PMU Start" /cadc_top_tb/uut/s_pmu_start
add wave -noupdate -label "PMU Busy" /cadc_top_tb/uut/s_pmu_busy
add wave -noupdate -label "PMU Done" /cadc_top_tb/uut/s_pmu_done
add wave -noupdate -label "PMU Op A (ACC)" -radix hexadecimal /cadc_top_tb/uut/s_pmu_operand_a
add wave -noupdate -label "PMU Op B (TMP)" -radix hexadecimal /cadc_top_tb/uut/s_pmu_operand_b
add wave -noupdate -label "PMU Result" -radix hexadecimal /cadc_top_tb/uut/s_pmu_result

# ============================================================================
# I/O Bridge
# ============================================================================
add wave -noupdate -divider {I/O Bridge}
add wave -noupdate -label "IO Ctrl" -radix hexadecimal /cadc_top_tb/uut/s_io_ctrl
add wave -noupdate -label "IO Data Out" -radix hexadecimal /cadc_top_tb/uut/s_io_data_out
add wave -noupdate -label "IO Data In" -radix hexadecimal /cadc_top_tb/uut/s_io_data_in

# ============================================================================
# RAS (Register Array)
# ============================================================================
add wave -noupdate -divider {RAS Storage}
add wave -noupdate -label "RAS Write En" /cadc_top_tb/uut/s_ras_write_en
add wave -noupdate -label "RAS Read Addr" -radix unsigned /cadc_top_tb/uut/s_ras_read_addr
add wave -noupdate -label "RAS Write Addr" -radix unsigned /cadc_top_tb/uut/s_ras_write_addr
add wave -noupdate -label "RAS Read Data" -radix hexadecimal /cadc_top_tb/uut/s_ras_read_data
add wave -noupdate -label "RAS Write Data" -radix hexadecimal /cadc_top_tb/uut/s_ras_write_data

# ============================================================================
# Flags
# ============================================================================
add wave -noupdate -divider {ALU Flags}
add wave -noupdate -label "Flag Z" /cadc_top_tb/uut/s_flag_z
add wave -noupdate -label "Flag N" /cadc_top_tb/uut/s_flag_n
add wave -noupdate -label "Flag C" /cadc_top_tb/uut/s_flag_c

# ============================================================================
# Test Status
# ============================================================================
add wave -noupdate -divider {Test Status}
add wave -noupdate -label "Test Count" -radix unsigned /cadc_top_tb/test_count
add wave -noupdate -label "Fail Count" -radix unsigned /cadc_top_tb/fail_count

# ============================================================================
# Other Outputs
# ============================================================================
add wave -noupdate -divider {Other Outputs}
add wave -noupdate -label "out_alt" -radix hexadecimal /cadc_top_tb/out_alt
add wave -noupdate -label "out_airspd" -radix hexadecimal /cadc_top_tb/out_airspd
add wave -noupdate -label "Fail Detect" /cadc_top_tb/fail_detect

# ============================================================================
# Configure Wave Window
# ============================================================================
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 180
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {50 us}

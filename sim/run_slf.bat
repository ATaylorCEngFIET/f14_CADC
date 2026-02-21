@echo off
REM SLF Testbench - Interactive Simulation
set QUESTA_PATH=C:\questa_base64_2025.3\win64
set PATH=%QUESTA_PATH%;%PATH%
set WORK_DIR=C:\temp\cadc_sim
set SRC_DIR=%~dp0..\hdl
set TB_DIR=%~dp0..\tb

cd /d %WORK_DIR%

REM Compile sources if needed
vlib work 2>nul
vcom -2008 -work work "%SRC_DIR%\slf.vhd"
vcom -2008 -work work "%TB_DIR%\slf_tb.vhd"

REM Create DO file for waveform setup
echo # SLF Waveform Setup > slf_wave.do
echo add wave -divider "Clock and Control" >> slf_wave.do
echo add wave /slf_tb/s_clk >> slf_wave.do
echo add wave /slf_tb/s_rst >> slf_wave.do
echo add wave -divider "ALU Control" >> slf_wave.do
echo add wave -hex /slf_tb/s_alu_op >> slf_wave.do
echo add wave /slf_tb/s_acc_write_en >> slf_wave.do
echo add wave /slf_tb/s_tmp_write_en >> slf_wave.do
echo add wave /slf_tb/s_flags_write_en >> slf_wave.do
echo add wave -divider "Data Paths" >> slf_wave.do
echo add wave -hex /slf_tb/s_acc_in >> slf_wave.do
echo add wave -hex /slf_tb/s_acc_out >> slf_wave.do
echo add wave -hex /slf_tb/s_tmp_out >> slf_wave.do
echo add wave -hex /slf_tb/s_alu_result >> slf_wave.do
echo add wave -divider "Flags" >> slf_wave.do
echo add wave /slf_tb/s_flag_z >> slf_wave.do
echo add wave /slf_tb/s_flag_n >> slf_wave.do
echo add wave /slf_tb/s_flag_c >> slf_wave.do
echo add wave -divider "Internal Registers" >> slf_wave.do
echo add wave -hex /slf_tb/uut/s_acc_reg >> slf_wave.do
echo add wave -hex /slf_tb/uut/s_tmp_reg >> slf_wave.do
echo add wave -divider "Test Status" >> slf_wave.do
echo add wave -decimal /slf_tb/s_test_count >> slf_wave.do
echo add wave -decimal /slf_tb/s_fail_count >> slf_wave.do
echo configure wave -namecolwidth 250 >> slf_wave.do
echo configure wave -valuecolwidth 120 >> slf_wave.do

REM Launch simulation with GUI
vsim -gui -do "do slf_wave.do; run 0 ns" work.slf_tb

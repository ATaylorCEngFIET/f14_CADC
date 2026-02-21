@echo off
REM SL Testbench - Interactive Simulation
set QUESTA_PATH=C:\questa_base64_2025.3\win64
set PATH=%QUESTA_PATH%;%PATH%
set WORK_DIR=C:\temp\cadc_sim
set SRC_DIR=%~dp0..\hdl
set TB_DIR=%~dp0..\tb

cd /d %WORK_DIR%

REM Compile sources if needed
vlib work 2>nul
vcom -2008 -work work "%SRC_DIR%\sl.vhd"
vcom -2008 -work work "%TB_DIR%\sl_tb.vhd"

REM Create DO file for waveform setup
echo # SL Waveform Setup > sl_wave.do
echo add wave -divider "Source Inputs" >> sl_wave.do
echo add wave -hex /sl_tb/s_src_ras >> sl_wave.do
echo add wave -hex /sl_tb/s_src_acc >> sl_wave.do
echo add wave -hex /sl_tb/s_src_tmp >> sl_wave.do
echo add wave -hex /sl_tb/s_src_pmu >> sl_wave.do
echo add wave -hex /sl_tb/s_src_pdu_q >> sl_wave.do
echo add wave -hex /sl_tb/s_src_pdu_r >> sl_wave.do
echo add wave -hex /sl_tb/s_src_io_in >> sl_wave.do
echo add wave -hex /sl_tb/s_src_const >> sl_wave.do
echo add wave -divider "Select Controls" >> sl_wave.do
echo add wave -hex /sl_tb/s_sel_acc_src >> sl_wave.do
echo add wave -hex /sl_tb/s_sel_ras_src >> sl_wave.do
echo add wave -hex /sl_tb/s_sel_io_src >> sl_wave.do
echo add wave -divider "Routed Outputs" >> sl_wave.do
echo add wave -hex /sl_tb/s_acc_in >> sl_wave.do
echo add wave -hex /sl_tb/s_ras_wr_data >> sl_wave.do
echo add wave -hex /sl_tb/s_io_out >> sl_wave.do
echo add wave -divider "Test Status" >> sl_wave.do
echo add wave -decimal /sl_tb/s_test_count >> sl_wave.do
echo add wave -decimal /sl_tb/s_fail_count >> sl_wave.do
echo configure wave -namecolwidth 220 >> sl_wave.do
echo configure wave -valuecolwidth 120 >> sl_wave.do

REM Launch simulation with GUI
vsim -gui -do "do sl_wave.do; run 0 ns" work.sl_tb

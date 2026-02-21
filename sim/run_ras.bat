@echo off
REM RAS Testbench - Interactive Simulation
set QUESTA_PATH=C:\questa_base64_2025.3\win64
set PATH=%QUESTA_PATH%;%PATH%
set WORK_DIR=C:\temp\cadc_sim
set SRC_DIR=%~dp0..\hdl
set TB_DIR=%~dp0..\tb

cd /d %WORK_DIR%

REM Compile sources if needed
vlib work 2>nul
vcom -2008 -work work "%SRC_DIR%\ras.vhd"
vcom -2008 -work work "%TB_DIR%\ras_tb.vhd"

REM Create DO file for waveform setup
echo # RAS Waveform Setup > ras_wave.do
echo add wave -divider "Clock and Control" >> ras_wave.do
echo add wave /ras_tb/clk >> ras_wave.do
echo add wave /ras_tb/rst >> ras_wave.do
echo add wave -divider "Read Port" >> ras_wave.do
echo add wave -unsigned /ras_tb/read_addr >> ras_wave.do
echo add wave -hex /ras_tb/read_data >> ras_wave.do
echo add wave -divider "Write Port" >> ras_wave.do
echo add wave /ras_tb/write_en >> ras_wave.do
echo add wave -unsigned /ras_tb/write_addr >> ras_wave.do
echo add wave -hex /ras_tb/write_data >> ras_wave.do
echo add wave -divider "Test Status" >> ras_wave.do
echo add wave -decimal /ras_tb/test_count >> ras_wave.do
echo add wave -decimal /ras_tb/fail_count >> ras_wave.do
echo configure wave -namecolwidth 220 >> ras_wave.do
echo configure wave -valuecolwidth 120 >> ras_wave.do

REM Launch simulation with GUI
vsim -gui -do "do ras_wave.do; run 0 ns" work.ras_tb

@echo off
REM PMU Testbench - Interactive Simulation
set QUESTA_PATH=C:\questa_base64_2025.3\win64
set PATH=%QUESTA_PATH%;%PATH%
set WORK_DIR=C:\temp\cadc_sim
set SRC_DIR=%~dp0..\hdl
set TB_DIR=%~dp0..\tb

cd /d %WORK_DIR%

REM Compile sources if needed
vlib work 2>nul
vcom -2008 -work work "%SRC_DIR%\pmu.vhd"
vcom -2008 -work work "%TB_DIR%\pmu_tb.vhd"

REM Create DO file for waveform setup
echo # PMU Waveform Setup > pmu_wave.do
echo add wave -divider "Clock and Control" >> pmu_wave.do
echo add wave /pmu_tb/s_clk >> pmu_wave.do
echo add wave /pmu_tb/s_rst >> pmu_wave.do
echo add wave /pmu_tb/s_start >> pmu_wave.do
echo add wave -divider "Operands (Q1.19 fractional)" >> pmu_wave.do
echo add wave -hex /pmu_tb/s_operand_a >> pmu_wave.do
echo add wave -hex /pmu_tb/s_operand_b >> pmu_wave.do
echo add wave -divider "Result" >> pmu_wave.do
echo add wave -hex /pmu_tb/s_result >> pmu_wave.do
echo add wave -divider "Status" >> pmu_wave.do
echo add wave /pmu_tb/s_busy >> pmu_wave.do
echo add wave /pmu_tb/s_done >> pmu_wave.do
echo add wave -divider "Internal State" >> pmu_wave.do
echo add wave /pmu_tb/uut/s_state >> pmu_wave.do
echo add wave -hex /pmu_tb/uut/s_accumulator >> pmu_wave.do
echo add wave -unsigned /pmu_tb/uut/s_bit_cnt >> pmu_wave.do
echo add wave -divider "Test Status" >> pmu_wave.do
echo add wave -decimal /pmu_tb/s_test_count >> pmu_wave.do
echo add wave -decimal /pmu_tb/s_fail_count >> pmu_wave.do
echo configure wave -namecolwidth 250 >> pmu_wave.do
echo configure wave -valuecolwidth 120 >> pmu_wave.do

REM Launch simulation with GUI
vsim -gui -do "do pmu_wave.do; run 0 ns" work.pmu_tb

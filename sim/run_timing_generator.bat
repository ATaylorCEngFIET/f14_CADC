@echo off
REM Timing Generator Testbench - Interactive Simulation
set QUESTA_PATH=C:\questa_base64_2025.3\win64
set PATH=%QUESTA_PATH%;%PATH%
set WORK_DIR=C:\temp\cadc_sim
set SRC_DIR=%~dp0..\hdl
set TB_DIR=%~dp0..\tb

cd /d %WORK_DIR%

REM Compile sources if needed
vlib work 2>nul
vcom -2008 -work work "%SRC_DIR%\timing_generator.vhd"
vcom -2008 -work work "%TB_DIR%\timing_generator_tb.vhd"

REM Create DO file for waveform setup
echo # Timing Generator Waveform Setup > timing_generator_wave.do
echo add wave -divider "Clocks and Reset" >> timing_generator_wave.do
echo add wave -hex /timing_generator_tb/s_clk_master >> timing_generator_wave.do
echo add wave -hex /timing_generator_tb/s_rst >> timing_generator_wave.do
echo add wave -divider "Phase Clocks" >> timing_generator_wave.do
echo add wave /timing_generator_tb/s_phi1 >> timing_generator_wave.do
echo add wave /timing_generator_tb/s_phi2 >> timing_generator_wave.do
echo add wave -divider "Counters" >> timing_generator_wave.do
echo add wave -unsigned /timing_generator_tb/s_bit_count >> timing_generator_wave.do
echo add wave /timing_generator_tb/s_word_type >> timing_generator_wave.do
echo add wave /timing_generator_tb/s_word_mark >> timing_generator_wave.do
echo add wave -unsigned /timing_generator_tb/s_op_count >> timing_generator_wave.do
echo add wave /timing_generator_tb/s_frame_mark >> timing_generator_wave.do
echo add wave -divider "Test Status" >> timing_generator_wave.do
echo add wave -decimal /timing_generator_tb/s_test_count >> timing_generator_wave.do
echo add wave -decimal /timing_generator_tb/s_fail_count >> timing_generator_wave.do
echo configure wave -namecolwidth 220 >> timing_generator_wave.do
echo configure wave -valuecolwidth 100 >> timing_generator_wave.do

REM Launch simulation with GUI
vsim -gui -do "do timing_generator_wave.do; run 0 ns" work.timing_generator_tb

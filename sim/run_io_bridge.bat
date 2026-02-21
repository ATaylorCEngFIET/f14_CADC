@echo off
REM I/O Bridge Testbench - Interactive Simulation
set QUESTA_PATH=C:\questa_base64_2025.3\win64
set PATH=%QUESTA_PATH%;%PATH%
set WORK_DIR=C:\temp\cadc_sim
set SRC_DIR=%~dp0..\hdl
set TB_DIR=%~dp0..\tb

cd /d %WORK_DIR%

REM Compile sources if needed
vlib work 2>nul
vcom -2008 -work work "%SRC_DIR%\io_bridge.vhd"
vcom -2008 -work work "%TB_DIR%\io_bridge_tb.vhd"

REM Create DO file for waveform setup
echo # I/O Bridge Waveform Setup > io_bridge_wave.do
echo add wave -divider "Clock and Control" >> io_bridge_wave.do
echo add wave /io_bridge_tb/clk >> io_bridge_wave.do
echo add wave /io_bridge_tb/rst >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/io_ctrl >> io_bridge_wave.do
echo add wave /io_bridge_tb/channel_active >> io_bridge_wave.do
echo add wave -divider "Data Bus" >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/io_data_in >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/io_data_out >> io_bridge_wave.do
echo add wave /io_bridge_tb/io_ready >> io_bridge_wave.do
echo add wave -divider "Sensor Inputs" >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/sensor_ps >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/sensor_qc >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/sensor_tat >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/sensor_analog >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/sensor_digital >> io_bridge_wave.do
echo add wave -divider "Display Outputs" >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/out_mach >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/out_alt >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/out_airspd >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/out_vspd >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/out_wing >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/out_flap >> io_bridge_wave.do
echo add wave -hex /io_bridge_tb/out_glove >> io_bridge_wave.do
echo add wave /io_bridge_tb/out_bit_status >> io_bridge_wave.do
echo add wave -divider "Test Status" >> io_bridge_wave.do
echo add wave -decimal /io_bridge_tb/test_count >> io_bridge_wave.do
echo add wave -decimal /io_bridge_tb/fail_count >> io_bridge_wave.do
echo configure wave -namecolwidth 250 >> io_bridge_wave.do
echo configure wave -valuecolwidth 120 >> io_bridge_wave.do

REM Launch simulation with GUI
vsim -gui -do "do io_bridge_wave.do; run 0 ns" work.io_bridge_tb

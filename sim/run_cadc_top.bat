@echo off
REM CADC Top-Level Testbench - Interactive Simulation
set QUESTA_PATH=C:\questa_base64_2025.3\win64
set PATH=%QUESTA_PATH%;%PATH%
set WORK_DIR=C:\temp\cadc_sim
set SRC_DIR=%~dp0..\hdl
set TB_DIR=%~dp0..\tb

cd /d %WORK_DIR%

REM Compile all sources (full design hierarchy)
vlib work 2>nul
vcom -2008 -work work "%SRC_DIR%\timing_generator.vhd"
vcom -2008 -work work "%SRC_DIR%\pmu.vhd"
vcom -2008 -work work "%SRC_DIR%\pdu.vhd"
vcom -2008 -work work "%SRC_DIR%\slf.vhd"
vcom -2008 -work work "%SRC_DIR%\ras.vhd"
vcom -2008 -work work "%SRC_DIR%\sl.vhd"
vcom -2008 -work work "%SRC_DIR%\control_rom_sequencer.vhd"
vcom -2008 -work work "%SRC_DIR%\io_bridge.vhd"
vcom -2008 -work work "%SRC_DIR%\cadc_top.vhd"
vcom -2008 -work work "%TB_DIR%\cadc_top_tb.vhd"

REM Create DO file for waveform setup
echo # CADC Top-Level Waveform Setup > cadc_top_wave.do
echo add wave -divider "Clock and Reset" >> cadc_top_wave.do
echo add wave /cadc_top_tb/clk >> cadc_top_wave.do
echo add wave /cadc_top_tb/rst >> cadc_top_wave.do
echo add wave -divider "Sensor Inputs" >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/sensor_ps >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/sensor_qc >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/sensor_tat >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/sensor_analog >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/sensor_digital >> cadc_top_wave.do
echo add wave -divider "Display Outputs" >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/out_mach >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/out_alt >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/out_airspd >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/out_vspd >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/out_wing >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/out_flap >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/out_glove >> cadc_top_wave.do
echo add wave -divider "Internal - ROM Sequencer" >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/ROM_SEQ_INST/s_state >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/UUT/ROM_SEQ_INST/s_rom_addr >> cadc_top_wave.do
echo add wave -hex /cadc_top_tb/UUT/ROM_SEQ_INST/s_microcode >> cadc_top_wave.do
echo add wave -divider "Internal - Timing Generator" >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/TIMING_INST/s_phase_a >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/TIMING_INST/s_phase_b >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/TIMING_INST/s_phase_c >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/TIMING_INST/s_phase_d >> cadc_top_wave.do
echo add wave -divider "Internal - SLF Flags" >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/SLF_INST/o_flag_z >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/SLF_INST/o_flag_n >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/SLF_INST/o_flag_c >> cadc_top_wave.do
echo add wave /cadc_top_tb/UUT/SLF_INST/o_flag_v >> cadc_top_wave.do
echo add wave -divider "Test Status" >> cadc_top_wave.do
echo add wave -decimal /cadc_top_tb/test_count >> cadc_top_wave.do
echo add wave -decimal /cadc_top_tb/fail_count >> cadc_top_wave.do
echo configure wave -namecolwidth 350 >> cadc_top_wave.do
echo configure wave -valuecolwidth 120 >> cadc_top_wave.do

REM Launch simulation with GUI
vsim -gui -do "do cadc_top_wave.do; run 0 ns" work.cadc_top_tb

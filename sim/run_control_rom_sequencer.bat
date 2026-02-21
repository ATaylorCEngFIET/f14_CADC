@echo off
REM Control ROM Sequencer Testbench - Interactive Simulation
set QUESTA_PATH=C:\questa_base64_2025.3\win64
set PATH=%QUESTA_PATH%;%PATH%
set WORK_DIR=C:\temp\cadc_sim
set SRC_DIR=%~dp0..\hdl
set TB_DIR=%~dp0..\tb

cd /d %WORK_DIR%

REM Compile sources if needed
vlib work 2>nul
vcom -2008 -work work "%SRC_DIR%\control_rom_sequencer.vhd"
vcom -2008 -work work "%TB_DIR%\control_rom_sequencer_tb.vhd"

REM Create DO file for waveform setup
echo # Control ROM Sequencer Waveform Setup > rom_seq_wave.do
echo add wave -divider "Clock and Control" >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/clk >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/rst >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/frame_mark >> rom_seq_wave.do
echo add wave -divider "Flags" >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/flag_z >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/flag_n >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/flag_c >> rom_seq_wave.do
echo add wave -divider "Unit Busy" >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/pmu_busy >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/pdu_busy >> rom_seq_wave.do
echo add wave -divider "Microcode" >> rom_seq_wave.do
echo add wave -unsigned /control_rom_sequencer_tb/micro_addr >> rom_seq_wave.do
echo add wave -hex /control_rom_sequencer_tb/micro_word >> rom_seq_wave.do
echo add wave -divider "Control Outputs" >> rom_seq_wave.do
echo add wave -hex /control_rom_sequencer_tb/alu_op >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/acc_write_en >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/tmp_write_en >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/ras_write_en >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/pmu_start >> rom_seq_wave.do
echo add wave /control_rom_sequencer_tb/pdu_start >> rom_seq_wave.do
echo add wave -hex /control_rom_sequencer_tb/io_ctrl >> rom_seq_wave.do
echo add wave -divider "Internal State" >> rom_seq_wave.do
echo add wave -unsigned /control_rom_sequencer_tb/uut/s_micro_pc >> rom_seq_wave.do
echo add wave -divider "Test Status" >> rom_seq_wave.do
echo add wave -decimal /control_rom_sequencer_tb/test_count >> rom_seq_wave.do
echo add wave -decimal /control_rom_sequencer_tb/fail_count >> rom_seq_wave.do
echo configure wave -namecolwidth 280 >> rom_seq_wave.do
echo configure wave -valuecolwidth 120 >> rom_seq_wave.do

REM Launch simulation with GUI
vsim -gui -do "do rom_seq_wave.do; run 0 ns" work.control_rom_sequencer_tb

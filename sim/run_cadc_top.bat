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

REM Copy wave DO file from sim directory
copy "%~dp0polynomial_waves.do" polynomial_waves.do >nul 2>&1

REM Launch simulation with GUI using polynomial waveform setup
vsim -gui -do "do polynomial_waves.do; run 50 us" work.cadc_top_tb

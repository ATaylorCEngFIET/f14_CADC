#!/usr/bin/env python3
"""Update testbench port maps to match new i_/o_/g_ prefixed HDL ports."""

import os
import re

BASE = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\tb"

# Port mappings: old_name -> new_name
# For each testbench, define the port map replacements

def fix_timing_generator_tb():
    path = os.path.join(BASE, "timing_generator_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Generic map
    content = content.replace("CLK_DIV => 1", "g_clk_div => 1")
    
    # Port map - inputs have i_, outputs have o_
    replacements = [
        ("clk_master => s_clk_master", "i_clk_master => s_clk_master"),
        ("rst        => s_rst",        "i_rst        => s_rst"),
        ("phi1       => s_phi1",       "o_phi1       => s_phi1"),
        ("phi2       => s_phi2",       "o_phi2       => s_phi2"),
        ("bit_count  => s_bit_count",  "o_bit_count  => s_bit_count"),
        ("word_type  => s_word_type",  "o_word_type  => s_word_type"),
        ("word_mark  => s_word_mark",  "o_word_mark  => s_word_mark"),
        ("op_count   => s_op_count",   "o_op_count   => s_op_count"),
        ("frame_mark => s_frame_mark", "o_frame_mark => s_frame_mark"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_pmu_tb():
    path = os.path.join(BASE, "pmu_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Inputs: clk, rst, start, operand_a, operand_b
    # Outputs: result, busy, done
    replacements = [
        ("clk       => s_clk",       "i_clk       => s_clk"),
        ("rst       => s_rst",       "i_rst       => s_rst"),
        ("start     => s_start",     "i_start     => s_start"),
        ("operand_a => s_operand_a", "i_operand_a => s_operand_a"),
        ("operand_b => s_operand_b", "i_operand_b => s_operand_b"),
        ("result    => s_result",    "o_result    => s_result"),
        ("busy      => s_busy",      "o_busy      => s_busy"),
        ("done      => s_done",      "o_done      => s_done"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_pdu_tb():
    path = os.path.join(BASE, "pdu_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Inputs: clk, rst, start, dividend, divisor
    # Outputs: quotient, remainder, busy, done, div_by_zero
    replacements = [
        ("clk         => s_clk",         "i_clk         => s_clk"),
        ("rst         => s_rst",         "i_rst         => s_rst"),
        ("start       => s_start",       "i_start       => s_start"),
        ("dividend    => s_dividend",    "i_dividend    => s_dividend"),
        ("divisor     => s_divisor",     "i_divisor     => s_divisor"),
        ("quotient    => s_quotient",    "o_quotient    => s_quotient"),
        ("remainder   => s_remainder",   "o_remainder   => s_remainder"),
        ("busy        => s_busy",        "o_busy        => s_busy"),
        ("done        => s_done",        "o_done        => s_done"),
        ("div_by_zero => s_div_by_zero", "o_div_by_zero => s_div_by_zero"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_slf_tb():
    path = os.path.join(BASE, "slf_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Inputs: clk, rst, alu_op, acc_in, acc_write_en, tmp_write_en, flags_write_en
    # Outputs: acc_out, tmp_out, alu_result, flag_z, flag_n, flag_c
    replacements = [
        ("clk            => s_clk",            "i_clk            => s_clk"),
        ("rst            => s_rst",            "i_rst            => s_rst"),
        ("alu_op         => s_alu_op",         "i_alu_op         => s_alu_op"),
        ("acc_in         => s_acc_in",         "i_acc_in         => s_acc_in"),
        ("acc_write_en   => s_acc_write_en",   "i_acc_write_en   => s_acc_write_en"),
        ("tmp_write_en   => s_tmp_write_en",   "i_tmp_write_en   => s_tmp_write_en"),
        ("flags_write_en => s_flags_write_en", "i_flags_write_en => s_flags_write_en"),
        ("acc_out        => s_acc_out",        "o_acc_out        => s_acc_out"),
        ("tmp_out        => s_tmp_out",        "o_tmp_out        => s_tmp_out"),
        ("alu_result     => s_alu_result",     "o_alu_result     => s_alu_result"),
        ("flag_z         => s_flag_z",         "o_flag_z         => s_flag_z"),
        ("flag_n         => s_flag_n",         "o_flag_n         => s_flag_n"),
        ("flag_c         => s_flag_c",         "o_flag_c         => s_flag_c"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_ras_tb():
    path = os.path.join(BASE, "ras_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Generics: ADDR_WIDTH, DATA_WIDTH -> g_addr_width, g_data_width
    # Inputs: clk, rst, read_addr, write_addr, write_data, write_en
    # Outputs: read_data
    replacements = [
        ("ADDR_WIDTH => 5", "g_addr_width => 5"),
        ("DATA_WIDTH => 20", "g_data_width => 20"),
        ("clk        => s_clk",        "i_clk        => s_clk"),
        ("rst        => s_rst",        "i_rst        => s_rst"),
        ("read_addr  => s_read_addr",  "i_read_addr  => s_read_addr"),
        ("read_data  => s_read_data",  "o_read_data  => s_read_data"),
        ("write_addr => s_write_addr", "i_write_addr => s_write_addr"),
        ("write_data => s_write_data", "i_write_data => s_write_data"),
        ("write_en   => s_write_en",   "i_write_en   => s_write_en"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_sl_tb():
    path = os.path.join(BASE, "sl_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Inputs: src_* and sel_*
    # Outputs: acc_in, ras_wr_data, io_out
    replacements = [
        ("src_acc      => s_src_acc",      "i_src_acc      => s_src_acc"),
        ("src_tmp      => s_src_tmp",      "i_src_tmp      => s_src_tmp"),
        ("src_ras      => s_src_ras",      "i_src_ras      => s_src_ras"),
        ("src_alu      => s_src_alu",      "i_src_alu      => s_src_alu"),
        ("src_io       => s_src_io",       "i_src_io       => s_src_io"),
        ("src_immed    => s_src_immed",    "i_src_immed    => s_src_immed"),
        ("sel_acc_src  => s_sel_acc_src",  "i_sel_acc_src  => s_sel_acc_src"),
        ("sel_ras_src  => s_sel_ras_src",  "i_sel_ras_src  => s_sel_ras_src"),
        ("sel_io_src   => s_sel_io_src",   "i_sel_io_src   => s_sel_io_src"),
        ("acc_in       => s_acc_in",       "o_acc_in       => s_acc_in"),
        ("ras_wr_data  => s_ras_wr_data",  "o_ras_wr_data  => s_ras_wr_data"),
        ("io_out       => s_io_out",       "o_io_out       => s_io_out"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_control_rom_sequencer_tb():
    path = os.path.join(BASE, "control_rom_sequencer_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Generics
    replacements = [
        ("CTRL_ROM_DEPTH => 256", "g_ctrl_rom_depth => 256"),
        ("DATA_ROM_DEPTH => 64", "g_data_rom_depth => 64"),
        ("UWORD_WIDTH    => 40", "g_uword_width    => 40"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    # Inputs: clk, rst, op_addr, bit_time, flag_z, flag_n, flag_c, io_ready
    # Outputs: uword, data_rom_addr, data_rom_data
    port_replacements = [
        ("clk           => s_clk",           "i_clk           => s_clk"),
        ("rst           => s_rst",           "i_rst           => s_rst"),
        ("op_addr       => s_op_addr",       "i_op_addr       => s_op_addr"),
        ("bit_time      => s_bit_time",      "i_bit_time      => s_bit_time"),
        ("flag_z        => s_flag_z",        "i_flag_z        => s_flag_z"),
        ("flag_n        => s_flag_n",        "i_flag_n        => s_flag_n"),
        ("flag_c        => s_flag_c",        "i_flag_c        => s_flag_c"),
        ("io_ready      => s_io_ready",      "i_io_ready      => s_io_ready"),
        ("uword         => s_uword",         "o_uword         => s_uword"),
        ("data_rom_addr => s_data_rom_addr", "o_data_rom_addr => s_data_rom_addr"),
        ("data_rom_data => s_data_rom_data", "o_data_rom_data => s_data_rom_data"),
    ]
    for old, new in port_replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_io_bridge_tb():
    path = os.path.join(BASE, "io_bridge_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Inputs: clk, rst, io_ctrl, io_data_in, sensor inputs
    # Outputs: io_data_out, ready, output ports
    replacements = [
        ("clk         => s_clk",         "i_clk         => s_clk"),
        ("rst         => s_rst",         "i_rst         => s_rst"),
        ("io_ctrl     => s_io_ctrl",     "i_io_ctrl     => s_io_ctrl"),
        ("io_data_in  => s_io_data_in",  "i_io_data_in  => s_io_data_in"),
        ("io_data_out => s_io_data_out", "o_io_data_out => s_io_data_out"),
        ("ready       => s_ready",       "o_ready       => s_ready"),
        # Sensor inputs
        ("altitude_in   => s_altitude_in",   "i_altitude_in   => s_altitude_in"),
        ("airspeed_in   => s_airspeed_in",   "i_airspeed_in   => s_airspeed_in"),
        ("mach_in       => s_mach_in",       "i_mach_in       => s_mach_in"),
        ("alpha_in      => s_alpha_in",      "i_alpha_in      => s_alpha_in"),
        ("total_temp_in => s_total_temp_in", "i_total_temp_in => s_total_temp_in"),
        # Output ports
        ("altitude_out   => s_altitude_out",   "o_altitude_out   => s_altitude_out"),
        ("airspeed_out   => s_airspeed_out",   "o_airspeed_out   => s_airspeed_out"),
        ("mach_out       => s_mach_out",       "o_mach_out       => s_mach_out"),
        ("alpha_out      => s_alpha_out",      "o_alpha_out      => s_alpha_out"),
        ("static_temp_out => s_static_temp_out", "o_static_temp_out => s_static_temp_out"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

def fix_cadc_top_tb():
    path = os.path.join(BASE, "cadc_top_tb.vhd")
    with open(path, 'r') as f:
        content = f.read()
    
    # Generic
    content = content.replace("CLK_DIV => 1", "g_clk_div => 1")
    
    # Inputs: clk_master, rst_n, sensor inputs
    # Outputs: all outputs
    replacements = [
        ("clk_master => s_clk_master", "i_clk_master => s_clk_master"),
        ("rst_n      => s_rst_n",      "i_rst_n      => s_rst_n"),
        # Sensor inputs
        ("altitude_in   => s_altitude_in",   "i_altitude_in   => s_altitude_in"),
        ("airspeed_in   => s_airspeed_in",   "i_airspeed_in   => s_airspeed_in"),
        ("mach_in       => s_mach_in",       "i_mach_in       => s_mach_in"),
        ("alpha_in      => s_alpha_in",      "i_alpha_in      => s_alpha_in"),
        ("total_temp_in => s_total_temp_in", "i_total_temp_in => s_total_temp_in"),
        # Outputs
        ("altitude_out    => s_altitude_out",    "o_altitude_out    => s_altitude_out"),
        ("airspeed_out    => s_airspeed_out",    "o_airspeed_out    => s_airspeed_out"),
        ("mach_out        => s_mach_out",        "o_mach_out        => s_mach_out"),
        ("alpha_out       => s_alpha_out",       "o_alpha_out       => s_alpha_out"),
        ("static_temp_out => s_static_temp_out", "o_static_temp_out => s_static_temp_out"),
    ]
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"Fixed: {path}")

if __name__ == "__main__":
    fix_timing_generator_tb()
    fix_pmu_tb()
    fix_pdu_tb()
    fix_slf_tb()
    fix_ras_tb()
    fix_sl_tb()
    fix_control_rom_sequencer_tb()
    fix_io_bridge_tb()
    fix_cadc_top_tb()
    print("Done fixing all testbenches!")

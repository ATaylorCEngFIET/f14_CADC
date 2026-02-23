#-------------------------------------------------------------------------------
# F-14A CADC Vivado Project Creation Script
# Target: Digilent Cmod A7 (xc7a35tcpg236-1)
#
# Usage: In Vivado Tcl Console:
#   cd <path_to_implementation>/scripts
#   source create_project.tcl
#-------------------------------------------------------------------------------

# Set project paths
set script_dir [file dirname [info script]]
set proj_dir [file normalize "$script_dir/../vivado_proj"]
set hdl_dir [file normalize "$script_dir/../../hdl"]
set constraints_dir [file normalize "$script_dir/../constraints"]

# Project name
set proj_name "cadc_cmoda7"

# Create project
create_project $proj_name $proj_dir -part xc7a35tcpg236-1 -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]

# Add HDL source files
add_files -norecurse [glob $hdl_dir/*.vhd]
update_compile_order -fileset sources_1

# Set CADC top as not top - we'll have a wrapper
set_property is_enabled true [get_files *cadc_top.vhd]

# Add constraints
add_files -fileset constrs_1 -norecurse $constraints_dir/cadc_cmoda7.xdc

# Create block design
source $script_dir/create_bd.tcl

# Create HDL wrapper for block design
make_wrapper -files [get_files $proj_dir/$proj_name.srcs/sources_1/bd/cadc_system/cadc_system.bd] -top
add_files -norecurse $proj_dir/$proj_name.gen/sources_1/bd/cadc_system/hdl/cadc_system_wrapper.vhd
update_compile_order -fileset sources_1

# Set wrapper as top
set_property top cadc_system_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Generate output products
generate_target all [get_files $proj_dir/$proj_name.srcs/sources_1/bd/cadc_system/cadc_system.bd]

puts "=========================================="
puts "Project created successfully!"
puts "Project location: $proj_dir"
puts "=========================================="
puts ""
puts "Next steps:"
puts "  1. Open Vivado GUI: start_gui"
puts "  2. Run Synthesis: launch_runs synth_1 -jobs 8"
puts "  3. Run Implementation: launch_runs impl_1 -jobs 8"
puts "  4. Generate Bitstream: launch_runs impl_1 -to_step write_bitstream -jobs 8"

onerror {resume}

proc run_tb {name} {
    puts "=========================================="
    puts "Running: $name"
    puts "=========================================="
    vsim -c work.$name
    run -all
    quit -sim
}

run_tb pmu_tb
run_tb pdu_tb
run_tb slf_tb
run_tb ras_tb
run_tb sl_tb
run_tb control_rom_sequencer_tb
run_tb io_bridge_tb
run_tb cadc_top_tb

quit -f

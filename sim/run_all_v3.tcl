onerror {resume}

set logfile [open "results.txt" w]

proc log_msg {msg} {
    variable logfile
    puts $logfile $msg
    puts $msg
    flush $logfile
}

proc run_tb {name timeout_ns} {
    variable logfile
    log_msg "=========================================="
    log_msg "TB: $name"
    log_msg "=========================================="

    vsim -quiet work.$name

    onbreak {resume}

    run $timeout_ns

    quit -sim
    log_msg "  finished: $name"
    log_msg ""
}

run_tb timing_generator_tb 500us
run_tb pmu_tb 100us
run_tb pdu_tb 100us
run_tb slf_tb 100us
run_tb ras_tb 100us
run_tb sl_tb 100us
run_tb control_rom_sequencer_tb 100us
run_tb io_bridge_tb 100us
run_tb cadc_top_tb 100us

close $logfile

quit -f

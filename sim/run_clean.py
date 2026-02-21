"""
Run all CADC testbenches via Questa vsim, one at a time.
Writes results to sim/results.txt.
Uses a single Tcl do-file per TB to avoid shell issues.
"""
import subprocess
import os
import sys
import time

SIM_DIR = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\sim"
VSIM = r"C:\questa_base64_2025.3\win64\vsim"
VLIB = r"C:\questa_base64_2025.3\win64\vlib"
VCOM = r"C:\questa_base64_2025.3\win64\vcom"

os.chdir(SIM_DIR)

# Kill any leftover simulator processes
os.system('taskkill /IM vsimk.exe /F 2>NUL')
os.system('taskkill /IM vish.exe /F 2>NUL')
time.sleep(2)

# Rebuild work library cleanly
import shutil
if os.path.exists("work"):
    shutil.rmtree("work", ignore_errors=True)
subprocess.run([VLIB, "work"], cwd=SIM_DIR, timeout=30)

# Compile sources
hdl_files = [
    "../hdl/timing_generator.vhd",
    "../hdl/pmu.vhd",
    "../hdl/pdu.vhd",
    "../hdl/slf.vhd",
    "../hdl/ras.vhd",
    "../hdl/sl.vhd",
    "../hdl/control_rom_sequencer.vhd",
    "../hdl/io_bridge.vhd",
    "../hdl/cadc_top.vhd",
]
r = subprocess.run(
    [VCOM, "-2008", "-work", "work"] + hdl_files,
    cwd=SIM_DIR, capture_output=True, text=True, timeout=60
)
if r.returncode != 0:
    print("HDL compile FAILED:")
    print(r.stdout)
    sys.exit(1)
print("HDL sources compiled OK")

# Compile TBs
tb_files = [
    "../tb/timing_generator_tb.vhd",
    "../tb/pmu_tb.vhd",
    "../tb/pdu_tb.vhd",
    "../tb/slf_tb.vhd",
    "../tb/ras_tb.vhd",
    "../tb/sl_tb.vhd",
    "../tb/control_rom_sequencer_tb.vhd",
    "../tb/io_bridge_tb.vhd",
    "../tb/cadc_top_tb.vhd",
]
r = subprocess.run(
    [VCOM, "-2008", "-work", "work"] + tb_files,
    cwd=SIM_DIR, capture_output=True, text=True, timeout=60
)
if r.returncode != 0:
    print("TB compile FAILED:")
    print(r.stdout)
    sys.exit(1)
print("Testbenches compiled OK")

# Run each TB
tbs = [
    ("timing_generator_tb", "500 us"),
    ("pmu_tb",              "100 us"),
    ("pdu_tb",              "100 us"),
    ("slf_tb",              "100 us"),
    ("ras_tb",              "100 us"),
    ("sl_tb",               "100 us"),
    ("control_rom_sequencer_tb", "100 us"),
    ("io_bridge_tb",        "100 us"),
    ("cadc_top_tb",         "100 us"),
]

all_results = []

for tb_name, sim_time in tbs:
    print(f"\n--- Running {tb_name} ---")
    t0 = time.time()

    # Write a temp do file
    do_file = os.path.join(SIM_DIR, "_run.do")
    with open(do_file, "w") as f:
        f.write(f"run {sim_time}\nquit -f\n")

    try:
        r = subprocess.run(
            [VSIM, "-c", "-do", "source _run.do", f"work.{tb_name}"],
            cwd=SIM_DIR, capture_output=True, text=True, timeout=600
        )
        elapsed = time.time() - t0
        output = r.stdout

        # Save full log
        with open(os.path.join(SIM_DIR, f"{tb_name}.log"), "w") as f:
            f.write(output)

        # Extract test results
        passed = []
        failed = []
        errors = []
        for line in output.splitlines():
            ls = line.strip().lstrip("# ").strip()
            if "PASSED" in ls:
                passed.append(ls)
            elif "FAILED" in ls:
                failed.append(ls)
            elif "** Error:" in line:
                errors.append(ls)

        status = "PASS" if not failed and not errors else "FAIL"
        result_line = f"{tb_name}: {status} ({len(passed)} passed, {len(failed)} failed, {len(errors)} errors, {elapsed:.1f}s)"
        print(result_line)
        all_results.append(result_line)

        # Print details for failures
        for f_line in failed:
            print(f"  FAIL: {f_line}")
            all_results.append(f"  FAIL: {f_line}")
        for e_line in errors:
            print(f"  ERR:  {e_line}")
            all_results.append(f"  ERR:  {e_line}")

    except subprocess.TimeoutExpired:
        elapsed = time.time() - t0
        result_line = f"{tb_name}: TIMEOUT ({elapsed:.1f}s)"
        print(result_line)
        all_results.append(result_line)
        os.system('taskkill /IM vsimk.exe /F 2>NUL')
        time.sleep(1)

    except Exception as e:
        result_line = f"{tb_name}: EXCEPTION ({e})"
        print(result_line)
        all_results.append(result_line)

# Write summary
summary_path = os.path.join(SIM_DIR, "results.txt")
with open(summary_path, "w") as f:
    f.write("CADC Testbench Results\n")
    f.write("=" * 60 + "\n\n")
    for line in all_results:
        f.write(line + "\n")

print(f"\n{'='*60}")
print("Summary written to results.txt")
print(f"{'='*60}")

"""
Comprehensive CADC build and simulate script.
Uses C:\temp\cadc_sim for work library to avoid Dropbox file locking.
Steps:
1. Write 4 new testbenches
2. Patch 5 existing testbenches with USE STD.ENV.ALL + STOP
3. Compile all sources
4. Run all 9 simulations
5. Write results summary
"""
import subprocess
import os
import sys
import shutil
import time
import re

VSIM = r"C:\questa_base64_2025.3\win64\vsim"
VLIB = r"C:\questa_base64_2025.3\win64\vlib"
VCOM = r"C:\questa_base64_2025.3\win64\vcom"

PROJECT_DIR = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC"
SIM_DIR = r"C:\temp\cadc_sim"
TB_DIR = os.path.join(PROJECT_DIR, "tb")
HDL_DIR = os.path.join(PROJECT_DIR, "hdl")
SCRIPT_DIR = os.path.join(PROJECT_DIR, "sim")

# Kill any existing vsim processes
os.system('taskkill /IM vsimk.exe /F 2>NUL')
os.system('taskkill /IM vish.exe /F 2>NUL')
time.sleep(2)

# Create temp sim directory
os.makedirs(SIM_DIR, exist_ok=True)
if os.path.exists(os.path.join(SIM_DIR, "work")):
    shutil.rmtree(os.path.join(SIM_DIR, "work"), ignore_errors=True)
    time.sleep(1)

print("=" * 60)
print(" Step 1: Writing 4 new testbenches")
print("=" * 60)
# Run write_testbenches_v2.py
r = subprocess.run(
    [sys.executable, os.path.join(SCRIPT_DIR, "write_testbenches_v2.py")],
    capture_output=True, text=True, timeout=30
)
print(r.stdout)
if r.returncode != 0:
    print("ERROR:", r.stderr)
    sys.exit(1)

print("=" * 60)
print(" Step 2: Patching 5 existing testbenches")
print("=" * 60)
# Run fix_termination.py
r = subprocess.run(
    [sys.executable, os.path.join(SCRIPT_DIR, "fix_termination.py")],
    capture_output=True, text=True, timeout=30
)
print(r.stdout)
if r.returncode != 0:
    print("ERROR:", r.stderr)
    sys.exit(1)

print("=" * 60)
print(" Step 3: Creating work library")
print("=" * 60)
os.chdir(SIM_DIR)
r = subprocess.run([VLIB, "work"], capture_output=True, text=True, timeout=30)
print("vlib:", "OK" if r.returncode == 0 else "FAILED")

print("=" * 60)
print(" Step 4: Compiling HDL sources")
print("=" * 60)
hdl_files = [
    os.path.join(HDL_DIR, f) for f in [
        "timing_generator.vhd", "pmu.vhd", "pdu.vhd", "slf.vhd",
        "ras.vhd", "sl.vhd", "control_rom_sequencer.vhd",
        "io_bridge.vhd", "cadc_top.vhd"
    ]
]
r = subprocess.run(
    [VCOM, "-2008", "-work", "work"] + hdl_files,
    capture_output=True, text=True, timeout=60
)
if "Errors: 0" in r.stdout:
    print("HDL compile: OK (0 errors)")
else:
    print("HDL compile FAILED:")
    print(r.stdout[-500:])
    sys.exit(1)

print("=" * 60)
print(" Step 5: Compiling testbenches")
print("=" * 60)
tb_files = [
    os.path.join(TB_DIR, f) for f in [
        "timing_generator_tb.vhd", "pmu_tb.vhd", "pdu_tb.vhd",
        "slf_tb.vhd", "ras_tb.vhd", "sl_tb.vhd",
        "control_rom_sequencer_tb.vhd", "io_bridge_tb.vhd",
        "cadc_top_tb.vhd"
    ]
]
r = subprocess.run(
    [VCOM, "-2008", "-work", "work"] + tb_files,
    capture_output=True, text=True, timeout=60
)
if "Errors: 0" in r.stdout:
    print("TB compile: OK (0 errors)")
else:
    print("TB compile FAILED:")
    print(r.stdout[-1000:])
    sys.exit(1)

print("=" * 60)
print(" Step 6: Running simulations")
print("=" * 60)

tbs = [
    ("timing_generator_tb", "500 us"),
    ("pmu_tb",              "100 us"),
    ("pdu_tb",              "100 us"),
    ("slf_tb",              "100 us"),
    ("ras_tb",              "100 us"),
    ("sl_tb",               "100 us"),
    ("control_rom_sequencer_tb", "100 us"),
    ("io_bridge_tb",        "100 us"),
    ("cadc_top_tb",         "500 us"),
]

all_results = []

for tb_name, sim_time in tbs:
    print(f"\n--- {tb_name} ---")
    t0 = time.time()

    do_content = f"run {sim_time}\nquit -f\n"
    do_path = os.path.join(SIM_DIR, "_run.do")
    with open(do_path, "w") as f:
        f.write(do_content)

    try:
        r = subprocess.run(
            [VSIM, "-c", "-do", f"source {do_path}", f"work.{tb_name}"],
            capture_output=True, text=True, timeout=600, cwd=SIM_DIR
        )
        elapsed = time.time() - t0

        # Save full log
        log_path = os.path.join(SIM_DIR, f"{tb_name}.log")
        with open(log_path, "w") as f:
            f.write(r.stdout)

        # Parse results
        passed_lines = []
        failed_lines = []
        error_lines = []
        summary_tests = ""
        summary_fails = ""

        for line in r.stdout.splitlines():
            stripped = line.strip().lstrip("# ").strip()
            if "PASSED" in stripped and "Note:" in line:
                passed_lines.append(stripped)
            elif "FAILED" in stripped:
                failed_lines.append(stripped)
            elif "** Error:" in line and "vopt" not in line and "vsim" not in line:
                error_lines.append(stripped)
            elif "Tests run:" in stripped:
                summary_tests = stripped
            elif "Failures:" in stripped:
                summary_fails = stripped

        n_passed = len(passed_lines)
        n_failed = len(failed_lines)
        n_errors = len(error_lines)

        if n_failed == 0 and n_errors == 0:
            status = "PASS"
        else:
            status = "FAIL"

        result = f"{tb_name}: {status} ({n_passed} pass, {n_failed} fail, {elapsed:.1f}s)"
        print(result)
        all_results.append(result)

        if n_failed > 0 or n_errors > 0:
            for fl in failed_lines:
                detail = f"  FAIL: {fl}"
                print(detail)
                all_results.append(detail)
            for el in error_lines:
                detail = f"  ERR:  {el}"
                print(detail)
                all_results.append(detail)

    except subprocess.TimeoutExpired:
        elapsed = time.time() - t0
        result = f"{tb_name}: TIMEOUT ({elapsed:.1f}s)"
        print(result)
        all_results.append(result)
        os.system('taskkill /IM vsimk.exe /F 2>NUL')
        time.sleep(2)

    except Exception as e:
        result = f"{tb_name}: EXCEPTION ({e})"
        print(result)
        all_results.append(result)

    # Small delay between sims to allow file cleanup
    time.sleep(1)

# Write results
print("\n" + "=" * 60)
print(" RESULTS SUMMARY")
print("=" * 60)
for line in all_results:
    print(line)

results_path = os.path.join(PROJECT_DIR, "sim", "results.txt")
with open(results_path, "w") as f:
    f.write("CADC Testbench Results\n")
    f.write("=" * 60 + "\n")
    f.write(f"Date: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
    for line in all_results:
        f.write(line + "\n")
    f.write("\n" + "=" * 60 + "\n")
    f.write("Logs in C:\\temp\\cadc_sim\\*.log\n")

print(f"\nResults written to {results_path}")
print("Logs in C:\\temp\\cadc_sim\\*.log")

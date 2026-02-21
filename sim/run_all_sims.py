"""Run all 9 testbenches via Questa and save output to log files."""
import subprocess, os, sys

VSIM = r"C:\questa_base64_2025.3\win64\vsim"
SIM_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(SIM_DIR)

tbs = [
    "timing_generator_tb",
    "pmu_tb",
    "pdu_tb",
    "slf_tb",
    "ras_tb",
    "sl_tb",
    "control_rom_sequencer_tb",
    "io_bridge_tb",
    "cadc_top_tb",
]

for tb in tbs:
    log_file = os.path.join(SIM_DIR, f"{tb}.log")
    print(f"Running {tb}...", end=" ", flush=True)
    cmd = [VSIM, "-c", "-do", f"run -all; quit -f", f"work.{tb}"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300, cwd=SIM_DIR)
        with open(log_file, "w") as f:
            f.write(result.stdout)
            if result.stderr:
                f.write("\nSTDERR:\n")
                f.write(result.stderr)
        # Count errors and notes
        errors = sum(1 for line in result.stdout.splitlines() if "** Error:" in line or "FAILED" in line)
        notes = sum(1 for line in result.stdout.splitlines() if "PASSED" in line)
        print(f"done. PASSED={notes}, Error lines={errors}")
    except subprocess.TimeoutExpired:
        print("TIMEOUT!")
    except Exception as e:
        print(f"ERROR: {e}")

print("\nAll simulations complete. Logs in sim/*.log")

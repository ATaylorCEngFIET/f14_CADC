"""Run all 9 testbenches and write summary to results.txt."""
import subprocess, os

VSIM = r"C:\questa_base64_2025.3\win64\vsim"
SIM_DIR = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\sim"
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

results = []

for tb in tbs:
    results.append(f"\n{'='*60}")
    results.append(f" {tb}")
    results.append(f"{'='*60}")
    cmd = [VSIM, "-c", "-do", "run -all; quit -f", f"work.{tb}"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300, cwd=SIM_DIR)
        for line in r.stdout.splitlines():
            line = line.strip().lstrip("# ").strip()
            if any(k in line for k in ["PASSED", "FAILED", "Error:", "Tests run", "Failures", "====", "Errors:"]):
                results.append(line)
        # Save full log
        with open(os.path.join(SIM_DIR, f"{tb}.log"), "w") as f:
            f.write(r.stdout)
    except subprocess.TimeoutExpired:
        results.append("*** TIMEOUT after 300s ***")
    except Exception as e:
        results.append(f"*** EXCEPTION: {e} ***")

# Write summary
summary_path = os.path.join(SIM_DIR, "results.txt")
with open(summary_path, "w") as f:
    f.write("\n".join(results))

print("DONE - results written to results.txt")

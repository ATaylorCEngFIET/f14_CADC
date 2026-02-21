"""Fix all 9 testbenches:
1. Add USE STD.ENV.ALL after IEEE imports
2. Replace final WAIT; with STOP; for clean simulation termination
"""
import os
import re

TB_DIR = r"c:\Users\aptay\Dropbox\adiuvo\f14-CADC\tb"

for fname in os.listdir(TB_DIR):
    if not fname.endswith("_tb.vhd"):
        continue
    path = os.path.join(TB_DIR, fname)
    with open(path, "r") as f:
        content = f.read()

    # 1. Add USE STD.ENV.ALL if not present
    if "STD.ENV" not in content:
        # Insert after the last USE IEEE... line
        content = re.sub(
            r"(USE IEEE\.NUMERIC_STD\.ALL;)",
            r"\1\nUSE STD.ENV.ALL;",
            content,
            count=1
        )

    # 2. Replace the final WAIT; before END PROCESS with STOP;
    # Match the pattern: WAIT;\n    END PROCESS or WAIT;\n  END PROCESS
    content = re.sub(
        r"(\s+)WAIT;\s*\n(\s+END PROCESS)",
        r"\1STOP;\n\2",
        content
    )

    with open(path, "w") as f:
        f.write(content)
    print(f"Patched: {fname}")

print("Done!")

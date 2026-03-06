#!/usr/bin/env python3
# cobfuscator_run.py — CLI wrapper for CObfuscator
# Usage: python3 tools/cobfuscator_run.py <input.c> <output.c>

import sys
import os

# Resolve CObfuscator path — check container path first, then host path
# Can also be overridden via COBFUSCATOR_PATH env var
COBFUSCATOR_PATH = (
    os.environ.get("COBFUSCATOR_PATH") or
    ("/opt/CObfuscator" if os.path.isdir("/opt/CObfuscator") else
     os.path.expanduser("~/tools/CObfuscator"))
)

sys.path.insert(0, COBFUSCATOR_PATH)

try:
    from CObfuscator import CObfuscator
except ImportError:
    print(f"Error: CObfuscator not found at {COBFUSCATOR_PATH}")
    print("  Install with: git clone https://github.com/AleksaZatezalo/CObfuscator.git ~/tools/CObfuscator")
    sys.exit(1)

if len(sys.argv) != 3:
    print("Usage: cobfuscator_run.py <input.c> <output.c>")
    sys.exit(1)

input_file  = sys.argv[1]
output_file = sys.argv[2]

if not os.path.isfile(input_file):
    print(f"Error: input file not found: {input_file}")
    sys.exit(1)

with open(input_file, "r") as f:
    c_code = f.read()

obfuscator = CObfuscator()
obfuscated = obfuscator.obfuscate(c_code)

with open(output_file, "w") as f:
    f.write(obfuscated)

print(f"[OK] CObfuscator: {input_file} → {output_file}")

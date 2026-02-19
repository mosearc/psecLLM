#!/usr/bin/env python3
# cobfuscator_run.py — CLI wrapper for CObfuscator
# Usage: python3 tools/cobfuscator_run.py <input.c> <output.c>

import sys
import os

# Add CObfuscator repo to path
COBFUSCATOR_PATH = os.path.expanduser("~/tools/CObfuscator")
sys.path.insert(0, COBFUSCATOR_PATH)

from CObfuscator import CObfuscator

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

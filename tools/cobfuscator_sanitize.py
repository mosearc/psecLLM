#!/usr/bin/env python3
# cobfuscator_sanitize.py — fixes known CObfuscator output bugs
# Usage: python3 tools/cobfuscator_sanitize.py <file.c>

import sys
import re

if len(sys.argv) != 2:
    print("Usage: cobfuscator_sanitize.py <file.c>")
    sys.exit(1)

path = sys.argv[1]

with open(path, 'r') as f:
    content = f.read()

original = content

# ── Fix 1: compound operators split by one or more spaces ────────────────────
def fix_operators(code):
    compound_ops = [
        (r'<\s+=',  '<='),
        (r'>\s+=',  '>='),
        (r'!\s+=',  '!='),
        (r'=\s+=',  '=='),
        (r'<\s+<',  '<<'),
        (r'>\s+>',  '>>'),
        (r'\+\s+=', '+='),
        (r'-\s+=',  '-='),
        (r'\*\s+=', '*='),
        (r'/\s+=',  '/='),
    ]
    lines = code.split('\n')
    result = []
    for line in lines:
        parts = re.split(r'("(?:[^"\\]|\\.)*")', line)
        fixed_parts = []
        for i, part in enumerate(parts):
            if i % 2 == 0:  # code part (outside quotes)
                for pattern, replacement in compound_ops:
                    part = re.sub(pattern, replacement, part)
            fixed_parts.append(part)
        result.append(''.join(fixed_parts))
    return '\n'.join(result)

content = fix_operators(content)

# ── Fix 2: variable names injected inside string literals ─────────────────────
def fix_string_literals(match):
    s = match.group(0)
    s = re.sub(r'\\_[A-Za-z_][A-Za-z0-9_]*', '', s)
    return s

content = re.sub(r'"(?:[^"\\]|\\.)*"', fix_string_literals, content)

# ── Fix 3: broken for loops ───────────────────────────────────────────────────
# CObfuscator sometimes splits for loop increment onto new lines and replaces
# it with the loop body, producing:
#
#   for (init;
#   condition;        ← or condition split across lines
#   {                 ← body wrongly placed as increment
#       ...
#   }
#
# We reconstruct it as: for (init; condition; VAR++) { ... }
# Strategy: find for( that has a { before the closing )

def fix_for_loops(code):
    lines = code.split('\n')
    result = []
    i = 0
    while i < len(lines):
        line = lines[i]

        # Detect start of a broken for loop:
        # "    for (VAR = INIT;"  with no closing )
        if re.match(r'\s*for\s*\(', line) and ')' not in line:
            for_indent = re.match(r'(\s*)', line).group(1)
            for_parts = [line.rstrip()]
            j = i + 1

            # Collect lines until we hit a { at the start (the misplaced body)
            condition_lines = []
            while j < len(lines):
                next_line = lines[j].strip()
                if next_line == '{':
                    # This { is the misplaced loop body — collect body until }
                    body_lines = []
                    j += 1
                    depth = 1
                    while j < len(lines) and depth > 0:
                        bl = lines[j]
                        depth += bl.count('{') - bl.count('}')
                        if depth > 0:
                            body_lines.append(bl)
                        j += 1

                    # Extract init and condition from collected for_parts
                    for_text = ' '.join(p.strip() for p in for_parts)
                    # for_text looks like: for (VAR = INIT; CONDITION;
                    # We need to find the loop variable for the increment
                    m = re.match(r'for\s*\(\s*(\w+)\s*=', for_text)
                    if m:
                        var = m.group(1)
                        increment = f'{var}++'
                    else:
                        increment = ''

                    # Strip trailing semicolon/whitespace from for_text
                    for_text = for_text.rstrip('; \t')
                    reconstructed = f'{for_indent}{for_text}; {increment})'
                    result.append(reconstructed)
                    result.append(f'{for_indent}{{')
                    result.extend(body_lines)
                    result.append(f'{for_indent}}}')
                    i = j
                    break
                else:
                    condition_lines.append(lines[j])
                    for_parts.append(lines[j])
                    j += 1
            else:
                # No broken body found — output as-is
                result.append(line)
                i += 1
        else:
            result.append(line)
            i += 1

    return '\n'.join(result)

content = fix_for_loops(content)

if content != original:
    with open(path, 'w') as f:
        f.write(content)
    print(f"[OK] Sanitized: {path}")
else:
    print(f"[OK] No issues found: {path}")

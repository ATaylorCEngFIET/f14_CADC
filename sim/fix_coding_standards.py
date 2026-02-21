"""
Fix 5 clean testbench files to follow coding standards:
1. Uppercase VHDL reserved words
2. Uppercase STD.STANDARD identifiers
3. Change architecture name from 'sim' to 'bench'
4. Ensure pure ASCII
"""
import re
import os

# VHDL reserved words (must be UPPERCASE per coding standard)
RESERVED = {
    'abs', 'access', 'after', 'alias', 'all', 'and', 'architecture',
    'array', 'assert', 'attribute',
    'begin', 'block', 'body', 'buffer', 'bus',
    'case', 'component', 'configuration', 'constant',
    'disconnect', 'downto',
    'else', 'elsif', 'end', 'entity', 'exit',
    'file', 'for', 'function',
    'generate', 'generic', 'group', 'guarded',
    'if', 'impure', 'in', 'inertial', 'inout', 'is',
    'label', 'library', 'linkage', 'literal', 'loop',
    'map', 'mod',
    'nand', 'new', 'next', 'nor', 'not', 'null',
    'of', 'on', 'open', 'or', 'others', 'out',
    'package', 'port', 'postponed', 'procedure', 'process', 'pure',
    'range', 'record', 'register', 'reject', 'rem', 'report', 'return',
    'rol', 'ror',
    'select', 'severity', 'signal', 'shared',
    'sla', 'sll', 'sra', 'srl', 'subtype',
    'then', 'to', 'transport', 'type',
    'unaffected', 'units', 'until', 'use',
    'variable',
    'wait', 'when', 'while', 'with',
    'xnor', 'xor',
}

# STD.STANDARD identifiers (must be UPPERCASE per coding standard)
STD_STANDARD = {
    'boolean', 'integer', 'natural', 'positive', 'real', 'time',
    'string', 'character', 'note', 'error', 'warning', 'failure',
    'true', 'false', 'now', 'severity_level', 'delay_length',
}

ALL_UPPER = RESERVED | STD_STANDARD

def process_line(line):
    """Process a single line, uppercasing keywords outside strings/comments."""
    # Find comment start
    comment_start = None
    in_string = False
    for i, ch in enumerate(line):
        if ch == '"' and not in_string:
            in_string = True
        elif ch == '"' and in_string:
            in_string = False
        elif ch == '-' and i + 1 < len(line) and line[i+1] == '-' and not in_string:
            comment_start = i
            break

    if comment_start is not None:
        code_part = line[:comment_start]
        comment_part = line[comment_start:]
    else:
        code_part = line
        comment_part = ''

    # Process code part: uppercase keywords at word boundaries, but not inside strings
    result = []
    i = 0
    in_str = False
    while i < len(code_part):
        ch = code_part[i]
        if ch == '"':
            in_str = not in_str
            result.append(ch)
            i += 1
        elif in_str:
            result.append(ch)
            i += 1
        elif ch.isalpha() or ch == '_':
            # Read the full identifier
            j = i
            while j < len(code_part) and (code_part[j].isalnum() or code_part[j] == '_'):
                j += 1
            word = code_part[i:j]
            if word.lower() in ALL_UPPER:
                result.append(word.upper())
            else:
                result.append(word)
            i = j
        else:
            result.append(ch)
            i += 1

    return ''.join(result) + comment_part


def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        # Strip non-ASCII
        clean = ''.join(ch if ord(ch) < 128 else '?' for ch in line)
        processed = process_line(clean)
        new_lines.append(processed)

    content = ''.join(new_lines)

    # Fix architecture name: sim -> bench
    content = re.sub(
        r'(?i)\barchitecture\s+sim\b',
        'ARCHITECTURE bench',
        content
    )
    content = re.sub(
        r'(?i)\bend\s+architecture\s+sim\b',
        'END ARCHITECTURE bench',
        content
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Fixed: {os.path.basename(filepath)}")


tb_dir = os.path.join(os.path.dirname(__file__), '..', 'tb')
files_to_fix = [
    'pdu_tb.vhd',
    'ras_tb.vhd',
    'control_rom_sequencer_tb.vhd',
    'io_bridge_tb.vhd',
    'cadc_top_tb.vhd',
]

for fn in files_to_fix:
    fp = os.path.join(tb_dir, fn)
    if os.path.exists(fp):
        fix_file(fp)
    else:
        print(f"NOT FOUND: {fn}")

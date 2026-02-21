import os, glob

replacements = {
    '\u2192': '->',   # →
    '\u2248': '~',    # ≈
    '\u2264': '<=',   # ≤
    '\u03a6': 'Phi',  # Φ
    '\u00d7': 'x',    # ×
    '\u2014': '--',   # —
    '\u2013': '-',    # –
    '\u201c': '"',    # "
    '\u201d': '"',    # "
    '\u2018': "'",    # '
    '\u2019': "'",    # '
    '\u00b1': '+/-',  # ±
    '\u00b0': 'deg',  # °
    '\u03bc': 'u',    # μ
    '\u2026': '...',  # …
    '\u00ab': '<<',   # «
    '\u00bb': '>>',   # »
    '\u2022': '*',    # •
}

tb_dir = os.path.join(os.path.dirname(__file__), '..', 'tb')
for f in glob.glob(os.path.join(tb_dir, '*.vhd')):
    with open(f, 'r', encoding='utf-8') as fh:
        text = fh.read()
    original = text
    for uchar, replacement in replacements.items():
        text = text.replace(uchar, replacement)
    # Also strip any remaining non-ASCII in string literals
    # Replace any remaining non-ASCII with '?'
    cleaned = []
    for ch in text:
        if ord(ch) > 127:
            cleaned.append('?')
        else:
            cleaned.append(ch)
    text = ''.join(cleaned)
    if text != original:
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write(text)
        print(f"Fixed: {os.path.basename(f)}")
    else:
        print(f"No changes: {os.path.basename(f)}")

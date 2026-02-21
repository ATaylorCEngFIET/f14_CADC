import os, glob
tb = os.path.join(os.path.dirname(__file__), '..', 'tb')
for f in sorted(glob.glob(os.path.join(tb, '*.vhd'))):
    data = open(f, 'rb').read()
    count = sum(1 for b in data if b > 127)
    print(f"{os.path.basename(f)}: {count} non-ASCII bytes")

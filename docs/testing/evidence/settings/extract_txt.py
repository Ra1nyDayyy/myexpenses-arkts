import json, sys
def extract(path):
    with open(path) as f:
        d = json.load(f)
    out = []
    def w(n):
        if not isinstance(n, dict):
            return
        t = n.get('attributes', {}).get('text', '')
        if t:
            out.append(t)
        for c in n.get('children', []):
            w(c)
    w(d)
    return out
p = sys.argv[1]
dst = p + '.txt'
lines = extract(p)
with open(dst, 'w') as f:
    f.write('\n'.join(lines))
print(len(lines))
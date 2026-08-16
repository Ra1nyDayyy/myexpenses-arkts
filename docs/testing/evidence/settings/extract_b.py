import json, sys

def extract_bounds(path):
    with open(path) as f:
        d = json.load(f)
    out = []
    def w(n):
        if not isinstance(n, dict):
            return
        a = n.get('attributes', {})
        t = a.get('text', '')
        b = a.get('bounds', '')
        if t:
            out.append(b + ' | ' + t)
        for c in n.get('children', []):
            w(c)
    w(d)
    return out

if __name__ == '__main__':
    p = sys.argv[1]
    lines = extract_bounds(p)
    out_path = p + '.out.txt'
    with open(out_path, 'w') as f:
        f.write('\n'.join(lines))
    print(out_path)
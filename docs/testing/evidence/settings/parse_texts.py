import json, glob, os, sys
def texts(path):
    d = json.load(open(path))
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
    return ' | '.join(out)
def texts_bounds(path):
    d = json.load(open(path))
    out = []
    def w(n):
        if not isinstance(n, dict):
            return
        a = n.get('attributes', {})
        t = a.get('text', '')
        b = a.get('bounds', '')
        if t:
            out.append(f'[{b}] {t}')
        for c in n.get('children', []):
            w(c)
    w(d)
    return out
if __name__ == '__main__':
    args = sys.argv[1:]
    if not args:
        print('usage: python3 parse_texts.py <jsonfile> [--bounds]')
        sys.exit(0)
    p = args[0]
    if 'bounds' in args:
        res = texts_bounds(p)
    else:
        res = [texts(p)]
    for r in res:
        print(r)
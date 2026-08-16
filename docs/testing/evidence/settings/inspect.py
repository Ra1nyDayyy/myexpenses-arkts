import json, sys, os

for p in sys.argv[1:]:
    if not os.path.exists(p):
        print(p, 'MISSING')
        continue
    size = os.path.getsize(p)
    if size == 0:
        print(p, 'EMPTY')
        continue
    try:
        with open(p) as f:
            d = json.load(f)
    except Exception as e:
        print(p, 'BADJSON', e)
        continue
    texts = []
    page = None
    def w(n):
        nonlocal page
        if not isinstance(n, dict):
            return
        a = n.get('attributes', {})
        if a.get('pagePath'):
            page = a.get('pagePath')
        t = a.get('text', '')
        if t:
            texts.append(t)
        for c in n.get('children', []):
            w(c)
    w(d)
    print('===', p, 'size', size, 'page', page, 'ntexts', len(texts))
    print(' | '.join(texts[:25]))
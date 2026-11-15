import re
def parse_inserts(path, tables):
    """Yield (table, row tuple) for INSERT statements of the given tables in a MySQL dump."""
    cols = {}
    cur_create = None
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            if line.startswith('CREATE TABLE `'):
                cur_create = line.split('`')[1]
                cols[cur_create] = []
                continue
            if cur_create:
                m = re.match(r'\s*`(\w+)`', line)
                if m:
                    cols[cur_create].append(m.group(1))
                elif line.startswith(')'):
                    cur_create = None
                continue
            if not line.startswith('INSERT INTO `'):
                continue
            t = line.split('`')[1]
            if t not in tables:
                continue
            body = line[line.index('VALUES') + 6:]
            for row in parse_values(body):
                yield t, cols[t], row

def parse_values(s):
    i, n = 0, len(s)
    rows = []
    while i < n:
        c = s[i]
        if c == '(':
            i += 1
            row = []
            while True:
                while s[i] == ' ': i += 1
                if s[i] == "'":
                    i += 1
                    buf = []
                    while True:
                        ch = s[i]
                        if ch == '\\':
                            nx = s[i + 1]
                            buf.append({'n': '\n', 'r': '\r', 't': '\t', '0': '\0'}.get(nx, nx))
                            i += 2
                        elif ch == "'":
                            if i + 1 < n and s[i + 1] == "'":
                                buf.append("'"); i += 2
                            else:
                                i += 1; break
                        else:
                            buf.append(ch); i += 1
                    row.append(''.join(buf))
                else:
                    j = i
                    while s[j] not in ',)': j += 1
                    tok = s[i:j].strip()
                    i = j
                    if tok == 'NULL': row.append(None)
                    else:
                        try:
                            row.append(int(tok))
                        except ValueError:
                            row.append(float(tok))
                if s[i] == ',':
                    i += 1; continue
                if s[i] == ')':
                    i += 1; break
            rows.append(row)
        else:
            i += 1
    return rows

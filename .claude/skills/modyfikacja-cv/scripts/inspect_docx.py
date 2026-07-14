# -*- coding: utf-8 -*-
"""Zrzut zawartości .docx pod modyfikację CV.

Wypisuje:
- tekst dokumentu (word/document.xml),
- etykiety i wartości wykresów (word/charts/chart*.xml) — w szablonach CV
  umiejętności bywają słupkami wykresu, nie zwykłym tekstem,
- obecność pól tekstowych (textboxów) i osadzonych arkuszy,
- listę plików w archiwum.

Użycie:
    python inspect_docx.py <sciezka_do.docx> [--out plik.txt]

Zapis do pliku (--out) jest w UTF-8 i pozwala uniknąć psucia polskich znaków
przez konsolę Windows (cp1250).
"""
import html
import re
import sys
import zipfile


def _strip(t):
    t = re.sub(r'</w:p>', '\n', t)
    t = re.sub(r'<w:tab[^>]*/>', ' | ', t)
    t = re.sub(r'<[^>]+>', '', t)
    return html.unescape(t)


def inspect(path):
    out = []
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        out.append('=== PLIKI W ARCHIWUM ===')
        out.append('\n'.join(names))

        out.append('\n\n=== TEKST DOKUMENTU (word/document.xml) ===')
        doc = z.read('word/document.xml').decode('utf-8')
        out.append('\n'.join(l for l in _strip(doc).splitlines() if l.strip()))

        has_txbx = '<w:txbxContent>' in doc or 'mc:AlternateContent' in doc
        out.append('\n=== POLA TEKSTOWE (textboxy) ===')
        out.append('obecne — tekst może być poza document.paragraphs'
                   if has_txbx else 'brak wykrytych')

        charts = [n for n in names if re.match(r'word/charts/chart\d+\.xml$', n)]
        for c in charts:
            cx = z.read(c).decode('utf-8')
            cats = re.findall(r'<c:pt idx="\d+"><c:v>(.*?)</c:v></c:pt>',
                              cx.split('</c:cat>')[0] if '</c:cat>' in cx else '')
            vals = re.findall(r'<c:pt idx="\d+"><c:v>(.*?)</c:v></c:pt>',
                              cx.split('</c:cat>')[1] if '</c:cat>' in cx else '')
            out.append('\n=== WYKRES %s ===' % c)
            for i, lab in enumerate(cats):
                v = vals[i] if i < len(vals) else '?'
                out.append('  %-45s %s' % (html.unescape(lab), v))

        emb = [n for n in names if 'embeddings' in n]
        if emb:
            out.append('\n=== OSADZONE ARKUSZE ===')
            out.append('\n'.join(emb))
    return '\n'.join(out)


def main(argv):
    if not argv:
        print('Użycie: python inspect_docx.py <plik.docx> [--out plik.txt]')
        return 1
    path = argv[0]
    result = inspect(path)
    if '--out' in argv:
        dest = argv[argv.index('--out') + 1]
        with open(dest, 'w', encoding='utf-8') as f:
            f.write(result)
        print('Zapisano do', dest)
    else:
        print(result)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

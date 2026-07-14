# Wzorce edycji XML dokumentu Word (.docx)

`.docx` to archiwum ZIP. Kluczowe wpisy:

- `word/document.xml` — treść (akapity `<w:p>`, runy `<w:r>`, tekst `<w:t>`).
- `word/charts/chart*.xml` — wykresy (np. słupki umiejętności) z cache danych.
- `word/embeddings/*.xlsx` — arkusze źródłowe wykresów (do wyświetlenia nie trzeba ich ruszać).
- `word/styles.xml`, `word/numbering.xml` — style i listy numerowane/punktowane.

Edytuj przez helpery z `scripts/docx_edit.py`. Poniżej wzorce i pułapki.

## Dlaczego runy bywają porozbijane

Jeden zdaniowy tekst potrafi być rozcięty na kilka `<w:r>` przez znaczniki
sprawdzania pisowni (`<w:proofErr .../>`) i różne `w:rsid`. Dlatego **nie** próbuj
podmieniać fragmentu jednego runa — przepisz cały akapit funkcją `rebuild_para`,
która zostawia `<w:pPr>` (formatowanie akapitu), a runy zastępuje Twoimi.

```python
doc = rebuild_para(doc, 'Jestem ambitnym', run(nowy_profil, sz=18))
```

`run(text, sz, bold, font)` sam escapuje znaki `& < >` (np. „J&J" → „J&amp;J").
`sz` jest w half-points: 18 = 9pt, 20 = 10pt, 28 = 14pt.

## Pole „stanowisko docelowe"

Zwykle krótki akapit u góry. Znajdź go po fragmencie tekstu i przepisz:

```python
doc = rebuild_para(doc, '<fragment starego tekstu>',
                   run('Aplikacja na stanowisko: <TYTUŁ Z OFERTY>', bold=True))
```

## Dodanie pozycji do listy (kursy, osiągnięcia, bullety)

Elementy listy mają w `<w:pPr>` styl i numerację, np.:

```xml
<w:pPr><w:pStyle w:val="Akapitzlist"/>
  <w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>
  <w:spacing w:after="120"/><w:ind w:left="428"/>
  <w:rPr><w:rFonts w:ascii="Candara" w:hAnsi="Candara"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
</w:pPr>
```

Nie wymyślaj tego `pPr` — **sklonuj z istniejącego bulletu** i wstaw nowy akapit po nim:

```python
ppr = get_ppr(doc, '<tekst sąsiedniego bulletu>')
nowy = list_item('Treść nowego punktu...', ppr, para_id='41C4B0F1')
doc = insert_after_para(doc, '<tekst sąsiedniego bulletu>', nowy)
```

`w14:paraId` powinien być unikalny — nadaj własny hex (Word i tak toleruje duplikaty,
ale lepiej unikać). Wstawiając kilka punktów, dawaj różne id.

## Dodanie słupka do wykresu umiejętności

Wykres słupkowy trzyma dane w cache: kategorie w `<c:cat>` (strCache) i wartości
w `<c:val>` (numCache), każdy z `<c:ptCount>` i punktami `<c:pt idx="…">`.
Aby dodać słupek trzeba: zwiększyć `ptCount`, dopisać `<c:pt>` na końcu i rozszerzyć
zakres (`$A$2:$A$8` → `$A$2:$A$9`). Robi to jedna funkcja:

```python
ch = get_xml(entries, 'word/charts/chart2.xml')
ch = add_chart_bar(ch, 'n8n (automatyzacja i integracja)', 8)   # etykieta, poziom
set_xml(entries, ch, 'word/charts/chart2.xml')
```

Wartość dobierz spójnie ze skalą pozostałych słupków (np. 1–10). Pamiętaj, że dodanie
słupka do wykresu o stałej wysokości lekko zagęszcza sekcję — jeśli słupków robi się
dużo, rozważ podmianę mniej istotnego zamiast dodawania.

Który wykres jest który: `inspect_docx.py` wypisuje etykiety każdego `chart*.xml`.
Umiejętności twarde (SQL, Power BI, PL/SQL…) to zwykle jeden wykres, a miękkie
(współpraca, kreatywność…) drugi.

## Przepakowanie i walidacja

Zawsze przepakowuj kopiując **wszystkie** wpisy w oryginalnej kolejności i podmieniając
tylko zmienione XML (`load` → edycja → `save`). Potem:

```python
print(validate(cv_path))            # minidom parsuje każdy xml + python-docx otwiera
```

Do podglądu treści zapisuj do pliku UTF‑8 (nie polegaj na wydruku w konsoli Windows):

```python
open('podglad.txt', 'w', encoding='utf-8').write(extract_text(cv_path))
```

## Znak myślnika i twarde znaki

Do wtrąceń używaj półpauzy „–" (U+2013). Uważaj na przypadkowe wklejenie twardego
łącznika (U+2011) lub twardej spacji — są poprawne w Wordzie, ale rozjeżdżają wykrywanie
i wyglądają niespójnie; jeśli reszta CV używa zwykłego „-", trzymaj się jego.

---
name: modyfikacja-cv
description: >-
  Dopasowuje istniejące CV w formacie .docx do konkretnej oferty pracy podanej
  jako link (URL). Użyj tego skilla ZAWSZE, gdy użytkownik prosi o zmodyfikowanie,
  dostosowanie, "podrasowanie" lub przygotowanie CV/résumé pod ogłoszenie o pracę
  (np. z pracuj.pl, LinkedIn, justjoin.it, theprotocol.it), wkleja link do oferty
  i plik .docx, chce dodać umiejętności/certyfikaty pod kątem rekrutacji, albo
  chce, żeby CV przechodziło weryfikację ATS / agentów sprawdzających zgłoszenia.
  Działa nawet, gdy użytkownik nie napisze wprost "ATS" ani "dopasuj" — wystarczy
  intencja "zmień moje CV pod tę ofertę".
---

# Modyfikacja CV pod ofertę pracy

Ten skill dostosowuje CV (`.docx`) do konkretnego ogłoszenia: pobiera treść oferty,
mapuje doświadczenie kandydata na jej wymagania, nasyca CV słowami kluczowymi
weryfikowanymi przez ATS i wprowadza precyzyjne zmiany bezpośrednio w XML pliku
Word — z zachowaniem układu, wykresów i formatowania.

## Parametry

Ustal je na starcie (dopytaj tylko o brakujące — resztę wywnioskuj z rozmowy):

- **`job_offer_url`** (wymagany) — link do ogłoszenia o pracę.
- **`cv_path`** (wymagany) — ścieżka do pliku `.docx` z CV.
- **`zmiany`** (opcjonalny) — dodatkowe rzeczy do uwzględnienia, które nie wynikają
  z samej oferty (np. „dodaj znajomość n8n — mam certyfikat", „dopisz certyfikat
  Claude Code", „rozwijam się w Power BI").

## Zasady nadrzędne

- **Nie zmyślaj.** Nie dopisuj technologii, systemów ani certyfikatów, których
  kandydat nie ma. Jeśli oferta wymienia np. SAP HR / Workday, a kandydat zna tylko
  TETA — zostaw TETA. Fałszywe słowa kluczowe wywalają CV na weryfikacji u człowieka.
- **Prawda + trafność.** Eksponuj realne dopasowania (np. „TETA" ↔ „systemy HR klasy
  ERP"), przeformułowując je językiem oferty.
- **Zachowaj układ.** CV to często szablon z tabelami, polami tekstowymi i wykresami.
  Edytuj przez celowane podmiany w rozpakowanym XML, a **nie** przez `python-docx`
  (ono nie widzi tekstu w textboxach ani na wykresach).
- **Zwięźle.** Dodawaj treść gęstą znaczeniowo, nie rozdmuchuj CV.

## Przebieg (kroki)

Wykonuj po kolei. Skrypty pomocnicze są w `scripts/`; szczegóły edycji XML w
`references/docx-editing.md`, a pobieranie ofert w `references/fetching-offers.md`.

### 1. Backup
Skopiuj oryginał CV do katalogu scratchpad (np. `<scratchpad>/CV_ORYGINAL.docx`),
zanim cokolwiek zmienisz. Edycje robimy in-place, więc kopia to bezpiecznik.

### 2. Zbadaj CV
Uruchom `python scripts/inspect_docx.py <cv_path>`. Zobaczysz:
- tekst całego dokumentu (akapity, listy),
- etykiety i wartości **wykresów** (`word/charts/chart*.xml`) — w szablonach CV
  umiejętności bywają słupkami wykresu, nie tekstem,
- informację, czy są pola tekstowe (textboxy) i osadzone arkusze.

Zapamiętaj, gdzie leżą: profil/podsumowanie, sekcja umiejętności (tekst czy wykres),
kursy/certyfikaty, doświadczenie/osiągnięcia, pole „stanowisko docelowe".

> Uwaga na polskie znaki: terminal na Windows (cp1250) potrafi wyświetlać `�`.
> To tylko artefakt wypisywania — plik jest w UTF‑8. Do podglądu zapisuj tekst do
> pliku `.txt` w UTF‑8 i czytaj go, zamiast polegać na wydruku w konsoli.

### 3. Pobierz treść oferty
Z `job_offer_url` wyciągnij: **stanowisko, firmę, obowiązki, wymagania, technologie,
benefity** i wszystkie **słowa kluczowe**.

Spróbuj najpierw `WebFetch`. Portale pracy (zwłaszcza pracuj.pl) często zwracają
403 lub przekierowują na stronę logowania — wtedy użyj przeglądarki Playwright.
Szczegóły i pułapki (redirect na `/konto`, potrzeba dwóch prób) →
`references/fetching-offers.md`.

### 4. Zmapuj kandydata na ofertę
Wypisz sobie: wymaganie oferty → dowód w CV (mocne / słabe / brak). To podstawa
zarówno treści, jak i doboru słów kluczowych. Zaznacz najmocniejsze dopasowania —
one trafią do profilu i pierwszych bulletów doświadczenia.

### 5. Wprowadź zmiany w XML
Rozpakuj `document.xml` i `chart*.xml`, zmodyfikuj, przepakuj. Użyj helperów z
`scripts/docx_edit.py` (funkcje `load`, `rebuild_para`, `insert_after_para`, `run`,
`add_chart_bar`, `save`). Wzorce i przykłady → `references/docx-editing.md`.

Typowy zestaw edycji:
- **Pole „stanowisko docelowe"** → nazwa stanowiska z oferty.
- **Profil/podsumowanie** → przepisany pod rolę: tytuł stanowiska (analityk…),
  kluczowe systemy (np. TETA/HR ERP), obszar danych, środowisko (międzynarodowe/
  rozproszone), języki, poziom angielskiego, plus rzeczy z `zmiany`.
- **Umiejętności** → jeśli to wykres, dodaj słupek przez `add_chart_bar`
  (kategoria + wartość + `ptCount` + zakres). Jeśli tekst — dopisz pozycję.
- **Kursy/certyfikaty** → dodaj/uzupełnij (np. certyfikat + nazwa szkoły).
- **Doświadczenie/osiągnięcia** → dodaj zwięzłe bullety w istniejącym stylu listy
  (`w:pStyle`, `w:numPr`) nasycone słowami kluczowymi oferty; opisz realne wdrożenia.

### 6. Pokrycie słów kluczowych (ATS)
Zbierz listę fraz z sekcji „wymagania" i „obowiązki" oferty i upewnij się, że każda
występuje w CV — **w naturalnej, odmienionej formie** (ATS dopasowuje po rdzeniu, więc
„analityka systemowego" pokrywa „analityk systemowy"). Rozłóż je między profil,
umiejętności i bullety doświadczenia, zamiast wciskać wszystkie w jedno miejsce.
Zweryfikuj skryptem porównującym listę fraz z tekstem CV (patrz krok 7).

### 7. Walidacja
- `docx_edit.validate(cv_path)` → każdy `.xml` parsuje się (minidom) i `python-docx`
  otwiera plik.
- Wypisz do pliku UTF‑8 kluczowe fragmenty (profil, nowe bullety, etykiety wykresu)
  i przeczytaj je, sprawdzając polskie znaki i sens.
- Policz pokrycie słów kluczowych (dopasowanie po rdzeniu / z uwzględnieniem odmiany).

### 8. Sprzątanie i podsumowanie
Usuń pliki tymczasowe utworzone w katalogu projektu (np. `.playwright-mcp/`,
pliki `.md` ze snapshotami, robocze `.txt`). Podsumuj użytkownikowi: co zmieniłeś,
gdzie jest backup, jakie słowa kluczowe pokryto i o czym warto sprawdzić ręcznie
(np. czy dodane bullety nie rozbijają układu na strony).

## Skrypty i materiały

- `scripts/inspect_docx.py` — zrzut tekstu + etykiet wykresów + wykrycie textboxów.
- `scripts/docx_edit.py` — biblioteka helperów do edycji i przepakowania `.docx`
  oraz walidacji i ekstrakcji tekstu.
- `references/docx-editing.md` — wzorce edycji XML Worda (akapity, listy, wykresy).
- `references/fetching-offers.md` — pobieranie ofert (WebFetch → Playwright, pracuj.pl).

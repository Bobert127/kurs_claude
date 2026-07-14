# Pobieranie treści ogłoszenia o pracę

Cel: z `job_offer_url` wydobyć stanowisko, firmę, obowiązki, wymagania, technologie,
benefity i słowa kluczowe.

## Kolejność prób

### 1. WebFetch (najtańsze)
Spróbuj najpierw:

```
WebFetch(url, "Wyodrębnij pełny opis oferty: stanowisko, firma, wymagane
umiejętności, obowiązki, kwalifikacje, technologie i słowa kluczowe. Wypisz
szczegółowo.")
```

Działa dla wielu prostych stron. Jeśli zwróci **403 Forbidden** albo poprosi o
logowanie/redirect — przejdź do Playwright.

### 2. Playwright (portale z ochroną / logowaniem)
Portale pracy (szczególnie **pracuj.pl**) blokują WebFetch. Użyj przeglądarki:

```
browser_navigate(url)
browser_snapshot(filename='offer.md')   # zrzut accessibility do pliku
```

Potem przeczytaj zapisany plik snapshotu (`Read`) i wyłuskaj treść.

Ważne pułapki pracuj.pl:
- Pierwszy snapshot potrafi wylądować na `/konto` (pulpit zalogowanego użytkownika),
  bo strona przekierowuje. **Zanawiguj na URL oferty ponownie** i zrób snapshot drugi
  raz — za drugim razem zwykle renderuje się właściwa oferta.
- Właściwa treść jest w sekcjach: „Twój zakres obowiązków", „Nasze wymagania",
  „Technologie, których używamy", „To oferujemy", „Benefity", „Dodatkowe informacje"
  (Specjalizacje). Tytuł strony zawiera stanowisko i firmę.
- Snapshot zawiera dużo szumu (menu, stopka, podobne oferty) — bierz tylko sekcje oferty.
- Na końcu **zamknij przeglądarkę** (`browser_close`).

## Co wyciągnąć i jak wykorzystać

Zbierz w jedną listę frazy z „Nasze wymagania" i „Twój zakres obowiązków" — to są
słowa kluczowe weryfikowane przez ATS/agentów rekrutacyjnych. Przykładowe rodziny
fraz dla ról analitycznych/IT:

- role: analityk systemowy / biznesowy / danych,
- systemy: HR klasy ERP (i konkretne nazwy — dopasuj tylko te, które kandydat zna),
- dane: operacyjna baza danych, dane referencyjne, słowniki, kontrola jakości danych,
- proces: RFI/RFP, wymagania niefunkcjonalne, dokumentacja analityczna/architektoniczna,
  interfejsy i integracja systemów, koncepcje zmian, szacowanie złożoności,
- kontekst: projekty międzynarodowe, środowisko rozproszone, angielski B2,
  pakiet Office (Teams, Excel, PowerPoint, Word).

Te frazy wpleć w profil i bullety doświadczenia (krok 5 i 6 w SKILL.md) — w naturalnej,
odmienionej formie, bez zmyślania kompetencji.

## Sprzątanie
Playwright zostawia w katalogu projektu `.playwright-mcp/` oraz zapisane snapshoty
(`*.md`). Usuń je po zakończeniu, żeby nie zaśmiecać repo.

# Dokumentacja: Workflow n8n – Formularz Rejestracji na Szkolenie

Plik do importu: **`formularz-rejestracji-n8n-workflow.json`**
Import: n8n → menu (⋮) w prawym górnym rogu → **Import from File** → wskaż plik.

Workflow realizuje wszystkie trzy poziomy z Twojej checklisty (podstawowy, średni,
zaawansowany) w jednym spójnym przepływie. Wewnątrz workflow znajdują się też
**sticky notes** z krótkimi opisami — ten dokument je rozszerza.

---

## Schemat przepływu (ogólnie)

```
Formularz Rejestracji
        │
IF - Waliduj Email ──(false)──> Set Błąd Email ─> HTML błędu ─> Respond (błąd)
        │(true)
Set - Generuj ID i Timestamp
        │
Set - Transformacje Danych (telefon, deadline)
        │
Code - Walidacja NIP (opcjonalna)
        │
Set - Symulacja Liczby Zapisów  (⚠ dane na sztywno)
        │
Code - Oblicz Statystyki (Agregacja)
        │
IF - Sprawdź Limit Miejsc ──(brak miejsc)──> Set Waitlist ─> HTML waitlist ─> Respond (waitlist)
        │(są miejsca)
HTTP Request - Generuj PDF (html2pdf.app)
        │
Code - PDF do Base64
        │
Code - Buduj HTML Potwierdzenia
        │
Respond to Webhook - Potwierdzenie
```

---

## Ważne ustalenia z rozmowy (Twoje decyzje)

| Pytanie | Decyzja |
|---|---|
| Skąd dane o liczbie zapisów (limit 20)? | **Dane na sztywno** w węźle `Set - Symulacja Liczby Zapisów` (symulacja, bez bazy danych) |
| Generowanie PDF? | **Tak** — przez zewnętrzne API `html2pdf.app` (musisz wstawić własny klucz API) |
| Wysyłka e-mail? | **Nie** — tylko odpowiedź HTML w przeglądarce (PDF pobierany bezpośrednio jako link `data:` w stronie potwierdzenia) |

---

## Opis węzłów

### 1. `Formularz Rejestracji` (Form Trigger)
Punkt wejścia workflow. Generuje publiczny formularz WWW z polami:

| Pole | Typ | Wymagane |
|---|---|---|
| Imię i nazwisko | tekst | tak |
| Email | email | tak |
| Telefon | tekst | tak |
| Firma | tekst | tak |
| NIP firmy (opcjonalnie) | tekst | nie |
| Termin szkolenia | dropdown (3 przykładowe terminy) | tak |
| Zgoda RODO | checkbox | tak |

**Response Mode = `responseNode`** — to kluczowe ustawienie: oznacza, że
odpowiedź do przeglądarki nie jest generowana automatycznie przez trigger,
tylko przez dedykowany węzeł `Respond to Webhook` gdzieś dalej w workflow.
Dzięki temu możemy zwrócić w pełni ostylowaną stronę HTML zamiast domyślnego
ekranu „Form Submitted”.

> Terminy szkoleń w dropdownie są przykładowe — podmień je na własne dni.

---

### 2. `IF - Waliduj Email`
Sprawdza, czy pole Email zawiera jednocześnie znak `@` i kropkę `.`.
- **true** → dane przechodzą dalej,
- **false** → gałąź błędu.

### 3a. Gałąź błędu: `Set - Błąd Email` → `Code - Buduj HTML Błędu` → `Respond to Webhook - Błąd`
Ustawia status `BLAD_EMAIL`, buduje prostą stronę HTML z komunikatem i zwraca
ją użytkownikowi (kod odpowiedzi HTTP 200, ale treść informuje o błędzie —
w razie potrzeby możesz w węźle Respond dodać kod 400 w opcjach).

---

### 4. `Set - Generuj ID i Timestamp`
- `id_uczestnika` – format `SZK-YYYYMM-<execution.id>` (np. `SZK-202608-142`).
  `$execution.id` gwarantuje unikalność w obrębie danej instancji n8n.
- `timestamp_rejestracji` – aktualny czas w strefie `Europe/Warsaw`.

### 5. `Set - Transformacje Danych`
- `telefon_sformatowany` – usuwa wszystkie niecyfrowe znaki i formatuje jako
  `+48 XXX XXX XXX` (bierze ostatnie 9 cyfr, więc działa zarówno dla numeru
  z prefiksem, jak i bez).
- `deadline_platnosci` – data aktualna **+7 dni**, strefa `Europe/Warsaw`,
  format `dd.MM.yyyy`.

### 6. `Code - Walidacja NIP (opcjonalna)`
Jeśli pole NIP jest puste — pomija walidację (`nip_valid = null`).
Jeśli podano:
- sprawdza długość (musi być dokładnie 10 cyfr),
- liczy sumę kontrolną z wagami `[6,5,7,2,3,4,5,6,7]`, `suma mod 11` musi
  równać się ostatniej cyfrze.

⚠️ To wyłącznie **walidacja formatu** — nie sprawdza, czy NIP istnieje
naprawdę w bazie GUS (zgodnie z Twoim materiałem szkoleniowym).

---

### 7. `Set - Symulacja Liczby Zapisów` ⚠️
**Dane na sztywno** (zgodnie z Twoją decyzją):
- `zarejestrowani_uczestnicy = 15`
- `limit_miejsc = 20`

To jedyne miejsce, które musisz ręcznie edytować, jeśli chcesz zmienić próg
testowy, oraz jedyne miejsce, które w przyszłości podmienisz na realne
źródło danych (np. węzeł Google Sheets odczytujący liczbę wierszy w arkuszu
zapisów, albo zapytanie do bazy danych).

### 8. `Code - Oblicz Statystyki (Agregacja)`
Liczy:
- `wolne_miejsca` = limit − zarejestrowani − 1 (odejmujemy 1, bo doliczamy
  bieżące zgłoszenie),
- `procent_wypelnienia` w %,
- `ma_wolne_miejsca` (boolean) — używany przez kolejny węzeł IF.

> W realnym scenariuszu z wieloma rekordami (np. z Google Sheets) do tego
> celu użyłbyś natywnego węzła **Aggregate** działającego na wielu itemach.
> Tutaj, ponieważ przetwarzamy pojedyncze zgłoszenie na sztywnych danych,
> logikę agregującą zaimplementowano w węźle Code — działanie jest
> równoważne, ale łatwiejsze do odczytania w tym kontekście.

### 9. `IF - Sprawdź Limit Miejsc`
- **są miejsca** (`ma_wolne_miejsca = true`) → generowanie PDF i potwierdzenia,
- **brak miejsc** → gałąź waitlisty.

### 9a. Gałąź waitlisty: `Set - Przygotuj Dane Waitlist` → `Code - Buduj HTML Waitlist` → `Respond to Webhook - Waitlist`
Ustawia `status_rejestracji = WAITLIST` i zwraca stronę HTML z informacją
o wpisaniu na listę rezerwową oraz numerem zgłoszenia.

---

### 10. `HTTP Request - Generuj PDF (html2pdf.app)`
Wysyła żądanie `POST` do `https://api.html2pdf.app/v1/generate` z prostym
HTML zawierającym dane rejestracji, prosząc o plik PDF w odpowiedzi
(`Response Format: File`).

Uwierzytelnianie odbywa się **nagłówkiem HTTP `X-API-Key`** (a nie parametrem
zapytania `apiKey` — to wymóg aktualnego API html2pdf.app). Klucz **nie jest
zapisany w pliku workflow** — węzeł używa poświadczenia n8n typu **Header Auth**
(`authentication: genericCredentialType`), którego sekret trzyma zaszyfrowana
baza n8n.

**Do zrobienia przed uruchomieniem — utwórz poświadczenie:**
1. W n8n: **Credentials → Add credential → Header Auth**.
   - **Name** (nazwa nagłówka): `X-API-Key`
   - **Value** (wartość): Twój klucz z html2pdf.app
     (zdobądź na https://dash.html2pdf.app/registration — przychodzi mailem)
   - Zapisz poświadczenie pod nazwą np. `html2pdf.app (X-API-Key)`.
2. Otwórz węzeł **HTTP Request - Generuj PDF** i w polu *Credential for Header
   Auth* wybierz utworzone poświadczenie (po imporcie może wymagać ręcznego
   wskazania).
2. Sprawdź w interfejsie n8n zakładkę **Options → Response → Response
   Format**, czy jest ustawiona na **File** — mapowanie tej opcji z pliku
   JSON bywa różne między wersjami n8n i czasem trzeba ją zaznaczyć ręcznie.
3. Jeśli wolisz inny serwis (np. `pdfshift.io`) lub self-hosted Puppeteer /
   WeasyPrint — podmień URL i format zapytania zgodnie z dokumentacją tego
   serwisu.

Węzeł ma ustawione **`continueOnFail: true`** — jeśli generowanie PDF się
nie powiedzie (np. zły klucz API, limit żądań), workflow **nie przerwie się**,
tylko przejdzie dalej bez pliku PDF (patrz punkt 12 — fallback).

### 11. `Code - PDF do Base64`
Bezpiecznie (w bloku `try/catch`) sprawdza, czy poprzedni węzeł zwrócił
plik binarny. Jeśli tak — konwertuje go na base64 (`pdf_available = true`).
Jeśli PDF się nie wygenerował — `pdf_available = false`, workflow idzie
dalej bez błędu.

### 12. `Code - Buduj HTML Potwierdzenia`
Buduje finalną, ostylowaną stronę HTML (CSS: kolory, zaokrąglone rogi,
responsywność) zawierającą:
- dane uczestnika w tabeli,
- ID uczestnika w wyróżnionym boksie,
- wynik walidacji NIP (jeśli podano),
- sekcję **„Kolejne kroki”**,
- link do pobrania PDF zakodowany jako `data:application/pdf;base64,...`
  (jeśli `pdf_available = true`) **albo** komunikat zastępczy, gdy PDF się
  nie wygenerował.

### 13. `Respond to Webhook - Potwierdzenie`
Zwraca zbudowany HTML jako finalną odpowiedź w przeglądarce użytkownika,
z nagłówkiem `Content-Type: text/html; charset=utf-8`.

---

## Sticky notes w workflow
W pliku znajdują się dodatkowo 5 kolorowych notatek opisujących:
- zakres poziomu podstawowego,
- zakres poziomu średniego,
- zakres poziomu zaawansowanego,
- listę rzeczy do zrobienia przed uruchomieniem (klucz API, response format,
  podmiana danych na sztywno),
- wyjaśnienie mechanizmu `responseNode` / Respond to Webhook.

---

## Obsługa błędów — podsumowanie
| Sytuacja | Zachowanie |
|---|---|
| Nieprawidłowy email | Osobna gałąź → czytelny komunikat HTML, workflow kończy się poprawnie |
| Brak wolnych miejsc | Osobna gałąź → strona waitlisty z numerem zgłoszenia |
| NIP nieprawidłowy / błędny format | Rejestracja **nie jest blokowana** — komunikat o błędzie NIP pojawia się informacyjnie na stronie potwierdzenia |
| Błąd generowania PDF (zły klucz, limit API, przerwa w usłudze) | `continueOnFail` — workflow kontynuuje, strona potwierdzenia pokazuje komunikat zastępczy zamiast linku do pobrania |

---

## Co możesz łatwo rozbudować dalej
- Podmiana `Set - Symulacja Liczby Zapisów` na węzeł **Google Sheets** (odczyt
  liczby wierszy) lub bazę danych — reszta logiki (IF, statystyki, waitlist)
  zadziała bez zmian.
- Dodanie węzła **Google Sheets (Append)** zapisującego każde zgłoszenie do
  arkusza jako trwały rejestr.
- Dodanie wysyłki e-mail (Gmail / SMTP) z załączonym PDF-em, gdyby jednak
  była potrzebna w przyszłości.
- Zamiana `html2pdf.app` na self-hosted Puppeteer, jeśli wolisz nie polegać
  na zewnętrznym API.

---

**Plik workflow:** `formularz-rejestracji-n8n-workflow.json`
**Liczba węzłów:** 23 (18 funkcjonalnych + 5 sticky notes dokumentujących)

-- =====================================================================
-- VERSION 2 - raport pokazuje TYLKO bledne wartosci (naruszenia normy dobowej)
--
-- Zmiany wzgledem wersji "wszystkie":
--   1. Filtr: czy_zach_odpoczynek_dobowy LIKE 'NARUSZENIE%'  (tylko naruszenia).
--   2. lp liczone PO filtrze (ROW_NUMBER w warstwie zewnetrznej, nad WHERE)
--      -> numeracja 1..N bez dziur. WHERE dziala przed funkcja okna, wiec
--      ROW_NUMBER numeruje juz odfiltrowane wiersze.
--   Reszta logiki i wydajnosci bez zmian.
--
-- Chcesz szerzej "bledne" (rowniez BRAK NASTEPNEJ ZMIANY)? Zmien filtr na:
--      WHERE czy_zach_odpoczynek_dobowy NOT LIKE 'OK%'
--
-- UWAGA: kalendarz_raport ma "< data_do + 2" -> do WYNIKU trafia tez dzien
--   po okresie (np. 01-07 dla czerwca). Jesli raport ma obejmowac tylko
--   okres, zmien tam na "< data_do + 1" (kalendarz_src zostaje + 2 dla LEAD).
-- =====================================================================
SELECT     lp,
    imie,
    nazwisko,
    numer_ewidencyjny,
    nr_karty,
    dzien_miesiaca,
    poczatek_pracy,
    koniec_pracy,
    poczatek_pier_zlecenia,
    poczatek_zlecenia,
    koniec_zlecenia,
    ilosc_zlecen,
    poczatek_dyzuru,
    koniec_dyzuru,
    ilosc_dyzurow,
    odpoczynek_z_uwzgl_dyzuru,
    poczatek_pracy_nas_dzien,
    nastepny_dzien,
    rodzaj_dnia_nastepnego,
    godziny_odpoczynku,
    czy_zach_odpoczynek_dobowy
INTO     v_lp,
    v_imie,
    v_nazwisko,
    v_numer_ewidencyjny,
    v_nr_karty,
    v_dzien_miesiaca,
    v_poczatek_pracy,
    v_koniec_pracy,
    v_poczatek_pier_zlecenia,
    v_poczatek_zlecenia,
    v_koniec_zlecenia,
    v_ilosc_zlecen,
    v_poczatek_dyzuru,
    v_koniec_dyzuru,
    v_ilosc_dyzurow,
    v_odpoczynek_z_uwzgl_dyzuru,
    v_poczatek_pracy_nas_dzien,
    v_nastepny_dzien,
    v_rodzaj_dnia_nastepnego,
    v_godziny_odpoczynku,
    v_czy_zach_odpoczynek_dobowy
FROM (
    -- === Warstwa 2: filtr bledne + numeracja lp po filtrze ===
    SELECT ROW_NUMBER() OVER (ORDER BY nazwisko, imie, dz_sort) AS lp,
           imie, nazwisko, numer_ewidencyjny, nr_karty, dzien_miesiaca,
           poczatek_pracy, koniec_pracy, poczatek_pier_zlecenia, poczatek_zlecenia,
           koniec_zlecenia, ilosc_zlecen, poczatek_dyzuru, koniec_dyzuru, ilosc_dyzurow,
           odpoczynek_z_uwzgl_dyzuru, poczatek_pracy_nas_dzien, nastepny_dzien,
           rodzaj_dnia_nastepnego, godziny_odpoczynku, czy_zach_odpoczynek_dobowy
    FROM (
        -- === Warstwa 1: pelne wyliczenie (bez lp), z kluczem sortowania dz_sort ===
        WITH parametry AS (
            SELECT  TO_DATE('^$DATA_OD^', '^$P_DATE_FORMAT^') AS data_od,
                    TO_DATE('^$DATA_DO^', '^$P_DATE_FORMAT^') AS data_do
            FROM dual
        ),
        kalendarz_src AS (
            SELECT /*+ MATERIALIZE */
                   k.prac_id, k.id, k.dzien_mies, k.czas_od, k.czas_do, k.typ_dnia
            FROM NT_KP_KDR_KALENDARZE_PRAC k
            CROSS JOIN parametry p
            WHERE k.dzien_mies >= p.data_od
              AND k.dzien_mies <  p.data_do + 2
        ),
        kalendarz AS (
            SELECT /*+ MATERIALIZE */
                   k.prac_id, k.id, k.dzien_mies, k.czas_od, k.czas_do, k.typ_dnia,
                   LEAD(k.czas_od)    OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_czas_od,
                   LEAD(k.dzien_mies) OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_dzien_mies,
                   LEAD(k.typ_dnia)   OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_typ_dnia
            FROM kalendarz_src k
        ),
        kalendarz_raport AS (
            SELECT /*+ MATERIALIZE */
                   k.*
            FROM kalendarz k
            CROSS JOIN parametry p
            WHERE k.dzien_mies >= p.data_od
              AND k.dzien_mies <  p.data_do + 2
              AND k.typ_dnia IS NULL
        ),
        zlecenia_aggr AS (
            SELECT /*+ MATERIALIZE NO_MERGE */
                   z.prac_id, z.kali_id,
                   COUNT(z.id) AS ile_zlecen,
                   MIN(z.godz_od) AS pierwsze_godz_od,
                   MAX(z.godz_od) KEEP (DENSE_RANK LAST ORDER BY z.godz_do, z.id) AS godz_od,
                   MAX(z.godz_do) KEEP (DENSE_RANK LAST ORDER BY z.godz_do, z.id) AS godz_do
            FROM KP_RCP_ZLEC_NADG_PRAC z
            JOIN kalendarz_raport k
              ON k.prac_id = z.prac_id
             AND k.id      = z.kali_id
            GROUP BY z.prac_id, z.kali_id
        ),
        zdarzenia_aggr AS (
            SELECT /*+ MATERIALIZE NO_MERGE */
                   zd.prac_id,
                   TRUNC(zd.workday_date) AS workday_date,
                   COUNT(*) AS ile_zdarzen,
                   MAX(zd.date_time_from) KEEP (DENSE_RANK LAST ORDER BY zd.date_time_to, zd.date_time_from) AS date_time_from,
                   MAX(zd.date_time_to)   KEEP (DENSE_RANK LAST ORDER BY zd.date_time_to, zd.date_time_from) AS date_time_to
            FROM KP_RCP_WORK_TIME_EVENTS zd
            CROSS JOIN parametry p
            WHERE zd.wtet_id = 18
              AND zd.workday_date >= p.data_od
              AND zd.workday_date <  p.data_do + 2
            GROUP BY zd.prac_id, TRUNC(zd.workday_date)
        ),
        dane AS (
            SELECT /*+ LEADING(k p) USE_HASH(p z zd) */
                   p.imie, p.nazwisko, p.nr_ew AS numer_ewidencyjny, p.nr_karty,
                   k.dzien_mies, k.czas_od, k.czas_do,
                   k.next_czas_od, k.next_dzien_mies, k.next_typ_dnia,
                   z.pierwsze_godz_od, z.godz_od, z.godz_do, z.ile_zlecen,
                   zd.date_time_from, zd.date_time_to, zd.ile_zdarzen,
                   TRUNC(k.dzien_mies)      + (k.czas_do     - TRUNC(k.czas_do))     AS koniec_pracy_dt,
                   TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)) AS poczatek_nast_pracy_dt,
                   TRUNC(k.dzien_mies)      + (z.godz_do     - TRUNC(z.godz_do))     AS koniec_zlecenia_dt
            FROM kalendarz_raport k
            JOIN t_prac p
              ON p.prac_id = k.prac_id
            LEFT JOIN zlecenia_aggr z
              ON z.prac_id = k.prac_id
             AND z.kali_id = k.id
            LEFT JOIN zdarzenia_aggr zd
              ON zd.prac_id = k.prac_id
             AND zd.workday_date = k.dzien_mies
        ),
        wyliczenia AS (
            SELECT d.*,
                   CASE
                       WHEN d.next_typ_dnia IS NOT NULL THEN 16
                       WHEN d.next_czas_od  IS NULL     THEN NULL
                       WHEN d.date_time_to IS NOT NULL
                            AND d.date_time_to >= d.koniec_pracy_dt
                            AND ( d.godz_od IS NULL
                               OR (d.godz_od - TRUNC(d.godz_od)) < (d.czas_do - TRUNC(d.czas_do))
                               OR d.date_time_to >= d.koniec_zlecenia_dt )
                           THEN ROUND((d.poczatek_nast_pracy_dt - d.date_time_to) * 24, 2)
                       WHEN d.godz_od IS NOT NULL
                            AND (d.godz_od - TRUNC(d.godz_od)) >= (d.czas_do - TRUNC(d.czas_do))
                           THEN ROUND((d.poczatek_nast_pracy_dt - d.koniec_zlecenia_dt) * 24, 2)
                       ELSE ROUND((d.poczatek_nast_pracy_dt - d.koniec_pracy_dt) * 24, 2)
                   END AS godziny_odpoczynku_calc
            FROM dane d
        )
        SELECT
               imie,
               nazwisko,
               numer_ewidencyjny,
               nr_karty,
               TO_CHAR(dzien_mies, '^$P_DATE_FORMAT^') AS dzien_miesiaca,
               TO_CHAR(czas_od, 'HH24:MI') AS poczatek_pracy,
               TO_CHAR(czas_do, 'HH24:MI') AS koniec_pracy,
               TO_CHAR(pierwsze_godz_od, 'HH24:MI') AS poczatek_pier_zlecenia,
               TO_CHAR(godz_od, 'HH24:MI') AS poczatek_zlecenia,
               TO_CHAR(godz_do, 'HH24:MI') AS koniec_zlecenia,
               ile_zlecen AS ilosc_zlecen,
               TO_CHAR(date_time_from, 'HH24:MI') AS poczatek_dyzuru,
               TO_CHAR(date_time_to, 'HH24:MI') AS koniec_dyzuru,
               ile_zdarzen AS ilosc_dyzurow,
               godziny_odpoczynku_calc AS odpoczynek_z_uwzgl_dyzuru,
               TO_CHAR(next_czas_od, 'HH24:MI') AS poczatek_pracy_nas_dzien,
               TO_CHAR(next_dzien_mies, '^$P_DATE_FORMAT^') AS nastepny_dzien,
               CASE next_typ_dnia
                   WHEN 'N'  THEN 'Niedziela'
                   WHEN 'S'  THEN 'Święto'
                   WHEN 'WN' THEN 'Wolne za niedzielę'
                   WHEN 'WS' THEN 'Wolne za święto'
                   WHEN 'SO' THEN 'Wolne za niedzielę i święto'
                   WHEN 'C'  THEN 'Wolne harmonogramowo'
                   WHEN 'W'  THEN 'Dzień wolny'
                   WHEN 'R'  THEN 'Dzień roboczy'
                   ELSE next_typ_dnia
               END AS rodzaj_dnia_nastepnego,
               godziny_odpoczynku_calc AS godziny_odpoczynku,
               CASE
                   WHEN next_typ_dnia IS NOT NULL
                       THEN 'OK - następny dzień wolny'
                   WHEN next_czas_od IS NULL
                       THEN 'BRAK NASTĘPNEJ ZMIANY'
                   WHEN date_time_to IS NOT NULL
                        AND date_time_to >= koniec_pracy_dt
                        AND ( godz_od IS NULL
                           OR (godz_od - TRUNC(godz_od)) < (czas_do - TRUNC(czas_do))
                           OR date_time_to >= koniec_zlecenia_dt )
                        AND godziny_odpoczynku_calc < 11
                       THEN 'NARUSZENIE - koniec dyżuru < 11h do następnej zmiany'
                   WHEN godz_od IS NOT NULL
                        AND (godz_od - TRUNC(godz_od)) >= (czas_do - TRUNC(czas_do))
                        AND godziny_odpoczynku_calc < 11
                       THEN 'NARUSZENIE - koniec nadgodzin < 11h do następnej zmiany'
                   WHEN ( godz_od IS NULL
                       OR (godz_od - TRUNC(godz_od)) < (czas_do - TRUNC(czas_do)) )
                        AND godziny_odpoczynku_calc < 11
                       THEN 'NARUSZENIE - koniec zmiany < 11h do następnej zmiany'
                   ELSE 'OK'
               END AS czy_zach_odpoczynek_dobowy,
               dzien_mies AS dz_sort                       -- klucz sortowania (surowa data)
        FROM wyliczenia
    )
    WHERE czy_zach_odpoczynek_dobowy LIKE 'NARUSZENIE%'    -- <<< FILTR: tylko bledne
)
ORDER BY lp;

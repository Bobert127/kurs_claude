-- =====================================================================
-- Brak odpoczynku dobowego (11h) - VERSION 2 + modul SELECT ... INTO
-- Do osadzenia w silniku raportowym (TETA/Konstelacja), ktory iteruje po
-- wierszach i mapuje kolumny na zmienne v_*.
-- VERSION 2: godziny_odpoczynku liczone jako najdluzsza nieprzerwana
-- przerwa w calej dobie pracowniczej (zmiana + kazde zlecenie osobno +
-- kazdy dyzur osobno + granica 24h od poczatku zmiany), a nie tylko
-- "koniec ostatniego zdarzenia -> poczatek nastepnej zmiany".
--
-- UWAGA: uruchomione samodzielnie jako zwykly SQL rzuci ORA-01422 (wiele
-- wierszy). Ten zapis ma sens WYLACZNIE w kontekscie silnika raportu,
-- ktory obsluguje pobieranie wiersz po wierszu.
-- =====================================================================
SELECT
        lp,
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
        koniec_przed_przerwa,
        poczatek_po_przerwie,
        odpoczynek_z_uwzgl_dyzuru,
        poczatek_pracy_nas_dzien,
        nastepny_dzien,
        rodzaj_dnia_nastepnego,
        godziny_odpoczynku,
        czy_zach_odpoczynek_dobowy

         INTO
         v_lp,
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
         v_koniec_przed_przerwa,
         v_poczatek_po_przerwie,
         v_odpoczynek_z_uwzgl_dyzuru,
         v_poczatek_pracy_nas_dzien,
         v_nastepny_dzien,
         v_rodzaj_dnia_nastepnego,
         v_godziny_odpoczynku,
         v_czy_zach_odpoczynek_dobowy

FROM (
WITH parametry AS (
    SELECT  TO_DATE('^$DATA_OD^', '^$P_DATE_FORMAT^')  AS data_od,
            TO_DATE('^$DATA_DO^', '^$P_DATE_FORMAT^')  AS data_do
    FROM dual
),
kalendarz_src_raw AS (
    SELECT /*+ MATERIALIZE */
           k.prac_id, k.id, k.dzien_mies, k.czas_od, k.czas_do, k.typ_dnia
    FROM NT_KP_KDR_KALENDARZE_PRAC k
    CROSS JOIN parametry p
    WHERE k.dzien_mies >= p.data_od
      AND k.dzien_mies <  p.data_do + 2
),
-- TYMCZASOWA LATA: dla (prac_id, dzien_mies) potrafia wystapic 2 wiersze
-- kalendarza (zaobserwowane dla dnia granicznego zakresu) - bez deduplikacji
-- LEAD w kalendarz/next_* losowo/blednie "przeskakuje" na duplikat tego
-- samego dnia zamiast prawdziwego kolejnego dnia, co dawalo bledny
-- (np. ujemny) odpoczynek mimo braku dyzuru/zlecenia. Zalozenie do potwierdzenia:
-- wiersz z najwyzszym id traktujemy jako obowiazujacy dla danego dnia.
kalendarz_src AS (
    SELECT prac_id, id, dzien_mies, czas_od, czas_do, typ_dnia
    FROM (
        SELECT r.*,
               ROW_NUMBER() OVER (PARTITION BY r.prac_id, r.dzien_mies ORDER BY r.id DESC) AS rn
        FROM kalendarz_src_raw r
    )
    WHERE rn = 1
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
      AND k.dzien_mies <  p.data_do + 1
      AND k.typ_dnia IS NULL
),
zlecenia_all AS (
    SELECT z.prac_id, z.kali_id, z.id,
           CASE WHEN (z.godz_od - TRUNC(z.godz_od)) < (k.czas_od - TRUNC(k.czas_od))
                THEN TRUNC(k.dzien_mies) + 1 + (z.godz_od - TRUNC(z.godz_od))
                ELSE TRUNC(k.dzien_mies)     + (z.godz_od - TRUNC(z.godz_od))
           END AS godz_od_real,
           CASE WHEN (z.godz_od - TRUNC(z.godz_od)) < (k.czas_od - TRUNC(k.czas_od))
                THEN TRUNC(k.dzien_mies) + 1 + (z.godz_do - TRUNC(z.godz_do))
                ELSE TRUNC(k.dzien_mies)     + (z.godz_do - TRUNC(z.godz_do))
           END AS godz_do_real
    FROM KP_RCP_ZLEC_NADG_PRAC z
    JOIN kalendarz_raport k
      ON k.prac_id = z.prac_id
     AND k.id      = z.kali_id
),
zlecenia_aggr AS (
    SELECT prac_id, kali_id,
           COUNT(id) AS ile_zlecen,
           MIN(godz_od_real) AS pierwsze_godz_od,
           MAX(godz_od_real) KEEP (DENSE_RANK LAST ORDER BY godz_do_real, id) AS godz_od,
           MAX(godz_do_real) KEEP (DENSE_RANK LAST ORDER BY godz_do_real, id) AS godz_do
    FROM zlecenia_all
    GROUP BY prac_id, kali_id
),
zdarzenia_all AS (
    SELECT k.prac_id, k.id AS kali_id,
           zd.date_time_from, zd.date_time_to
    FROM KP_RCP_WORK_TIME_EVENTS zd
    JOIN kalendarz_raport k
      ON k.prac_id = zd.prac_id
     AND k.dzien_mies = TRUNC(zd.workday_date)
    WHERE zd.wtet_id = 18
),
zdarzenia_aggr AS (
    SELECT prac_id, kali_id,
           COUNT(*) AS ile_zdarzen,
           MAX(date_time_from) KEEP (DENSE_RANK LAST ORDER BY date_time_to, date_time_from) AS date_time_from,
           MAX(date_time_to)   KEEP (DENSE_RANK LAST ORDER BY date_time_to, date_time_from) AS date_time_to
    FROM zdarzenia_all
    GROUP BY prac_id, kali_id
),
intervals AS (
    SELECT k.prac_id, k.id AS kali_id,
           TRUNC(k.dzien_mies) + (k.czas_od - TRUNC(k.czas_od)) AS start_ts,
           TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)) AS end_ts
    FROM kalendarz_raport k

    UNION ALL

    SELECT prac_id, kali_id, godz_od_real, godz_do_real
    FROM zlecenia_all

    UNION ALL

    SELECT prac_id, kali_id, date_time_from, date_time_to
    FROM zdarzenia_all

    UNION ALL

    /*wirtualna granica koncowa doby pracowniczej: ZAWSZE 24h od poczatku biezacej zmiany*/
    SELECT k.prac_id, k.id AS kali_id,
           TRUNC(k.dzien_mies) + (k.czas_od - TRUNC(k.czas_od)) + 1 AS start_ts,
           TRUNC(k.dzien_mies) + (k.czas_od - TRUNC(k.czas_od)) + 1 AS end_ts
    FROM kalendarz_raport k
),
ordered AS (
    SELECT prac_id, kali_id, start_ts, end_ts,
           MAX(end_ts) OVER (PARTITION BY prac_id, kali_id
                              ORDER BY start_ts, end_ts
                              ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_max_end
    FROM intervals
    WHERE start_ts IS NOT NULL
),
gaps AS (
    /*tylko realne (dodatnie) przerwy - stykajace sie przedzialy (koniec = poczatek) to NIE przerwa*/
    SELECT prac_id, kali_id,
           prev_max_end AS gap_od,
           start_ts     AS gap_do,
           ROUND((start_ts - prev_max_end) * 24, 2) AS gap_godziny
    FROM ordered
    WHERE prev_max_end IS NOT NULL
      AND start_ts > prev_max_end
),
gap_max AS (
    /*najdluzsza nieprzerwana przerwa w calej dobie - to ona musi miec >= 11h*/
    SELECT prac_id, kali_id,
           MAX(gap_godziny) AS godziny_odpoczynku_calc,
           MAX(gap_od) KEEP (DENSE_RANK FIRST ORDER BY gap_godziny DESC, gap_od) AS przerwa_od,
           MAX(gap_do) KEEP (DENSE_RANK FIRST ORDER BY gap_godziny DESC, gap_od) AS przerwa_do
    FROM gaps
    GROUP BY prac_id, kali_id
),
dane AS (
    SELECT /*+ LEADING(k p) USE_HASH(p z zd gm) */
           p.imie, p.nazwisko, p.nr_ew AS numer_ewidencyjny, p.nr_karty,
           k.dzien_mies, k.czas_od, k.czas_do,
           k.next_czas_od, k.next_dzien_mies, k.next_typ_dnia,
           z.pierwsze_godz_od, z.godz_od, z.godz_do, z.ile_zlecen,
           zd.date_time_from, zd.date_time_to, zd.ile_zdarzen,
           gm.godziny_odpoczynku_calc,
           gm.przerwa_od, gm.przerwa_do
    FROM kalendarz_raport k
    JOIN t_prac p
      ON p.prac_id = k.prac_id
    LEFT JOIN zlecenia_aggr z
      ON z.prac_id = k.prac_id
     AND z.kali_id = k.id
    LEFT JOIN zdarzenia_aggr zd
      ON zd.prac_id = k.prac_id
     AND zd.kali_id = k.id
    LEFT JOIN gap_max gm
      ON gm.prac_id = k.prac_id
     AND gm.kali_id = k.id
)
SELECT ROW_NUMBER() OVER (ORDER BY nazwisko, imie, dzien_mies) AS lp,
       imie,
       nazwisko,
       numer_ewidencyjny,
       nr_karty,
       TO_CHAR(dzien_mies, 'dd-mm-yyyy') AS dzien_miesiaca,
       TO_CHAR(czas_od, 'HH24:MI') AS poczatek_pracy,
       TO_CHAR(czas_do, 'HH24:MI') AS koniec_pracy,
       TO_CHAR(pierwsze_godz_od, 'HH24:MI') AS poczatek_pier_zlecenia,
       TO_CHAR(godz_od, 'HH24:MI') AS poczatek_zlecenia,
       TO_CHAR(godz_do, 'HH24:MI') AS koniec_zlecenia,
       ile_zlecen AS ilosc_zlecen,
       TO_CHAR(date_time_from, 'HH24:MI') AS poczatek_dyzuru,
       TO_CHAR(date_time_to, 'HH24:MI') AS koniec_dyzuru,
       ile_zdarzen AS ilosc_dyzurow,
       TO_CHAR(przerwa_od, 'dd-mm-yyyy HH24:MI') AS koniec_przed_przerwa,
       TO_CHAR(przerwa_do, 'dd-mm-yyyy HH24:MI') AS poczatek_po_przerwie,
       godziny_odpoczynku_calc AS odpoczynek_z_uwzgl_dyzuru,
       TO_CHAR(next_czas_od, 'HH24:MI') AS poczatek_pracy_nas_dzien,
       TO_CHAR(next_dzien_mies, 'dd-mm-yyyy') AS nastepny_dzien,
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
           WHEN godziny_odpoczynku_calc IS NULL
               THEN 'NARUSZENIE - brak przerwy w ciągu doby (praca ciągła)'
           WHEN godziny_odpoczynku_calc >= 11
               THEN 'OK'
           ELSE 'NARUSZENIE - max przerwa ' || TO_CHAR(godziny_odpoczynku_calc) || 'h (' ||
                TO_CHAR(przerwa_od, 'HH24:MI') || ' - ' || TO_CHAR(przerwa_do, 'dd-mm HH24:MI') || ') < 11h'
       END AS czy_zach_odpoczynek_dobowy
FROM dane
where (pierwsze_godz_od is not null or date_time_from is not null)
ORDER BY nazwisko, imie, dzien_mies
);

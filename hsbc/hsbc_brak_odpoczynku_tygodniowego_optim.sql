-- =====================================================================
-- Nieprzerwany odpoczynek tygodniowy - wersja ZOPTYMALIZOWANA
-- Bazuje na produkcyjnym bloku (v3 z kolumna lp) z pliku
-- hsbc_brak_odpoczynku_tygodniowego.sql (linie 555-847).
--
-- CO ZMIENIONO (poziom SQL, bez zmiany wynikow):
--   1. Zracjonalizowano hinty MATERIALIZE - zostaja tylko na CTE
--      uzywanych WIELOKROTNIE (kalendarze, prac_hr, kal_base,
--      valid_pairs, okres, zdarzenia, nadgodziny, pary). Z CTE
--      jednorazowych hint zdjeto, by optymalizator mogl je zlaczyc
--      (pipelining) i uniknac zapisu/odczytu tabel tymczasowych.
--   2. kal_base czerpie liste pracownikow z prac_hr (juz odduplikowana,
--      1 wiersz/pracownik) zamiast z kalendarze (wiele wierszy/prac.).
--   3. Usunieto debugowy filtr p.nr_ew = '44109003' (zakomentowany).
--
-- UWAGA - najwiekszy zysk jest NIE w tym SELECT, tylko w:
--   * indeksach (sekcja DDL ponizej) - patrz komentarz,
--   * szybkosci funkcji akt_dane.* (wolane raz/pracownik; przyspieszyc
--     je mozna tylko wewnatrz: indeksy na ich tabelach albo RESULT_CACHE).
--   Sam rewrite SQL da umiarkowana poprawe; bez indeksow calosc dalej
--   bedzie robic FULL SCAN po NT_KP_KDR_KALENDARZE_PRAC.
--
-- Daty (parametry raportu w TETA Konstelacja) wystepuja jako literaly
-- DATE '...'. Podmieniaj je parametrem TYPU DATA (nie TO_CHAR na kolumnie),
-- inaczej indeks na DZIEN_MIES nie zadziala (sargability).
-- =====================================================================

-- ---------------------------------------------------------------------
-- SEKCJA DDL - uruchom RAZ (jako DBA). Najpierw sprawdz, czy indeks juz
-- istnieje (USER_INDEXES/USER_IND_COLUMNS); tworz tylko brakujace.
-- To one daja realne przyspieszenie raportu.
-- ---------------------------------------------------------------------
-- Napedza company-wide skan CTE kalendarze (TYP_DNIA='W' + zakres dat):
-- CREATE INDEX ix_kal_typ_dzien ON NT_KP_KDR_KALENDARZE_PRAC (TYP_DNIA, DZIEN_MIES, PRAC_ID);
-- Napedza lookupy per-pracownik (kal_base, self-join valid_pairs, D-1/D+2):
-- CREATE INDEX ix_kal_prac_dzien ON NT_KP_KDR_KALENDARZE_PRAC (PRAC_ID, DZIEN_MIES);
-- Zdarzenia (wtet_id=18, zakres workday_date):
-- CREATE INDEX ix_wte_prac_dzien ON KP_RCP_WORK_TIME_EVENTS (PRAC_ID, WORKDAY_DATE, WTET_ID);
-- Zlecone nadgodziny:
-- CREATE INDEX ix_nadg_prac_data ON KP_RCP_ZLEC_NADG_PRAC (PRAC_ID, DATA);
-- (t_prac.PRAC_ID, KP_RCP_WORKING_TIME_SYSTEMS.CODE, KP_RCP_OKRESY_BILANSU.ID
--  zwykle sa juz PK/UNIQUE - zweryfikuj.)
--
-- Opcjonalnie, jesli mozesz modyfikowac pakiet (uwaga: nadpisywany przy
-- aktualizacji TETA) - deklaracje funkcji z RESULT_CACHE zetna koszt
-- powtarzalnych wywolan akt_dane.j_org/mpk/stanowisko/work_time_system.
-- ---------------------------------------------------------------------

-- Nazwy kolumn wynikowych w naglowku, dane z podzapytania (bez dual)
SELECT lp,
       imie,
       nazwisko,
       nr_ew,
       nr_karty,
       jednostka_organizacyjna,
       mpk,
       stanowisko,
       okres_rozliczeniowy,
       pierwszy_dzien_okresu_rozliczeniowego,
       pierwszy_dzien_tygodnia,
       zakres_tygodnia,
       odejmowanie,
       suma_roznic_h,
       zdarzenia_wtet_id_18,
       zlecone_nadgodziny
FROM (
WITH
    -- Uzywane 3x (prac_hr, kal_base posrednio, okres) -> MATERIALIZE
    kalendarze AS (
        SELECT /*+ MATERIALIZE */
               k.id, k.prac_id, k.dzien_mies
        FROM NT_KP_KDR_KALENDARZE_PRAC k
        WHERE k.TYP_DNIA = 'W'
          AND k.DZIEN_MIES BETWEEN DATE '2026-06-01' AND DATE '2026-07-05'
    ),
    -- Uzywane 4x (system_pracy, zdarzenia, nadgodziny, kal_base, SELECT) -> MATERIALIZE
    prac_hr AS (
        SELECT /*+ MATERIALIZE */
               p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
               LEAST(NVL(p.data_rozw, DATE '2026-07-05'), DATE '2026-07-05') AS data_ref,
               akt_dane.j_org(p.prac_id,
                   LEAST(NVL(p.data_rozw, DATE '2026-07-05'), DATE '2026-07-05')) AS jednostka_org,
               akt_dane.mpk(p.prac_id,
                   LEAST(NVL(p.data_rozw, DATE '2026-07-05'), DATE '2026-07-05')) AS mpk,
               akt_dane.stanowisko(p.prac_id,
                   LEAST(NVL(p.data_rozw, DATE '2026-07-05'), DATE '2026-07-05')) AS stanowisko
        FROM t_prac p
        WHERE p.prac_id IN (SELECT prac_id FROM kalendarze)
    ),
    -- Jednorazowe (tylko okres) -> bez MATERIALIZE, niech sie zlaczy z okres
    system_pracy AS (
        SELECT ph.prac_id, b.dlugosc
        FROM prac_hr ph
        JOIN KP_RCP_WORKING_TIME_SYSTEMS scz
             ON scz.code = akt_dane.work_time_system(ph.prac_id, DATE '2026-07-05')
        JOIN KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
    ),
    -- Uzywane 4x (pary_agg, zdarzenia_agg, nadgodziny_agg, SELECT) -> MATERIALIZE
    okres AS (
        SELECT /*+ MATERIALIZE */
               k.prac_id, sp.dlugosc,
               CASE
                   WHEN sp.dlugosc = 1 THEN TRUNC(k.dzien_mies, 'MM')
                   WHEN sp.dlugosc = 3 THEN TRUNC(k.dzien_mies, 'Q')
               END AS poczatek_okresu,
               CASE
                   WHEN sp.dlugosc = 1 THEN LAST_DAY(k.dzien_mies)
                   WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(k.dzien_mies, 'Q'), 2))
               END AS koniec_okresu
        FROM kalendarze k
        JOIN system_pracy sp ON sp.prac_id = k.prac_id
        GROUP BY
               k.prac_id, sp.dlugosc,
               CASE
                   WHEN sp.dlugosc = 1 THEN TRUNC(k.dzien_mies, 'MM')
                   WHEN sp.dlugosc = 3 THEN TRUNC(k.dzien_mies, 'Q')
               END,
               CASE
                   WHEN sp.dlugosc = 1 THEN LAST_DAY(k.dzien_mies)
                   WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(k.dzien_mies, 'Q'), 2))
               END
    ),
    -- Uzywane wielokrotnie (valid_pairs 2x, pary_raw 2x) -> MATERIALIZE
    -- Lista pracownikow z prac_hr (odduplikowana, 1 wiersz/prac.)
    kal_base AS (
        SELECT /*+ MATERIALIZE */
               prac_id, dzien_mies, typ_dnia, czas_do, czas_od
        FROM NT_KP_KDR_KALENDARZE_PRAC
        WHERE dzien_mies BETWEEN DATE '2026-05-31' AND DATE '2026-07-07'
          AND prac_id IN (SELECT prac_id FROM prac_hr)
    ),
    -- Uzywane 3x (zdarzenia_per_para, nadgodziny_per_para, pary_raw) -> MATERIALIZE
    valid_pairs AS (
        SELECT /*+ MATERIALIZE */
               k1.prac_id, k1.dzien_mies AS d1
        FROM kal_base k1
        JOIN kal_base k2
             ON  k2.prac_id    = k1.prac_id
             AND k2.dzien_mies = k1.dzien_mies + 1
             AND k2.typ_dnia  IS NOT NULL
        WHERE k1.typ_dnia IS NOT NULL
          AND k1.dzien_mies BETWEEN DATE '2026-06-01' AND DATE '2026-07-05'
    ),
    -- Uzywane 2x (zdarzenia_per_para, zdarzenia_agg) -> MATERIALIZE
    zdarzenia AS (
        SELECT /*+ MATERIALIZE */
               z.prac_id,
               z.workday_date,
               TO_CHAR(z.date_time_from, 'HH24:MI') AS z_godz_od,
               TO_CHAR(z.date_time_to,   'HH24:MI') AS z_godz_do,
               z.date_time_from                      AS z_od_dt,
               z.date_time_to                        AS z_do_dt
        FROM KP_RCP_WORK_TIME_EVENTS z
        WHERE z.wtet_id = 18
          AND z.prac_id     IN (SELECT prac_id FROM prac_hr)
          AND z.workday_date BETWEEN DATE '2026-05-31' AND DATE '2026-07-07'
    ),
    -- Uzywane 2x (nadgodziny_per_para, nadgodziny_agg) -> MATERIALIZE
    nadgodziny AS (
        SELECT /*+ MATERIALIZE */
               n.prac_id,
               n.data,
               TO_CHAR(n.godz_od, 'HH24:MI')                  AS n_godz_od,
               TO_CHAR(n.godz_do, 'HH24:MI')                  AS n_godz_do,
               TRUNC(n.data) + (n.godz_od - TRUNC(n.godz_od)) AS n_od_dt,
               TRUNC(n.data) + (n.godz_do - TRUNC(n.godz_do)) AS n_do_dt
        FROM KP_RCP_ZLEC_NADG_PRAC n
        WHERE n.prac_id IN (SELECT prac_id FROM prac_hr)
          AND n.data    BETWEEN DATE '2026-05-31' AND DATE '2026-07-07'
    ),
    -- Jednorazowe (tylko pary_raw) -> bez MATERIALIZE
    zdarzenia_per_para AS (
        SELECT vp.prac_id, vp.d1,
               MIN(z.z_od_dt) AS min_z_od_dt,
               MAX(z.z_do_dt) AS max_z_do_dt
        FROM valid_pairs vp
        JOIN zdarzenia z
             ON  z.prac_id      = vp.prac_id
             AND z.workday_date BETWEEN vp.d1 - 1 AND vp.d1 + 2
        GROUP BY vp.prac_id, vp.d1
    ),
    -- Jednorazowe (tylko pary_raw) -> bez MATERIALIZE
    nadgodziny_per_para AS (
        SELECT vp.prac_id, vp.d1,
               MIN(n.n_od_dt) AS min_n_od_dt,
               MAX(n.n_do_dt) AS max_n_do_dt
        FROM valid_pairs vp
        JOIN nadgodziny n
             ON  n.prac_id = vp.prac_id
             AND n.data   BETWEEN vp.d1 - 1 AND vp.d1 + 2
        GROUP BY vp.prac_id, vp.d1
    ),
    -- Jednorazowe (tylko pary) -> bez MATERIALIZE
    pary_raw AS (
        SELECT vp.prac_id, vp.d1,
               TRUNC(k_po.dzien_mies)    + (k_po.czas_od    - TRUNC(k_po.czas_od))    AS k_po_dt,
               TRUNC(k_przed.dzien_mies) + (k_przed.czas_do - TRUNC(k_przed.czas_do)) AS k_przed_dt,
               zpp.min_z_od_dt, zpp.max_z_do_dt,
               npp.min_n_od_dt, npp.max_n_do_dt
        FROM valid_pairs vp
        LEFT JOIN kal_base k_przed
             ON  k_przed.prac_id    = vp.prac_id
             AND k_przed.dzien_mies = vp.d1 - 1
        LEFT JOIN kal_base k_po
             ON  k_po.prac_id    = vp.prac_id
             AND k_po.dzien_mies = vp.d1 + 2
        LEFT JOIN zdarzenia_per_para  zpp ON zpp.prac_id = vp.prac_id AND zpp.d1 = vp.d1
        LEFT JOIN nadgodziny_per_para npp ON npp.prac_id = vp.prac_id AND npp.d1 = vp.d1
    ),
    -- Uzywane 3x (pary_agg, zdarzenia_agg, nadgodziny_agg) -> MATERIALIZE
    pary AS (
        SELECT /*+ MATERIALIZE */
               prac_id, d1,
               TO_CHAR(k_przed_dt, 'dd-mm-yyyy HH24:MI')
                   || ' - '
                   || TO_CHAR(k_po_dt,    'dd-mm-yyyy HH24:MI') AS odejmowanie,
               ROUND(
                   GREATEST(
                       (k_po_dt - k_przed_dt) * 24,
                       NVL((min_z_od_dt - k_przed_dt) * 24, (k_po_dt - k_przed_dt) * 24),
                       NVL((min_n_od_dt - k_przed_dt) * 24, (k_po_dt - k_przed_dt) * 24),
                       NVL((k_po_dt - max_z_do_dt)    * 24, (k_po_dt - k_przed_dt) * 24),
                       NVL((k_po_dt - max_n_do_dt)    * 24, (k_po_dt - k_przed_dt) * 24)
                   )
               , 2) AS roznica_h
        FROM pary_raw
    ),
    -- Jednorazowe (tylko SELECT) -> bez MATERIALIZE
    pary_agg AS (
        SELECT par.prac_id,
               o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7) AS nr_tygodnia,
               MIN(par.odejmowanie)                      AS odejmowanie,
               ROUND(SUM(par.roznica_h), 2)              AS suma_roznica_h
        FROM pary par
        JOIN okres o
             ON  o.prac_id  = par.prac_id
             AND par.d1    >= o.poczatek_okresu
             AND par.d1    <= o.koniec_okresu
        GROUP BY par.prac_id, o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)
    ),
    -- Jednorazowe (tylko SELECT) -> bez MATERIALIZE
    zdarzenia_agg AS (
        SELECT ze.prac_id,
               o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)  AS nr_tygodnia,
               LISTAGG(
                   TO_CHAR(ze.workday_date, 'dd-mm-yyyy')
                       || ' ' || ze.z_godz_od || '-' || ze.z_godz_do,
                   ', '
               ) WITHIN GROUP (ORDER BY ze.workday_date) AS z_zdarzenia
        FROM zdarzenia ze
        JOIN pary par
             ON  par.prac_id      = ze.prac_id
             AND ze.workday_date BETWEEN par.d1 - 1 AND par.d1 + 2
        JOIN okres o
             ON  o.prac_id  = par.prac_id
             AND par.d1    >= o.poczatek_okresu
             AND par.d1    <= o.koniec_okresu
        GROUP BY ze.prac_id, o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)
    ),
    -- Jednorazowe (tylko SELECT) -> bez MATERIALIZE
    nadgodziny_agg AS (
        SELECT n.prac_id,
               o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)  AS nr_tygodnia,
               LISTAGG(
                   TO_CHAR(n.data, 'dd-mm-yyyy')
                       || ' ' || n.n_godz_od || '-' || n.n_godz_do,
                   ', '
               ) WITHIN GROUP (ORDER BY n.data)          AS n_nadgodziny
        FROM nadgodziny n
        JOIN pary par
             ON  par.prac_id = n.prac_id
             AND n.data    BETWEEN par.d1 - 1 AND par.d1 + 2
        JOIN okres o
             ON  o.prac_id  = par.prac_id
             AND par.d1    >= o.poczatek_okresu
             AND par.d1    <= o.koniec_okresu
        GROUP BY n.prac_id, o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)
    )

SELECT
      ROW_NUMBER() OVER (ORDER BY NLSSORT(p.nazwisko, 'NLS_SORT=POLISH'), NLSSORT(p.imie,'NLS_SORT=POLISH')) AS lp,
       p.imie,
       p.nazwisko,
       p.nr_ew,
       p.nr_karty,
       p.jednostka_org AS jednostka_organizacyjna,
       p.mpk,
       p.stanowisko,
       CASE o.dlugosc
           WHEN 1 THEN '1 - miesięczny okres rozliczeniowy'
           WHEN 3 THEN '3 - miesięczny okres rozliczeniowy'
       END AS okres_rozliczeniowy,
       TO_CHAR(o.poczatek_okresu, 'dd-mm-yyyy')
           AS pierwszy_dzien_okresu_rozliczeniowego,
       TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy')
           AS pierwszy_dzien_tygodnia,
       'od ' || TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy')
           || ' do ' || TO_CHAR(
               LEAST(o.poczatek_okresu + t.nr * 7 + 6, DATE '2026-07-05'),
               'dd-mm-yyyy'
           ) AS zakres_tygodnia,
       pa.odejmowanie    AS odejmowanie,
       pa.suma_roznica_h AS suma_roznic_h,
       za.z_zdarzenia    AS zdarzenia_wtet_id_18,
       na.n_nadgodziny   AS zlecone_nadgodziny
FROM prac_hr p
JOIN okres o ON o.prac_id = p.prac_id
JOIN (
    SELECT LEVEL - 1 AS nr
    FROM DUAL
    CONNECT BY LEVEL <= 26
) t ON o.poczatek_okresu + t.nr * 7 BETWEEN DATE '2026-06-01' AND DATE '2026-07-05'
LEFT JOIN pary_agg pa
       ON  pa.prac_id        = p.prac_id
       AND pa.poczatek_okresu = o.poczatek_okresu
       AND pa.nr_tygodnia    = t.nr
LEFT JOIN zdarzenia_agg za
       ON  za.prac_id        = p.prac_id
       AND za.poczatek_okresu = o.poczatek_okresu
       AND za.nr_tygodnia    = t.nr
LEFT JOIN nadgodziny_agg na
       ON  na.prac_id        = p.prac_id
       AND na.poczatek_okresu = o.poczatek_okresu
       AND na.nr_tygodnia    = t.nr
WHERE  pa.odejmowanie IS NOT NULL
--   AND  p.nr_ew = '44109003'   -- debug: pojedynczy pracownik (wylaczone)
ORDER BY p.nazwisko, p.imie, o.poczatek_okresu, t.nr
);

WITH
    kalendarze AS (
        SELECT /*+ MATERIALIZE */
               k.id,
               k.prac_id,
               k.dzien_mies
        FROM NT_KP_KDR_KALENDARZE_PRAC k
        WHERE k.TYP_DNIA = 'W'
          AND k.DZIEN_MIES BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'
    ),
    prac_hr AS (
        SELECT /*+ MATERIALIZE */
               p.prac_id,
               p.imie,
               p.nazwisko,
               p.nr_ew,
               p.nr_karty,
               LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30') AS data_ref,
               akt_dane.j_org(
                   p.prac_id,
                   LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')
               ) AS jednostka_org,
               akt_dane.mpk(
                   p.prac_id,
                   LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')
               ) AS mpk,
               akt_dane.stanowisko(
                   p.prac_id,
                   LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')
               ) AS stanowisko
        FROM t_prac p
        WHERE p.prac_id IN (SELECT prac_id FROM kalendarze)
    ),
    system_pracy AS (
        SELECT /*+ MATERIALIZE */
               ph.prac_id,
               b.dlugosc
        FROM prac_hr ph
        JOIN KP_RCP_WORKING_TIME_SYSTEMS scz
             ON scz.code = akt_dane.work_time_system(ph.prac_id, DATE '2026-06-30')
        JOIN KP_RCP_OKRESY_BILANSU b
             ON b.id = scz.rcok_id
    ),
    okres AS (
        SELECT /*+ MATERIALIZE */
               k.prac_id,
               sp.dlugosc,
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
               k.prac_id,
               sp.dlugosc,
               CASE
                   WHEN sp.dlugosc = 1 THEN TRUNC(k.dzien_mies, 'MM')
                   WHEN sp.dlugosc = 3 THEN TRUNC(k.dzien_mies, 'Q')
               END,
               CASE
                   WHEN sp.dlugosc = 1 THEN LAST_DAY(k.dzien_mies)
                   WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(k.dzien_mies, 'Q'), 2))
               END
    ),

    /* Dane kalendarza tylko dla potrzebnych pracowników
       Szerszy zakres dat aby obsłużyć D-1 i D+2 */
    kal_base AS (
        SELECT /*+ MATERIALIZE */
               prac_id,
               dzien_mies,
               typ_dnia,
               czas_do
        FROM NT_KP_KDR_KALENDARZE_PRAC
        WHERE dzien_mies BETWEEN DATE '2025-12-31' AND DATE '2026-07-02'
          AND prac_id IN (SELECT prac_id FROM kalendarze)
    ),

    /* Dni D gdzie D i D+1 mają typ_dnia IS NOT NULL */
    valid_pairs AS (
        SELECT /*+ MATERIALIZE */
               k1.prac_id,
               k1.dzien_mies AS d1
        FROM kal_base k1
        JOIN kal_base k2
             ON  k2.prac_id    = k1.prac_id
             AND k2.dzien_mies = k1.dzien_mies + 1
             AND k2.typ_dnia  IS NOT NULL
        WHERE k1.typ_dnia IS NOT NULL
          AND k1.dzien_mies BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'
    ),

    /* D-1 i D+2 pobierane z kal_base
       czas_do zawiera tylko składową czasową (data referencyjna 2008-09-01)
       dlatego czas rzeczywisty = TRUNC(dzien_mies) + (czas_do - TRUNC(czas_do)) */
    pary AS (
        SELECT /*+ MATERIALIZE */
               vp.prac_id,
               vp.d1,
               TO_CHAR(
                   TRUNC(k_po.dzien_mies) + (k_po.czas_do - TRUNC(k_po.czas_do)),
                   'dd-mm-yyyy HH24:MI'
               ) || ' - ' || TO_CHAR(
                   TRUNC(k_przed.dzien_mies) + (k_przed.czas_do - TRUNC(k_przed.czas_do)),
                   'dd-mm-yyyy HH24:MI'
               )                                                             AS odejmowanie,
               ROUND((
                   (TRUNC(k_po.dzien_mies)    + (k_po.czas_do    - TRUNC(k_po.czas_do)))
                 - (TRUNC(k_przed.dzien_mies) + (k_przed.czas_do - TRUNC(k_przed.czas_do)))
               ) * 24, 2)                                                    AS roznica_h
        FROM valid_pairs vp
        LEFT JOIN kal_base k_przed
             ON  k_przed.prac_id    = vp.prac_id
             AND k_przed.dzien_mies = vp.d1 - 1
        LEFT JOIN kal_base k_po
             ON  k_po.prac_id    = vp.prac_id
             AND k_po.dzien_mies = vp.d1 + 2
    ),

    /* Agregacja par do poziomu (pracownik, okres, tydzień)
       Brak filtra po koniec_okresu — tygodnie są generowane do 2026-06-30
       niezależnie od nominalnego końca okresu rozliczeniowego */
    pary_agg AS (
        SELECT /*+ MATERIALIZE */
               par.prac_id,
               o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7) AS nr_tygodnia,
               MIN(par.odejmowanie)                      AS odejmowanie,
               ROUND(SUM(par.roznica_h), 2)              AS suma_roznica_h
        FROM pary par
        JOIN okres o
             ON  o.prac_id  = par.prac_id
             AND par.d1    >= o.poczatek_okresu
        GROUP BY
               par.prac_id,
               o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)
    )

SELECT
       p.imie,
       p.nazwisko,
       p.nr_ew,
       p.nr_karty,
       p.jednostka_org AS "jednostka organizacyjna",
       p.mpk,
       p.stanowisko,
       CASE o.dlugosc
           WHEN 1 THEN '1 - miesięczny okres rozliczeniowy'
           WHEN 3 THEN '3 - miesięczny okres rozliczeniowy'
       END AS "okres rozliczeniowy",
       TO_CHAR(o.poczatek_okresu, 'dd-mm-yyyy') AS "pierwszy dzień okresu rozliczeniowego",
       'od ' || TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy')
           || ' do ' || TO_CHAR(
               LEAST(o.poczatek_okresu + t.nr * 7 + 6, DATE '2026-06-30'),
               'dd-mm-yyyy'
           ) AS "zakres tygodnia",
       pa.odejmowanie    AS "odejmowanie",
       pa.suma_roznica_h AS "suma różnic [h]"
FROM prac_hr p
JOIN okres o ON o.prac_id = p.prac_id
JOIN (
    SELECT LEVEL - 1 AS nr
    FROM DUAL
    CONNECT BY LEVEL <= 26
) t ON o.poczatek_okresu + t.nr * 7 <= DATE '2026-06-30'
LEFT JOIN pary_agg pa
       ON  pa.prac_id          = p.prac_id
       AND pa.poczatek_okresu  = o.poczatek_okresu
       AND pa.nr_tygodnia      = t.nr
ORDER BY p.nazwisko, p.imie, o.poczatek_okresu, t.nr;


-- =====================================================================
-- Nieprzerwany odpoczynek tygodniowy - wersja 3 (poprawiona)
--
-- POPRAWKA wzgledem v1/v2:
--   Poprzednia logika zwijala wszystkie przerwy w oknie do jednego
--   przedzialu (MIN(start)/MAX(koniec)) i liczyla tylko odstep PRZED
--   pierwsza i PO ostatniej przerwie. Nie liczyla luki MIEDZY przerwami,
--   ktora czesto jest najdluzsza -> stad 21 h zamiast 40 h.
--
--   Tutaj liczymy rzeczywiscie najdluzsza ciagla luke metoda
--   gaps-and-islands: wszystkie przerwy (zdarzenia wtet_id=18 ∪ zlecone
--   nadgodziny) sa przyciete do okna [k_przed_dt, k_po_dt], scalone
--   (nakladajace sie), a nastepnie bierzemy MAX z wszystkich wolnych luk.
-- =====================================================================
WITH
    kalendarze AS (
        SELECT /*+ MATERIALIZE */
               k.id, k.prac_id, k.dzien_mies
        FROM NT_KP_KDR_KALENDARZE_PRAC k
        WHERE k.TYP_DNIA = 'W'
          AND k.DZIEN_MIES BETWEEN DATE '2026-06-01' AND DATE '2026-07-05'
    ),
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
    system_pracy AS (
        SELECT /*+ MATERIALIZE */
               ph.prac_id, b.dlugosc
        FROM prac_hr ph
        JOIN KP_RCP_WORKING_TIME_SYSTEMS scz
             ON scz.code = akt_dane.work_time_system(ph.prac_id, DATE '2026-07-05')
        JOIN KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
    ),
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
    kal_base AS (
        SELECT /*+ MATERIALIZE */
               prac_id, dzien_mies, typ_dnia, czas_do, czas_od
        FROM NT_KP_KDR_KALENDARZE_PRAC
        WHERE dzien_mies BETWEEN DATE '2026-05-31' AND DATE '2026-07-07'
          AND prac_id IN (SELECT prac_id FROM kalendarze)
    ),
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
    -- ----------------------------------------------------------------
    -- Okno odpoczynku dla kazdej pary dni wolnych:
    --   k_przed_dt = koniec pracy w dniu d1-1
    --   k_po_dt    = poczatek pracy w dniu d1+2
    -- ----------------------------------------------------------------
    pary_okno AS (
        SELECT /*+ MATERIALIZE */
               vp.prac_id,
               vp.d1,
               TRUNC(k_przed.dzien_mies) + (k_przed.czas_do - TRUNC(k_przed.czas_do)) AS k_przed_dt,
               TRUNC(k_po.dzien_mies)    + (k_po.czas_od    - TRUNC(k_po.czas_od))    AS k_po_dt
        FROM valid_pairs vp
        LEFT JOIN kal_base k_przed
               ON  k_przed.prac_id    = vp.prac_id
               AND k_przed.dzien_mies = vp.d1 - 1
        LEFT JOIN kal_base k_po
               ON  k_po.prac_id    = vp.prac_id
               AND k_po.dzien_mies = vp.d1 + 2
    ),
    -- ----------------------------------------------------------------
    -- Wszystkie przerwy (zdarzenia ∪ nadgodziny) PRZYCIETE do okna.
    -- Warunek nakladania sie eliminuje przedzialy lezace calkowicie
    -- poza oknem (np. w godzinach pracy dnia d1-1 albo d1+2).
    -- ----------------------------------------------------------------
    przerwy AS (
        SELECT /*+ MATERIALIZE */
               po.prac_id, po.d1, po.k_przed_dt, po.k_po_dt,
               GREATEST(z.z_od_dt, po.k_przed_dt) AS p_od,
               LEAST(z.z_do_dt,    po.k_po_dt)    AS p_do
        FROM pary_okno po
        JOIN zdarzenia z
             ON  z.prac_id = po.prac_id
             AND z.z_do_dt > po.k_przed_dt
             AND z.z_od_dt < po.k_po_dt
        UNION ALL
        SELECT po.prac_id, po.d1, po.k_przed_dt, po.k_po_dt,
               GREATEST(n.n_od_dt, po.k_przed_dt) AS p_od,
               LEAST(n.n_do_dt,    po.k_po_dt)    AS p_do
        FROM pary_okno po
        JOIN nadgodziny n
             ON  n.prac_id = po.prac_id
             AND n.n_do_dt > po.k_przed_dt
             AND n.n_od_dt < po.k_po_dt
    ),
    -- ----------------------------------------------------------------
    -- Scalanie nakladajacych sie przerw (gaps-and-islands).
    -- ----------------------------------------------------------------
    przerwy_ord AS (
        SELECT /*+ MATERIALIZE */
               prac_id, d1, k_przed_dt, k_po_dt, p_od, p_do,
               MAX(p_do) OVER (
                   PARTITION BY prac_id, d1
                   ORDER BY p_od, p_do
                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
               ) AS poprz_max_do
        FROM przerwy
    ),
    przerwy_grp AS (
        SELECT /*+ MATERIALIZE */
               prac_id, d1, k_przed_dt, k_po_dt, p_od, p_do,
               SUM(CASE WHEN poprz_max_do IS NULL OR p_od > poprz_max_do
                        THEN 1 ELSE 0 END)
                   OVER (PARTITION BY prac_id, d1
                         ORDER BY p_od, p_do
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS grp
        FROM przerwy_ord
    ),
    przerwy_merged AS (
        SELECT /*+ MATERIALIZE */
               prac_id, d1,
               MIN(k_przed_dt) AS k_przed_dt,
               MIN(k_po_dt)    AS k_po_dt,
               MIN(p_od)       AS m_od,
               MAX(p_do)       AS m_do
        FROM przerwy_grp
        GROUP BY prac_id, d1, grp
    ),
    -- ----------------------------------------------------------------
    -- Wolne luki: przed pierwsza przerwa, miedzy przerwami, po ostatniej.
    -- ----------------------------------------------------------------
    przerwy_gaps AS (
        SELECT /*+ MATERIALIZE */
               prac_id, d1, k_przed_dt, k_po_dt, m_od, m_do,
               LAG(m_do) OVER (PARTITION BY prac_id, d1 ORDER BY m_od) AS poprz_m_do,
               ROW_NUMBER() OVER (PARTITION BY prac_id, d1 ORDER BY m_od) AS rn,
               COUNT(*)     OVER (PARTITION BY prac_id, d1)              AS cnt
        FROM przerwy_merged
    ),
    roznica AS (
        SELECT /*+ MATERIALIZE */
               prac_id, d1, ROUND(MAX(gap_h), 2) AS roznica_h
        FROM (
            -- luka przed dana przerwa (dla pierwszej: od poczatku okna)
            SELECT prac_id, d1,
                   (m_od - NVL(poprz_m_do, k_przed_dt)) * 24 AS gap_h
            FROM przerwy_gaps
            UNION ALL
            -- luka po ostatniej przerwie (do konca okna)
            SELECT prac_id, d1,
                   (k_po_dt - m_do) * 24 AS gap_h
            FROM przerwy_gaps
            WHERE rn = cnt
        )
        GROUP BY prac_id, d1
    ),
    -- ----------------------------------------------------------------
    -- Finalna roznica na pare. Gdy brak przerw -> pelne okno.
    -- ----------------------------------------------------------------
    pary AS (
        SELECT /*+ MATERIALIZE */
               po.prac_id,
               po.d1,
               TO_CHAR(po.k_po_dt,    'dd-mm-yyyy HH24:MI')
                   || ' - '
                   || TO_CHAR(po.k_przed_dt, 'dd-mm-yyyy HH24:MI') AS odejmowanie,
               NVL(r.roznica_h, ROUND((po.k_po_dt - po.k_przed_dt) * 24, 2)) AS roznica_h
        FROM pary_okno po
        LEFT JOIN roznica r
               ON  r.prac_id = po.prac_id
               AND r.d1      = po.d1
    ),
    pary_agg AS (
        SELECT /*+ MATERIALIZE */
               par.prac_id,
               o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7) AS nr_tygodnia,
               MIN(par.odejmowanie)                      AS odejmowanie,
               ROUND(SUM(par.roznica_h), 2)              AS suma_roznica_h
        FROM pary par
        JOIN okres o
             ON  o.prac_id  = par.prac_id
             AND par.d1    >= o.poczatek_okresu
             AND par.d1    <= o.koniec_okresu
        GROUP BY
               par.prac_id, o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)
    ),
    zdarzenia_agg AS (
        SELECT /*+ MATERIALIZE */
               ze.prac_id,
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
        GROUP BY
               ze.prac_id, o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)
    ),
    nadgodziny_agg AS (
        SELECT /*+ MATERIALIZE */
               n.prac_id,
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
        GROUP BY
               n.prac_id, o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7)
    ),
    godz_od_do_agg AS (
        SELECT /*+ MATERIALIZE */
               kb.prac_id,
               o.poczatek_okresu,
               FLOOR((kb.dzien_mies - o.poczatek_okresu) / 7) AS nr_tygodnia,
               LISTAGG(
                   TO_CHAR(kb.dzien_mies, 'dd-mm-yyyy')
                       || ' '
                       || TO_CHAR(TRUNC(kb.dzien_mies) + (kb.czas_od - TRUNC(kb.czas_od)), 'HH24:MI'),
                   ', '
               ) WITHIN GROUP (ORDER BY kb.dzien_mies)         AS godz_od,
               LISTAGG(
                   TO_CHAR(kb.dzien_mies, 'dd-mm-yyyy')
                       || ' '
                       || TO_CHAR(TRUNC(kb.dzien_mies) + (kb.czas_do - TRUNC(kb.czas_do)), 'HH24:MI'),
                   ', '
               ) WITHIN GROUP (ORDER BY kb.dzien_mies)         AS godz_do
        FROM kal_base kb
        JOIN okres o
             ON  o.prac_id     = kb.prac_id
             AND kb.dzien_mies >= o.poczatek_okresu
             AND kb.dzien_mies <= o.koniec_okresu
        WHERE kb.typ_dnia IS NOT NULL
          AND kb.dzien_mies BETWEEN DATE '2026-06-01' AND DATE '2026-07-05'
        GROUP BY
               kb.prac_id,
               o.poczatek_okresu,
               FLOOR((kb.dzien_mies - o.poczatek_okresu) / 7)
    )

SELECT
       p.imie,
       p.nazwisko,
       p.nr_ew,
       p.nr_karty,
       p.jednostka_org AS "jednostka organizacyjna",
       p.mpk,
       p.stanowisko,
       CASE o.dlugosc
           WHEN 1 THEN '1 - miesięczny okres rozliczeniowy'
           WHEN 3 THEN '3 - miesięczny okres rozliczeniowy'
       END AS "okres rozliczeniowy",
       TO_CHAR(o.poczatek_okresu, 'dd-mm-yyyy')
           AS "pierwszy dzień okresu rozliczeniowego",
       TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy')
           AS "pierwszy dzień tygodnia",
       'od ' || TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy')
           || ' do ' || TO_CHAR(
               LEAST(o.poczatek_okresu + t.nr * 7 + 6, DATE '2026-07-05'),
               'dd-mm-yyyy'
           ) AS "zakres tygodnia",
       gd.godz_od        AS "godzina od",
       gd.godz_do        AS "godzina do",
       pa.odejmowanie    AS "odejmowanie",
       pa.suma_roznica_h AS "suma różnic [h]",
       za.z_zdarzenia    AS "zdarzenia",
       na.n_nadgodziny   AS "zlecone nadgodziny"
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
LEFT JOIN godz_od_do_agg gd
       ON  gd.prac_id        = p.prac_id
       AND gd.poczatek_okresu = o.poczatek_okresu
       AND gd.nr_tygodnia    = t.nr
WHERE  pa.odejmowanie IS NOT NULL
--   AND  p.nr_ew = '44109003'
ORDER BY p.nazwisko, p.imie, o.poczatek_okresu, t.nr;

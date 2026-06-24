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

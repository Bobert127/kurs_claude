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
               prac_id, dzien_mies, czas_nom
        FROM NT_KP_KDR_KALENDARZE_PRAC
        WHERE dzien_mies BETWEEN DATE '2026-06-01' AND DATE '2026-07-05'
          AND prac_id IN (SELECT prac_id FROM kalendarze)
    ),
    nadgodziny AS (
        SELECT /*+ MATERIALIZE */
               n.prac_id,
               n.data,
               n.czas
        FROM KP_RCP_ZLEC_NADG_PRAC n
        WHERE n.prac_id IN (SELECT prac_id FROM prac_hr)
          AND n.data    BETWEEN DATE '2026-05-31' AND DATE '2026-07-07'
    ),
    nadg_tydz AS (
        SELECT /*+ MATERIALIZE */
               n.prac_id,
               o.poczatek_okresu,
               FLOOR((n.data - o.poczatek_okresu) / 7) AS nr_tygodnia,
               SUM(n.czas)                              AS suma_czas_nadg
        FROM nadgodziny n
        JOIN okres o
             ON  o.prac_id = n.prac_id
             AND n.data   >= o.poczatek_okresu
             AND n.data   <= o.koniec_okresu
        GROUP BY
               n.prac_id,
               o.poczatek_okresu,
               FLOOR((n.data - o.poczatek_okresu) / 7)
    ),
    czas_nom_agg AS (
        SELECT /*+ MATERIALIZE */
               kb.prac_id,
               o.poczatek_okresu,
               o.koniec_okresu,
               FLOOR((kb.dzien_mies - o.poczatek_okresu) / 7)  AS nr_tygodnia,
               ROUND(SUM(kb.czas_nom) / 3600, 2)               AS suma_kal_h,
               ROUND(NVL(MAX(nt.suma_czas_nadg), 0), 2)        AS suma_nadg_h,
               ROUND(
                   SUM(kb.czas_nom) / 3600
                   + NVL(MAX(nt.suma_czas_nadg), 0),
                   2
               )                                                AS suma_czas_nom_h
        FROM kal_base kb
        JOIN okres o
             ON  o.prac_id     = kb.prac_id
             AND kb.dzien_mies >= o.poczatek_okresu
             AND kb.dzien_mies <= o.koniec_okresu
        LEFT JOIN nadg_tydz nt
             ON  nt.prac_id        = kb.prac_id
             AND nt.poczatek_okresu = o.poczatek_okresu
             AND nt.nr_tygodnia    = FLOOR((kb.dzien_mies - o.poczatek_okresu) / 7)
        GROUP BY
               kb.prac_id,
               o.poczatek_okresu,
               o.koniec_okresu,
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
       TO_CHAR(o.poczatek_okresu, 'dd-mm-yyyy') AS "pierwszy dzień okresu rozliczeniowego",
       TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy') AS "pierwszy dzień tygodnia",
       'od ' || TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy')
           || ' do ' || TO_CHAR(
               LEAST(o.poczatek_okresu + t.nr * 7 + 6, DATE '2026-07-05'),
               'dd-mm-yyyy'
           ) AS "zakres tygodnia",
       cn.suma_kal_h                                          AS "CZAS_NOM z kalendarza [h]",
       cn.suma_nadg_h                                         AS "suma CZAS nadgodzin [h]",
       cn.suma_czas_nom_h                                     AS "suma CZAS_NOM [h]",
       ROUND(
           AVG(cn.suma_czas_nom_h) OVER (
               PARTITION BY p.prac_id, o.poczatek_okresu, o.koniec_okresu
           ), 2
       )                                                      AS "średnia CZAS_NOM w okresie [h]"
FROM prac_hr p
JOIN okres o ON o.prac_id = p.prac_id
JOIN (
    SELECT LEVEL - 1 AS nr
    FROM DUAL
    CONNECT BY LEVEL <= 26
) t ON o.poczatek_okresu + t.nr * 7 BETWEEN DATE '2026-06-01' AND DATE '2026-07-05'
JOIN czas_nom_agg cn
       ON  cn.prac_id        = p.prac_id
       AND cn.poczatek_okresu = o.poczatek_okresu
       AND cn.nr_tygodnia    = t.nr
ORDER BY p.nazwisko, p.imie, o.poczatek_okresu, t.nr;

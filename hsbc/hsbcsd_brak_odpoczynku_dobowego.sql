-- Wersja 1
WITH kalendarz AS (
    SELECT
        k.prac_id,
        k.id,
        k.dzien_mies,
        k.czas_od,
        k.czas_do,
        k.typ_dnia,
        LEAD(k.czas_od)    OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_czas_od,
        LEAD(k.dzien_mies) OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_dzien_mies,
        LEAD(k.typ_dnia)   OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_typ_dnia
    FROM NT_KP_KDR_KALENDARZE_PRAC k
    WHERE k.DZIEN_MIES BETWEEN '26/06/01' AND '26/07/01'
),
z_ostatni AS (
    SELECT z.*, ROW_NUMBER() OVER (PARTITION BY z.prac_id, z.kali_id ORDER BY z.godz_do DESC) AS rn,
           COUNT(z.id)    OVER (PARTITION BY z.prac_id, z.kali_id) AS ile_zlecen
    FROM KP_RCP_ZLEC_NADG_PRAC z
)
SELECT
    p.imie,
    p.nazwisko,
    p.nr_ew,
    p.nr_karty,
    k.dzien_mies,
    TO_CHAR(k.czas_od,      'HH24:MI') AS k_godz_od,
    TO_CHAR(k.czas_do,      'HH24:MI') AS k_godz_do,
    TO_CHAR(z.godz_od,      'HH24:MI') AS z_godz_od,
    TO_CHAR(z.godz_do,      'HH24:MI') AS z_godz_do,
    z.ile_zlecen,
    TO_CHAR(k.next_czas_od, 'HH24:MI') AS next_godz_od,
    k.next_dzien_mies,
    k.next_typ_dnia,
    CASE
        WHEN k.next_typ_dnia IS NOT NULL THEN 16
        WHEN k.next_czas_od IS NULL THEN NULL
        WHEN z.godz_od IS NOT NULL AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                      - (TRUNC(k.dzien_mies)       + (z.godz_do      - TRUNC(z.godz_do)))) * 24, 2)
        ELSE
            ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                 - (TRUNC(k.dzien_mies)       + (k.czas_do      - TRUNC(k.czas_do)))) * 24, 2)
    END AS godz_odpoczynku,
    CASE
        WHEN k.next_typ_dnia IS NOT NULL THEN 'OK - nastepny dzien wolny'
        WHEN k.next_czas_od IS NULL THEN 'BRAK NASTEPNEJ ZMIANY'
        WHEN z.godz_od IS NOT NULL
             AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                - (TRUNC(k.dzien_mies)       + (z.godz_do      - TRUNC(z.godz_do)))) * 24 < 11
            THEN 'NARUSZENIE - koniec nadgodzin < 11h do nastepnej zmiany'
        WHEN (z.godz_od IS NULL OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do)))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                - (TRUNC(k.dzien_mies)       + (k.czas_do      - TRUNC(k.czas_do)))) * 24 < 11
            THEN 'NARUSZENIE - koniec zmiany < 11h do nastepnej zmiany'
        ELSE 'OK'
    END AS status_odpoczynku
FROM t_prac p
JOIN kalendarz k ON p.prac_id = k.prac_id
LEFT JOIN z_ostatni z ON z.prac_id = k.prac_id AND k.id = z.kali_id AND z.rn = 1
WHERE k.dzien_mies BETWEEN '26/06/01' AND '26/06/30'
  -- AND p.prac_id = 76220
  AND k.typ_dnia IS NULL
ORDER BY p.nazwisko, p.imie, k.dzien_mies;


-- Wersja 2 - poprawa nagłówków
WITH kalendarz AS (
    SELECT
        k.prac_id,
        k.id,
        k.dzien_mies,
        k.czas_od,
        k.czas_do,
        k.typ_dnia,
        LEAD(k.czas_od)    OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_czas_od,
        LEAD(k.dzien_mies) OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_dzien_mies,
        LEAD(k.typ_dnia)   OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_typ_dnia
    FROM NT_KP_KDR_KALENDARZE_PRAC k
    WHERE k.DZIEN_MIES BETWEEN '26/06/01' AND '26/07/01'
),
z_ostatni AS (
    SELECT
        z.*,
        ROW_NUMBER()  OVER (PARTITION BY z.prac_id, z.kali_id ORDER BY z.godz_do DESC) AS rn,
        COUNT(z.id)   OVER (PARTITION BY z.prac_id, z.kali_id)                          AS ile_zlecen,
        FIRST_VALUE(z.godz_od) OVER (PARTITION BY z.prac_id, z.kali_id ORDER BY z.godz_od ASC) AS pierwsze_godz_od
    FROM KP_RCP_ZLEC_NADG_PRAC z
)
SELECT
    p.imie,
    p.nazwisko,
    p.nr_ew                                          AS "numer ewidencyjny",
    p.nr_karty                                       AS "nr karty",
    to_char(k.dzien_mies, 'DD-MM-YYYY')              AS "dzień miesiąca",
    TO_CHAR(k.czas_od,          'HH24:MI')           AS "początek pracy",
    TO_CHAR(k.czas_do,          'HH24:MI')           AS "koniec pracy",
    TO_CHAR(z.pierwsze_godz_od, 'HH24:MI')           AS "początek pierwsego lecenia",
    TO_CHAR(z.godz_od,          'HH24:MI')           AS "początek zlecenia",
    TO_CHAR(z.godz_do,          'HH24:MI')           AS "koniec zlecenia",
    z.ile_zlecen                                     AS "ilość zleceń",
    TO_CHAR(k.next_czas_od,     'HH24:MI')           AS "początek pracy następny dzień",
    TO_CHAR(k.next_dzien_mies, 'DD-MM-YYYYY')        AS "następny dzień",
    CASE k.next_typ_dnia
        WHEN 'N'  THEN 'Niedziela'
        WHEN 'S'  THEN 'Święto'
        WHEN 'WN' THEN 'Wolne za niedzielę'
        WHEN 'WS' THEN 'Wolne za święto'
        WHEN 'SO' THEN 'Wolne za niedzielę i święto'
        WHEN 'C'  THEN 'Wolne harmonogramowo'
        WHEN 'W'  THEN 'Dzień wolny'
        WHEN 'R'  THEN 'Dzień roboczy'
        ELSE k.next_typ_dnia
    END                                              AS "rodzaj dnia  następnego",
    CASE
        WHEN k.next_typ_dnia IS NOT NULL THEN 16
        WHEN k.next_czas_od IS NULL THEN NULL
        WHEN z.godz_od IS NOT NULL AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                      - (TRUNC(k.dzien_mies)       + (z.godz_do      - TRUNC(z.godz_do)))) * 24, 2)
        ELSE
            ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                 - (TRUNC(k.dzien_mies)       + (k.czas_do      - TRUNC(k.czas_do)))) * 24, 2)
    END AS godz_odpoczynku,
    CASE
        WHEN k.next_typ_dnia IS NOT NULL THEN 'OK - nastepny dzien wolny'
        WHEN k.next_czas_od IS NULL THEN 'BRAK NASTEPNEJ ZMIANY'
        WHEN z.godz_od IS NOT NULL AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                - (TRUNC(k.dzien_mies)       + (z.godz_do      - TRUNC(z.godz_do)))) * 24 < 11
            THEN 'NARUSZENIE - koniec nadgodzin < 11h do nastepnej zmiany'
        WHEN (z.godz_od IS NULL OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do)))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                - (TRUNC(k.dzien_mies)       + (k.czas_do      - TRUNC(k.czas_do)))) * 24 < 11
            THEN 'NARUSZENIE - koniec zmiany < 11h do nastepnej zmiany'
        ELSE 'OK'
    END AS "czy zachowano odpoczynek dobowy"
FROM t_prac p
JOIN kalendarz k ON p.prac_id = k.prac_id
LEFT JOIN z_ostatni z ON z.prac_id = k.prac_id AND k.id = z.kali_id AND z.rn = 1
WHERE k.dzien_mies BETWEEN '26/06/01' AND '26/06/30'
  -- AND p.prac_id = 76220
  AND k.typ_dnia IS NULL
ORDER BY p.nazwisko, p.imie, k.dzien_mies;


-- Wersja 3 - przerwa dobowa z uwzględnieniem dyżuru
WITH kalendarz AS (
    SELECT
        k.prac_id,
        k.id,
        k.dzien_mies,
        k.czas_od,
        k.czas_do,
        k.typ_dnia,
        LEAD(k.czas_od)    OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_czas_od,
        LEAD(k.dzien_mies) OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_dzien_mies,
        LEAD(k.typ_dnia)   OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_typ_dnia
    FROM NT_KP_KDR_KALENDARZE_PRAC k
    WHERE k.DZIEN_MIES BETWEEN '26/06/01' AND '26/07/01'
),
z_ostatni AS (
    SELECT
        z.*,
        ROW_NUMBER()  OVER (PARTITION BY z.prac_id, z.kali_id ORDER BY z.godz_do DESC)        AS rn,
        COUNT(z.id)   OVER (PARTITION BY z.prac_id, z.kali_id)                                 AS ile_zlecen,
        FIRST_VALUE(z.godz_od) OVER (PARTITION BY z.prac_id, z.kali_id ORDER BY z.godz_od ASC) AS pierwsze_godz_od
    FROM KP_RCP_ZLEC_NADG_PRAC z
),
zdarzenia AS (
    SELECT
        zd.prac_id,
        zd.workday_date,
        zd.date_time_from,
        zd.date_time_to,
        ROW_NUMBER() OVER (PARTITION BY zd.prac_id, TRUNC(zd.workday_date) ORDER BY zd.date_time_to DESC) AS rn_zd,
        COUNT(*)     OVER (PARTITION BY zd.prac_id, TRUNC(zd.workday_date))                               AS ile_zdarzen
    FROM KP_RCP_WORK_TIME_EVENTS zd
    WHERE zd.wtet_id = 18
      AND zd.workday_date BETWEEN '26/06/01' AND '26/07/01'
)
SELECT
    p.imie,
    p.nazwisko,
    p.nr_ew                                          AS "numer ewidencyjny",
    p.nr_karty                                       AS "nr karty",
    TO_CHAR(k.dzien_mies,       'DD-MM-YYYY')        AS "dzień miesiąca",
    TO_CHAR(k.czas_od,          'HH24:MI')           AS "początek pracy",
    TO_CHAR(k.czas_do,          'HH24:MI')           AS "koniec pracy",
    TO_CHAR(z.pierwsze_godz_od, 'HH24:MI')           AS "początek pierwszego zlecenia",
    TO_CHAR(z.godz_od,          'HH24:MI')           AS "początek zlecenia",
    TO_CHAR(z.godz_do,          'HH24:MI')           AS "koniec zlecenia",
    z.ile_zlecen                                     AS "ilość zleceń",
    TO_CHAR(zd.date_time_from,  'HH24:MI')           AS "początek dyżuru",
    TO_CHAR(zd.date_time_to,    'HH24:MI')           AS "koniec dyżuru",
    zd.ile_zdarzen                                   AS "ilość dyżurów",
    CASE
        WHEN k.next_typ_dnia IS NOT NULL
            THEN 16
        WHEN k.next_czas_od IS NULL
            THEN NULL
        WHEN zd.date_time_to IS NOT NULL
             AND zd.date_time_to >= (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))
             AND (   z.godz_od IS NULL
                  OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do))
                  OR zd.date_time_to >= (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do))))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                        - zd.date_time_to) * 24, 2)
        WHEN z.godz_od IS NOT NULL
             AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                        - (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do)))) * 24, 2)
        ELSE
            ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                   - (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))) * 24, 2)
    END AS "odpoczynek z uwzględnieniem dyżuru",
    TO_CHAR(k.next_czas_od,    'HH24:MI')            AS "początek pracy następny dzień",
    TO_CHAR(k.next_dzien_mies, 'DD-MM-YYYY')         AS "następny dzień",
    CASE k.next_typ_dnia
        WHEN 'N'  THEN 'Niedziela'
        WHEN 'S'  THEN 'Święto'
        WHEN 'WN' THEN 'Wolne za niedzielę'
        WHEN 'WS' THEN 'Wolne za święto'
        WHEN 'SO' THEN 'Wolne za niedzielę i święto'
        WHEN 'C'  THEN 'Wolne harmonogramowo'
        WHEN 'W'  THEN 'Dzień wolny'
        WHEN 'R'  THEN 'Dzień roboczy'
        ELSE k.next_typ_dnia
    END AS "rodzaj dnia następnego",
    CASE
        WHEN k.next_typ_dnia IS NOT NULL
            THEN 16
        WHEN k.next_czas_od IS NULL
            THEN NULL
        WHEN zd.date_time_to IS NOT NULL
             AND zd.date_time_to >= (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))
             AND (   z.godz_od IS NULL
                  OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do))
                  OR zd.date_time_to >= (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do))))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                        - zd.date_time_to) * 24, 2)
        WHEN z.godz_od IS NOT NULL
             AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                        - (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do)))) * 24, 2)
        ELSE
            ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                   - (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))) * 24, 2)
    END AS "godziny odpoczynku",
    CASE
        WHEN k.next_typ_dnia IS NOT NULL
            THEN 'OK - następny dzień wolny'
        WHEN k.next_czas_od IS NULL
            THEN 'BRAK NASTĘPNEJ ZMIANY'
        WHEN zd.date_time_to IS NOT NULL
             AND zd.date_time_to >= (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))
             AND (   z.godz_od IS NULL
                  OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do))
                  OR zd.date_time_to >= (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do))))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                  - zd.date_time_to) * 24 < 11
            THEN 'NARUSZENIE - koniec dyżuru < 11h do następnej zmiany'
        WHEN z.godz_od IS NOT NULL
             AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                  - (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do)))) * 24 < 11
            THEN 'NARUSZENIE - koniec nadgodzin < 11h do następnej zmiany'
        WHEN (z.godz_od IS NULL OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do)))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                  - (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))) * 24 < 11
            THEN 'NARUSZENIE - koniec zmiany < 11h do następnej zmiany'
        ELSE 'OK'
    END AS "czy zachowano odpoczynek dobowy"
FROM t_prac p
JOIN  kalendarz k  ON p.prac_id = k.prac_id
LEFT JOIN z_ostatni z  ON z.prac_id = k.prac_id AND k.id = z.kali_id AND z.rn = 1
LEFT JOIN zdarzenia zd ON zd.prac_id = p.prac_id
                       AND TRUNC(zd.workday_date) = TRUNC(k.dzien_mies)
                       AND zd.rn_zd = 1
WHERE k.dzien_mies BETWEEN '26/06/01' AND '26/07/01'
  -- AND p.nr_ew = '43996156'
  AND k.typ_dnia IS NULL
ORDER BY p.nazwisko, p.imie, k.dzien_mies;


-- Wersja 4 - norma tygodniowa: CZAS_NOM z kalendarza + nadgodziny w rozbiciu na tygodnie
WITH
        kalendarze AS (
            SELECT /*+ MATERIALIZE */
                   k.prac_id, k.dzien_mies
            FROM NT_KP_KDR_KALENDARZE_PRAC k
            WHERE k.TYP_DNIA = 'W'
              AND k.DZIEN_MIES BETWEEN DATE '2026-01-01' AND DATE '2026-04-06'
        ),
        prac_hr AS (
            SELECT /*+ MATERIALIZE */
                   p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
                   LEAST(NVL(p.data_rozw, DATE '2026-04-06'), DATE '2026-04-06') AS data_ref, akt_dane.j_org(p.prac_id, LEAST(NVL(p.data_rozw, DATE '2026-04-06'), DATE '2026-04-06')) AS jednostka_org,
                   akt_dane.mpk(p.prac_id, LEAST(NVL(p.data_rozw, DATE '2026-04-06'), DATE '2026-04-06')) AS mpk,
                   akt_dane.stanowisko(p.prac_id, LEAST(NVL(p.data_rozw, DATE '2026-04-06'), DATE '2026-04-06')) AS stanowisko
            FROM t_prac p
            WHERE p.prac_id IN (SELECT prac_id FROM kalendarze)
        ),
        system_pracy AS (
            SELECT /*+ MATERIALIZE */
                   ph.prac_id, b.dlugosc
            FROM prac_hr ph
            JOIN KP_RCP_WORKING_TIME_SYSTEMS scz
                 ON scz.code = akt_dane.work_time_system(ph.prac_id, DATE '2026-04-06')
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
            WHERE dzien_mies BETWEEN DATE '2026-01-01' AND DATE '2026-04-06'
              AND prac_id IN (SELECT prac_id FROM kalendarze)
              AND czas_nom IS NOT NULL
        ),
        nadgodziny AS (
            SELECT /*+ MATERIALIZE */
                   n.prac_id,
                   n.data,
                   n.czas
            FROM KP_RCP_ZLEC_NADG_PRAC n
            WHERE n.prac_id IN (SELECT prac_id FROM prac_hr)
              AND n.data BETWEEN DATE '2026-01-01' AND DATE '2026-04-06'
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

  SELECT /*+ LEADING(p o t cn) USE_HASH(cn) */
        ROW_NUMBER() OVER (ORDER BY NLSSORT(p.nazwisko, 'NLS_SORT=POLISH'), NLSSORT(p.imie,'NLS_SORT=POLISH')) AS lp,
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
         TO_CHAR(o.poczatek_okresu, 'dd-mm-yyyy') AS "pierwszy dzien okresu rozliczeniowego",
         TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy') AS "pierwszy dzien tygodnia",
         'od ' || TO_CHAR(o.poczatek_okresu + t.nr * 7, 'dd-mm-yyyy')
             || ' do ' || TO_CHAR(
                 LEAST(o.poczatek_okresu + t.nr * 7 + 6, DATE '2026-04-06'),
                 'dd-mm-yyyy'
             ) AS "zakres tygodnia",
         cn.suma_kal_h      AS "CZAS_NOM z kalendarza [h]",
         cn.suma_nadg_h     AS "suma CZAS nadgodzin [h]",
         cn.suma_czas_nom_h AS "suma CZAS_NOM [h]",
         ROUND(
             AVG(cn.suma_czas_nom_h) OVER (
                 PARTITION BY p.prac_id, o.poczatek_okresu, o.koniec_okresu
             ), 2
         ) AS "srednia CZAS_NOM w okresie [h]"
  FROM prac_hr p
  JOIN okres o ON o.prac_id = p.prac_id
  JOIN (
      SELECT LEVEL - 1 AS nr
      FROM DUAL
      CONNECT BY LEVEL <= 26
  ) t ON o.poczatek_okresu + t.nr * 7 BETWEEN DATE '2026-01-01' AND DATE '2026-04-06'
  JOIN czas_nom_agg cn
         ON  cn.prac_id        = p.prac_id
         AND cn.poczatek_okresu = o.poczatek_okresu
         AND cn.nr_tygodnia    = t.nr
  ORDER BY p.nazwisko, p.imie, o.poczatek_okresu, t.nr;


-- Wersja 5 - obudowanie zewnętrznym SELECT + lp, skrócone nazwy kolumn (poprawione puste THEN)
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
    odpoczynek_z_uwzgl_dyzuru,
    poczatek_pracy_nas_dzien,
    nastepny_dzien,
    rodzaj_dnia_nastepnego,
    godziny_odpoczynku,
    czy_zach_odpoczynek_dobowy
FROM (
WITH kalendarz AS (
    SELECT
        k.prac_id,
        k.id,
        k.dzien_mies,
        k.czas_od,
        k.czas_do,
        k.typ_dnia,
        LEAD(k.czas_od)    OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_czas_od,
        LEAD(k.dzien_mies) OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_dzien_mies,
        LEAD(k.typ_dnia)   OVER (PARTITION BY k.prac_id ORDER BY k.dzien_mies) AS next_typ_dnia
    FROM NT_KP_KDR_KALENDARZE_PRAC k
    WHERE k.DZIEN_MIES BETWEEN to_date('2026-06-01', 'yyyy-MM-dd') AND to_date('2026-06-10', 'yyyy-MM-dd')
),
z_ostatni AS (
    SELECT
        z.*,
        ROW_NUMBER()  OVER (PARTITION BY z.prac_id, z.kali_id ORDER BY z.godz_do DESC)        AS rn,
        COUNT(z.id)   OVER (PARTITION BY z.prac_id, z.kali_id)                                 AS ile_zlecen,
        FIRST_VALUE(z.godz_od) OVER (PARTITION BY z.prac_id, z.kali_id ORDER BY z.godz_od ASC) AS pierwsze_godz_od
    FROM KP_RCP_ZLEC_NADG_PRAC z
),
zdarzenia AS (
    SELECT
        zd.prac_id,
        zd.workday_date,
        zd.date_time_from,
        zd.date_time_to,
        ROW_NUMBER() OVER (PARTITION BY zd.prac_id, TRUNC(zd.workday_date) ORDER BY zd.date_time_to DESC) AS rn_zd,
        COUNT(*)     OVER (PARTITION BY zd.prac_id, TRUNC(zd.workday_date))                               AS ile_zdarzen
    FROM KP_RCP_WORK_TIME_EVENTS zd
    WHERE zd.wtet_id = 18
      AND zd.workday_date BETWEEN to_date('2026-06-01', 'yyyy-MM-dd') AND to_date('2026-06-10', 'yyyy-MM-dd')
)
SELECT
    ROW_NUMBER() OVER (ORDER BY NLSSORT(p.nazwisko, 'NLS_SORT=POLISH'), NLSSORT(p.imie,'NLS_SORT=POLISH')) AS lp,
    p.imie,
    p.nazwisko,
    p.nr_ew                                          AS numer_ewidencyjny,
    p.nr_karty                                       AS nr_karty,
    TO_CHAR(k.dzien_mies,       'yyyy-MM-dd')        AS dzien_miesiaca,
    TO_CHAR(k.czas_od,          'HH24:MI')           AS poczatek_pracy,
    TO_CHAR(k.czas_do,          'HH24:MI')           AS koniec_pracy,
    TO_CHAR(z.pierwsze_godz_od, 'HH24:MI')           AS poczatek_pier_zlecenia,
    TO_CHAR(z.godz_od,          'HH24:MI')           AS poczatek_zlecenia,
    TO_CHAR(z.godz_do,          'HH24:MI')           AS koniec_zlecenia,
    z.ile_zlecen                                     AS ilosc_zlecen,
    TO_CHAR(zd.date_time_from,  'HH24:MI')           AS poczatek_dyzuru,
    TO_CHAR(zd.date_time_to,    'HH24:MI')           AS koniec_dyzuru,
    zd.ile_zdarzen                                   AS ilosc_dyzurow,
    CASE
        WHEN k.next_typ_dnia IS NOT NULL
            THEN 16
        WHEN k.next_czas_od IS NULL
            THEN NULL
        WHEN zd.date_time_to IS NOT NULL
             AND zd.date_time_to >= (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))
             AND (   z.godz_od IS NULL
                  OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do))
                  OR zd.date_time_to >= (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do))))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                        - zd.date_time_to) * 24, 2)
        WHEN z.godz_od IS NOT NULL
             AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                        - (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do)))) * 24, 2)
        ELSE
            ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                   - (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))) * 24, 2)
    END AS odpoczynek_z_uwzgl_dyzuru,
    TO_CHAR(k.next_czas_od,    'HH24:MI')            AS poczatek_pracy_nas_dzien,
    TO_CHAR(k.next_dzien_mies, 'yyyy-MM-dd')         AS nastepny_dzien,
    CASE k.next_typ_dnia
        WHEN 'N'  THEN 'Niedziela'
        WHEN 'S'  THEN 'Święto'
        WHEN 'WN' THEN 'Wolne za niedzielę'
        WHEN 'WS' THEN 'Wolne za święto'
        WHEN 'SO' THEN 'Wolne za niedzielę i święto'
        WHEN 'C'  THEN 'Wolne harmonogramowo'
        WHEN 'W'  THEN 'Dzień wolny'
        WHEN 'R'  THEN 'Dzień roboczy'
        ELSE k.next_typ_dnia
    END AS rodzaj_dnia_nastepnego,
    CASE
        WHEN k.next_typ_dnia IS NOT NULL
            THEN 16
        WHEN k.next_czas_od IS NULL
            THEN NULL
        WHEN zd.date_time_to IS NOT NULL
             AND zd.date_time_to >= (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))
             AND (   z.godz_od IS NULL
                  OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do))
                  OR zd.date_time_to >= (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do))))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                        - zd.date_time_to) * 24, 2)
        WHEN z.godz_od IS NOT NULL
             AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
            THEN ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                        - (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do)))) * 24, 2)
        ELSE
            ROUND(((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                   - (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))) * 24, 2)
    END AS godziny_odpoczynku,
    CASE
        WHEN k.next_typ_dnia IS NOT NULL
            THEN 'OK - następny dzień wolny'
        WHEN k.next_czas_od IS NULL
            THEN 'BRAK NASTĘPNEJ ZMIANY'
        WHEN zd.date_time_to IS NOT NULL
             AND zd.date_time_to >= (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))
             AND (   z.godz_od IS NULL
                  OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do))
                  OR zd.date_time_to >= (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do))))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                  - zd.date_time_to) * 24 < 11
            THEN 'NARUSZENIE - koniec dyżuru < 11h do następnej zmiany'
        WHEN z.godz_od IS NOT NULL
             AND (z.godz_od - TRUNC(z.godz_od)) >= (k.czas_do - TRUNC(k.czas_do))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                  - (TRUNC(k.dzien_mies) + (z.godz_do - TRUNC(z.godz_do)))) * 24 < 11
            THEN 'NARUSZENIE - koniec nadgodzin < 11h do następnej zmiany'
        WHEN (z.godz_od IS NULL OR (z.godz_od - TRUNC(z.godz_od)) < (k.czas_do - TRUNC(k.czas_do)))
             AND ((TRUNC(k.next_dzien_mies) + (k.next_czas_od - TRUNC(k.next_czas_od)))
                  - (TRUNC(k.dzien_mies) + (k.czas_do - TRUNC(k.czas_do)))) * 24 < 11
            THEN 'NARUSZENIE - koniec zmiany < 11h do następnej zmiany'
        ELSE 'OK'
    END AS czy_zach_odpoczynek_dobowy
FROM t_prac p
JOIN  kalendarz k  ON p.prac_id = k.prac_id
LEFT JOIN z_ostatni z  ON z.prac_id = k.prac_id AND k.id = z.kali_id AND z.rn = 1
LEFT JOIN zdarzenia zd ON zd.prac_id = p.prac_id
                       AND TRUNC(zd.workday_date) = TRUNC(k.dzien_mies)
                       AND zd.rn_zd = 1
WHERE k.dzien_mies BETWEEN to_date('2026-06-01', 'yyyy-MM-dd') AND to_date('2026-06-10', 'yyyy-MM-dd')
  AND k.typ_dnia IS NULL
ORDER BY p.nazwisko, p.imie, k.dzien_mies);


-- =====================================================================
-- Wersja 6 - zoptymalizowana wydajnosciowo + poprawki poprawnosci
--
-- WYDAJNOSC (na podstawie planu wykonania):
--   Pierwotnie plan pokazywal NESTED LOOPS OUTER z VIEW PUSHED PREDICATE
--   (~13M kosztu, ~08:44) - agregat zlecen liczyl sie na kazdy z ~105 tys.
--   wierszy, pelnym skanem tabeli tymczasowej. FIX: MATERIALIZE NO_MERGE na
--   agregatach + LEADING/USE_HASH w 'dane' -> agregaty liczone RAZ, hash-join.
--
-- POPRAWNOSC:
--   FIX 1 (LEAD): kalendarz_src siega < data_do + 2, aby LEAD mial dzien
--          nastepny dla ostatniego dnia okresu (30-06 -> 01-07);
--          kalendarz_raport zostaje < data_do + 1 (sam czerwiec).
--   FIX 2: galaz dyzuru    -> 'NARUSZENIE - koniec dyzuru < 11h...'
--   FIX 3: galaz nadgodzin -> 'NARUSZENIE - koniec nadgodzin < 11h...'
--
-- Zapytanie WIELOWIERSZOWE. Wariant 'SELECT ... INTO v_...' dla silnika
-- raportowego: hsbcsd_brak_odpoczynku_dobowego_v7_into.sql
-- =====================================================================
WITH parametry AS (
    SELECT  TO_DATE('01-06-2026',  'dd-mm-yyyy' ) AS data_od,
            TO_DATE('30-06-2026',  'dd-mm-yyyy' ) AS data_do
    FROM dual
),
kalendarz_src AS (
    SELECT /*+ MATERIALIZE */
           k.prac_id, k.id, k.dzien_mies, k.czas_od, k.czas_do, k.typ_dnia
    FROM NT_KP_KDR_KALENDARZE_PRAC k
    CROSS JOIN parametry p
    WHERE k.dzien_mies >= p.data_od
      AND k.dzien_mies <  p.data_do + 2      -- FIX 1: +2 dla LEAD (dzien nastepny)
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
      AND k.dzien_mies <  p.data_do + 1      -- sam czerwiec
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
      AND zd.workday_date <  p.data_do + 1
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
               THEN 'NARUSZENIE - koniec dyżuru < 11h do następnej zmiany'      -- FIX 2
           WHEN godz_od IS NOT NULL
                AND (godz_od - TRUNC(godz_od)) >= (czas_do - TRUNC(czas_do))
                AND godziny_odpoczynku_calc < 11
               THEN 'NARUSZENIE - koniec nadgodzin < 11h do następnej zmiany'   -- FIX 3
           WHEN ( godz_od IS NULL
               OR (godz_od - TRUNC(godz_od)) < (czas_do - TRUNC(czas_do)) )
                AND godziny_odpoczynku_calc < 11
               THEN 'NARUSZENIE - koniec zmiany < 11h do następnej zmiany'
           ELSE 'OK'
       END AS czy_zach_odpoczynek_dobowy
FROM wyliczenia
ORDER BY nazwisko, imie, dzien_mies;


-- =====================================================================
-- Wersja 7 (pracownicy v2) - parametr pracownicy (prac_id) + odpoczynek
--                            dobowy liczony jako MINIMUM wszystkich luk
--
-- ROZNICE vs Wersja 6:
--   1. CTE 'pracownicy' - lista prac_id sterujaca calym zapytaniem
--      (tu: po nr_ew + zakres zatrudnienia); filtr wchodzi najwczesniej
--      (kalendarz_src, zdarzenia_aggr) -> mniej danych do okien/agregatow.
--   2. Odpoczynek dobowy = LEAST z luk liczonych osobno w CTE 'luki':
--        - odp_przed_dyzurem   : koniec_pracy   -> poczatek_dyzuru
--        - odp_po_dyzurze      : koniec_dyzuru  -> poczatek nast. zmiany
--        - odp_przed_zleceniem : koniec_pracy   -> poczatek_zlecenia
--        - odp_po_zleceniu     : koniec_zlecenia-> poczatek nast. zmiany
--        - odp_praca_do_zmiany : koniec_pracy   -> poczatek nast. zmiany
--      Luki "po ..." licza sie tylko gdy istnieje realna nast. zmiana
--      (next_typ_dnia IS NULL). Status wskazuje wiazaca (najkrotsza) luke.
--   3. FIX: dzien nastepny wolny + dyzur/zlecenie w tym dniu -> odpoczynek
--      NIE jest juz na sztywno 16, tylko realna luka do poczatku dyzuru.
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
FROM   (

WITH parametry AS (
    SELECT  TO_DATE('10-06-2026', 'DD-MM-YYYY') AS data_od,
            TO_DATE('13-06-2026', 'DD-MM-YYYY') AS data_do
    FROM dual
),
pracownicy AS (
    SELECT /*+ MATERIALIZE */ prac.prac_id AS prac_id
    FROM t_prac prac
    CROSS JOIN parametry p
    WHERE prac.DATA_ZATR <= p.data_od
      AND (prac.DATA_ROZW IS NULL OR prac.DATA_ROZW >= p.data_do)
      AND prac.nr_ew = '45041478'
),
kalendarz_src AS (
    SELECT /*+ MATERIALIZE */
           k.prac_id, k.id, k.dzien_mies, k.czas_od, k.czas_do, k.typ_dnia
    FROM NT_KP_KDR_KALENDARZE_PRAC k
    CROSS JOIN parametry p
    WHERE k.dzien_mies >= p.data_od
      AND k.dzien_mies <  p.data_do + 2
      AND k.prac_id IN (SELECT prac_id FROM pracownicy)
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
    WHERE k.typ_dnia IS NULL
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
      AND zd.prac_id IN (SELECT prac_id FROM pracownicy)
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
           TRUNC(k.dzien_mies)      + (z.godz_od     - TRUNC(z.godz_od))     AS poczatek_zlecenia_dt,
           TRUNC(k.dzien_mies)      + (z.godz_do     - TRUNC(z.godz_do))     AS koniec_zlecenia_dt
    FROM kalendarz_raport k
    JOIN t_prac p
      ON p.prac_id = k.prac_id
    --  JOIN t_prac_rob rob
    --   ON p.prac_id = rob.prac_id and rob.sessionid = ^$SESSIONID^
    LEFT JOIN zlecenia_aggr z
      ON z.prac_id = k.prac_id
     AND z.kali_id = k.id
    LEFT JOIN zdarzenia_aggr zd
      ON zd.prac_id = k.prac_id
     AND zd.workday_date = k.dzien_mies
),
luki AS (
    SELECT d.*,
           -- odpoczynek PRZED dyżurem: koniec_pracy -> poczatek_dyzuru
           CASE WHEN d.date_time_from IS NOT NULL
                     AND d.date_time_from >= d.koniec_pracy_dt
                THEN ROUND((d.date_time_from - d.koniec_pracy_dt) * 24, 2)
           END AS odp_przed_dyzurem,
           -- odpoczynek PO dyżurze: koniec_dyzuru -> poczatek nast. zmiany (tylko gdy jest realna nast. zmiana)
           CASE WHEN d.next_typ_dnia IS NULL
                     AND d.next_czas_od IS NOT NULL
                     AND d.date_time_to IS NOT NULL
                     AND d.poczatek_nast_pracy_dt >= d.date_time_to
                THEN ROUND((d.poczatek_nast_pracy_dt - d.date_time_to) * 24, 2)
           END AS odp_po_dyzurze,
           -- odpoczynek PRZED zleceniem: koniec_pracy -> poczatek_zlecenia
           CASE WHEN d.poczatek_zlecenia_dt IS NOT NULL
                     AND d.poczatek_zlecenia_dt >= d.koniec_pracy_dt
                THEN ROUND((d.poczatek_zlecenia_dt - d.koniec_pracy_dt) * 24, 2)
           END AS odp_przed_zleceniem,
           -- odpoczynek PO zleceniu: koniec_zlecenia -> poczatek nast. zmiany (tylko gdy jest realna nast. zmiana)
           CASE WHEN d.next_typ_dnia IS NULL
                     AND d.next_czas_od IS NOT NULL
                     AND d.koniec_zlecenia_dt IS NOT NULL
                     AND d.poczatek_nast_pracy_dt >= d.koniec_zlecenia_dt
                THEN ROUND((d.poczatek_nast_pracy_dt - d.koniec_zlecenia_dt) * 24, 2)
           END AS odp_po_zleceniu,
           -- odpoczynek bazowy: koniec_pracy -> poczatek nast. zmiany (tylko gdy jest realna nast. zmiana)
           CASE WHEN d.next_typ_dnia IS NULL
                     AND d.next_czas_od IS NOT NULL
                THEN ROUND((d.poczatek_nast_pracy_dt - d.koniec_pracy_dt) * 24, 2)
           END AS odp_praca_do_zmiany
    FROM dane d
),
wyliczenia AS (
    SELECT l.*,
           CASE
               -- brak następnej zmiany i brak dyżuru/zlecenia -> nie ma czego mierzyć
               WHEN l.next_typ_dnia IS NULL
                    AND l.next_czas_od IS NULL
                    AND l.date_time_from IS NULL
                    AND l.poczatek_zlecenia_dt IS NULL
                   THEN NULL
               -- dzień następny wolny i brak dyżuru/zlecenia -> pełny odpoczynek
               WHEN l.next_typ_dnia IS NOT NULL
                    AND l.odp_przed_dyzurem IS NULL
                    AND l.odp_przed_zleceniem IS NULL
                   THEN 16
               -- w pozostałych przypadkach: najmniejsza (najbardziej restrykcyjna) luka
               ELSE LEAST(
                        NVL(l.odp_praca_do_zmiany, 9999),
                        NVL(l.odp_przed_dyzurem,   9999),
                        NVL(l.odp_po_dyzurze,      9999),
                        NVL(l.odp_przed_zleceniem, 9999),
                        NVL(l.odp_po_zleceniu,     9999)
                    )
           END AS godziny_odpoczynku_calc
    FROM luki l
)
SELECT ROW_NUMBER() OVER (ORDER BY nazwisko, imie, dzien_mies) AS lp,
       imie,
       nazwisko,
       numer_ewidencyjny,
       nr_karty,
       TO_CHAR(dzien_mies, 'DD-MM-YYYY') AS dzien_miesiaca,
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
       TO_CHAR(next_dzien_mies, 'DD-MM-YYYY') AS nastepny_dzien,
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
               THEN 'BRAK NASTĘPNEJ ZMIANY'
           WHEN godziny_odpoczynku_calc >= 11
               THEN CASE WHEN next_typ_dnia IS NOT NULL
                             AND odp_przed_dyzurem IS NULL
                             AND odp_przed_zleceniem IS NULL
                            THEN 'OK - następny dzień wolny'
                         ELSE 'OK'
                    END
           -- naruszenie: wskazujemy wiążącą (najkrótszą) lukę
           WHEN godziny_odpoczynku_calc = odp_przed_dyzurem
               THEN 'NARUSZENIE - koniec pracy < 11h do początku dyżuru'
           WHEN godziny_odpoczynku_calc = odp_po_dyzurze
               THEN 'NARUSZENIE - koniec dyżuru < 11h do następnej zmiany'
           WHEN godziny_odpoczynku_calc = odp_przed_zleceniem
               THEN 'NARUSZENIE - koniec pracy < 11h do początku zlecenia'
           WHEN godziny_odpoczynku_calc = odp_po_zleceniu
               THEN 'NARUSZENIE - koniec zlecenia < 11h do następnej zmiany'
           ELSE 'NARUSZENIE - koniec pracy < 11h do następnej zmiany'
       END AS czy_zach_odpoczynek_dobowy
FROM wyliczenia
ORDER BY nazwisko, imie, dzien_mies);

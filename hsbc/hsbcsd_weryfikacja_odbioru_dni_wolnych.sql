-- Weryfikacja odbioru dni wolnych
-- Zapytanie 1: Sprawdzenie ostatniego dnia okresu rozliczeniowego dla pracownika

WITH okres AS (
    SELECT
        p.prac_id,
        k.dzien_mies,
        CASE
            WHEN b.dlugosc = 1 THEN LAST_DAY(k.dzien_mies)
            WHEN b.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(k.dzien_mies, 'Q'), 2))
        END AS koniec_okresu
    FROM t_prac p
    JOIN NT_KP_KDR_KALENDARZE_PRAC k
        ON  k.prac_id    = p.prac_id
        AND k.dzien_mies BETWEEN DATE '2026-01-01' AND DATE '2026-05-31'
    JOIN KP_RCP_WORKING_TIME_SYSTEMS scz
        ON  scz.code = akt_dane.work_time_system(p.prac_id, DATE '2026-06-30')
    JOIN KP_RCP_OKRESY_BILANSU b
        ON  b.id = scz.rcok_id
    WHERE p.prac_id = 77076
)
SELECT
    o.dzien_mies, o.koniec_okresu AS wynik,
    CASE
        WHEN o.dzien_mies = o.koniec_okresu
            THEN CASE k_koniec.typ_dnia
                WHEN 'N'  THEN 'Niedziela'
                WHEN 'S'  THEN 'Święto'
                WHEN 'WN' THEN 'Wolne za niedzielę'
                WHEN 'WS' THEN 'Wolne za święto'
                WHEN 'SO' THEN 'Wolne za niedzielę i święto'
                WHEN 'C'  THEN 'Wolne harmonogramowo'
                WHEN 'W'  THEN 'Dzień wolny'
                WHEN 'R'  THEN 'Dzień roboczy'
            END
        WHEN o.dzien_mies = o.koniec_okresu - 1
             AND k_koniec.typ_dnia IS NOT NULL
            THEN 'Ostatni dzień roboczy'
    END AS komunikat
FROM okres o
LEFT JOIN NT_KP_KDR_KALENDARZE_PRAC k_koniec
    ON  k_koniec.prac_id    = o.prac_id
    AND k_koniec.dzien_mies = o.koniec_okresu;


-- Zapytanie 2: Weryfikacja odbioru dni wolnych — zoptymalizowane dla całej bazy (SELECT DISTINCT)

WITH
/*  1. Tylko rekordy z nadgodzinami */
kalendarze AS (
    SELECT /*+ MATERIALIZE */
           k.id, k.prac_id, k.dzien_mies
    FROM   NT_KP_KDR_KALENDARZE_PRAC k
    WHERE  k.TYP_DNIA   = 'W'
      AND  k.DZIEN_MIES BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'
      AND  EXISTS (
               SELECT 1
               FROM   KP_RCP_ZLEC_NADG_PRAC z
               WHERE  z.kali_id = k.id
                 AND  z.prac_id = k.prac_id
           )
),
/*  2. Dane HR — raz na pracownika */
prac_hr AS (
    SELECT /*+ MATERIALIZE */
           p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY,
           LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30') AS data_ref,
           akt_dane.j_org(p.prac_id,
               LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')) AS jednostka_org,
           akt_dane.mpk(p.prac_id,
               LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')) AS mpk,
           akt_dane.stanowisko(p.prac_id,
               LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')) AS stanowisko
    FROM   t_prac p
    WHERE  p.prac_id IN (SELECT prac_id FROM kalendarze)
),
/*  3. System czasu pracy — raz na pracownika */
system_pracy AS (
    SELECT /*+ MATERIALIZE */
           ph.prac_id, b.dlugosc
    FROM   prac_hr ph
    JOIN   KP_RCP_WORKING_TIME_SYSTEMS scz
        ON  scz.code = akt_dane.work_time_system(ph.prac_id, DATE '2026-06-30')
    JOIN   KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
),
/*  4. Koniec okresu */
okres AS (
    SELECT /*+ MATERIALIZE */
           k.id AS kali_id, k.prac_id, k.dzien_mies,
           CASE
               WHEN sp.dlugosc = 1 THEN LAST_DAY(k.dzien_mies)
               WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(k.dzien_mies, 'Q'), 2))
           END AS koniec_okresu
    FROM   kalendarze k
    JOIN   system_pracy sp ON sp.prac_id = k.prac_id
),
/*  5. Komunikat */
komunikat_cte AS (
    SELECT /*+ MATERIALIZE */
           o.kali_id,
           CASE
               WHEN o.dzien_mies = o.koniec_okresu
                   THEN CASE k_koniec.typ_dnia
                       WHEN 'N'  THEN 'Niedziela'
                       WHEN 'S'  THEN 'Święto'
                       WHEN 'WN' THEN 'Wolne za niedzielę'
                       WHEN 'WS' THEN 'Wolne za święto'
                       WHEN 'SO' THEN 'Wolne za niedzielę i święto'
                       WHEN 'C'  THEN 'Wolne harmonogramowo'
                       WHEN 'W'  THEN 'Dzień wolny'
                       WHEN 'R'  THEN 'Dzień roboczy'
                   END
               WHEN o.dzien_mies = o.koniec_okresu - 1
                    AND k_koniec.typ_dnia IS NOT NULL
                   THEN 'Ostatni dzień roboczy'
           END AS komunikat
    FROM   okres o
    LEFT JOIN NT_KP_KDR_KALENDARZE_PRAC k_koniec
        ON  k_koniec.prac_id    = o.prac_id
        AND k_koniec.dzien_mies = o.koniec_okresu
)
SELECT imie, nazwisko, nr_ew, NR_KARTY,
       "jednostka organizacyjna", mpk, stanowisko, status,
       "data zlecenia", "doba pracownicza", "czas zlecenia",
       "godziny 50", "godziny 100", "zapłata 50", "zapłata 100",
       "godziny odebrane", "sposób rozliczenia", komunikat
FROM (
    SELECT DISTINCT
        p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY,
        p.jednostka_org                                    AS "jednostka organizacyjna",
        p.mpk,
        p.stanowisko,
        CASE WHEN z.settled = 'N' THEN 'Nie rozliczone' ELSE 'Rozliczone' END AS status,
        TO_CHAR(z.data,       'dd-mm-yyyy')                AS "data zlecenia",
        TO_CHAR(k.dzien_mies, 'dd-mm-yyyy')                AS "doba pracownicza",
        z.czas                                             AS "czas zlecenia",
        NVL(ROUND(z.CLASSIFIED_SECONDS_01 / 3600, 2), 0)  AS "godziny 50",
        NVL(ROUND(z.CLASSIFIED_SECONDS_02 / 3600, 2), 0)  AS "godziny 100",
        NVL(op.g50,  0)                                    AS "zapłata 50",
        NVL(op.g100, 0)                                    AS "zapłata 100",
        NVL(odb.czas, 0)                                   AS "godziny odebrane",
        CASE WHEN odb.odbior_dnia_wolnego IS NULL AND z.settled = 'T'
             THEN 'Zapłata pieniężna'
             ELSE odb.odbior_dnia_wolnego
        END                                                AS "sposób rozliczenia",
        kom.komunikat,
        p.nazwisko   AS sort_nazwisko,
        p.imie       AS sort_imie,
        k.dzien_mies AS sort_dzien
    FROM   kalendarze k
    JOIN   prac_hr p
        ON  p.prac_id = k.prac_id
    JOIN   KP_RCP_ZLEC_NADG_PRAC z
        ON  z.kali_id = k.id
        AND z.prac_id = k.prac_id
    --  AND z.data    = DATE '2026-03-14'
    LEFT JOIN (
        SELECT RCZP_ID                                     AS pow,
               ROUND(SUM(CLASSIFIED_SECONDS_01) / 3600, 2) AS g50,
               ROUND(SUM(CLASSIFIED_SECONDS_02) / 3600, 2) AS g100
        FROM   KP_RCP_OVERTIME_PAYMENT
        GROUP BY RCZP_ID
    ) op  ON op.pow = z.ID
    LEFT JOIN (
        SELECT o.RCZP_ID                                                  AS pow,
               CASE WHEN MAX(o.ALL_DAY) = 'T'
                    THEN SUM(a.liczba_godzin)
                    ELSE ROUND(SUM(o.SECONDS_COUNT) / 3600, 2)
               END                                                        AS czas,
               CASE WHEN MAX(o.ALL_DAY) = 'T' THEN 'Odbior dnia wolnego' END AS odbior_dnia_wolnego
        FROM   KP_RCP_LABS_RCZP o
        LEFT JOIN l_absencje a ON a.id = o.LABS_ID
        GROUP BY o.RCZP_ID
    ) odb ON odb.pow = z.ID
    LEFT JOIN komunikat_cte kom ON kom.kali_id = k.id
    -- WHERE p.nr_ew = '45148971'
)
ORDER BY sort_nazwisko, sort_imie, sort_dzien;


-- Zapytanie 3: Po zmianach klienta — tylko zapłata pieniężna, okres rozliczeniowy,
--              daty początku/końca okresu, absencje w okresie (XMLAGG), filtr komunikatu

WITH
  /*  1. Tylko rekordy z nadgodzinami */
  kalendarze AS (
      SELECT /*+ MATERIALIZE */
             k.id, k.prac_id, k.dzien_mies
      FROM   NT_KP_KDR_KALENDARZE_PRAC k
      WHERE  k.TYP_DNIA   = 'W'
        AND  k.DZIEN_MIES BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'
        AND  EXISTS (
                 SELECT 1
                 FROM   KP_RCP_ZLEC_NADG_PRAC z
                 WHERE  z.kali_id = k.id
                   AND  z.prac_id = k.prac_id
             )
  ),
  /*  2. Dane HR — raz na pracownika */
  prac_hr AS (
      SELECT /*+ MATERIALIZE */
             p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY,
             LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30') AS data_ref,
             akt_dane.j_org(p.prac_id,
                 LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')) AS jednostka_org,
             akt_dane.mpk(p.prac_id,
                 LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')) AS mpk,
             akt_dane.stanowisko(p.prac_id,
                 LEAST(NVL(p.data_rozw, DATE '2026-06-30'), DATE '2026-06-30')) AS stanowisko
      FROM   t_prac p
      WHERE  p.prac_id IN (SELECT prac_id FROM kalendarze)
  ),
  /*  3. System czasu pracy — raz na pracownika */
  system_pracy AS (
      SELECT /*+ MATERIALIZE */
             ph.prac_id, b.dlugosc
      FROM   prac_hr ph
      JOIN   KP_RCP_WORKING_TIME_SYSTEMS scz
          ON  scz.code = akt_dane.work_time_system(ph.prac_id, DATE '2026-06-30')
      JOIN   KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
  ),
  /*  4. Koniec okresu */
  okres AS (
      SELECT /*+ MATERIALIZE */
             k.id AS kali_id, k.prac_id, k.dzien_mies,
             sp.dlugosc,
             CASE
                 WHEN sp.dlugosc = 1 THEN TRUNC(k.dzien_mies, 'MM')
                 WHEN sp.dlugosc = 3 THEN TRUNC(k.dzien_mies, 'Q')
             END AS poczatek_okresu,
             CASE
                 WHEN sp.dlugosc = 1 THEN LAST_DAY(k.dzien_mies)
                 WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(k.dzien_mies, 'Q'), 2))
             END AS koniec_okresu
      FROM   kalendarze k
      JOIN   system_pracy sp ON sp.prac_id = k.prac_id
  ),
  /*  5. Komunikat — NULL gdy OK, NOT NULL gdy ostatni/przedostatni dzień okresu jest DW */
  komunikat_cte AS (
      SELECT /*+ MATERIALIZE */
             o.kali_id,
             o.dlugosc,
             o.poczatek_okresu,
             o.koniec_okresu,
             CASE
                 WHEN o.dzien_mies = o.koniec_okresu
                     THEN CASE k_koniec.typ_dnia
                         WHEN 'N'  THEN 'Niedziela'
                         WHEN 'S'  THEN 'Święto'
                         WHEN 'WN' THEN 'Wolne za niedzielę'
                         WHEN 'WS' THEN 'Wolne za święto'
                         WHEN 'SO' THEN 'Wolne za niedzielę i święto'
                         WHEN 'C'  THEN 'Wolne harmonogramowo'
                         WHEN 'W'  THEN 'Dzień wolny'
                         WHEN 'R'  THEN 'Dzień roboczy'
                     END
                 WHEN o.dzien_mies = o.koniec_okresu - 1
                      AND k_koniec.typ_dnia IS NOT NULL
                     THEN 'Ostatni dzień roboczy'
             END AS komunikat
      FROM   okres o
      LEFT JOIN NT_KP_KDR_KALENDARZE_PRAC k_koniec
          ON  k_koniec.prac_id    = o.prac_id
          AND k_koniec.dzien_mies = o.koniec_okresu
  ),
  /*  6. Absencje w okresie rozliczeniowym (XMLAGG — brak limitu 4000 znaków) */
  absencje_cte AS (
      SELECT /*+ MATERIALIZE */
             o.kali_id,
             RTRIM(
                 XMLAGG(
                     XMLELEMENT(e,
                         s.tytul || ' ' || TO_CHAR(a.data_od, 'DD-MM-YYYY')
                                  || ' - '  || TO_CHAR(a.data_do, 'DD-MM-YYYY') || '; '
                     ) ORDER BY a.data_od
                 ).EXTRACT('//text()').getClobVal(),
                 '; '
             ) AS absencje_w_okresie
      FROM   okres o
      JOIN   l_absencje a ON a.prac_id = o.prac_id
                          AND a.data_od BETWEEN o.poczatek_okresu AND o.koniec_okresu
      JOIN   SL_NIEOB s   ON s.id = a.NIEOB_ID
      GROUP BY o.kali_id
  )
SELECT q.imie, q.nazwisko, q.nr_ew, q.NR_KARTY,
       q."jednostka organizacyjna", q.mpk, q.stanowisko,
       q."okres rozliczeniowy",
       q."początek okresu rozliczeniowego",
       q."koniec okresu rozliczeniowego",
       q.status,
       q."data zlecenia", q."doba pracownicza", q."czas zlecenia",
       q."zapłata 100",
       q."godziny odebrane", q."sposób rozliczenia",
       abs.absencje_w_okresie                             AS "absencje w okresie rozliczeniowym",
       q.komunikat
FROM (
    SELECT DISTINCT
        p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY,
        p.jednostka_org                                    AS "jednostka organizacyjna",
        p.mpk,
        p.stanowisko,
        CASE kom.dlugosc
            WHEN 1 THEN '1 - miesięczny okres rozliczeniowy'
            WHEN 3 THEN '3 - miesięczny okres rozliczeniowy'
        END                                                AS "okres rozliczeniowy",
        TO_CHAR(kom.poczatek_okresu, 'DD-MM-YYYY')         AS "początek okresu rozliczeniowego",
        TO_CHAR(kom.koniec_okresu,   'DD-MM-YYYY')         AS "koniec okresu rozliczeniowego",
        CASE WHEN z.settled = 'N' THEN 'Nie rozliczone' ELSE 'Rozliczone' END AS status,
        TO_CHAR(z.data,       'dd-mm-yyyy')                AS "data zlecenia",
        TO_CHAR(k.dzien_mies, 'dd-mm-yyyy')                AS "doba pracownicza",
        z.czas                                             AS "czas zlecenia",
        NVL(op.g100, 0)                                    AS "zapłata 100",
        NVL(odb.czas, 0)                                   AS "godziny odebrane",
        CASE WHEN odb.odbior_dnia_wolnego IS NULL AND z.settled = 'T'
             THEN 'Zapłata pieniężna'
             ELSE odb.odbior_dnia_wolnego
        END                                                AS "sposób rozliczenia",
        kom.komunikat,
        k.id                                               AS sort_kali_id,
        p.nazwisko                                         AS sort_nazwisko,
        p.imie                                             AS sort_imie,
        k.dzien_mies                                       AS sort_dzien
    FROM   kalendarze k
    JOIN   prac_hr p
        ON  p.prac_id = k.prac_id
    JOIN   KP_RCP_ZLEC_NADG_PRAC z
        ON  z.kali_id = k.id
        AND z.prac_id = k.prac_id
        AND Z.SETTLED = 'T'
    LEFT JOIN (
        SELECT RCZP_ID                                      AS pow,
               ROUND(SUM(CLASSIFIED_SECONDS_01) / 3600, 2)  AS g50,
               ROUND(SUM(CLASSIFIED_SECONDS_02) / 3600, 2)  AS g100
        FROM   KP_RCP_OVERTIME_PAYMENT
        GROUP BY RCZP_ID
    ) op  ON op.pow = z.ID
    LEFT JOIN (
        SELECT o.RCZP_ID                                                   AS pow,
               CASE WHEN MAX(o.ALL_DAY) = 'T'
                    THEN SUM(a.liczba_godzin)
                    ELSE ROUND(SUM(o.SECONDS_COUNT) / 3600, 2)
               END                                                         AS czas,
               CASE WHEN MAX(o.ALL_DAY) = 'T' THEN 'Odbior dnia wolnego' END AS odbior_dnia_wolnego
        FROM   KP_RCP_LABS_RCZP o
        LEFT JOIN l_absencje a ON a.id = o.LABS_ID
        GROUP BY o.RCZP_ID
    ) odb ON odb.pow = z.ID
    LEFT JOIN komunikat_cte kom ON kom.kali_id = k.id
--  WHERE p.nr_ew = '45148971'
) q
LEFT JOIN absencje_cte abs ON abs.kali_id = q.sort_kali_id
WHERE q."sposób rozliczenia" = 'Zapłata pieniężna'
  AND q.komunikat IS NULL
ORDER BY q.sort_nazwisko, q.sort_imie, q.sort_dzien;

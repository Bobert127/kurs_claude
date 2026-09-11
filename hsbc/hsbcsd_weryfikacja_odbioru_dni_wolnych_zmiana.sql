WITH
  /*  1. Tylko rekordy z nadgodzinami */
  kalendarze AS (
      SELECT
             k.id, k.prac_id, k.dzien_mies
      FROM   NT_KP_KDR_KALENDARZE_PRAC k
      WHERE  k.TYP_DNIA   = 'W'
        AND  k.DZIEN_MIES BETWEEN DATE '2026-07-01' AND DATE '2026-07-31'
        AND  EXISTS (
                 SELECT 1
                 FROM   KP_RCP_ZLEC_NADG_PRAC z
                 WHERE  z.kali_id = k.id
                   AND  z.prac_id = k.prac_id
             )
  ),
  /*  1a. Zlecenia - poziom pojedynczego zlecenia + data zlecenia */
  zlecenia AS (
      SELECT
             k.id       AS kali_id,
             k.prac_id,
             k.dzien_mies,
             z.id       AS zlec_id,
             z.data     AS data_zlecenia
      FROM   kalendarze k
      JOIN   KP_RCP_ZLEC_NADG_PRAC z
          ON  z.kali_id = k.id
          AND z.prac_id = k.prac_id
  ),
  /*  2. Dane HR - raz na pracownika */
  prac_hr AS (
      SELECT
             p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY,
             LEAST(NVL(p.data_rozw, DATE '2026-07-31'), DATE '2026-07-31') AS data_ref,
             akt_dane.j_org(p.prac_id,
                 LEAST(NVL(p.data_rozw, DATE '2026-07-31'), DATE '2026-07-31')) AS jednostka_org,
             akt_dane.mpk(p.prac_id,
                 LEAST(NVL(p.data_rozw, DATE '2026-07-31'), DATE '2026-07-31')) AS mpk,
             akt_dane.stanowisko(p.prac_id,
                 LEAST(NVL(p.data_rozw, DATE '2026-07-31'), DATE '2026-07-31')) AS stanowisko
      FROM   t_prac p
      WHERE  p.prac_id IN (SELECT prac_id FROM kalendarze)
  ),
  /*  3. System czasu pracy - aktualny NA DZIEN ZLECENIA (per zlecenie) */
  system_pracy AS (
      SELECT
             zl.zlec_id, b.dlugosc
      FROM   zlecenia zl
      JOIN   KP_RCP_WORKING_TIME_SYSTEMS scz
          ON  scz.code = akt_dane.work_time_system(zl.prac_id, zl.data_zlecenia)
      JOIN   KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
  ),
  /*  4. Koniec okresu - per zlecenie */
  okres AS (
      SELECT
             zl.zlec_id, zl.kali_id, zl.prac_id, zl.dzien_mies,
             sp.dlugosc,
             CASE
                 WHEN sp.dlugosc = 1 THEN TRUNC(zl.dzien_mies, 'MM')
                 WHEN sp.dlugosc = 3 THEN TRUNC(zl.dzien_mies, 'Q')
             END AS poczatek_okresu,
             CASE
                 WHEN sp.dlugosc = 1 THEN LAST_DAY(zl.dzien_mies)
                 WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(zl.dzien_mies, 'Q'), 2))
             END AS koniec_okresu
      FROM   zlecenia zl
      JOIN   system_pracy sp ON sp.zlec_id = zl.zlec_id
  ),
  /*  5. Komunikat - per zlecenie */
  komunikat_cte AS (
      SELECT
             o.zlec_id,
             o.dlugosc,
             o.poczatek_okresu,
             o.koniec_okresu,
             CASE
                 WHEN o.dzien_mies = o.koniec_okresu
                     THEN CASE k_koniec.typ_dnia
                         WHEN 'N'  THEN 'Niedziela'
                         WHEN 'S'  THEN 'Swieto'
                         WHEN 'WN' THEN 'Wolne za niedziele'
                         WHEN 'WS' THEN 'Wolne za swieto'
                         WHEN 'SO' THEN 'Wolne za niedziele i swieto'
                         WHEN 'C'  THEN 'Wolne harmonogramowo'
                         WHEN 'W'  THEN 'Dzien wolny'
                         WHEN 'R'  THEN 'Dzien roboczy'
                     END
                 WHEN o.dzien_mies = o.koniec_okresu - 1
                      AND k_koniec.typ_dnia IS NOT NULL
                     THEN 'Ostatni dzien roboczy'
             END AS komunikat
      FROM   okres o
      LEFT JOIN NT_KP_KDR_KALENDARZE_PRAC k_koniec
          ON  k_koniec.prac_id    = o.prac_id
          AND k_koniec.dzien_mies = o.koniec_okresu
  ),
  /*  6. Absencje w okresie rozliczeniowym (XMLAGG - brak limitu 4000 znakow),
        powiazane ze zleceniem oraz poczatkiem i koncem okresu rozliczeniowego */
  absencje_cte AS (
      SELECT
             o.zlec_id,
             o.prac_id,
             o.poczatek_okresu,
             o.koniec_okresu,
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
      JOIN   l_absencje a ON a.prac_id  = o.prac_id
                          AND a.data_od BETWEEN o.poczatek_okresu AND o.koniec_okresu
      JOIN   SL_NIEOB s   ON s.id = a.NIEOB_ID
      GROUP BY o.zlec_id, o.prac_id, o.poczatek_okresu, o.koniec_okresu
  )
SELECT ROW_NUMBER() OVER (ORDER BY NLSSORT(q.nazwisko, 'NLS_SORT=POLISH'), NLSSORT(q.imie, 'NLS_SORT=POLISH')) AS lp,
       q.imie, q.nazwisko, q.nr_ew, q.NR_KARTY,
       q."jednostka organizacyjna", q.mpk, q.stanowisko,
       q."okres rozliczeniowy",
       q."poczatek okresu rozlicz.",
       q."koniec okresu rozlicz.",
       q.status,
       q."data zlecenia", q."doba pracownicza", q."czas zlecenia",
       q."zaplata 100",
       q."godziny odebrane", q."sposob rozliczenia",
       abs.absencje_w_okresie                             AS "absencje w okresie rozlicz.",
       q.komunikat
FROM (
    SELECT DISTINCT
        p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY,
        p.jednostka_org                                    AS "jednostka organizacyjna",
        p.mpk,
        p.stanowisko,
        CASE kom.dlugosc
            WHEN 1 THEN '1 - miesieczny okres rozliczeniowy'
            WHEN 3 THEN '3 - miesieczny okres rozliczeniowy'
        END                                                AS "okres rozliczeniowy",
        TO_CHAR(kom.poczatek_okresu, 'DD-MM-YYYY')         AS "poczatek okresu rozlicz.",
        TO_CHAR(kom.koniec_okresu,   'DD-MM-YYYY')         AS "koniec okresu rozlicz.",
        CASE WHEN z.settled = 'N' THEN 'Nie rozliczone' ELSE 'Rozliczone' END AS status,
        TO_CHAR(z.data,       'dd-mm-yyyy')                AS "data zlecenia",
        TO_CHAR(k.dzien_mies, 'dd-mm-yyyy')                AS "doba pracownicza",
        z.czas                                             AS "czas zlecenia",
        NVL(op.g100, 0)                                    AS "zaplata 100",
        NVL(odb.czas, 0)                                   AS "godziny odebrane",
        CASE WHEN odb.odbior_dnia_wolnego IS NULL AND z.settled = 'T'
             THEN 'Zaplata pieniezna'
             ELSE odb.odbior_dnia_wolnego
        END                                                AS "sposob rozliczenia",
        kom.komunikat,
        p.prac_id                                          AS prac_id,
        kom.poczatek_okresu                                AS okres_od,
        kom.koniec_okresu                                  AS okres_do,
        z.id                                               AS zlec_id,
        p.nazwisko                                         AS sort_nazwisko,
        p.imie                                             AS sort_imie,
        k.dzien_mies                                       AS sort_dzien
    FROM   kalendarze k
    JOIN   prac_hr p
        ON  p.prac_id = k.prac_id
    JOIN   KP_RCP_ZLEC_NADG_PRAC z
        ON  z.kali_id = k.id
        AND z.prac_id = k.prac_id
        -- AND Z.SETTLED = 'T'
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
    LEFT JOIN komunikat_cte kom ON kom.zlec_id = z.id
--  WHERE p.nr_ew = '45148971'
) q
LEFT JOIN absencje_cte abs
    ON  abs.zlec_id         = q.zlec_id
    AND abs.prac_id         = q.prac_id
    AND abs.poczatek_okresu = q.okres_od
    AND abs.koniec_okresu   = q.okres_do
WHERE  q."sposob rozliczenia" = 'Zaplata pieniezna'
  AND q.komunikat IS NULL
  AND q.nr_ew = '45159350'
ORDER BY q.sort_nazwisko, q.sort_imie, q.sort_dzien;

SELECT
    lp,
    imie,
    nazwisko,
    nr_ew,
    nr_karty,
    "jednostka organizacyjna",
    mpk,
    stanowisko,
    "okres rozliczeniowy",
    "początek okresu rozlicz.",
    "koniec okresu rozlicz.",
    status,
    "data zlecenia",
    "doba pracownicza",
    "czas zlecenia",
    "zapłata 100",
    "godziny odebrane",
    "sposób rozliczenia",
    "absencje w okresie rozlicz.",
    komunikat
FROM
    (
        WITH /* 1. Tylko rekordy z nadgodzinami */ kalendarze AS (
            SELECT
                k.id,
                k.prac_id,
                k.dzien_mies
            FROM
                nt_kp_kdr_kalendarze_prac k
            WHERE
                    k.typ_dnia = 'W'
                AND k.dzien_mies BETWEEN TO_DATE('2026-07-01', 'yyyy-MM-dd') AND TO_DATE('2026-07-31', 'yyyy-MM-dd')
                AND EXISTS (
                    SELECT
                        1
                    FROM
                        kp_rcp_zlec_nadg_prac z
                    WHERE
                            z.kali_id = k.id
                        AND z.prac_id = k.prac_id
                )
        ), /* 1a. Zlecenia - poziom pojedynczego zlecenia + data zlecenia */ zlecenia AS (
            SELECT
                k.id   AS kali_id,
                k.prac_id,
                k.dzien_mies,
                z.id   AS zlec_id,
                z.data AS data_zlecenia
            FROM
                     kalendarze k
                JOIN kp_rcp_zlec_nadg_prac z ON z.kali_id = k.id
                                                AND z.prac_id = k.prac_id
        ), /* 2. Dane HR - raz na pracownika */ prac_hr AS (
            SELECT
                p.prac_id,
                p.imie,
                p.nazwisko,
                p.nr_ew,
                p.nr_karty,
                least(
                    nvl(p.data_rozw, DATE '2026-07-31'),
                    DATE '2026-07-31'
                )  AS data_ref,
                akt_dane.j_org(p.prac_id,
                               least(
                          nvl(p.data_rozw, DATE '2026-07-31'),
                          DATE '2026-07-31'
                      )) AS jednostka_org,
                akt_dane.mpk(p.prac_id,
                             least(
                        nvl(p.data_rozw, DATE '2026-07-31'),
                        DATE '2026-07-31'
                    )) AS mpk,
                akt_dane.stanowisko(p.prac_id,
                                    least(
                               nvl(p.data_rozw, DATE '2026-07-31'),
                               DATE '2026-07-31'
                           )) AS stanowisko
            FROM
                t_prac p
            WHERE
                p.prac_id IN (
                    SELECT
                        prac_id
                    FROM
                        kalendarze
                )
        ), /* 3. System czasu pracy - aktualny NA DZIEN ZLECENIA (per zlecenie) */ system_pracy AS (
            SELECT
                zl.zlec_id,
                b.dlugosc
            FROM
                     zlecenia zl
                JOIN kp_rcp_working_time_systems scz ON scz.code = akt_dane.work_time_system(zl.prac_id, zl.data_zlecenia)
                JOIN kp_rcp_okresy_bilansu       b ON b.id = scz.rcok_id
        ), /* 4. Koniec okresu - per zlecenie */ okres AS (
            SELECT
                zl.zlec_id,
                zl.kali_id,
                zl.prac_id,
                zl.dzien_mies,
                sp.dlugosc,
                CASE
                    WHEN sp.dlugosc = 1 THEN
                        trunc(zl.dzien_mies, 'MM')
                    WHEN sp.dlugosc = 3 THEN
                        trunc(zl.dzien_mies, 'Q')
                END AS poczatek_okresu,
                CASE
                    WHEN sp.dlugosc = 1 THEN
                        last_day(zl.dzien_mies)
                    WHEN sp.dlugosc = 3 THEN
                        last_day(add_months(
                            trunc(zl.dzien_mies, 'Q'),
                            2
                        ))
                END AS koniec_okresu
            FROM
                     zlecenia zl
                JOIN system_pracy sp ON sp.zlec_id = zl.zlec_id
        ), /* 5. Komunikat - per zlecenie */ komunikat_cte AS (
            SELECT
                o.zlec_id,
                o.dlugosc,
                o.poczatek_okresu,
                o.koniec_okresu,
                CASE
                    WHEN o.dzien_mies = o.koniec_okresu THEN
                            CASE k_koniec.typ_dnia
                                WHEN 'N'  THEN
                                    'Niedziela'
                                WHEN 'S'  THEN
                                    'Swieto'
                                WHEN 'WN' THEN
                                    'Wolne za niedziele'
                                WHEN 'WS' THEN
                                    'Wolne za swieto'
                                WHEN 'SO' THEN
                                    'Wolne za niedziele i swieto'
                                WHEN 'C'  THEN
                                    'Wolne harmonogramowo'
                                WHEN 'W'  THEN
                                    'Dzien wolny'
                                WHEN 'R'  THEN
                                    'Dzien roboczy'
                            END
                    WHEN o.dzien_mies = o.koniec_okresu - 1
                         AND k_koniec.typ_dnia IS NOT NULL THEN
                        'Ostatni dzien roboczy'
                END AS komunikat
            FROM
                okres                     o
                LEFT JOIN nt_kp_kdr_kalendarze_prac k_koniec ON k_koniec.prac_id = o.prac_id
                                                                AND k_koniec.dzien_mies = o.koniec_okresu
        ), /* 6. Absencje w okresie rozliczeniowym (XMLAGG - brak limitu 4000 znakow), powiazane ze zleceniem oraz poczatkiem i koncem okresu rozliczeniowego */
        absencje_cte AS (
            SELECT
                o.zlec_id,
                o.prac_id,
                o.poczatek_okresu,
                o.koniec_okresu,
                rtrim(XMLAGG(XMLELEMENT(
                    e,
       s.tytul
       || ' '
       || to_char(a.data_od, 'yyyy-MM-dd')
       || ' - '
       || to_char(a.data_do, 'yyyy-MM-dd')
       || '; '
                )
                    ORDER BY
                        a.data_od
                ).extract('//text()').getclobval(),
                      '; ') AS absencje_w_okresie
            FROM
                     okres o
                JOIN l_absencje a ON a.prac_id = o.prac_id
                                     AND a.data_od BETWEEN o.poczatek_okresu AND o.koniec_okresu
                JOIN sl_nieob   s ON s.id = a.nieob_id
            GROUP BY
                o.zlec_id,
                o.prac_id,
                o.poczatek_okresu,
                o.koniec_okresu
        ), /* 7. Ostatnie zlecenie pracownika w okresie rozliczeniowym */ ostatnie_zlecenie AS (
            SELECT
                o.prac_id,
                o.poczatek_okresu,
                o.koniec_okresu,
                MAX(o.dzien_mies) AS ostatni_dzien_zlecenia
            FROM
                okres o
            GROUP BY
                o.prac_id,
                o.poczatek_okresu,
                o.koniec_okresu
        ), /* 8. WERYFIKACJA DODATKOWA: od ostatniego zlecenia do konca okresu
              istnial w kalendarzu dzien z typem NULL (wolny do odbioru),
              ktory NIE byl pokryty absencja -> pracownik mial mozliwosc odbioru (blad) */ weryfikacja_odbioru AS (
            SELECT DISTINCT
                oz.prac_id,
                oz.poczatek_okresu,
                oz.koniec_okresu
            FROM
                     ostatnie_zlecenie oz
                JOIN nt_kp_kdr_kalendarze_prac kal ON kal.prac_id = oz.prac_id
                                                      AND kal.dzien_mies BETWEEN oz.ostatni_dzien_zlecenia AND oz.koniec_okresu
                                                      AND kal.typ_dnia IS NULL
            WHERE
                NOT EXISTS (
                    SELECT
                        1
                    FROM
                        l_absencje a
                    WHERE
                            a.prac_id = oz.prac_id
                        AND kal.dzien_mies BETWEEN a.data_od AND a.data_do
                )
        )
        SELECT
            ROW_NUMBER()
            OVER(
                ORDER BY
                    nlssort(q.nazwisko, 'NLS_SORT=POLISH'),
                    nlssort(q.imie, 'NLS_SORT=POLISH')
            )                      AS lp,
            q.imie,
            q.nazwisko,
            q.nr_ew,
            q.nr_karty,
            q."jednostka organizacyjna",
            q.mpk,
            q.stanowisko,
            q."okres rozliczeniowy",
            q."początek okresu rozlicz.",
            q."koniec okresu rozlicz.",
            q.status,
            q."data zlecenia",
            q."doba pracownicza",
            q."czas zlecenia",
            q."zapłata 100",
            q."godziny odebrane",
            q."sposób rozliczenia",
            abs.absencje_w_okresie AS "absencje w okresie rozlicz.",
            q.komunikat
        FROM
            (
                SELECT DISTINCT
                    p.imie,
                    p.nazwisko,
                    p.nr_ew,
                    p.nr_karty,
                    p.jednostka_org                            AS "jednostka organizacyjna",
                    p.mpk,
                    p.stanowisko,
                    CASE kom.dlugosc
                        WHEN 1 THEN
                            '1 - miesieczny okres rozliczeniowy'
                        WHEN 3 THEN
                            '3 - miesieczny okres rozliczeniowy'
                    END                                        AS "okres rozliczeniowy",
                    to_char(kom.poczatek_okresu, 'yyyy-MM-dd') AS "początek okresu rozlicz.",
                    to_char(kom.koniec_okresu, 'yyyy-MM-dd')   AS "koniec okresu rozlicz.",
                    CASE
                        WHEN z.settled = 'N' THEN
                            'Nie rozliczone'
                        ELSE
                            'Rozliczone'
                    END                                        AS status,
                    to_char(z.data, 'yyyy-MM-dd')              AS "data zlecenia",
                    to_char(k.dzien_mies, 'yyyy-MM-dd')        AS "doba pracownicza",
                    z.czas                                     AS "czas zlecenia",
                    nvl(op.g100, 0)                            AS "zapłata 100",
                    nvl(odb.czas, 0)                           AS "godziny odebrane",
                    CASE
                        WHEN odb.odbior_dnia_wolnego IS NULL
                             AND z.settled = 'T' THEN
                            'Zaplata pieniezna'
                        ELSE
                            odb.odbior_dnia_wolnego
                    END                                        AS "sposób rozliczenia",
                    kom.komunikat,
                    p.prac_id                                  AS prac_id,
                    kom.poczatek_okresu                        AS okres_od,
                    kom.koniec_okresu                          AS okres_do,
                    z.id                                       AS zlec_id,
                    p.nazwisko                                 AS sort_nazwisko,
                    p.imie                                     AS sort_imie,
                    k.dzien_mies                               AS sort_dzien
                FROM
                         kalendarze k
                    JOIN prac_hr               p ON p.prac_id = k.prac_id
                    JOIN kp_rcp_zlec_nadg_prac z ON z.kali_id = k.id
                                                    AND z.prac_id = k.prac_id
                    LEFT JOIN (
                        SELECT
                            rczp_id  AS pow,
                            round(sum(classified_seconds_01) / 3600,
                                  2) AS g50,
                            round(sum(classified_seconds_02) / 3600,
                                  2) AS g100
                        FROM
                            kp_rcp_overtime_payment
                        GROUP BY
                            rczp_id
                    )                     op ON op.pow = z.id
                    LEFT JOIN (
                        SELECT
                            o.rczp_id AS pow,
                            CASE
                                WHEN MAX(o.all_day) = 'T' THEN
                                    SUM(a.liczba_godzin)
                                ELSE
                                    round(sum(o.seconds_count) / 3600,
                                          2)
                            END       AS czas,
                            CASE
                                WHEN MAX(o.all_day) = 'T' THEN
                                    'Odbior dnia wolnego'
                            END       AS odbior_dnia_wolnego
                        FROM
                            kp_rcp_labs_rczp o
                            LEFT JOIN l_absencje       a ON a.id = o.labs_id
                        GROUP BY
                            o.rczp_id
                    )                     odb ON odb.pow = z.id
                    LEFT JOIN komunikat_cte         kom ON kom.zlec_id = z.id
            )            q
            LEFT JOIN absencje_cte abs ON abs.zlec_id = q.zlec_id
                                          AND abs.prac_id = q.prac_id
                                          AND abs.poczatek_okresu = q.okres_od
                                          AND abs.koniec_okresu = q.okres_do
        WHERE
                q."sposób rozliczenia" = 'Zaplata pieniezna'
            AND q.komunikat IS NULL
            AND EXISTS (
                SELECT
                    1
                FROM
                    weryfikacja_odbioru w
                WHERE
                        w.prac_id = q.prac_id
                    AND w.poczatek_okresu = q.okres_od
                    AND w.koniec_okresu = q.okres_do
            )
        ORDER BY
            q.sort_nazwisko,
            q.sort_imie,
            q.sort_dzien
    )

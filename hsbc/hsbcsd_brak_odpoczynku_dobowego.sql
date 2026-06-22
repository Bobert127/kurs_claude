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

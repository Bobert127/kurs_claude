WITH CzysteNiedziele AS (
    /*+ MATERIALIZE */
    -- KROK 1+2: Niedziele pracujące — scalenie dwóch CTE w jedno przejście.
    -- EXISTS zamiast korelowanego COUNT: zatrzymuje się na pierwszym trafieniu.
    -- CZAS_OD <> TRUNC(CZAS_OD) zastępuje TO_CHAR i jest NULL-safe.
    SELECT p.prac_id,
           p.IMIE, p.NAZWISKO, p.NR_EW, p.NR_KARTY,
           TRUNC(k.DZIEN_MIES) AS DZIEN_MIES
    FROM T_PRAC p
    JOIN NT_KP_KDR_KALENDARZE_PRAC k ON p.PRAC_ID = k.PRAC_ID
    WHERE k.DZIEN_MIES BETWEEN TRUNC(ADD_MONTHS(SYSDATE, -6), 'MM')
                            AND LAST_DAY(ADD_MONTHS(SYSDATE, 2))
      AND TRUNC(k.DZIEN_MIES) - TRUNC(k.DZIEN_MIES, 'IW') = 6
      AND (
               k.CZAS_OD <> TRUNC(k.CZAS_OD)
            OR EXISTS (
                   SELECT 1
                   FROM KP_RCP_ZLEC_NADG_PRAC Z
                   WHERE Z.PRAC_ID = k.PRAC_ID AND Z.KALI_ID = k.ID
               )
         )
),
FunkcjePrac AS (
    /*+ MATERIALIZE */
    -- KROK 2b: J_ORG, MPK, przełożony obliczone raz na pracownika wg ostatniej jego niedzieli.
    SELECT prac_id,
           AKT_DANE.J_ORG(prac_id, MAX(DZIEN_MIES))                                    AS JO,
           AKT_DANE.MPK(prac_id, MAX(DZIEN_MIES))                                       AS MPK,
           AKT_DANE.Direct_Superior(prac_id, MAX(DZIEN_MIES))                           AS PRZELOZONY,
           AKT_DANE.Superior_Identification_Number(prac_id, MAX(DZIEN_MIES), 'T', 1)   AS PRZELOZONY_NR_EW
    FROM CzysteNiedziele
    GROUP BY prac_id
),
WyspyDni AS (
    -- KROK 3: "Wyspy i luki" — kolejne niedziele w serii różnią się o 7 dni.
    SELECT cn.prac_id, cn.IMIE, cn.NAZWISKO, cn.NR_EW, cn.NR_KARTY,
           fp.JO, fp.MPK, fp.PRZELOZONY, fp.PRZELOZONY_NR_EW,
           cn.DZIEN_MIES,
           cn.DZIEN_MIES - ROW_NUMBER() OVER (PARTITION BY cn.NR_EW ORDER BY cn.DZIEN_MIES) * 7 AS id_grupy
    FROM CzysteNiedziele cn
    JOIN FunkcjePrac fp ON fp.prac_id = cn.prac_id
)
-- KROK 4: Zwijamy w jeden wiersz na serię, pokazujemy tylko serie >= 4 niedziel.
SELECT IMIE, NAZWISKO, NR_EW, NR_KARTY, JO, MPK, PRZELOZONY, PRZELOZONY_NR_EW,
       TO_CHAR(MIN(DZIEN_MIES), 'DD-MM-YYYY') || ' - ' || TO_CHAR(MAX(DZIEN_MIES), 'DD-MM-YYYY') AS DZIEN_MIES_ZAKRES,
       COUNT(*) AS ILOSC_NIEDZIEL
FROM WyspyDni
GROUP BY PRAC_ID, JO, MPK, PRZELOZONY, PRZELOZONY_NR_EW, IMIE, NAZWISKO, NR_EW, NR_KARTY, id_grupy
HAVING COUNT(*) >= 4
ORDER BY NAZWISKO, IMIE, MIN(DZIEN_MIES);

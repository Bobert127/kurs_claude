-- =============================================================================
-- HSBC - rozliczenie zmian (I / II zmiana)
--
-- Zalozenie: grupowanie po MIESIACU (nie po dniu).
--   Bilans z rcp_bilans jest agregowany do poziomu pracownik + miesiac,
--   a dopasowanie do zlecenia HR odbywa sie po kluczu 'YYYY-MM'
--   (nr ewidencyjny + miesiac wyciety z pola SUBJECT).
--
-- Poprawki wzgledem wersji wyjsciowej:
--   * data_z trzymana jako DATA (TRUNC do 1. dnia miesiaca), nie string
--     'mm-yyyy' - dzieki temu TO_CHAR, JOIN i filtry dzialaja poprawnie.
--   * Dopasowanie miesieczne: TO_CHAR(bi.data_z,'YYYY-MM') = SUBSTR(subject,1,7).
--   * Ujednolicona skladnia zlaczen ANSI (bez mieszania z przecinkiem).
--   * Literaly dat jako DATE 'YYYY-MM-DD' (bez zaleznosci od NLS_DATE_FORMAT).
--   * Naprawiona literowka w zakresie request_date ('2026-06-310 -> 2026-06-30').
--   * Zakres bilansu (Q1 2026) filtrowany raz, w CTE - LEFT JOIN nie jest
--     unieważniany przez warunki na bi.* w klauzuli WHERE.
--
-- Aby ograniczyc raport tylko do II zmiany: w WHERE zmien
--   "ze.HRRC_ID IN (64, 66)" na "ze.HRRC_ID = 66".
-- =============================================================================
WITH bilans_mies AS (
        -- Bilans zagregowany do poziomu: pracownik + miesiac
        SELECT
               p.nr_ew                       AS pow,
               TRUNC(b.data, 'MM')           AS data_z,        -- 1. dzien miesiaca
               p.imie                        AS imie,
               p.nazwisko                    AS nazwisko,
               p.nr_karty                    AS nr_karty
        FROM   t_prac     p
        JOIN   rcp_bilans b ON b.prac_id = p.prac_id
        WHERE  b.data BETWEEN DATE '2026-01-01' AND DATE '2026-03-31'
        GROUP BY
               p.nr_ew, TRUNC(b.data, 'MM'),
               p.imie, p.nazwisko, p.nr_karty
     )
SELECT
       CASE ze.HRRC_ID
            WHEN 64 THEN 'I zmiana'
            WHEN 66 THEN 'II zmiana'
       END                                                     AS zmiana,
       bi.imie,
       bi.nazwisko,
       bi.pow,
       bi.nr_karty,
       TO_CHAR(bi.data_z, 'month yyyy')                        AS data_zdarzenia,
       SUBSTR(ze.SUBJECT, 1, 8)                                AS nr_ew,
       SUBSTR(ze.SUBJECT, INSTR(ze.SUBJECT, ';') + 1, 10)      AS data
FROM   KP_REQ_REQUEST      z
JOIN   KP_REQ_HR_REQUESTS  ze ON ze.KRRQ_ID = z.id
LEFT JOIN bilans_mies      bi
       ON bi.pow = SUBSTR(ze.SUBJECT, 1, 8)
      AND TO_CHAR(bi.data_z, 'YYYY-MM') =
              SUBSTR(ze.SUBJECT, INSTR(ze.SUBJECT, ';') + 1, 7)   -- 'YYYY-MM' ze zlecenia
WHERE  z.STATUS_TC = 'W'
  AND  ze.HRRC_ID IN (64, 66)
  AND  z.request_date BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
ORDER BY
       zmiana,
       bi.data_z,
       bi.nazwisko,
       bi.imie;

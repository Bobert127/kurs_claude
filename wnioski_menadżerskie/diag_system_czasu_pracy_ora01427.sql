-- ============================================================================
-- Diagnostyka ORA-01427 dla kolumny SYSTEM_CZASU_PRACY
-- (raport: wnioski_menadżerski_czas_pracy.sql)
--
-- Podzapytanie w raporcie NIE ma FETCH FIRST 1 ROWS ONLY i jest skorelowane
-- z PRAC.ID oraz z miesiącem RCBO.DATA (przez TRUNC(LAST_DAY(RCBO.DATA))).
-- "Rekord" = para pracownik + miesiąc. Błąd pojawia się, gdy dla danego
-- pracownika i miesiąca pasuje > 1 system czasu pracy (nakładające się okresy
-- DATE_FROM/DATE_TO w KP_RCP_EMPLOYEE_WOTS).
--
-- Zapytanie zwraca TYLKO rekordy z ILE_WIERSZY > 1 (te powodujące ORA-01427),
-- razem z listą nazw systemów, żeby było widać nakładające się wpisy.
-- ============================================================================
SELECT
    PRAC.ID,
    PRAC.NAZWISKO,
    PRAC.IMIE,
    PRAC.NR_EWIDENCYJNY,
    TO_CHAR(RCBO.DATA, 'YYYY-MM') AS ROK_MIESIAC,
    (
        SELECT COUNT(*)
        FROM KP_RCP_EMPLOYEE_WOTS EMWO
             JOIN KP_RCP_WORKING_TIME_SYSTEMS WOTS
               ON WOTS.ID = EMWO.WOTS_ID
        WHERE EMWO.PRAC_ID = PRAC.ID
          AND EMWO.DATE_FROM <= TRUNC(LAST_DAY(RCBO.DATA))
          AND (EMWO.DATE_TO >= TRUNC(LAST_DAY(RCBO.DATA))
               OR EMWO.DATE_TO IS NULL)
    ) AS ILE_WIERSZY,
    (
        SELECT LISTAGG(WOTS.NAME, ' | ') WITHIN GROUP (ORDER BY WOTS.NAME)
        FROM KP_RCP_EMPLOYEE_WOTS EMWO
             JOIN KP_RCP_WORKING_TIME_SYSTEMS WOTS
               ON WOTS.ID = EMWO.WOTS_ID
        WHERE EMWO.PRAC_ID = PRAC.ID
          AND EMWO.DATE_FROM <= TRUNC(LAST_DAY(RCBO.DATA))
          AND (EMWO.DATE_TO >= TRUNC(LAST_DAY(RCBO.DATA))
               OR EMWO.DATE_TO IS NULL)
    ) AS SYSTEMY
FROM NT_KP_PRC_PRACOWNICY PRAC
    INNER JOIN RCP_BILANS_O RCBO
        ON RCBO.PRAC_ID = PRAC.ID
WHERE RCBO.DATA >= ADD_MONTHS(TRUNC(SYSDATE), -24)
  AND RCBO.STATUS IN ('M', 'ZM')
  AND (
        SELECT COUNT(*)
        FROM KP_RCP_EMPLOYEE_WOTS EMWO
             JOIN KP_RCP_WORKING_TIME_SYSTEMS WOTS
               ON WOTS.ID = EMWO.WOTS_ID
        WHERE EMWO.PRAC_ID = PRAC.ID
          AND EMWO.DATE_FROM <= TRUNC(LAST_DAY(RCBO.DATA))
          AND (EMWO.DATE_TO >= TRUNC(LAST_DAY(RCBO.DATA))
               OR EMWO.DATE_TO IS NULL)
      ) > 1
ORDER BY ILE_WIERSZY DESC, PRAC.NAZWISKO, PRAC.IMIE, ROK_MIESIAC;

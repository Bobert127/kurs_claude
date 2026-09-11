-- ============================================================================
-- Diagnostyka ORA-01427 dla kolumny RODZAJ_STANOWISKA
-- (raport: wnioski_menadżerski_czas_pracy.sql)
--
-- Przyczyna: podzapytanie skalarne
--     (SELECT DISTINCT RECO.RV_MEANING
--      FROM CG_REF_CODES RECO
--      WHERE RECO.RV_DOMAIN = 'ost_dane.t_stan(PRAC.PRAC_ID)')
-- nie ma FETCH FIRST 1 ROWS ONLY, więc gdy zwróci > 1 wiersz -> ORA-01427.
-- Dodatkowo RV_DOMAIN jest porównywane do LITERAŁU (a nie do wartości funkcji),
-- więc podzapytanie NIE jest skorelowane z pracownikiem i daje ten sam wynik
-- dla wszystkich.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- KROK 1. Szybkie, rozstrzygające sprawdzenie GLOBALNE
-- Ile RÓŻNYCH wartości zwraca podzapytanie dokładnie tak, jak w raporcie.
--   ILE_ROZNYCH_WARTOSCI = 0  -> kolumna zawsze NULL (nie ten błąd)
--   ILE_ROZNYCH_WARTOSCI = 1  -> OK, błędu nie ma
--   ILE_ROZNYCH_WARTOSCI > 1  -> to jest źródło ORA-01427 (dla WSZYSTKICH)
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*) AS ILE_ROZNYCH_WARTOSCI,
    LISTAGG(RV_MEANING, ' | ') WITHIN GROUP (ORDER BY RV_MEANING) AS WARTOSCI
FROM (
    SELECT DISTINCT RECO.RV_MEANING
    FROM CG_REF_CODES RECO
    WHERE RECO.RV_DOMAIN = 'ost_dane.t_stan(PRAC.PRAC_ID)'
);


-- ----------------------------------------------------------------------------
-- KROK 2. Lista pracowników "dla kogo" kolumna zwraca > 1 wiersz.
-- Wierne odwzorowanie raportu: ta sama populacja (RCBO status M/ZM, 24 mies.)
-- i to samo podzapytanie. Jeśli literał daje > 1 wartość, wyjdą TU WSZYSCY
-- z populacji raportu (bo podzapytanie jest nieskorelowane) - co potwierdza,
-- że raport nie wykona się dla nikogo.
-- ----------------------------------------------------------------------------
SELECT DISTINCT
    PRAC.ID,
    PRAC.NAZWISKO,
    PRAC.IMIE,
    PRAC.NR_EWIDENCYJNY,
    (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT RECO.RV_MEANING
            FROM CG_REF_CODES RECO
            WHERE RECO.RV_DOMAIN = 'ost_dane.t_stan(PRAC.PRAC_ID)'
        )
    ) AS ILE_WIERSZY
FROM NT_KP_PRC_PRACOWNICY PRAC
    INNER JOIN RCP_BILANS_O RCBO
        ON RCBO.PRAC_ID = PRAC.ID
WHERE RCBO.DATA >= ADD_MONTHS(TRUNC(SYSDATE), -24)
  AND RCBO.STATUS IN ('M', 'ZM')
  AND (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT RECO.RV_MEANING
            FROM CG_REF_CODES RECO
            WHERE RECO.RV_DOMAIN = 'ost_dane.t_stan(PRAC.PRAC_ID)'
        )
      ) > 1
ORDER BY PRAC.NAZWISKO, PRAC.IMIE;


-- ----------------------------------------------------------------------------
-- KROK 3. Wariant "jak to prawdopodobnie miało wyglądać" - SKORELOWANY.
-- Jeśli 'ost_dane.t_stan(PRAC.PRAC_ID)' miało być wywołaniem funkcji
-- zwracającej KOD rodzaju stanowiska pracownika, to prawidłowy lookup wygląda
-- tak, jak niżej. Wtedy ta diagnostyka wskaże KONKRETNYCH pracowników, dla
-- których słownik ma zdublowane znaczenia dla jednego kodu.
--
-- UWAGA: 'NAZWA_DOMENY' trzeba podmienić na właściwą domenę CG_REF_CODES
-- (nie znam jej z treści raportu). RV_LOW_VALUE zwykle jest tekstem, stąd
-- rzutowanie na znak.
-- ----------------------------------------------------------------------------
-- SELECT DISTINCT
--     PRAC.ID,
--     PRAC.NAZWISKO,
--     PRAC.IMIE,
--     PRAC.NR_EWIDENCYJNY,
--     ost_dane.t_stan(PRAC.ID) AS KOD_RODZAJU,
--     (
--         SELECT COUNT(DISTINCT RECO.RV_MEANING)
--         FROM CG_REF_CODES RECO
--         WHERE RECO.RV_DOMAIN = 'NAZWA_DOMENY'
--           AND RECO.RV_LOW_VALUE = TO_CHAR(ost_dane.t_stan(PRAC.ID))
--     ) AS ILE_WIERSZY
-- FROM NT_KP_PRC_PRACOWNICY PRAC
--     INNER JOIN RCP_BILANS_O RCBO
--         ON RCBO.PRAC_ID = PRAC.ID
-- WHERE RCBO.DATA >= ADD_MONTHS(TRUNC(SYSDATE), -24)
--   AND RCBO.STATUS IN ('M', 'ZM')
--   AND (
--         SELECT COUNT(DISTINCT RECO.RV_MEANING)
--         FROM CG_REF_CODES RECO
--         WHERE RECO.RV_DOMAIN = 'NAZWA_DOMENY'
--           AND RECO.RV_LOW_VALUE = TO_CHAR(ost_dane.t_stan(PRAC.ID))
--       ) > 1
-- ORDER BY PRAC.NAZWISKO, PRAC.IMIE;

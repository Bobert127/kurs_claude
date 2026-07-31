SELECT
    PRAC.ID,
    PRAC.NAZWISKO,
    PRAC.IMIE,
    PRAC.NR_EWIDENCYJNY,
    PRAC.NR_KARTY,
    PRAC.DATA_ZATRUDNIENIA,
    PRAC.DATA_ZWOLNIENIA,

    CASE
        WHEN PRAC.STATUS_WYP = 'T' THEN 'WYPOŻYCZONY'
        WHEN PRAC.STATUS_TYMCZASOWY = 'T' THEN 'APT'
        WHEN PRAC.STATUS_KADRY = 'T' THEN 'UMOWA O PRACĘ'
        WHEN PRAC.STATUS_UC = 'T' THEN 'UMOWA CYWILNOPRAWNA'
    END AS TYP_ZATRUDNIENIA,

    FIRM.NAZWA AS FIRMA,

    /* Symbol jednostki organizacyjnej */
    NVL(
        (
            SELECT JEOR.SYMBOL
            FROM L_STANOWISKA L
                 JOIN TETA_JEDN_ORG JEOR
                   ON JEOR.ID = L.JEOR_ID
            WHERE L.PRAC_ID = PRAC.ID
              AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
              AND L.DATA_OD <= TRUNC(SYSDATE)
              AND (L.DATA_DO IS NULL OR L.DATA_DO >= TRUNC(SYSDATE))
              AND JEOR.DATA_OD <= TRUNC(SYSDATE)
              AND (JEOR.DATA_DO IS NULL OR JEOR.DATA_DO >= TRUNC(SYSDATE))
            ORDER BY L.DATA_OD DESC
            FETCH FIRST 1 ROWS ONLY
        ),
        (
            SELECT JEOR.SYMBOL
            FROM L_STANOWISKA L
                 JOIN TETA_JEDN_ORG JEOR
                   ON JEOR.ID = L.JEOR_ID
            WHERE L.PRAC_ID = PRAC.ID
              AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
            ORDER BY L.DATA_OD DESC
            FETCH FIRST 1 ROWS ONLY
        )
    ) AS SYMBOL_JEDNOSTKI,

    /* Nazwa jednostki organizacyjnej */
    NVL(
        (
            SELECT JEOR.NAZWA
            FROM L_STANOWISKA L
                 JOIN TETA_JEDN_ORG JEOR
                   ON JEOR.ID = L.JEOR_ID
            WHERE L.PRAC_ID = PRAC.ID
              AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
              AND L.DATA_OD <= TRUNC(SYSDATE)
              AND (L.DATA_DO IS NULL OR L.DATA_DO >= TRUNC(SYSDATE))
              AND JEOR.DATA_OD <= TRUNC(SYSDATE)
              AND (JEOR.DATA_DO IS NULL OR JEOR.DATA_DO >= TRUNC(SYSDATE))
            ORDER BY L.DATA_OD DESC
            FETCH FIRST 1 ROWS ONLY
        ),
        (
            SELECT JEOR.NAZWA
            FROM L_STANOWISKA L
                 JOIN TETA_JEDN_ORG JEOR
                   ON JEOR.ID = L.JEOR_ID
            WHERE L.PRAC_ID = PRAC.ID
              AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
            ORDER BY L.DATA_OD DESC
            FETCH FIRST 1 ROWS ONLY
        )
    ) AS JEDNOSTKA_ORG,

    /* Stanowisko */
    NVL(
        (
            SELECT S.NAZWA
            FROM L_STANOWISKA L
                 JOIN SL_STAN S
                   ON S.ID = L.KASTA_SL_STAN_ID
            WHERE L.PRAC_ID = PRAC.ID
              AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
              AND L.DATA_OD <= TRUNC(SYSDATE)
              AND (L.DATA_DO IS NULL OR L.DATA_DO >= TRUNC(SYSDATE))
            ORDER BY L.DATA_OD DESC
            FETCH FIRST 1 ROWS ONLY
        ),
        (
            SELECT S.NAZWA
            FROM L_STANOWISKA L
                 JOIN SL_STAN S
                   ON S.ID = L.KASTA_SL_STAN_ID
            WHERE L.PRAC_ID = PRAC.ID
              AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
            ORDER BY L.DATA_OD DESC
            FETCH FIRST 1 ROWS ONLY
        )
    ) AS STANOWISKO,

    /* Druga nazwa stanowiska */
    NVL(
        (
            SELECT S.NAZWA_2
            FROM L_STANOWISKA L
                 JOIN SL_STAN S
                   ON S.ID = L.KASTA_SL_STAN_ID
            WHERE L.PRAC_ID = PRAC.ID
              AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
            ORDER BY L.DATA_OD DESC
            FETCH FIRST 1 ROWS ONLY
        ),
        (
            SELECT S.NAZWA_2
            FROM L_STANOWISKA L
                 JOIN SL_STAN S
                   ON S.ID = L.KASTA_SL_STAN_ID
            WHERE L.PRAC_ID = PRAC.ID
              AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
            ORDER BY L.DATA_OD DESC
            FETCH FIRST 1 ROWS ONLY
        )
    ) AS STANOWISKO_2,

    /* Rodzaj stanowiska */
    (
        SELECT DISTINCT RECO.RV_MEANING
        FROM CG_REF_CODES RECO
        WHERE RECO.RV_DOMAIN = 'ost_dane.t_stan(PRAC.PRAC_ID)'
          AND RECO.RV_LOW_VALUE =
              (
                  SELECT K.STATUS
                  FROM L_STANOWISKA L
                       JOIN KARTOTEKA_STANOWISK K
                         ON K.SL_STAN_ID = L.KASTA_SL_STAN_ID
                        AND K.JEOR_ID    = L.JEOR_ID
                        AND K.ID         = L.KASTA_ID
                  WHERE L.PRAC_ID = PRAC.ID
                    AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
                  ORDER BY L.DATA_OD DESC
                  FETCH FIRST 1 ROWS ONLY
              )
    ) AS RODZAJ_STANOWISKA,

    /* Typ stanowiska */
    (
        SELECT T.NAZWA
        FROM L_STANOWISKA L
             JOIN KARTOTEKA_STANOWISK K
               ON K.SL_STAN_ID = L.KASTA_SL_STAN_ID
              AND K.JEOR_ID    = L.JEOR_ID
              AND K.ID         = L.KASTA_ID
             JOIN KARTA_OPISU_STANOWISKA KOS
               ON KOS.ID = K.KOS_ID
             JOIN ZP_SL_TYPY_STAN T
               ON T.ID = KOS.ZP_SL_TYST_ID
        WHERE L.PRAC_ID = PRAC.ID
          AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
        ORDER BY L.DATA_OD DESC
        FETCH FIRST 1 ROWS ONLY
    ) AS TYP_STANOWISKA,

    /* Lokalizacja */
    (
        SELECT SLOK.NAZWA
        FROM L_STANOWISKA L
             JOIN KARTOTEKA_STANOWISK K
               ON K.SL_STAN_ID = L.KASTA_SL_STAN_ID
              AND K.JEOR_ID    = L.JEOR_ID
              AND K.ID         = L.KASTA_ID
             JOIN SL_LOKAL_STAN SLOK
               ON SLOK.ID = K.LOSTA_ID
        WHERE L.PRAC_ID = PRAC.ID
          AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
        ORDER BY L.DATA_OD DESC
        FETCH FIRST 1 ROWS ONLY
    ) AS LOKALIZACJA,

    RODS.SYMBOL AS RODZINA_STANOWISK_SYMBOL,
    RODS.NAZWA  AS RODZINA_STANOWISK,

    /* Kod GUS stanowiska */
    (
        SELECT SLKZ.KOD
        FROM L_STANOWISKA L
             JOIN SL_STAN S
               ON S.ID = L.KASTA_SL_STAN_ID
             JOIN SL_KODY_ZAWOD SLKZ
               ON SLKZ.ID = S.SLKZ_ID
        WHERE L.PRAC_ID = PRAC.ID
          AND (L.STATUS IS NULL OR L.STATUS IN ('W','Z'))
        ORDER BY L.DATA_OD DESC
        FETCH FIRST 1 ROWS ONLY
    ) AS KOD_GUS,

    /* Przełożony */
    NVL(
        (
            SELECT PRAC_W.IMIE || ' ' || PRAC_W.NAZWISKO
            FROM L_STRUKTURA_AGENTOW STAG
                 JOIN SL_RODZ_PODL RPSL
                   ON RPSL.ID = STAG.RODZ_PODL_ID
                  AND RPSL.DEFAULT_KIND = 'T'
                  AND RPSL.AKTUALNA = 'T'
                 JOIN T_PRAC_W PRAC_W
                   ON PRAC_W.PRAC_ID = STAG.PRZELOZONY_ID
            WHERE STAG.PRAC_ID = PRAC.ID
              AND STAG.BEZPOSREDNI = 'T'
            ORDER BY STAG.DATA_OD DESC,
                     STAG.DATA_UTWORZENIA DESC
            FETCH FIRST 1 ROWS ONLY
        ),
        NULL
    ) AS PRZELOZONY,

    TO_CHAR(RCBO.DATA, 'YYYY-MM') AS ROK_MIESIAC,

    RK_MPK_SQL.KOD(RCBO.MPK_ID) AS KOD_MPK,

    (
        SELECT WOTS.NAME
        FROM KP_RCP_EMPLOYEE_WOTS EMWO
             JOIN KP_RCP_WORKING_TIME_SYSTEMS WOTS
               ON WOTS.ID = EMWO.WOTS_ID
        WHERE EMWO.PRAC_ID = PRAC.ID
          AND EMWO.DATE_FROM <= TRUNC(LAST_DAY(RCBO.DATA))
          AND (EMWO.DATE_TO >= TRUNC(LAST_DAY(RCBO.DATA))
               OR EMWO.DATE_TO IS NULL)
    ) AS SYSTEM_CZASU_PRACY,

    (
        SELECT RCOK.NAZWA
        FROM KP_RCP_OKRESY_PRAC OKRP
             JOIN KP_RCP_OKRESY_BILANSU RCOK
               ON RCOK.ID = OKRP.RCOK_ID
        WHERE OKRP.PRAC_ID = PRAC.ID
          AND OKRP.DATA_OD <= TRUNC(LAST_DAY(RCBO.DATA))
          AND (OKRP.DATA_DO >= TRUNC(LAST_DAY(RCBO.DATA))
               OR OKRP.DATA_DO IS NULL)
        FETCH FIRST 1 ROWS ONLY
    ) AS OKRES_ROZLICZENIOWY,

    NUMTODSINTERVAL(
        KP_RCP_OVERTIME_SUMMARY.Employee_Unused_Summary_Json(
            PRAC.ID,
            'T',
            'T',
            RCBO.DATA
        ).UNUSED_HOURS_TOTAL,
        'SECOND'
    ) AS SALDO_NADGODZIN,

    KP_RCP_OVERTIME_SUMMARY.Employee_Unused_Summary_Json(
        PRAC.ID,
        'T',
        'T',
        RCBO.DATA
    ).UNUSED_DAYS_TOTAL AS SALDO_DNI_DO_ODBIORU,

    NUMTODSINTERVAL(
        KP_RCP_OVERTIME_SUMMARY.Employee_Unused_Summary_Json(
            PRAC.ID,
            'N',
            'T',
            RCBO.DATA
        ).UNUSED_SHORT_BREAK_HOURS_TOTAL,
        'SECOND'
    ) AS SALDO_NADGODZIN_SKROCONY_ODPOCZYNEK,

    KP_RCP_OVERTIME_SUMMARY.Employee_Unused_Summary_Json(
        PRAC.ID,
        'T',
        'N',
        RCBO.DATA
    ).UNUSED_SHORT_BREAK_DAYS_TOTAL AS SALDO_DNI_SKROCONY_ODPOCZYNEK

FROM NT_KP_PRC_PRACOWNICY PRAC

LEFT JOIN NT_PA_SLO_FIRMY FIRM
       ON FIRM.ID = PRAC.FIRM_ID

INNER JOIN RCP_BILANS_O RCBO
       ON RCBO.PRAC_ID = PRAC.ID

LEFT JOIN NT_KP_KOP_KOS_PRAC PKOS
       ON PKOS.PRAC_ID = PRAC.ID

LEFT JOIN NT_KP_SLO_RODZINY_STAN RODS
       ON RODS.ID = PKOS.RODS_ID

WHERE RCBO.DATA >= ADD_MONTHS(TRUNC(SYSDATE), -24)
  AND RCBO.STATUS IN ('M','ZM')

ORDER BY
    PRAC.NAZWISKO,
    PRAC.IMIE,
    RCBO.DATA;


-- ============================================================================
-- WERYFIKACJA: osoby/rekordy powodujące ORA-01427 w kolumnie SYSTEM_CZASU_PRACY
-- ----------------------------------------------------------------------------
-- Podzapytanie SYSTEM_CZASU_PRACY nie ma FETCH FIRST 1 ROWS ONLY i jest
-- skorelowane z PRAC.ID oraz miesiącem RCBO.DATA. Poniższe zapytanie zwraca
-- TYLKO rekordy (pracownik + miesiąc), dla których pasuje > 1 system czasu
-- pracy (nakładające się okresy DATE_FROM/DATE_TO w KP_RCP_EMPLOYEE_WOTS).
-- Odkomentuj i uruchom, aby znaleźć osoby z błędem.
-- ============================================================================
-- SELECT
--     PRAC.ID,
--     PRAC.NAZWISKO,
--     PRAC.IMIE,
--     PRAC.NR_EWIDENCYJNY,
--     TO_CHAR(RCBO.DATA, 'YYYY-MM') AS ROK_MIESIAC,
--     (
--         SELECT COUNT(*)
--         FROM KP_RCP_EMPLOYEE_WOTS EMWO
--              JOIN KP_RCP_WORKING_TIME_SYSTEMS WOTS
--                ON WOTS.ID = EMWO.WOTS_ID
--         WHERE EMWO.PRAC_ID = PRAC.ID
--           AND EMWO.DATE_FROM <= TRUNC(LAST_DAY(RCBO.DATA))
--           AND (EMWO.DATE_TO >= TRUNC(LAST_DAY(RCBO.DATA))
--                OR EMWO.DATE_TO IS NULL)
--     ) AS ILE_WIERSZY,
--     (
--         SELECT LISTAGG(WOTS.NAME, ' | ') WITHIN GROUP (ORDER BY WOTS.NAME)
--         FROM KP_RCP_EMPLOYEE_WOTS EMWO
--              JOIN KP_RCP_WORKING_TIME_SYSTEMS WOTS
--                ON WOTS.ID = EMWO.WOTS_ID
--         WHERE EMWO.PRAC_ID = PRAC.ID
--           AND EMWO.DATE_FROM <= TRUNC(LAST_DAY(RCBO.DATA))
--           AND (EMWO.DATE_TO >= TRUNC(LAST_DAY(RCBO.DATA))
--                OR EMWO.DATE_TO IS NULL)
--     ) AS SYSTEMY
-- FROM NT_KP_PRC_PRACOWNICY PRAC
--     INNER JOIN RCP_BILANS_O RCBO
--         ON RCBO.PRAC_ID = PRAC.ID
-- WHERE RCBO.DATA >= ADD_MONTHS(TRUNC(SYSDATE), -24)
--   AND RCBO.STATUS IN ('M', 'ZM')
--   AND (
--         SELECT COUNT(*)
--         FROM KP_RCP_EMPLOYEE_WOTS EMWO
--              JOIN KP_RCP_WORKING_TIME_SYSTEMS WOTS
--                ON WOTS.ID = EMWO.WOTS_ID
--         WHERE EMWO.PRAC_ID = PRAC.ID
--           AND EMWO.DATE_FROM <= TRUNC(LAST_DAY(RCBO.DATA))
--           AND (EMWO.DATE_TO >= TRUNC(LAST_DAY(RCBO.DATA))
--                OR EMWO.DATE_TO IS NULL)
--       ) > 1
-- ORDER BY ILE_WIERSZY DESC, PRAC.NAZWISKO, PRAC.IMIE, ROK_MIESIAC;

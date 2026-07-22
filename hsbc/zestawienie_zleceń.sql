-- =====================================================================
-- Zestawienie zlecen / nadgodzin - kolumny godzinowe w formacie HH:MI.
--
-- Kolumny od g_zlecone do YTD, ktore sa GODZINAMI (wynik p_rcp_licz.n_nh,
-- np. 10.5), prezentowane jako HH:MI (10:30). Kolumny "dniowe"
-- (odebrane_dni, saldo_dni) oraz tekstowe/id zostaja bez zmian.
-- Obsluga: NULL, wartosci > 24h (np. 40 -> 40:00) i znak ujemny (saldo).
--
-- UWAGA (GenRap/wzorzec): kolumny godzinowe sa teraz TEKSTEM 'HH:MI', wiec
--   ich komorki w szablonie ustaw na tekst (@), a zmienne raportu na VARCHAR2
--   (nie NUMBER) - inaczej ryzyko "naprawiania" pliku Excel.
-- =====================================================================
SELECT
    lp, prac_id, imie, nazwisko, nr_ew, nr_karty, jednostka_org, mpk, stanowisko,
    data_zlecenia,
    CASE WHEN src.g_zlecone IS NULL THEN NULL ELSE CASE WHEN src.g_zlecone < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.g_zlecone)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.g_zlecone)*60),60)),2,'0') END AS g_zlecone,
    CASE WHEN src.g_ponadwymiar IS NULL THEN NULL ELSE CASE WHEN src.g_ponadwymiar < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.g_ponadwymiar)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.g_ponadwymiar)*60),60)),2,'0') END AS g_ponadwymiar,
    CASE WHEN src.g_50 IS NULL THEN NULL ELSE CASE WHEN src.g_50 < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.g_50)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.g_50)*60),60)),2,'0') END AS g_50,
    CASE WHEN src.g_100 IS NULL THEN NULL ELSE CASE WHEN src.g_100 < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.g_100)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.g_100)*60),60)),2,'0') END AS g_100,
    CASE WHEN src.g_nocne IS NULL THEN NULL ELSE CASE WHEN src.g_nocne < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.g_nocne)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.g_nocne)*60),60)),2,'0') END AS g_nocne,
    CASE WHEN src.g_odebrane IS NULL THEN NULL ELSE CASE WHEN src.g_odebrane < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.g_odebrane)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.g_odebrane)*60),60)),2,'0') END AS g_odebrane,
    odebrane_dni,
    CASE WHEN src.za_g_ponadwymiar IS NULL THEN NULL ELSE CASE WHEN src.za_g_ponadwymiar < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.za_g_ponadwymiar)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.za_g_ponadwymiar)*60),60)),2,'0') END AS za_g_ponadwymiar,
    CASE WHEN src.za_g_50 IS NULL THEN NULL ELSE CASE WHEN src.za_g_50 < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.za_g_50)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.za_g_50)*60),60)),2,'0') END AS za_g_50,
    CASE WHEN src.za_g_100 IS NULL THEN NULL ELSE CASE WHEN src.za_g_100 < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.za_g_100)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.za_g_100)*60),60)),2,'0') END AS za_g_100,
    CASE WHEN src.za_g_nocne IS NULL THEN NULL ELSE CASE WHEN src.za_g_nocne < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.za_g_nocne)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.za_g_nocne)*60),60)),2,'0') END AS za_g_nocne,
    CASE WHEN src.saldo_godzin IS NULL THEN NULL ELSE CASE WHEN src.saldo_godzin < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.saldo_godzin)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.saldo_godzin)*60),60)),2,'0') END AS saldo_godzin,
    saldo_dni,
    CASE WHEN src.ytd IS NULL THEN NULL ELSE CASE WHEN src.ytd < 0 THEN '-' END||LPAD(TO_CHAR(TRUNC(ROUND(ABS(src.ytd)*60)/60)),2,'0')||':'||LPAD(TO_CHAR(MOD(ROUND(ABS(src.ytd)*60),60)),2,'0') END AS ytd,
    okres_rozliczeniowy
FROM (
        SELECT
        ROW_NUMBER() OVER (ORDER BY NLSSORT(p.nazwisko, 'NLS_SORT=POLISH'), NLSSORT(p.imie,'NLS_SORT=POLISH')) AS lp,
                   p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
                   akt_dane.j_org(p.prac_id, LEAST(NVL(p.data_rozw, DATE '2026-04-06'), DATE '2026-04-06')) AS jednostka_org,
                   akt_dane.mpk(p.prac_id, LEAST(NVL(p.data_rozw, DATE '2026-04-06'), DATE '2026-04-06')) AS mpk,
                   akt_dane.stanowisko(p.prac_id, LEAST(NVL(p.data_rozw, DATE '2026-04-06'), DATE '2026-04-06')) AS stanowisko,
                   to_char(zn.data, 'dd-mm-yyyy') data_zlecenia,
                   round(p_rcp_licz.n_nh(zn.czas),2) g_zlecone,
                   p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_30/3600) g_ponadwymiar, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_11/3600 + zn.CLASSIFIED_SECONDS_32/3600) g_50,
                   p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_12/3600 + zn.CLASSIFIED_SECONDS_33/3600 + zn.CLASSIFIED_SECONDS_20/3600) g_100, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_03/3600) g_nocne,
                   nvl(p_rcp_licz.n_nh(odb.seconds_count/3600),0) g_odebrane, case when odb.all_day = 'T' then 1 else 0 end odebrane_dni,

                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_30/3600),0) za_g_ponadwymiar, nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_11/3600 + za.CLASSIFIED_SECONDS_32/3600),0) za_g_50,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_12/3600 + za.CLASSIFIED_SECONDS_33/3600 + za.CLASSIFIED_SECONDS_20/3600),0) za_g_100, nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_03/3600),0) za_g_nocne,

                  ROUND(case when zn.settled = 'T' then 0 else round(p_rcp_licz.n_nh(zn.czas),2) - nvl(p_rcp_licz.n_nh(odb.seconds_count/3600),0) - nvl(p_rcp_licz.n_nh(za.seconds_count/3600),0) end,2) saldo_godzin,
                  NVL(case when zn.settled = 'T' then 0 when odb.all_day = 'T' then 0  when zn.DAY_OFF_IN_LIEU = 'T' then 1 end, 0) saldo_dni,

                  (SELECT round(p_rcp_licz.n_nh(SUM(z.czas)),2) g_zlecone
                  FROM KP_RCP_ZLEC_NADG_PRAC Z
                  WHERE Z.DATA BETWEEN TRUNC(zn.data, 'YYYY') AND (ADD_MONTHS(TRUNC(zn.data, 'YYYY'), 12) - 1)
                  AND Z.PRAC_ID = ZN.PRAC_ID
                  ) YTD,

                  (SELECT MAX(k_164||' '||case when k_164 = 1 then '- miesięczny' when k_164 = 3 then '- miesięczny' end||' okres rozliczeniowy')
                  FROM RCP_BILANS B
                  WHERE B.PRAC_ID = ZN.PRAC_ID
                  AND TRUNC(B.DATA) = TRUNC(ZN.DATA)
                  ) OKRES_ROZLICZENIOWY

            FROM t_prac p, KP_RCP_ZLEC_NADG_PRAC zn
            left join KP_RCP_LABS_RCZP odb on odb.rczp_id = zn.id
            left join KP_RCP_OVERTIME_PAYMENT za on za.RCZP_ID = zn.id
            where p.prac_id = zn.PRAC_ID
            and zn.data between '26/06/01' and '26/07/31'
            -- AND P.NR_EW = '45297529'
) src
ORDER BY lp;

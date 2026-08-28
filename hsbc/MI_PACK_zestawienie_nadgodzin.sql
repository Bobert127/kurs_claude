SELECT     lp, imie, nazwisko, nr_ew, nr_karty, jednostka_org, mpk, stanowisko,
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
    ytd,
    okres_rozliczeniowy
 INTO V_LP, V_IMIE, V_NAZWISKO, V_NR_EW, V_NR_KARTY, V_JO, V_MPK, V_STANOWISKO, V_G_ZLECONE, V_G_PONADWYMIAROWE, V_G_50, V_G_100, V_G_NOCNE, V_G_ODEBRANE, V_DNI_ODEBRANE, V_ZA_G_PONADWYMIAROWE, V_ZA_G_50, V_ZA_G_100, V_ZA_NOCNE, V_SALOD_GODZIN, V_SALDO_DNI, V_YTD, V_OKRES_ROZLICZENIOWY
FROM  (
        SELECT
            ROW_NUMBER() OVER (ORDER BY NLSSORT(nazwisko, 'NLS_SORT=POLISH'), NLSSORT(imie,'NLS_SORT=POLISH')) AS lp,
            prac_id, imie, nazwisko, nr_ew, nr_karty, jednostka_org, mpk, stanowisko,
            SUM(p_rcp_licz.nh_n(g_zlecone))        g_zlecone,
            SUM(p_rcp_licz.nh_n(g_ponadwymiar))    g_ponadwymiar,
            SUM(p_rcp_licz.nh_n(g_50))             g_50,
            SUM(p_rcp_licz.nh_n(g_100))            g_100,
            SUM(p_rcp_licz.nh_n(g_nocne))          g_nocne,
            SUM(p_rcp_licz.nh_n(g_odebrane))       g_odebrane,
            SUM(odebrane_dni)                      odebrane_dni,
            SUM(p_rcp_licz.nh_n(za_g_ponadwymiar)) za_g_ponadwymiar,
            SUM(p_rcp_licz.nh_n(za_g_50))          za_g_50,
            SUM(p_rcp_licz.nh_n(za_g_100))         za_g_100,
            SUM(p_rcp_licz.nh_n(za_g_nocne))       za_g_nocne,
            SUM(p_rcp_licz.nh_n(saldo_godzin))     saldo_godzin,
            SUM(saldo_dni)        saldo_dni,
            MAX(ytd)              ytd,
            MAX(okres_rozliczeniowy) okres_rozliczeniowy,
            LISTAGG(CASE WHEN rn_data = 1 THEN TO_CHAR(data_dt, 'dd-mm-yyyy') END, ', ')
                WITHIN GROUP (ORDER BY data_dt) daty_zlecen
        FROM (
                SELECT
                   p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
                   akt_dane.j_org(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('^$data_do^','^$V_DATA_FORMAT^')), TO_DATE('^$data_do^','^$V_DATA_FORMAT^'))) AS jednostka_org,
                   akt_dane.mpk(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('^$data_do^','^$V_DATA_FORMAT^')), TO_DATE('^$data_do^','^$V_DATA_FORMAT^'))) AS mpk,
                   akt_dane.stanowisko(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('^$data_do^','^$V_DATA_FORMAT^')), TO_DATE('^$data_do^','^$V_DATA_FORMAT^'))) AS stanowisko,
                   round(p_rcp_licz.n_nh(zn.czas),2) g_zlecone,
                   p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_30/3600) g_ponadwymiar, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_11/3600 + zn.CLASSIFIED_SECONDS_32/3600) g_50,
                   p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_12/3600 + zn.CLASSIFIED_SECONDS_33/3600 + zn.CLASSIFIED_SECONDS_20/3600) g_100, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_03/3600) g_nocne,
                   nvl(p_rcp_licz.n_nh(odb.seconds_count/3600),0) g_odebrane, case when odb.all_day = 'T' then 1 else 0 end odebrane_dni,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_30/3600),0) za_g_ponadwymiar, nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_11/3600 + za.CLASSIFIED_SECONDS_32/3600),0) za_g_50,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_12/3600 + za.CLASSIFIED_SECONDS_33/3600 + za.CLASSIFIED_SECONDS_20/3600),0) za_g_100,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_03/3600),0) za_g_nocne,
                  ROUND(case when zn.settled = 'T' then 0 else round(p_rcp_licz.n_nh(zn.czas),2) - nvl(p_rcp_licz.n_nh(odb.seconds_count/3600),0) - nvl(p_rcp_licz.n_nh(za.seconds_count/3600),0) end,2) saldo_godzin,
                  NVL(case when zn.settled = 'T' then 0 when odb.all_day = 'T' then 0  when zn.DAY_OFF_IN_LIEU = 'T' then 1 end, 0) saldo_dni,
                  (SELECT round(p_rcp_licz.n_nh(SUM(z.czas)),2)
                  FROM KP_RCP_ZLEC_NADG_PRAC Z
                  WHERE Z.DATA BETWEEN TRUNC(zn.data, 'YYYY') AND (ADD_MONTHS(TRUNC(zn.data, 'YYYY'), 12) - 1)
                  AND Z.PRAC_ID = ZN.PRAC_ID
                  ) YTD,
                  (SELECT MAX(k_164||' '||case when k_164 = 1 then '- miesięczny' when k_164 = 3 then '- miesięczny' end||' okres rozliczeniowy')
                  FROM RCP_BILANS B
                  WHERE B.PRAC_ID = ZN.PRAC_ID
                  AND TRUNC(B.DATA) = TRUNC(ZN.DATA)
                  ) OKRES_ROZLICZENIOWY,
                  zn.data data_dt,
                  ROW_NUMBER() OVER (PARTITION BY zn.id ORDER BY zn.data) rn_data
            FROM t_prac p, T_PRAC_ROB ROB, KP_RCP_ZLEC_NADG_PRAC zn
            left join KP_RCP_LABS_RCZP odb on odb.rczp_id = zn.id
            left join KP_RCP_OVERTIME_PAYMENT za on za.RCZP_ID = zn.id
            where p.prac_id = zn.PRAC_ID
            AND P.PRAC_ID = ROB.PRAC_ID
            AND ROB.sessionid = '^$P_SESSION_ID^'
            and zn.data between TO_DATE('^$data_od^','^$V_DATA_FORMAT^') and TO_DATE('^$data_do^','^$V_DATA_FORMAT^')

            union

                SELECT
                   p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
                   akt_dane.j_org(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('^$data_do^','^$V_DATA_FORMAT^')), TO_DATE('^$data_do^','^$V_DATA_FORMAT^'))) AS jednostka_org,
                   akt_dane.mpk(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('^$data_do^','^$V_DATA_FORMAT^')), TO_DATE('^$data_do^','^$V_DATA_FORMAT^'))) AS mpk,
                   akt_dane.stanowisko(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('^$data_do^','^$V_DATA_FORMAT^')), TO_DATE('^$data_do^','^$V_DATA_FORMAT^'))) AS stanowisko,
                   round(p_rcp_licz.n_nh(zn.czas),2) g_zlecone,
                   p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_30/3600) g_ponadwymiar, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_11/3600 + zn.CLASSIFIED_SECONDS_32/3600) g_50,
                   p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_12/3600 + zn.CLASSIFIED_SECONDS_33/3600 + zn.CLASSIFIED_SECONDS_20/3600) g_100, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_03/3600) g_nocne,
                   nvl(p_rcp_licz.n_nh(odb.seconds_count/3600),0) g_odebrane, case when odb.all_day = 'T' then 1 else 0 end odebrane_dni,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_30/3600),0) za_g_ponadwymiar, nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_11/3600 + za.CLASSIFIED_SECONDS_32/3600),0) za_g_50,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_12/3600 + za.CLASSIFIED_SECONDS_33/3600 + za.CLASSIFIED_SECONDS_20/3600),0) za_g_100,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_03/3600),0) za_g_nocne,
                  ROUND(case when zn.settled = 'T' then 0 else round(p_rcp_licz.n_nh(zn.czas),2) - nvl(p_rcp_licz.n_nh(odb.seconds_count/3600),0) - nvl(p_rcp_licz.n_nh(za.seconds_count/3600),0) end,2) saldo_godzin,
                  NVL(case when zn.settled = 'T' then 0 when odb.all_day = 'T' then 0  when zn.DAY_OFF_IN_LIEU = 'T' then 1 end, 0) saldo_dni,
                  (SELECT round(p_rcp_licz.n_nh(SUM(z.czas)),2)
                  FROM KP_RCP_ZLEC_NADG_PRAC Z
                  WHERE Z.DATA BETWEEN TRUNC(zn.data, 'YYYY') AND (ADD_MONTHS(TRUNC(zn.data, 'YYYY'), 12) - 1)
                  AND Z.PRAC_ID = ZN.PRAC_ID
                  ) YTD,
                  (SELECT MAX(k_164||' '||case when k_164 = 1 then '- miesięczny' when k_164 = 3 then '- miesięczny' end||' okres rozliczeniowy')
                  FROM RCP_BILANS B
                  WHERE B.PRAC_ID = ZN.PRAC_ID
                  AND TRUNC(B.DATA) = TRUNC(ZN.DATA)
                  ) OKRES_ROZLICZENIOWY,
                  zn.data data_dt,
                  ROW_NUMBER() OVER (PARTITION BY zn.id ORDER BY zn.data) rn_data
            FROM t_prac p, KP_RCP_ZLEC_NADG_PRAC zn
            left join KP_RCP_LABS_RCZP odb on odb.rczp_id = zn.id
            left join KP_RCP_OVERTIME_PAYMENT za on za.RCZP_ID = zn.id
            where p.prac_id = zn.PRAC_ID
            and zn.data between TO_DATE('^$data_od^','^$V_DATA_FORMAT^') and TO_DATE('^$data_do^','^$V_DATA_FORMAT^')
            AND NOT EXISTS (
                SELECT 1
                FROM T_PRAC_ROB ROB2
                WHERE ROB2.PRAC_ID = p.PRAC_ID
                  AND ROB2.sessionid = '^$P_SESSION_ID^'
            )
            AND EXISTS (
                SELECT 1
                FROM L_STANOWISKA LS, L_KASTA_MPK LKM, RK_MPK RM, KP_KDR_ADDITIONAL_INFO_4 WM
                WHERE 1=1
                  AND LS.PRAC_ID = p.PRAC_ID
                  AND LS.KASTA_ID = LKM.KASTA_ID
                  AND LKM.MPK_ID = RM.ID
                  AND RM.NAZWA = WM.T_01
                  AND WM.T_02 = 'Właściciel'
                  AND WM.PRAC_ID = (
                      SELECT U.PRAC_ID
                      FROM NT_PA_ADM_UZYTKOWNICY U
                      WHERE U.ID = (
                          SELECT PA_SESJE.USER_ID
                          FROM DUAL
                      )
                  )
                  AND LS.DATA_OD <= TO_DATE('^$data_od^','^$V_DATA_FORMAT^')
                  AND (LS.DATA_DO >= TO_DATE('^$data_do^','^$V_DATA_FORMAT^') OR LS.DATA_DO IS NULL)
                  AND WM.DATE_FROM <= TRUNC(SYSDATE)
                  AND (WM.DATE_TO >= TRUNC(SYSDATE) OR WM.DATE_TO IS NULL)
            )

        ) dane
        GROUP BY prac_id, imie, nazwisko, nr_ew, nr_karty, jednostka_org, mpk, stanowisko
) src
ORDER BY lp;

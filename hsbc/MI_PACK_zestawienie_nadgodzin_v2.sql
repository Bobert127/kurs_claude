SELECT     lp, imie, nazwisko, nr_ew, nr_karty, jednostka_org, mpk, stanowisko,
    to_char(round(src.g_zlecone, 2), 'FM999999990.00')  AS g_zlecone,
    to_char(round(src.g_ponadwymiar, 2), 'FM999999990.00')  AS g_ponadwymiar,
    to_char(round(src.g_50, 2), 'FM999999990.00')  AS g_50,
    to_char(round(src.g_100, 2), 'FM999999990.00')  AS g_100,
    to_char(round(src.g_nocne , 2), 'FM999999990.00')  AS g_nocne,
    to_char(round(src.g_odebrane,2), 'FM999999990.00')  AS g_odebrane,
    odebrane_dni,
    to_char(round(src.za_g_ponadwymiar, 2), 'FM999999990.00')  AS za_g_ponadwymiar,
    to_char(round(src.za_g_50, 2), 'FM999999990.00')  AS za_g_50,
    to_char(round(src.za_g_100, 2), 'FM999999990.00')  AS za_g_100,
    to_char(round(src.za_g_nocne, 2), 'FM999999990.00')  AS za_g_nocne,
    to_char(round(src.saldo_godzin, 2), 'FM999999990.00')  AS saldo_godzin,    saldo_dni,
    to_char(ytd, 'FM999999990.00') AS ytd,
    okres_rozliczeniowy
--  INTO V_LP, V_IMIE, V_NAZWISKO, V_NR_EW, V_NR_KARTY, V_JO, V_MPK, V_STANOWISKO, V_G_ZLECONE, V_G_PONADWYMIAROWE, V_G_50, V_G_100, V_G_NOCNE, V_G_ODEBRANE, V_DNI_ODEBRANE, V_ZA_G_PONADWYMIAROWE, V_ZA_G_50, V_ZA_G_100, V_ZA_NOCNE, V_SALOD_GODZIN, V_SALDO_DNI, V_YTD, V_OKRES_ROZLICZENIOWY
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
                   akt_dane.j_org(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('31.08.2026','DD.MM.YYYY')), TO_DATE('31.08.2026','DD.MM.YYYY'))) AS jednostka_org,
                   akt_dane.mpk(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('31.08.2026','DD.MM.YYYY')), TO_DATE('31.08.2026','DD.MM.YYYY'))) AS mpk,
                   akt_dane.stanowisko(p.prac_id, LEAST(NVL(p.data_rozw, TO_DATE('31.08.2026','DD.MM.YYYY')), TO_DATE('31.08.2026','DD.MM.YYYY'))) AS stanowisko,
                   round(p_rcp_licz.n_nh(zn.czas),2) g_zlecone,
                   p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_30/3600) g_ponadwymiar, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_11/3600 + zn.CLASSIFIED_SECONDS_32/3600) g_50,
                   p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_12/3600 + zn.CLASSIFIED_SECONDS_33/3600 + zn.CLASSIFIED_SECONDS_20/3600) g_100, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_03/3600) g_nocne,
                   nvl(p_rcp_licz.n_nh(odb.seconds_count/3600),0) g_odebrane, case when odb.all_day = 'T' then 1 else 0 end odebrane_dni,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_30/3600),0) za_g_ponadwymiar, nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_11/3600 + za.CLASSIFIED_SECONDS_32/3600),0) za_g_50,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_12/3600 + za.CLASSIFIED_SECONDS_33/3600 + za.CLASSIFIED_SECONDS_20/3600),0) za_g_100,
                   nvl(p_rcp_licz.n_nh(za.CLASSIFIED_SECONDS_03/3600),0) za_g_nocne,
                  ROUND(case when zn.settled = 'T' then 0 else round(p_rcp_licz.n_nh(zn.czas),2) - nvl(p_rcp_licz.n_nh(odb.seconds_count/3600),0) - nvl(p_rcp_licz.n_nh(za.seconds_count/3600),0) end,2) saldo_godzin,
                  NVL(case when zn.settled = 'T' then 0 when odb.all_day = 'T' then 0 when zn.DAY_OFF_IN_LIEU = 'T' and zn.settled = 'N' and row_number() over (partition by k.dzien_mies order by zn.id) = 1 then 1 else 0 end, 0) saldo_dni,
                  (SELECT round(p_rcp_licz.n_nh(SUM(z.czas)),2)
                  FROM KP_RCP_ZLEC_NADG_PRAC Z
                  WHERE Z.DATA BETWEEN TRUNC(zn.data, 'YYYY') AND (ADD_MONTHS(TRUNC(zn.data, 'YYYY'), 12) - 1)
                  AND Z.PRAC_ID = ZN.PRAC_ID
                  ) YTD,
                  (SELECT MAX(k_164||' '||case when k_164 in(1,3) and pa_sesje.biezacy_jezyk = 'en' then '- month' else '- miesięczny' end|| case when pa_sesje.biezacy_jezyk = 'en' then ' settlement period' else ' okres rozliczeniowy' end)
                  FROM RCP_BILANS B
                  WHERE B.PRAC_ID = ZN.PRAC_ID
                  AND TRUNC(B.DATA) = TRUNC(ZN.DATA)
                  ) OKRES_ROZLICZENIOWY,
                  zn.data data_dt,
                  ROW_NUMBER() OVER (PARTITION BY zn.id ORDER BY zn.data) rn_data
            FROM NT_KP_KDR_KALENDARZE_PRAC k, t_prac p,  KP_RCP_ZLEC_NADG_PRAC zn
            left join KP_RCP_LABS_RCZP odb on odb.rczp_id = zn.id
            left join KP_RCP_OVERTIME_PAYMENT za on za.RCZP_ID = zn.id
            where p.prac_id = zn.PRAC_ID
            and k.prac_id = zn.prac_id
            and k.id = zn.kali_id
            AND P.PRAC_ID = 76220
            -- AND ROB.sessionid = '^$P_SESSION_ID^'
            and zn.data between TO_DATE('01.08.2026','DD.MM.YYYY') and TO_DATE('31.08.2026','DD.MM.YYYY')

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
                  AND LS.DATA_OD <= TO_DATE('01.08.2026','DD.MM.YYYY')
                  AND (LS.DATA_DO >= TO_DATE('31.08.2026','DD.MM.YYYY') OR LS.DATA_DO IS NULL)
                  AND WM.DATE_FROM <= TRUNC(SYSDATE)
                  AND (WM.DATE_TO >= TRUNC(SYSDATE) OR WM.DATE_TO IS NULL)
            )
        ) dane
        GROUP BY prac_id, imie, nazwisko, nr_ew, nr_karty, jednostka_org, mpk, stanowisko
) src
ORDER BY lp;

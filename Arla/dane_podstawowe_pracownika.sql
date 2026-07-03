-- Raport informacji podstawowych pracownika
select PRAC.NR_EWIDENCYJNY nr_ewidencyjny, PRAC.NAZWISKO nazwisko, PRAC.IMIE IMIE, NSTA.NAZWA STANOWISKO, MPK.NAZWA cost_center, ORG.NAZWA JEDN_ORG, ORG2.NAZWA DZIAL, PRAC.DATA_ZATRUDNIENIA DATA_UMOWY, PRAC.DATA_ZWOLNIENIA DATA_ZWOLNIENIA, PRAC.E_MAIL EMAIL,
SUMO.NAZWA RODZAJ_UMOWY, LSTN.WYMIAR_ETATU_LICZNIK||'/'||LSTN.WYMIAR_ETATU_MIANOWNIK ETAT, UMOW.DATA_OD U_DATA_OD, UMOW.DATA_DO U_DATA_DO,
akt_dane.stawka(prac.id, sysdate) STAWKA, prac.pesel PESEL, prac.data_urodzenia DATA_URODZENIA, konr.nazwa URZAD_SKARBOWY, FIRM.NAZWA FIIRMA, RACH.NR_RACHUNKU RACHUNEK_BANKOWY, BANK.NAZWA NAZWA_BANK, INF1.T_01 BAND, NFZ.NAZWA NFZ, KNFZ.data_od nfz_data_od, KNFZ.data_do nfz_data_do,
akt_dane.stopien_wykszt(prac.id, sysdate) WYKSZTALCENIE, adrs.city_name||' '||adrs.post_code||' '||adrs.street_name||' '||adrs.BUILDING_NO||case when adrs.HOUSE_NO is null then null else '/' end||adrs.HOUSE_NO adres_staly,
adrt.city_name||' '||adrt.post_code||' '||adrt.street_name||' '||adrt.BUILDING_NO||case when adrt.HOUSE_NO is null then null else '/' end||adrt.HOUSE_NO adres_zamieszkania,
adrc.city_name||' '||adrc.post_code||' '||adrc.street_name||' '||adrc.BUILDING_NO||case when adrc.HOUSE_NO is null then null else '/' end||adrc.HOUSE_NO adres_korespondecyjny

-- INTO
--         V_NR_EW, V_NAZWISKO, V_IMIE, V_STANOWISKO, V_COST_CENTER, V_JEDN_ORG, V_DZIAL, V_DATA_ZATRUDNIENIA, V_DATA_ZWOLNIENIA, V_EMAIL,
--         V_RODZAJ_UMOWY, V_WYMIAR_ETATU, V_U_DATA_OD, V_U_DATA_DO,
--     V_STAWKA, V_PESEL, V_DATA_URODZENIA, V_US, V_FIRMA, V_NR_BANKOWY, V_NAZWA_BANKU, V_BAND, V_NFZ, V_NFZ_DATA_OD, V_NFZ_DATA_DO,
--     V_WYKSZTALCENIE, V_ADRES_STALY, V_ADRES_ZAMIESZKANIA, V_ADRES_KORESPONDENCYJNY

from SL_STAN nsta, NT_KP_KDR_STANOWISKA LSTN, RK_MPK MPK, TETA_JEDN_ORG ORG, TETA_JEDN_ORG_POWIAZANIA NORG, TETA_JEDN_ORG ORG2, L_UMOWY UMOW, SL_UMOWY SUMO, NT_KP_PRC_PRACOWNICY PRAC

LEFT JOIN TETA_FIRMY FIRM ON FIRM.ID = PRAC.FIRM_ID
left join ap_kontrahenci konr on prac.konr_id = konr.id
LEFT JOIN KP_SOP_RACHUNKI_BANKOWE RACH ON RACH.OSBY_ID = PRAC.OSBY_ID AND RACH.DEFAULT_ACCOUNT = 'T'
LEFT JOIN RK_BANKI BANK ON BANK.ID = RACH.BANK_ID
LEFT JOIN KP_KDR_ADDITIONAL_INFO_1 INF1 ON INF1.PRAC_ID = PRAC.ID and INF1.date_from <= sysdate AND nvl(INF1.date_to, TO_DATE('2099-12-31', 'YYYY-MM-DD')) >= sysdate
LEFT JOIN L_KASA_CHORYCH KNFZ ON KNFZ.PRAC_ID = PRAC.ID AND KNFZ.DATA_DO IS NULL
LEFT JOIN SL_KASA_CHORYCH NFZ ON NFZ.ID = KNFZ.SL_KASA_CHORYCH_ID
left join HH_HR_EMPloyee_ADDRESSES adrs on adrs.prac_id = prac.id and adrs.adr_type = 'P' and adrs.date_to is null
left join HH_HR_EMPloyee_ADDRESSES adrt on adrt.prac_id = prac.id and adrt.adr_type = 'T' and adrt.date_to is null
left join HH_HR_EMPloyee_ADDRESSES adrc on adrc.prac_id = prac.id and adrc.adr_type = 'C' and adrc.date_to is null
where
ORG.ID = LSTN.JEOR_ID
AND prac.id = lstn.prac_id
AND LSTN.DATA_OD <= sysdate
AND (NVL(LSTN.DATA_DO, TO_DATE('2099-01-01', 'YYYY-MM-DD')) >= sysdate)
and lstn.SSTN_ID = nsta.id
AND MPK.ID = LSTN.MPK_ID
AND ORG.ID = NORG.JEOR_ID
AND NORG.NAD_JEOR_ID = ORG2.ID
AND umow.DATA_OD <= sysdate
AND (NVL(umow.DATA_DO, TO_DATE('2099-01-01', 'YYYY-MM-DD')) >= sysdate)
and umow.prac_id = prac.id
AND SUMO.ID = UMOW.UMOWY_ID
and PRAC.ID = (SELECT U.PRAC_ID FROM TETA_USERS U WHERE U.ID = PA_SESJE.USER_ID)
AND PRAC.ID = 9683;

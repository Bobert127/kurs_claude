-- ============================================================
-- ORYGINALNE ZAPYTANIE
-- Blok 1: Insert benefitów dla nadgodzin
-- ============================================================
declare

a KP_RCP_ZLEC_NADG_PRAC.id%type;
b KP_RCP_ZLEC_NADG_PRAC.czas%type;

cursor c is

    select DISTINCT CASE WHEN BEN.ID IS NULL THEN OV.ID END, ov.czas
    FROM NT_KP_KDR_KALENDARZE_PRAC KA, T_PRAC PRAC, KP_RCP_ZLEC_NADG_PRAC OV
    LEFT JOIN KP_RCP_ZLEC_NADG_PRAC_BENEFITY BEN ON BEN.BEN_ID = OV.ID
    WHERE OV.kali_id = ka.id
    AND OV.HOURS_OFF_IN_LIEU = 'T'
    AND OV.RCZN_ID IN (31,32)
    AND KA.TYP_DNIA is null
    AND OV.PAYMENT_ONLY = 'N'
    AND PRAC.PRAC_ID = OV.PRAC_ID
--    AND OV.ID = 11520
    AND PRAC.FIRM_ID = 100
    AND TO_DATE(SYSDATE, 'YY/MM/DD') >= TO_DATE(OV.DATA, 'YY/MM/DD') - 60
    AND (OV.UZASADNIENIE != 'benefit nadgodziny' or OV.UZASADNIENIE is null);

begin
    open c;
        loop
            fetch c into a, b;
            exit when c%notfound;
             if a is not null then
                Insert into kp_rcp_zlec_nadg_prac values
                (
                kp_rczp_seq.nextval,
                (select prac_id from kp_rcp_zlec_nadg_prac where id = a),
                (select RCZN_ID from kp_rcp_zlec_nadg_prac where id = a),
                (select MPK_ID from kp_rcp_zlec_nadg_prac where id = a),
                (select to_date(data, 'RR/MM/DD') from kp_rcp_zlec_nadg_prac where id = a),
                (select GODZ_DO from kp_rcp_zlec_nadg_prac where id = a),
                (select GODZ_DO + b/2/24 from kp_rcp_zlec_nadg_prac where id = a),
                (select CZAS/2 from kp_rcp_zlec_nadg_prac where id = a),
                null,'benefit nadgodziny','ARLA (unknown)',
                (select to_date(DATA_UTWORZENIA, 'RR/MM/DD') from kp_rcp_zlec_nadg_prac where id = a),
                NULL,
                (select to_date(DATA_MODYFIKACJI, 'RR/MM/DD') from kp_rcp_zlec_nadg_prac where id = a),
                (select kali_id from kp_rcp_zlec_nadg_prac where id = a),
                'N',null,null,null,
                (select OVTO_ID from kp_rcp_zlec_nadg_prac where id = a),
                '02','N','N',
                (select APPROVED_TIME_TO from kp_rcp_zlec_nadg_prac where id = a),
                (select APPROVED_TIME_TO + b/2/24 from kp_rcp_zlec_nadg_prac where id = a),
                (select APPROVED_HOURS/2 from kp_rcp_zlec_nadg_prac where id = a),
                (select CLASSIFIED_SECONDS_01/2 from kp_rcp_zlec_nadg_prac where id = a),
                (select CLASSIFIED_SECONDS_02/2 from kp_rcp_zlec_nadg_prac where id = a),
                (select CLASSIFIED_SECONDS_03/2 from kp_rcp_zlec_nadg_prac where id = a),
                'T',null,null,null,
                sys_guid(),
                (select CLASSIFIED_SECONDS_10 from kp_rcp_zlec_nadg_prac where id = a),
                (select CLASSIFIED_SECONDS_11 from kp_rcp_zlec_nadg_prac where id = a),
                (select CLASSIFIED_SECONDS_12 from kp_rcp_zlec_nadg_prac where id = a),
                (select CLASSIFIED_SECONDS_20 from kp_rcp_zlec_nadg_prac where id = a),
                 '0','0','0','N','T','0','02','N',null, null, null,null, null, null, null,
                null, null, null,null, null, null, null, null,null,null,
                null, null, null,null, null, null, null, null,null,null,
                null, null, null,null, null, null, null, null,null,null,
                null, null, null,null, null,'N','N','N','N','N','N','N','N','N','N',NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
                commit;
                insert into KP_RCP_ZLEC_NADG_PRAC_BENEFITY values(KP_RCP_ZLEC_NADG_PRAC_BENEFITY_SEQ.NEXTVAL, a);
                COMMIT;
              end if;
        end loop;
    close c;
end;

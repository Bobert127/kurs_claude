-- ============================================================
-- ORYGINALNE ZAPYTANIE
-- Blok 1: Insert benefitow dla niedziel (TYP_DNIA = 'N')
-- ============================================================
declare
a KP_RCP_ZLEC_NADG_PRAC.id%type;
b KP_RCP_ZLEC_NADG_PRAC.prac_id%type;
cursor c is
select DISTINCT CASE WHEN BEN.ID IS NULL THEN OV.ID END, ov.prac_id prac
FROM NT_KP_KDR_KALENDARZE_PRAC KA, T_PRAC PRAC, KP_RCP_ZLEC_NADG_PRAC OV
LEFT JOIN KP_RCP_ZLEC_NADG_PRAC_BENEFITY BEN ON BEN.BEN_ID = OV.ID
WHERE OV.kali_id = ka.id
AND OV.DAY_OFF_IN_LIEU = 'T'
AND KA.TYP_DNIA in ('N')
AND PRAC.PRAC_ID = KA.PRAC_ID
AND PRAC.FIRM_ID = 100
AND (OV.UZASADNIENIE != 'benefit niedziela i święto' or OV.UZASADNIENIE is null)
AND TO_DATE(SYSDATE, 'YY/MM/DD') >= TO_DATE(OV.DATA, 'YY/MM/DD') -60
AND OV.CZAS = 8;
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
(select GODZ_OD from kp_rcp_zlec_nadg_prac where id = a),
(select GODZ_DO from kp_rcp_zlec_nadg_prac where id = a),
(select CZAS from kp_rcp_zlec_nadg_prac where id = a),
null,'benefit niedziela i święto','ARLA (unknown)',
(select to_date(DATA_UTWORZENIA, 'RR/MM/DD') from kp_rcp_zlec_nadg_prac where id = a),
NULL,
(select to_date(DATA_MODYFIKACJI, 'RR/MM/DD') from kp_rcp_zlec_nadg_prac where id = a),
(select kal.id
from NT_KP_KDR_KALENDARZE_PRAC kal, L_UMOWY luw
where kal.typ_dnia = 'N'
and luw.prac_id = kal.prac_id
AND luw.DATA_OD <= sysdate
AND (NVL(luw.DATA_DO, TO_DATE('2099-01-01', 'YYYY-MM-DD')) >= sysdate)
and to_date(kal.dzien_mies, 'YY/MM/DD') >= to_date(luw.DATA_OD, 'YY/MM/DD')
and dzien_mies between sysdate -30 and sysdate +30
and dzien_mies < pa_standard.Ostatni_Dzien_Roku(sysdate)
and kal.prac_id = b
and not exists (select kali_id from KP_RCP_ZLEC_NADG_PRAC zlec where zlec.kali_id = kal.id and zlec.prac_id = kal.prac_id and kal.typ_dnia = 'N')
and kal.typ_dnia = 'N'
and ROWNUM <= 1) ,
'N',null,null,null,
(select OVTO_ID from kp_rcp_zlec_nadg_prac where id = a),
'02','N','N',
(select APPROVED_TIME_FROM from kp_rcp_zlec_nadg_prac where id = a),
(select APPROVED_TIME_TO from kp_rcp_zlec_nadg_prac where id = a),
(select APPROVED_HOURS from kp_rcp_zlec_nadg_prac where id = a),
'0',
(select CLASSIFIED_SECONDS_02 from kp_rcp_zlec_nadg_prac where id = a),
'0','T',null,null,null,
sys_guid(),'0','0','0',
(select CLASSIFIED_SECONDS_20 from kp_rcp_zlec_nadg_prac where id = a),
'0','0','0','N','T','0','02','N',null, null, null,null, null, null, null,
null, null, null,null, null, null, null, null,null,null,
null, null, null,null, null, null, null, null,null,null,
null, null, null,null, null, null, null, null,null,null,
null, null, null,null, null,'N','N','N','N','N','N','N','N','N','N', null,null,null, NULL, NULL, NULL, NULL, NULL);
commit;
insert into KP_RCP_ZLEC_NADG_PRAC_BENEFITY values(KP_RCP_ZLEC_NADG_PRAC_BENEFITY_SEQ.NEXTVAL, a);
COMMIT;
end if;
end loop;
close c;
end;


-- ============================================================
-- ORYGINALNE ZAPYTANIE
-- Blok 2: Zmiana payment_only dla odbioru w soboty
-- ============================================================
declare
a KP_RCP_ZLEC_NADG_PRAC.id%type;
cursor c is
SELECT OV.ID
FROM NT_KP_KDR_KALENDARZE_PRAC KA, T_PRAC PRAC, KP_RCP_ZLEC_NADG_PRAC OV
WHERE OV.kali_id = ka.id
AND OV.DAY_OFF_IN_LIEU = 'T'
AND OV.SETTLED = 'N'
AND OV.PAYMENT_ONLY = 'T'
AND KA.TYP_DNIA in ('S')
AND TO_DATE(SYSDATE, 'YY/MM/DD') >= TO_DATE(OV.DATA, 'YY/MM/DD') - 60
AND OV.CZAS = 8
AND PRAC.PRAC_ID = KA.PRAC_ID
AND PRAC.FIRM_ID = 100;
begin
open c;
loop
fetch c into a;
exit when c%notfound;
if a is not null then
update kp_rcp_zlec_nadg_prac set payment_only = 'N' where id = a;
commit;
end if;
end loop;
close c;
end;

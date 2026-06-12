-- ============================================================
-- ORYGINALNE ZAPYTANIE
-- Blok 1: Insert benefitow dla sobot (TYP_DNIA = 'W')
-- ============================================================
declare
a KP_RCP_ZLEC_NADG_PRAC.id%type;
b t_prac.prac_id%type;
cursor c is
select DISTINCT CASE WHEN BEN.ID IS NULL THEN OV.ID END, prac.prac_id prac
FROM NT_KP_KDR_KALENDARZE_PRAC KA, T_PRAC PRAC, KP_RCP_ZLEC_NADG_PRAC OV
LEFT JOIN KP_RCP_ZLEC_NADG_PRAC_BENEFITY BEN ON BEN.BEN_ID = OV.ID
WHERE OV.kali_id = ka.id
AND OV.DAY_OFF_IN_LIEU = 'T'
AND OV.SETTLED = 'N'
AND KA.TYP_DNIA = 'W'
AND KA.PRAC_ID = PRAC.PRAC_ID
AND PRAC.FIRM_ID = 100
--AND PRAC.PRAC_ID = 12124
AND (OV.UZASADNIENIE != 'benefit sobota' or OV.UZASADNIENIE is null)
AND TO_DATE(SYSDATE, 'YY/MM/DD') >= TO_DATE(OV.DATA, 'YY/MM/DD') - 60
AND TO_DATE(OV.DATA, 'YY/MM/DD') >= '25/12/01'
AND OV.CZAS = 8
AND PRAC.prac_id = ov.prac_id;
begin
open c;
loop
fetch c into a,b;
exit when c%notfound;
if a is not null then
Insert into kp_rcp_zlec_nadg_prac values(
kp_rczp_seq.nextval,
(select prac_id from kp_rcp_zlec_nadg_prac where id = a),
(select RCZN_ID from kp_rcp_zlec_nadg_prac where id = a),
(select MPK_ID from kp_rcp_zlec_nadg_prac where id = a),
(select to_date(data, 'RR/MM/DD') from kp_rcp_zlec_nadg_prac where id = a),
(select GODZ_OD from kp_rcp_zlec_nadg_prac where id = a),
(select GODZ_DO from kp_rcp_zlec_nadg_prac where id = a),
(select CZAS from kp_rcp_zlec_nadg_prac where id = a),
null,'benefit sobota','ARLA (unknown)',
(select to_date(DATA_UTWORZENIA, 'RR/MM/DD') from kp_rcp_zlec_nadg_prac where id = a),
NULL,
(select to_date(DATA_MODYFIKACJI, 'RR/MM/DD') from kp_rcp_zlec_nadg_prac where id = a),
(select kal.id
from NT_KP_KDR_KALENDARZE_PRAC kal, L_UMOWY luw
where kal.typ_dnia in ('W')
and luw.prac_id = kal.prac_id
AND luw.DATA_OD <= sysdate
AND (NVL(luw.DATA_DO, TO_DATE('2099-01-01', 'YYYY-MM-DD')) >= sysdate)
and to_date(kal.dzien_mies, 'YY/MM/DD') >= to_date(luw.DATA_OD, 'YY/MM/DD')
and not exists (select kali_id from KP_RCP_ZLEC_NADG_PRAC zlec where zlec.kali_id = kal.id and zlec.prac_id = kal.prac_id and kal.typ_dnia in('W'))
and typ_dnia in ('W')
and dzien_mies between sysdate -60 and sysdate +30
and dzien_mies < pa_standard.Ostatni_Dzien_Roku(sysdate)
and kal.prac_id = b
and ROWNUM <= 1),
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
'0','0','0','T','N','0','02','N',null, null, null,null, null, null, null,
null, null, null,null, null, null, null, null,null,null,
null, null, null,null, null, null, null, null,null,null,
null, null, null,null, null, null, null, null,null,null,
null, null, null,null, null,'N','N','N','N','N','N','N','N','N','N', null,null,null,null,null,null,null,null);
commit;
insert into KP_RCP_ZLEC_NADG_PRAC_BENEFITY values(KP_RCP_ZLEC_NADG_PRAC_BENEFITY_SEQ.NEXTVAL, a);
COMMIT;
end if;
end loop;
close c;
end;

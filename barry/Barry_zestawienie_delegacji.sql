select akt_dane.firma(p.prac_id) firma, p.nr_ew, to_char(p.data_zatr, 'YYYY-MM-DD') data_zatr, to_char(p.data_rozw, 'YYYY-MM-DD') data_rozw,
p.imie, p.nazwisko, akt_dane.stanowisko(p.prac_id, z.WORKDAY_DATE_FROM) stanowisko,
doc.numer, st.nazwa as status_wniosku, ztt.name as typ_wniosku, to_char(doc.data_rejestracji, 'YYYY-MM-DD') as data_wniosku,
to_char(z.WORKDAY_DATE_from, 'YYYY-MM-DD') as data_od, to_char(z.WORKDAY_DATE_to, 'YYYY-MM-DD') as data_do,
zt.godzina_od as godzina_od_delegacji,
zt.godzina_do as godzina_do_delegacji,
initcap(akt_dane.Direct_Superior(p.prac_id, z.WORKDAY_DATE_FROM)) as przelozony
from  t_prac p, KP_RCP_WORKTIME_EVENT_REQUESTS z
left join PA_WFL_DOC_ASSOCIATIONS DOAS on z.GUID = DOAS.DOCUMENT_GUID
left join PA_WFL_DOKUMENTY DOC on DOAS.DOKU_ID = DOC.ID
left join PA_WFL_STATUSY_DOKUMENTOW ST on DOC.STDO_KOD = ST.KOD
left join KP_RCP_WORK_TIME_EVENT_TYPES ztt on ztt.id = z.wtet_id
left join (
    select zczp.wter_id pow,
    to_char(min(zczp.DATE_TIME_FROM), 'HH24:MI') godzina_od,
    to_char(max(zczp.DATE_TIME_TO), 'HH24:MI') godzina_do
    from KP_RCP_WORK_TIME_EVENTS zczp
    where zczp.wtet_id in (12,13)
    group by zczp.wter_id
) zt on zt.pow = z.id and trunc(z.WORKDAY_DATE_from) = trunc(z.WORKDAY_DATE_to)
where z.wtet_id in (12,13)
and p.PRAC_ID = z.prac_id
and z.WORKDAY_DATE_from >= to_date('2026-01-01', 'YYYY-MM-DD')
and z.WORKDAY_DATE_to <= to_date('2026-10-31', 'YYYY-MM-DD')
order by firma, p.nazwisko, p.imie, doc.data_rejestracji desc;

select p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY, to_char(zn.data, 'DD-MM-YYYY') as data_zlecenia, to_char(zn.data, 'MM-YYYY') as data_miesiac,  case when zn.settled = 'T' then 'Rozliczone' else 'Nierozliczone' end as rozliczone, wn.symbol as nr_wnisku,
p_rcp_licz.n_nh(zn.czas) as czas, p_rcp_licz.n_nh(zn.CLASSIFIED_SECONDS_01/3600) g_50, p_rcp_licz.n_nh(zn.classified_seconds_02/3600) g_100,
nvl(case when odb.all_day = 'T' then 8 else p_rcp_licz.n_nh(odb.seconds_count/3600) end,0) as godziny_odebrne,
to_char(a.data_od, 'DD-MM-YYYY') as data_odbioru
from t_prac p, KP_RCP_ZLEC_NADG_PRAC zn
left join KP_RCP_OVERTIME_AND_TOIL_REQ wn on wn.id = zn.ovto_id
left join KP_RCP_LABS_RCZP odb on odb.RCZP_ID = zn.ID
left join l_absencje a on a.id = odb.LABS_ID
where p.prac_id = zn.prac_id
and p.nr_ew
IN (
'BC146620',
'BC145867',
'BC145568',
'BC144757',
'BC146621',
'BC145222',
'BC144476',
'BC146661',
'BC139787',
'BC142061',
'BC134354',
'BC134209',
'BC145571',
'BC143382',
'BC139835',
'BC110561',
'BC134923',
'BC136656'
)
and zn.data between to_date('01-08-2025', 'DD-MM-YYYY') and to_date('31-08-2026', 'DD-MM-YYYY')
order by p.nazwisko, p.imie, zn.data, to_char(zn.data, 'MM-YYYY') ;

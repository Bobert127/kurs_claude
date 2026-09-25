select akt_dane.firma(p.id) firma,
p.imie, p.NAZWISKO, p.NR_EWIDENCYJNY, p.NR_KARTY,
to_char(z.data, 'mm-yyyy') miesiac,
sum(round(p_rcp_licz.n_nh(z.CLASSIFIED_SECONDS_11/3600),2)) z_50, sum(round(p_rcp_licz.n_nh(z.CLASSIFIED_SECONDS_12/3600),2)) z_100,
sum(round(p_rcp_licz.n_nh(z.CLASSIFIED_SECONDS_20/3600),2)) + sum(round(p_rcp_licz.n_nh(z.CLASSIFIED_SECONDS_24/3600),2)) z_średniotygodniowe,
nvl(sum(odb.g50),0) zap_g50, nvl(sum(odb.g100),0) zap_g100, nvl(sum(odb.gsredniotygodniowe),0) zap_gśredniotygodniowe

from NT_KP_PRC_PRACOWNICY p, NT_KP_RCP_ZLECENIA_NADG z
left join
(
select zz.RCZP_ID pow,
sum(round(p_rcp_licz.n_nh(zz.CLASSIFIED_SECONDS_11/3600),2)) g50,
sum(round(p_rcp_licz.n_nh(zz.CLASSIFIED_SECONDS_12/3600),2)) g100,
sum(round(p_rcp_licz.n_nh(zz.CLASSIFIED_SECONDS_20/3600),2)) gsredniotygodniowe
from KP_RCP_OVERTIME_PAYMENT zz
group by zz.RCZP_ID
)  odb on  odb.pow = z.ID

where p.id = z.prac_id
and z.DATA between '25/01/01' and '26/09/30'
-- and p.NR_EWIDENCYJNY = 'PL016705'
group by p.imie, p.NAZWISKO, p.NR_EWIDENCYJNY, p.NR_KARTY, p.id, to_char(z.data, 'mm-yyyy')
order by akt_dane.firma(p.id), p.NAZWISKO, p.IMIE,  to_char(z.data, 'mm-yyyy');

---ver2

select akt_dane.firma(p.id) firma,
p.imie, p.NAZWISKO, p.NR_EWIDENCYJNY, p.NR_KARTY,
to_char(z.data, 'dd-mm-yyyy') dzień,
round(p_rcp_licz.n_nh(z.CLASSIFIED_SECONDS_11/3600),2) z_50, round(p_rcp_licz.n_nh(z.CLASSIFIED_SECONDS_12/3600),2) z_100,
round(p_rcp_licz.n_nh(z.CLASSIFIED_SECONDS_20/3600),2) + round(p_rcp_licz.n_nh(z.CLASSIFIED_SECONDS_24/3600),2) z_średniotygodniowe,
nvl(odb.g50,0) zap_g50, nvl(odb.g100,0) zap_g100, nvl(odb.gsredniotygodniowe,0) zap_gśredniotygodniowe

from NT_KP_PRC_PRACOWNICY p, NT_KP_RCP_ZLECENIA_NADG z
left join
(
select zz.RCZP_ID pow,
sum(round(p_rcp_licz.n_nh(zz.CLASSIFIED_SECONDS_11/3600),2)) g50,
sum(round(p_rcp_licz.n_nh(zz.CLASSIFIED_SECONDS_12/3600),2)) g100,
sum(round(p_rcp_licz.n_nh(zz.CLASSIFIED_SECONDS_20/3600),2)) gsredniotygodniowe
from KP_RCP_OVERTIME_PAYMENT zz
group by zz.RCZP_ID
)  odb on  odb.pow = z.ID

where p.id = z.prac_id
and z.DATA between '25/01/01' and '26/09/30'
-- and p.NR_EWIDENCYJNY = 'PL016705'
-- group by p.imie, p.NAZWISKO, p.NR_EWIDENCYJNY, p.NR_KARTY, p.id, to_char(z.data, 'mm-yyyy')
order by akt_dane.firma(p.id), p.NAZWISKO, p.IMIE,  to_char(z.data, 'dd-mm-yyyy');

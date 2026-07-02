select p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY, z.data
from kp_rcp_zlec_nadg_prac z, t_prac p
where z.data between DATE '2026-05-01' and DATE '2026-06-30'
and p.PRAC_ID = z.PRAC_ID
and z.SETTLED = 'N'
and akt_dane.firma(p.prac_id) in ('Barry Callebaut Manufacturing Polska sp. z o.o. ', 'Barry Callebaut Polska sp z o.o.');

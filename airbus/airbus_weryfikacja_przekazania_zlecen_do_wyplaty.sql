select p.imie, p.nazwisko, p.nr_ew, p.NR_KARTY, z.data
from kp_rcp_zlec_nadg_prac z, t_prac p
where z.data between DATE '2026-04-01' and DATE '2026-06-30'
and p.PRAC_ID = z.PRAC_ID
and z.SETTLED = 'N'
and AKT_DANE.TYP_PRACOWNIKA(
        p.prac_id,
        case
            when p.data_rozw <= DATE '2026-06-30' then p.data_rozw
            else DATE '2026-06-30'
        end
    ) = 'BCW';
